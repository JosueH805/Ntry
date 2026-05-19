import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:ntry_mobile/database/lock_helper.dart';
import 'package:ntry_mobile/providers/user_provider.dart';

/// Top-level instance initialized once in main.dart.
late final LockProvider lockProviderInstance;

/// Streams the current user's assigned lock document and exposes its fields
/// as observable state. Automatically re-subscribes when the user's lockId
/// changes (e.g. after an admin reassigns them).
class LockProvider extends ChangeNotifier {
  final _helper = LockHelper();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _lockSub;
  String? _currentLockId;

  String? _room;
  String? _name;
  String? _status;
  bool _unlocked = false;
  bool _isLockedDown = false;

  String? get room => _room;
  String? get name => _name;
  String? get status => _status;
  bool get unlocked => _unlocked;
  bool get isLockedDown => _isLockedDown;

  LockProvider() {
    userProviderInstance.addListener(_onUserChanged);
    _onUserChanged();
  }

  void _onUserChanged() {
    final lockId = userProviderInstance.lockId;
    if (lockId == _currentLockId) return;
    _currentLockId = lockId;
    if (lockId != null) {
      _startListening(lockId);
    } else {
      _clear();
    }
  }

  void _startListening(String lockId) {
    _lockSub?.cancel();
    _lockSub = _helper.stream(lockId).listen((doc) {
      final data = doc.data();
      _room = data?['room'] as String?;
      _name = data?['name'] as String?;
      _status = data?['status'] as String?;
      _unlocked = data?['unlocked'] as bool? ?? false;
      _isLockedDown = data?['isLockedDown'] as bool? ?? false;
      notifyListeners();
    });
  }

  void _clear() {
    _lockSub?.cancel();
    _lockSub = null;
    _room = null;
    _name = null;
    _status = null;
    _unlocked = false;
    _isLockedDown = false;
    notifyListeners();
  }

  @override
  void dispose() {
    userProviderInstance.removeListener(_onUserChanged);
    _lockSub?.cancel();
    super.dispose();
  }
}
