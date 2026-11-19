import 'dart:typed_data';

import 'package:client/client.dart';
import 'package:test/test.dart';

Uint8List _b(List<int> bytes) => Uint8List.fromList(bytes);

void main() {
  test('ida y vuelta de todos los tipos', () {
    final values = <Object?>[
      null, true, false,
      0, 1, 127, 128, 255, 256, 65535, 65536, 4294967295, 4294967296, 9007199254740991,
      -1, -32, -33, -128, -129, -32768, -32769, -2147483648, -2147483649, -9007199254740991,
      1.5, -0.25, 3.141592653589793,
      '', 'hola', 'ñandú 💅', 'x' * 31, 'x' * 32, 'x' * 300, 'x' * 70000,
      _b([1, 2, 3]), _b(List.filled(300, 7)),
      <Object?>[], [1, 'a', null], List.generate(20, (i) => i), List.generate(70000, (i) => i % 3),
      <String, Object?>{}, {'a': 1, 'b': [true]}, {for (var i = 0; i < 20; i++) 'k$i': i},
      {'user': {'id': {r'$oid': '6650f0c2a1b2c3d4e5f60718'}, 'roles': <Object?>[]}},
    ];
    for (final v in values) {
      expect(MsgPack.decode(MsgPack.encode(v)), equals(v), reason: '$v'.length > 60 ? '${'$v'.substring(0, 60)}…' : '$v');
    }
  });

  test('usa el formato más corto', () {
    expect(MsgPack.encode(5), [0x05]);
    expect(MsgPack.encode(-1), [0xff]);
    expect(MsgPack.encode(200), [0xcc, 200]);
    expect(MsgPack.encode(-100), [0xd0, 0x9c]);
    expect(MsgPack.encode('ab'), [0xa2, 0x61, 0x62]);
    expect(MsgPack.encode([1]), [0x91, 0x01]);
    expect(MsgPack.encode({'a': null}), [0x81, 0xa1, 0x61, 0xc0]);
    expect(MsgPack.encode(4294967296), [0xcf, 0, 0, 0, 1, 0, 0, 0, 0]);
    expect(MsgPack.encode(-4294967296), [0xd3, 0xff, 0xff, 0xff, 0xff, 0, 0, 0, 0]);
  });

  test('lee lo que manda rmp_serde', () {
    // {"status": 422, "ok": false, "f": 1.5} con float32 y uint16.
    final bytes = _b([
      0x83, //
      0xa6, ...'status'.codeUnits, 0xcd, 0x01, 0xa6,
      0xa2, ...'ok'.codeUnits, 0xc2,
      0xa1, ...'f'.codeUnits, 0xca, 0x3f, 0xc0, 0x00, 0x00,
    ]);
    expect(MsgPack.decode(bytes), {'status': 422, 'ok': false, 'f': 1.5});
  });

  test('modelos con toJson', () {
    expect(MsgPack.decode(MsgPack.encode(_Model())), {'a': 1});
    expect(() => MsgPack.encode(DateTime(2026)), throwsArgumentError);
  });

  test('datos rotos', () {
    expect(() => MsgPack.decode(_b([0xa5, 0x61])), throwsFormatException);
    expect(() => MsgPack.decode(_b([0x01, 0x02])), throwsFormatException);
    expect(() => MsgPack.decode(_b([0xd4, 0x00, 0x00])), throwsFormatException);
  });
}

class _Model {
  Map<String, Object?> toJson() => {'a': 1};
}
