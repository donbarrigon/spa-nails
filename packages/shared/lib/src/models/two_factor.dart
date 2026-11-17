/// De dónde sale el código del segundo factor. Igual que `TwoFactorMethod` del backend.
enum TwoFactorMethod {
  email,
  whatsapp,

  /// App de autenticación (Google Authenticator, Authy, ...).
  totp;

  static TwoFactorMethod? tryParse(Object? value) =>
      values.where((m) => m.name == value).firstOrNull;
}

/// Respuesta `202` del login cuando la cuenta tiene segundo factor:
/// la sesión se crea al enviar el código con este `challenge`.
final class TwoFactorChallenge {
  const TwoFactorChallenge({required this.challenge, required this.method});

  final String challenge;
  final TwoFactorMethod method;

  factory TwoFactorChallenge.fromJson(Map<String, Object?> json) => TwoFactorChallenge(
        challenge: json['challenge'] as String,
        method: TwoFactorMethod.tryParse(json['method']) ??
            (throw FormatException('Unknown two-factor method: ${json['method']}')),
      );
}
