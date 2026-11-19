import 'bson.dart';
import 'profile.dart';
import 'two_factor.dart';

/// Usuario de la sesión, tal como lo responde el backend (`SessionUser`).
/// Sin credenciales: ni contraseña, ni secreto TOTP, ni el `sub` de Google.
final class SessionUser {
  const SessionUser({
    required this.id,
    required this.nickname,
    required this.name,
    required this.avatar,
    this.banner = '',
    this.birthdate,
    this.documentType,
    this.document,
    this.address,
    this.city,
    this.preferences = const {},
    required this.email,
    required this.phone,
    this.pendingEmail,
    this.pendingPhone,
    this.emailVerifiedAt,
    this.phoneVerifiedAt,
    this.twoFactor,
    this.totpConfirmedAt,
    this.googleLinked = false,
    this.roles = const [],
    this.permissions = const [],
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String nickname;
  final String name;
  final String avatar;
  final String banner;

  /// Medianoche UTC del día de nacimiento: leer con `.toUtc()`, no `.toLocal()`.
  final DateTime? birthdate;
  final DocumentType? documentType;
  final String? document;
  final String? address;
  final String? city;

  /// `profile.preferences` del backend, ej. `{"theme": "dark"}`.
  final Map<String, Object?> preferences;

  final String email;

  /// Con código de país, ej. `+573001234567`.
  final String phone;

  /// Email o teléfono nuevo que espera confirmación.
  final String? pendingEmail;
  final String? pendingPhone;

  final DateTime? emailVerifiedAt;
  final DateTime? phoneVerifiedAt;

  /// Método preferido del segundo factor; `null` si no lo tiene activo.
  final TwoFactorMethod? twoFactor;
  final DateTime? totpConfirmedAt;
  final bool googleLinked;
  final List<String> roles;
  final List<String> permissions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get emailVerified => emailVerifiedAt != null;
  bool get phoneVerified => phoneVerifiedAt != null;

  /// `null` si no eligió: sigue el tema del dispositivo.
  ThemePreference? get theme => ThemePreference.tryParse(preferences['theme']);

  factory SessionUser.fromJson(Map<String, Object?> json) => SessionUser(
        id: readId(json['id']),
        nickname: json['nickname'] as String,
        name: json['name'] as String,
        avatar: json['avatar'] as String? ?? '',
        banner: json['banner'] as String? ?? '',
        birthdate: readDateOrNull(json['birthdate']),
        documentType: DocumentType.tryParse(json['document_type']),
        document: json['document'] as String?,
        address: json['address'] as String?,
        city: json['city'] as String?,
        preferences: switch (json['preferences']) {
          final Map<String, Object?> map => map,
          _ => const {},
        },
        email: json['email'] as String,
        phone: json['phone'] as String,
        pendingEmail: json['pending_email'] as String?,
        pendingPhone: json['pending_phone'] as String?,
        emailVerifiedAt: readDateOrNull(json['email_verified_at']),
        phoneVerifiedAt: readDateOrNull(json['phone_verified_at']),
        twoFactor: TwoFactorMethod.tryParse(json['two_factor']),
        totpConfirmedAt: readDateOrNull(json['totp_confirmed_at']),
        googleLinked: json['google_linked'] as bool? ?? false,
        roles: _strings(json['roles']),
        permissions: _strings(json['permissions']),
        createdAt: readDate(json['created_at']),
        updatedAt: readDate(json['updated_at']),
        deletedAt: readDateOrNull(json['deleted_at']),
      );

  static List<String> _strings(Object? value) =>
      (value as List<Object?>? ?? const []).cast<String>();
}
