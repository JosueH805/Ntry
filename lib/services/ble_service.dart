import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../auth/auth_service.dart';

late BleService bleServiceInstance;

class BleService extends ChangeNotifier {
  static const _prefKey = 'ble_device_uuid';
  static const _secretKey = 'ble_hmac_secret';
  static const _windowMs = 30000;
  // All Ntry token UUIDs start with these two bytes ("NT").
  // The edge reader uses this prefix to identify Ntry advertisements.
  static const _tokenPrefix = [0x4E, 0x54];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  final FlutterSecureStorage _secureStore = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  Timer? _rotationTimer;
  Uint8List? _secretBytes;

  bool _isAdvertising = false;
  bool get isAdvertising => _isAdvertising;

  BleService() {
    authServiceInstance.addListener(_onAuthChanged);
    _adapterSub = FlutterBluePlus.adapterState.listen(_onAdapterStateChanged);
  }

  void _onAdapterStateChanged(BluetoothAdapterState state) {
    if (state == BluetoothAdapterState.off && _isAdvertising) {
      _rotationTimer?.cancel();
      _rotationTimer = null;
      _isAdvertising = false;
      notifyListeners();
    } else if (state == BluetoothAdapterState.on) {
      final uid = authServiceInstance.currentUser?.uid;
      if (uid != null && authServiceInstance.isLoggedIn) {
        initialize(uid);
      }
    }
  }

  void _onAuthChanged() {
    final uid = authServiceInstance.currentUser?.uid;
    if (uid != null && authServiceInstance.isLoggedIn) {
      initialize(uid);
    } else {
      stop();
    }
  }

  Future<void> initialize(String userId) async {
    try {
      final supported = await _peripheral.isSupported;
      if (!supported) return;

      // Resolve deviceId — identifier only, not secret
      final prefs = await SharedPreferences.getInstance();
      var uuid = prefs.getString(_prefKey);

      if (uuid == null) {
        uuid = const Uuid().v4();
        await prefs.setString(_prefKey, uuid);
        await _firestore.collection('devices').doc(uuid).set({
          'uuid': uuid,
          'ownedBy': userId,
          'lockId': authServiceInstance.lockID,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'registeredAt': FieldValue.serverTimestamp(),
          'isRevoked': false,
        });
      } else {
        // Keep lockId + ownedBy in sync — user's lock assignment may have changed.
        final lockId = authServiceInstance.lockID;
        await _firestore.collection('devices').doc(uuid).set(
          {
            'uuid': uuid,
            'ownedBy': userId,
            'lockId': lockId,
            'platform': Platform.isIOS ? 'ios' : 'android',
            'isRevoked': false,
          },
          SetOptions(merge: true),
        );
      }
      // Resolve HMAC secret — if doc was deleted, stored secret is stale; reprovision.
      final storedB64 = await _secureStore.read(key: _secretKey);
      if (storedB64 != null) {
        final docSnap = await _firestore.collection('devices').doc(uuid).get();
        if (docSnap.exists && docSnap.data()?['hmacSecret'] != null) {
          _secretBytes = base64Decode(storedB64);
        } else {
          // Doc missing hmacSecret (e.g. deleted and recreated) — reprovision.
          await _secureStore.delete(key: _secretKey);
          _secretBytes = await _provisionSecret(uuid);
        }
      } else {
        _secretBytes = await _provisionSecret(uuid);
      }

      await _startAdvertising();

      _rotationTimer?.cancel();
      _rotationTimer = Timer.periodic(
        const Duration(milliseconds: _windowMs),
        (_) => _rotateToken(),
      );

      _isAdvertising = true;
      notifyListeners();
    } catch (e) {
      debugPrint('BleService.initialize error: $e');
    }
  }

  Future<Uint8List> _provisionSecret(String deviceId) async {
    // Generate secret on-device using a cryptographically secure RNG.
    // Stored in hardware-backed secure storage locally, and in Firestore
    // for server-side validation by validateBleToken (Admin SDK bypasses rules).
    final rand = Random.secure();
    final secretBytes = Uint8List.fromList(
      List.generate(32, (_) => rand.nextInt(256)),
    );
    final secretB64 = base64Encode(secretBytes);

    await _firestore.collection('devices').doc(deviceId).set(
      {
        'hmacSecret': secretB64,
        'secretProvisionedAt': FieldValue.serverTimestamp(),
        'ownedBy': authServiceInstance.currentUser?.uid,
        'lockId': authServiceInstance.lockID,
      },
      SetOptions(merge: true),
    );

    await _secureStore.write(key: _secretKey, value: secretB64);
    return secretBytes;
  }

  // Computes the rolling token and encodes it as a UUID string.
  // Format: 0x4E54 prefix (2 bytes) + first 14 HMAC bytes = 16 bytes total.
  // Works identically on iOS and Android — no manufacturer data needed.
  String _computeTokenUuid() {
    final window = DateTime.now().millisecondsSinceEpoch ~/ _windowMs;
    final digest = Hmac(sha256, _secretBytes!)
        .convert(utf8.encode(window.toString()));
    final b = Uint8List(16);
    b[0] = _tokenPrefix[0]; // 0x4E
    b[1] = _tokenPrefix[1]; // 0x54
    for (int i = 0; i < 14; i++) { b[i + 2] = digest.bytes[i]; }
    String seg(int s, int e) => b
        .sublist(s, e)
        .map((v) => v.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${seg(0, 4)}-${seg(4, 6)}-${seg(6, 8)}'
        '-${seg(8, 10)}-${seg(10, 16)}';
  }

  Future<void> _startAdvertising() async {
    final tokenUuid = _computeTokenUuid();
    await _peripheral.stop().catchError((_) => BluetoothPeripheralState.unknown);
    await _peripheral.start(
      advertiseData: AdvertiseData(
        serviceUuid: tokenUuid,
        includeDeviceName: false,
      ),
    );
  }

  Future<void> _rotateToken() async {
    if (_secretBytes == null) return;
    try {
      await _startAdvertising();
    } catch (e) {
      debugPrint('BleService: token rotation error: $e');
    }
  }

  Future<void> stop() async {
    _rotationTimer?.cancel();
    _rotationTimer = null;
    try {
      await _peripheral.stop();
    } catch (_) {}
    _isAdvertising = false;
    notifyListeners();
  }

  @override
  void dispose() {
    authServiceInstance.removeListener(_onAuthChanged);
    _adapterSub?.cancel();
    _rotationTimer?.cancel();
    _peripheral.stop().ignore();
    super.dispose();
  }
}
