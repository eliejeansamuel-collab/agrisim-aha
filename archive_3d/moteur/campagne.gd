class_name Campagne
extends RefCounted
## Simulation journalière d'une campagne de riz irrigué en casiers (bas-fond).
## Bilan d'eau du casier : P + I = ETr + percolation + drainage + débordement + variation de stock.
## Sources : cours L3 Bilan hydrique (P = E + R + I +/- dS), Bases techniques ch. 3-4,
## FAO-56 et FAO-33 pour Ks et Ky (approfondissement).

# --- Paramètres (fixés par les études et la conception du joueur) ---
var surface_ha := 5.0
var ru_mm := 120.0            # réserve utile de la zone racinaire
var rfu_fraction := 0.5
var percolation_mm_j := 3.0   # pertes par percolation sous lame d'eau (dépend du sol)
var lame_cible_mm := 50.0
var hauteur_diguette_mm := 150.0
var q_canal_m3_s := 0.01      # capacité du canal dimensionné par le joueur
var efficience := 0.6         # transport x application (gravitaire : 0,45 à 0,65 dans le cours)
var q_riviere_m3_s: Array = []  # débit prélevable par mois (12 valeurs)
var drainage_mm_j := 0.0      # capacité du réseau de drainage (0 = pas de drain)
var hauteur_digue_m := 0.0    # digue de protection contre la crue
var facteur_fertilite := 1.0
var culture: Dictionary
var jour_semis := 121         # jour de l'année du repiquage
var crue_jour := -1           # jour de campagne où survient une crue (-1 = aucune)
var crue_hauteur_m := 0.0
var crue_duree := 0
# Retenue (petit barrage) : stocke l'eau du marigot non utilisée et la restitue quand il baisse
var retenue_capacite_m3 := 0.0
var retenue_m3 := 0.0
var retenue_surface_m2 := 0.0

# --- État ---
var jour := 0                 # jour de campagne (1..durée)
var lame_mm := 0.0
var stock_mm := 0.0
var termine := false
var journal: Array = []
var tot := {"pluie": 0.0, "irrigation": 0.0, "etm": 0.0, "etr": 0.0, "percolation": 0.0,
	"drainage": 0.0, "debordement": 0.0, "preleve_m3": 0.0}
var jours_stress := 0
var jours_stress_floraison := 0   # le riz est très sensible au manque d'eau à la floraison
var jours_debordement := 0
var jours_submersion := 0
var stock_initial := 0.0
var meteo: Meteo

func _init(p_culture: Dictionary, p_meteo: Meteo) -> void:
	culture = p_culture
	meteo = p_meteo

func duree() -> int:
	var d := 0
	for x in culture.durees_stades:
		d += int(x)
	return d

func demarrer() -> void:
	stock_mm = ru_mm
	stock_initial = stock_mm
	lame_mm = 0.0
	jour = 0

## Apport maximal possible aujourd'hui à la parcelle (mm), limité par le canal ET par la rivière
func apport_max_mm(jour_annee: int) -> float:
	var v: float = min(q_canal_m3_s * 86400.0, _volume_riviere_jour(jour_annee) + retenue_m3)
	return v * efficience / (surface_ha * 10000.0) * 1000.0

func _volume_riviere_jour(jour_annee: int) -> float:
	if q_riviere_m3_s.size() != 12:
		return 1.0e12
	return q_riviere_m3_s[Meteo.mois_du_jour(jour_annee)] * 86400.0

func jour_suivant() -> Dictionary:
	if termine:
		return {}
	jour += 1
	var ja := jour_semis + jour - 1
	var w := meteo.jour(ja)
	var kc: float = Eau.kc_du_jour(jour, culture.durees_stades, culture.kc_ini, culture.kc_mid, culture.kc_fin)
	var etm: float = Eau.etc(w.et0, kc)
	# On arrête d'irriguer pendant les derniers jours (assec avant récolte)
	var assec: bool = jour > duree() - int(culture.get("jours_assec", 10))
	var irr := 0.0
	if not assec:
		var demande: float = max(0.0, lame_cible_mm - lame_mm + etm + percolation_mm_j - w.pluie + (ru_mm - stock_mm))
		irr = min(demande, apport_max_mm(ja))
	if retenue_capacite_m3 > 0.0:
		var v_riv: float = _volume_riviere_jour(ja)
		var besoin_v: float = Eau.mm_vers_m3(irr, surface_ha) / efficience
		var de_riviere: float = min(besoin_v, v_riv)
		retenue_m3 -= besoin_v - de_riviere
		retenue_m3 += v_riv - de_riviere
		retenue_m3 -= w.et0 / 1000.0 * retenue_surface_m2 * clamp(retenue_m3 / retenue_capacite_m3, 0.0, 1.0)
		retenue_m3 = clamp(retenue_m3, 0.0, retenue_capacite_m3)
	lame_mm += w.pluie + irr
	# Réhumectation du sol
	var inf: float = min(lame_mm, ru_mm - stock_mm)
	lame_mm -= inf
	stock_mm += inf
	# Percolation profonde sous lame d'eau
	var perc: float = min(lame_mm, percolation_mm_j)
	lame_mm -= perc
	# Évapotranspiration
	var ks := 1.0
	if lame_mm <= 0.0:
		ks = Eau.ks_stress(ru_mm - stock_mm, ru_mm, ru_mm * rfu_fraction)
	var etr: float = ks * etm
	var pris: float = min(lame_mm, etr)
	lame_mm -= pris
	var reste: float = min(etr - pris, stock_mm)
	stock_mm -= reste
	etr = pris + reste
	if ks < 0.999 and not assec:
		jours_stress += 1
		var d1: int = int(culture.durees_stades[0]) + int(culture.durees_stades[1])
		if jour > d1 and jour <= d1 + int(culture.durees_stades[2]):
			jours_stress_floraison += 1
	# Drainage puis débordement par-dessus les diguettes
	var seuil: float = hauteur_diguette_mm if not assec else 0.0
	var draine := 0.0
	var deborde := 0.0
	var cible_drain: float = lame_cible_mm * 1.5 if not assec else 0.0
	if lame_mm > cible_drain and drainage_mm_j > 0.0:
		draine = min(lame_mm - cible_drain, drainage_mm_j)
		lame_mm -= draine
	if lame_mm > hauteur_diguette_mm:
		deborde = lame_mm - hauteur_diguette_mm
		lame_mm = hauteur_diguette_mm
		jours_debordement += 1
	# Crue de la rivière
	var submerge := false
	if crue_jour > 0 and jour >= crue_jour and jour < crue_jour + crue_duree and hauteur_digue_m < crue_hauteur_m:
		submerge = true
		jours_submersion += 1
	tot.pluie += w.pluie
	tot.irrigation += irr
	tot.etm += etm
	tot.etr += etr
	tot.percolation += perc
	tot.drainage += draine
	tot.debordement += deborde
	tot.preleve_m3 += Eau.mm_vers_m3(irr, surface_ha) / efficience
	var ligne := {"jour": jour, "pluie": w.pluie, "et0": w.et0, "kc": kc, "etm": etm, "etr": etr,
		"irrigation": irr, "lame": lame_mm, "stock": stock_mm, "ks": ks, "submerge": submerge,
		"deborde": deborde, "assec": assec}
	journal.append(ligne)
	if jour >= duree():
		termine = true
	return ligne

## Écart de fermeture du bilan d'eau (mm) : doit rester ~0
func erreur_bilan() -> float:
	var entrees: float = tot.pluie + tot.irrigation
	var sorties: float = tot.etr + tot.percolation + tot.drainage + tot.debordement
	var delta: float = (lame_mm + stock_mm) - stock_initial
	return entrees - sorties - delta

## Rendement (t/ha) et décomposition des pertes
func resultat() -> Dictionary:
	var rel_eau: float = Eau.rendement_relatif(tot.etr, tot.etm, culture.ky)
	var rel_crue: float = clamp(1.0 - float(culture.get("perte_par_jour_submersion", 0.12)) * jours_submersion, 0.0, 1.0)
	var rel_debord: float = clamp(1.0 - 0.01 * jours_debordement, 0.7, 1.0)
	var rel_floraison: float = clamp(1.0 - float(culture.get("perte_par_jour_stress_floraison", 0.0)) * jours_stress_floraison, 0.3, 1.0)
	var rdt: float = culture.rendement_max_t_ha * rel_eau * rel_floraison * rel_crue * rel_debord * facteur_fertilite
	return {"rendement_t_ha": rdt, "production_t": rdt * surface_ha, "rel_eau": rel_eau,
		"rel_floraison": rel_floraison, "rel_crue": rel_crue, "rel_debordement": rel_debord, "jours_stress": jours_stress,
		"jours_submersion": jours_submersion, "jours_debordement": jours_debordement,
		"productivite_eau_kg_m3": (rdt * surface_ha * 1000.0) / max(tot.preleve_m3, 1.0)}

func simuler_tout() -> Dictionary:
	demarrer()
	while not termine:
		jour_suivant()
	return resultat()
