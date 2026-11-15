# AgriSim AHA

Jeu mobile 3D de simulation en aménagement hydro-agricole (Côte d'Ivoire). Projet de Tchaou, L3 AHA, UFR-ARHAI, Université Polytechnique de San-Pédro.

- Cahier des charges : `PROMPT_AGRISIM_AHA.md`
- État réel du projet : `ROADMAP.md`
- Conception : `GDD.md`, `COURS_MATRICE.md`, `FORMULES.md`, `ARCHITECTURE.md`, `DECISIONS.md`

## Jouer sur un ordinateur

1. Installer Godot 4.4 (gratuit) : https://godotengine.org
2. Ouvrir le dossier `jeu/` comme projet, puis F5.

## Obtenir l'APK Android

Voir ROADMAP.md, « À faire » n° 1. Deux voies : le workflow GitHub Actions fourni, ou l'export depuis Godot sur un PC équipé du SDK Android.

## Tester le moteur

```
sh jeu/tests/lancer.sh /chemin/vers/godot
```
