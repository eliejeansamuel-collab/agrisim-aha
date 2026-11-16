#!/bin/sh
# Lance les tests unitaires du moteur. Usage : sh tests/lancer.sh [chemin/vers/godot]
G=${1:-godot}
cd "$(dirname "$0")/.."
timeout 120 "$G" --headless --path . -s tests/run_tests.gd 2>&1 | grep -v "^Godot Engine"
