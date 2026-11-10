use ironforge::{Context, ForgeError, ODModel};

use crate::{
    data::{
        models::{
            history::{ActionType::Create, History},
            user::User,
        },
        resources::session_user::SessionUser,
    },
    handler::validators::user::UserRegisterValidator,
};

pub async fn register(c: &mut Context) -> Result<(), ForgeError> {
    let req = c.get_body::<UserRegisterValidator>().await?;

    let remember = req.remember;
    let mut user = User::fill_register(req);

    user.create().await?;
    let su = SessionUser::try_from(&user)?;
    let auth = c.login(su, remember).await?;

    History::record(c, user, None, Create, Some("User register")).await;

    c.response_created(&*auth.user)
}

pub async fn loggin(_: &mut Context) -> Result<(), ForgeError> {
    Ok(())
}
