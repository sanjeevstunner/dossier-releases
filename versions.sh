#!/bin/sh
# Runs a command with each app's image tag taken from its submodule's package.json.
v() { node -p "require('./$1/package.json').version"; }
export DOSSIER_VERSION="$(v dossier)" NOPERI_VERSION="$(v noperi-ts)"
exec "$@"
