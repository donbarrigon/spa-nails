use ironforge::{Context, ValidationError, Validator};
use ironforge_macros::rules;
use serde::{Deserialize, Serialize};

use super::phone_codes::PHONE_CODES;

#[derive(Serialize, Deserialize)]
pub struct UserRegisterValidator {
    pub nickname: String,
    pub email: String,
    pub phone_code: String,
    pub phone: String,
    pub password: String,
    #[serde(default)]
    pub remember: bool,
}
impl Validator for UserRegisterValidator {
    fn validate(&mut self, c: &mut Context) -> Result<(), ValidationError> {
        rules! {
            self, c,
            nickname => [ required(), re_username(3, 30) ],
            email => [ required(), re_email() ],
            phone_code => [ required(), is_in(PHONE_CODES) ],
            phone => [ required(), re_phone() ],
            password => [ required(), min(8), max(32) ],
        }
    }
}
