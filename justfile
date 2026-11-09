# Backend en modo desarrollo (en debug fija el cwd a backend/ para env.json y tmp/)
dev:
    cargo run -p spa-nails

# Compila el frontend web a JS dentro de los estáticos del backend
build-web:
    dart compile js -O2 -o backend/static/js/main.js web/web/main.dart

build: build-web
    cargo build --release

codegen:
    echo "TODO: generar openapi y cliente dart"

test:
    cargo test
    cd packages/spa_shared && dart test

movil:
    cd movil && flutter run
