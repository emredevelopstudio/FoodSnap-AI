package com.foodsnap.ai

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.tensorflow.lite.DataType
import org.tensorflow.lite.Interpreter
import java.io.File
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.foodsnap.ai/vision"
    private val TAG = "FoodSnapVision"

    private var tfliteInterpreter: Interpreter? = null
    private var labelsList: List<String> = emptyList()
    private var loadedModelPath: String? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "classifyImage" -> {
                    val imagePath = call.argument<String>("imagePath")
                    val threshold = (call.argument<Number>("threshold")?.toFloat()) ?: 0.10f
                    val maxResults = call.argument<Int>("maxResults") ?: 5

                    Log.d(TAG, "MethodCall 'classifyImage' empfangen. imagePath=$imagePath, threshold=$threshold, maxResults=$maxResults")
                    if (imagePath.isNullOrBlank()) {
                        Log.e(TAG, "classifyImage fehlgeschlagen: imagePath ist null oder leer.")
                        result.error("INVALID_ARGUMENT", "Pfad 'imagePath' darf nicht leer sein.", null)
                        return@setMethodCallHandler
                    }

                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val file = File(imagePath)
                            if (!file.exists()) {
                                Log.e(TAG, "Bilddatei nicht gefunden unter: $imagePath")
                                withContext(Dispatchers.Main) {
                                    result.error("FILE_NOT_FOUND", "Bilddatei existiert nicht: $imagePath", null)
                                }
                                return@launch
                            }

                            val candidates = runInferenceOnImagePath(imagePath, threshold, maxResults)
                            val resultsList = candidates.map {
                                mapOf(
                                    "label" to it.label,
                                    "confidence" to it.confidence.toDouble()
                                )
                            }
                            Log.i(TAG, "classifyImage erfolgreich: ${resultsList.size} Treffer zurückgegeben.")
                            withContext(Dispatchers.Main) {
                                result.success(resultsList)
                            }
                        } catch (e: OutOfMemoryError) {
                            Log.e(TAG, "OOM während TFLite-Inferenz: ${e.message}", e)
                            System.gc()
                            withContext(Dispatchers.Main) {
                                result.error("OOM_ERROR", "Nicht genügend Speicher für Bildanalyse.", null)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "SCHWERER FEHLER bei classifyImage: ${e.message}", e)
                            withContext(Dispatchers.Main) {
                                result.error("CLASSIFICATION_ERROR", e.localizedMessage ?: "Inferenzfehler", null)
                            }
                        }
                    }
                }

                "analyzeFoodLocal" -> {
                    val imagePath = call.argument<String>("imagePath")
                    Log.d(TAG, "MethodCall 'analyzeFoodLocal' empfangen. imagePath=$imagePath")
                    if (imagePath.isNullOrBlank()) {
                        Log.e(TAG, "analyzeFoodLocal fehlgeschlagen: imagePath ist null oder leer.")
                        result.error("INVALID_ARGUMENT", "Pfad 'imagePath' darf nicht leer sein.", null)
                        return@setMethodCallHandler
                    }

                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val file = File(imagePath)
                            if (!file.exists()) {
                                Log.e(TAG, "Bilddatei nicht gefunden unter: $imagePath")
                                withContext(Dispatchers.Main) {
                                    result.error("FILE_NOT_FOUND", "Bilddatei existiert nicht: $imagePath", null)
                                }
                                return@launch
                            }

                            val candidates = runInferenceOnImagePath(imagePath, 0.01f, 5)
                            val detectedList = candidates.map {
                                mapOf(
                                    "label" to it.label,
                                    "confidence" to it.confidence.toDouble(),
                                    "displayName" to it.label
                                )
                            }

                            val top = detectedList.firstOrNull() ?: mapOf(
                                "label" to "unrecognized",
                                "confidence" to 0.0,
                                "displayName" to "Unbekannt"
                            )

                            val response = mapOf(
                                "label" to (top["label"] ?: "unrecognized"),
                                "confidence" to (top["confidence"] ?: 0.0),
                                "displayName" to (top["displayName"] ?: "Unbekannt"),
                                "categories" to detectedList
                            )

                            Log.d(TAG, "analyzeFoodLocal ERFOLGREICH! Top: '${top["label"]}' (${top["confidence"]}).")
                            withContext(Dispatchers.Main) {
                                result.success(response)
                            }
                        } catch (e: OutOfMemoryError) {
                            Log.e(TAG, "OOM während analyzeFoodLocal: ${e.message}", e)
                            System.gc()
                            withContext(Dispatchers.Main) {
                                result.error("OOM_ERROR", "Nicht genügend Speicher für Bildanalyse.", null)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "SCHWERER FEHLER bei analyzeFoodLocal: ${e.message}", e)
                            withContext(Dispatchers.Main) {
                                result.error("CLASSIFICATION_ERROR", e.localizedMessage ?: "Inferenzfehler", null)
                            }
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    data class Detection(val label: String, val confidence: Float)

    @Synchronized
    private fun getOrInitTFLite(): Interpreter? {
        if (tfliteInterpreter != null) {
            return tfliteInterpreter
        }

        val buffer = loadModelMapped()
        if (buffer == null) {
            Log.e(TAG, "Modell konnte aus keinem Pfad geladen werden.")
            return null
        }

        return try {
            val options = Interpreter.Options().apply {
                setNumThreads(4)
            }
            tfliteInterpreter = Interpreter(buffer, options)
            Log.i(TAG, "TensorFlow Lite Interpreter erfolgreich initialisiert ($loadedModelPath).")
            tfliteInterpreter
        } catch (e: Exception) {
            Log.e(TAG, "Fehler beim Erstellen des TFLite Interpreters: ${e.message}", e)
            null
        }
    }

    @Synchronized
    private fun getOrInitLabels(): List<String> {
        if (labelsList.isNotEmpty()) {
            return labelsList
        }

        val candidates = listOf(
            "flutter_assets/assets/models/food_labels.txt",
            "assets/models/food_labels.txt",
            "models/food_labels.txt",
            "flutter_assets/assets/models/labels.txt",
            "assets/models/labels.txt",
            "models/labels.txt"
        )

        for (candidate in candidates) {
            try {
                assets.open(candidate).bufferedReader().useLines { lines ->
                    val list = lines.map { it.trim() }.filter { it.isNotEmpty() }.toList()
                    if (list.isNotEmpty()) {
                        labelsList = list
                        Log.i(TAG, "Erfolgreich ${labelsList.size} Food-Labels geladen aus: $candidate")
                        return labelsList
                    }
                }
            } catch (e: Exception) {
                Log.d(TAG, "Label-Kandidat '$candidate' nicht ladbar: ${e.message}")
            }
        }

        Log.w(TAG, "Keine separate Label-Datei gefunden.")
        return emptyList()
    }

    private fun loadModelMapped(): ByteBuffer? {
        val candidates = listOf(
            "flutter_assets/assets/models/food_classifier_quant.tflite",
            "assets/models/food_classifier_quant.tflite",
            "models/food_classifier_quant.tflite",
            "flutter_assets/assets/models/food_classifier.tflite",
            "assets/models/food_classifier.tflite",
            "models/food_classifier.tflite"
        )

        for (candidate in candidates) {
            try {
                val fileDescriptor = assets.openFd(candidate)
                val inputStream = FileInputStream(fileDescriptor.fileDescriptor)
                val fileChannel = inputStream.channel
                val startOffset = fileDescriptor.startOffset
                val declaredLength = fileDescriptor.declaredLength
                val buffer = fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength)
                loadedModelPath = candidate
                Log.i(TAG, "TFLite Modell via AssetManager Memory-Map geladen: $candidate ($declaredLength Bytes)")
                return buffer
            } catch (e: Exception) {
                Log.d(TAG, "Memory-Map via openFd für '$candidate' nicht verfügbar (${e.message}), prüfe Fallbacks...")
            }
        }

        for (candidate in candidates) {
            try {
                assets.open(candidate).use { inputStream ->
                    val bytes = inputStream.readBytes()
                    val buffer = ByteBuffer.allocateDirect(bytes.size).apply {
                        order(ByteOrder.nativeOrder())
                        put(bytes)
                        rewind()
                    }
                    loadedModelPath = candidate
                    Log.i(TAG, "TFLite Flatbuffer via Stream geladen aus: $candidate (${bytes.size} Bytes)")
                    return buffer
                }
            } catch (e: Exception) {
                Log.d(TAG, "Stream-Kandidat '$candidate' nicht ladbar: ${e.message}")
            }
        }

        val fileCandidates = listOf(
            File(context.filesDir, "models/food_classifier_quant.tflite"),
            File(context.filesDir, "models/food_classifier.tflite"),
            File(context.cacheDir, "models/food_classifier_quant.tflite"),
            File(context.cacheDir, "models/food_classifier.tflite")
        )

        for (file in fileCandidates) {
            if (file.exists() && file.length() > 0) {
                try {
                    val inputStream = FileInputStream(file)
                    val fileChannel = inputStream.channel
                    val buffer = fileChannel.map(FileChannel.MapMode.READ_ONLY, 0, file.length())
                    loadedModelPath = file.absolutePath
                    Log.i(TAG, "TFLite Modell gemappt aus Datei: ${file.absolutePath} (${file.length()} Bytes)")
                    return buffer
                } catch (e: Exception) {
                    Log.d(TAG, "Datei-Mapping für '${file.absolutePath}' fehlgeschlagen: ${e.message}")
                }
            }
        }

        return null
    }

    private fun decodeSampledBitmap(imagePath: String, targetDim: Int): Bitmap? {
        val boundsOptions = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }
        BitmapFactory.decodeFile(imagePath, boundsOptions)
        val origW = boundsOptions.outWidth
        val origH = boundsOptions.outHeight
        if (origW <= 0 || origH <= 0) return null

        var sampleSize = 1
        val maxDim = maxOf(origW, origH)
        while ((maxDim / sampleSize) > targetDim * 2) {
            sampleSize *= 2
        }

        val decodeOptions = BitmapFactory.Options().apply {
            inSampleSize = sampleSize
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        return BitmapFactory.decodeFile(imagePath, decodeOptions)
    }

    private fun centerCropAndScale(source: Bitmap, targetWidth: Int, targetHeight: Int): Bitmap {
        val size = minOf(source.width, source.height)
        val x = (source.width - size) / 2
        val y = (source.height - size) / 2

        val cropped = if (source.width == size && source.height == size) {
            source
        } else {
            Bitmap.createBitmap(source, x, y, size, size)
        }

        val scaled = if (cropped.width == targetWidth && cropped.height == targetHeight) {
            cropped
        } else {
            Bitmap.createScaledBitmap(cropped, targetWidth, targetHeight, true)
        }

        if (cropped != source && cropped != scaled) {
            cropped.recycle()
        }
        if (source != scaled) {
            source.recycle()
        }

        return scaled
    }

    private fun runInferenceOnImagePath(imagePath: String, threshold: Float, maxResults: Int): List<Detection> {
        val interpreter = getOrInitTFLite() ?: throw IllegalStateException("LiteRT / TFLite Interpreter nicht verfügbar.")
        val labels = getOrInitLabels()

        val inputTensor = interpreter.getInputTensor(0)
        val outputTensor = interpreter.getOutputTensor(0)

        val inputShape = inputTensor.shape()
        val inputHeight = if (inputShape.size >= 3) inputShape[1] else 224
        val inputWidth = if (inputShape.size >= 3) inputShape[2] else 224

        val sampledBitmap = decodeSampledBitmap(imagePath, maxOf(inputWidth, inputHeight))
            ?: throw IllegalArgumentException("Bild konnte nicht geladen werden: $imagePath")

        val preparedBitmap = centerCropAndScale(sampledBitmap, inputWidth, inputHeight)

        val isInputFloat = inputTensor.dataType() == DataType.FLOAT32
        val isInputInt8 = inputTensor.dataType() == DataType.INT8
        val bytesPerChannel = if (isInputFloat) 4 else 1

        val inputBuffer = ByteBuffer.allocateDirect(1 * inputHeight * inputWidth * 3 * bytesPerChannel).apply {
            order(ByteOrder.nativeOrder())
        }

        val intValues = IntArray(inputWidth * inputHeight)
        try {
            preparedBitmap.getPixels(intValues, 0, inputWidth, 0, 0, inputWidth, inputHeight)
        } finally {
            preparedBitmap.recycle()
        }

        for (pixelValue in intValues) {
            val r = ((pixelValue shr 16) and 0xFF)
            val g = ((pixelValue shr 8) and 0xFF)
            val b = (pixelValue and 0xFF)
            when {
                isInputFloat -> {
                    inputBuffer.putFloat(r / 255.0f)
                    inputBuffer.putFloat(g / 255.0f)
                    inputBuffer.putFloat(b / 255.0f)
                }
                isInputInt8 -> {
                    inputBuffer.put((r - 128).toByte())
                    inputBuffer.put((g - 128).toByte())
                    inputBuffer.put((b - 128).toByte())
                }
                else -> { // UINT8
                    inputBuffer.put(r.toByte())
                    inputBuffer.put(g.toByte())
                    inputBuffer.put(b.toByte())
                }
            }
        }
        inputBuffer.rewind()

        val outputShape = outputTensor.shape()
        val numClasses = if (outputShape.size >= 2) outputShape[1] else (if (labels.isNotEmpty()) labels.size else 2024)
        val isOutputFloat = outputTensor.dataType() == DataType.FLOAT32
        val isOutputInt8 = outputTensor.dataType() == DataType.INT8

        val probabilities: FloatArray = when {
            isOutputFloat -> {
                val outputArray = Array(1) { FloatArray(numClasses) }
                interpreter.run(inputBuffer, outputArray)
                outputArray[0]
            }
            isOutputInt8 -> {
                val outputArray = Array(1) { ByteArray(numClasses) }
                interpreter.run(inputBuffer, outputArray)
                val quantParams = outputTensor.quantizationParams()
                val scale = quantParams.scale
                val zeroPoint = quantParams.zeroPoint
                FloatArray(numClasses) { i ->
                    val byteVal = outputArray[0][i].toInt()
                    if (scale > 0f) {
                        ((byteVal - zeroPoint) * scale).coerceIn(0f, 1f)
                    } else {
                        ((byteVal + 128) and 0xFF) / 255.0f
                    }
                }
            }
            else -> { // UINT8
                val outputArray = Array(1) { ByteArray(numClasses) }
                interpreter.run(inputBuffer, outputArray)
                val quantParams = outputTensor.quantizationParams()
                val scale = quantParams.scale
                val zeroPoint = quantParams.zeroPoint
                FloatArray(numClasses) { i ->
                    val raw = outputArray[0][i].toInt() and 0xFF
                    if (scale > 0f) {
                        ((raw - zeroPoint) * scale).coerceIn(0f, 1f)
                    } else {
                        raw / 255.0f
                    }
                }
            }
        }

        val sortedIndices = probabilities.indices.sortedByDescending { probabilities[it] }

        // Top 5 Roh-Ergebnisse mit Label und Konfidenz via Log.d ausgeben
        Log.d(TAG, "=== LiteRT Inferenz Top-5 Roh-Ergebnisse (threshold=$threshold, maxResults=$maxResults) ===")
        for (i in 0 until minOf(5, sortedIndices.size)) {
            val idx = sortedIndices[i]
            val rawLabel = if (idx in labels.indices) labels[idx] else "Index $idx"
            val rawConfidence = probabilities[idx]
            Log.d(TAG, "  Top-$i: Label='$rawLabel', Konfidenz=$rawConfidence (Index=$idx)")
        }

        val detectedList = mutableListOf<Detection>()
        for (idx in sortedIndices) {
            if (idx in labels.indices) {
                val rawLabel = labels[idx].trim()
                if (rawLabel.isNotEmpty() && rawLabel != "__background__" && !rawLabel.startsWith("/g/")) {
                    val score = probabilities[idx]
                    if (score >= threshold) {
                        detectedList.add(Detection(rawLabel, score))
                        if (detectedList.size >= maxResults) break
                    }
                }
            }
        }

        // Falls kein Treffer über threshold liegt, aber valide Food-Labels existieren:
        // Top-1 Food-Kandidat beibehalten, damit nicht versehentlich alle Ergebnisse verworfen werden
        if (detectedList.isEmpty()) {
            for (idx in sortedIndices) {
                if (idx in labels.indices) {
                    val rawLabel = labels[idx].trim()
                    if (rawLabel.isNotEmpty() && rawLabel != "__background__" && !rawLabel.startsWith("/g/")) {
                        Log.d(TAG, "Fallback: Kein Treffer über threshold $threshold. Nehme Top-1: '$rawLabel' (Konfidenz: ${probabilities[idx]})")
                        detectedList.add(Detection(rawLabel, probabilities[idx]))
                        break
                    }
                }
            }
        }

        return detectedList
    }

    override fun onDestroy() {
        super.onDestroy()
        tfliteInterpreter?.close()
        tfliteInterpreter = null
    }
}
