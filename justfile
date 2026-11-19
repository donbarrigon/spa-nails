# Backend en modo desarrollo (en debug fija el cwd a backend/ para env.json y tmp/)
dev:
    cargo run -p spa-nails

# Estáticos de la web en backend/public/resources: CSS minificado, JS de Dart y fuentes
build-web:
    ./build_web.sh

build: build-web
    cargo build --release

codegen:
    echo "TODO: generar openapi y cliente dart"

test:
    cargo test
    cd packages/shared && dart test
    cd packages/client && dart test
    cd mobile && flutter test

# App mobile/escritorio con la configuración de mobile/env.json
mobile *args:
    cd mobile && flutter run --dart-define-from-file=env.json {{args}}
