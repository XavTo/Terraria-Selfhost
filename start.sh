#!/bin/sh
set -eu

WORLD_DIR="${CONFIGPATH:-/root/.local/share/Terraria/Worlds}"
WORLD_FILE="${WORLD_FILENAME:-world.wld}"
WORLD_PATH="${WORLD_DIR}/${WORLD_FILE}"

PORT="${GAME_PORT:-7777}"
MAXPLAYERS="${MAXPLAYERS:-8}"
WORLD_SIZE="${WORLD_SIZE:-2}"   # 1=Small, 2=Medium, 3=Large
PASSWORD="${PASSWORD:-}"
MOTD="${MOTD:-}"
EXTRA_ARGS="${EXTRA_ARGS:-}"

ARGS="-world ${WORLD_PATH} -port ${PORT} -maxplayers ${MAXPLAYERS}"

# Mot de passe (optionnel)
if [ -n "${PASSWORD}" ]; then
  ARGS="${ARGS} -password ${PASSWORD}"
fi

# Message du serveur (optionnel)
if [ -n "${MOTD}" ]; then
  ARGS="${ARGS} -motd ${MOTD}"
fi

# Si le monde n'existe pas, on le crée
if [ ! -f "${WORLD_PATH}" ]; then
  ARGS="${ARGS} -autocreate ${WORLD_SIZE}"
fi

# Lance le bootstrap d'origine de l'image
exec /bin/sh /tshock/bootstrap.sh ${ARGS} ${EXTRA_ARGS}
