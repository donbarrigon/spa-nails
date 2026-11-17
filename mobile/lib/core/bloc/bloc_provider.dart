import 'package:flutter/widgets.dart';

import 'bloc.dart';

/// Crea un bloc, lo pone disponible para el subárbol y lo cierra al salir.
/// Se lee con `BlocProvider.of<MiBloc>(context)`.
class BlocProvider<B extends Bloc<Object?, Object?>> extends StatefulWidget {
  const BlocProvider({super.key, required this.create, required this.child});

  final B Function() create;
  final Widget child;

  static B of<B extends Bloc<Object?, Object?>>(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<_BlocScope<B>>();
    assert(scope != null, 'No hay un BlocProvider<$B> encima de este widget');
    return scope!.bloc;
  }

  @override
  State<BlocProvider<B>> createState() => _BlocProviderState<B>();
}

class _BlocProviderState<B extends Bloc<Object?, Object?>> extends State<BlocProvider<B>> {
  late final B _bloc = widget.create();

  @override
  void dispose() {
    _bloc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _BlocScope<B>(bloc: _bloc, child: widget.child);
}

class _BlocScope<B extends Bloc<Object?, Object?>> extends InheritedWidget {
  const _BlocScope({required this.bloc, required super.child});

  final B bloc;

  @override
  bool updateShouldNotify(_BlocScope<B> oldWidget) => false;
}
