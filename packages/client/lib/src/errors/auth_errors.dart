import '../api_exception.dart';

/// Pasa los errores de la API a mensajes en español para el usuario.
///
/// El backend responde en inglés y sin código propio por caso, así que algunos
/// se reconocen por el mensaje. Si el backend agrega traducciones (`config/lang`)
/// o devuelve esos casos como errores de campo, esto se simplifica.
abstract final class AuthErrors {
  static const network =
      'No pudimos conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.';
  static const google = 'No pudimos iniciar sesión con Google. Inténtalo de nuevo.';
  static const googleAccountExists =
      'Ya tienes una cuenta con este correo. Inicia sesión con tu contraseña y vincula Google desde tu perfil.';
  static const signInExpired = 'Tu inicio de sesión venció. Vuelve a ingresar tus datos.';

  /// Mensaje general para un formulario.
  static String of(ApiException e) => switch (e.status) {
        0 => network,
        401 => 'El correo, teléfono o contraseña no son correctos.',
        422 when e.fields.isNotEmpty => 'Revisa los campos marcados.',
        429 => 'Hiciste demasiados intentos. Espera unos minutos y vuelve a intentarlo.',
        >= 500 => 'Algo falló en el servidor. Inténtalo de nuevo en unos minutos.',
        _ => 'No pudimos completar la acción. Inténtalo de nuevo.',
      };

  /// Errores al enviar o reenviar el código del segundo factor.
  static String ofCode(ApiException e) => switch (e.status) {
        404 => 'El código no es correcto o ya venció.',
        422 => 'Ese método no está disponible en tu cuenta.',
        429 => 'Hiciste demasiados intentos. Pide un código nuevo.',
        _ => of(e),
      };

  /// Datos repetidos en el registro (`409`), como error del campo que corresponde.
  static Map<String, String> registerConflict(ApiException e) => switch (e.message) {
        'Nickname already exists' => {'nickname': 'Este nombre de usuario ya está en uso'},
        'Email already exists' => {'email': 'Ya hay una cuenta con este correo'},
        'Phone already exists' => {'phone': 'Ya hay una cuenta con este teléfono'},
        _ => const {},
      };
}
