class_name Eau
extends RefCounted
## Sol - plante - atmosphère : besoins en eau et pilotage de l'irrigation.
## Sources : cours L3 « Bases techniques et pilotage de projet d'irrigation » (ch. 1, 3, 4, 5),
## « Aménagement et conception de systèmes d'irrigation », FAO-56 (approfondissement).

const MM_EN_M3_PAR_HA := 10.0  # 1 mm = 10 m3/ha (cours Bases techniques, ch. 1)

static func mm_vers_m3(mm: float, surface_ha: float) -> float:
	return mm * MM_EN_M3_PAR_HA * surface_ha

static func m3_vers_mm(m3: float, surface_ha: float) -> float:
	return m3 / (MM_EN_M3_PAR_HA * surface_ha)

## ETc = Kc x ET0 (cours Bases techniques, ch. 4)
static func etc(et0: float, kc: float) -> float:
	return et0 * kc

## Besoin net = ETc - pluie efficace, jamais négatif
static func besoin_net(etc_mm: float, pluie_efficace: float) -> float:
	return max(0.0, etc_mm - pluie_efficace)

## Besoin brut = besoin net / efficience (0 à 1)
static func besoin_brut(besoin_net_mm: float, efficience: float) -> float:
	assert(efficience > 0.0 and efficience <= 1.0)
	return besoin_net_mm / efficience

## Efficience = volume en sortie / volume en entrée
static func efficience(v_sortie: float, v_entree: float) -> float:
	return v_sortie / v_entree

## Efficience globale = produit des efficiences (transport x distribution x application)
static func efficience_globale(e: Array) -> float:
	var p := 1.0
	for x in e:
		p *= x
	return p

## RU en mm à partir de CC et PFP en % volumique et de la profondeur racinaire en mm
static func reserve_utile(cc_pct: float, pfp_pct: float, profondeur_mm: float) -> float:
	return (cc_pct - pfp_pct) / 100.0 * profondeur_mm

## RFU = fraction p de la RU (0,4 à 0,6 selon le cours)
static func rfu(ru_mm: float, p: float = 0.5) -> float:
	return ru_mm * p

## Tour d'eau (jours) = dose nette / ETc
static func tour_eau(dose_nette_mm: float, etc_mm_j: float) -> float:
	return dose_nette_mm / etc_mm_j

## Débit fictif continu (L/s/ha) pour un besoin brut en mm/jour : 1 mm/j = 10 m3/ha/j
static func debit_fictif_continu(besoin_brut_mm_j: float) -> float:
	return besoin_brut_mm_j * 10000.0 / 86400.0

## Débit d'équipement (m3/s) si on n'irrigue que h heures par jour
static func debit_equipement(qfc_l_s_ha: float, surface_ha: float, heures_par_jour: float = 24.0) -> float:
	return qfc_l_s_ha * surface_ha * (24.0 / heures_par_jour) / 1000.0

## Pédotransfert du cours « Aménagement hydro-agricole » (humidités pondérales en %).
## ATTENTION : tel qu'écrit dans le support, donne une RU négative pour les sols argileux ;
## coefficient à vérifier avec l'enseignant (voir FORMULES.md). Non utilisé par la simulation.
static func pf25_cours(argile_pct: float, limon_pct: float) -> float:
	return 0.038 * (argile_pct + limon_pct) + 1.5

static func pf42_cours(argile_pct: float) -> float:
	return 0.234 * argile_pct + 1.3

## ETP à partir du bac : ETP = Kb x Evbac (cours Aménagement, Kb = 0,75)
static func etp_bac(ev_bac: float, kb: float = 0.75) -> float:
	return kb * ev_bac

## Pluie efficace mensuelle USDA-SCS (méthode CROPWAT, approfondissement)
static func pluie_efficace_mensuelle(p_mm: float) -> float:
	if p_mm <= 250.0:
		return p_mm * (125.0 - 0.2 * p_mm) / 125.0
	return 125.0 + 0.1 * p_mm

## Pression de vapeur saturante (kPa)
static func e0(t: float) -> float:
	return 0.6108 * exp(17.27 * t / (t + 237.3))

## Rayonnement extraterrestre Ra (MJ/m2/j), FAO-56 éq. 21
static func ra(lat_deg: float, jour: int) -> float:
	var phi := deg_to_rad(lat_deg)
	var dr := 1.0 + 0.033 * cos(TAU * jour / 365.0)
	var d := 0.409 * sin(TAU * jour / 365.0 - 1.39)
	var ws := acos(-tan(phi) * tan(d))
	return (24.0 * 60.0 / PI) * 0.0820 * dr * (ws * sin(phi) * sin(d) + cos(phi) * cos(d) * sin(ws))

## ET0 Penman-Monteith FAO-56 (mm/j), pas journalier. rs en MJ/m2/j, u2 en m/s.
static func et0_penman_monteith(tmin: float, tmax: float, rhmin: float, rhmax: float,
		u2: float, rs: float, lat_deg: float, altitude: float, jour: int) -> float:
	var tm := (tmin + tmax) / 2.0
	var p := 101.3 * pow((293.0 - 0.0065 * altitude) / 293.0, 5.26)
	var gamma := 0.000665 * p
	var es := (e0(tmax) + e0(tmin)) / 2.0
	var ea := (e0(tmin) * rhmax / 100.0 + e0(tmax) * rhmin / 100.0) / 2.0
	var delta := 4098.0 * e0(tm) / pow(tm + 237.3, 2)
	var r_a := ra(lat_deg, jour)
	var rso := (0.75 + 2e-5 * altitude) * r_a
	var rns := 0.77 * rs
	var rnl: float = 4.903e-9 * (pow(tmax + 273.16, 4) + pow(tmin + 273.16, 4)) / 2.0 \
		* (0.34 - 0.14 * sqrt(ea)) * (1.35 * min(rs / rso, 1.0) - 0.35)
	var rn: float = rns - rnl
	return (0.408 * delta * rn + gamma * 900.0 / (tm + 273.0) * u2 * (es - ea)) \
		/ (delta + gamma * (1.0 + 0.34 * u2))

## ET0 Hargreaves (mm/j) quand on n'a que les températures (approfondissement FAO-56 éq. 52)
static func et0_hargreaves(tmin: float, tmax: float, lat_deg: float, jour: int) -> float:
	var tm := (tmin + tmax) / 2.0
	return 0.0023 * (tm + 17.8) * sqrt(max(tmax - tmin, 0.0)) * ra(lat_deg, jour) * 0.408

## Kc du jour selon les 4 stades (cours Bases techniques ch. 4 ; interpolation FAO-56)
static func kc_du_jour(jour: int, durees: Array, kc_ini: float, kc_mid: float, kc_fin: float) -> float:
	var d1: int = durees[0]
	var d2: int = d1 + durees[1]
	var d3: int = d2 + durees[2]
	var d4: int = d3 + durees[3]
	if jour <= d1:
		return kc_ini
	if jour <= d2:
		return kc_ini + (kc_mid - kc_ini) * float(jour - d1) / float(durees[1])
	if jour <= d3:
		return kc_mid
	if jour <= d4:
		return kc_mid + (kc_fin - kc_mid) * float(jour - d3) / float(durees[3])
	return kc_fin

## Coefficient de stress Ks (FAO-56) : 1 tant que l'épuisement <= RFU, puis décroît jusqu'à 0 au PFP
static func ks_stress(epuisement_mm: float, ru_mm: float, rfu_mm: float) -> float:
	if epuisement_mm <= rfu_mm:
		return 1.0
	return clamp((ru_mm - epuisement_mm) / (ru_mm - rfu_mm), 0.0, 1.0)

## Rendement relatif FAO-33 : 1 - Ya/Ym = Ky (1 - ETr/ETm)
static func rendement_relatif(etr_total: float, etm_total: float, ky: float) -> float:
	if etm_total <= 0.0:
		return 0.0
	return clamp(1.0 - ky * (1.0 - etr_total / etm_total), 0.0, 1.0)
