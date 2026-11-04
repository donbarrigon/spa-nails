use ironforge::{Context, error::validation_error::ValidationError, validator::Validator};
use ironforge_macros::rules;

pub struct UserRegisterValidator {
    pub nickname: String,
    pub email: String,
    pub phone: String,
    pub password: String,
}
impl Validator for UserRegisterValidator {
    fn validate(&mut self, c: &mut Context) -> Result<(), ValidationError> {
        rules! {
            self, c,
            nickname => [ required(), min(3), max(255) ],
            email => [ required(), re_email() ],
            phone => [ required(), re_phone() ],
            password => [ required(), min(8), max(255) ],
        }
    }
}