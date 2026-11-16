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
| 16 | Débit du marigot = 0,0254 × (pluie décalée / 100)² × facteur de bassin ; crues = hauteurs de base × facteur du relief | Relier simplement ressource et climat choisi, sans données de jaugeage | Débits mesurés ou modèle pluie-débit calé | Faible (`_generer_site`) |
| 17 | Effets de la structure du sol (percolation × 0,6 à 1,3 ; fertilité 0,85 à 1,0) : paramètres de jeu | Le cours donne le sens de l'effet, pas de chiffres | Valeurs mesurées | Faible (`sols.json`) |
| 18 | Données réelles téléchargées **par le jeu lui-même** (téléphone), pas embarquées | L'environnement de développement n'a pas accès aux serveurs ; le téléphone, si | Embarquer un MNT de tout le pays (plusieurs centaines de Mo en 30 m) | Moyen |
| 19 | Hors-ligne = cache local par lieu, mise à jour tentée au lancement ; pas de serveur de synchronisation | Zéro coût d'exploitation | Compte utilisateur + serveur | Élevé |
| 20 | En mode réel, le type hydrologique (crues, drainage) est déduit des pentes mesurées ; le sol reste choisi par le joueur | Le satellite ne donne ni les crues ni le sol | SoilGrids (sols), données de jaugeage | Moyen |

## 21. Refonte en jeu de stratégie 2D (16 novembre 2026)

**Décision.** Le jeu 3D est archivé dans `archive_3d/` (plus construit). Le jeu actif (`jeu/`) est un jeu de stratégie 2D sur carte, du même genre que Rebel Inc. : une région découpée en 11 zones, un budget, des initiatives à financer (Études, Ouvrages, Organisation) qui se déploient zone par zone, des crises qui s'aggravent et se propagent, des équipes à envoyer, une jauge de confiance du bailleur, des événements à choix.

**Pourquoi.** Demande d'Elie : pas les moyens de faire une application 3D « digne de ce nom » pour l'instant. La 2D tient sur tout téléphone et l'APK ne contient plus les packs 3D.

**Ce qui est repris de Rebel Inc. : le genre seulement** (carte en zones, initiatives, inflation des prix quand on dépense vite, corruption, réputation, unités à déplacer, événements). Aucun texte, visuel, nom ou chiffre du jeu d'origine n'est repris.

**Ce qui vient des cours.** Le moteur testé (`moteur/eau.gd`, `hydrologie.gd`) calcule : besoins en eau par décade (ETc = Kc × ET0, pluie efficace, percolation, efficience), débit fictif continu, bilan de la retenue, rendement FAO-33, crue annuelle tirée dans une loi de Gumbel et période de retour, risque de dépassement sur n années. Principe « vérité contre croyance » conservé : sans étude, les chiffres affichés sont faux ou absents et les ouvrages sont mal dimensionnés.

**Limites assumées.** La carte est fictive (générée au hasard) : les limites administratives réelles n'étaient pas téléchargeables depuis l'environnement de développement. Les coûts, durées et réglages d'équilibrage sont des valeurs indicatives de jeu. Le climat par région reste « valeur indicative » (voir `donnees/climat.json`).
