# Architecture

```
agrisim/
  PROMPT_AGRISIM_AHA.md   cahier des charges
  GDD.md  COURS_MATRICE.md  FORMULES.md  DECISIONS.md  ROADMAP.md  CREDITS.md
  cours/                  supports de cours (hors git)
  jeu/                    projet Godot 4.4
    project.godot  export_presets.cfg
    moteur/               règles de calcul, sans dépendance au rendu
      eau.gd              sol-plante-atmosphère, besoins, Kc, Ks, Penman-Monteith
      hydraulique.gd      Manning, pertes de charge, pompes, ouvrages
      hydrologie.gd       bassin versant, crues, retenues, qualité des eaux, Darcy
      economie.gd         VAN, TRI, annuités, seuils
      meteo.gd            générateur journalier à partir de normales mensuelles
      campagne.gd         simulation journalière d'une campagne (bilan d'eau fermé)
    donnees/              contenu modifiable sans toucher au code (JSON)
      climat.json  cultures.json  sols.json  couts.json  notions.json
    scenes/
      main.tscn / main.gd  tranche verticale (monde 3D, interface, déroulement)
      terrain.gd           relief (fonction hauteur, maillage, lancer de rayon)
      terrain.gdshader     couleurs + courbes de niveau
    tests/run_tests.gd     72 tests unitaires ; tests/lancer.sh
  .github/workflows/android.yml   tests + APK (non testé)
```

## Principes

1. **Le moteur ne connaît pas l'écran.** `moteur/*.gd` sont des classes `RefCounted` à fonctions statiques (formules) ou à état simple (`Campagne`, `Meteo`). Elles tournent en ligne de commande.
2. **Le contenu est dans des données.** Toute valeur chiffrée hors formule vit dans `donnees/*.json` avec `statut` et `source`.
3. **Vérité et croyance.** La scène garde la réalité du terrain (`VRAI`) et ce que le joueur croit (`CROYANCE`). L'interface calcule avec le connu ; `Campagne` simule avec le vrai.
4. **Conservation.** `Campagne.erreur_bilan()` doit rester nul : P + I = ETr + percolation + drainage + débordement + Δstock. Testé.
5. **Reproductibilité.** Même graine, même partie (`AGRISIM_GRAINE`).

## Déroulement d'un jour de campagne (`Campagne.jour_suivant`)

météo → Kc du stade → ETm → demande d'irrigation plafonnée par min(capacité du canal, débit du marigot) × efficience → apport → réhumectation du sol → percolation → ETr avec Ks → drainage → débordement → crue éventuelle → journal.

## Modèle de données cible (non encore implémenté en entier)

Région, Terrain, Parcelle, ProfilDeSol, SourceEau, Ouvrage, Équipement, Culture, Campagne, Intrant, Stock, Travailleur, Fournisseur, Client, Tâche, Incident, Transaction, Notion, Cours. Sauvegarde : un fichier JSON par partie (`user://`), export/import à faire. Aujourd'hui : seul le résumé de la dernière partie est écrit (`user://derniere_partie.json`).

## Étendre

- **Nouvelle culture ou région** : ajouter une entrée dans `cultures.json` / `climat.json`.
- **Nouvelle formule** : fonction statique dans le module adéquat + test dans `run_tests.gd` + ligne dans `FORMULES.md`.
- **Nouveau cours** : ligne dans `COURS_MATRICE.md`, notions dans `notions.json`, puis mécanique ou mission.
- **Nouveau scénario** : aujourd'hui `main.gd` est un seul script ; prochaine étape, extraire `Etape` en scènes séparées et un `Partie` (état) sérialisable.

## Commandes

```
godot --headless --path jeu --import              # première fois
sh jeu/tests/lancer.sh /chemin/vers/godot         # tests du moteur
godot --path jeu                                  # jouer sur PC
AGRISIM_AUTO=bon AGRISIM_GRAINE=5 AGRISIM_CAPTURES=/tmp godot --path jeu   # partie automatique + captures
```
