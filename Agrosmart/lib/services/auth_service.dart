import '../models/user_model.dart';

class AuthService {
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    return UserModel(name: email.split('@').first, email: email);
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    return UserModel(name: name, email: email);
  }
}
