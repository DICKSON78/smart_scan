import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/sign_in_screen.dart';
import '../screens/auth/sign_up_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/history/history_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/purchase/purchase_package_screen.dart';
import '../screens/teacher/teacher_management_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final authProvider = context.read<AuthProvider>();

      if (!authProvider.isAuthenticated) {
        if (state.matchedLocation != '/' &&
            !state.matchedLocation.startsWith('/sign-in') &&
            !state.matchedLocation.startsWith('/sign-up')) {
          return '/sign-in';
        }
        return null;
      }

      if (state.matchedLocation == '/' ||
          state.matchedLocation.startsWith('/sign-in') ||
          state.matchedLocation.startsWith('/sign-up')) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/purchase',
        builder: (context, state) => const PurchasePackageScreen(),
      ),
      GoRoute(
        path: '/teacher-management',
        builder: (context, state) => const TeacherManagementScreen(),
      ),
    ],
  );
}
