import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/app_user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/group_repository.dart';

enum AuthStatus { loading, signedOut, needsRole, ready }

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repo, this._groups) {
    _sub = _repo.authChanges.listen(_onAuthChanged);
  }

  final AuthRepository _repo;
  final GroupRepository _groups;
  bool _justJoined = false;
  String? _notice;

  /// True once, right after a student joined a group while signing up.
  bool takeJustJoined() {
    final v = _justJoined;
    _justJoined = false;
    return v;
  }

  String? takeNotice() {
    final v = _notice;
    _notice = null;
    return v;
  }

  StreamSubscription<User?>? _sub;

  AuthStatus status = AuthStatus.loading;
  AppUser? profile;
  String? errorMessage;
  bool busy = false;

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      _justJoined = false;
      _notice = null;
      profile = null;
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    try {
      final existing = await _repo.fetchProfile(user.uid);
      profile =
          existing ??
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

  Future<void> chooseRole(
    UserRole role, {
    String? adviserCode,
    String? studentNumber,
    String? teammateCode,
  }) async {
    final current = profile;
    if (current == null) return;

    busy = true;
    errorMessage = null;
    notifyListeners();

    try {
      if (role == UserRole.adviser) {
        profile = await _repo.registerAdviser(current, adviserCode ?? '');
      } else {
        final code = (teammateCode ?? '').trim();
        // A wrong code is caught here, before anything is saved.
        if (code.isNotEmpty) await _groups.verifyTeammateCode(code);

        profile = await _repo.registerStudent(current, studentNumber ?? '');

        if (code.isNotEmpty) {
          try {
            await _groups.joinByCode(profile!, code);
            _justJoined = true;
          } on GroupFailure catch (e) {
            _notice =
                'Your profile is saved, but joining the group failed: ${e.message} You can join from the Groups tab.';
          }
        }
      }
      status = AuthStatus.ready;
    } on AuthFailure catch (e) {
      errorMessage = e.message;
    } on GroupFailure catch (e) {
      errorMessage = e.message;
    } catch (e) {
      debugPrint('ROLE SAVE ERROR: $e');
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
