import 'package:flutter/material.dart';

/// Círculo con las iniciales del nombre. Cuando se puedan subir fotos de
/// perfil, aquí va la imagen.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.size = 56});

  final String name;
  final double size;

  static String initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: Text(
        initials(name),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: scheme.onPrimaryContainer,
              fontSize: size * 0.36,
            ),
      ),
    );
  }
}
