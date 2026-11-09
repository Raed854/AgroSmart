// Modèle filtre enregistré – module 3.6, fonctionnalité 3

import 'stock_product.dart';

class SavedFilter {
  const SavedFilter({
    this.id,
    required this.name,
    this.category,
    this.filterLow = false,
    this.filterExpiring = false,
    this.filterArchived = false,
    this.searchText,
    this.isPreset = false,
    required this.createdAt,
  });

  final int? id;

  /// Nom affiché sur la puce (obligatoire, unique, ≤ 40 caractères).
  final String name;

  /// Filtre catégorie (null = toutes).
  final ProductCategory? category;

  final bool filterLow;
  final bool filterExpiring;
  final bool filterArchived;

  /// Texte de recherche optionnel inclus dans le filtre.
  final String? searchText;

  /// Vrai pour les 3 filtres prédéfinis — non supprimables.
  final bool isPreset;

  final DateTime createdAt;

  /// Vrai si au moins un critère est actif.
  bool get hasAnyCriteria =>
      category != null ||
      filterLow ||
      filterExpiring ||
      filterArchived ||
      (searchText != null && searchText!.isNotEmpty);

  SavedFilter copyWith({
    int? id,
    String? name,
    ProductCategory? category,
    bool? filterLow,
    bool? filterExpiring,
    bool? filterArchived,
    String? searchText,
    bool? isPreset,
    DateTime? createdAt,
    bool clearCategory = false,
    bool clearSearchText = false,
  }) {
    return SavedFilter(
      id: id ?? this.id,
      name: name ?? this.name,
      category: clearCategory ? null : (category ?? this.category),
      filterLow: filterLow ?? this.filterLow,
      filterExpiring: filterExpiring ?? this.filterExpiring,
      filterArchived: filterArchived ?? this.filterArchived,
      searchText:
          clearSearchText ? null : (searchText ?? this.searchText),
      isPreset: isPreset ?? this.isPreset,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'category': category?.name,
      'filter_low': filterLow ? 1 : 0,
      'filter_expiring': filterExpiring ? 1 : 0,
      'filter_archived': filterArchived ? 1 : 0,
      'search_text': searchText,
      'is_preset': isPreset ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SavedFilter.fromMap(Map<String, dynamic> map) {
    final catStr = map['category'] as String?;
    return SavedFilter(
      id: map['id'] as int?,
      name: map['name'] as String,
      category: catStr != null
          ? ProductCategory.values.firstWhere(
              (c) => c.name == catStr,
              orElse: () => ProductCategory.semences,
            )
          : null,
      filterLow: (map['filter_low'] as int? ?? 0) == 1,
      filterExpiring: (map['filter_expiring'] as int? ?? 0) == 1,
      filterArchived: (map['filter_archived'] as int? ?? 0) == 1,
      searchText: map['search_text'] as String?,
      isPreset: (map['is_preset'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Résumé lisible des critères actifs (pour l'info-bulle).
  String get criteriaLabel {
    final parts = <String>[];
    if (category != null) parts.add(category!.label);
    if (filterLow) parts.add('Stock faible');
    if (filterExpiring) parts.add('Expire bientôt');
    if (filterArchived) parts.add('Archivés');
    if (searchText != null && searchText!.isNotEmpty) {
      parts.add('"$searchText"');
    }
    return parts.isEmpty ? 'Aucun critère' : parts.join(' · ');
  }
}
