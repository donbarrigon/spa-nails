import 'dart:convert';
import 'dart:typed_data';

/// MessagePack mínimo para hablar con el backend (`rmp_serde::to_vec_named`):
/// null, bool, int, double, String, bytes, List y Map. Sin extensiones.
///
/// Funciona igual en la VM y compilado a JS: los enteros de 64 bits se leen y
/// escriben como dos mitades de 32, porque dart2js no soporta `getInt64`.
/// En JS los enteros son exactos solo hasta 2^53.
abstract final class MsgPack {
  static Uint8List encode(Object? value) => (_Writer()..write(value)).takeBytes();

  static Object? decode(Uint8List bytes) {
    final reader = _Reader(bytes);
    final value = reader.read();
    if (reader.offset != bytes.length) {
      throw const FormatException('MessagePack: sobran bytes al final');
    }
    return value;
  }
}

const _two32 = 0x100000000;

final class _Writer {
  final _out = BytesBuilder(copy: false);
  final _scratch = ByteData(8);

  Uint8List takeBytes() => _out.takeBytes();

  void write(Object? v) {
    switch (v) {
      case null:
        _byte(0xc0);
      case bool b:
        _byte(b ? 0xc3 : 0xc2);
      // En JS `1.0 is int`: un double entero se manda como entero.
      case int i:
        _int(i);
      case double d:
        _byte(0xcb);
        _scratch.setFloat64(0, d);
        _out.add(_scratch.buffer.asUint8List(0, 8));
      case String s:
        _str(s);
      case Uint8List b:
        _len(b.length, 0xc4, 0xc5, 0xc6);
        _out.add(b);
      case List<Object?> l:
        if (l.length < 16) {
          _byte(0x90 | l.length);
        } else {
          _len(l.length, null, 0xdc, 0xdd);
        }
        l.forEach(write);
      case Map<Object?, Object?> m:
        if (m.length < 16) {
          _byte(0x80 | m.length);
        } else {
          _len(m.length, null, 0xde, 0xdf);
        }
        m.forEach((k, v) {
          write(k);
          write(v);
        });
      default:
        // Igual que jsonEncode: los modelos se mandan con su toJson().
        try {
          write((v as dynamic).toJson());
        } on NoSuchMethodError {
          throw ArgumentError.value(v, 'value', 'MessagePack: tipo no soportado ${v.runtimeType}');
        }
    }
  }

  void _byte(int b) => _out.addByte(b);

  void _int(int i) {
    if (i >= 0) {
      if (i < 0x80) return _byte(i);
      if (i <= 0xff) return _bytes(0xcc, i, 1);
      if (i <= 0xffff) return _bytes(0xcd, i, 2);
      if (i <= 0xffffffff) return _bytes(0xce, i, 4);
      return _wide(0xcf, i);
    }
    if (i >= -32) return _byte(i & 0xff);
    if (i >= -0x80) return _bytes(0xd0, i, 1);
    if (i >= -0x8000) return _bytes(0xd1, i, 2);
    if (i >= -0x80000000) return _bytes(0xd2, i, 4);
    _wide(0xd3, i);
  }

  /// `tag` + `n` bytes big-endian de `v` (n = 1, 2 o 4).
  void _bytes(int tag, int v, int n) {
    _byte(tag);
    switch (n) {
      case 1:
        _scratch.setUint8(0, v & 0xff);
      case 2:
        _scratch.setUint16(0, v & 0xffff);
      default:
        _scratch.setUint32(0, v & 0xffffffff);
    }
    _out.add(Uint8List.fromList(_scratch.buffer.asUint8List(0, n)));
  }

  /// 64 bits como dos uint32 (alto y bajo) para que funcione en JS.
  void _wide(int tag, int v) {
    final hi = (v / _two32).floor();
    final lo = v - hi * _two32;
    _byte(tag);
    _scratch
      ..setUint32(0, hi & 0xffffffff)
      ..setUint32(4, lo);
    _out.add(Uint8List.fromList(_scratch.buffer.asUint8List(0, 8)));
  }

  void _str(String s) {
    final bytes = utf8.encode(s);
    if (bytes.length < 32) {
      _byte(0xa0 | bytes.length);
    } else {
      _len(bytes.length, 0xd9, 0xda, 0xdb);
    }
    _out.add(bytes);
  }

  /// Cabecera de largo: 8 bits (si hay `tag8`), 16 o 32.
  void _len(int n, int? tag8, int tag16, int tag32) {
    if (tag8 != null && n <= 0xff) return _bytes(tag8, n, 1);
    if (n <= 0xffff) return _bytes(tag16, n, 2);
    _bytes(tag32, n, 4);
  }
}

final class _Reader {
  _Reader(this.bytes) : _data = ByteData.sublistView(bytes);

  final Uint8List bytes;
  final ByteData _data;
  int offset = 0;

  Object? read() {
    final b = _u8();
    if (b <= 0x7f) return b;
    if (b >= 0xe0) return b - 0x100;
    if (b & 0xf0 == 0x80) return _map(b & 0x0f);
    if (b & 0xf0 == 0x90) return _list(b & 0x0f);
    if (b & 0xe0 == 0xa0) return _str(b & 0x1f);

    return switch (b) {
      0xc0 => null,
      0xc2 => false,
      0xc3 => true,
      0xc4 => _bin(_u8()),
      0xc5 => _bin(_u16()),
      0xc6 => _bin(_u32()),
      0xca => _take(4, () => _data.getFloat32(offset)),
      0xcb => _take(8, () => _data.getFloat64(offset)),
      0xcc => _u8(),
      0xcd => _u16(),
      0xce => _u32(),
      0xcf => _u32() * _two32 + _u32(),
      0xd0 => _take(1, () => _data.getInt8(offset)),
      0xd1 => _take(2, () => _data.getInt16(offset)),
      0xd2 => _take(4, () => _data.getInt32(offset)),
      0xd3 => _take(4, () => _data.getInt32(offset)) * _two32 + _u32(),
      0xd9 => _str(_u8()),
      0xda => _str(_u16()),
      0xdb => _str(_u32()),
      0xdc => _list(_u16()),
      0xdd => _list(_u32()),
      0xde => _map(_u16()),
      0xdf => _map(_u32()),
      _ => throw FormatException('MessagePack: tipo 0x${b.toRadixString(16)} no soportado', bytes, offset - 1),
    };
  }

  T _take<T>(int n, T Function() get) {
    _need(n);
    final v = get();
    offset += n;
    return v;
  }

  void _need(int n) {
    if (offset + n > bytes.length) {
      throw FormatException('MessagePack: datos incompletos', bytes, offset);
    }
  }

  int _u8() => _take(1, () => _data.getUint8(offset));
  int _u16() => _take(2, () => _data.getUint16(offset));
  int _u32() => _take(4, () => _data.getUint32(offset));

  String _str(int n) => utf8.decode(_bin(n));

  Uint8List _bin(int n) {
    _need(n);
    final out = Uint8List.sublistView(bytes, offset, offset + n);
    offset += n;
    return out;
  }

  List<Object?> _list(int n) => [for (var i = 0; i < n; i++) read()];

  Map<String, Object?> _map(int n) {
    final out = <String, Object?>{};
    for (var i = 0; i < n; i++) {
      final key = read();
      // El backend solo manda claves de texto (structs y mapas de serde).
      out[key is String ? key : '$key'] = read();
    }
    return out;
  }
}
