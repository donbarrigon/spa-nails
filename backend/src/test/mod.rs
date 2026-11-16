//! Tests de la API pública, uno por archivo: `<módulo>_<archivo>.rs`
//! (ej. `app/data/models/user.rs` → `app_data_models_user.rs`).
//! Los tests de funciones privadas van en su propio archivo (`#[cfg(test)] mod tests`).

mod app_handler_services_totp;

/// Carga `env.json` una sola vez para los tests que lo necesitan (ej. `ForgeError`
/// o lo que use `app.key`). `cargo test` corre desde `backend/`, donde está el archivo.
pub fn init_env() {
    static ONCE: std::sync::Once = std::sync::Once::new();
    ONCE.call_once(|| ironforge::load_env().expect("failed to load env.json for tests"));
}
