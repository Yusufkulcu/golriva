/* ══════════════════════════════════════════════════════════
   GOLRIVA YÖNETİM — ortak motor
   Her sayfa bunu yükler: oturum, menü, yardımcılar, tazeleme
   ══════════════════════════════════════════════════════════ */

/* ───────── tema ───────── */
(function temaKur(){
  var t = localStorage.getItem('glr_tema') || 'acik';
  document.documentElement.setAttribute('data-tema', t);
})();
function temaDegistir(){
  var s = document.documentElement.getAttribute('data-tema') === 'karanlik' ? 'acik' : 'karanlik';
  document.documentElement.setAttribute('data-tema', s);
  localStorage.setItem('glr_tema', s);
  var b = document.getElementById('tema-btn'); if (b) b.innerHTML = temaIkon();
}
function temaIkon(){
  return document.documentElement.getAttribute('data-tema') === 'karanlik' ? IK.gunes : IK.ay;
}

/* ───────── ikonlar (inline svg) ───────── */
var IK = {
  pano:'<svg class="ikon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3" y="3" width="7" height="9" rx="1.5"/><rect x="14" y="3" width="7" height="5" rx="1.5"/><rect x="14" y="12" width="7" height="9" rx="1.5"/><rect x="3" y="16" width="7" height="5" rx="1.5"/></svg>',
  canli:'<svg class="ikon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="3"/><path d="M6.3 6.3a8 8 0 0 0 0 11.4M17.7 17.7a8 8 0 0 0 0-11.4"/></svg>',
  karsilasma:'<svg class="ikon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="8.5"/><path d="M12 3.5v3M12 17.5v3M3.5 12h3M17.5 12h3M8.7 8.7 6.6 6.6M15.3 8.7l2.1-2.1M8.7 15.3l-2.1 2.1M15.3 15.3l2.1 2.1"/></svg>',
  istatistik:'<svg class="ikon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/></svg>',
  kullanici:'<svg class="ikon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="8" r="3.5"/><path d="M4.5 20a7.5 7.5 0 0 1 15 0"/></svg>',
  lig:'<svg class="ikon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M8 4h8v5a4 4 0 0 1-8 0V4Z"/><path d="M8 6H5v1a3 3 0 0 0 3 3M16 6h3v1a3 3 0 0 1-3 3M10 20h4M12 13v7"/></svg>',
  itiraz:'<svg class="ikon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M21 15a2 2 0 0 1-2 2H8l-4 3V5a2 2 0 0 1 2-2h13a2 2 0 0 1 2 2Z"/></svg>',
  ekonomi:'<svg class="ikon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="8.5"/><path d="M12 7v10M9.5 9.8h4a1.7 1.7 0 0 1 0 3.4h-3a1.7 1.7 0 0 0 0 3.4h4"/></svg>',
  market:'<svg class="ikon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M4 8h16l-1.2 11a2 2 0 0 1-2 1.8H7.2a2 2 0 0 1-2-1.8Z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/></svg>',
  reklam:'<svg class="ikon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M3 10v4h3l5 4V6L6 10H3Z"/><path d="M16 9.5a4 4 0 0 1 0 5M18.8 7a7 7 0 0 1 0 10"/></svg>',
  bildirim:'<svg class="ikon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M18 9a6 6 0 1 0-12 0c0 5-2 6-2 6h16s-2-1-2-6"/><path d="M10.3 20a2 2 0 0 0 3.4 0"/></svg>',
  hata:'<svg class="ikon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 8v5M12 16.5v.5"/><path d="M10.3 3.9 2.6 17.4A2 2 0 0 0 4.3 20.4h15.4a2 2 0 0 0 1.7-3l-7.7-13.5a2 2 0 0 0-3.4 0Z"/></svg>',
  ara:'<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>',
  menu:'<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 7h16M4 12h16M4 17h16"/></svg>',
  ay:'<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M20 14.5A8.5 8.5 0 0 1 9.5 4a8.5 8.5 0 1 0 10.5 10.5Z"/></svg>',
  gunes:'<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>',
  kapat:'<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m6 6 12 12M18 6 6 18"/></svg>',
  cikis:'<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M9 20H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/></svg>',
};

/* ───────── menü tanımı ───────── */
var MENU = [
  ['GENEL', [
    ['pano','Pano','pano.html'],
    ['canli','Canlı Oyunlar','canli.html'],
    ['karsilasma','Karşılaşmalar','karsilasmalar.html'],
    ['istatistik','İstatistik','istatistik.html'],
  ]],
  ['TOPLULUK', [
    ['kullanici','Kullanıcılar','kullanicilar.html'],
    ['lig','Ligler & Sezon','lig.html'],
    ['itiraz','Veri İtirazları','itiraz.html'],
  ]],
  ['EKONOMİ', [
    ['ekonomi','Riva Ekonomisi','ekonomi.html'],
    ['market','Market','market.html'],
    ['reklam','Reklam','reklam.html'],
  ]],
  ['SİSTEM', [
    ['bildirim','Push Bildirim','bildirim.html'],
    ['hata','Hata Kayıtları','hatalar.html'],
  ]],
];

/* ───────── yardımcılar ───────── */
var sb = null;
function E(s){ return String(s==null?'':s).replace(/[&<>"']/g, function(c){
  return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]; }); }
function S(n){ return (n==null||isNaN(n)) ? '—' : Number(n).toLocaleString('tr-TR'); }
function T(iso){ if(!iso) return '—';
  return new Date(iso).toLocaleString('tr-TR',{day:'2-digit',month:'short',hour:'2-digit',minute:'2-digit'}); }
function TGun(iso){ if(!iso) return '—';
  return new Date(iso).toLocaleDateString('tr-TR',{day:'2-digit',month:'short',year:'2-digit'}); }
function gecen(iso){
  if(!iso) return '—';
  var s = Math.floor((Date.now()-new Date(iso).getTime())/1000);
  if(s<60) return s+' sn';
  if(s<3600) return Math.floor(s/60)+' dk';
  if(s<86400) return Math.floor(s/3600)+' sa';
  return Math.floor(s/86400)+' gün';
}
function bas(s){ return (s||'?').trim().charAt(0).toUpperCase(); }
function hataAt(r){ if(r && r.error) throw r.error; return r; }

function toast(mesaj, hataMi){
  var k = document.getElementById('bildirimler');
  if(!k){ k=document.createElement('div'); k.id='bildirimler'; document.body.appendChild(k); }
  var d = document.createElement('div');
  d.className = 'toast' + (hataMi ? ' hata' : '');
  d.textContent = mesaj;
  k.appendChild(d);
  setTimeout(function(){ d.remove(); }, hataMi ? 7000 : 3200);
}
async function dene(islem, basariMesaji){
  try { await islem(); if(basariMesaji) toast(basariMesaji); return true; }
  catch(e){ toast('Hata: ' + (e.message||e), true); return false; }
}

/* ───────── kullanıcı adı önbelleği ───────── */
var adlar = {};
async function adlariYukle(uidler){
  var eksik = [];
  (uidler||[]).forEach(function(u){ if(u && !adlar[u] && eksik.indexOf(u)<0) eksik.push(u); });
  if(!eksik.length) return;
  var r = hataAt(await sb.from('profiller').select('id, kullanici_adi, avatar_url').in('id', eksik));
  r.data.forEach(function(p){ adlar[p.id] = {ad:p.kullanici_adi, avatar:p.avatar_url}; });
}
function ad(uid){ return uid ? ((adlar[uid]||{}).ad || uid.slice(0,8)) : '—'; }
function kisiHtml(uid, ikincil){
  if(!uid) return '<span class="mono">—</span>';
  var a = adlar[uid]||{};
  var av = a.avatar ? '<img src="'+E(a.avatar)+'" alt="">' : E(bas(a.ad));
  return '<div class="kisi"><div class="avt">'+av+'</div><div style="min-width:0">'+
         '<div class="isim">'+E(a.ad||uid.slice(0,8))+'</div>'+
         (ikincil ? '<div class="ikincil">'+E(ikincil)+'</div>' : '')+'</div></div>';
}

/* ───────── otomatik tazeleme ───────── */
var Tazele = {
  _t:null, _fn:null, _ms:5000, _acik:true, _son:null,
  baslat:function(fn, ms){
    this._fn = fn; this._ms = ms || 5000;
    this.calistir();
    this._kur();
  },
  _kur:function(){
    var o = this;
    clearInterval(this._t);
    if(!this._acik) return;
    this._t = setInterval(function(){ if(!document.hidden) o.calistir(); }, this._ms);
  },
  calistir:async function(){
    if(!this._fn) return;
    try { await this._fn(); this._son = new Date(); this._gosterge(); }
    catch(e){ /* sessiz — bir sonraki turda düzelir */ }
  },
  durdur:function(){ clearInterval(this._t); this._t=null; },
  degistir:function(ms){ this._ms = ms; this._kur(); },
  ac_kapa:function(){
    this._acik = !this._acik;
    if(this._acik){ this.calistir(); this._kur(); } else this.durdur();
    this._gosterge();
  },
  _gosterge:function(){
    var e = document.getElementById('canli-gosterge');
    if(!e) return;
    if(this._acik){
      e.innerHTML = '<span class="nokta canli"></span> canlı · '+(this._ms/1000)+' sn'+
        (this._son ? ' · '+gecen(this._son.toISOString())+' önce' : '');
    } else {
      e.innerHTML = '<span class="nokta" style="background:var(--metin-3)"></span> duraklatıldı';
    }
  }
};
function tazeleGostergeHtml(){
  return '<span class="canli-etiket" id="canli-gosterge"><span class="nokta canli"></span> canlı</span>'+
         '<button class="kucuk sade" onclick="Tazele.ac_kapa()" id="tazele-btn">Duraklat</button>'+
         '<select onchange="Tazele.degistir(+this.value)" style="width:auto;padding:5px 8px;font-size:12px">'+
         '<option value="3000">3 sn</option><option value="5000" selected>5 sn</option>'+
         '<option value="10000">10 sn</option><option value="30000">30 sn</option></select>';
}

/* ───────── çekmece ───────── */
function cekmeceAc(baslik, icerik){
  var p = document.getElementById('perde'), c = document.getElementById('cekmece');
  document.getElementById('cekmece-baslik').textContent = baslik;
  document.getElementById('cekmece-govde').innerHTML = icerik;
  p.classList.add('acik'); c.classList.add('acik');
}
function cekmeceKapat(){
  var p = document.getElementById('perde'), c = document.getElementById('cekmece');
  if(p) p.classList.remove('acik');
  if(c) c.classList.remove('acik');
}

/* ───────── modal ───────── */
function modalAc(baslik, icerik, genis){
  var p = document.getElementById('modal-perde');
  if(!p) return;
  document.getElementById('modal-baslik').innerHTML = baslik;
  document.getElementById('modal-govde').innerHTML = icerik;
  document.getElementById('modal').classList.toggle('genis', !!genis);
  p.classList.add('acik');
  document.body.style.overflow = 'hidden';
}
function modalYaz(icerik){
  var g = document.getElementById('modal-govde');
  if(g) g.innerHTML = icerik;
}
function modalAcikMi(){
  var p = document.getElementById('modal-perde');
  return !!(p && p.classList.contains('acik'));
}
function modalKapat(){
  var p = document.getElementById('modal-perde');
  if(!p) return;
  p.classList.remove('acik');
  document.getElementById('modal-govde').innerHTML = '';
  document.body.style.overflow = '';
}
document.addEventListener('keydown', function(e){
  if(e.key === 'Escape'){ if(modalAcikMi()) modalKapat(); else cekmeceKapat(); }
});

/* ───────── oturum ───────── */
function oturumOku(){
  try { return JSON.parse(localStorage.getItem('glr_yonetim')||'null'); } catch(e){ return null; }
}
function oturumYaz(o){ localStorage.setItem('glr_yonetim', JSON.stringify(o)); }
function cikisYap(){ localStorage.removeItem('glr_yonetim'); location.href='index.html'; }

var YANLIS_ANAHTAR =
  'Bu anahtar service_role değil — panel bu anahtarla boş görünür. ' +
  'Doğrusu: Supabase → Project Settings → API keys → service_role';

function anahtarOnKontrol(anahtar){
  if(anahtar.indexOf('sb_publishable_')===0 || anahtar.indexOf('sb_anon_')===0) return YANLIS_ANAHTAR;
  if(anahtar.indexOf('eyJ')===0){
    try{
      var rol = JSON.parse(atob(anahtar.split('.')[1].replace(/-/g,'+').replace(/_/g,'/'))).role;
      if(rol && rol !== 'service_role') return YANLIS_ANAHTAR;
    }catch(e){}
  }
  return null;
}
async function baglantiSina(url, anahtar){
  var istemci = supabase.createClient(url, anahtar);
  var pr = hataAt(await istemci.from('profiller').select('id',{count:'exact',head:true}));
  var cz = hataAt(await istemci.from('cuzdanlar').select('user_id',{count:'exact',head:true}));
  if((pr.count||0) > 0 && (cz.count||0) === 0) throw new Error(YANLIS_ANAHTAR);
  return istemci;
}

/* ───────── sayfa kurulumu ───────── */
async function sayfaKur(ayar){
  var o = oturumOku();
  if(!o || !o.url || !o.anahtar){ location.href='index.html'; return false; }
  if(typeof supabase === 'undefined'){
    document.body.innerHTML = '<div class="yukleniyor">Supabase kütüphanesi yüklenemedi — internet bağlantını kontrol et.</div>';
    return false;
  }
  sb = supabase.createClient(o.url, o.anahtar);

  // menü
  var m = '';
  MENU.forEach(function(grup){
    m += '<div class="menu-grup">'+E(grup[0])+'</div>';
    grup[1].forEach(function(x){
      m += '<a href="'+x[2]+'" class="'+(x[0]===ayar.sayfa?'aktif':'')+'">'+(IK[x[0]]||'')+
           '<span>'+E(x[1])+'</span></a>';
    });
  });

  var kabuk =
   '<div class="kabuk">'+
    '<aside class="kenar-cubugu" id="kenar">'+
      '<div class="marka"><div class="logo">GR</div>'+
        '<div class="ad">GolRiva<small>yönetim paneli</small></div></div>'+
      '<nav class="menu">'+m+'</nav>'+
      '<div class="kenar-alt">'+
        '<span class="proje-ad">'+E(o.url.replace('https://','').replace('.supabase.co',''))+'</span>'+
        '<button class="kucuk sade" id="tema-btn" onclick="temaDegistir()" title="Tema">'+temaIkon()+'</button>'+
        '<button class="kucuk sade" onclick="cikisYap()" title="Çıkış">'+IK.cikis+'</button>'+
      '</div>'+
    '</aside>'+
    '<main class="icerik">'+
      '<header class="ust">'+
        '<button class="menu-btn" onclick="document.getElementById(\'kenar\').classList.toggle(\'acik\')">'+IK.menu+'</button>'+
        '<div><h1>'+E(ayar.baslik)+'</h1>'+(ayar.alt?'<div class="alt">'+E(ayar.alt)+'</div>':'')+'</div>'+
        '<div class="ust-sag" id="ust-sag"></div>'+
      '</header>'+
      '<div class="govde" id="govde"><div class="yukleniyor">Yükleniyor…</div></div>'+
    '</main>'+
   '</div>'+
   '<div class="perde" id="perde" onclick="cekmeceKapat()"></div>'+
   '<aside class="cekmece" id="cekmece">'+
     '<div class="cekmece-bas"><h3 id="cekmece-baslik"></h3>'+
       '<button class="sade kucuk" onclick="cekmeceKapat()">'+IK.kapat+'</button></div>'+
     '<div class="cekmece-govde" id="cekmece-govde"></div>'+
   '</aside>'+
   '<div class="modal-perde" id="modal-perde" onclick="modalKapat()">'+
     '<div class="modal" id="modal" onclick="event.stopPropagation()">'+
       '<div class="modal-bas"><h3 id="modal-baslik"></h3>'+
         '<button class="sade kucuk" onclick="modalKapat()">'+IK.kapat+'</button></div>'+
       '<div class="modal-govde" id="modal-govde"></div>'+
     '</div>'+
   '</div>'+
   '<div id="bildirimler"></div>';

  document.body.innerHTML = kabuk;
  document.title = ayar.baslik + ' · GolRiva Yönetim';
  return true;
}

/* sunucu eksikse gösterilecek kart */
function sunucuEksik(dosya, e){
  return '<div class="kart"><div class="kart-govde">'+
    '<b>Sunucu güncellemesi gerekli.</b><br>Supabase SQL editöründe <code>'+E(dosya)+'</code> çalıştırılmalı.'+
    '<div class="mono" style="margin-top:8px">'+E((e&&e.message)||e||'')+'</div></div></div>';
}

/* boş durum */
function bosDurum(mesaj){ return '<div class="bos">'+E(mesaj)+'</div>'; }

/* ══════════════════════════════════════════════════════════
   KULLANICI SEÇİCİ
   Serbest metin yerine aramalı açılır liste. Büyük kullanıcı
   tabanında paneli kilitlememek için EN AZ 3 HARF yazılmadan
   sunucuya hiç sorgu atılmaz; sonuç 8 satırla sınırlıdır.

     <div id="e-kul"></div>
     kullaniciSecici('e-kul');
     secilenKullanici('e-kul')  ->  {id, kullanici_adi} | null
     seciciTemizle('e-kul');
   ══════════════════════════════════════════════════════════ */
var _ksSecim = {};

function kullaniciSecici(alanId, ayar){
  ayar = ayar || {};
  var kok = document.getElementById(alanId);
  if(!kok) return null;
  delete _ksSecim[alanId];        // yeniden kurulan bileşen = seçim sıfır
  kok.classList.add('ks');
  kok.innerHTML =
    '<input class="ks-giris" type="text" autocomplete="off" spellcheck="false" placeholder="'+
      E(ayar.yerTutucu || 'kullanıcı ara (en az 3 harf)')+'">'+
    '<div class="ks-secili" style="display:none"></div>'+
    '<div class="ks-liste" style="display:none"></div>';

  var giris  = kok.querySelector('.ks-giris');
  var liste  = kok.querySelector('.ks-liste');
  var secili = kok.querySelector('.ks-secili');
  var zaman = null, sira = 0, satirlar = [], imlec = -1;

  function kapat(){ liste.style.display='none'; liste.innerHTML=''; satirlar=[]; imlec=-1; }

  function ipucu(metin){
    liste.innerHTML = '<div class="ks-bos">'+E(metin)+'</div>';
    liste.style.display = 'block'; satirlar = []; imlec = -1;
  }

  function ciz(kayitlar){
    satirlar = kayitlar; imlec = kayitlar.length ? 0 : -1;
    if(!kayitlar.length){ ipucu('eşleşen kullanıcı yok'); return; }
    liste.innerHTML = kayitlar.map(function(k,i){
      return '<div class="ks-sat'+(i===0?' aktif':'')+'" data-i="'+i+'">'+
             '<b>'+E(k.kullanici_adi||'—')+'</b>'+
             (k.yasakli ? '<em class="ks-yasak">yasaklı</em>' : '')+
             '<span>'+(k.elo!=null?('Elo '+k.elo):'')+'</span></div>';
    }).join('');
    liste.style.display = 'block';
  }

  function sec(k){
    if(!k) return;
    _ksSecim[alanId] = {id:k.id, kullanici_adi:k.kullanici_adi};
    kapat();
    giris.style.display = 'none';
    secili.style.display = 'flex';
    secili.innerHTML =
      '<b>'+E(k.kullanici_adi||'—')+'</b>'+
      '<code class="ks-uid">'+E(String(k.id).slice(0,8))+'…</code>'+
      '<button type="button" class="ks-sil" title="Seçimi kaldır">×</button>';
    secili.querySelector('.ks-sil').onclick = function(){
      seciciTemizle(alanId); kok.querySelector('.ks-giris').focus();
    };
    if(ayar.secildi) ayar.secildi(_ksSecim[alanId]);
  }

  async function ara(q){
    var benim = ++sira;
    try{
      var r = await sb.from('profiller')
        .select('id,kullanici_adi,elo,yasakli')
        .ilike('kullanici_adi','%'+q+'%')
        .order('kullanici_adi').limit(8);
      if(benim !== sira) return;          // geç gelen eski istek — yoksay
      if(r.error) throw r.error;
      ciz(r.data || []);
    }catch(e){
      if(benim !== sira) return;
      ipucu('arama hatası: '+((e&&e.message)||e));
    }
  }

  giris.addEventListener('input', function(){
    clearTimeout(zaman);
    var q = giris.value.trim();
    if(q.length < 3){                     // ölçek koruması: sorgu YOK
      if(q.length) ipucu('aramak için en az 3 harf yaz'); else kapat();
      return;
    }
    ipucu('aranıyor…');
    zaman = setTimeout(function(){ ara(q); }, 250);
  });

  giris.addEventListener('focus', function(){
    if(giris.value.trim().length >= 3 && satirlar.length) liste.style.display='block';
  });

  // odak başka alana geçince liste kapansın (altındaki alanları örtmesin).
  // Satır seçimi mousedown+preventDefault ile yapıldığı için blur tetiklenmez.
  giris.addEventListener('blur', function(){ setTimeout(kapat, 120); });

  giris.addEventListener('keydown', function(ev){
    if(ev.key === 'Escape'){ kapat(); return; }
    if(liste.style.display !== 'block' || !satirlar.length) return;
    if(ev.key === 'ArrowDown' || ev.key === 'ArrowUp'){
      ev.preventDefault();
      imlec = (imlec + (ev.key==='ArrowDown' ? 1 : satirlar.length-1)) % satirlar.length;
      var hepsi = liste.querySelectorAll('.ks-sat');
      for(var i=0;i<hepsi.length;i++) hepsi[i].classList.toggle('aktif', i===imlec);
      var akt = liste.querySelector('.ks-sat.aktif');
      if(akt) akt.scrollIntoView({block:'nearest'});
    } else if(ev.key === 'Enter'){
      ev.preventDefault();
      if(imlec >= 0) sec(satirlar[imlec]);
    }
  });

  liste.addEventListener('mousedown', function(ev){
    var s = ev.target.closest ? ev.target.closest('.ks-sat') : null;
    if(!s) return;
    ev.preventDefault();
    sec(satirlar[+s.dataset.i]);
  });

  document.addEventListener('click', function(ev){ if(!kok.contains(ev.target)) kapat(); });
  return kok;
}

function secilenKullanici(alanId){ return _ksSecim[alanId] || null; }

function seciciTemizle(alanId){
  delete _ksSecim[alanId];
  var kok = document.getElementById(alanId); if(!kok) return;
  var giris = kok.querySelector('.ks-giris');
  var secili = kok.querySelector('.ks-secili');
  var liste  = kok.querySelector('.ks-liste');
  if(giris){ giris.value=''; giris.style.display=''; }
  if(secili){ secili.style.display='none'; secili.innerHTML=''; }
  if(liste){ liste.style.display='none'; liste.innerHTML=''; }
}
