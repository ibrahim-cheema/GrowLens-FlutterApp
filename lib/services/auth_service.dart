// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream to listen for auth changes (user login/logout)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Sign in with email and password
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        await _upsertUserProfile(
          uid: credential.user!.uid,
          email: credential.user!.email ?? email,
          name: credential.user!.displayName ?? '',
          includeCreatedAt: false,
          includeRoleDefaults: false,
        );
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapSignInError(e));
    } catch (e) {
      throw Exception('Failed to sign in: $e');
    }
  }

  /// Sign up with email, password, and name
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      if (credential.user != null) {
        try {
          await credential.user!.updateDisplayName(name);
          await credential.user!.reload();
          await _upsertUserProfile(
            uid: credential.user!.uid,
            email: credential.user!.email ?? email,
            name: name,
            includeCreatedAt: true,
            includeRoleDefaults: true,
          );
        } catch (e) {
          // Display name update failed, but signup succeeded
          // This is acceptable - the user is still registered
        }
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to sign up: $e');
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to send password reset email: $e');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  /// Update password
  Future<void> updatePassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
         throw Exception('For security, please logout and login again to change password.');
      }
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }

  String _mapSignInError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return 'Wrong email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return e.message ?? 'Sign in failed. Please try again.';
    }
  }

  Future<void> _upsertUserProfile({
    required String uid,
    required String email,
    required String name,
    required bool includeCreatedAt,
    required bool includeRoleDefaults,
  }) async {
    final data = <String, dynamic>{
      'uid': uid,
      'email': email,
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (includeRoleDefaults) {
      data['role'] = 'user';
      data['isActive'] = true;
    }
    if (includeCreatedAt) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }
}
