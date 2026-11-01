import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'app/app_router.dart';
import 'theme/app_theme.dart';
import 'providers/expense_provider.dart';

// ==========================================
// 1. KHỞI ĐỘNG ỨNG DỤNG
// ==========================================

Future<void> main() async {
  // Đảm bảo Flutter đã khởi tạo.
  WidgetsFlutterBinding.ensureInitialized();

  // Hiển thị lỗi trong quá trình khởi tạo.
  try {
    // Kết nối Firebase theo nền tảng hiện tại.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Firebase thành công -> chạy ứng dụng.
    runApp(const MyApp());
  } catch (error) {
    // Firebase thất bại -> hiển thị màn báo lỗi.
    runApp(
      FirebaseErrorApp(
        errorMessage: error.toString(),
      ),
    );
  }
}

// ==========================================
// 2. YOUR WALLET APP
// ==========================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
      ],
      child: MaterialApp.router(
        // Tắt chữ DEBUG.
        debugShowCheckedModeBanner: false,

        // Tên ứng dụng.
        title: 'Your Wallet',

        // Giao diện sáng theo Figma.
        theme: AppTheme.lightTheme,

        // Không tự đổi sang giao diện tối.
        themeMode: ThemeMode.light,

        // Cấu hình toàn bộ đường dẫn.
        routerConfig: AppRouter.router,

        // Tránh xuất hiện nhãn debug.
        builder: (context, child) {
          return child ?? const SizedBox.shrink();
        },
      ),
    );
  }
}

// ==========================================
// 3. MÀN HÌNH LỖI FIREBASE
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
      title: 'Your Wallet',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4096F5),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F8FF),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Your Wallet'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Biểu tượng lỗi.
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.cloud_off_rounded,
                        size: 48,
                        color: Colors.redAccent,
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'Không thể kết nối Firebase',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Ứng dụng chưa khởi tạo được Firebase. '
                      'Vui lòng kiểm tra cấu hình Firebase '
                      'và kết nối mạng.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Chi tiết lỗi giúp kiểm tra khi phát triển.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFE0E6EF),
                        ),
                      ),
                      child: SelectableText(
                        errorMessage,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    FilledButton.icon(
                      onPressed: () {
                        // Thử khởi tạo Firebase lại.
                        main();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử kết nối lại'),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Your Wallet - Quản lý chi tiêu thông minh',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
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