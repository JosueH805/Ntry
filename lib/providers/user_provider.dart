import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:ntry_mobile/auth/auth_service.dart';
import 'package:ntry_mobile/database/user_helper.dart';

/// Top-level instance initialized once in main.dart.
late final UserProvider userProviderInstance;

/// Streams the current user's Firestore document and exposes all profile
/// fields as observable state. Screens should prefer this over setting up
/// their own streams for user data.
class UserProvider extends ChangeNotifier {
  final _helper = UserHelper();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  String? _firstName;
  String? _lastName;
  String? _organization;
  String? _lockId;
  String? _role;
  String? _approvalStatus;

  String? get firstName => _firstName;
  String? get lastName => _lastName;
  String? get organization => _organization;
  String? get lockId => _lockId;
  String? get role => _role;
  String? get approvalStatus => _approvalStatus;

  String get displayName {
    final parts = [_firstName, _lastName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');
    return parts;
  }

  UserProvider() {
    authServiceInstance.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  void _onAuthChanged() {
    final uid = authServiceInstance.currentUser?.uid;
    if (uid != null) {
      _startListening(uid);
    } else {
      _clear();
    }
  }

  void _startListening(String uid) {
    _userSub?.cancel();
    _userSub = _helper.streamUser(uid).listen((doc) {
      final data = doc.data();
      _firstName = data?['first_name'] as String?;
      _lastName = data?['last_name'] as String?;
      _organization = data?['organization'] as String?;
      _lockId = data?['lock_id'] as String?;
      _role = data?['role'] as String?;
      _approvalStatus = data?['approvalStatus'] as String?;
      notifyListeners();
    });
  }

  void _clear() {
    _userSub?.cancel();
    _userSub = null;
    _firstName = null;
    _lastName = null;
    _organization = null;
    _lockId = null;
    _role = null;
    _approvalStatus = null;
    notifyListeners();
  }

  @override
  void dispose() {
    authServiceInstance.removeListener(_onAuthChanged);
    _userSub?.cancel();
    super.dispose();
  }
}
