import 'package:client/client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared/shared.dart';
import 'package:spa_nails_mobile/components/info_panel.dart';
import 'package:spa_nails_mobile/core/bloc/bloc_provider.dart';
import 'package:spa_nails_mobile/core/deps.dart';
import 'package:spa_nails_mobile/core/google_auth.dart';
import 'package:spa_nails_mobile/core/session_storage.dart';
import 'package:spa_nails_mobile/core/theme/app_theme.dart';
import 'package:spa_nails_mobile/features/auth/session/session_bloc.dart';
import 'package:spa_nails_mobile/features/profile/profile_page.dart';

final _user = SessionUser(
  id: '6650f0c2a1b2c3d4e5f60718',
  nickname: 'ana.perez',
  name: 'Ana María Pérez',
  avatar: '',
  email: 'ana@correo.com',
  phone: '+573001234567',
  pendingPhone: '+573009876543',
  emailVerifiedAt: DateTime.utc(2026, 11, 1),
  twoFactor: TwoFactorMethod.email,
  birthdate: DateTime.utc(1990, 5, 17),
  documentType: DocumentType.cc,
  document: '1020304050',
  city: 'Bogotá',
  createdAt: DateTime.utc(2026, 11, 1),
  updatedAt: DateTime.utc(2026, 11, 1),
);

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final api = ApiClient(
    baseUrl: Uri.parse('https://api.test'),
    httpClient: MockClient((_) async => http.Response('', 500)),
  );
  final session = SessionBloc(
    api: api,
    userApi: UserApi(api),
    storage: SessionStorage(),
    google: GoogleAuth(),
  )..add(SessionStarted(_user, remember: false));

  await tester.pumpWidget(AppDeps(
    api: api,
    userApi: UserApi(api),
    profileApi: ProfileApi(api),
    google: GoogleAuth(),
    sessionStorage: SessionStorage(),
    child: BlocProvider<SessionBloc>(
      create: () => session,
      child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: ProfilePage())),
    ),
  ));
  // `SessionStarted` toca el almacén seguro (un canal de plataforma): fuera del reloj falso.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

void main() {
  for (final (name, size) in [('celular', const Size(360, 780)), ('escritorio', const Size(1280, 800))]) {
    testWidgets('las cuatro pantallas se dibujan en $name', (tester) async {
      await _pump(tester, size);
      expect(find.text('Ana María Pérez'), findsWidgets);

      for (final tab in ProfileTab.values.skip(1)) {
        // Barra inferior (etiqueta corta) o panel lateral (título).
        final target = size.width < 840 ? tab.shortLabel : tab.title;
        await tester.tap(find.text(target).last);
        await tester.pumpAndSettle();
        expect(find.text(tab.title), findsWidgets);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Editar del resumen lleva a la pantalla del grupo', (tester) async {
    await _pump(tester, const Size(360, 780));
    final panel = find.ancestor(of: find.text('Datos personales'), matching: find.byType(InfoPanel));
    await tester.scrollUntilVisible(panel, 200);
    await tester.tap(find.descendant(of: panel, matching: find.text('Editar')));
    await tester.pumpAndSettle();
    expect(find.text('Guardar cambios'), findsOneWidget);
  });
}
