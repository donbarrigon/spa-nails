/// Tipo de documento de identidad. Igual que `DocumentType` del backend, que lo
/// guarda con [code].
enum DocumentType {
  cc('CC', 'Cédula de ciudadanía'),
  ce('CE', 'Cédula de extranjería'),
  ti('TI', 'Tarjeta de identidad'),
  pp('PP', 'Pasaporte'),
  ppt('PPT', 'Permiso por protección temporal'),
  nit('NIT', 'NIT');

  const DocumentType(this.code, this.label);

  final String code;
  final String label;

  static DocumentType? tryParse(Object? value) =>
      values.where((t) => t.code == value).firstOrNull;
}

/// Tema de la app elegido en las preferencias. Igual que `Theme` del backend.
/// Sin elegir, la app sigue el tema del dispositivo.
enum ThemePreference {
  light,
  dark;

  static ThemePreference? tryParse(Object? value) =>
      values.where((t) => t.name == value).firstOrNull;
}
