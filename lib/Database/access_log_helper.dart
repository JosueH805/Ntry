import 'package:cloud_firestore/cloud_firestore.dart';

class AccessLog {
  final String id;
  final String lockId;
  final String? userId;
  final String? visitorName;
  final String method; // 'manual', 'BLE', 'QR', 'admin_override'
  final DateTime timestamp;
  final String? details; // Optional details about the access
  final String status; // 'pending' | 'executed' | 'failed'
  final String? deniedReason;

  AccessLog({
    required this.id,
    required this.lockId,
    this.userId,
    required this.method,
    required this.timestamp,
    required this.status,
    this.visitorName,
    this.details,
    this.deniedReason,
  });

  factory AccessLog.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return AccessLog(
      id: doc.id,
      lockId: data['lock_id'] as String,
      userId: data['user_id'] as String?,
      visitorName: data['visitor_name'] as String?,
      method: data['method'] as String,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'executed',
      details: data['details'] as String?,
      deniedReason: data['denied_reason'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'lock_id': lockId,
        'user_id': userId,
        if (visitorName != null) 'visitor_name': visitorName,
        'method': method,
        'timestamp': Timestamp.fromDate(timestamp),
        'status': status,
        if (details != null) 'details': details,
        if (deniedReason != null) 'denied_reason': deniedReason,
      };
}

class AccessLogHelper {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Log an access event for a specific lock.
  Future<void> logAccess({
    required String lockId,
    required String userId,
    required String method,
    required String status,
    String? visitorName,
    String? details,
    String? deniedReason,
  }) =>
      _firestore.collection('access_logs').add({
        'lock_id': lockId,
        'user_id': userId,
        if (visitorName != null) 'visitor_name': visitorName,
        'method': method,
        'timestamp': FieldValue.serverTimestamp(),
        'status': status,
        if (details != null) 'details': details,
        if (deniedReason != null) 'denied_reason': deniedReason,
      });

  /// Stream all access logs for a specific lock, ordered by most recent first.
  /// Limit to [limit] entries (default 100) to avoid overwhelming the UI.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamByLock(
    String lockId, {
    int limit = 100,
  }) =>
      _firestore
          .collection('access_logs')
          .where('lock_id', isEqualTo: lockId)
          .limit(limit)
          .snapshots();

  /// Stream all access logs for an organization (all locks).
  /// Limited to [limit] entries to prevent overwhelming admins.
  /// Defaults to 50 to protect against thousands of daily entries.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamByOrg(
    String org, {
    int limit = 50,
  }) =>
      _firestore
          .collection('access_logs')
          .where('organization', isEqualTo: org)
          .limit(limit)
          .snapshots();

  /// One-time fetch of access logs for a specific lock.
  Future<QuerySnapshot<Map<String, dynamic>>> getByLock(
    String lockId, {
    int limit = 100,
  }) =>
      _firestore
          .collection('access_logs')
          .where('lock_id', isEqualTo: lockId)
          .limit(limit)
          .get();

  /// One-time fetch of access logs for a specific lock within a date range.
  Future<QuerySnapshot<Map<String, dynamic>>> getByLockAndDateRange(
    String lockId, {
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      _firestore
          .collection('access_logs')
          .where('lock_id', isEqualTo: lockId)
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .get();

  /// One-time fetch of access logs for a specific lock and user.
  Future<QuerySnapshot<Map<String, dynamic>>> getByLockAndUser(
    String lockId,
    String userId, {
    int limit = 50,
  }) =>
      _firestore
          .collection('access_logs')
          .where('lock_id', isEqualTo: lockId)
          .where('user_id', isEqualTo: userId)
          .limit(limit)
          .get();

  /// Count failed access attempts for a lock in the last [minutes] minutes.
  Future<int> getRecentFailedAttempts(
    String lockId, {
    int minutes = 60,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(minutes: minutes));
    final result = await _firestore
        .collection('access_logs')
        .where('lock_id', isEqualTo: lockId)
        .where('status', isEqualTo: 'failed')
        .where('timestamp', isGreaterThan: cutoff)
        .count()
        .get();
    return result.count ?? 0;
  }
}
