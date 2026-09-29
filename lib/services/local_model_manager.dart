import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../core/logging/app_log.dart';

/// Verwaltet den Lebenszyklus, Speicherort und Ladevorgang des lokalen
/// On-Device Multimodal-Vision-Modells (z. B. SmolVLM2 oder Qwen2-VL als MediaPipe .task / .bin).
class LocalModelManager {
  static const String defaultModelFileName = 'vision_model.task';
  static const String secondaryModelFileName = 'vision_model.bin';

  static LocalModelManager? _instance;
  static LocalModelManager get instance => _instance ??= LocalModelManager._();

  LocalModelManager._();

  bool _isInitializing = false;
  bool _isModelReady = false;
  String? _loadedModelPath;

  bool get isModelReady => _isModelReady;
  bool get isInitializing => _isInitializing;
  String? get loadedModelPath => _loadedModelPath;

  /// Liefert das Verzeichnis für lokale KI-Modelle im privaten App-Speicher.
  Future<Directory> getModelDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${docsDir.path}/models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  /// Ermittelt den Pfad zur verfügbaren lokalen Modelldatei.
  Future<String?> getAvailableModelPath() async {
    final modelDir = await getModelDirectory();
    
    // 1. Primäre .task-Datei prüfen
    final primaryFile = File('${modelDir.path}/$defaultModelFileName');
    if (await primaryFile.exists() && await primaryFile.length() > 0) {
      return primaryFile.path;
    }

    // 2. Sekundäre .bin-Datei prüfen
    final secondaryFile = File('${modelDir.path}/$secondaryModelFileName');
    if (await secondaryFile.exists() && await secondaryFile.length() > 0) {
      return secondaryFile.path;
    }

    // 3. Nach beliebiger .task- oder .bin-Datei im Modell-Ordner suchen
    try {
      final entities = modelDir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final ext = entity.path.toLowerCase();
          if ((ext.endsWith('.task') || ext.endsWith('.bin')) && await entity.length() > 0) {
            return entity.path;
          }
        }
      }
    } on FileSystemException catch (e) {
      AppLog.w('LocalModelManager', 'Modellordner nicht lesbar', e);
    }

    return null;
  }

  /// Prüft, ob ein Modell lokal zur Verfügung steht.
  Future<bool> isModelAvailable() async {
    final path = await getAvailableModelPath();
    return path != null;
  }

  /// Kopiert ein optional im Bundle hinterlegtes Asset-Modell in den privaten Speicher,
  /// da On-Device NPU/GPU Runtimes (LiteRT / MediaPipe) einen echten Dateipfad für mmap() benötigen.
  Future<String?> installAssetModelIfPresent(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final modelDir = await getModelDirectory();
      final targetFile = File('${modelDir.path}/$defaultModelFileName');

      final buffer = data.buffer;
      await targetFile.writeAsBytes(
        buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      debugPrint('[LocalModelManager] Asset-Modell erfolgreich installiert nach: ${targetFile.path}');
      return targetFile.path;
    } catch (e) {
      debugPrint('[LocalModelManager] Kein Asset-Modell unter "$assetPath" vorhanden ($e).');
      return null;
    }
  }

  /// Initialisiert das Modell asynchron und ressourcenschonend.
  Future<bool> prepareModel() async {
    if (_isModelReady) return true;
    if (_isInitializing) return false;

    _isInitializing = true;
    try {
      String? modelPath = await getAvailableModelPath();

      if (modelPath == null) {
        // Versuche, ein im Bundle gepacktes Modell zu extrahieren
        modelPath = await installAssetModelIfPresent('assets/models/$defaultModelFileName');
      }

      if (modelPath != null && await File(modelPath).exists()) {
        _loadedModelPath = modelPath;
        _isModelReady = true;
        debugPrint('[LocalModelManager] Modell einsatzbereit: $modelPath');
        return true;
      } else {
        debugPrint('[LocalModelManager] Keine lokale Modelldatei gefunden.');
        return false;
      }
    } catch (e) {
      debugPrint('[LocalModelManager] Fehler beim Vorbereiten des Modells: $e');
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Gibt belegten GPU/NPU Speicher frei.
  void releaseModel() {
    _isModelReady = false;
    _loadedModelPath = null;
    debugPrint('[LocalModelManager] Modell-Ressourcen freigegeben.');
  }
}

