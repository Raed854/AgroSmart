import 'package:intl/intl.dart';

// Utilitaires pour la gestion des dates

/// Formatte une date en format court français (ex: 15 mars 2024)
String formatDateFr(DateTime date) {
  final formatter = DateFormat('d MMMM yyyy', 'fr_FR');
  return formatter.format(date);
}

/// Formatte une date en format court (ex: 15/03/2024)
String formatDateShort(DateTime date) {
  final formatter = DateFormat('dd/MM/yyyy');
  return formatter.format(date);
}

/// Formatte une date avec l'heure
String formatDateTime(DateTime date) {
  final formatter = DateFormat('dd/MM/yyyy HH:mm');
  return formatter.format(date);
}

/// Calcule le nombre de jours entre deux dates
int daysBetween(DateTime from, DateTime to) {
  from = DateTime(from.year, from.month, from.day);
  to = DateTime(to.year, to.month, to.day);
  return to.difference(from).inDays;
}

/// Retourne une description relative de la date (ex: "dans 5 jours", "il y a 2 jours")
String getRelativeTimeDescription(DateTime date) {
  final now = DateTime.now();
  final difference = daysBetween(now, date);

  if (difference == 0) {
    return "aujourd'hui";
  } else if (difference == 1) {
    return 'demain';
  } else if (difference == -1) {
    return 'hier';
  } else if (difference > 0) {
    return 'dans $difference jours';
  } else {
    return 'il y a ${-difference} jours';
  }
}

/// Retourne le nom du mois en français
String getMonthName(int month) {
  const months = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];

  if (month < 1 || month > 12) return '';
  return months[month - 1];
}

/// Calcule l'année de la saison agricole (commence en septembre)
int getSaisonAgricole(DateTime date) {
  // Une saison agricole commence en septembre
  // Ex: Sept 2023 - Août 2024 = Saison 2023-2024 (retourne 2023)
  if (date.month >= 9) {
    return date.year;
  } else {
    return date.year - 1;
  }
}

/// Formatte une période de saison agricole
String formatSaisonAgricole(int annee) {
  return '$annee-${annee + 1}';
}
