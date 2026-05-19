import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
  show ChangeNotifier, TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ntry_mobile/firebase_options.dart';

/// Top-level instance initialized once in main.dart.
late final AuthService authServiceInstance;

class AuthService extends ChangeNotifier {
  static const String _googleServerClientId =
      '660294707735-k4kdd08vgitahfipn36n3pfjtgq938fd.apps.googleusercontent.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  User? _currentUser;
  bool _hasProfile = false;
  bool _isInitialized = false;
  String? _role;
  String? _approvalStatus;
  String? _lockID;
  String? _firstName;
  String? _lastName;
  String? _organization;

  StreamSubscription<User?>? _authSub;

  // ── Public getters ────────────────────────────────────────────────────
  bool get isLoggedIn => _currentUser != null;
  bool get hasProfile => _hasProfile;
  bool get isInitialized => _isInitialized;
  User? get currentUser => _currentUser;
  String? get role => _role;
  bool get isAdmin => _role == 'admin';
  bool get isResident => _role == 'resident';
  String? get lockID => _lockID;
  String? get approvalStatus => _approvalStatus;
  // null approvalStatus means the field wasn't written yet (legacy users) → treat as approved
  bool get isPendingApproval => _approvalStatus != null && _approvalStatus != 'approved';
  String? get firstName => _firstName;
  String? get lastName => _lastName;
  String? get organization => _organization;


  AuthService() {
    _authSub = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _currentUser = user;
    if (user != null) {
      try {
        await _checkProfile(user.uid);
      } catch (_) {
        _hasProfile = false;
        _role = null;
        _approvalStatus = null;
        _lockID = null;
      }
    } else {
      _hasProfile = false;
      _role = null;
      _firstName = null;
      _lastName = null;
      _organization = null;
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _checkProfile(String uid) async {
  final doc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();

  _hasProfile = doc.exists;

  if (doc.exists) {
    final data = doc.data() as Map<String, dynamic>;
    _role = data['role'] as String?;
    _lockID = data['lock_id'] as String?;
    _approvalStatus = data['approvalStatus'] as String?;
    _firstName = data['first_name'] as String?;
    _lastName = data['last_name'] as String?;
    _organization = data['organization'] as String?;
  } else {
    _role = null;
    _approvalStatus = null;
    _firstName = null;
    _lastName = null;
    _organization = null;
  }
}


  /// Call after onboarding saves a Firestore profile so the router re-evaluates.
  Future<void> refreshProfile() async {
    if (_currentUser == null) return;
    await _checkProfile(_currentUser!.uid);
    notifyListeners();
  }

  // ── Auth methods ──────────────────────────────────────────────────────
  Future<User?> signInWithGoogle() async {
    if (kIsWeb) {
      final userCredential = await _auth.signInWithPopup(GoogleAuthProvider());
      return userCredential.user;
    }

    final String? clientId =
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)
        ? DefaultFirebaseOptions.currentPlatform.iosClientId
        : null;

    await _googleSignIn.initialize(
      clientId: clientId,
      serverClientId: _googleServerClientId,
    );

    final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google sign-in did not return an ID token.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await _auth.signInWithCredential(credential);
    return userCredential.user;
  }

  Future<User?> signInWithEmail(String email, String password) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential.user;
  }

  Future<User?> signUpWithEmail(String email, String password) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential.user;
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
