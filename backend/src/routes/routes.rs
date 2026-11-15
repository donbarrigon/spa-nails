use ironforge::server::Router;

pub fn app_routes() -> Router {
    Router::build("app", |r| {
        r.prefix("/api", |r| {
            r.post(
                "/users/register",
                crate::app::handler::controllers::user::register,
            );
            r.post("/users/login", crate::app::handler::controllers::user::loggin);
            r.post(
                "/users/verify/email",
                crate::app::handler::controllers::user::verify_email,
            );
            r.post(
                "/users/verify/phone",
                crate::app::handler::controllers::user::verify_phone,
            );
        });
    })
}
