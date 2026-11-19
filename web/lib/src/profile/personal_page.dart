import 'package:client/client.dart';
import 'package:shared/shared.dart';
import 'package:web/web.dart' show ElementEventGetters;

import '../components/snack_bar.dart';
import '../core/form_view.dart';
import '../core/page.dart';

/// Datos personales: guarda y deja en los campos lo que normalizó el backend.
void initPersonalPage() {
  final element = query('#personal-form');
  if (element == null) return;
  final form = FormView(element, errorId: 'personal-error');
  final type = form.fields['document_type']!;
  final document = form.fields['document']!;

  // Sin tipo de documento no hay número.
  void syncDocument() {
    final none = type.value.isEmpty;
    document.enabled = !none;
    if (none) document.value = '';
  }

  element.onChange.listen((e) {
    if (e.target == query('select[name="document_type"]', element)) syncDocument();
  });

  form.onSubmit.listen((_) async {
    final validator = UpdateProfileValidator(
      nickname: form.value('nickname'),
      name: form.value('name'),
      birthdate: form.value('birthdate'),
      documentType: DocumentType.tryParse(type.value),
      document: document.value,
      address: form.value('address'),
      city: form.value('city'),
    )..prepareForValidation();
    final errors = validator.validate();
    if (errors.isNotEmpty) return form.show(fields: errors);

    form
      ..show()
      ..busy = true;
    try {
      final res = await api('/api/users/profile', method: 'PUT', body: validator.toJson());
      final user = SessionUser.fromJson(res.json);
      form.fields['name']!.value = user.name;
      form.fields['nickname']!.value = user.nickname;
      document.value = user.document ?? '';
      form.fields['address']!.value = user.address ?? '';
      form.fields['city']!.value = user.city ?? '';
      showSnackBar('Guardamos tus datos');
    } on ApiException catch (e) {
      final (message, fields) = ProfileErrors.of(e);
      form.show(fields: fields, message: message);
    } finally {
      form.busy = false;
      syncDocument();
    }
  });
}
