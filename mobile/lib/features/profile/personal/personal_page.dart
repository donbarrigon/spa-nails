import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import '../../../components/app_button.dart';
import '../../../components/app_text_field.dart';
import '../../../components/message_banner.dart';
import '../../../components/page_body.dart';
import '../../../core/deps.dart';
import '../../../core/format.dart';
import '../profile_form.dart';

/// Nombre, usuario, fecha de nacimiento, documento y dirección.
///
/// La foto de perfil y la portada todavía no se pueden cambiar: falta que el
/// backend reciba archivos.
class PersonalPage extends StatefulWidget {
  const PersonalPage({super.key, required this.user});

  final SessionUser user;

  @override
  State<PersonalPage> createState() => _PersonalPageState();
}

class _PersonalPageState extends State<PersonalPage> {
  late final _name = TextEditingController(text: widget.user.name);
  late final _nickname = TextEditingController(text: widget.user.nickname);
  late final _document = TextEditingController(text: widget.user.document);
  late final _address = TextEditingController(text: widget.user.address);
  late final _city = TextEditingController(text: widget.user.city);
  late final _birthdateText = TextEditingController();
  late DateTime? _birthdate = widget.user.birthdate;
  late DocumentType? _documentType = widget.user.documentType;

  @override
  void initState() {
    super.initState();
    _showBirthdate();
  }

  @override
  void dispose() {
    for (final c in [_name, _nickname, _document, _address, _city, _birthdateText]) {
      c.dispose();
    }
    super.dispose();
  }

  void _showBirthdate() =>
      _birthdateText.text = switch (_birthdate) { final d? => formatDate(d, utc: true), null => '' };

  /// Lo que guardó el backend (con mayúsculas y espacios normalizados).
  void _reset(SessionUser user) {
    _name.text = user.name;
    _nickname.text = user.nickname;
    _document.text = user.document ?? '';
    _address.text = user.address ?? '';
    _city.text = user.city ?? '';
    setState(() {
      _birthdate = user.birthdate;
      _documentType = user.documentType;
      _showBirthdate();
    });
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final current = _birthdate?.toUtc();
    final picked = await showDatePicker(
      context: context,
      initialDate: current == null ? DateTime(now.year - 25) : DateTime(current.year, current.month, current.day),
      firstDate: DateTime(1900),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Fecha de nacimiento',
    );
    if (picked == null) return;
    setState(() {
      _birthdate = DateTime.utc(picked.year, picked.month, picked.day);
      _showBirthdate();
    });
  }

  void _submit(ProfileSubmit submit) {
    final form = UpdateProfileValidator(
      nickname: _nickname.text,
      name: _name.text,
      birthdate: switch (_birthdate) { final d? => Rules.isoDate(d), null => '' },
      documentType: _documentType,
      document: _document.text,
      address: _address.text,
      city: _city.text,
    );
    final api = AppDeps.of(context).profileApi;
    submit(() => api.update(form), form: form);
  }

  @override
  Widget build(BuildContext context) => ProfileForm(
        successMessage: (_) => 'Guardamos tus datos',
        onDone: (result) => _reset(result! as SessionUser),
        builder: (context, state, submit) {
          final busy = state.submitting;
          final fields = state.fields;

          return PageBody(
            spacing: 14,
            children: [
              AppTextField(
                label: 'Nombre completo',
                controller: _name,
                error: fields['name'],
                enabled: !busy,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
              ),
              AppTextField(
                label: 'Nombre de usuario',
                controller: _nickname,
                error: fields['nickname'],
                enabled: !busy,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
              ),
              AppTextField(
                label: 'Fecha de nacimiento',
                hint: 'Opcional',
                controller: _birthdateText,
                error: fields['birthdate'],
                enabled: !busy,
                readOnly: true,
                onTap: _pickBirthdate,
                suffix: _birthdate == null
                    ? const Icon(Icons.calendar_today_outlined)
                    : IconButton(
                        tooltip: 'Quitar fecha',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _birthdate = null;
                          _showBirthdate();
                        }),
                      ),
              ),
              DropdownButtonFormField<DocumentType?>(
                // `initialValue` solo se lee al crear el campo: la key lo recrea
                // cuando el valor cambia desde afuera (al guardar).
                key: ValueKey(_documentType),
                initialValue: _documentType,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Tipo de documento',
                  errorText: fields['document_type'],
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sin documento')),
                  for (final type in DocumentType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(type.label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (type) => setState(() {
                          _documentType = type;
                          if (type == null) _document.clear();
                        }),
              ),
              AppTextField(
                label: 'Número de documento',
                controller: _document,
                error: fields['document'],
                enabled: !busy && _documentType != null,
                keyboardType: switch (_documentType) {
                  DocumentType.ce || DocumentType.pp => TextInputType.text,
                  _ => TextInputType.number,
                },
                textInputAction: TextInputAction.next,
              ),
              AppTextField(
                label: 'Dirección',
                hint: 'Opcional',
                controller: _address,
                error: fields['address'],
                enabled: !busy,
                maxLength: 120,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.streetAddressLine1],
              ),
              AppTextField(
                label: 'Ciudad',
                hint: 'Opcional',
                controller: _city,
                error: fields['city'],
                enabled: !busy,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.addressCity],
                onSubmitted: (_) => _submit(submit),
              ),
              if (state.error case final error?) MessageBanner(error),
              AppButton(label: 'Guardar cambios', loading: busy, onPressed: () => _submit(submit)),
            ],
          );
        },
      );
}
