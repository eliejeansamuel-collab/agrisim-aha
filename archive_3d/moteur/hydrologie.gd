class_name Hydrologie
extends RefCounted
## Bassin versant, crues, retenues, qualité des eaux.
## Sources : cours L3 « Hydrologie appliquée », « Stockage des eaux de surface »,
## « Qualité des eaux d'irrigation », cours L2 « Hydrologie », L1 « Probabilités et statistiques ».

## Indice de compacité de Gravelius : Kc = 0,28 . P / sqrt(A)  (P en km, A en km2)
static func gravelius(perimetre_km: float, aire_km2: float) -> float:
	return 0.28 * perimetre_km / sqrt(aire_km2)

## Méthode rationnelle : Q = C . i . A (unités SI : i en m/s, A en m2)
static func debit_rationnel(c: float, intensite_mm_h: float, aire_km2: float) -> float:
	return c * (intensite_mm_h / 1000.0 / 3600.0) * (aire_km2 * 1.0e6)

## Temps de concentration de Kirpich (minutes) : 0,0195 . L^0,77 . S^-0,385 (L en m, S en m/m)
static func tc_kirpich_min(longueur_m: float, pente: float) -> float:
	return 0.0195 * pow(longueur_m, 0.77) * pow(pente, -0.385)

## Quantile de Gumbel pour la période de retour T (ajustement par les moments)
static func gumbel_quantile(moyenne: float, ecart_type: float, t_retour: float) -> float:
	var k := -sqrt(6.0) / PI * (0.5772 + log(log(t_retour / (t_retour - 1.0))))
	return moyenne + k * ecart_type

## Probabilité qu'une crue de période T survienne au moins une fois en n années
static func risque_sur_n_ans(t_retour: float, n: int) -> float:
	return 1.0 - pow(1.0 - 1.0 / t_retour, n)

static func moyenne(v: Array) -> float:
	var s := 0.0
	for x in v:
		s += x
	return s / v.size()

static func ecart_type(v: Array) -> float:
	var m := moyenne(v)
	var s := 0.0
	for x in v:
		s += (x - m) * (x - m)
	return sqrt(s / (v.size() - 1))

## Pluie moyenne par polygones de Thiessen
static func thiessen(pluies: Array, surfaces: Array) -> float:
	var s := 0.0
	var a := 0.0
	for i in pluies.size():
		s += pluies[i] * surfaces[i]
		a += surfaces[i]
	return s / a

## ETR annuelle de Turc (mm) : P / sqrt(0,9 + P2/L2), L = 300 + 25T + 0,05T3
static func etr_turc(p_mm: float, t_moy: float) -> float:
	var l := 300.0 + 25.0 * t_moy + 0.05 * pow(t_moy, 3)
	return p_mm / sqrt(0.9 + p_mm * p_mm / (l * l))

## Bilan P = E + R + I +/- dS : infiltration par différence (cours Bilan hydrique)
static func infiltration_par_bilan(p: float, etr: float, ruissellement: float, ds: float = 0.0) -> float:
	return p - etr - ruissellement - ds

## Largeur en crête d'un barrage en terre (cours Stockage des eaux de surface, ch. V)
static func crete_knappen(h: float) -> float:
	return 1.65 * sqrt(h)

static func crete_preece(h: float) -> float:
	return 1.10 * sqrt(h) + 1.0

## Volume approché d'une retenue (m3) : V = L . l . H / 2,67 (même cours)
static func volume_retenue(longueur: float, largeur: float, hauteur: float) -> float:
	return longueur * largeur * hauteur / 2.67

## Population future : Pop(a+n) = Pop(a) . (1 + taux)^n
static func population_future(pop: float, taux: float, n: int) -> float:
	return pop * pow(1.0 + taux, n)

## Bilan journalier d'une retenue (m3). Renvoie [volume, déversé, déficit]
static func bilan_retenue(volume: float, capacite: float, apport: float, evap_mm: float,
		surface_m2: float, prelevement: float, infiltration: float = 0.0) -> Array:
	var v := volume + apport - evap_mm / 1000.0 * surface_m2 - infiltration
	v = max(v, 0.0)
	var servi: float = min(prelevement, v)
	v -= servi
	var deverse: float = max(v - capacite, 0.0)
	v -= deverse
	return [v, deverse, prelevement - servi]

## SAR = Na / sqrt((Ca + Mg) / 2), concentrations en méq/L
static func sar(na: float, ca: float, mg: float) -> float:
	return na / sqrt((ca + mg) / 2.0)

## RSC = (CO3 + HCO3) - (Ca + Mg), en méq/L
static func rsc(co3: float, hco3: float, ca: float, mg: float) -> float:
	return (co3 + hco3) - (ca + mg)

## Classes du cours : C1 < 250 ; C2 250-750 ; C3 750-2250 ; C4 > 2250 µS/cm
static func classe_salinite(ce_us_cm: float) -> String:
	if ce_us_cm < 250.0: return "C1"
	if ce_us_cm < 750.0: return "C2"
	if ce_us_cm < 2250.0: return "C3"
	return "C4"

## Classes du cours : S1 < 10 ; S2 10-18 ; S3 18-26 ; S4 > 26
static func classe_sar(v: float) -> String:
	if v < 10.0: return "S1"
	if v < 18.0: return "S2"
	if v < 26.0: return "S3"
	return "S4"

static func classe_rsc(v: float) -> String:
	if v < 1.25: return "nul"
	if v < 2.5: return "léger à modéré"
	return "sévère"

## Loi de Darcy : Q = K . i . A
static func debit_darcy(k: float, gradient: float, section: float) -> float:
	return k * gradient * section

## Débit spécifique d'un forage (m3/h par m de rabattement)
static func debit_specifique(q: float, rabattement: float) -> float:
	return q / rabattement
