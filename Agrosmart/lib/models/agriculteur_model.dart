import 'exploitation_model.dart';

class Agriculteur {
  const Agriculteur({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.email = '',
    this.address = '',
    this.exploitation,
    this.archived = false,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String phone;
  final String email;
  final String address;
  final Exploitation? exploitation;
  final bool archived;

  String get fullName => '$firstName $lastName';

  Agriculteur copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? address,
    Exploitation? exploitation,
    bool? archived,
  }) {
    return Agriculteur(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      exploitation: exploitation ?? this.exploitation,
      archived: archived ?? this.archived,
    );
  }
}
