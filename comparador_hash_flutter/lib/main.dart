import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ComparadorHashApp());
}

/// Widget raiz responsável pelo tema escuro unificado e pela exibição inicial
/// do splash animado com a logo antes da tela principal de comparação.
class ComparadorHashApp extends StatelessWidget {
  const ComparadorHashApp({
    super.key,
    this.showSplash = true,
  });

  /// Controla se a [SplashScreen] é exibida na inicialização (útil também em testes).
  final bool showSplash;

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF38BDF8),
        secondary: Color(0xFFA78BFA),
        surface: Color(0xFF1E293B),
        error: Color(0xFFEF4444),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
    );

    return MaterialApp(
      title: 'Comparador de Arquivos por Hash',
      debugShowCheckedModeBanner: false,
      theme: baseTheme,
      home: showSplash ? const SplashScreen() : const HomeScreen(),
    );
  }
}
