import 'package:client/client.dart';
import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import '../../core/bloc/bloc.dart';
import '../../core/bloc/bloc_provider.dart';
import '../../core/bloc/bloc_widgets.dart';
import '../auth/session/session_bloc.dart';

// Todos los formularios y acciones del perfil hacen lo mismo: validar, enviar,
// mostrar los errores y, si el backend responde el usuario, actualizar la
// sesión. Este bloc y [ProfileForm] lo hacen una vez para todos.

/// Valida [form] (si hay) y ejecuta [send].
final class ProfileFormSubmitted {
  const ProfileFormSubmitted(this.send, {this.form});

  final Validator? form;
  final Future<Object?> Function() send;
}

sealed class ProfileFormState {
  const ProfileFormState();
}

final class ProfileFormIdle extends ProfileFormState {
  const ProfileFormIdle({this.submitting = false, this.error, this.fields = const {}});

  final bool submitting;
  final String? error;

  /// Error de cada campo, con los nombres del backend.
  final Map<String, String> fields;
}

/// Lo que respondió [ProfileFormSubmitted.send]. Le sigue un [ProfileFormIdle].
final class ProfileFormDone extends ProfileFormState {
  const ProfileFormDone(this.result);
  final Object? result;
}

class ProfileFormBloc extends Bloc<ProfileFormSubmitted, ProfileFormState> {
  ProfileFormBloc() : super(const ProfileFormIdle());

  @override
  Stream<ProfileFormState> mapEventToState(ProfileFormSubmitted event) async* {
    if (event.form case final form?) {
      form.prepareForValidation();
      final errors = form.validate();
      if (errors.isNotEmpty) {
        yield ProfileFormIdle(fields: errors);
        return;
      }
    }

    yield const ProfileFormIdle(submitting: true);
    try {
      yield ProfileFormDone(await event.send());
      yield const ProfileFormIdle();
    } on ApiException catch (e) {
      final (error, fields) = ProfileErrors.of(e);
      yield ProfileFormIdle(error: error, fields: fields);
    }
  }
}

/// Envía con validación: `submit(() => api.algo(form), form: form)`.
typedef ProfileSubmit = void Function(Future<Object?> Function() send, {Validator? form});

/// Un formulario o grupo de acciones del perfil con su propio estado.
///
/// Al terminar bien: si la respuesta es un [SessionUser] actualiza la sesión,
/// muestra [successMessage] y llama [onDone].
class ProfileForm extends StatefulWidget {
  const ProfileForm({super.key, required this.builder, this.successMessage, this.onDone});

  final Widget Function(BuildContext context, ProfileFormIdle state, ProfileSubmit submit) builder;

  /// Puede depender de la respuesta (ej. "reenviamos" vs. "cambiamos").
  final String? Function(Object? result)? successMessage;
  final void Function(Object? result)? onDone;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  final _bloc = ProfileFormBloc();

  @override
  void dispose() {
    _bloc.dispose();
    super.dispose();
  }

  void _submit(Future<Object?> Function() send, {Validator? form}) =>
      _bloc.add(ProfileFormSubmitted(send, form: form));

  void _onState(BuildContext context, ProfileFormState state) {
    if (state is! ProfileFormDone) return;
    if (state.result case final SessionUser user) {
      BlocProvider.of<SessionBloc>(context).add(SessionUserUpdated(user));
    }
    if (widget.successMessage?.call(state.result) case final message?) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
    }
    widget.onDone?.call(state.result);
  }

  @override
  Widget build(BuildContext context) => BlocListener<ProfileFormState>(
        bloc: _bloc,
        listener: _onState,
        child: BlocBuilder<ProfileFormState>(
          bloc: _bloc,
          builder: (context, state) => widget.builder(
            context,
            switch (state) {
              final ProfileFormIdle idle => idle,
              ProfileFormDone() => const ProfileFormIdle(),
            },
            _submit,
          ),
        ),
      );
}
