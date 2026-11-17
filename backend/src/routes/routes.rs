use ironforge::server::Router;

pub fn app_routes() -> Router {
    Router::build("app", |r| {
        r.prefix("/api", |r| {
            r.post(
                "/users/register",
                crate::app::handler::controllers::user::register,
            );
            r.post("/users/login", crate::app::handler::controllers::user::login);
            r.post(
                "/users/login/two-factor",
                crate::app::handler::controllers::user::login_two_factor,
            );
            r.post(
                "/users/login/two-factor/resend",
                crate::app::handler::controllers::user::resend_two_factor,
            );
            r.post(
                "/users/login/google",
                crate::app::handler::controllers::user::google_login,
            );
            r.post(
                "/users/register/google",
                crate::app::handler::controllers::user::google_register,
            );
            r.post("/users/google", crate::app::handler::controllers::user::link_google);
            r.delete("/users/google", crate::app::handler::controllers::user::unlink_google);
            r.post("/users/logout", crate::app::handler::controllers::user::logout);
            r.post(
                "/users/logout/all",
                crate::app::handler::controllers::user::logout_all,
            );
            r.get("/users/me", crate::app::handler::controllers::user::me);
            r.delete("/users/me", crate::app::handler::controllers::user::delete_account);
            r.get("/users/sessions", crate::app::handler::controllers::user::sessions);
            r.delete(
                "/users/sessions/{id}",
                crate::app::handler::controllers::user::destroy_session,
            );
            r.put(
                "/users/password",
                crate::app::handler::controllers::user::change_password,
            );
            r.post(
                "/users/password/forgot",
                crate::app::handler::controllers::user::forgot_password,
            );
            r.post(
                "/users/password/reset",
                crate::app::handler::controllers::user::reset_password,
            );
            r.post(
                "/users/password/reset/code",
                crate::app::handler::controllers::user::reset_password_code,
            );
            r.post(
                "/users/verify/email/resend",
                crate::app::handler::controllers::user::resend_verify_email,
            );
            r.post(
                "/users/verify/phone/resend",
                crate::app::handler::controllers::user::resend_verify_phone,
            );
            r.delete(
                "/users/email/pending",
                crate::app::handler::controllers::user::cancel_email_change,
            );
            r.delete(
                "/users/phone/pending",
                crate::app::handler::controllers::user::cancel_phone_change,
            );
            r.put(
                "/users/two-factor",
                crate::app::handler::controllers::user::update_two_factor,
            );
            r.delete(
                "/users/two-factor",
                crate::app::handler::controllers::user::disable_two_factor,
            );
            r.post("/users/totp", crate::app::handler::controllers::user::setup_totp);
            r.post(
                "/users/totp/confirm",
                crate::app::handler::controllers::user::confirm_totp,
            );
            r.put("/users/email", crate::app::handler::controllers::user::change_email);
            r.post(
                "/users/email/confirm",
                crate::app::handler::controllers::user::confirm_email_change,
            );
            r.post(
                "/users/email/revert",
                crate::app::handler::controllers::user::revert_email,
            );
            r.put("/users/phone", crate::app::handler::controllers::user::change_phone);
            r.post(
                "/users/phone/confirm",
                crate::app::handler::controllers::user::confirm_phone_change,
            );
            r.post(
                "/users/phone/revert",
                crate::app::handler::controllers::user::revert_phone,
            );
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
