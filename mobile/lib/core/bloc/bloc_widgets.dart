import 'dart:async';

import 'package:flutter/widgets.dart';

import 'bloc.dart';

/// Reconstruye con cada estado del bloc.
class BlocBuilder<S> extends StatelessWidget {
  const BlocBuilder({super.key, required this.bloc, required this.builder});

  final Bloc<Object?, S> bloc;
  final Widget Function(BuildContext context, S state) builder;

  @override
  Widget build(BuildContext context) => StreamBuilder<S>(
        stream: bloc.stream,
        initialData: bloc.state,
        builder: (context, snapshot) => builder(context, snapshot.data as S),
      );
}

/// Ejecuta efectos (navegar, mostrar un mensaje) con cada estado nuevo,
/// sin reconstruir [child].
class BlocListener<S> extends StatefulWidget {
  const BlocListener({
    super.key,
    required this.bloc,
    required this.listener,
    required this.child,
  });

  final Bloc<Object?, S> bloc;
  final void Function(BuildContext context, S state) listener;
  final Widget child;

  @override
  State<BlocListener<S>> createState() => _BlocListenerState<S>();
}

class _BlocListenerState<S> extends State<BlocListener<S>> {
  late StreamSubscription<S> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = _listen();
  }

  StreamSubscription<S> _listen() => widget.bloc.stream.listen((state) {
        if (mounted) widget.listener(context, state);
      });

  @override
  void didUpdateWidget(BlocListener<S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bloc != widget.bloc) {
      _subscription.cancel();
      _subscription = _listen();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
