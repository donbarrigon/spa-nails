/// Mismo contrato que los validadores del backend (`ironforge::Validator`):
/// - [prepareForValidation] normaliza los datos (trim, minúsculas, teléfono...).
/// - [validate] devuelve el primer error de cada campo; vacío si todo es válido.
/// - [toJson] es el body que se envía a la API.
///
/// Los nombres de campo son los del backend, así los errores del servidor
/// (`data.errors`) caen en el mismo campo del formulario.
abstract class Validator {
  void prepareForValidation() {}

  Map<String, String> validate();

  Map<String, Object?> toJson();
}

/// Acumula el primer error de cada campo.
final class FieldErrors {
  final _errors = <String, String>{};

  /// Registra [message] si [valid] es falso y el campo aún no tiene error.
  void check(String field, bool valid, String message) {
    if (!valid) _errors.putIfAbsent(field, () => message);
  }

  bool has(String field) => _errors.containsKey(field);

  Map<String, String> get errors => Map.unmodifiable(_errors);
}
