import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import '../core/logging/app_log.dart';
import '../l10n/app_localizations.dart';
import '../models/meal_entry.dart';
import '../providers/meal_provider.dart';
import '../services/image_storage_service.dart';

/// Menü beim Tippen auf ein Mahlzeiten-Foto: in Galerie speichern / ersetzen.
class MealPhotoActions {
  MealPhotoActions._();

  static Future<void> show(BuildContext context, MealEntry meal) {
    final l10n = context.l10n;
    final path = meal.localImagePath;
    final hasImage = path != null && path.isNotEmpty && File(path).existsSync();

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasImage)
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: Text(l10n.tr('Bild in Galerie speichern', 'Save photo to gallery')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _saveToGallery(context, path);
                },
              ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(hasImage
                  ? l10n.tr('Bild ersetzen (Kamera)', 'Replace photo (camera)')
                  : l10n.tr('Foto aufnehmen', 'Take photo')),
              onTap: () {
                Navigator.pop(sheetContext);
                _replace(context, meal, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(hasImage
                  ? l10n.tr('Bild ersetzen (Galerie)', 'Replace photo (gallery)')
                  : l10n.tr('Foto aus Galerie wählen', 'Choose photo from gallery')),
              onTap: () {
                Navigator.pop(sheetContext);
                _replace(context, meal, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _saveToGallery(BuildContext context, String path) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }
      await Gal.putImage(path, album: 'FoodSnap AI');
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.tr('Bild in der Galerie gespeichert', 'Photo saved to gallery')),
      ));
    } on GalException catch (e) {
      AppLog.w('MealPhoto', 'Galerie-Export fehlgeschlagen: ${e.type}');
      messenger.showSnackBar(SnackBar(
        content: Text(e.type == GalExceptionType.accessDenied
            ? l10n.tr('Kein Zugriff auf die Galerie erlaubt.', 'Gallery access was denied.')
            : l10n.tr('Bild konnte nicht gespeichert werden.', 'Could not save the photo.')),
      ));
    }
  }

  static Future<void> _replace(
      BuildContext context, MealEntry meal, ImageSource source) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);

    final picked = await ImagePicker().pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.rear,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (picked == null) return;

    try {
      final newPath = await ImageStorageService.saveImagePermanently(picked.path);
      await container
          .read(mealListProvider.notifier)
          .updateMeal(meal.copyWith(localImagePath: newPath));
      // Altes Bild erst nach erfolgreichem Update löschen
      final oldPath = meal.localImagePath;
      if (oldPath != null && oldPath != newPath) {
        await ImageStorageService.deleteImage(oldPath);
      }
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.tr('Bild aktualisiert', 'Photo updated')),
      ));
    } catch (e, st) {
      AppLog.e('MealPhoto', 'Bild ersetzen fehlgeschlagen', e, st);
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.tr('Bild konnte nicht ersetzt werden.', 'Could not replace the photo.')),
      ));
    }
  }
}
