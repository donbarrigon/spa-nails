import 'package:client/client.dart';
import 'package:shared/shared.dart';
import 'package:web/web.dart' show ElementEventGetters;

import '../core/form_view.dart';
import '../core/page.dart';

/// Registro con correo: crea la cuenta y la sesión, y vuelve al inicio.
///
/// El nombre de usuario, el correo y el teléfono se revisan al salir de cada
/// campo (no al escribir, para no enviar una petición por tecla).
void initRegisterPage() {
  final element = query('#register-form');
  if (element == null) return;
  final form = FormView(element, errorId: 'register-error');

  /// Lo que ya es de otra cuenta: campo → valor normalizado.
  final taken = <String, String>{};

  /// Último valor revisado de cada campo: si no cambió no se vuelve a preguntar.
  final checked = <String, String>{};

  RegisterAvailableValidator available(String field) =>
      RegisterAvailableValidator(field: field, value: form.value(field))..prepareForValidation();

  /// Los "ya está en uso" que siguen valiendo para lo que está escrito ahora.
  Map<String, String> stillTaken() => {
    for (final MapEntry(key: field, :value) in taken.entries)
      if (available(field).value == value) field: AuthErrors.registerTaken[field]!,
  };

  Future<void> check(String field) async {
    final validator = available(field);
    final input = form.fields[field]!;
    // Cambió lo que estaba en uso: ese error ya no aplica.
    if (taken.containsKey(field) && taken[field] != validator.value) {
      taken.remove(field);
      input.error = null;
    }
    // Con formato inválido no se pregunta: el registro lo explica al enviarlo.
    if (validator.validate().isNotEmpty || checked[field] == validator.value) return;

    checked[field] = validator.value;
    try {
      await api('/api/users/auth/register/available', body: validator.toJson());
      if (available(field).value == validator.value) input.error = null;
    } on ApiException catch (e) {
      // Sin conexión o demasiadas peticiones: se revisa de nuevo al enviar.
      if (e.status != 409) {
        checked.remove(field);
        return;
      }
      taken[field] = validator.value;
      if (available(field).value == validator.value) input.error = AuthErrors.registerTaken[field];
    }
  }

  for (final field in const ['nickname', 'email', 'phone']) {
    query('input', form.fields[field]!.root)!.onBlur.listen((_) => check(field));
  }

  form.onSubmit.listen((_) async {
    final validator = UserRegisterValidator(
      nickname: form.value('nickname'),
      name: form.value('name'),
      email: form.value('email'),
      phone: form.value('phone'),
      password: form.value('password'),
      passwordConfirmation: form.value('password_confirmation'),
      remember: form.checked('remember'),
    )..prepareForValidation();
    final errors = {...stillTaken(), ...validator.validate()};
    if (errors.isNotEmpty) return form.show(fields: errors);

    form
      ..show()
      ..busy = true;
    try {
      await api('/api/users/auth/register', body: validator.toJson());
      go('/');
    } on ApiException catch (e) {
      final conflict = e.status == 409 ? AuthErrors.registerConflict(e) : const <String, String>{};
      form
        ..busy = false
        ..show(fields: {...e.fields, ...conflict}, message: conflict.isEmpty ? AuthErrors.of(e) : null);
    }
  });
}
