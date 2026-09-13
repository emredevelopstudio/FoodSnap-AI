import 'dart:typed_data';

/// Prefer the actual encoding over the filename supplied by the picker.
String detectImageMimeType(Uint8List bytes, {String? filePath}) {
  if (bytes.isEmpty) {
    throw const FormatException('Die ausgewählte Bilddatei ist leer.');
  }
  bool startsWith(List<int> signature) =>
      bytes.length >= signature.length &&
      List.generate(signature.length, (i) => bytes[i] == signature[i])
          .every((matches) => matches);

  if (startsWith([0xff, 0xd8, 0xff])) return 'image/jpeg';
  if (startsWith([0x89, 0x50, 0x4e, 0x47, 13, 10, 26, 10])) {
    return 'image/png';
  }
  if (bytes.length >= 12) {
    final container = String.fromCharCodes(bytes.sublist(0, 4));
    final format = String.fromCharCodes(bytes.sublist(8, 12));
    if (container == 'RIFF' && format == 'WEBP') return 'image/webp';
    if (String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp') {
      if (['heic', 'heix', 'hevc', 'hevx'].contains(format)) {
        return 'image/heic';
      }
      if (['mif1', 'msf1'].contains(format)) return 'image/heif';
    }
  }
  final extension = filePath?.split('.').last.toLowerCase();
  const types = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'heif': 'image/heif',
  };
  final type = types[extension];
  if (type != null) return type;
  throw const FormatException(
      'Nicht unterstütztes Bildformat. Bitte JPEG, PNG, WebP oder HEIF verwenden.');
}
