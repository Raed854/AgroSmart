import '../models/user_model.dart';

class AuthService {
  /// The signed-in user, or `null` before sign-in.
  static UserModel? currentUser;

  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    return currentUser = UserModel(name: email.split('@').first, email: email);
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    return currentUser = UserModel(name: name, email: email);
  }
}
