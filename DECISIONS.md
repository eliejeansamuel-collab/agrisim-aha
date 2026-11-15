# Décisions prises sans validation (consigne spéciale de temps)

Chaque décision peut être annulée ; l'alternative et son coût sont indiqués.

| # | Décision | Raison | Alternative | Coût du changement |
| --- | --- | --- | --- | --- |
| 1 | Moteur **Godot 4.4.1** | Gratuit, libre, export Android, léger, scriptable et testable en ligne de commande ; téléchargeable dans l'environnement | Unity (écosystème 3D mobile plus mature, plus lourd, licence) | Élevé pour les scènes ; faible pour les règles si on porte les formules |
| 2 | Moteur de simulation en **GDScript pur** (`jeu/moteur/`), sans dépendance au rendu | Une seule implémentation, testée hors écran (72 tests) | C# ou module natif | Moyen |
| 3 | Rendu « mobile », 3D low-poly générée par code | Aucun fichier graphique sous licence à gérer ; léger | Packs CC0 (Kenney, Quaternius) | Faible : remplacer les maillages dans `main.gd` |
| 4 | **Relief procédural calibré** au lieu d'un MNT réel | Serveurs Copernicus / SRTM / OSM inaccessibles depuis l'environnement | Importer un MNT réel de la région de San-Pédro | Faible : remplacer `Terrain.hauteur()` par une lecture de carte de hauteurs |
| 5 | **Climat : normales mensuelles indicatives** + générateur aléatoire | NASA POWER inaccessible | Séries réelles 1991-2020 | Faible : remplacer `donnees/climat.json` |
| 6 | Tranche verticale = **chapitre 3 (bas-fond rizicole de 5 ha)** | C'est la Phase 2 du cahier des charges | — | — |
| 7 | Lieu fictif « bas-fond de Gabiadji », personnages fictifs | Règle : aucune personne réelle ; pas de données réelles de parcelle | Site réel après import du MNT | Faible |
| 8 | Sans étude, le joueur calcule avec des **valeurs crues fausses** ; la simulation utilise les vraies | Fait sentir la valeur d'une étude sans pénalité arbitraire | Bloquer la conception sans étude | Faible |
| 9 | Dimensionnement du riz sur **période sans pluie** (pluie efficace = 0), mise en eau non comptée | Simplification prudente et lisible | Pluie de fréquence 80 %, besoins de mise en boue | Faible |
| 10 | Ky, pertes par submersion et par stress à la floraison : **paramètres de jeu indicatifs** | Pas dans les cours ; ordre de grandeur FAO | Calage sur des références CNRA / AfricaRice | Faible (fichier `cultures.json`) |
| 11 | Coûts en FCFA **indicatifs** | Aucun devis réel disponible | Mercuriale réelle | Faible (fichier `couts.json`) |
| 12 | **APK non construit ici** ; workflow GitHub Actions fourni | Le SDK Android (dl.google.com) est inaccessible depuis l'environnement | Construire sur un PC avec Godot + Android SDK | Aucun |
| 13 | Procédure foncière en 5 démarches à effet probabiliste | Cours « Droit foncier rural » manquant ; textes à vérifier | Procédure détaillée conforme aux textes en vigueur | Moyen (contenu) |
| 14 | Orientation paysage | Vue 3D + panneau lisibles | Portrait | Moyen (interface) |
| 15 | Les cours ne sont **pas versionnés** dans git (`.gitignore`) | Volume (230 Mo) et droits des enseignants | — | — |
