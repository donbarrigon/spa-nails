import 'package:flutter/material.dart';

/// Casilla "Recordarme": guarda la sesión en el dispositivo por 30 días.
class RememberMe extends StatelessWidget {
  const RememberMe({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onChanged == null ? null : () => onChanged!(!value),
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: value,
                  onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
                ),
                Text('Recordarme', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      );
}
