use ironforge::Server;

use crate::routes::routes::app_routes;
pub mod data;
pub mod handler;
pub mod routes;

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