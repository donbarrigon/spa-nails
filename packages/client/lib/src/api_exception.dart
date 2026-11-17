/// Error de la API. El backend (ironforge) responde
/// `{ "status", "message", "data"? }` y, en validaciones (`422`),
/// `data.errors` con los mensajes por campo: `{ "campo": ["msg", ...] }`.
final class ApiException implements Exception {
  const ApiException(this.status, this.message, {this.fields = const {}});

  /// No hubo respuesta: sin red, servidor caído, certificado rechazado...
  const ApiException.network(this.message)
      : status = 0,
        fields = const {};

  factory ApiException.fromBody(int status, Object? body) {
    if (body is! Map<String, Object?>) return ApiException(status, 'HTTP $status');

    final fields = <String, String>{};
    if (body['data'] case {'errors': final Map<String, Object?> errors}) {
      for (final MapEntry(:key, :value) in errors.entries) {
        if (value case [final String first, ...]) fields[key] = first;
      }
    }
    return ApiException(status, body['message'] as String? ?? 'HTTP $status', fields: fields);
  }

  /// Código HTTP; `0` si no hubo respuesta.
  final int status;

  /// Mensaje del backend (en inglés): para registros, no para mostrar tal cual.
  final String message;

  /// Primer error de cada campo, con los nombres de campo del backend.
  final Map<String, String> fields;

  bool get isNetwork => status == 0;

  @override
  String toString() => 'ApiException($status, $message${fields.isEmpty ? '' : ', $fields'})';
}
