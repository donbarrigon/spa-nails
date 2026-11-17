import 'package:flutter/material.dart';

import '../components/brand_mark.dart';

/// Mientras se revisa la sesión guardada al abrir la app.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 28,
            children: [
              BrandMark(size: 56),
              SizedBox(width: 120, child: LinearProgressIndicator()),
            ],
          ),
        ),
      );
}
