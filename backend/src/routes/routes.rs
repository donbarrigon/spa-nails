use ironforge::server::{Router};

pub fn app_routes() -> Router {
    Router::build("app", |r|{
        r.prefix("/api", |r| {
            r.get("/users/register", crate::api::handler::controllers::user::register);
        });
    })
}