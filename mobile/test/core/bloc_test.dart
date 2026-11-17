import 'package:flutter_test/flutter_test.dart';
import 'package:spa_nails_mobile/core/bloc/bloc.dart';

/// Cada evento tarda distinto: si se procesaran en paralelo, el orden cambiaría.
class _DelayBloc extends Bloc<int, String> {
  _DelayBloc() : super('idle');

  @override
  Stream<String> mapEventToState(int ms) async* {
    yield 'start $ms';
    await Future<void>.delayed(Duration(milliseconds: ms));
    yield 'end $ms';
  }
}

void main() {
  test('procesa los eventos de a uno y en orden', () async {
    final bloc = _DelayBloc();
    final states = <String>[];
    bloc.stream.listen(states.add);

    bloc
      ..add(30)
      ..add(1);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(states, ['start 30', 'end 30', 'start 1', 'end 1']);
    expect(bloc.state, 'end 1');
    await bloc.dispose();
  });

  test('después de dispose ignora eventos', () async {
    final bloc = _DelayBloc();
    await bloc.dispose();
    bloc.add(1);
    expect(bloc.isClosed, isTrue);
  });
}
