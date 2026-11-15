# Catalogue des formules

Provenance : **C** = dans mon cours · **D** = reformulé ou déduit du cours · **A** = approfondissement (hors cours).
« Testé » = un exemple vérifié à la main ou tiré d'un exercice corrigé figure dans `jeu/tests/run_tests.gd`.

## 1. Sol, plante, atmosphère (`moteur/eau.gd`)

| Formule | Variables et unités | Prov. | Source | Fonction | Testé |
| --- | --- | --- | --- | --- | --- |
| 1 mm = 10 m³/ha | lame d'eau, volume | C | L3 Bases techniques ch. 1 | `mm_vers_m3` | oui (exercice 2 ha × 5 mm = 100 m³) |
| E = V utile ÷ V prélevé ; Eg = Et × Ed × Ea | sans unité | C | L3 Bases techniques ch. 1 et 5.4 | `efficience`, `efficience_globale` | oui (86,7 ; 88,5 ; 82,6 ; 63,3 %) |
| RU = CC − PFP | % volumique × profondeur (mm) → mm | C | L3 Bases techniques ch. 3 | `reserve_utile` | oui |
| RFU = p × RU, p = 0,4 à 0,6 | mm | C | L3 Bases techniques ch. 3 ; L3 Aménagement (RFU = 72 mm) | `rfu` | oui |
| ETc = Kc × ET0 | mm/j | C | L3 Bases techniques ch. 4 ; Bilan hydrique | `etc` | oui (5 × 1,15 = 5,75) |
| Besoin net = ETc − Peff | mm/j | C | L3 Bases techniques ch. 4 | `besoin_net` | oui |
| Besoin brut = besoin net ÷ Ea | mm/j | C | idem | `besoin_brut` | oui (6,39 mm/j) |
| Tour d'eau = dose nette ÷ ETc | jours | C | idem ; L3 Aménagement (Te = RFU/ETr = 12 j) | `tour_eau` | oui |
| Qfc = besoin brut × 10 000 ÷ 86 400 | L/s/ha | D | définition du Qfc, L3 Bases techniques ch. 1 | `debit_fictif_continu` | oui (8,64 mm/j = 1 L/s/ha) |
| ETP = Kb × Ev bac, Kb = 0,75 | mm/j | C | L3 Aménagement | `etp_bac` | oui |
| Kc par 4 stades, interpolation linéaire | — | C + A | stades : L3 Bases techniques ch. 4 ; interpolation : FAO-56 | `kc_du_jour` | oui |
| ET0 Penman-Monteith FAO-56 | Tmin, Tmax °C ; HR % ; u2 m/s ; Rs MJ/m²/j | C (citée) + A (équations) | cours : formule citée comme norme ; équations : FAO-56 | `et0_penman_monteith` | oui (FAO-56 ex. 18 : 3,88 mm/j) |
| ET0 Hargreaves | Tmin, Tmax, Ra | A | FAO-56 éq. 52 | `et0_hargreaves` | non |
| Pluie efficace USDA-SCS | mm/mois | A | CROPWAT | `pluie_efficace_mensuelle` | oui |
| Ks = (RU − Dr) ÷ (RU − RFU) | — | A | FAO-56 | `ks_stress` | oui |
| 1 − Ya/Ym = Ky (1 − ETr/ETm) | — | A | FAO-33 ; le cours L3 Aménagement utilise Kr = ETR/ETM | `rendement_relatif` | oui |

## 2. Hydraulique (`moteur/hydraulique.gd`)

| Formule | Variables et unités | Prov. | Source | Fonction | Testé |
| --- | --- | --- | --- | --- | --- |
| S = (b + m·h)·h ; P = b + 2h√(1+m²) | m, m² | C | L3 Bases techniques ch. 6 | `section_trapeze`, `perimetre_trapeze` | oui |
| Q = Ks · S · Rh^(2/3) · √I | m³/s | C | L3 Bases techniques ch. 6 ; L2 Hydraulique ch. 5 | `debit_manning` | oui |
| Hauteur normale par approximations successives | m | C | L3 Bases techniques ch. 6 (exercice) | `hauteur_normale` | oui |
| Fr = U ÷ √(g·Dh) | — | C | L2 Hydraulique ch. 5 | `froude` | oui |
| Re = V·D ÷ ν ; laminaire < 2000, turbulent > 4000 | — | C | L2 Hydraulique ch. 4 | `reynolds` | indirect |
| J = λ · L/D · V²/2g | m | C | L2 Hydraulique ch. 4 (Darcy-Weisbach) | `perte_charge_lineaire` | oui |
| λ = 64/Re (laminaire) | — | C | L2 Hydraulique ch. 4 | `lambda_pdc` | oui |
| λ turbulent : Swamee-Jain | — | A | approximation explicite de Colebrook | `lambda_pdc` | oui |
| P = ρ·g·Q·H ÷ η | kW | C | L3 Aménagement (« 1 m³/s à 10 m = 125 kW ») | `puissance_pompe_kw` | oui |
| Charge = z + p/ρg + V²/2g | m | C | L2 Hydraulique ch. 3 ; MDF ch. 3 | `charge` | non |
| p = ρ·g·h | Pa | C | MDF ch. 2 ; L2 Hydraulique ch. 2 | `pression_hydrostatique` | oui |
| Déversoir : Q = μ·L·√(2g)·h^(3/2) | m³/s | C (image) | L3 Bases techniques ch. 6 | `debit_deversoir` | oui |
| Vanne noyée : Q = μ·S·√(2g·Δh) | m³/s | C (image) | L3 Bases techniques ch. 6 | `debit_vanne_noyee` | non |

## 3. Hydrologie, retenues, qualité (`moteur/hydrologie.gd`)

| Formule | Variables et unités | Prov. | Source | Fonction | Testé |
| --- | --- | --- | --- | --- | --- |
| Kc = 0,28 · P ÷ √A | km, km² | C | L3 Hydrologie appliquée (Gravelius) | `gravelius` | oui |
| Q = C · i · A | SI | C | L3 Hydrologie appliquée I.4 | `debit_rationnel` | oui |
| tc Kirpich | min, m, m/m | C (image) | L3 Hydrologie appliquée II.2 | `tc_kirpich_min` | oui |
| Quantile de Gumbel | — | C (citée) + A | L3 Hydrologie appliquée ; L1 Proba-stat | `gumbel_quantile` | oui |
| Risque = 1 − (1 − 1/T)^n | — | D | L3 Hydrologie appliquée I.6 | `risque_sur_n_ans` | oui |
| Thiessen | mm | C | L3 Hydrologie appliquée | `thiessen` | oui |
| ETR Turc annuelle | mm, °C | C (image) | L3 Hydrologie appliquée ; Bilan hydrique | `etr_turc` | oui |
| P = E + R + I ± ΔS | mm | C | L3 Bilan hydrique ch. 3 | `infiltration_par_bilan`, `Campagne` | oui |
| Crête : L = 1,65·√H (Knappen) ; L = 1,10·√H + 1 (Preece) | m | C | L3 Stockage des eaux de surface ch. V | `crete_knappen`, `crete_preece` | oui |
| V = L · l · H ÷ 2,67 | m³ | C | idem | `volume_retenue` | oui |
| Pop(a+n) = Pop(a)·(1+δ)^n | hab. | C | idem ch. II | `population_future` | non |
| SAR = Na ÷ √((Ca+Mg)/2) | méq/L | C (image) | L3 Qualité des eaux ch. II | `sar` | oui |
| RSC = (CO3 + HCO3) − (Ca + Mg) | méq/L | C (image) | idem | `rsc` | oui |
| Classes C1-C4, S1-S4, RSC | µS/cm | C | idem | `classe_*` | oui |
| Q = K · i · A | m³/s | C | L3 Eaux souterraines (Darcy) | `debit_darcy` | non |
| Débit spécifique = Q ÷ s | m³/h/m | C | idem | `debit_specifique` | non |

## 4. Économie (`moteur/economie.gd`)

VAN, TRI, délai de récupération, annuité constante, amortissement linéaire, marge, seuil de rentabilité : **A** (méthodes standard ; le cours « Gestion et évaluation de projet » de L2 n'est pas fourni). Toutes testées.

## 5. Points à vérifier avec les enseignants

1. **Pédotransfert du cours Aménagement** : le support écrit `pF2,5 = 0,038 × (A+L) % + 1,5` et `pF4,2 = 0,234 × A % + 1,3`. Tel quel, pour 30 % d'argile et 30 % de limon : pF2,5 = 3,8 % et pF4,2 = 8,3 %, soit une RU négative. Le coefficient est probablement 0,38. Codé tel qu'écrit (`pf25_cours`), **non utilisé** par la simulation.
2. **Formules présentes en image dans les PDF** (non extractibles) : SAR, RSC, Turc, Kirpich, déversoir, vanne, évaporation de Pouyaud, revanche du barrage, sédimentation (Grésillon, Karambiri), Dupuit, Thiem, Cooper-Jacob. Celles qui sont codées utilisent l'expression standard ; à comparer au support.
3. **Hauteur manométrique** : le cours Aménagement exprime Hm en Pa ; le code prend des mètres de colonne d'eau.
4. **Ks = 30** pour un canal en terre, **efficience 0,6** : valeurs usuelles dans la fourchette du cours (0,45 à 0,65), à confirmer.
5. **Cours de topographie** : lu par OCR (qualité moyenne) ; les formules de nivellement ne sont pas encore codées.
6. **Formules non encore codées** : évaporation des retenues, sédimentation, revanche, essais de pompage, fertilisation (efficiences EA, ER, EP, EI), CEC, indices climatiques ETCCDI.
