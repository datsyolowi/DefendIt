import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/constants/strings.dart';
import '../../core/utils/student_number.dart';
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
          'Sign-in was canceled or the app is not configured correctly (check SHA-1).',
        );
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

  /// Creates the adviser profile and claims the access code in ONE transaction.
  /// The security rules accept an adviser profile only together with this claim.
  Future<AppUser> registerAdviser(AppUser user, String rawCode) async {
    final code = rawCode.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (code.isEmpty) throw AuthFailure('Enter your adviser access code.');
    if (code.contains('/')) throw AuthFailure('That code is not valid.');

    final codeRef = _db.collection(FirestorePaths.adviserCodes).doc(code);
    final userRef = _db.collection(FirestorePaths.users).doc(user.uid);
    final adviser = user.copyWith(role: UserRole.adviser);

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(codeRef);
        if (!snap.exists) throw AuthFailure('That code is not valid.');
        final claimedBy = snap.data()?['claimedByUid'];
        if (claimedBy != null && claimedBy != user.uid) {
          throw AuthFailure('That code has already been used.');
        }
        tx.update(codeRef, {
          'claimedByUid': user.uid,
          'claimedAt': FieldValue.serverTimestamp(),
        });
        tx.set(userRef, {
          ...adviser.toMap(),
          'adviserCode': code,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw AuthFailure(
          'That code could not be verified. Check it and try again.',
        );
      }
      throw AuthFailure(
        'Could not verify the code. Check your connection and try again.',
      );
    }
    return adviser;
  }

  /// Creates the student profile and registers the student number in ONE
  /// transaction, so a student number can belong to only one account.
  Future<AppUser> registerStudent(AppUser user, String rawNumber) async {
    final number = StudentNumber.normalize(rawNumber);
    if (!StudentNumber.isValid(number)) {
      throw AuthFailure(
        'Use the student number format ${StudentNumber.example}, for example 2022-102420.',
      );
    }

    final numberRef = _db.collection(FirestorePaths.studentNumbers).doc(number);
    final userRef = _db.collection(FirestorePaths.users).doc(user.uid);
    final student = user.copyWith(
      role: UserRole.student,
      studentNumber: number,
    );

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(numberRef);
        final owner = snap.data()?['uid'];
        if (snap.exists && owner != user.uid) {
          throw AuthFailure(
            'That student number is already registered to another account.',
          );
        }

        if (!snap.exists) {
          tx.set(numberRef, {
            'uid': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        tx.set(userRef, {
          ...student.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw AuthFailure(
          'That student number could not be verified. Check it and try again.',
        );
      }
      throw AuthFailure(
        'Could not save your profile. Check your connection and try again.',
      );
    }
    return student;
  }

  Future<void> signOut() async {
    await _ensureGoogle();
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}
