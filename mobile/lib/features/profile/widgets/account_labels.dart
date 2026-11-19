import 'package:shared/shared.dart';

import '../../../components/status_chip.dart';

/// Textos de la cuenta que se repiten entre el resumen y la pantalla de autenticación.
abstract final class AccountLabels {
  static String method(TwoFactorMethod method) => switch (method) {
        TwoFactorMethod.email => 'Por correo',
        TwoFactorMethod.whatsapp => 'Por WhatsApp',
        TwoFactorMethod.totp => 'App de autenticación',
      };

  static StatusChip verified(bool verified) => verified
      ? const StatusChip(label: 'Verificado', tone: StatusTone.success)
      : const StatusChip(label: 'Sin verificar', tone: StatusTone.warning);

  static StatusChip twoFactor(TwoFactorMethod? method) => switch (method) {
        null => const StatusChip(label: 'Desactivada', tone: StatusTone.neutral),
        final m => StatusChip(label: AccountLabels.method(m), tone: StatusTone.success),
      };

  static StatusChip google(bool linked) => linked
      ? const StatusChip(label: 'Vinculado', tone: StatusTone.success)
      : const StatusChip(label: 'No vinculado', tone: StatusTone.neutral);

  static StatusChip totp(bool confirmed) => confirmed
      ? const StatusChip(label: 'Configurada', tone: StatusTone.success)
      : const StatusChip(label: 'Sin configurar', tone: StatusTone.neutral);
}
