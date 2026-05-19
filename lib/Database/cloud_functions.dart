// import 'package:cloud_functions/cloud_functions.dart';

// class CloudFunctions {
//   final FirebaseFunctions _functions = FirebaseFunctions.instance;

//   /// Calls the Firebase function to generate + store a signed JWT
//   Future<Map<String, dynamic>> signGuestPass({
//     required String passId,
//     required String lockId,
//     required int expiresAt, // milliseconds
//   }) async {
//     try {
//       final callable = _functions.httpsCallable('signGuestPass');

//       final result = await callable.call({
//         'passId': passId,
//         'lockId': lockId,
//         'expiresAt': expiresAt,
//       });

//       return Map<String, dynamic>.from(result.data);
//     } on FirebaseFunctionsException catch (e) {
//       throw Exception('Firebase function error: ${e.message}');
//     } catch (e) {
//       throw Exception('Unexpected error: $e');
//     }
//   }
// }