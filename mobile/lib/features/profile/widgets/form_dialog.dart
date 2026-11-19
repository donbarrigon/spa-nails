import 'package:flutter/material.dart';

import '../../../components/app_button.dart';
import '../../../components/message_banner.dart';
import '../profile_form.dart';

/// Marco de los diálogos con formulario: título, explicación, campos, error
/// general y los botones Cancelar / [submitLabel].
class FormDialog extends StatelessWidget {
  const FormDialog({
    super.key,
    required this.title,
    this.description,
    required this.state,
    required this.children,
    required this.submitLabel,
    required this.onSubmit,
  });

  final String title;
  final String? description;
  final ProfileFormIdle state;
  final List<Widget> children;
  final String submitLabel;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final busy = state.submitting;

    return AlertDialog(
      title: Text(title),
      scrollable: true,
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            if (description case final description?)
              Text(
                description,
                style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ...children,
            if (state.error case final error?) MessageBanner(error),
          ],
        ),
      ),
      actions: [
        AppButton.text(label: 'Cancelar', onPressed: busy ? null : () => Navigator.of(context).pop()),
        AppButton(label: submitLabel, expand: false, loading: busy, onPressed: onSubmit),
      ],
    );
  }
}
