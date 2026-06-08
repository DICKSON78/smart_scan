import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/result_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/course_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/audit_provider.dart';
import 'providers/session_provider.dart';
import 'routes/app_router.dart';
import 'services/logger_service.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  LoggerService.instance.init();
  final authProvider = AuthProvider();
  await authProvider.tryAutoLogin();
  runApp(MyApp(authProvider: authProvider));
}

class MyApp extends StatelessWidget {
  final AuthProvider authProvider;
  const MyApp({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => ResultProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => CourseProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuditProvider()),
        ChangeNotifierProvider(create: (_) => SessionProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, tp, _) => MaterialApp.router(
          title: 'SmartScan Marks',
          debugShowCheckedModeBanner: false,
          theme: EduTheme.light,
          darkTheme: EduTheme.dark,
          themeMode: tp.mode,
          routerConfig: AppRouter.router,
        ),
      ),
    );
  }
}
