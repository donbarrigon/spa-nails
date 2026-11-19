use mongodb::bson::{DateTime, oid::ObjectId};

use super::init_env;
use crate::app::{
    handlers::users::validators::user::UserRegisterValidator,
    shared::{models::user::User, services::totp},
};

fn user() -> User {
    init_env();
    let mut user = User::fill_register(UserRegisterValidator {
        nickname: "ana".into(),
        name: "Ana".into(),
        email: "ana@mail.com".into(),
        phone: "+573001234567".into(),
        password: "secret123".into(),
        remember: false,
    });
    user.id = Some(ObjectId::new());
    user
}

#[test]
fn generate_secret_cifra_y_reinicia_la_confirmacion() {
    let mut u = user();
    u.totp_confirmed_at = Some(DateTime::now());
    u.totp_last_step = Some(10);

    totp::generate_secret(&mut u).unwrap();

    let stored = u.totp_secret.clone().unwrap();
    let plain = totp::secret(&u).unwrap();
    assert!(stored.starts_with("v1:"), "{stored}");
    assert!(!stored.contains(&plain));
    assert_eq!(plain.len(), 32); // 20 bytes en Base32
    assert!(u.totp_confirmed_at.is_none());
    assert!(u.totp_last_step.is_none());

    totp::generate_secret(&mut u).unwrap();
    assert_ne!(totp::secret(&u).unwrap(), plain);
}

#[test]
fn url_qr_y_codigo() {
    let mut u = user();
    totp::generate_secret(&mut u).unwrap();

    let url = totp::url(&u).unwrap();
    assert!(url.starts_with("otpauth://totp/MR%20nails:ana%40mail.com?"), "{url}");
    assert!(url.contains(&format!("secret={}", totp::secret(&u).unwrap())));

    assert!(!totp::qr(&u).unwrap().is_empty());

    let code = totp::code(&u).unwrap();
    assert_eq!(code.len(), 6);
    assert!(code.chars().all(|c| c.is_ascii_digit()));
}

#[test]
fn secreto_de_otro_usuario_no_se_descifra() {
    let mut a = user();
    totp::generate_secret(&mut a).unwrap();

    let mut b = user();
    b.totp_secret = a.totp_secret.clone();
    assert!(totp::secret(&b).is_err());
    assert!(totp::code(&b).is_err());
}

#[test]
fn secreto_alterado_no_se_descifra() {
    let mut u = user();
    totp::generate_secret(&mut u).unwrap();

    let mut stored = u.totp_secret.clone().unwrap();
    let last = stored.pop().unwrap();
    stored.push(if last == '0' { '1' } else { '0' });
    u.totp_secret = Some(stored);
    assert!(totp::secret(&u).is_err());
}

#[test]
fn sin_secreto_falla() {
    let u = user();
    assert!(totp::url(&u).is_err());
    assert!(totp::code(&u).is_err());
}
