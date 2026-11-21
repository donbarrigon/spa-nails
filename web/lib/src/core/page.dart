import 'package:client/client.dart';
import 'package:web/web.dart' as web;

/// Token CSRF que el servidor pone en `<meta name="csrf-token">` de cada página.
String get csrfToken => web.document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') ?? '';

/// Request a la API del mismo sitio: MessagePack, la cookie de sesión del
/// navegador y el token CSRF en `x-csrf-token`.
Future<ApiResponse> api(String path, {String method = 'POST', Object? body}) =>
    fetch(path, method: method, body: body, headers: {'x-csrf-token': csrfToken});

/// Navega a otra página del sitio.
void go(String path) => web.window.location.assign(path);

/// Primer elemento de [selector] dentro de [root] (o del documento).
web.Element? query(String selector, [web.Element? root]) =>
    root == null ? web.document.querySelector(selector) : root.querySelector(selector);

/// Todos los elementos de [selector] dentro de [root] (o del documento).
List<web.Element> queryAll(String selector, [web.Element? root]) {
  final nodes = root == null ? web.document.querySelectorAll(selector) : root.querySelectorAll(selector);
  return [for (var i = 0; i < nodes.length; i++) nodes.item(i)! as web.Element];
}

/// En las páginas con pasos: muestra el hijo de [root] con `data-state="[state]"`
/// y oculta los demás.
void showState(web.Element root, String state) {
  for (final section in queryAll('[data-state]', root)) {
    section.toggleAttribute('hidden', section.getAttribute('data-state') != state);
  }
}
