import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/landing_pages.dart';
import 'pages/beranda_pages.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/verify_email_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const RambuIDApp());
}

class RambuIDApp extends StatefulWidget {
  const RambuIDApp({super.key});

  @override
  State<RambuIDApp> createState() => _RambuIDAppState();
}

class _RambuIDAppState extends State<RambuIDApp> {
  Key get _appKey => ValueKey(_themeMode.toString());
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('themeMode') ?? 'system';

    setState(() {
      _themeMode = _parseThemeMode(themeString);
    });
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = mode.name; // 'light', 'dark', 'system'
    await prefs.setString('themeMode', themeString);
  }

  ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void _toggleThemeMode(bool isDark) async {
    final newMode = isDark ? ThemeMode.dark : ThemeMode.light;
    debugPrint("🌗 Toggle Theme Dipanggil! New Mode: $newMode");

    setState(() {
      _themeMode = newMode;
    });

    // Delay sedikit agar _themeMode sempat rebuild
    await Future.delayed(const Duration(milliseconds: 50));
    await _saveTheme(newMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: _appKey,
      title: 'RambuID',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        textTheme: GoogleFonts.oswaldTextTheme(),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.oswaldTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('id', 'ID'), Locale('en', '')],
      initialRoute: '/',
      routes: {
        '/': (context) => LandingPage(
          currentThemeMode: _themeMode,
          onToggleTheme: _toggleThemeMode,
        ),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/verify-email': (context) => const VerifyEmailPage(),
        '/home': (context) => BerandaPage(
          currentThemeMode: _themeMode,
          onToggleTheme: _toggleThemeMode,
        ),
      },
    );
  }
}
