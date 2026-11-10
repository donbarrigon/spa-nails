use ironforge::{Context, ForgeError, ODModel};

use crate::{
    api::handler::validators::user::UserRegisterValidator,
    shared::models::{
        history::{ActionType::Create, History},
        user::User,
    },
};

pub async fn register(c: &mut Context) -> Result<(), ForgeError> {
    let req = c.get_body::<UserRegisterValidator>().await?;

    let mut user = User::fill_register(req);

    user.create().await?;

    History::record(c, user, None, Create, Some("User register")).await?;

    Ok(())
}
