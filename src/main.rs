use ironforge::Server;

use crate::shared::routes::routes::app_routes;
pub mod shared;
pub mod api;

#[tokio::main]
async fn main() {
    if let Err(e) = Server::start(app_routes()).await {
        eprintln!("Error al iniciar el servidor: {e}");
        std::process::exit(1);
    }
}