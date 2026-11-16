# Feuille de route

Mise à jour : 15 novembre 2026, fin de la cinquième session.

## Fait et vérifié

- **Phase 1** : GDD.md, COURS_MATRICE.md (49 fichiers de cours lus, dont la topographie par OCR), FORMULES.md, ARCHITECTURE.md, DECISIONS.md.
- **Moteur de simulation** (`jeu/moteur/`) : 6 modules, **72 tests réussis** (`sh jeu/tests/lancer.sh`), dont les exercices corrigés du cours Bases techniques et deux exemples FAO-56. Bilan d'eau fermé à 10⁻¹³ mm près.
- **Tranche verticale 3D** (`jeu/scenes/`) : bas-fond rizicole de 5 ha jouable de bout en bout sur PC — foncier (5 démarches), études (3), quiz du débit de projet, conception (canal, diguettes, digue, drain) avec devis, campagne de 120 jours animée en 3D (lame d'eau, croissance, sécheresse, crue, litige), bilan (rendement, marge, VAN, TRI, 5 notes), débriefing en quatre parties, Codex, Comptes.
- Deux parties automatiques exécutées avec captures d'écran : « bon » → 5,0 t/ha ; « mauvais » → 2,0 t/ha, 58 jours de stress.

- **Site paramétrable (session 2)** : écran « Nouveau projet » avec 5 régions (San-Pédro, Abidjan, Man, Bouaké, Korhogo), 4 reliefs (bas-fond, vallée encaissée, versant à 4 %, plaine alluviale), sol (3 textures × 3 structures × 3 profondeurs), climat de l'année (pluie, ET0, durée de sécheresse, hauteur des crues), tirage au hasard et indice de difficulté. Le débit du marigot, les crues, le planage, la pente du canal et le drainage en découlent. Vérifié par 5 parties automatiques sur des sites différents.

- **Données réelles et hors-ligne (session 3)** : 14 villes de Côte d'Ivoire ; `scenes/donnees_reelles.gd` télécharge le relief (Copernicus GLO-90 via l'API d'altitude Open-Meteo, grille 20 × 20 sur 800 m) et les normales climatiques (NASA POWER, ET0 recalculée par Penman-Monteith), les met en cache (`user://sites/`), les réutilise hors connexion et tente une mise à jour au lancement. Vérifié avec un **serveur factice** (`tests/serveur_factice.py`) : téléchargement, cache, bascule hors ligne.
- **Monde vivant (session 3)** : course du soleil et de la lune, ciel jour / aube / nuit, nuages qui dérivent et s'épaississent les jours de pluie, pluie, riz qui ondule selon le vent, 10 ouvriers aux champs le jour. Trois vitesses : 1 jour = 5 s, normal, rapide. Les résultats ne dépendent pas de la vitesse (pas de calcul journalier inchangé).

- **Équipe, chantier, énergie (session 4)** : recrutement au village (manœuvres, maçons, chef de chantier, pelle, repas, riziculteurs, salaires mensuels) ; chantier simulé jour par jour par lots avec date butoir de repiquage, pluie qui ralentit, retard qui décale la campagne ; ouvriers autonomes (fatigue, faim, repas, repos, absence si épuisement, ordres collectifs et individuels, gerbes portées à la récolte) ; pompage (HMT, puissance, kWh/m³), part solaire, panneaux, batterie, gasoil ; conduite PVC (Darcy-Weisbach) ; petit barrage et retenue ; vitesses de 1 jour = 2 min à rapide, saut de 1 ou 10 jours ; ajout de budget et budget illimité. 77 tests ; 4 parties automatiques.

## Fait mais NON vérifié

- **Les deux API réelles n'ont jamais été appelées** (inaccessibles depuis l'environnement). Le format de la réponse d'altitude vient de la documentation Open-Meteo ; celui de NASA POWER (`properties.parameter.<PARAM>.<MOIS>`, pluie en mm/j, rayonnement en MJ/m²/j pour la communauté AG) vient de la mémoire du modèle : **à vérifier au premier essai sur téléphone**.

- **Export Android** : `export_presets.cfg` et `.github/workflows/android.yml` écrits mais jamais exécutés (le SDK Android est inaccessible depuis l'environnement). Attendre des ajustements au premier lancement.
- **Tactile réel** : les gestes sont émulés à la souris ; le pincement à deux doigts n'a pas été essayé sur un téléphone.
- **Performance sur téléphone** : non mesurée. Le rendu utilise 2 000 touffes de riz et 740 arbres en MultiMesh, ce qui devrait rester léger.

## Simplifié (à dire au joueur, déjà signalé dans le jeu ou DECISIONS.md)

- Relief procédural calibré, lieu fictif ; climat en normales mensuelles indicatives.
- Procédure foncière en 5 démarches probabilistes.
- Pluie efficace nulle pour le dimensionnement ; mise en eau non comptée ; irrigation en pilote automatique.
- Travaux : coût et délai forfaitaires. Vente à prix fixe. Pas de fertilisation, ravageurs, main-d'œuvre, stocks.
- Sauvegarde : seul le résumé de la dernière partie est écrit ; pas de reprise en cours de partie.

- **Modèles 3D libres (session 5)** : personnages animés (marche, travail, assis, repas) pour les ouvriers et le joueur, arbres, rochers, maisons du village, puits, tente, tonneaux, caisses, sacs ; touffes de riz en feuilles. Le chargeur (`scenes/modeles.gd`) retombe sur les formes simples si un modèle manque. Limite : personnages et maisons de style médiéval-fantaisie européen, faute de pack libre représentant des agriculteurs et un village ivoiriens ; pas d'engins, de palmiers ni de cacaoyers.

## Limites de la session 4

- Les ouvriers sont des agents à règles (besoins + ordres), pas des modèles d'IA ; pas d'humeur, pas de dialogue.
- Salaires, rendements de chantier, prix des pompes, panneaux, batteries et PVC : ordres de grandeur ; seul le gasoil (725 FCFA/L, novembre 2026) vient d'un prix officiel.
- Barrage : pas de calcul de crue de projet ni de déversoir en jeu ; retenue à géométrie fixe.
- Graphismes : formes géométriques. Un rendu proche d'un jeu commercial demande des modèles 3D, textures et animations faits par des artistes ou des packs de ressources.

## À faire, par priorité

1. **Obtenir l'APK** : pousser le dépôt sur GitHub, lancer le workflow, corriger ; ou ouvrir `jeu/` dans Godot 4.4 sur un PC avec le SDK Android et exporter. Tester sur le téléphone cible (toucher, lisibilité, fluidité).
2. **Données réelles** : MNT de la région de San-Pédro (Copernicus GLO-30) converti en carte de hauteurs et lu par `Terrain` ; normales climatiques NASA POWER dans `climat.json` ; hydrographie OSM.
3. **Vérifications avec les enseignants** : les 6 points de FORMULES.md § 5 ; valeurs de `cultures.json` et `couts.json`.
4. **Refactorisation** : découper `main.gd` (≈ 800 lignes) en `Partie` (état sérialisable), écrans par étape, vue 3D ; sauvegarde complète, export et import.
5. **Vrai relief** : la maille de 90 m ne voit ni un bas-fond de quelques hectares ni le lit d'un marigot (placé par convention) ; passer au GLO-30, tracer les cours d'eau depuis OpenStreetMap, choisir le point sur une carte, agrandir la fenêtre. Météo du jour et prévisions (Open-Meteo) pour un mode « saison en cours ». Synchronisation de la sauvegarde entre appareils (demande un serveur : non prévu).
6. **Sites** : calage des 5 climats et des 4 reliefs sur des données réelles ; ajouter température, humidité, vent et rayonnement jour par jour (Penman-Monteith est déjà codé) ; effets de la vitesse d'eau (érosion des canaux en terre) ; autres cultures que le riz selon le site.
6. **Phase 3** : chapitres 1 à 3 de la Carrière ; tutoriel ; irrigation manuelle (vannes, tour d'eau) ; fertilisation et amendements ; choix entre plusieurs terrains ; mini-jeu de nivellement et profil en long.
6. **Phase 4** : retenue et barrage en terre, forage et essai de pompage, pompage et réseau sous pression, qualité de l'eau (scénario « L'eau trop salée »), financement détaillé.
7. **Phase 5** : scénarios, Bureau d'études, bac à sable, révision espacée, sons, packs graphiques CC0, carte de Côte d'Ivoire.
8. **Phase 6** : campagne de tests sur appareil, livraison.

## Pour reprendre le projet (autre modèle ou développeur)

Lire dans l'ordre : PROMPT_AGRISIM_AHA.md → DECISIONS.md → ARCHITECTURE.md → FORMULES.md § 5 → ce fichier. Lancer les tests avant et après toute modification du moteur. Ne jamais mettre une valeur chiffrée dans le code : elle va dans `donnees/` avec sa source.
