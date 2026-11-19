import 'package:web/web.dart' as web;

/// El `AppButton` del HTML: muestra el indicador y se desactiva mientras dura la acción.
final class AppButton {
  AppButton(this.element);

  final web.Element element;

  set loading(bool loading) {
    element
      ..classList.toggle('app-button--loading', loading)
      ..toggleAttribute('disabled', loading)
      ..setAttribute('aria-busy', '$loading');
  }
}
