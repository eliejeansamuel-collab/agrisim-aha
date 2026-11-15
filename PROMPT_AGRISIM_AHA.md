# PROMPT — JEU MOBILE 3D DE SIMULATION EN AMÉNAGEMENT HYDRO-AGRICOLE

_Nom de code : AgriSim AHA — Côte d'Ivoire · Version 2 du 15 novembre 2026 · Document à joindre à Fable (Claude Code) avec le dossier de mes cours_

> **Ce document est la demande complète. Lis-le en entier avant d'agir. Les fichiers de mes cours sont joints dans un dossier « cours/ ». En cas de conflit : (1) les règles non négociables (section 16), (2) la consigne spéciale de temps (section 2), (3) le reste du document.**

## 1. Qui je suis et pourquoi ce jeu

- Étudiant en Licence 3, parcours Aménagements hydro-agricoles (AHA), licence professionnelle, UFR Agriculture, Ressources halieutiques et Agro-industrie (ARHAI), Université Polytechnique de San-Pédro, Côte d'Ivoire. Semestre 5 en cours ; le semestre 6 est consacré au projet tutoré et au stage de 4 mois.
- Mes L1 et L2 sont le tronc commun de l'UFR, partagé avec l'agronomie, l'agroalimentaire / industrie des bioressources et l'halieutique / aquaculture.
- Je veux un jeu mobile en 3D, une simulation « grandeur nature » qui se passe en Côte d'Ivoire. En y jouant régulièrement, je dois acquérir tout ce qu'il faut pour monter et conduire un projet d'aménagement hydro-agricole d'envergure, du terrain nu jusqu'à la vente des récoltes, même sans aller sur le terrain.
- Ce n'est pas un quiz déguisé : les connaissances de mes cours sont dans les mécaniques. Une décision mal fondée a des conséquences réalistes, puis le jeu m'explique pourquoi, en citant mon cours.
- Rien n'est trop simple pour être simulé : posséder un terrain, droits coutumiers, certificat et titre foncier, notaire, géomètre, papiers administratifs, banque, recrutement… du début à la fin.
- Mon téléphone : Android d'entrée ou de milieu de gamme, connexion Internet parfois limitée.

## 2. Consigne spéciale : tu n'as que quelques jours

> **Mon accès à toi (Fable) est limité à environ 3 jours et je suis très peu disponible. Ne t'arrête pas pour attendre ma validation entre les phases. Quand une décision me revient, prends l'option la plus raisonnable, note-la dans DECISIONS.md avec l'alternative et la raison, et continue.**

Priorités si le temps manque, dans cet ordre :

1. Document de conception complet (GDD) + matrice de traçabilité cours ↔ notions ↔ mécaniques, à partir de TOUS les fichiers du dossier cours/.
2. Moteur de simulation testé : bilan hydrique de la parcelle, besoins en eau des cultures, hydraulique des canaux et conduites, pompage, économie de base.
3. Tranche verticale jouable en 3D (section 15, Phase 2) et APK Android installable.
4. Documentation de passation : README, ARCHITECTURE.md, ROADMAP.md, DECISIONS.md, pour qu'un autre modèle (Claude Opus) reprenne le projet sans rien perdre.

Fais des commits fréquents et petits, avec des messages clairs. À la fin de chaque session, mets à jour ROADMAP.md : fait / en cours / à faire.

## 3. Ton rôle et ta méthode

- Tu réunis : directeur de jeu (game designer simulation), développeur de jeux mobiles 3D, artiste technique 3D, ingénieur AHA (hydrologie, hydraulique, irrigation, drainage, barrages), agronome tropical, pédologue, spécialiste SIG et topographie, juriste du foncier rural ivoirien, économiste de projet agricole et pédagogue.
- Tu travailles dans un vrai environnement de développement : tu crées, compiles et testes. Pas de code théorique, pas de bouton décoratif, pas de fonction simulée par un faux résultat.
- Tu poses au maximum 5 questions bloquantes à la fois ; sinon tu annonces des hypothèses raisonnables et modifiables.
- Tu es honnête : tu listes ce qui fonctionne, ce qui est simplifié et ce qui manque. Tu signales chaque simplification pédagogique par rapport à une vraie étude d'ingénierie.
- Tu ne présentes jamais une estimation comme une mesure, ni une hypothèse comme un fait.

## 4. Vision : un vrai jeu 3D, pas un logiciel de bureau

Le joueur incarne un jeune diplômé AHA de l'USP. Il se déplace en 3D (avatar) sur ses terrains, observe le relief, les bas-fonds, les cours d'eau, ses canaux et ses cultures ; il passe à une vue « bureau d'études » pour les cartes, calculs et plans ; il passe à une carte de la Côte d'Ivoire pour choisir une région, acheter, vendre et se déplacer.

Jeux de référence et ce que tu dois leur emprunter :

| Jeu | Ce qu'on emprunte | Ce qu'on n'emprunte pas |
| --- | --- | --- |
| Genshin Impact | Exploration 3D agréable, monde qui donne envie, quêtes narratives, personnages attachants, progression par chapitres | L'échelle de production (studio de centaines de personnes), le combat, le système de tirage payant |
| SimCity BuildIt | Construction sur une carte, chaînes de production, objectifs courts, progression mobile adaptée aux sessions courtes | Les minuteurs d'attente et achats intégrés |
| Pocket City 2 | Preuve qu'un petit studio peut faire un city-builder 3D mobile avec avatar qui se promène dans sa création, saisons, jour/nuit, catastrophes | — |
| Farming Simulator 23 Mobile | Machines agricoles, saisons, cycle cultural, chaînes de production, maintenance du matériel | La conduite d'engins comme cœur du jeu |
| Timberborn | LA référence pour l'eau : simulation physique de l'eau sur le relief, barrages, digues, vannes, irrigation qui recule pendant les sécheresses | Le thème post-apocalyptique |
| Terra Nil | Irrigation et restauration des sols comme mécanique centrale, conséquences écologiques visibles, ambiance apaisante | — |

> **Honnêteté sur l'échelle : un monde ouvert du niveau de Genshin Impact est hors de portée. Vise une 3D stylisée « low-poly » propre et cohérente, des ressources graphiques libres de droits (CC0 ou licence compatible, listées dans CREDITS.md), et un relief RÉEL de Côte d'Ivoire. La beauté vient de la direction artistique, de la lumière, de l'eau et du relief, pas du nombre de polygones.**

## 5. Le monde : la Côte d'Ivoire réelle

- Carte nationale stylisée en 3D avec les régions ; zone de départ : région de San-Pédro (Bas-Sassandra), climat à deux saisons des pluies. Régions débloquées plus tard : centre (savane, une saison des pluies plus marquée), nord soudanien (saison sèche longue), autres zones du sud.
- Relief réel : modèle numérique de terrain gratuit (par exemple Copernicus DEM GLO-30 ou SRTM). Rivières, routes et villages : OpenStreetMap. Climat : séries réelles gratuites (par exemple NASA POWER) ou données de stations. C'est le relief réel qui sert aux exercices de topographie, de cartographie et de géomatique de mes cours.
- Si tu ne peux pas télécharger ces données dans ton environnement, génère un terrain procédural calibré sur des valeurs documentées, marque-le « à remplacer par les données réelles » et écris dans ROADMAP.md la procédure pour les intégrer.
- Trois échelles de jeu : (1) le terrain du projet en 3D, à pied ou en véhicule, quelques km² ; (2) la carte de la région et du pays ; (3) une carte du monde abstraite pour les marchés d'exportation via le port de San-Pédro.
- Monnaie FCFA, unités du système international, langue française.
- Personnages non joueurs fictifs (aucune personne réelle) : chef de terre et notables, comité villageois de gestion foncière, agent foncier, notaire, géomètre-expert, banquier et microfinance, coopérative, association d'usagers de l'eau, inspecteur de l'environnement, fournisseurs, ouvriers, un professeur mentor.

Cadre légal à simuler (à vérifier, version en vigueur, avant intégration) : loi n° 98-750 du 23 décembre 1998 relative au domaine foncier rural et ses modifications (2004, 2013, 2019) ; certificat foncier, titre foncier, droits coutumiers, rôle de l'Agence foncière rurale (AFOR), délimitation des territoires villageois ; code de l'eau ; code de l'environnement et étude d'impact environnemental et social ; droit OHADA (sociétés, sociétés coopératives) ; fiscalité de base ; contrats de travail saisonniers ; règles phytosanitaires. N'invente jamais un numéro d'article, un délai ou un coût de procédure : marque « à vérifier ».

## 6. Histoire et mode Carrière

Le jeu raconte la progression d'un jeune diplômé AHA. Chaque chapitre est un projet plus grand, qui mobilise de nouveaux cours :

| Chapitre | Projet | Ce qu'il enseigne surtout |
| --- | --- | --- |
| 1. Le stage | Aider un exploitant sur 1 ha de maraîchage | Prise en main, besoins en eau, arrosage, sol, fertilisation de base |
| 2. Le premier terrain | Trouver et sécuriser un terrain | Foncier rural, droits coutumiers, notaire, géomètre, bornage, négociation |
| 3. Le bas-fond | Aménager un bas-fond rizicole de 5 à 20 ha | Topographie, hydrologie, digues et diguettes, canaux, drainage, calendrier rizicole |
| 4. Le périmètre irrigué | 100 à 200 ha avec retenue ou barrage en terre et station de pompage | Barrages, crue de projet, pompes, réseaux sous pression, financement, appel d'offres |
| 5. L'entreprise | Plusieurs sites, pisciculture, transformation, export | Gestion, coopérative, qualité de l'eau, eaux non conventionnelles, marchés |

Chaque chapitre a des quêtes courtes (5 à 15 minutes) jouables dans le bus, et des objectifs longs. Le professeur mentor débriefe chaque échec en citant mon cours.

## 7. Boucle de jeu et modules obligatoires

Chaîne de décision au cœur du jeu : diagnostiquer → étudier → comparer → décider → financer → aménager → équiper → produire → gérer → entretenir → évaluer et améliorer.

| Module | Contenu attendu |
| --- | --- |
| A. Opportunité et faisabilité | Filière et cultures (riz irrigué, maraîchage, vivriers, cacao, hévéa, palmier, anacarde, pisciculture associée), marché, prix, saisonnalité, budget prévisionnel, comparaison de scénarios |
| B. Terrain et foncier | Parcelles candidates sur la carte, fiche terrain, vérification foncière, droits coutumiers, achat, location ou bail, notaire, géomètre, bornage, enregistrement. Jamais automatique : une étape sautée déclenche des litiges réalistes |
| C. Études techniques | Pédologie (profil, texture, réserve utile, pH, salinité, infiltration), topographie (levé, nivellement, courbes, profils, volumes), géologie et hydrogéologie, climat (ETo Penman-Monteith), hydrologie (bassin versant, crue de projet, étiage). Chaque étude a un coût, une durée et une marge d'incertitude |
| D. Environnement et social | Zones humides, inondables, protégées ; consultation des communautés et usagers ; autorisations de prélèvement ; mesures d'évitement et de réduction ; santé (paludisme, bilharziose liés aux eaux stagnantes) |
| E. Ressources en eau | Rivière, retenue, barrage, puits, forage, eaux non conventionnelles ; débit exploitable, rabattement, recharge, qualité (CE, SAR, pH, MES), concurrence entre usages |
| F. Besoins en eau et irrigation | Kc, ETc, pluie efficace, réserve utile, besoins nets et bruts, dose, fréquence, durée, calendrier, suivi de l'humidité du sol |
| G. Conception et dimensionnement | Gravitaire, à la raie, submersion, aspersion, goutte-à-goutte ; canaux (Manning-Strickler), conduites et pertes de charge, pompes (HMT, puissance, rendement), ouvrages (prises, partiteurs, chutes, dalots, vannes), drainage, barrages en terre ; atelier 3D où le joueur pose les ouvrages puis vérifie le dimensionnement |
| H. Énergie et instrumentation | Réseau, solaire photovoltaïque, groupe électrogène ; capteurs, électrovannes, télémétrie ; fonctionnement manuel en cas de panne |
| I. Travaux | Défrichement raisonné, terrassement, déblais/remblais, engins, planning, entreprises, contrôle qualité, réception, imprévus |
| J. Production végétale | Itinéraire technique, pépinière, repiquage, fertilisation raisonnée (bilan NPK, amendements, compost, fertigation), lutte intégrée, stress, rendement variable |
| K. Intrants et stocks | Catalogue, fournisseurs, délais, stockage, péremption, traçabilité des applications, sécurité des produits |
| L. Ressources humaines | Rôles, recrutement, contrats, formation, planning des équipes, sécurité, sans caricature |
| M. Récolte et commercialisation | Récolte, séchage, stockage, pertes, transformation, qualité, contrats, coopérative, export |
| N. Finance | Capital, crédit, subventions, trésorerie, amortissements, coût par hectare, marge, VAN, TRI, délai de récupération, prévu / réalisé |
| O. Maintenance | Préventive et corrective ; usure, colmatage, fuites, envasement des retenues, curage des canaux |
| P. Durabilité et risques | Érosion, salinisation, engorgement, fertilité, sécheresse, inondation, conflits d'usage ; indicateurs et plans de contingence |

## 8. Le lien avec mes cours (le cœur pédagogique)

- Lis tous les fichiers du dossier cours/. Construis la matrice de traçabilité cours ↔ notions ↔ mécaniques (fichier COURS_MATRICE.md + écran « Codex » dans le jeu).
- Chaque notion affichée indique sa provenance : « Dans ton cours » (intitulé, niveau, chapitre ou page), « Reformulé ou déduit », ou « Approfondissement (hors cours) » avec sa référence. Ne présente jamais une information comme venant de mon cours si elle n'y figure pas.
- Rends visible la chaîne L1 → L2 → L3 → jeu. Exemples : probabilités et statistiques (L1) → loi de Gumbel et crue de projet (L3 Hydrologie appliquée) → déversoir du barrage qui déborde si le calcul est faux ; mécanique des fluides (L2) → Manning-Strickler (L3) → canal qui déborde ; réactions ioniques en solution (L1) → SAR et conductivité (L3 Qualité des eaux) → sol qui se sodise ; thermodynamique (L2) → chaleur latente et évapotranspiration (L3 Bilan hydrique).
- Bouton « Voir le calcul » sur chaque résultat : formule, données, unités, résultat, cours d'origine.
- Les cours « terminés » servent de base de connaissances ; les cours « en cours » sont prioritaires dans les missions et la révision espacée.
- Pour un cours manquant (section 9.3) : prépare sa place, n'invente pas son contenu, appuie-toi sur des sources officielles marquées « approfondissement », et marque-le « en attente du cours ».
- Toute valeur chiffrée qui ne vient pas de mes cours (coût, rendement, Kc, prix) vient d'une source reconnue (FAO, CNRA, ANADER, textes officiels ivoiriens), est citée dans les données et marquée « valeur indicative », modifiable.

## 9. Inventaire de mes cours

### 9.1 Licence 3 — semestre 5 (en cours) et semestre 6 (à venir)

| ECUE | Cours | Statut | Fichier |
| --- | --- | --- | --- |
| ACH71151 | Agro-climatologie | Terminé | CM_AC.pdf |
| ACH71152 | Hydrologie appliquée (précipitations, ETP, ruissellement, infiltration, crues, étiages) | En cours | CM_Hydrologie_appliquee.pdf |
| FOI71151 | Bilan hydrique | Terminé | Bilan_hydrique_Enregistrement_automatique1.pdf |
| FOI71152 | Bases techniques et pilotage de projet d'irrigation | Terminé (examen 16/11) | USP_-_Cours_Bases_technik_et_pilotage_projet_dirrigation_vf.pdf |
| FOI71153 | Manipulation des données climatiques | En cours | Cours_Manipulation_de_donnees_climatiques_Licence_3_AHA_UFR_ARHAI_USP.pdf |
| MSE71151 | Stockage des eaux de surface (barrages) | Terminé | COURS_DE_BARRAGE_L3_AHA.pdf |
| MSE71152 | Mobilisation des eaux souterraines | Terminé | CM_MOBILISATION_DES_EAUX_SOUTERRAINES.pdf |
| MSE71153 | Mobilisation des eaux non conventionnelles | Terminé | COURS_DE_QUALIT__DES_ENC.pdf |
| FEF71151 | Amendements des sols | En cours | COURS_AMENDEMENT_DES_SOLS1.pdf |
| FEF71152 | Fertilisation-fertigation | En cours | FERTILISATION_ET_FERTIGATION_CM_TD_TP-1.pdf |
| GET71151 | Géomatique | En cours | manquant |
| GET71152 | Cartographie (projections UTM et TMCI, profils) | En cours | COURS_CARTOGRAPHIE_L3.pdf |
| GET71153 | Topographie | En cours | COURS_TOPOGRAPHIE_LICENCE3_AMENAGEMENT_HYDRO-AGRICOLE_OK_Phoenix.pdf (scanné : OCR nécessaire) |
| HYS71151 | Qualité des eaux d'irrigation (CE, SAR, RSC, classification USSL, Wilcox) | Terminé | COURS_DE_QUALIT__DES_EAUX_D.pdf |
| HYS71152 | Aménagement et conception de systèmes d'irrigation | En cours | AMENAGEMENT_HYDRO_AGRICOLE.pdf |
| STA7115 | Analyse de données ; initiation au logiciel R | En cours | manquants |
| ENE7115 | Culture entrepreneuriale et plan d'affaires ; microéconomie d'entreprise | En cours | manquants |
| S6 | Algorithmique, optimisation, programmation ; gestion des organisations, leadership, recherche d'emploi ; rédaction scientifique, projet tutoré, stage | À venir | — |

La maquette officielle (Maquettes_AHA_2024-2025.pdf) donne les volumes horaires et les crédits.

### 9.2 Licence 1 et Licence 2 (tronc commun ARHAI)

Rôle dans le jeu : « cœur » = alimente directement les moteurs de simulation ; « secondaire » = alimente des mécaniques ou missions ; « codex » = fiches et défis de culture scientifique. Le niveau exact de certains cours (L1 ou L2) est à confirmer ; ce n'est pas bloquant.

| Niveau | Cours | Rôle dans le jeu | Fichier(s) |
| --- | --- | --- | --- |
| L2 | Hydraulique générale + mécanique des fluides (introduction, statique, fluides parfaits, fluides réels) | Cœur : canaux, conduites, pertes de charge, pompes | Cours_dhydraulique_L2_ABV-PARH-IAAA_New_UPS_Lazare_K.pdf ; chap_1 à chap_4 (MDF) |
| L2 | Hydrologie (cycle et bilan hydrologique) | Cœur : bilan d'eau, bassin versant | L2-2022-2023_USP-ARHAI-Cours_Hydrologie_v1.0-Ppt_1.pdf |
| L2 | Pédogenèse | Cœur : types de sols, profils, aptitude | COURS_DE_POGENESE_231130_170315.pdf |
| L2 | Géomorphologie | Cœur : relief, bas-fonds, érosion, choix de site | COURS_GEOMORPHOLOGIE__USP.pdf |
| L2 | Physiologie végétale | Cœur : croissance, stress hydrique, nutrition | COURS_PHYSIO_VEGETALE_L2_2024__2025.pdf |
| L2 | Thermodynamique physique (3 chapitres) + thermodynamique chimique | Cœur : chaleur latente, évaporation, énergie de pompage | CM_THERMODYNAMIQUE_PHYSIQUE_.pdf ; Chapitre_1/2/3_THERMODYNAMIQUE_L2_ARHAI_2025-2026.pdf ; CM-thermochimie_1.pdf |
| L1 | Probabilités et statistiques | Cœur : fréquences de pluie, crues, risques, analyse de données | Proba-stat_L1_San_Pedro.pdf |
| L1 | Algèbre et géométrie | Cœur : surfaces, volumes, pentes, calculs topographiques | SDM-ARHAI_ALGEBRE-GEOMETRIE.pdf |
| L1 | Électricité | Cœur : moteurs de pompes, solaire, consommation | Fascicule_cours_electricit__ARHAI_2024-2025-1.pdf |
| L1 | Réactions ioniques en solution aqueuse | Cœur : pH, salinité, qualité des eaux | Cours_de_R_actions_Ioniques_en_Solution_aqueuse.pdf |
| L1/L2 | Biologie végétale | Secondaire : choix des cultures, botanique | CM_BV_USP_2024_2025.pdf |
| L1/L2 | Cinétique chimique | Secondaire : décomposition de la matière organique, engrais | COURS_CINETIQUE_CHIMIQUE_san_pedro.pdf |
| L2 | Biochimie métabolique et énergétique | Secondaire : photosynthèse, respiration, rendement | USP_BME_2026.pdf |
| L1/L2 | Biochimie : glucides, lipides, protides | Secondaire : qualité des récoltes, post-récolte | CM_BIOCHIMIE_ECUE1_Glucides.pdf ; ECUE_2_Lipides.pdf ; ECUE_3-Protides.pdf |
| L1/L2 | Microbiologie | Secondaire : compost, contamination de l'eau, réutilisation des eaux usées | SUPPORT_DE_COURS_ECUE_INITIATION_MICROBIOLOGIE.pdf |
| L1/L2 | Génétique (connaissances fondamentales, mutations) | Secondaire : choix des variétés, amélioration des plantes | USP_Connaissances_Fondamentales_en_g_n_tiques.pdf ; GENE_MUTA_Dr_GORE_BI-2024-2025_-VF-PROJECTION_docx.pdf |
| L1/L2 | Civisme | Secondaire : relations avec les communautés, éthique, vie citoyenne | POWERPOINT_CIVISME_2024-2025_ARHAI.pptx |
| L1/L2 | Immunologie et antimicrobiens ; agents antimicrobiens | Codex : santé animale et pisciculture, hygiène | ECUE2_Immuno_et_Antimicrobiens.pdf ; Chapitre_III_AGENTS_ANTIMICROBIENS_2023.docx |
| L1/L2 | Biologie moléculaire ; acides nucléiques | Codex | 0_-_Cours_de_biologie_mol_culaire_6.pptx ; COURS_STRUCTURES_PROPRIETES_ACIDES_NUCLEIQUES-1.pdf |
| L1 | Biologie du développement | Codex | COURS_Presentation_BID_2023_L1_ARHAI0.pdf |
| L1 | Électrostatique | Codex : capteurs, notions de base | Fascicule_cours_electrostatique_ARHAI_SDM_2024-2025.pdf |

### 9.3 Cours manquants et ce qu'il faut faire

| Cours manquant | Importance pour le jeu | En attendant |
| --- | --- | --- |
| Droit foncier rural (L2) | Très haute : tout le module B | Textes officiels (loi 98-750 modifiée, AFOR), marqués « approfondissement » |
| Gestion et évaluation de projet (L2) | Très haute : financement, VAN, TRI | Méthodes standard d'évaluation de projet, marquées « approfondissement » |
| Méthode de rédaction de projet (L2) | Haute : dossiers de financement et d'autorisation | Modèles génériques de dossier |
| Communication en milieu rural (L2) | Haute : consultation des communautés | Bonnes pratiques de concertation |
| Éducation environnementale et développement durable (L2) | Haute : module D | Cadre de l'étude d'impact |
| Géologie structurale ; matériaux de l'écorce terrestre (L1) | Moyenne : fondations de barrage, aquifères | Cours de barrage et d'eaux souterraines de L3 |
| Mécanique (L1) | Moyenne : stabilité des ouvrages | Notions de statique du cours de MDF |
| Entreprises agricoles ; industries agroalimentaires ; production animale et ressources halieutiques (L1) | Moyenne : chapitre 5 | Préparer la place |
| Méthodologie de la recherche ; références bibliographiques ; rédaction administrative ; rédaction de compte rendu (L1/L2) | Faible à moyenne : rapports d'étude dans le jeu | Préparer la place |
| Optique ; analyse géométrique ; atomistique ; liaisons chimiques ; multiplication cellulaire ; organisation fonctionnelle de la cellule ; anglais (L1) | Faible : codex | Préparer la place |

## 10. Moteur de simulation

- Moteur modulaire séparant physique, hydrologie, hydraulique, agronomie, économie, social et événements. Formules documentées, testables et paramétrables. Le moteur ne dépend pas du rendu 3D (il tourne seul en test).
- Temps : pas journalier, accélérable ; météo aléatoire calibrée sur des séries réelles de la région.
- Bilan hydrique du sol (réserve utile, infiltration, ruissellement, percolation, drainage) et bilan des retenues (apports, évaporation, prélèvements, déversement).
- Écoulement de l'eau sur le relief en 3D, simplifié mais crédible (inspiration Timberborn) : remplissage des bas-fonds, débordements, effet des digues et vannes.
- Croissance des cultures par stades : Kc, stress hydrique, azoté et salin, rendement (approche inspirée de FAO-33 / AquaCrop, simplifiée et documentée).
- Hydraulique : canaux, conduites, pertes de charge, pompes, pressions, puissance et énergie.
- Sol : fertilité, matière organique, salinité, sodicité, érosion, selon les pratiques.
- Économie : coûts indicatifs en FCFA, trésorerie, crédit, prix variables, amortissements.
- Unités et conversions vérifiées : m, ha, mm, m³, L/s, m³/h, kPa, bar, kW, kWh, kg, t, FCFA.
- Tests unitaires pour chaque formule avec exemples vérifiés à la main ; tests de cohérence des bilans (l'eau ne se crée pas, l'argent non plus).

## 11. Données et réalisme

- Une carte, un rapport d'étude et les paramètres de simulation décrivent le même terrain.
- Chaque étude a un coût, une durée, une précision et une incertitude ; le joueur peut approfondir.
- Mesures, estimations et hypothèses sont distinguées ; unités et dates affichées.
- Les ressources ne sont pas infinies : nappe qui baisse, retenue qui s'envase, sol qui se dégrade, matériel qui s'use.
- Les conséquences découlent de mécanismes compréhensibles, jamais de pénalités arbitraires.
- Le contenu (cours, notions, cultures, coûts, prix, procédures, quêtes) est dans des fichiers de données (JSON ou YAML), modifiables sans toucher au moteur.

## 12. Pédagogie et modes de jeu

| Mode | Description |
| --- | --- |
| Prise en main | Tutoriel 3D pas à pas : se déplacer, lire une étude, poser un canal, lancer une campagne |
| Carrière | L'histoire des 5 chapitres (section 6) |
| Scénarios | Missions courtes centrées sur un cours : « La crue de projet », « Le litige foncier », « Le canal qui déborde », « L'eau trop salée » |
| Bureau d'études | Exercices de calcul sur les données de ma partie, corrigés détaillés, contrôle des unités et tolérance d'arrondi |
| Bac à sable | Tout débloqué, paramètres modifiables |
| Codex | Toutes les notions débloquées, classées par cours et niveau, avec leur provenance |

- Pas de « game over » sec : débriefing en quatre parties — ce qui s'est passé, pourquoi, ce que dit mon cours, ce qu'il fallait faire.
- Révision espacée intégrée : les notions où je me trompe reviennent plus souvent dans les missions.
- Évaluation multicritère : qualité du diagnostic, justesse des calculs, sécurité, rentabilité, durabilité, respect des personnes. Le profit seul ne fait pas gagner.
- Checklists réutilisables dans la vraie vie, exportables (exemple : « Avant d'acheter un terrain rural »).

## 13. Interface mobile 3D

- Caméra tactile simple : glisser pour tourner, pincer pour zoomer, double-tap pour aller ; mode avatar à pied et mode vue du dessus.
- Couches activables sur la vue 3D : relief et courbes de niveau, sols, eau, parcelles, réseaux, bâtiments.
- Tableau de bord : trésorerie, eau disponible, état des cultures, alertes, tâches, stocks, maintenance.
- Utilisable d'une main pour les actions courantes, lisible en plein soleil, mode sombre, textes en français.
- Sessions courtes (5-15 min) et longues ; sauvegarde automatique ; jeu entièrement hors ligne.

## 14. Choix techniques (à justifier dans DECISIONS.md)

- Android en priorité ; architecture qui permettra iOS plus tard.
- Moteur : compare Godot 4 (gratuit, export Android, renderer mobile) et Unity (écosystème 3D mobile très mature). Choisis, justifie, note l'alternative. Pas de serveur, pas de coût d'exploitation, pas d'IA nécessaire pour jouer.
- Cible de performance : téléphone Android de 3 à 4 Go de RAM, 30 images/s stables, temps de chargement court, taille d'installation raisonnable. Prévois des niveaux de qualité graphique.
- Ressources 3D, textures, sons et polices libres de droits uniquement, listées avec leur licence dans CREDITS.md ; remplaçables sans toucher au code.
- Architecture séparée : interface et navigation ; données du monde et sauvegardes ; moteur de simulation ; modules métier ; événements ; rapports et tableaux de bord ; contenu pédagogique.
- Modèle de données : région, terrain, parcelle, profil de sol, source d'eau, ouvrage, équipement, culture, campagne, intrant, stock, travailleur, fournisseur, client, tâche, incident, transaction, notion, cours.
- Sauvegarde locale, export et import de sauvegarde.

## 15. Phases et livrables

1. Phase 1 — Analyse et document de conception (GDD) : vision, boucle de jeu, modules, histoire, matrice cours ↔ mécaniques, choix techniques justifiés, architecture et modèle de données, catalogue des formules (variables, unités, hypothèses, sources), risques, limites, plan. Livrables : GDD.md, COURS_MATRICE.md, FORMULES.md, ARCHITECTURE.md, DECISIONS.md.
2. Phase 2 — Tranche verticale jouable en 3D : un bas-fond rizicole de 5 ha près de San-Pédro, sur relief réel ou calibré. Le joueur explore le terrain, sécurise le foncier (version simplifiée), fait la topographie et l'étude de sol, calcule les besoins en eau, pose digues, diguettes et canaux, vérifie le dimensionnement, conduit une campagne de riz avec une sécheresse ou une crue, récolte et vend, puis reçoit son bilan et son débriefing. APK installable.
3. Phase 3 — Moteurs complets et chapitres 1 à 3 de la Carrière.
4. Phase 4 — Intégration des cours un par un, chapitres 4 et 5, eaux souterraines, barrage, pompage sous pression.
5. Phase 5 — Modes annexes, finition graphique, sons, optimisation.
6. Phase 6 — Tests (formules, scénarios, performance sur téléphone modeste) et livraison : code source, APK, instructions de compilation, documentation, liste de ce qui fonctionne et de ce qui reste à faire.

Rappel de la section 2 : enchaîne les phases sans attendre ma validation, en commençant par la Phase 1 puis la Phase 2.

## 16. Règles non négociables et critères de réussite

1. L'exactitude scientifique et légale passe avant le spectaculaire.
2. Ne jamais attribuer à mon cours une information qui n'y figure pas ; toujours distinguer cours / déduit / approfondissement.
3. Le joueur ne prend pas une décision technique majeure sans les informations nécessaires, ou sans accepter explicitement le risque.
4. Les études influencent réellement les résultats ; les erreurs ont des conséquences crédibles, compréhensibles et proportionnées.
5. Le jeu enseigne une démarche d'ingénieur : observer, mesurer, analyser, dimensionner, décider, contrôler, corriger.
6. Aucune fonctionnalité annoncée terminée si elle ne l'est pas.
7. Contenu dans des fichiers de données ; jeu hors ligne sur téléphone modeste ; licences respectées.
8. Aucune personne réelle comme personnage ; aucun logo ni marque réelle sans licence.

## 17. Pour ajouter un cours plus tard

> **« Voici le cours [intitulé], niveau [L1/L2/L3], semestre [S…], type [CM/TD/TP]. Analyse-le, mets à jour COURS_MATRICE.md, propose les mécaniques et missions qui l'exploitent, puis intègre-le dans les fichiers de données. Ne modifie pas ce qui fonctionne déjà sans me le dire. »**

**COMMENCE MAINTENANT PAR LA PHASE 1, PUIS ENCHAÎNE SUR LA PHASE 2.**
