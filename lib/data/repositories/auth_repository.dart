import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/constants/strings.dart';
import '../models/app_user.dart';

class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;
}

class AuthRepository {
  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  bool _googleReady = false;

  Stream<User?> get authChanges => _auth.authStateChanges();

  Future<void> _ensureGoogle() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize(serverClientId: Strings.webClientId);
    _googleReady = true;
  }

  /// Returns null if the user cancelled. Throws [AuthFailure] on real errors.
  Future<User?> signInWithGoogle() async {
    try {
      await _ensureGoogle();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw AuthFailure('Google did not return an ID token.');
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await _auth.signInWithCredential(credential);
      return result.user;
    } on GoogleSignInException catch (e) {
      debugPrint('GOOGLE ERROR: code=${e.code} description=${e.description}');
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw AuthFailure(
            'Sign-in was canceled or the app is not configured correctly (check SHA-1).');
      }
      throw AuthFailure('Google sign-in failed (${e.code.name}).');
    }
  }

  Future<AppUser?> fetchProfile(String uid) async {
    final doc = await _db.collection(FirestorePaths.users).doc(uid).get();
    final data = doc.data();
    return data == null ? null : AppUser.fromMap(data);
  }

  Future<AppUser> saveProfile(AppUser user) async {
    await _db.collection(FirestorePaths.users).doc(user.uid).set({
      ...user.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return user;
  }

  Future<void> signOut() async {
    await _ensureGoogle();
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}