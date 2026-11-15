import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app_router.dart';
import 'firebase_options.dart';
import 'providers/expense_provider.dart';
import 'services/theme_controller.dart';
import 'theme/your_wallet_themes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final firebaseApp = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (kDebugMode) {
      debugPrint('[FIREBASE] Project: ${firebaseApp.options.projectId}');
    }

    await ThemeController.instance.initialize();
    runApp(const YourWalletApp());
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[STARTUP ERROR] $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    runApp(FirebaseErrorApp(errorMessage: error.toString()));
  }
}

class YourWalletApp extends StatelessWidget {
  const YourWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
      ],
      child: AnimatedBuilder(
        animation: ThemeController.instance,
        builder: (context, _) {
          return MaterialApp.router(
            title: 'Your Wallet',
            debugShowCheckedModeBanner: false,
            theme: YourWalletThemes.light,
            darkTheme: YourWalletThemes.dark,
            themeMode: ThemeController.instance.themeMode,
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}

class FirebaseErrorApp extends StatelessWidget {
  final String errorMessage;

  const FirebaseErrorApp({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Your Wallet',
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 64,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Không thể khởi động ứng dụng',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Vui lòng kiểm tra cấu hình Firebase và kết nối mạng.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: main,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
