import 'package:flutter/material.dart';

import '../core/config.dart';

/// Monograma del local (ej. "MR") en un círculo rosa pastel, con el nombre al lado.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.showName = true, this.onPastel = false});

  final double size;
  final bool showName;

  /// Sobre un fondo rosa pastel el círculo va blanco para que se distinga.
  final bool onPastel;

  /// "MR Nails" → "MR": la primera palabra si es una sigla; si no, las iniciales.
  static String get initials {
    final words = AppConfig.appName.trim().split(RegExp(r'\s+'));
    final first = words.first;
    if (first.length <= 3 && first == first.toUpperCase()) return first;
    return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final mark = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onPastel ? scheme.surface : scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: text.titleMedium?.copyWith(
          fontFamily: text.headlineMedium?.fontFamily,
          fontSize: size * 0.4,
          color: onPastel ? scheme.primary : scheme.onPrimaryContainer,
        ),
      ),
    );

    if (!showName) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        mark,
        Text(AppConfig.appName, style: text.headlineSmall?.copyWith(fontSize: size * 0.45)),
      ],
    );
  }
}
