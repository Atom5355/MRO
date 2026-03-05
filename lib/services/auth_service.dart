import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Authentication service using Firebase Auth with email + 5-digit PIN.
/// Under the hood we use email/password auth where the "password" is a
/// padded version of the PIN (Firebase requires ≥6 chars).
class AuthService extends ChangeNotifier {
  /// Internal prefix so the 5-digit PIN meets Firebase's 6-char minimum.
  static const _pinPrefix = 'MRO_';
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    _auth.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;

  /// Current Firebase user
  User? get user => _user;

  /// Whether the user is logged in
  bool get isLoggedIn => _user != null;

  /// Current user's email
  String get email => _user?.email ?? '';

  /// Current user's UID
  String get uid => _user?.uid ?? '';

  /// Current user's display name (from Firestore profile)
  String _displayName = '';
  String get displayName => _displayName;

  /// Sign up with email + 5-digit PIN
  Future<String?> signUp({
    required String email,
    required String pin,
    required String name,
  }) async {
    try {
      // Validate PIN
      if (pin.length != 5 || int.tryParse(pin) == null) {
        return 'PIN must be exactly 5 digits';
      }

      // Create user with email + padded PIN as password
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: '$_pinPrefix$pin',
      );

      // Store profile in Firestore
      if (cred.user != null) {
        await _firestore.collection('users').doc(cred.user!.uid).set({
          'email': email.trim(),
          'name': name.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        _displayName = name.trim();
        notifyListeners();
      }

      return null; // success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'An account with this email already exists';
        case 'invalid-email':
          return 'Please enter a valid email address';

        default:
          return e.message ?? 'Sign up failed';
      }
    } catch (e) {
      return e.toString();
    }
  }

  /// Sign in with email + 5-digit PIN
  Future<String?> signIn({
    required String email,
    required String pin,
  }) async {
    try {
      if (pin.length != 5 || int.tryParse(pin) == null) {
        return 'PIN must be exactly 5 digits';
      }

      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: '$_pinPrefix$pin',
      );

      // Load display name from Firestore
      await _loadProfile();

      return null; // success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email';
        case 'wrong-password':
          return 'Incorrect PIN';
        case 'invalid-email':
          return 'Please enter a valid email address';
        case 'invalid-credential':
          return 'Invalid email or PIN';
        default:
          return e.message ?? 'Sign in failed';
      }
    } catch (e) {
      return e.toString();
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    _displayName = '';
    notifyListeners();
  }

  /// Load the user's profile from Firestore
  Future<void> _loadProfile() async {
    if (_user == null) return;
    try {
      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      if (doc.exists) {
        _displayName = (doc.data()?['name'] as String?) ?? '';
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Initialize — call after Firebase.initializeApp
  Future<void> init() async {
    _user = _auth.currentUser;
    if (_user != null) {
      await _loadProfile();
    }
  }
}
