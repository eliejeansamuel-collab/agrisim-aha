# Feuille de route

Mise à jour : 15 novembre 2026, fin de la deuxième session.

## Fait et vérifié

- **Phase 1** : GDD.md, COURS_MATRICE.md (49 fichiers de cours lus, dont la topographie par OCR), FORMULES.md, ARCHITECTURE.md, DECISIONS.md.
- **Moteur de simulation** (`jeu/moteur/`) : 6 modules, **72 tests réussis** (`sh jeu/tests/lancer.sh`), dont les exercices corrigés du cours Bases techniques et deux exemples FAO-56. Bilan d'eau fermé à 10⁻¹³ mm près.
- **Tranche verticale 3D** (`jeu/scenes/`) : bas-fond rizicole de 5 ha jouable de bout en bout sur PC — foncier (5 démarches), études (3), quiz du débit de projet, conception (canal, diguettes, digue, drain) avec devis, campagne de 120 jours animée en 3D (lame d'eau, croissance, sécheresse, crue, litige), bilan (rendement, marge, VAN, TRI, 5 notes), débriefing en quatre parties, Codex, Comptes.
- Deux parties automatiques exécutées avec captures d'écran : « bon » → 5,0 t/ha ; « mauvais » → 2,0 t/ha, 58 jours de stress.

- **Site paramétrable (session 2)** : écran « Nouveau projet » avec 5 régions (San-Pédro, Abidjan, Man, Bouaké, Korhogo), 4 reliefs (bas-fond, vallée encaissée, versant à 4 %, plaine alluviale), sol (3 textures × 3 structures × 3 profondeurs), climat de l'année (pluie, ET0, durée de sécheresse, hauteur des crues), tirage au hasard et indice de difficulté. Le débit du marigot, les crues, le planage, la pente du canal et le drainage en découlent. Vérifié par 5 parties automatiques sur des sites différents.

## Fait mais NON vérifié

- **Export Android** : `export_presets.cfg` et `.github/workflows/android.yml` écrits mais jamais exécutés (le SDK Android est inaccessible depuis l'environnement). Attendre des ajustements au premier lancement.
- **Tactile réel** : les gestes sont émulés à la souris ; le pincement à deux doigts n'a pas été essayé sur un téléphone.
- **Performance sur téléphone** : non mesurée. Le rendu utilise 2 000 touffes de riz et 740 arbres en MultiMesh, ce qui devrait rester léger.

## Simplifié (à dire au joueur, déjà signalé dans le jeu ou DECISIONS.md)

- Relief procédural calibré, lieu fictif ; climat en normales mensuelles indicatives.
- Procédure foncière en 5 démarches probabilistes.
- Pluie efficace nulle pour le dimensionnement ; mise en eau non comptée ; irrigation en pilote automatique.
- Travaux : coût et délai forfaitaires. Vente à prix fixe. Pas de fertilisation, ravageurs, main-d'œuvre, stocks.
- Sauvegarde : seul le résumé de la dernière partie est écrit ; pas de reprise en cours de partie.

## À faire, par priorité

1. **Obtenir l'APK** : pousser le dépôt sur GitHub, lancer le workflow, corriger ; ou ouvrir `jeu/` dans Godot 4.4 sur un PC avec le SDK Android et exporter. Tester sur le téléphone cible (toucher, lisibilité, fluidité).
2. **Données réelles** : MNT de la région de San-Pédro (Copernicus GLO-30) converti en carte de hauteurs et lu par `Terrain` ; normales climatiques NASA POWER dans `climat.json` ; hydrographie OSM.
3. **Vérifications avec les enseignants** : les 6 points de FORMULES.md § 5 ; valeurs de `cultures.json` et `couts.json`.
4. **Refactorisation** : découper `main.gd` (≈ 800 lignes) en `Partie` (état sérialisable), écrans par étape, vue 3D ; sauvegarde complète, export et import.
5. **Sites** : calage des 5 climats et des 4 reliefs sur des données réelles ; ajouter température, humidité, vent et rayonnement jour par jour (Penman-Monteith est déjà codé) ; effets de la vitesse d'eau (érosion des canaux en terre) ; autres cultures que le riz selon le site.
6. **Phase 3** : chapitres 1 à 3 de la Carrière ; tutoriel ; irrigation manuelle (vannes, tour d'eau) ; fertilisation et amendements ; choix entre plusieurs terrains ; mini-jeu de nivellement et profil en long.
6. **Phase 4** : retenue et barrage en terre, forage et essai de pompage, pompage et réseau sous pression, qualité de l'eau (scénario « L'eau trop salée »), financement détaillé.
7. **Phase 5** : scénarios, Bureau d'études, bac à sable, révision espacée, sons, packs graphiques CC0, carte de Côte d'Ivoire.
8. **Phase 6** : campagne de tests sur appareil, livraison.

## Pour reprendre le projet (autre modèle ou développeur)

Lire dans l'ordre : PROMPT_AGRISIM_AHA.md → DECISIONS.md → ARCHITECTURE.md → FORMULES.md § 5 → ce fichier. Lancer les tests avant et après toute modification du moteur. Ne jamais mettre une valeur chiffrée dans le code : elle va dans `donnees/` avec sa source.
