import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../../features/home/main_shell.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/role_onboarding_screen.dart';
import '../widgets/loading_view.dart';

class AppRouter {
  AppRouter._();

  static GoRouter create(AuthProvider auth) {
    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: auth,
      redirect: (context, state) {
        final loc = state.matchedLocation;
        switch (auth.status) {
          case AuthStatus.loading:
            return loc == '/splash' ? null : '/splash';
          case AuthStatus.signedOut:
            return loc == '/login' ? null : '/login';
          case AuthStatus.needsRole:
            return loc == '/onboarding' ? null : '/onboarding';
          case AuthStatus.ready:
            const authScreens = ['/splash', '/login', '/onboarding'];
            return authScreens.contains(loc) ? '/home' : null;
        }
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, __) => const Scaffold(body: LoadingView()),
        ),
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(
            path: '/onboarding',
            builder: (_, __) => const RoleOnboardingScreen()),
        GoRoute(path: '/home', builder: (_, __) => const MainShell()),
      ],
    );
  }
}