# GOLRIVA — R8/ProGuard koruma kurallari (release derleme)
# Belirti: debug calisir, release ACILISTA "surekli duruyor" ile coker.
# Neden: R8, eklentilerin calisma aninda ihtiyac duydugu siniflari sokuyor.

# Google Mobile Ads (AdMob) — acilista kendini baslatir, EN kritik koruma
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-keep class io.flutter.plugins.googlemobileads.** { *; }

# Play Billing (uygulama ici satin alma)
-keep class com.android.billingclient.** { *; }

# Flutter gomulu motor girisleri
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Play Core (Flutter ertelenmis bilesen referanslari — kullanilmiyor, sustur)
-dontwarn com.google.android.play.core.**
