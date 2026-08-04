// ============================================================
// GOLRIVA — PUSH BİLDİRİMİ GÖNDERME (Supabase Edge Function)
// Admin panel bunu service_role anahtarıyla çağırır. Fonksiyon:
//   1) çağıranın service_role olduğunu doğrular,
//   2) hedef cihaz jetonlarını (tümü / tek kullanıcı) çeker,
//   3) servis hesabından OAuth2 jetonu üretir,
//   4) FCM HTTP v1 ile her cihaza gönderir,
//   5) ölü jetonları temizler, sonucu bildirim_gecmisi'ne yazar.
//
// GEREKLİ ORTAM DEĞİŞKENLERİ (Supabase → Edge Functions → Secrets):
//   FCM_SERVICE_ACCOUNT  : Firebase servis hesabı JSON'unun TAMAMI (tek satır)
//   SB_URL               : https://xxxx.supabase.co
//   SB_SERVICE_ROLE_KEY  : service_role anahtarı
// (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY adları Supabase'te ayrılmış
//  olduğundan kendi adlarımızı kullanıyoruz.)
// ============================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ── Ses → Android kanal + iOS ses dosyası eşlemesi ──
// (Android'de kanal sesi kanal oluşturulurken sabitlenir; bu yüzden her ses
//  için ayrı kanal. Uygulama tarafı bu kanalları aynı adla oluşturur.)
// TEK TİP bildirim: tek kanal + cihaz varsayılan sesi.
const KANAL = "golriva_bildirim";

function b64url(data: Uint8Array): string {
  let s = btoa(String.fromCharCode(...data));
  return s.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToDer(pem: string): Uint8Array {
  const gövde = pem
    .replace(/-----BEGIN [^-]+-----/, "")
    .replace(/-----END [^-]+-----/, "")
    .replace(/\s+/g, "");
  const bin = atob(gövde);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

// Servis hesabından Google OAuth2 access_token üretir (RS256 imzalı JWT).
async function erisimJetonu(sa: {
  client_email: string;
  private_key: string;
  token_uri: string;
}): Promise<string> {
  const şimdi = Math.floor(Date.now() / 1000);
  const başlık = { alg: "RS256", typ: "JWT" };
  const iddia = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: sa.token_uri,
    iat: şimdi,
    exp: şimdi + 3600,
  };
  const enc = new TextEncoder();
  const gövde =
    b64url(enc.encode(JSON.stringify(başlık))) +
    "." +
    b64url(enc.encode(JSON.stringify(iddia)));
  const anahtar = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const imza = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", anahtar, enc.encode(gövde)),
  );
  const jwt = gövde + "." + b64url(imza);

  const yanıt = await fetch(sa.token_uri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const veri = await yanıt.json();
  if (!yanıt.ok) {
    throw new Error("OAuth jetonu alınamadı: " + JSON.stringify(veri));
  }
  return veri.access_token as string;
}

Deno.serve(async (istek) => {
  if (istek.method === "OPTIONS") return new Response("ok", { headers: CORS });

  const json = (o: unknown, durum = 200) =>
    new Response(JSON.stringify(o), {
      status: durum,
      headers: { ...CORS, "Content-Type": "application/json" },
    });

  try {
    const SERVICE_ROLE = Deno.env.get("SB_SERVICE_ROLE_KEY") ?? "";
    const SB_URL = Deno.env.get("SB_URL") ?? "";
    const SA_HAM = Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "";
    if (!SERVICE_ROLE || !SB_URL || !SA_HAM) {
      return json({ hata: "Sunucu ortam değişkenleri eksik (secrets)." }, 500);
    }

    // ── YETKİ: yalnız service_role çağırabilir ──
    const yetki = istek.headers.get("Authorization") ?? "";
    const gelen = yetki.replace(/^Bearer\s+/i, "").trim();
    if (gelen !== SERVICE_ROLE) {
      return json({ hata: "Yetkisiz — yalnız yönetim paneli gönderebilir." }, 401);
    }

    const {
      hedef = "tum",
      user_id = null,
      kullanici_adi = null,
      baslik,
      govde,
      veri = {},
    } = await istek.json();

    if (!baslik || !govde) {
      return json({ hata: "Başlık ve mesaj zorunlu." }, 400);
    }

    const sb = createClient(SB_URL, SERVICE_ROLE);

    // ── Hedef kullanıcıyı çöz ──
    let hedefUid: string | null = user_id;
    if (hedef === "kullanici" && !hedefUid && kullanici_adi) {
      const { data: prof } = await sb
        .from("profiller")
        .select("id")
        .ilike("kullanici_adi", String(kullanici_adi).trim())
        .limit(1)
        .maybeSingle();
      if (!prof) return json({ hata: "Kullanıcı bulunamadı." }, 404);
      hedefUid = prof.id;
    }
    if (hedef === "kullanici" && !hedefUid) {
      return json({ hata: "Kullanıcı belirtilmedi." }, 400);
    }

    // ── Jetonları çek ──
    let sorgu = sb.from("cihaz_tokenleri").select("token, platform");
    if (hedef === "kullanici") sorgu = sorgu.eq("user_id", hedefUid);
    const { data: cihazlar, error: tokHata } = await sorgu;
    if (tokHata) return json({ hata: "Jetonlar okunamadı: " + tokHata.message }, 500);
    if (!cihazlar || cihazlar.length === 0) {
      await sb.from("bildirim_gecmisi").insert({
        hedef, user_id: hedefUid, baslik, govde, gonderildi: 0, basarisiz: 0,
      });
      return json({ gonderildi: 0, basarisiz: 0, not: "Hedefte kayıtlı cihaz yok." });
    }

    // ── OAuth + proje kimliği ──
    const sa = JSON.parse(SA_HAM);
    const jeton = await erisimJetonu(sa);
    const projeId = sa.project_id;
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projeId}/messages:send`;

    // ── Her cihaza gönder (tek tip: varsayılan ses) ──
    let ok = 0, fail = 0;
    const olu: string[] = [];
    for (const c of cihazlar) {
      const mesaj: Record<string, unknown> = {
        token: c.token,
        notification: { title: baslik, body: govde },
        data: Object.fromEntries(
          Object.entries(veri).map(([k, v]) => [k, String(v)]),
        ),
        android: {
          priority: "high",
          notification: { channel_id: KANAL, sound: "default" },
        },
        apns: {
          payload: { aps: { sound: "default" } },
        },
      };
      try {
        const r = await fetch(fcmUrl, {
          method: "POST",
          headers: {
            Authorization: "Bearer " + jeton,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ message: mesaj }),
        });
        if (r.ok) {
          ok++;
        } else {
          fail++;
          const hataMetni = await r.text();
          // kayıtlı olmayan / geçersiz jeton → temizle
          if (
            r.status === 404 ||
            hataMetni.includes("UNREGISTERED") ||
            hataMetni.includes("INVALID_ARGUMENT")
          ) {
            olu.push(c.token);
          }
        }
      } catch (_) {
        fail++;
      }
    }

    if (olu.length) {
      await sb.from("cihaz_tokenleri").delete().in("token", olu);
    }
    await sb.from("bildirim_gecmisi").insert({
      hedef, user_id: hedefUid, baslik, govde, gonderildi: ok, basarisiz: fail,
    });

    return json({ gonderildi: ok, basarisiz: fail, temizlenen: olu.length });
  } catch (e) {
    return json({ hata: "Gönderim hatası: " + (e?.message ?? e) }, 500);
  }
});
