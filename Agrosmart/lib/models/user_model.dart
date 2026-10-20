class UserModel {
  const UserModel({
    required this.name,
    required this.email,
    this.farmName = 'Green Valley Farm',
  });

  final String name;
  final String email;
  final String farmName;
}
