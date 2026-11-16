class_name Hydraulique
extends RefCounted
## Canaux, conduites, ouvrages, pompage.
## Sources : cours L2 « Hydraulique générale » (ch. 3 à 5), MDF ch. 3-4,
## cours L3 « Bases techniques » ch. 6, « Aménagement » (puissance de pompage).

const G := 9.81
const RHO := 1000.0
const NU := 1.0e-6  # viscosité cinématique de l'eau à ~20 °C (m2/s)

static func section_trapeze(b: float, h: float, m: float) -> float:
	return (b + m * h) * h

static func perimetre_trapeze(b: float, h: float, m: float) -> float:
	return b + 2.0 * h * sqrt(1.0 + m * m)

## Manning-Strickler : Q = Ks . S . Rh^(2/3) . I^(1/2)
static func debit_manning(ks: float, b: float, h: float, m: float, pente: float) -> float:
	if h <= 0.0:
		return 0.0
	var s := section_trapeze(b, h, m)
	var rh := s / perimetre_trapeze(b, h, m)
	return ks * s * pow(rh, 2.0 / 3.0) * sqrt(pente)

## Hauteur normale par approximations successives (dichotomie), comme l'exercice du ch. 6
static func hauteur_normale(q: float, ks: float, b: float, m: float, pente: float) -> float:
	var lo := 0.0
	var hi := 20.0
	for i in 60:
		var mid := (lo + hi) / 2.0
		if debit_manning(ks, b, mid, m, pente) < q:
			lo = mid
		else:
			hi = mid
	return (lo + hi) / 2.0

static func vitesse(q: float, section: float) -> float:
	return q / section

## Froude = U / sqrt(g.Dh), Dh = S / largeur au miroir
static func froude(q: float, b: float, h: float, m: float) -> float:
	var s := section_trapeze(b, h, m)
	var miroir := b + 2.0 * m * h
	return (q / s) / sqrt(G * s / miroir)

static func reynolds(v: float, d: float) -> float:
	return v * d / NU

## Coefficient de perte de charge : 64/Re en laminaire (Re < 2000), Swamee-Jain en turbulent
static func lambda_pdc(re: float, rugosite: float, d: float) -> float:
	if re < 2000.0:
		return 64.0 / max(re, 1.0)
	return 0.25 / pow(log(rugosite / (3.7 * d) + 5.74 / pow(re, 0.9)) / log(10.0), 2)

## Perte de charge linéaire Darcy-Weisbach (m) : J = lambda . L/D . V2/2g
static func perte_charge_lineaire(q: float, d: float, longueur: float, rugosite: float = 0.0001) -> float:
	var v := q / (PI * d * d / 4.0)
	var lam := lambda_pdc(reynolds(v, d), rugosite, d)
	return lam * longueur / d * v * v / (2.0 * G)

## Perte de charge singulière : K . V2/2g
static func perte_charge_singuliere(k: float, v: float) -> float:
	return k * v * v / (2.0 * G)

## HMT = hauteur géométrique + pertes de charge + pression utile en sortie (m)
static func hmt(h_geo: float, pdc: float, pression_utile_m: float = 0.0) -> float:
	return h_geo + pdc + pression_utile_m

## Puissance absorbée (kW) = rho.g.Q.H / rendement
static func puissance_pompe_kw(q_m3_s: float, hmt_m: float, rendement: float) -> float:
	return RHO * G * q_m3_s * hmt_m / rendement / 1000.0

static func energie_kwh(puissance_kw: float, heures: float) -> float:
	return puissance_kw * heures

## Déversoir rectangulaire à seuil mince : Q = mu . L . sqrt(2g) . h^(3/2)
static func debit_deversoir(largeur: float, h: float, mu: float = 0.42) -> float:
	return mu * largeur * sqrt(2.0 * G) * pow(max(h, 0.0), 1.5)

## Vanne ou orifice noyé : Q = mu . S . sqrt(2g . dh)
static func debit_vanne_noyee(section: float, dh: float, mu: float = 0.6) -> float:
	return mu * section * sqrt(2.0 * G * max(dh, 0.0))

## Charge de Bernoulli (m) : z + p/(rho g) + V2/2g
static func charge(z: float, pression_pa: float, v: float) -> float:
	return z + pression_pa / (RHO * G) + v * v / (2.0 * G)

## Pression hydrostatique (Pa) à la profondeur h
static func pression_hydrostatique(h: float) -> float:
	return RHO * G * h

## Volume de terrassement d'un canal ou d'une digue trapézoïdale (m3)
static func volume_trapeze(b: float, h: float, m: float, longueur: float) -> float:
	return section_trapeze(b, h, m) * longueur

## Débit (m3/s) d'une conduite gravitaire qui consomme toute la charge disponible (m), par dichotomie
static func debit_conduite(d: float, longueur: float, charge_m: float, rugosite: float = 0.00001) -> float:
	var lo := 0.0
	var hi := 2.0
	for i in 60:
		var mid := (lo + hi) / 2.0
		if perte_charge_lineaire(mid, d, longueur, rugosite) < charge_m:
			lo = mid
		else:
			hi = mid
	return (lo + hi) / 2.0
