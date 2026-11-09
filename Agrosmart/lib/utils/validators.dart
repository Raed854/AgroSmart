// Validateurs pour les formulaires

/// Valide que le champ n'est pas vide
String? validateRequired(String? value, String fieldName) {
  if (value == null || value.trim().isEmpty) {
    return '$fieldName est requis';
  }
  return null;
}

/// Valide un nombre positif
String? validatePositiveNumber(String? value, String fieldName) {
  if (value == null || value.trim().isEmpty) {
    return '$fieldName est requis';
  }

  final number = double.tryParse(value.trim());
  if (number == null) {
    return '$fieldName doit être un nombre';
  }

  if (number <= 0) {
    return '$fieldName doit être positif';
  }

  return null;
}

/// Valide une surface en hectares
String? validateSurface(String? value) {
  final error = validatePositiveNumber(value, 'La surface');
  if (error != null) return error;

  final surface = double.parse(value!.trim());
  if (surface > 10000) {
    return 'La surface ne peut pas dépasser 10000 ha';
  }

  return null;
}

/// Valide une latitude (-90 à 90)
String? validateLatitude(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'La latitude est requise';
  }

  final number = double.tryParse(value.trim());
  if (number == null) {
    return 'La latitude doit être un nombre';
  }

  if (number < -90 || number > 90) {
    return 'La latitude doit être entre -90 et 90';
  }

  return null;
}

/// Valide une longitude (-180 à 180)
String? validateLongitude(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'La longitude est requise';
  }

  final number = double.tryParse(value.trim());
  if (number == null) {
    return 'La longitude doit être un nombre';
  }

  if (number < -180 || number > 180) {
    return 'La longitude doit être entre -180 et 180';
  }

  return null;
}

/// Valide qu'une date de récolte est après la date de plantation
String? validateHarvestDate(DateTime? plantation, DateTime? harvest) {
  if (harvest == null) {
    return 'La date de récolte est requise';
  }

  if (plantation == null) {
    return null; // La date de plantation sera validée séparément
  }

  if (harvest.isBefore(plantation)) {
    return 'La date de récolte doit être après la date de plantation';
  }

  return null;
}

/// Valide une quantité de récolte
String? validateQuantite(String? value) {
  return validatePositiveNumber(value, 'La quantité');
}
