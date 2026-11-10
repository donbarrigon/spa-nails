use ironforge::server::Router;

pub fn app_routes() -> Router {
    Router::build("app", |r| {
        r.prefix("/api", |r| {
            r.post(
                "/users/register",
                crate::handler::controllers::user::register,
            );
            r.post("/users/login", crate::handler::controllers::user::loggin);
        });
    })
}
