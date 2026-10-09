import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/app_user.dart';
import '../../data/repositories/auth_repository.dart';

enum AuthStatus { loading, signedOut, needsRole, ready }

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repo) {
    _sub = _repo.authChanges.listen(_onAuthChanged);
  }

  final AuthRepository _repo;
  StreamSubscription<User?>? _sub;

  AuthStatus status = AuthStatus.loading;
  AppUser? profile;
  String? errorMessage;
  bool busy = false;

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      profile = null;
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    try {
      final existing = await _repo.fetchProfile(user.uid);
      profile = existing ??
          AppUser(
            uid: user.uid,
            name: user.displayName ?? '',
            email: user.email ?? '',
            photoUrl: user.photoURL,
          );
      status = profile!.role == null ? AuthStatus.needsRole : AuthStatus.ready;
    } catch (e, st) {
      debugPrint('PROFILE LOAD ERROR: $e');
      debugPrint('$st');
      errorMessage = 'Could not load your profile: $e';
      status = AuthStatus.signedOut;
    }
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _repo.signInWithGoogle();
    } on AuthFailure catch (e) {
      errorMessage = e.message;
    } catch (e, st) {
      debugPrint('SIGN-IN ERROR: $e');
      debugPrint('$st');
      errorMessage = 'Something went wrong. Please try again.';
    }
    busy = false;
    notifyListeners();
  }

  Future<void> chooseRole(UserRole role) async {
    final current = profile;
    if (current == null) return;
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      profile = await _repo.saveProfile(current.copyWith(role: role));
      status = AuthStatus.ready;
    } catch (_) {
      errorMessage = 'Could not save your role. Please try again.';
    }
    busy = false;
    notifyListeners();
  }

  Future<void> signOut() => _repo.signOut();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}