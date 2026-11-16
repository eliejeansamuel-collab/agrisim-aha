# AgriSim AHA

Jeu de stratégie 2D pour Android : diriger un projet d'aménagement hydro-agricole dans une région de Côte d'Ivoire. Les mécaniques viennent des cours de Licence AHA (UFR ARHAI, Université Polytechnique de San-Pédro).

- `jeu/` : le jeu actif (Godot 4.4, 2D). Simulation dans `jeu/moteur/region.gd`, interface dans `jeu/scenes/main.gd`, données dans `jeu/donnees/`.
- `archive_3d/` : l'ancienne version 3D, conservée mais plus construite.
- Tests : `sh jeu/tests/lancer.sh godot` (77 tests du moteur des cours) et `godot --headless --path jeu -s tests/partie_auto.gd` (29 parties automatiques).
- APK : construit par GitHub Actions à chaque envoi, publié dans la version « dernier-apk ».

Voir `DECISIONS.md` (décision 21) pour la refonte, `ROADMAP.md` pour la suite.

---

*Ancien contenu (version 3D) :*

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
