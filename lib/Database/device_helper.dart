import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceData {
  final String lockId;
  final String? deviceName;
  final String? deviceId;   // the m5-stack-door-01 style ID
  final String? room;
  final String? location;
  final DateTime? lastUnlocked;
  final String? status;

  const DeviceData({
    required this.lockId,
    this.deviceName,
    this.deviceId,
    this.room,
    this.location,
    this.lastUnlocked,
    this.status,
  });

  factory DeviceData.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final raw = data['last_unlocked'];
    return DeviceData(
      lockId: doc.id,
      deviceName: data['name'] as String?,
      deviceId: data['deviceId'] as String?,
      room: data['room'] as String?,
      location: data['location'] as String?,
      lastUnlocked: raw is Timestamp ? raw.toDate() : null,
      status: data['status'] as String?,
    );
  }
}

class DeviceHelper {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch device info directly from the locks collection.
  Future<DeviceData?> getDeviceByLockId(String lockId) async {
    try {
      final doc = await _firestore.collection('locks').doc(lockId).get();
      if (!doc.exists) return null;
      return DeviceData.fromDoc(doc);
    } catch (e) {
      print('Error fetching device: $e');
      return null;
    }
  }
}