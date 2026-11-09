import 'package:flutter_test/flutter_test.dart';

import 'package:my_application/services/stock_read_only_tools.dart';

void main() {
  final tools = StockReadOnlyTools();

  group('StockReadOnlyTools', () {
    test('refuse une limite supérieure à 20', () async {
      await expectLater(tools.searchProducts(limit: 21), throwsArgumentError);
    });

    test('refuse une limite nulle', () async {
      await expectLater(
        tools.getInventorySummary(limit: 0),
        throwsArgumentError,
      );
    });

    test('refuse une période négative', () async {
      await expectLater(
        tools.getReorderSuggestions(windowDays: -1),
        throwsArgumentError,
      );
    });

    test('refuse un mois invalide', () async {
      await expectLater(
        tools.getMonthlyReport(year: 2026, month: 13),
        throwsArgumentError,
      );
    });

    test('refuse une période de mouvements inversée', () async {
      await expectLater(
        tools.getMovements(from: DateTime(2026, 2), to: DateTime(2026, 1)),
        throwsArgumentError,
      );
    });
  });
}
