/// Fecha como `dd/mm/aaaa`. Con [utc] usa el día UTC: para fechas sin hora
/// (nacimiento), que el backend guarda a medianoche UTC.
String formatDate(DateTime date, {bool utc = false}) {
  final d = utc ? date.toUtc() : date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}
