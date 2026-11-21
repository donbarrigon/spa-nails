use ironforge::handler::resources;
use ironforge::middleware::{rate_limit_group, rate_limit_ip};
use ironforge::server::Router;

use crate::app::handlers::home::controllers::home;
use crate::app::handlers::users::controllers::{auth, auth_page, profile, profile_page};

pub fn app_routes() -> Router {
    Router::build("app", |r| {
        // Web: páginas HTML (Askama) y sus estáticos (public/resources).
        r.get("/", home::home);
        r.get("/login", auth_page::login_page);
        r.get("/register", auth_page::register_page);
        r.get("/verify-email", auth_page::verify_email_page);
        r.get("/forgot-password", auth_page::forgot_password_page);
        r.get("/reset-password", auth_page::reset_password_page);
        r.prefix("/profile", |r| {
            r.get("/", profile_page::overview);
            r.get("/account", profile_page::account);
            r.get("/personal", profile_page::personal);
            r.get("/preferences", profile_page::preferences);
        });
        r.get("/resources/*", resources::serve);

        r.prefix("/api", |r| {
            // Rutas que hashean o verifican contraseñas con argon2 (caras en CPU/RAM).
            r.group("/users/auth", rate_limit_ip(4, 60), |r| {
                r.post("/register", auth::register);
                r.post("/register/google", auth::google_register);
                r.post("/login", auth::login);
                r.put("/password", auth::change_password);
                r.post("/password/reset", auth::reset_password);
                r.post("/password/reset/code", auth::reset_password_code);
                r.put("/two-factor", auth::update_two_factor);
                r.delete("/two-factor", auth::disable_two_factor);
                r.post("/totp", auth::setup_totp);
                r.post("/google", auth::link_google);
                r.delete("/google", auth::unlink_google);
                r.put("/email", auth::change_email);
                r.put("/phone", auth::change_phone);
                r.delete("/me", auth::delete_account);
            });

            // Resto de rutas de usuarios. Un solo límite compartido entre los dos grupos.
            r.group("/users/profile", rate_limit_group(30, 60, "users"), |r| {
                r.put("/", profile::update);
                r.put("/preferences", profile::update_preferences);
            });
            r.group("/users/auth", rate_limit_group(30, 60, "users"), |r| {
                r.post("/login/two-factor", auth::login_two_factor);
                r.post("/login/two-factor/resend", auth::resend_two_factor);
                r.post("/login/google", auth::google_login);
                r.post("/register/available", auth::register_available);
                r.post("/logout", auth::logout);
                r.post("/logout/all", auth::logout_all);
                r.get("/me", auth::me);
                r.get("/sessions", auth::sessions);
                r.delete("/sessions/{id}", auth::destroy_session);
                r.post("/password/forgot", auth::forgot_password);
                r.post("/verify/email/resend", auth::resend_verify_email);
                r.post("/verify/phone/resend", auth::resend_verify_phone);
                r.delete("/email/pending", auth::cancel_email_change);
                r.delete("/phone/pending", auth::cancel_phone_change);
                r.post("/totp/confirm", auth::confirm_totp);
                r.post("/email/confirm", auth::confirm_email_change);
                r.post("/email/revert", auth::revert_email);
                r.post("/phone/confirm", auth::confirm_phone_change);
                r.post("/phone/revert", auth::revert_phone);
                r.post("/verify/email", auth::verify_email);
                r.post("/verify/phone", auth::verify_phone);
            });
        });
    })
}
