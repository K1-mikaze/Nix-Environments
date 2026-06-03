#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

nix eval --raw --file "$DIR/generate-flake.nix" > "$DIR/flake.nix"

echo "Regenerated $DIR/flake.nix from $DIR/child-specs.nix"
