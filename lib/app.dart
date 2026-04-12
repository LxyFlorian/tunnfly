import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/chat/screens/conversations_screen.dart';

class TunnflyApp extends ConsumerWidget {
  const TunnflyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Tunnfly',
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      home: const _AuthGate(),
    );
  }
}

final _lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF111111),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF555555),
    onSecondary: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF111111),
    onSurfaceVariant: Color(0xFF777777),
    surfaceContainerHighest: Color(0xFFF0F0F0),
    outline: Color(0xFFBBBBBB),
    outlineVariant: Color(0xFFEEEEEE),
    error: Color(0xFFB00020),
    onError: Color(0xFFFFFFFF),
  ),
  scaffoldBackgroundColor: const Color(0xFFFFFFFF),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFFFFFFF),
    foregroundColor: Color(0xFF111111),
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: TextStyle(
      color: Color(0xFF111111),
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
    ),
    iconTheme: IconThemeData(color: Color(0xFF111111)),
  ),
  dividerTheme: const DividerThemeData(
    color: Color(0xFFEEEEEE),
    space: 1,
    thickness: 1,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFF7F7F7),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF111111), width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFB00020)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFB00020), width: 1.5),
    ),
    labelStyle: const TextStyle(color: Color(0xFF888888)),
    hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF111111),
      foregroundColor: const Color(0xFFFFFFFF),
      minimumSize: const Size(double.infinity, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      elevation: 0,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xFF111111),
      textStyle: const TextStyle(fontWeight: FontWeight.w500),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Color(0xFF111111),
    foregroundColor: Color(0xFFFFFFFF),
    elevation: 0,
    shape: CircleBorder(),
  ),
  listTileTheme: const ListTileThemeData(
    iconColor: Color(0xFF888888),
    minLeadingWidth: 0,
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: const Color(0xFF111111),
    contentTextStyle: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    behavior: SnackBarBehavior.floating,
    elevation: 0,
  ),
);

final _darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFFFFFFFF),
    onPrimary: Color(0xFF111111),
    secondary: Color(0xFFAAAAAA),
    onSecondary: Color(0xFF111111),
    surface: Color(0xFF0D0D0D),
    onSurface: Color(0xFFF0F0F0),
    onSurfaceVariant: Color(0xFF888888),
    surfaceContainerHighest: Color(0xFF1E1E1E),
    outline: Color(0xFF444444),
    outlineVariant: Color(0xFF282828),
    error: Color(0xFFCF6679),
    onError: Color(0xFF111111),
  ),
  scaffoldBackgroundColor: const Color(0xFF0D0D0D),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF0D0D0D),
    foregroundColor: Color(0xFFF0F0F0),
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: TextStyle(
      color: Color(0xFFF0F0F0),
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
    ),
    iconTheme: IconThemeData(color: Color(0xFFF0F0F0)),
  ),
  dividerTheme: const DividerThemeData(
    color: Color(0xFF282828),
    space: 1,
    thickness: 1,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF1A1A1A),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF333333)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF333333)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFFFFFFF), width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFCF6679)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFCF6679), width: 1.5),
    ),
    labelStyle: const TextStyle(color: Color(0xFF666666)),
    hintStyle: const TextStyle(color: Color(0xFF555555)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFFFFFFFF),
      foregroundColor: const Color(0xFF111111),
      minimumSize: const Size(double.infinity, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      elevation: 0,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xFFF0F0F0),
      textStyle: const TextStyle(fontWeight: FontWeight.w500),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Color(0xFFFFFFFF),
    foregroundColor: Color(0xFF111111),
    elevation: 0,
    shape: CircleBorder(),
  ),
  listTileTheme: const ListTileThemeData(
    iconColor: Color(0xFF777777),
    minLeadingWidth: 0,
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: const Color(0xFF1E1E1E),
    contentTextStyle: const TextStyle(color: Color(0xFFF0F0F0), fontSize: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    behavior: SnackBarBehavior.floating,
    elevation: 0,
  ),
);

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Erreur: $e'))),
      data: (user) {
        if (user == null) return const LoginScreen();
        return const ConversationsScreen();
      },
    );
  }
}
