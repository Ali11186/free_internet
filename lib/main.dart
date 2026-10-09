import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/vpn_guard.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FreeInternetApp());
}

class FreeInternetApp extends StatelessWidget {
  const FreeInternetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider()..init(),
      child: MaterialApp(
        title: 'Free Internet',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        builder: (context, child) {
          return DefaultTextStyle(
            style: GoogleFonts.cairo(fontSize: 14, color: AppColors.text),
            child: VpnGuard(
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        home: const SplashScreen(),
      ),
    );
  }
}
