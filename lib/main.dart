import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data.dart';
import 'screens/home.dart';
import 'screens/login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  try {
    await Supabase.initialize(
      url: dotenv.get('SUPABASE_URL'),
      publishableKey: dotenv.get('SUPABASE_ANON_KEY'),
    );
    runApp(const MyApp());
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Tidak dapat memulai aplikasi. Periksa konfigurasi dan koneksi, lalu buka kembali.',
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.home});
  final Widget? home;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Rukun • Kepanitiaan',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF087F8C),
        primary: const Color(0xFF087F8C),
        secondary: const Color(0xFF46BFC2),
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF6F8FA),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16),
        bodyMedium: TextStyle(fontSize: 14),
        bodySmall: TextStyle(fontSize: 13),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF6F8FA),
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE5ECEE)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDCE5E7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF087F8C), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
        extendedTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFD8F1F0),
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(size: states.contains(WidgetState.selected) ? 22 : 21),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    home: home ?? const AuthGate(),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) => client.auth.currentSession == null
          ? LoginPage(
              onLogin: (identity, password) async {
                final value = identity.trim();
                var email = value;
                if (!value.contains('@')) {
                  email = await client.rpc(
                    'email_for_username',
                    params: {'p_username': value.toLowerCase()},
                  ) as String;
                }
                await client.auth.signInWithPassword(
                  email: email,
                  password: password,
                );
              },
            )
          : HomePage(
              key: ValueKey(client.auth.currentUser!.id),
              repo: CmsRepository(client),
            ),
    );
  }
}
