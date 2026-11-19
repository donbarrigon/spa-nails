import 'package:client/client.dart';
import 'package:flutter/widgets.dart';

import 'google_auth.dart';
import 'session_storage.dart';

/// Servicios de la app, disponibles para crear los blocs: `AppDeps.of(context)`.
class AppDeps extends InheritedWidget {
  const AppDeps({
    super.key,
    required this.api,
    required this.userApi,
    required this.profileApi,
    required this.google,
    required this.sessionStorage,
    required super.child,
  });

  final ApiClient api;
  final UserApi userApi;
  final ProfileApi profileApi;
  final GoogleAuth google;
  final SessionStorage sessionStorage;

  static AppDeps of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppDeps>()!;

  @override
  bool updateShouldNotify(AppDeps oldWidget) => false;
}
