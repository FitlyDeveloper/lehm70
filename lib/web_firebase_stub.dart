// This is a stub file for Firebase Auth on web platforms
// It provides mock implementations of Firebase Auth classes to avoid import errors

class FirebaseAuth {
  static final FirebaseAuth instance = FirebaseAuth();

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError('Firebase Auth is not available on web');
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError('Firebase Auth is not available on web');
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    throw UnimplementedError('Firebase Auth is not available on web');
  }
}

class UserCredential {
  final User? user;

  UserCredential({this.user});
}

class User {
  final String uid;
  final String? email;

  User({required this.uid, this.email});
}

class FirebaseAuthException implements Exception {
  final String code;
  final String? message;

  FirebaseAuthException({required this.code, this.message});
}
