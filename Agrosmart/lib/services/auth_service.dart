import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_model.dart';
import 'database_helper.dart';

/// Thrown when sign-in or registration is refused (wrong credentials,
/// duplicate account, ...). The message is safe to show to the user.
class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// SQLite-backed accounts (table `users`). Holds the signed-in user for the
/// session so any screen can read who is logged in.
class AuthService {
  static UserModel? _currentUser;

  final _googleSignIn = GoogleSignIn();

  UserModel? get currentUser => _currentUser;

  Future<UserModel> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw AuthException('Google sign-in was cancelled.');
    }

    final googleAuth = await googleUser.authentication;
    final credential = fb.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential =
        await fb.FirebaseAuth.instance.signInWithCredential(credential);
    final firebaseUser = userCredential.user;
    if (firebaseUser == null || firebaseUser.email == null) {
      throw AuthException('Google sign-in failed.');
    }

    final user = UserModel(
      name: firebaseUser.displayName ?? firebaseUser.email!.split('@').first,
      email: firebaseUser.email!,
    );
    _currentUser = user;
    return user;
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final normalizedEmail = email.trim().toLowerCase();

    final existing = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [normalizedEmail],
    );
    if (existing.isNotEmpty) {
      throw AuthException('An account with this email already exists.');
    }

    final salt = _generateSalt();
    await db.insert('users', {
      'email': normalizedEmail,
      'name': name.trim(),
      'password_hash': _hashPassword(password, salt),
      'password_salt': salt,
    });

    final user = UserModel(name: name.trim(), email: normalizedEmail);
    _currentUser = user;
    return user;
  }

  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final normalizedEmail = email.trim().toLowerCase();

    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [normalizedEmail],
    );
    if (rows.isEmpty) {
      throw AuthException('No account found for this email.');
    }

    final row = rows.first;
    final salt = row['password_salt'] as String;
    final expectedHash = row['password_hash'] as String;
    if (_hashPassword(password, salt) != expectedHash) {
      throw AuthException('Incorrect password.');
    }

    final user = UserModel(name: row['name'] as String, email: normalizedEmail);
    _currentUser = user;
    return user;
  }

  Future<void> signOut() async {
    _currentUser = null;
    await _googleSignIn.signOut();
    await fb.FirebaseAuth.instance.signOut();
  }

  String _generateSalt() {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
  }

  String _hashPassword(String password, String salt) {
    return sha256.convert(utf8.encode('$salt:$password')).toString();
  }
}
