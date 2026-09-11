import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/hive_service.dart';

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(HiveService.getLocale());

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await HiveService.saveLocale(locale);
  }

  void setLanguageCode(String code) {
    setLocale(Locale(code));
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

