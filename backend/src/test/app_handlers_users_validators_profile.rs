use mongodb::bson::DateTime;

use crate::app::handlers::users::validators::profile::UpdateProfileValidator;

fn form(birthdate: &str) -> UpdateProfileValidator {
    UpdateProfileValidator {
        nickname: "ana.perez".into(),
        name: "Ana Pérez".into(),
        birthdate: birthdate.into(),
        document_type: None,
        document: String::new(),
        address: String::new(),
        city: String::new(),
    }
}

#[test]
fn birthdate_es_medianoche_utc() {
    let expected = DateTime::parse_rfc3339_str("1990-05-17T00:00:00Z").unwrap();
    assert_eq!(form("1990-05-17").birthdate(), Some(expected));
}

#[test]
fn birthdate_vacia_o_invalida_es_none() {
    assert_eq!(form("").birthdate(), None);
    assert_eq!(form("1990-02-30").birthdate(), None);
}
