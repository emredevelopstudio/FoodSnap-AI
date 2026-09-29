# Lokale On-Device Multimodal-Vision-Modelle

In diesem Verzeichnis können quantisierte Multimodal-Vision-Modelle für FoodSnap AI abgelegt werden (z. B. SmolVLM2 500M/2B oder Qwen2-VL 2B im MediaPipe / LiteRT-LM Format `.task` oder `.bin`).

- Standard-Dateiname: `vision_model.task` oder `vision_model.bin`
- Speicherort auf dem Smartphone: `${applicationDocumentsDirectory}/models/vision_model.task`
- Der `LocalModelManager` prüft beim Start automatisch das Dokumentenverzeichnis und das Asset-Verzeichnis.

