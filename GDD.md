# AgriSim AHA — Document de conception (GDD)

Version 0.1 — 15 novembre 2026. Ce document décrit le jeu visé ; ROADMAP.md dit ce qui existe réellement.

## 1. Vision

Un jeu mobile 3D de simulation où le joueur, jeune diplômé AHA de l'Université Polytechnique de San-Pédro, monte et conduit des projets d'aménagement hydro-agricole en Côte d'Ivoire, du terrain nu à la vente des récoltes. Les connaissances des cours de L1 à L3 sont les règles du jeu : une décision mal fondée produit une conséquence réaliste, puis le jeu explique pourquoi en citant le cours.

Public : étudiants AHA et agronomie (L2-M1), jeunes techniciens. Sessions de 5 à 15 minutes, ou longues. Hors ligne, téléphone Android modeste.

Trois piliers :
1. **La chaîne de décision de l'ingénieur** : diagnostiquer → étudier → comparer → décider → financer → aménager → équiper → produire → gérer → entretenir → évaluer.
2. **L'eau visible** : on voit l'eau arriver, manquer, déborder, sur un relief en 3D.
3. **La traçabilité** : chaque résultat a son bouton « Voir le calcul » et sa provenance (cours / déduit / approfondissement).

## 2. Références

| Jeu | Ce qu'on emprunte |
| --- | --- |
| Timberborn | L'eau comme système central : relief, digues, vannes, sécheresses |
| Pocket City 2 | City-builder 3D mobile faisable par une petite équipe, avatar qui se promène dans sa création |
| Farming Simulator 23 Mobile | Saisons, cycle cultural, chaînes de production |
| Terra Nil | Irrigation et restauration des sols, conséquences écologiques visibles |
| SimCity BuildIt | Objectifs courts adaptés au mobile (sans minuteurs payants) |
| Genshin Impact | Plaisir d'explorer, quêtes narratives (pas l'échelle de production) |

Direction artistique : 3D stylisée « low-poly », couleurs franches, eau lisible, relief réel. Aucune personne ni marque réelle.

## 3. Le monde

- Côte d'Ivoire réelle. Départ : région de San-Pédro (deux saisons des pluies). Ensuite : centre, nord soudanien.
- Trois échelles : terrain du projet en 3D (quelques km²) ; carte régionale et nationale ; carte abstraite des marchés d'export via le port de San-Pédro.
- Relief : MNT réel (Copernicus GLO-30 / SRTM) ; hydrographie et villages : OpenStreetMap ; climat : séries réelles (NASA POWER, stations). **État actuel : relief et climat procéduraux calibrés, marqués « à remplacer »** (l'environnement de développement n'a pas accès à ces serveurs).
- Personnages fictifs : chef de terre, comité villageois de gestion foncière, agent foncier, notaire, géomètre-expert, banquier, coopérative, association d'usagers de l'eau, inspecteur de l'environnement, fournisseurs, ouvriers, professeur mentor.

## 4. Mode Carrière

| Chapitre | Projet | Cours mobilisés en priorité |
| --- | --- | --- |
| 1. Le stage | 1 ha de maraîchage chez un exploitant | Bases techniques ch. 1-4, Bilan hydrique, Fertilisation, Amendements |
| 2. Le premier terrain | Trouver et sécuriser un terrain | Droit foncier rural (en attente), Civisme, Communication en milieu rural (en attente) |
| 3. Le bas-fond | Bas-fond rizicole de 5 à 20 ha | Topographie, Cartographie, Hydrologie appliquée, Hydraulique L2, Pédogenèse, Géomorphologie |
| 4. Le périmètre irrigué | 100 à 200 ha, retenue, pompage | Stockage des eaux de surface, Eaux souterraines, MDF, Électricité, Aménagement et conception, Gestion de projet (en attente) |
| 5. L'entreprise | Plusieurs sites, pisciculture, transformation, export | Qualité des eaux, Eaux non conventionnelles, Culture entrepreneuriale, Microéconomie |

**La tranche verticale livrée correspond au cœur du chapitre 3.**

## 5. Boucle de jeu d'un projet

1. **Opportunité** : filière, marché, budget, scénarios.
2. **Foncier** : parcelles candidates, détenteurs coutumiers, comité villageois, certificat foncier, bornage, bail ou achat, notaire. Chaque étape sautée augmente un risque de litige qui se réalise plus tard.
3. **Études** : topographie, pédologie, hydrologie-hydrogéologie, climat, socio-économie, environnement. Chaque étude a un coût, une durée, une précision. Sans étude, le joueur décide avec des estimations fausses — et les calculs affichés utilisent ce qu'il croit, pas la réalité.
4. **Bureau d'études** : besoins en eau (ET0, Kc, ETc, pluie efficace, besoin net et brut, Qfc), ressource, qualité de l'eau.
5. **Conception** : choix du système, dimensionnement (canaux, conduites, pompe, digues, drainage, barrage), devis, financement.
6. **Travaux** : planning, entreprises, imprévus, réception.
7. **Campagne** : simulation jour par jour ; météo, irrigation, stress, événements (sécheresse, crue, panne, litige, ravageurs).
8. **Récolte et vente**, comptes, **bilan** multicritère, **débriefing** en quatre parties : ce qui s'est passé / pourquoi / ce que dit ton cours / ce qu'il fallait faire.

## 6. Modules (A à P du cahier des charges)

| Module | Priorité | État |
| --- | --- | --- |
| A. Opportunité et faisabilité | V2 | À faire |
| B. Terrain et foncier | MVP | Tranche : 5 démarches + risque de litige |
| C. Études techniques | MVP | Tranche : topo, sol, hydro |
| D. Environnement et social | V2 | À faire |
| E. Ressources en eau | MVP | Tranche : marigot à débit mensuel ; formules retenue, forage, SAR codées et testées |
| F. Besoins en eau | MVP | Fait (moteur + écran + quiz) |
| G. Conception et dimensionnement | MVP | Tranche : canal Manning, diguettes, digue, drain ; conduites et pompes codées et testées |
| H. Énergie et instrumentation | V3 | À faire |
| I. Travaux | V2 | Tranche : coûts et délai forfaitaire |
| J. Production végétale | MVP | Tranche : riz, stress hydrique, submersion ; fertilisation à faire |
| K. Intrants et stocks | V2 | À faire |
| L. Ressources humaines | V3 | À faire |
| M. Récolte et commercialisation | V2 | Tranche : vente à prix fixe |
| N. Finance | MVP | Fait : trésorerie, prêt, VAN, TRI, délai |
| O. Maintenance | V2 | À faire |
| P. Durabilité et risques | V2 | Tranche : note de durabilité, sécheresse, crue |

## 7. Modes de jeu

Prise en main (tutoriel 3D) · Carrière · Scénarios courts (« La crue de projet », « Le litige foncier », « Le canal qui déborde », « L'eau trop salée ») · Bureau d'études (exercices sur les données de la partie, tolérance d'arrondi, contrôle des unités) · Bac à sable · Codex (notions par cours et niveau, avec provenance). Révision espacée : les notions ratées reviennent dans les missions.

Évaluation sur 5 critères notés sur 20 : diagnostic, calculs, sécurité foncière, rentabilité, durabilité. Le profit seul ne suffit pas.

## 8. Interface mobile

Paysage. Vue 3D à gauche, panneau d'action à droite (défilant, gros boutons). Caméra : glisser = tourner, pincer = zoomer, toucher le sol = déplacer l'avatar et lire l'altitude. Couches : courbes de niveau (après l'étude topographique), puis sols, eau, réseaux. Boutons permanents : Codex, Comptes.

## 9. Limites assumées

- Pas de monde ouvert à l'échelle d'un jeu AAA ; une carte par projet.
- Simulation de l'eau par bilans et capacités (pas de mécanique des fluides 3D).
- Procédures foncières et réglementaires simplifiées et marquées « à vérifier » ; le jeu ne remplace pas un juriste ni un bureau d'études.
- Toutes les valeurs économiques et agronomiques hors cours sont indicatives.
