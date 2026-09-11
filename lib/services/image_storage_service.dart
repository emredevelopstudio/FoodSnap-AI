import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ImageStorageService {
  /// Liefert das persistente Verzeichnis für Mahlzeiten-Bilder im Anwendungs-Dokumentenverzeichnis
  static Future<Directory> getImagesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/meal_images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  /// Speichert ein Bild dauerhaft und update-sicher im getApplicationDocumentsDirectory() Unterordner
  static Future<String> saveImagePermanently(String sourcePath) async {
    final imagesDir = await getImagesDirectory();
    final fileName = 'meal_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final targetFile = File('${imagesDir.path}/$fileName');
    final sourceFile = File(sourcePath);
    await sourceFile.copy(targetFile.path);
    return targetFile.path;
  }

  /// Prüft synchron, ob die Bilddatei auf dem Dateisystem existiert
  static bool imageExists(String? path) {
    if (path == null || path.isEmpty) return false;
    return File(path).existsSync();
  }

  /// Löscht ein gespeichertes Bild sicher vom Dateisystem
  static Future<void> deleteImage(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }
}


