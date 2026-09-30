import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../l10n/app_localizations.dart';
import '../services/barcode_nutrition_service.dart';
import '../views/manual_entry_view.dart';
import '../views/scan_review_view.dart';
import '../core/logging/app_log.dart';

class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  ConsumerState<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> {
  late final MobileScannerController _controller;
  bool _isProcessing = false;
  bool _isStopping = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeDetected(String rawCode) async {
    if (_isProcessing || _isStopping || !mounted) return;
    _isStopping = true;

    // 1. Controller sofort stoppen beim ersten Treffer
    try {
      await _controller.stop();
    } catch (e) {
      AppLog.w('BarcodeScanner', 'Controller-Stop fehlgeschlagen', e);
      // Ignoriere Controller-Stop-Fehler
    }

    if (!mounted) return;

    // Erst nach dem Stoppen _isProcessing aktivieren (Ladeanzeige)
    setState(() {
      _isProcessing = true;
      _isStopping = false;
    });

    try {
      final productData = await BarcodeNutritionService.fetchProductByBarcode(
        rawCode,
      );

      if (!mounted) return;

      if (productData != null) {
        final meal =
            BarcodeNutritionService.createMealEntryFromBarcodeData(productData);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (ctx) => ScanReviewView(initialMeal: meal),
          ),
        );
        return;
      } else {
        _showErrorSnackBar(context.l10n.tr('Produkt nicht in Datenbank gefunden', 'Product not found in database'));
      }
    } on BarcodeNetworkException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(context.l10n.tr(e.message, 'Slow network, please enter manually'));
    } catch (e, stack) {
      if (!mounted) return;
      debugPrint('[BarcodeScannerScreen] Unerwarteter Fehler: $e\n$stack');
      _showErrorSnackBar(context.l10n.tr('Produkt nicht in Datenbank gefunden', 'Product not found in database'));
    } finally {
      // State-Reset bei Fehler / nicht gefundenem Produkt:
      // Scanner wieder reaktivieren, Nutzer bleibt nie im Ladekreis stecken
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isStopping = false;
        });

        try {
          await _controller.start();
        } catch (e, st) {
          AppLog.e('BarcodeScanner', 'Kamera-Neustart fehlgeschlagen', e, st);
        }
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: context.l10n.tr('Manuell eintragen', 'Add manually'),
          textColor: Colors.white,
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (ctx) => const ManualEntryView(),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          context.l10n.tr('Barcode scannen', 'Scan barcode'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isTorchOn ? Colors.amber : Colors.white,
            ),
            tooltip: context.l10n.tr('Taschenlampe umschalten', 'Toggle flashlight'),
            onPressed: () async {
              try {
                await _controller.toggleTorch();
                setState(() {
                  _isTorchOn = !_isTorchOn;
                });
              } catch (e) {
                AppLog.w('BarcodeScanner', 'Taschenlampe nicht verfügbar', e);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Kamera-Scanner
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_isProcessing || _isStopping) return;
              for (final barcode in capture.barcodes) {
                final code = barcode.rawValue?.trim();
                if (code != null &&
                    code.length >= 8 &&
                    RegExp(r'^\d+$').hasMatch(code)) {
                  _handleBarcodeDetected(code);
                  break;
                }
              }
            },
          ),

          // Sucher-Overlay
          _buildScannerOverlay(context),

          // Lade-Overlay während Abfrage
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Card(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          context.l10n.tr('Produktdaten werden geladen...', 'Loading product data...'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.l10n.tr('Open Food Facts Datenbank', 'Open Food Facts database'),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final scanAreaWidth = (screenSize.width * 0.75).clamp(240.0, 320.0);
    final scanAreaHeight = (scanAreaWidth * 0.65).clamp(160.0, 220.0);

    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.qr_code_scanner, color: Color(0xFF10B981), size: 18),
              const SizedBox(width: 8),
              Text(
                context.l10n.tr('Barcode im Rahmen platzieren', 'Place the barcode inside the frame'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),

        // Zentraler Sucher-Rahmen
        Center(
          child: Container(
            width: scanAreaWidth,
            height: scanAreaHeight,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF10B981), width: 2.5),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),

        const Spacer(),

        // Manuell eintragen Shortcut unten
        Padding(
          padding: const EdgeInsets.only(bottom: 36, left: 24, right: 24),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
            label: Text(
              context.l10n.tr('Manuell eintragen', 'Add manually'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white38),
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (ctx) => const ManualEntryView(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
