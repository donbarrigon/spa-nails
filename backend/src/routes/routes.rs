use ironforge::server::Router;

use crate::app::handlers::users::controllers::auth;

pub fn app_routes() -> Router {
    Router::build("app", |r| {
        r.prefix("/api", |r| {
            r.prefix("/users/auth", |r| {
                r.post("/register", auth::register);
                r.post("/login", auth::login);
                r.post("/login/two-factor", auth::login_two_factor);
                r.post("/login/two-factor/resend", auth::resend_two_factor);
                r.post("/login/google", auth::google_login);
                r.post("/register/google", auth::google_register);
                r.post("/google", auth::link_google);
                r.delete("/google", auth::unlink_google);
                r.post("/logout", auth::logout);
                r.post("/logout/all", auth::logout_all);
                r.get("/me", auth::me);
                r.delete("/me", auth::delete_account);
                r.get("/sessions", auth::sessions);
                r.delete("/sessions/{id}", auth::destroy_session);
                r.put("/password", auth::change_password);
                r.post("/password/forgot", auth::forgot_password);
                r.post("/password/reset", auth::reset_password);
                r.post("/password/reset/code", auth::reset_password_code);
                r.post("/verify/email/resend", auth::resend_verify_email);
                r.post("/verify/phone/resend", auth::resend_verify_phone);
                r.delete("/email/pending", auth::cancel_email_change);
                r.delete("/phone/pending", auth::cancel_phone_change);
                r.put("/two-factor", auth::update_two_factor);
                r.delete("/two-factor", auth::disable_two_factor);
                r.post("/totp", auth::setup_totp);
                r.post("/totp/confirm", auth::confirm_totp);
                r.put("/email", auth::change_email);
                r.post("/email/confirm", auth::confirm_email_change);
                r.post("/email/revert", auth::revert_email);
                r.put("/phone", auth::change_phone);
                r.post("/phone/confirm", auth::confirm_phone_change);
                r.post("/phone/revert", auth::revert_phone);
                r.post("/verify/email", auth::verify_email);
                r.post("/verify/phone", auth::verify_phone);
            });
        });
    })
}
