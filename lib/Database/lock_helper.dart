import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class LockHelper {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  /// Stream a single lock document in real time.
  Stream<DocumentSnapshot<Map<String, dynamic>>> stream(String lockId) =>
      _firestore.collection('locks').doc(lockId).snapshots();

  /// Stream all locks belonging to [org].
  Stream<QuerySnapshot<Map<String, dynamic>>> streamByOrg(String org) =>
      _firestore
          .collection('locks')
          .where('organization', isEqualTo: org)
          .snapshots();

  /// One-time fetch of all locks belonging to [org].
  Future<QuerySnapshot<Map<String, dynamic>>> getByOrg(String org) => _firestore
      .collection('locks')
      .where('organization', isEqualTo: org)
      .get();

  Future<QuerySnapshot<Map<String, dynamic>>> getByIds(List<String> lockIds) {
    if (lockIds.isEmpty) {
      return _firestore
          .collection('locks')
          .where(FieldPath.documentId, whereIn: ['__none__'])
          .get();
    }

    return _firestore
        .collection('locks')
        .where(FieldPath.documentId, whereIn: lockIds)
        .get();
  }

  /// Create a new lock document and return its reference.
  Future<DocumentReference<Map<String, dynamic>>> create(
    Map<String, dynamic> data,
  ) => _firestore.collection('locks').add(data);

  /// Update fields on an existing lock document.
  Future<void> update(String lockId, Map<String, dynamic> data) =>
      _firestore.collection('locks').doc(lockId).update(data);

  /// Set the lock to the unlocked state.
  Future<void> unlock(String lockId) =>
      _firestore.collection('locks').doc(lockId).set({
        'unlocked': true,
        'last_unlocked': FieldValue.serverTimestamp(),
        'status': 'unlocked',
      }, SetOptions(merge: true));

  /// Logs the unlock attempt immediately, then enqueues the command for the
  /// M5Stack. Returns the logId so the caller can listen for status updates.
  /// The log entry is created first (status: "pending") so there is always
  /// an audit record. If the pendingCommand write fails the log is updated
  /// to "failed" before rethrowing.
  Future<String> addUnlockToPending(
    String lockId,
    String userId,
    String lockName,
    String userName,
  ) async {
    final logRef = await _firestore.collection('access_logs').add({
      'lock_id': lockId,
      'user_id': userId,
      'visitor_name': userName,
      'method': 'manual',
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    try {
      await _rtdb.ref('locks/$lockId/pendingCommand').set({
        'command': 'unlock',
        'requestedBy': userId,
        'requesterName': userName,
        'status': 'pending',
        'logId': logRef.id,
      });

      // ── Firestore pendingCommands path (disabled — kept for reference) ──────
      // await _firestore
      //     .collection('locks')
      //     .doc(lockId)
      //     .collection('pendingCommands')
      //     .add({
      //       'command': 'unlock',
      //       'requestedBy': userId,
      //       'requesterName': userName,
      //       'type': 'resident',
      //       'requestedAt': FieldValue.serverTimestamp(),
      //       'status': 'pending',
      //       'logId': logRef.id,
      //     });
      // ── End Firestore path ───────────────────────────────────────────────────
    } catch (e) {
      await logRef.update({'status': 'failed'});
      rethrow;
    }

    return logRef.id;
  }

  /// Stream a single access log document — used to observe M5Stack execution.
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamLog(String logId) =>
      _firestore.collection('access_logs').doc(logId).snapshots();


  /// Set the lock back to the locked state.
  Future<void> relock(String lockId) =>
      _firestore.collection('locks').doc(lockId).set(
        {
          'unlocked': false,
          'status': 'locked',
        },
        SetOptions(merge: true),
      );
    

  Future<int?> getGuestPassMaxDuration(String lockId) async {
    final firestore = FirebaseFirestore.instance;
    try {
      final lockDoc = await firestore.collection('locks').doc(lockId).get();

      if (!lockDoc.exists) return null;

      final lockData = lockDoc.data();
      final locationId = lockData?['locationId'] as String?;

      if (locationId == null || locationId.isEmpty) return null;

      final locationDoc = await firestore
          .collection('locations')
          .doc(locationId)
          .get();

      if (!locationDoc.exists) return null;

      final locationData = locationDoc.data();
      final maxDuration = locationData?['guestPassMaxDurationHours'] as int?;
      return maxDuration;
    } catch (e) {
      return null;
    }
  }

//Admin force unlock - writes to pending command, bypasses resident validation. Used for emergency override and testing.
Future<void> forceUnlock(String lockId, String adminUserId) async {
  try {
    // print('Writing to pendingCommands...');
    await _rtdb.ref('locks/$lockId/pendingCommand').set({
      'command': 'unlock',
      'requestedBy': adminUserId,
      'type': 'admin_override',
      'requestedAt': ServerValue.timestamp,
      'status': 'pending',
    });
    // print('RTDB write successful');

    await _firestore.collection('access_logs').add({
      'lock_id': lockId,
      'user_id': adminUserId,
      'method': 'admin_override',
      'status': 'granted',
      'timestamp': FieldValue.serverTimestamp(),
    });
    // print('access_logs write successful');
  } catch (e) {
    // print('forceUnlock error: $e');
    rethrow;
  }
}

Future<void> setLockdown(String lockId, String adminUserId, bool lockdown) async {
  try {
    await _rtdb.ref('locks/$lockId/pendingCommand').set({
      'command': lockdown ? 'lockdown' : 'lift_lockdown',
      'requestedBy': adminUserId,
      'type': 'admin_override',
      'requestedAt': ServerValue.timestamp,
      'status': 'pending',
    });

    await _firestore.collection('locks').doc(lockId).update({
      'isLockedDown': lockdown,
    });
    // print('setLockdown write successful');
  } catch (e) {
    // print('setLockdown error: $e');
    rethrow;
  }
} 


}
