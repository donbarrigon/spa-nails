use chrono::{NaiveDate, Utc};
use ironforge::{Context, StrFormat, ValidationError, Validator, validator::format::Format};
use ironforge_macros::rules;
use mongodb::bson::DateTime;
use serde::{Deserialize, Serialize};

use crate::app::shared::models::user::{DocumentType, Theme};

/// Datos personales del perfil. Los opcionales llegan como `""` cuando el
/// usuario los deja vacíos; el controller los guarda como `None`.
#[derive(Serialize, Deserialize)]
pub struct UpdateProfileValidator {
    pub nickname: String,
    pub name: String,
    /// `YYYY-MM-DD`.
    #[serde(default)]
    pub birthdate: String,
    #[serde(default)]
    pub document_type: Option<DocumentType>,
    #[serde(default)]
    pub document: String,
    #[serde(default)]
    pub address: String,
    #[serde(default)]
    pub city: String,
}

impl UpdateProfileValidator {
    /// Fecha de nacimiento a medianoche UTC; `None` si no la puso.
    pub fn birthdate(&self) -> Option<DateTime> {
        let date = parse_date(&self.birthdate)?;
        Some(DateTime::from_millis(date.and_hms_opt(0, 0, 0)?.and_utc().timestamp_millis()))
    }
}

impl Validator for UpdateProfileValidator {
    fn prepare_for_validation(&mut self, _: &mut Context) -> Result<(), ValidationError> {
        self.nickname = self.nickname.trim().to_string();
        self.name = collapse_spaces(&self.name).to_title_case_es();
        self.birthdate = self.birthdate.trim().to_string();
        // Sin puntos ni espacios: `1.020.304.050` → `1020304050`.
        self.document = self.document.chars().filter(|c| !matches!(c, '.' | ' ')).collect::<String>().to_uppercase();
        self.address = collapse_spaces(&self.address);
        self.city = collapse_spaces(&self.city).to_title_case_es();
        Ok(())
    }

    fn validate(&mut self, c: &mut Context) -> Result<(), ValidationError> {
        // `rules!` muestra los argumentos en los mensajes: van como texto.
        let document_type = self.document_type.map(DocumentType::code).unwrap_or_default();
        rules! {
            self, c,
            nickname => [ required(), re_username(3, 30) ],
            name => [ required(), re_alpha_spaces(), min(3), max(80) ],
            birthdate => [
                birthdate_or_empty().msg("the :field field must be a past date in the format YYYY-MM-DD"),
            ],
            document_type => [
                type_for_document(!self.document.is_empty()).msg("Select the document type"),
            ],
            document => [
                document_for_type(document_type).msg("the :field field does not match the document type"),
            ],
            address => [ max(120) ],
            city => [ alpha_spaces_or_empty().msg("the :field field may only contain letters and spaces"), max(60) ],
        }
    }
}

/// Preferencias de la app. Por ahora solo el tema.
#[derive(Serialize, Deserialize)]
pub struct PreferencesValidator {
    pub theme: Theme,
}

impl Validator for PreferencesValidator {
    fn validate(&mut self, c: &mut Context) -> Result<(), ValidationError> {
        // `theme` ya viene validado por serde: solo acepta "light" o "dark".
        rules! { self, c, }
    }
}

// ===============================================================================
// Reglas
// ===============================================================================

fn collapse_spaces(value: &str) -> String {
    value.split_whitespace().collect::<Vec<_>>().join(" ")
}

/// `YYYY-MM-DD` entre 1900 y hoy.
fn parse_date(value: &str) -> Option<NaiveDate> {
    let date = NaiveDate::parse_from_str(value, "%Y-%m-%d").ok()?;
    let min = NaiveDate::from_ymd_opt(1900, 1, 1)?;
    (date >= min && date <= Utc::now().date_naive()).then_some(date)
}

trait ProfileRules {
    fn birthdate_or_empty(&self) -> bool;
    fn alpha_spaces_or_empty(&self) -> bool;
    /// Vacío si no hay tipo (`""`); con tipo (`"CC"`...), el formato de ese documento.
    fn document_for_type(&self, document_type: &str) -> bool;
}

impl ProfileRules for str {
    fn birthdate_or_empty(&self) -> bool {
        self.is_empty() || parse_date(self).is_some()
    }

    fn alpha_spaces_or_empty(&self) -> bool {
        self.is_empty() || self.re_alpha_spaces()
    }

    fn document_for_type(&self, document_type: &str) -> bool {
        let digits = |min: usize, max: usize| {
            (min..=max).contains(&self.len()) && self.bytes().all(|b| b.is_ascii_digit())
        };
        match document_type {
            "" => self.is_empty(),
            "CC" | "TI" => digits(6, 10),
            "PPT" => digits(6, 12),
            // Con o sin dígito de verificación: `900123456-7`.
            "NIT" => match self.split_once('-') {
                Some((number, dv)) => {
                    (9..=10).contains(&number.len())
                        && number.bytes().all(|b| b.is_ascii_digit())
                        && dv.len() == 1
                        && dv.bytes().all(|b| b.is_ascii_digit())
                }
                None => digits(9, 10),
            },
            "CE" | "PP" => {
                (5..=15).contains(&self.len()) && self.bytes().all(|b| b.is_ascii_alphanumeric())
            }
            _ => false,
        }
    }
}

trait DocumentTypeRules {
    /// Obligatorio si escribió un documento.
    fn type_for_document(&self, has_document: bool) -> bool;
}

impl DocumentTypeRules for Option<DocumentType> {
    fn type_for_document(&self, has_document: bool) -> bool {
        self.is_some() || !has_document
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn documento_segun_el_tipo() {
        assert!("".document_for_type(""));
        assert!(!"123".document_for_type(""));
        assert!("1020304050".document_for_type("CC"));
        assert!(!"10203".document_for_type("CC"));
        assert!(!"AB12345".document_for_type("CC"));
        assert!("900123456-7".document_for_type("NIT"));
        assert!("900123456".document_for_type("NIT"));
        assert!(!"900123456-78".document_for_type("NIT"));
        assert!("AB123456".document_for_type("PP"));
        assert!(!"".document_for_type("PP"));
    }

    #[test]
    fn fecha_de_nacimiento_pasada_y_desde_1900() {
        assert!("".birthdate_or_empty());
        assert!("1990-05-17".birthdate_or_empty());
        assert!(!"1899-12-31".birthdate_or_empty());
        assert!(!"2990-01-01".birthdate_or_empty());
        assert!(!"17/05/1990".birthdate_or_empty());
        assert!(!"1990-02-30".birthdate_or_empty());
    }

    #[test]
    fn ciudad_vacia_o_con_letras() {
        assert!("".alpha_spaces_or_empty());
        assert!("Bogotá".alpha_spaces_or_empty());
        assert!(!"Bogotá 2".alpha_spaces_or_empty());
    }

    #[test]
    fn tipo_obligatorio_solo_con_documento() {
        assert!(None.type_for_document(false));
        assert!(!None.type_for_document(true));
        assert!(Some(DocumentType::Cc).type_for_document(true));
    }
}
