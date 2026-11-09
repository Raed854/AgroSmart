import 'package:flutter/material.dart';

import '../main.dart';
import '../models/stock_movement.dart';
import '../models/stock_product.dart';
import '../services/reorder_suggestion_service.dart';
import '../services/stock_question_parser.dart';
import '../services/stock_read_only_tools.dart';
import 'stock_alerts_screen.dart';
import 'stock_history_screen.dart';
import 'stock_suggestions_screen.dart';

class StockAssistantScreen extends StatefulWidget {
  const StockAssistantScreen({super.key});

  @override
  State<StockAssistantScreen> createState() => _StockAssistantScreenState();
}

class _StockAssistantScreenState extends State<StockAssistantScreen> {
  final _questionController = TextEditingController();
  final _parser = const RuleBasedQuestionParser();
  final _tools = StockReadOnlyTools();
  final _messages = <_AssistantMessage>[];
  bool _loading = false;
  List<StockProduct> _products = [];

  static const _suggestedQuestions = [
    'Quels stocks sont faibles ?',
    'Quels lots expirent bientôt ?',
    'Que dois-je réapprovisionner ?',
    'Donne-moi le résumé de l’inventaire',
    'Montre les mouvements ce mois',
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final result = await _tools.searchProducts();
      if (mounted) setState(() => _products = result.items);
    } catch (_) {
      // Une question ultérieure affichera l'erreur explicitement.
    }
  }

  Future<void> _ask([String? suggestion]) async {
    final question = (suggestion ?? _questionController.text).trim();
    if (question.isEmpty || _loading) return;
    _questionController.clear();
    setState(() {
      _messages.add(_AssistantMessage(text: question, isUser: true));
      _loading = true;
    });

    try {
      final parsed = _parser.parse(question, products: _products);
      if (parsed.isAmbiguous) {
        _addAssistant(
          'Quel produit voulez-vous consulter ?',
          source: 'Recherche de produits',
          candidates: parsed.productCandidates,
        );
      } else {
        final response = await _answer(parsed);
        _addAssistant(response.text, source: response.source);
      }
    } catch (_) {
      _addAssistant(
        'Je n’ai pas pu lire ces informations. Réessayez.',
        source: 'Outils de stock',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<_AssistantResponse> _answer(ParsedStockQuestion parsed) async {
    switch (parsed.intent) {
      case StockQuestionIntent.medicationUsage:
        return const _AssistantResponse(
          'Cette application gère uniquement le stock des médicaments.',
          'Règle de sécurité',
        );
      case StockQuestionIntent.offTopic:
      case StockQuestionIntent.unknown:
        return _AssistantResponse(
          parsed.helpMessage ??
              'Je réponds uniquement aux questions sur le stock.',
          'Aide de l’assistant',
        );
      case StockQuestionIntent.productQuantity:
        final product = parsed.product;
        if (product == null) {
          return const _AssistantResponse(
            'Je n’ai trouvé aucune information correspondante.',
            'Recherche de produits',
          );
        }
        return _AssistantResponse(
          '${product.name} : ${_quantity(product.totalQuantity, product.unit)} '
              '(seuil : ${_quantity(product.minThreshold, product.unit)}).',
          'Inventaire',
        );
      case StockQuestionIntent.inventorySummary:
        final result = await _tools.getInventorySummary();
        if (result.items.isEmpty) {
          return const _AssistantResponse(
            'Je n’ai trouvé aucune information correspondante.',
            'Résumé d’inventaire',
          );
        }
        final lines = result.items
            .take(6)
            .map(
              (item) =>
                  '• ${item.product.name} : ${_quantity(item.product.totalQuantity, item.product.unit)}',
            )
            .join('\n');
        return _AssistantResponse(
          'Voici l’inventaire (${result.items.length} produit(s)) :\n$lines'
              '${result.truncated ? '\n• Résultats tronqués à 20 lignes.' : ''}',
          'Résumé d’inventaire',
        );
      case StockQuestionIntent.lowStock:
        final result = await _tools.getAlerts();
        final items = result.items
            .where((item) => item.kind == AlertKind.stockFaible)
            .toList();
        if (items.isEmpty) {
          return const _AssistantResponse(
            'Je n’ai trouvé aucune information correspondante.',
            'Alertes de stock',
          );
        }
        return _AssistantResponse(
          'Stock faible :\n${items.take(6).map((item) => '• ${item.product.name} : ${_quantity(item.product.totalQuantity, item.product.unit)}').join('\n')}'
              '${result.truncated ? '\n• Résultats tronqués à 20 lignes.' : ''}',
          'Alertes de stock',
        );
      case StockQuestionIntent.expiration:
        final result = await _tools.getAlerts();
        final items = result.items
            .where((item) => item.kind == AlertKind.expiration)
            .toList();
        if (items.isEmpty) {
          return const _AssistantResponse(
            'Je n’ai trouvé aucune information correspondante.',
            'Alertes d’expiration',
          );
        }
        return _AssistantResponse(
          'Lots à surveiller :\n${items.take(6).map((item) => '• ${item.product.name}').join('\n')}'
              '${result.truncated ? '\n• Résultats tronqués à 20 lignes.' : ''}',
          'Alertes d’expiration',
        );
      case StockQuestionIntent.reorder:
        final result = await _tools.getReorderSuggestions();
        final suggestions = result.items.whereType<SuggestionOk>().toList();
        if (suggestions.isEmpty) {
          return const _AssistantResponse(
            'Je n’ai trouvé aucune information correspondante.',
            'Suggestions de réapprovisionnement',
          );
        }
        return _AssistantResponse(
          'Suggestions calculées :\n${suggestions.take(6).map((item) => '• ${item.suggestion.product.name} : ${_quantity(item.suggestion.suggestedQuantity, item.suggestion.product.unit)}').join('\n')}'
              '${result.truncated ? '\n• Résultats tronqués à 20 lignes.' : ''}',
          'Suggestions de réapprovisionnement',
        );
      case StockQuestionIntent.movements:
        final range = _resolvePeriod(parsed.period);
        final result = await _tools.getMovements(
          productId: parsed.product?.id,
          from: range.$1,
          to: range.$2,
        );
        if (result.items.isEmpty) {
          return const _AssistantResponse(
            'Je n’ai trouvé aucune information correspondante.',
            'Historique des mouvements',
          );
        }
        return _AssistantResponse(
          'Mouvements trouvés :\n${result.items.take(6).map((item) => '• ${item.product.name} : ${item.movement.type == MovementType.entree ? 'entrée' : 'sortie'} de ${_quantity(item.movement.quantity, item.product.unit)}').join('\n')}'
              '${result.truncated ? '\n• Résultats tronqués à 20 lignes.' : ''}',
          'Historique des mouvements',
        );
      case StockQuestionIntent.report:
        final now = DateTime.now();
        final report = await _tools.getMonthlyReport(
          year: parsed.month == null ? now.year : now.year,
          month: parsed.month ?? now.month,
        );
        return _AssistantResponse(
          'Rapport du ${report.month}/${report.year} : '
              '${report.movementCount} mouvement(s), '
              '${report.entries} unité(s) en entrée et '
              '${report.sorties} unité(s) en sortie.',
          'Rapport mensuel',
        );
    }
  }

  (DateTime?, DateTime?) _resolvePeriod(StockQuestionPeriod period) {
    final now = DateTime.now();
    switch (period) {
      case StockQuestionPeriod.yesterday:
        final day = DateTime(now.year, now.month, now.day);
        return (day.subtract(const Duration(days: 1)), day);
      case StockQuestionPeriod.lastWeek:
        return (now.subtract(const Duration(days: 7)), now);
      case StockQuestionPeriod.last30Days:
        return (now.subtract(const Duration(days: 30)), now);
      case StockQuestionPeriod.lastMonth:
        final first = DateTime(now.year, now.month - 1);
        return (first, DateTime(now.year, now.month));
      case StockQuestionPeriod.thisMonth:
        return (DateTime(now.year, now.month), now);
      case StockQuestionPeriod.namedMonth:
      case StockQuestionPeriod.unknown:
        return (null, null);
    }
  }

  void _addAssistant(
    String text, {
    required String source,
    List<StockProduct> candidates = const [],
  }) {
    if (!mounted) return;
    setState(() {
      _messages.add(
        _AssistantMessage(
          text: text,
          isUser: false,
          source: source,
          candidates: candidates,
        ),
      );
    });
  }

  void _newConversation() => setState(_messages.clear);

  String _quantity(double value, String unit) {
    final formatted = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
    return '$formatted $unit';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: inkGreen),
        title: const Text(
          'Assistant stock',
          style: TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Nouvelle conversation',
            onPressed: _newConversation,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _messages.isEmpty ? _welcome() : _conversation()),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          _composer(),
        ],
      ),
    );
  }

  Widget _welcome() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.forum_outlined, color: forestGreen, size: 48),
        const SizedBox(height: 12),
        const Text(
          'Posez une question sur vos stocks.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: inkGreen,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Assistant local, gratuit et hors ligne. Il ne modifie jamais vos données.',
          textAlign: TextAlign.center,
          style: TextStyle(color: mutedGreen),
        ),
        const SizedBox(height: 24),
        ..._suggestedQuestions.map(
          (question) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: () => _ask(question),
              child: Text(question),
            ),
          ),
        ),
      ],
    );
  }

  Widget _conversation() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (_, index) {
        final message = _messages[index];
        return Align(
          alignment: message.isUser
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: message.isUser ? const Color(0xFFEAF6E5) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderGreen),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.text, style: const TextStyle(color: inkGreen)),
                if (!message.isUser) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Basé sur : ${message.source}',
                    style: const TextStyle(color: mutedGreen, fontSize: 11),
                  ),
                  if (message.candidates.isNotEmpty)
                    ...message.candidates.map(
                      (product) => TextButton(
                        onPressed: () => _ask('quantité de ${product.name}'),
                        child: Text(product.name),
                      ),
                    ),
                  if (message.source.contains('Alerte'))
                    _sourceLink('Voir les alertes', const StockAlertsScreen()),
                  if (message.source.contains('mouvements'))
                    _sourceLink(
                      'Voir l’historique',
                      const StockHistoryScreen(),
                    ),
                  if (message.source.contains('réapprovisionnement'))
                    _sourceLink(
                      'Voir les suggestions',
                      const StockSuggestionsScreen(),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sourceLink(String label, Widget screen) {
    return TextButton.icon(
      onPressed: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      icon: const Icon(Icons.open_in_new, size: 14),
      label: Text(label),
    );
  }

  Widget _composer() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _questionController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _ask(),
                decoration: const InputDecoration(
                  hintText: 'Votre question…',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Envoyer',
              onPressed: _loading ? null : _ask,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantMessage {
  const _AssistantMessage({
    required this.text,
    required this.isUser,
    this.source = '',
    this.candidates = const [],
  });

  final String text;
  final bool isUser;
  final String source;
  final List<StockProduct> candidates;
}

class _AssistantResponse {
  const _AssistantResponse(this.text, this.source);

  final String text;
  final String source;
}
