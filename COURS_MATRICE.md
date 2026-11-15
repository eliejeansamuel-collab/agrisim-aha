# Matrice de traçabilité : cours ↔ notions ↔ mécaniques

État : **Jouable** (dans la tranche verticale) · **Moteur** (formule codée et testée, pas encore d'écran) · **Prévu** (chapitre de Carrière visé) · **Codex** (fiche de culture scientifique).

## Licence 3 — semestre 5

| Cours (ECUE) | Statut du cours | Notions clés relevées dans le support | Mécanique de jeu | État |
| --- | --- | --- | --- | --- |
| Bases techniques et pilotage de projet d'irrigation (FOI71152) | Terminé | Efficience, dose, Qfc ; ouvrages de tête, transport, colature ; gravitaire / aspersion / micro-irrigation ; CC, PFP, RU, RFU ; ET0, Kc, ETc ; besoins nets et bruts ; tour d'eau ; études préalables ; APS / APD ; modes de distribution ; Manning-Strickler ; vannes, modules à masques, déversoirs ; AUE | Écrans Études, Besoins en eau (quiz Qfc), Conception (canal), campagne, débriefing | **Jouable** |
| Bilan hydrique (FOI71151) | Terminé | États de l'eau, chaleur latente ; bilan global ; P = E + R + I ± ΔS ; Thornthwaite, Turc ; ETc = Kc × ET0 | Bilan d'eau journalier affiché pendant la campagne, écart de fermeture au bilan | **Jouable** |
| Aménagement et conception de systèmes d'irrigation (HYS71152) | En cours | Continuum, carte d'unités d'aménagement ; faisabilité ; coûts et amortissement d'un barrage ; CEC, pédotransfert, RU ; ETP bac ; Kr = ETR/ETM ; puissance de pompage ; RFU et tour d'eau ; efficiences ; aspersion ; matériel (vannes, bornes) | Stress Ks et rendement ; puissance de pompe ; amortissement (VAN) | **Jouable** (stress, VAN) / **Moteur** (pompe) / **Prévu** ch. 4 (aspersion, matériel) |
| Hydrologie appliquée (ACH71152) | En cours | Bassin versant, Gravelius ; Thiessen, isohyètes ; Turc, Penman, Thornthwaite ; Horton ; courbe de tarage ; méthode rationnelle ; Gumbel, période de retour ; temps de concentration ; hydrogramme ; étiages | Étude hydrologique, crue tirée selon sa période de retour, choix de la hauteur de digue | **Jouable** (crue, période de retour) / **Moteur** (rationnelle, Kirpich, Gumbel, Thiessen) |
| Stockage des eaux de surface (MSE71151) | Terminé | Choix du site, morphologie de vallée ; besoins (bétail, AEP, irrigation) ; pertes (infiltration, évaporation) ; sédimentation ; types de barrages ; barrage en terre ; largeur en crête, revanche, talus ; auscultation | Conception d'une retenue : site, digue, déversoir, envasement | **Moteur** (crête, volume, bilan de retenue) / **Prévu** ch. 4 |
| Mobilisation des eaux souterraines (MSE71152) | Terminé | Aquifère, aquitard ; provinces hydrogéologiques (socle) ; porosité totale et efficace ; Darcy ; transmissivité ; Dupuit, Thiem, Jacob ; prospection ; essais de pompage ; débit critique, débit spécifique | Implantation d'un forage, essai de pompage, rabattement, surexploitation | **Moteur** (Darcy, débit spécifique) / **Prévu** ch. 4 |
| Mobilisation des eaux non conventionnelles (MSE71153) | Terminé | Typologie des ENC ; REUT, filières d'épuration ; normes sanitaires ; CAPEX / OPEX, coût au m³ ; acceptabilité sociale | Réutiliser des eaux traitées pour le maraîchage : risque sanitaire, acceptabilité, coût | **Prévu** ch. 5 |
| Qualité des eaux d'irrigation (HYS71151) | Terminé | MES, pH, turbidité ; balance ionique ; CE ; SAR ; RSC ; classification USSL, Wilcox ; tolérance des cultures à la salinité ; colmatage du goutte-à-goutte | Analyse d'eau avant de choisir la source ; sol qui se sodise ; goutteurs colmatés | **Moteur** (SAR, RSC, classes) / **Prévu** scénario « L'eau trop salée » |
| Agro-climatologie (ACH71151) | Terminé | Climat, zones climatiques de Côte d'Ivoire ; pluie, température, humidité, vent, rayonnement ; outils de mesure ; risques climatiques et gestion | Choix de la date de repiquage ; poche de sécheresse ; effets du vent et de la chaleur | **Jouable** (dates, sécheresse) / **Prévu** (vent, chaleur) |
| Manipulation des données climatiques (FOI71153) | En cours | Normales 1991-2020 ; contrôle de qualité ; indices ETCCDI (RClimDex) ; tendances ; données satellitaires (CHIRPS, TAMSAT, WaPOR) | Mini-jeu : nettoyer une série de pluie, calculer une normale et un indice avant de dimensionner | **Prévu** (Bureau d'études) |
| Amendements des sols (FEF71151) | En cours | pH, complexe d'échange ; chaulage ; compost, C/N, étapes du compostage ; effets sur structure, rétention d'eau | Corriger un sol acide ; fabriquer et épandre du compost ; effet sur RU et rendement | **Prévu** ch. 1 (paramètre `facteur_fertilite` déjà dans le moteur) |
| Fertilisation-fertigation (FEF71152) | En cours | Dose optimale et économique ; diagnostic de carence ; fumure de fond, de redressement ; flux de masse, diffusion ; efficiences des engrais ; fertigation | Plan de fumure à partir d'une analyse de sol ; fertigation en goutte-à-goutte | **Prévu** ch. 1 et 5 |
| Topographie (GET71153) | En cours | Unités, angles, gisement ; nivellement direct (mire arrière − mire avant), indirect ; cheminement | Étude topographique : courbes de niveau, lecture d'altitude ; mini-jeu de nivellement | **Jouable** (courbes, altitude) / **Prévu** (carnet de nivellement) |
| Cartographie (GET71152) | En cours | Cartes topographiques et thématiques ; règles ; profil topographique ; projections UTM et TMCI | Tracer un profil en long du canal sur la carte ; coordonnées | **Prévu** ch. 3 |
| Géomatique (GET71151) | En cours — **support manquant** | — | Couches SIG de la carte régionale | En attente du cours |
| Analyse de données, R (STA7115) | En cours — manquants | — | Bureau d'études : statistiques de pluie | En attente |
| Culture entrepreneuriale, microéconomie (ENE7115) | En cours — manquants | — | Plan d'affaires, financement | En attente (VAN / TRI codés en approfondissement) |

## Licence 1 et 2 — tronc commun

| Cours | Rôle | Lien L1/L2 → L3 → jeu | État |
| --- | --- | --- | --- |
| Hydraulique générale + MDF (4 chapitres) (L2) | Cœur | Bernoulli, pertes de charge, Reynolds, Manning → dimensionnement L3 → canal qui déborde, pompe sous-dimensionnée | **Jouable** (Manning) / **Moteur** |
| Hydrologie (L2) | Cœur | Cycle et bilan, bassin versant, hydrométrie → Hydrologie appliquée → débit du marigot, crue | **Jouable** |
| Pédogenèse (L2) | Cœur | Formation et types de sols → étude pédologique → percolation, RU | **Jouable** (3 classes de sol) |
| Géomorphologie (L2) | Cœur | Formes du relief, bas-fonds → choix du site → carte 3D | **Prévu** (choix entre plusieurs sites) |
| Physiologie végétale (L2) | Cœur | Nutrition hydrique, transpiration, stomates ; nutrition minérale et azotée ; photosynthèse → stress Ks, rendement | **Jouable** (stress) |
| Thermodynamique physique et chimique (L2) | Cœur | Chaleur latente, changements d'état → évaporation, ET0 ; énergie → pompage | **Moteur** (Penman-Monteith) |
| Probabilités et statistiques (L1) | Cœur | Moyenne, écart-type, régression, lois → Gumbel, période de retour → hauteur de digue | **Jouable** |
| Algèbre et géométrie (L1) | Cœur | Calcul, géométrie → surfaces, sections, volumes de terrassement | **Jouable** (devis) |
| Électricité (L1) | Cœur | Loi d'Ohm, puissance → moteur de pompe, solaire | **Prévu** ch. 4 |
| Réactions ioniques en solution aqueuse (L1) | Cœur | Acides-bases, pH, équilibres, précipitation → CE, SAR, RSC → salinisation | **Moteur** |
| Biologie végétale | Secondaire | Botanique → choix des cultures | **Prévu** |
| Cinétique chimique | Secondaire | Vitesse de réaction → décomposition du compost, libération des engrais | **Prévu** |
| Biochimie métabolique et énergétique (L2) | Secondaire | Photosynthèse, respiration → rendement potentiel | Codex |
| Biochimie structurale (glucides, lipides, protides) | Secondaire | Composition des récoltes → qualité, post-récolte | Codex |
| Microbiologie | Secondaire | Bactéries, métabolisme → compost, qualité sanitaire de l'eau, REUT | **Prévu** ch. 5 |
| Génétique (fondamentaux, mutations) | Secondaire | Hérédité → choix variétal | Codex |
| Civisme | Secondaire | Institutions, comportement citoyen → relations avec autorités et communautés | **Prévu** ch. 2 |
| Immunologie et antimicrobiens | Codex | Santé en pisciculture et élevage | Codex |
| Biologie moléculaire, acides nucléiques | Codex | — | Codex |
| Biologie du développement (L1) | Codex | — | Codex |
| Électrostatique (L1) | Codex | Principe des capteurs | Codex |

## Cours manquants

| Cours | Importance | Ce qui est fait en attendant |
| --- | --- | --- |
| Droit foncier rural (L2) | Très haute | Module foncier simplifié, marqué « approfondissement, à vérifier » |
| Gestion et évaluation de projet (L2) | Très haute | VAN, TRI, délai : méthodes standard |
| Méthode de rédaction de projet, Communication en milieu rural, Éducation environnementale (L2) | Haute | Place prévue (chapitres 2 et 4) |
| Géologie structurale, Matériaux de l'écorce terrestre, Mécanique (L1) | Moyenne | Place prévue (barrage, forage) |
| Entreprises agricoles, IAA, Production animale et halieutique (L1) | Moyenne | Place prévue (chapitre 5) |
| Autres (rédaction, optique, atomistique, liaisons, biologie cellulaire, anglais) | Faible | Codex |

## Notions déjà dans le Codex du jeu

15 fiches (`jeu/donnees/notions.json`), chacune avec sa provenance et sa référence de cours : foncier, études préalables, texture, RU/RFU, ETc, besoin brut, Qfc, Manning-Strickler, drainage, période de retour, bilan hydrique, stress hydrique, Ky, VAN, tour d'eau et AUE.
