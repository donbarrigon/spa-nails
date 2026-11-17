import 'package:flutter/material.dart';

import '../../../components/brand_mark.dart';
import '../../../core/config.dart';
import '../../../core/layout.dart';
import '../../../core/theme/app_theme.dart';

/// Marco de las pantallas de login y registro según el tamaño de ventana:
/// - celular: el formulario a pantalla completa;
/// - tablet: el formulario en una tarjeta centrada;
/// - escritorio: panel de marca a la izquierda y formulario a la derecha.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.child, this.showBack = false});

  final Widget child;

  /// Flecha para volver (registro). El login tiene su propio "Ahora no".
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = context.windowSize;
    final canPop = showBack && Navigator.of(context).canPop();

    Widget form(double maxWidth, EdgeInsets padding) => Center(
          child: SingleChildScrollView(
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: AutofillGroup(child: child),
            ),
          ),
        );

    return Scaffold(
      backgroundColor: size == WindowSize.medium ? scheme.surfaceContainerLow : scheme.surface,
      appBar: canPop ? AppBar(backgroundColor: Colors.transparent) : null,
      body: SafeArea(
        child: switch (size) {
          WindowSize.compact => form(480, const EdgeInsets.fromLTRB(20, 16, 20, 24)),
          WindowSize.medium => Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: AutofillGroup(child: child),
                    ),
                  ),
                ),
              ),
            ),
          WindowSize.expanded => Row(
              children: [
                const Expanded(flex: 5, child: _BrandPanel()),
                Expanded(flex: 6, child: form(420, const EdgeInsets.all(40))),
              ],
            ),
        },
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius + 8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandMark(size: 56, showName: false, onPastel: true),
          const Spacer(),
          Text(
            AppConfig.appName,
            style: text.displayMedium?.copyWith(color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              'Reserva tus citas y consulta tus servicios desde cualquier dispositivo.',
              style: text.bodyLarge?.copyWith(color: scheme.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
