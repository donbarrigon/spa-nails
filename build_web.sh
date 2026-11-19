#!/usr/bin/env bash
# Arma los estáticos de la web en backend/public/resources (lo que sirve
# GET /resources/*). Provisional para hacer pruebas: después pasa al CLI.
#
#   css/main.css      ← backend/src/app/ui/css/main.css + components/*.css
#   css/<módulo>.css  ← backend/src/app/ui/css/<módulo>/*.css   (auth, home, profile)
#   js/<módulo>.js    ← web/web/<módulo>.dart compilado con dart2js   (app, auth, profile)
#   fonts/*.ttf       ← mobile/assets/fonts
#
# Uso: ./build_web.sh          (desde cualquier carpeta)
#      ./build_web.sh css      (solo CSS, sin compilar el Dart)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSS_SRC="$ROOT/backend/src/app/ui/css"
DART_SRC="$ROOT/web/web"
FONTS_SRC="$ROOT/mobile/assets/fonts"
OUT="$ROOT/backend/public/resources"

# Minifica CSS de stdin a stdout: quita comentarios, saltos de línea y los
# espacios que sobran alrededor de { } : ; , > (no toca + ni -, que importan en calc()).
minify_css() {
  perl -0777 -pe '
    s{/\*.*?\*/}{}gs;
    s/\s+/ /g;
    s/\s*([{};,>])\s*/$1/g;
    s/\s*:\s*/:/g;
    s/;}/}/g;
    s/^\s+|\s+$//g;
  '
}

build_css() {
  mkdir -p "$OUT/css"
  cat "$CSS_SRC/main.css" "$CSS_SRC"/components/*.css | minify_css > "$OUT/css/main.css"
  echo "css/main.css"
  for dir in "$CSS_SRC"/*/; do
    local module
    module="$(basename "$dir")"
    [ "$module" = components ] && continue
    cat "$dir"*.css | minify_css > "$OUT/css/$module.css"
    echo "css/$module.css"
  done
}

build_js() {
  mkdir -p "$OUT/js"
  for entry in "$DART_SRC"/*.dart; do
    local module
    module="$(basename "$entry" .dart)"
    (cd "$ROOT/web" && dart compile js -O2 --no-source-maps -o "$OUT/js/$module.js" "$entry" >/dev/null)
    rm -f "$OUT/js/$module.js.deps" "$OUT/js/$module.js.map"
    echo "js/$module.js"
  done
}

copy_fonts() {
  mkdir -p "$OUT/fonts"
  cp "$FONTS_SRC"/*.ttf "$OUT/fonts/"
  echo "fonts/ ($(ls "$FONTS_SRC"/*.ttf | wc -l) archivos)"
}

build_css
copy_fonts
if [ "${1:-}" != css ]; then
  build_js
fi
echo "Listo: $OUT"
