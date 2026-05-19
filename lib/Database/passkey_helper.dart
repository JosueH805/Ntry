import 'package:cloud_firestore/cloud_firestore.dart';

class PasskeyHelper {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns the lockId (roomId) if passkey exists.
  /// Returns null if it does not exist.
Future<String?> getLockIdFromPasskey(String passkey) async {
  try {
    final query = await _firestore
        .collection('passkeys')
        .where('passkey', isEqualTo: passkey)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return query.docs.first.data()['lockId'] as String?;
  } catch (e) {
    return null;
  }
}

  Future<void> revokeGuestPass(String passId) async {
    await _firestore
      .collection('passkeys')
      .doc(passId)
      .update({
        'revoked': true,
      });
  }

Future<({String lockId, DateTime? expiresAt, double? latitude, double? longitude})?>
    getLockIdExpiryAndCoordinates(String passkey) async {
  try {
    print('Looking up passkey: "$passkey"');

    // passkey is stored as a field, not the document ID
    final query = await _firestore
        .collection('passkeys')
        .where('passkey', isEqualTo: passkey)
        .limit(1)
        .get();

    print('Docs found: ${query.docs.length}');
    if (query.docs.isEmpty) return null;

    final data = query.docs.first.data();
    print('Doc data: $data');

    final lockId = data['lockId'] as String?;
    if (lockId == null) return null;

    final raw = data['expiresAt'];
    final expiresAt = raw is Timestamp ? raw.toDate() : null;

    // Read 2: lock document → get locationId
    final lockDoc = await _firestore.collection('locks').doc(lockId).get();
    final locationId = lockDoc.data()?['locationId'] as String?;

    if (locationId == null) {
      return (lockId: lockId, expiresAt: expiresAt, latitude: null, longitude: null);
    }

    // Read 3: location document → get coordinates
    final locationDoc = await _firestore.collection('locations').doc(locationId).get();
    final lat = (locationDoc.data()?['latitude'] as num?)?.toDouble();
    final lng = (locationDoc.data()?['longitude'] as num?)?.toDouble();

    return (lockId: lockId, expiresAt: expiresAt, latitude: lat, longitude: lng);
  } catch (e) {
    print('Error: $e');
    return null;
  }
}
}
