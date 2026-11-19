use ironforge::{Context, ForgeError};

use crate::app::shared::resources::session_user::SessionUser;

/// Exige sesión iniciada (401 si no la hay). Deja el `Auth<SessionUser>` en el
/// contexto, así el `c.auth::<SessionUser>()` del controller no vuelve a buscarlo.
pub async fn auth(c: &mut Context) -> Result<(), ForgeError> {
    c.auth::<SessionUser>().await?;
    Ok(())
}
