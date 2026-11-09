use ironforge::Server;

use crate::shared::routes::routes::app_routes;
pub mod shared;
pub mod api;

#[tokio::main]
async fn main() {
    // ironforge lee `env.json` y `./tmp/{logs,certs}` relativos al directorio actual.
    // En desarrollo fijamos el cwd al crate para que `cargo run -p spa-nails` funcione
    // desde la raíz del monorepo. En release se respeta el cwd del proceso.
    #[cfg(debug_assertions)]
    std::env::set_current_dir(env!("CARGO_MANIFEST_DIR"))
        .expect("no se pudo cambiar al directorio del crate");

    if let Err(e) = Server::start(app_routes()).await {
        eprintln!("Error al iniciar el servidor: {e}");
        std::process::exit(1);
    }
}