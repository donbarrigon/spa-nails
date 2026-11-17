import 'dart:async';

/// Base del patrón BLoC sin librerías: entran eventos con [add] y salen
/// estados por [stream].
///
/// Los eventos se procesan de a uno y en orden (`asyncExpand`): un evento no
/// empieza hasta que el anterior terminó de emitir sus estados.
abstract class Bloc<E, S> {
  Bloc(S initial) : _state = initial {
    _subscription = _events.stream
        .asyncExpand(mapEventToState)
        .listen(_emit, onError: (Object e, StackTrace st) => Zone.current.handleUncaughtError(e, st));
  }

  final _events = StreamController<E>();
  final _states = StreamController<S>.broadcast();
  late final StreamSubscription<S> _subscription;
  S _state;

  S get state => _state;
  Stream<S> get stream => _states.stream;
  bool get isClosed => _states.isClosed;

  void add(E event) {
    if (!_events.isClosed) _events.add(event);
  }

  /// Traduce un evento a cero o más estados (`async*` + `yield`).
  Stream<S> mapEventToState(E event);

  void _emit(S state) {
    if (_states.isClosed) return;
    _state = state;
    _states.add(state);
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _events.close();
    await _states.close();
  }
}
