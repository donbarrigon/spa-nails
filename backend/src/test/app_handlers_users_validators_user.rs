use crate::app::handlers::users::validators::user::RegisterAvailableValidator;

fn form(nickname: &str, email: &str, phone: &str) -> RegisterAvailableValidator {
    RegisterAvailableValidator { nickname: nickname.into(), email: email.into(), phone: phone.into() }
}

#[test]
fn register_available_cuenta_los_campos_con_valor() {
    assert_eq!(form("", "", "").filled(), 0);
    assert_eq!(form("ana.perez", "", "").filled(), 1);
    assert_eq!(form("", "ana@correo.com", "+573001234567").filled(), 2);
}
