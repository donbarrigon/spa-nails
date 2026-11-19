use serde_json::{Value, json};

use crate::app::data::models::user::Profile;

fn profile(preferences: Value) -> Profile {
    Profile {
        avatar: Profile::DEFAULT_AVATAR.to_string(),
        banner: Profile::DEFAULT_BANNER.to_string(),
        name: "Ana".to_string(),
        birthdate: None,
        document_type: None,
        document: None,
        address: None,
        city: None,
        preferences,
    }
}

#[test]
fn preference_returns_value_converted_to_type() {
    let p = profile(json!({ "dark_mode": true, "language": "es", "favorites": [1, 2] }));
    assert_eq!(p.preference::<bool>("dark_mode"), Some(true));
    assert_eq!(p.preference::<String>("language"), Some("es".to_string()));
    assert_eq!(p.preference::<Vec<u32>>("favorites"), Some(vec![1, 2]));
}

#[test]
fn preference_is_none_when_missing_or_wrong_type() {
    let p = profile(json!({ "dark_mode": true }));
    assert_eq!(p.preference::<bool>("language"), None);
    assert_eq!(p.preference::<String>("dark_mode"), None);
}

#[test]
fn preference_is_none_when_field_absent_in_stored_document() {
    // Usuarios guardados antes de existir `preferences`: serde lo deja en `Null`.
    let p: Profile = serde_json::from_value(json!({
        "avatar": "a", "banner": "b", "name": "Ana",
        "birthdate": null, "document_type": null, "document": null,
        "address": null, "city": null,
    }))
    .unwrap();
    assert_eq!(p.preference::<bool>("dark_mode"), None);
}
