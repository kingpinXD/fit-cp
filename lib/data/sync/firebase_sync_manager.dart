import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps Firebase Auth so the app can check the signed-in state and pretend
/// to push exports to a cloud — fit-cp dropped RTDB-backed sync, so this is
/// effectively a no-op outside of the auth check.
///
/// Tests inject a fake (`FakeFirebaseSyncManager`) via the provider override.
class FirebaseSyncManager {
  FirebaseSyncManager({FirebaseAuth? auth}) : _auth = auth;

  final FirebaseAuth? _auth;

  bool get isSignedIn {
    try {
      final auth = _auth ?? FirebaseAuth.instance;
      return auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  /// Returns whether the user is signed in. The Kotlin version pretended to
  /// upload; here it's just an auth check the UI can react to.
  Future<bool> exportProgramme(
    String programmeName,
    String identifier,
    String jsonData,
  ) async {
    return isSignedIn;
  }
}

final firebaseSyncManagerProvider = Provider<FirebaseSyncManager>((ref) {
  return FirebaseSyncManager();
});
