use ironforge::server::Router;

pub fn app_routes() -> Router {
    Router::build("app", |r| {
        r.prefix("/api", |r| {
            r.post(
                "/users/register",
                crate::app::handlers::users::controllers::user::register,
            );
            r.post("/users/login", crate::app::handlers::users::controllers::user::login);
            r.post(
                "/users/login/two-factor",
                crate::app::handlers::users::controllers::user::login_two_factor,
            );
            r.post(
                "/users/login/two-factor/resend",
                crate::app::handlers::users::controllers::user::resend_two_factor,
            );
            r.post(
                "/users/login/google",
                crate::app::handlers::users::controllers::user::google_login,
            );
            r.post(
                "/users/register/google",
                crate::app::handlers::users::controllers::user::google_register,
            );
            r.post("/users/google", crate::app::handlers::users::controllers::user::link_google);
            r.delete("/users/google", crate::app::handlers::users::controllers::user::unlink_google);
            r.post("/users/logout", crate::app::handlers::users::controllers::user::logout);
            r.post(
                "/users/logout/all",
                crate::app::handlers::users::controllers::user::logout_all,
            );
            r.get("/users/me", crate::app::handlers::users::controllers::user::me);
            r.delete("/users/me", crate::app::handlers::users::controllers::user::delete_account);
            r.get("/users/sessions", crate::app::handlers::users::controllers::user::sessions);
            r.delete(
                "/users/sessions/{id}",
                crate::app::handlers::users::controllers::user::destroy_session,
            );
            r.put(
                "/users/password",
                crate::app::handlers::users::controllers::user::change_password,
            );
            r.post(
                "/users/password/forgot",
                crate::app::handlers::users::controllers::user::forgot_password,
            );
            r.post(
                "/users/password/reset",
                crate::app::handlers::users::controllers::user::reset_password,
            );
            r.post(
                "/users/password/reset/code",
                crate::app::handlers::users::controllers::user::reset_password_code,
            );
            r.post(
                "/users/verify/email/resend",
                crate::app::handlers::users::controllers::user::resend_verify_email,
            );
            r.post(
                "/users/verify/phone/resend",
                crate::app::handlers::users::controllers::user::resend_verify_phone,
            );
            r.delete(
                "/users/email/pending",
                crate::app::handlers::users::controllers::user::cancel_email_change,
            );
            r.delete(
                "/users/phone/pending",
                crate::app::handlers::users::controllers::user::cancel_phone_change,
            );
            r.put(
                "/users/two-factor",
                crate::app::handlers::users::controllers::user::update_two_factor,
            );
            r.delete(
                "/users/two-factor",
                crate::app::handlers::users::controllers::user::disable_two_factor,
            );
            r.post("/users/totp", crate::app::handlers::users::controllers::user::setup_totp);
            r.post(
                "/users/totp/confirm",
                crate::app::handlers::users::controllers::user::confirm_totp,
            );
            r.put("/users/email", crate::app::handlers::users::controllers::user::change_email);
            r.post(
                "/users/email/confirm",
                crate::app::handlers::users::controllers::user::confirm_email_change,
            );
            r.post(
                "/users/email/revert",
                crate::app::handlers::users::controllers::user::revert_email,
            );
            r.put("/users/phone", crate::app::handlers::users::controllers::user::change_phone);
            r.post(
                "/users/phone/confirm",
                crate::app::handlers::users::controllers::user::confirm_phone_change,
            );
            r.post(
                "/users/phone/revert",
                crate::app::handlers::users::controllers::user::revert_phone,
            );
            r.post(
                "/users/verify/email",
                crate::app::handlers::users::controllers::user::verify_email,
            );
            r.post(
                "/users/verify/phone",
                crate::app::handlers::users::controllers::user::verify_phone,
            );
        });
    })
}
