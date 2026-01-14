#!/bin/sh
set -eu

# --- Chemins attendus par l'image ryshe/terraria (Dockerfile) ---
WORLD_DIR="/root/.local/share/Terraria/Worlds"
mkdir -p "$WORLD_DIR"

# --- Variables (avec valeurs par défaut raisonnables) ---
: "${WORLD_FILENAME:=world.wld}"      # recommandé par l'image pour charger un monde existant :contentReference[oaicite:2]{index=2}
: "${WORLD_SIZE:=2}"                 # 1=Small, 2=Medium, 3=Large (utilisé avec -autocreate) :contentReference[oaicite:3]{index=3}
: "${MAXPLAYERS:=8}"
: "${PASSWORD:=}"
: "${MOTD:=}"

# Port : Terraria écoute en 7777 par défaut. Sur Railway, ne changez PAS si vous utilisez le TCP Proxy sur 7777.
PORT_ARG="${GAME_PORT:-7777}"

WORLD_PATH="${WORLD_DIR}/${WORLD_FILENAME}"

# --- Nettoyage des arguments pour éviter les doublons (-world/-configpath/-logpath) ---
# (Le bootstrap de l'image peut déjà définir ces options ; si elles sont aussi dans $@, Terraria/TShock plante.)
SANITIZED_ARGS=""
skip_next=0
for a in "$@"; do
  if [ "$skip_next" -eq 1 ]; then
    skip_next=0
    continue
  fi

  case "$a" in
    -world|-configpath|-logpath)
      skip_next=1
      continue
      ;;
    *)
      SANITIZED_ARGS="${SANITIZED_ARGS} $(printf "%s" "$a")"
      ;;
  esac
done

# --- Construction d'arguments "sûrs" (ne jamais ajouter -world ici) ---
SAFE_ARGS=""

# Si le monde n'existe pas, on crée automatiquement un monde (comme indiqué dans le README Docker Hub) :contentReference[oaicite:4]{index=4}
if [ ! -f "$WORLD_PATH" ]; then
  SAFE_ARGS="${SAFE_ARGS} -autocreate ${WORLD_SIZE}"
fi

# Options classiques (optionnelles)
SAFE_ARGS="${SAFE_ARGS} -maxplayers ${MAXPLAYERS} -port ${PORT_ARG}"

if [ -n "$PASSWORD" ]; then
  SAFE_ARGS="${SAFE_ARGS} -password ${PASSWORD}"
fi

if [ -n "$MOTD" ]; then
  SAFE_ARGS="${SAFE_ARGS} -motd ${MOTD}"
fi

# --- Exécution : on laisse bootstrap.sh gérer -world via WORLD_FILENAME ---
# (Le README indique explicitement l'usage de WORLD_FILENAME pour démarrer sur un monde existant) :contentReference[oaicite:5]{index=5}
export WORLD_FILENAME

# Important : pas de guillemets autour de $SAFE_ARGS / $SANITIZED_ARGS car on veut une expansion en "mots"
exec /bin/sh /tshock/bootstrap.sh $SAFE_ARGS $SANITIZED_ARGS
