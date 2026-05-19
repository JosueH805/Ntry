import 'package:cloud_firestore/cloud_firestore.dart';

class UserHelper {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String uid) =>
      _firestore.collection('users').doc(uid).get();

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamUser(String uid) =>
      _firestore.collection('users').doc(uid).snapshots();

  Future<void> setUserProfile(String uid, Map<String, dynamic> data) =>
      _firestore.collection('users').doc(uid).set(data);

  Future<void> updateUser(String uid, Map<String, dynamic> data) =>
      _firestore.collection('users').doc(uid).update(data);

  /// Stream users in [org], optionally filtered by [approvalStatus] and/or [role].
  Stream<QuerySnapshot<Map<String, dynamic>>> streamUsersByOrg(
    String org, {
    String? approvalStatus,
    String? role,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .where('organization', isEqualTo: org);
    if (approvalStatus != null) {
      query = query.where('approvalStatus', isEqualTo: approvalStatus);
    }
    if (role != null) {
      query = query.where('role', isEqualTo: role);
    }
    return query.snapshots();
  }

  /// One-time fetch of users in [org], optionally filtered by [approvalStatus] and/or [role].
  Future<QuerySnapshot<Map<String, dynamic>>> getUsersByOrg(
    String org, {
    String? approvalStatus,
    String? role,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .where('organization', isEqualTo: org);
    if (approvalStatus != null) {
      query = query.where('approvalStatus', isEqualTo: approvalStatus);
    }
    if (role != null) {
      query = query.where('role', isEqualTo: role);
    }
    return query.get();
  }

  /// Stream approved users assigned to [lockId].
  Stream<QuerySnapshot<Map<String, dynamic>>> streamUsersByLock(
    String lockId,
  ) => _firestore
      .collection('users')
      .where('lock_id', isEqualTo: lockId)
      .where('approvalStatus', isEqualTo: 'approved')
      .snapshots();

  /// Update a user's approval status and optionally assign a lock.
  Future<void> updateApproval(String uid, String status, {String? lockId}) {
    final data = <String, dynamic>{'approvalStatus': status};
    if (lockId != null) data['lock_id'] = lockId;
    return _firestore.collection('users').doc(uid).update(data);
  }

  /// Assign [lockId] to the user with [uid].
  Future<void> assignLock(String uid, String lockId) =>
      _firestore.collection('users').doc(uid).update({'lock_id': lockId});
}
