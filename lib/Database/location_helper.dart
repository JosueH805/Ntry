import 'package:cloud_firestore/cloud_firestore.dart';

class LocationHelper {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream all locations belonging to [org].
  Stream<QuerySnapshot<Map<String, dynamic>>> streamByOrg(String org) =>
      _firestore
          .collection('locations')
          .where('organization', isEqualTo: org)
          .snapshots();

  /// One-time fetch of all locations belonging to [org].
  Future<QuerySnapshot<Map<String, dynamic>>> getByOrg(String org) =>
      _firestore
          .collection('locations')
          .where('organization', isEqualTo: org)
          .get();

  /// Create a new location document and return its reference.
  Future<DocumentReference<Map<String, dynamic>>> create(
    Map<String, dynamic> data,
  ) =>
      _firestore.collection('locations').add(data);

  /// Update an existing location document.
  Future<void> update(String locationId, Map<String, dynamic> data) =>
      _firestore.collection('locations').doc(locationId).update(data);
}
