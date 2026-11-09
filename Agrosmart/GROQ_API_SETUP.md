# Configuration de l'API Groq (Optionnel)

L'application AgroSmart fonctionne **parfaitement sans API externe** grâce à son assistant IA basé sur des règles.

Cependant, pour obtenir une analyse plus détaillée et personnalisée, vous pouvez activer l'intégration Groq AI.

## Option 1 : Utiliser l'app sans API (Recommandé)

L'app fonctionne déjà ! Le bouton "Analyse détaillée (IA)" affichera des suggestions basées sur le type de sol et les caractéristiques de la parcelle.

**Aucune configuration requise.**

## Option 2 : Ajouter l'API Groq (Optionnel)

### Avantages :
- Analyses plus détaillées et contextuelles
- Suggestions personnalisées
- Gratuit et rapide

### Étapes :

1. **Obtenez une clé API gratuite**
   - Visitez : https://console.groq.com
   - Créez un compte (email uniquement)
   - Accédez à "API Keys"
   - Cliquez sur "Create API Key"
   - Copiez la clé générée

2. **Ajoutez la clé dans le code**
   
   Ouvrez `lib/screens/parcelles/parcelle_detail_screen.dart`
   
   Trouvez la ligne 16 :
   ```dart
   final _groqService = GroqAIService(apiKey: ''); 
   ```
   
   Remplacez par :
   ```dart
   final _groqService = GroqAIService(apiKey: 'votre-clé-api-ici');
   ```

3. **Redémarrez l'app**
   ```bash
   flutter run
   ```

4. **Testez**
   - Ouvrez une parcelle
   - Cliquez sur "Analyse détaillée (IA)"
   - Vous verrez maintenant une analyse générée par Groq AI !

## Modèle utilisé

- **llama-3.3-70b-versatile** : Modèle rapide et performant de Meta
- Optimisé pour des réponses courtes et pertinentes
- Spécialisé pour l'agriculture tunisienne

## Sécurité

⚠️ **Important** : Ne partagez jamais votre clé API publiquement
⚠️ Ne commitez pas votre clé API sur Git

## Dépannage

### "Mode démo activé"
✅ Normal si aucune clé API n'est configurée

### "IA en ligne indisponible"
- Vérifiez votre connexion internet
- Vérifiez que votre clé API est correcte
- L'app continue de fonctionner avec l'analyse locale

### Erreur de compilation
- Assurez-vous d'avoir bien copié-collé la clé entre guillemets simples
- Vérifiez qu'il n'y a pas d'espace avant/après la clé

## Support

Questions ? Contactez l'équipe AgroSmart.
