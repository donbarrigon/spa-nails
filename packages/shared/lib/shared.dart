/// Modelos y validadores compartidos entre la app mobile y la web.
///
/// Dart puro: no puede importar Flutter ni `dart:io`, porque la web lo compila a JS.
library;

export 'src/models/profile.dart';
export 'src/models/session_user.dart';
export 'src/models/two_factor.dart';
export 'src/validators/profile.dart';
export 'src/validators/rules.dart';
export 'src/validators/user.dart';
export 'src/validators/validator.dart';
