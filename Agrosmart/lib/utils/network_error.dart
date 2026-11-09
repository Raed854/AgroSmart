import 'dart:async';
import 'dart:io';

/// Short French explanation of why an HTTP request failed, so the farmer
/// (and the developer) can tell a missing connection from a blocked one.
String describeNetworkError(Object error) => switch (error) {
  TimeoutException() => 'délai dépassé, réseau trop lent',
  HandshakeException() =>
    'connexion sécurisée refusée — vérifiez la date et l\'heure du téléphone',
  SocketException(:final osError?)
      when osError.errorCode == 7 || osError.message.contains('host lookup') =>
    "adresse introuvable — l'appareil n'a pas accès à internet (DNS)",
  SocketException() => "pas d'accès à internet sur l'appareil",
  _ => error.toString(),
};
