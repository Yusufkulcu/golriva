/// Turkce-duyarsiz arama normalizasyonu — HTML oyunlardaki norm() ile birebir.
/// Dart'in toLowerCase'i Turkce I/i kurallarini BILMEZ; elle esleriz.
String trNorm(String s) {
  final sb = StringBuffer();
  for (final rune in s.runes) {
    var ch = String.fromCharCode(rune);
    switch (ch) {
      case 'I':
      case 'ı':
      case 'İ':
      case 'i':
        ch = 'i';
        break;
      default:
        ch = ch.toLowerCase();
    }
    sb.write(ch);
  }
  // aksan temizligi (NFD ayristirmasi yerine dogrudan esleme tablosu)
  const map = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'ă': 'a', 'ą': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ě': 'e', 'ę': 'e', 'ė': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'į': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o', 'ő': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ů': 'u', 'ű': 'u',
    'ç': 'c', 'ć': 'c', 'č': 'c',
    'ş': 's', 'ś': 's', 'š': 's',
    'ğ': 'g', 'ñ': 'n', 'ń': 'n', 'ň': 'n',
    'ý': 'y', 'ž': 'z', 'ź': 'z', 'ż': 'z',
    'ł': 'l', 'đ': 'd', 'ð': 'd', 'ţ': 't', 'ț': 't', 'ř': 'r',
    'æ': 'ae', 'œ': 'oe', 'ß': 'ss',
  };
  final out = StringBuffer();
  for (final rune in sb.toString().runes) {
    final ch = String.fromCharCode(rune);
    out.write(map[ch] ?? ch);
  }
  return out.toString();
}
