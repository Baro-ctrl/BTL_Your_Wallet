
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app_router.dart';
import 'firebase_options.dart';
import 'services/theme_controller.dart';
import 'theme/your_wallet_themes.dart';

// ==========================================
// MAIN
// ==========================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // ======================================
    // 1. FIREBASE
    // ======================================

    final firebaseApp = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (kDebugMode) {
      debugPrint(
        '[FIREBASE] Project: '
            '${firebaseApp.options.projectId}',
      );
      debugPrint(
        '[FIREBASE] Initialized successfully',
      );
    }

    // ======================================
    // 2. LOAD USER THEME
    // ======================================

    await ThemeController.instance.initialize();

    if (kDebugMode) {
      debugPrint(
        '[THEME] Mode: '
            '${ThemeController.instance.themeMode.name}',
      );
    }

    // ======================================
    // 3. RUN APP
    // ======================================

    runApp(const YourWalletApp());
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[STARTUP ERROR] $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    runApp(
      FirebaseErrorApp(
        errorMessage: error.toString(),
      ),
    );
  }
}

// ==========================================
// YOUR WALLET APP
// ==========================================

class YourWalletApp extends StatelessWidget {
  const YourWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,

      builder: (context, child) {
        return MaterialApp.router(
          title: 'Your Wallet',

          debugShowCheckedModeBanner: false,

          // ==================================
          // LIGHT THEME
          // ==================================

          theme: YourWalletThemes.light,

          // ==================================
          // DARK THEME
          // ==================================

          darkTheme: YourWalletThemes.dark,

          // ==================================
          // THEME MODE ĐỘNG
          // ==================================

          themeMode:
          ThemeController.instance.themeMode,

          // ==================================
          // GO ROUTER
          // ==================================

          routerConfig: AppRouter.router,
        );
      },
    );
  }
}

// ==========================================
// FIREBASE STARTUP ERROR SCREEN
// ==========================================

class FirebaseErrorApp extends StatelessWidget {
  final String errorMessage;

  const FirebaseErrorApp({
    super.key,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Colors.red,
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Không thể khởi động ứng dụng',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 14),

                  const Text(
                    'Không thể khởi tạo Firebase '
                        'hoặc đọc cài đặt ứng dụng.',
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  SelectableText(
                    errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
