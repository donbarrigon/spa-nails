/// Lectura de los tipos de Mongo que el backend serializa como JSON extendido:
/// `ObjectId` → `{"$oid": "..."}` y `DateTime` → `{"$date": {"$numberLong": "..."}}`.
/// También acepta los valores planos (string / ISO / milisegundos).
library;

String readId(Object? value) => switch (value) {
      {r'$oid': final String oid} => oid,
      final String id => id,
      _ => throw FormatException('Invalid id: $value'),
    };

DateTime readDate(Object? value) =>
    readDateOrNull(value) ?? (throw FormatException('Invalid date: $value'));

DateTime? readDateOrNull(Object? value) => switch (value) {
      null => null,
      {r'$date': final Object? date} => readDateOrNull(date),
      {r'$numberLong': final String millis} => _fromMillis(int.parse(millis)),
      final int millis => _fromMillis(millis),
      final String iso => DateTime.parse(iso),
      _ => throw FormatException('Invalid date: $value'),
    };

DateTime _fromMillis(int millis) => DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
