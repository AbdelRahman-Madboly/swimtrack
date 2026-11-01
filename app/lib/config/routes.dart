// GoRouter configuration for SwimTrack.
// Redirect logic: no profile → stay on login; has profile + on login → go to main.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/login_screen.dart';
import '../screens/profile_setup_screen.dart';
import '../screens/main_screen.dart';
import '../screens/session_detail_screen.dart';
import '../providers/profile_provider.dart';

/// Provides the singleton [GoRouter] to the widget tree via Riverpod.
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) => notifier._redirect(state),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/main',
        builder: (context, state) => const MainScreen(),
      ),
      GoRoute(
        path: '/session/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return SessionDetailScreen(sessionId: id);
        },
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
      body: Center(child: Text('Page not found: \${state.uri}')),
    ),
  );
});

/// Listens to profileProvider and notifies GoRouter when profile state changes.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(profileProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? _redirect(GoRouterState state) {
    final profile = _ref.read(profileProvider);
    final path    = state.uri.path;

    // Has profile and is on login → go straight to main
    if (profile != null && path == '/') {
      return '/main';
    }

    // No profile and trying to access protected route → back to login
    if (profile == null && path != '/' && path != '/profile-setup') {
      return '/';
    }

    return null;
  }
}