import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'l10n/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'services/hive_service.dart';
import 'services/purchase_service.dart';
import 'services/ad_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'views/responsive_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  await AdService.init();
  await initializeDateFormatting('de_DE', null);
  await Hive.initFlutter();
  await HiveService.init();

  // RevenueCat Service vor App-Start initialisieren
  await PurchaseService.init();

  try {
    await dotenv.load(fileName: ".env");
    // ignore: avoid_print
    print('>>> CHECK KEY: ${dotenv.env['GEMINI_API_KEY'] != null ? "KEY VORHANDEN" : "KEY IST NULL/LEER"}');
  } catch (e) {
    // ignore: avoid_print
    print('>>> CHECK KEY: KEY IST NULL/LEER ($e)');
    debugPrint('Hinweis: .env nicht geladen ($e). API-Keys können via --dart-define bereitgestellt werden.');
  }

  runApp(
    const ProviderScope(
      child: FoodSnapApp(),
    ),
  );
}

class FoodSnapApp extends ConsumerWidget {
  const FoodSnapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const seedColor = Color(0xFF10B981); // Fresh Emerald Green
    final currentThemeMode = ref.watch(themeModeProvider);
    final currentLocale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'FoodSnap AI',
      debugShowCheckedModeBanner: false,
      themeMode: currentThemeMode,
      locale: currentLocale,
      supportedLocales: const [
        Locale('de'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E1E),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFF121212),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      home: const ResponsiveScaffold(),
    );
  }
}   