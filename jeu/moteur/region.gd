class_name Region
extends RefCounted
## Simulation d'une région à aménager, par pas d'une décade (10 jours, 36 par an).
## Aucune dépendance au rendu : testable en ligne de commande.
## Les calculs d'eau et de rendement viennent du moteur des cours (Eau, Hydrologie).
## Tous les paramètres d'équilibrage du jeu sont des VALEURS INDICATIVES.

const DEC_AN := 36
const MOIS := ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]
const NOMS_TYPE := {"ville": "Chef-lieu", "village": "Village", "bas_fond": "Bas-fond", "plaine": "Plaine", "versant": "Versant"}
const NOMS_INCIDENT := {"conflit_foncier": "Conflit foncier", "conflit_eau": "Conflit d'eau", "degradation": "Ouvrages dégradés", "salinisation": "Salinisation des sols"}
const PERCOLATION := {"argileux": 1.0, "limoneux": 2.5, "sableux": 5.0}  # mm/j, indicatif
const CAP_RETENUE := 6.0e6       # m3
const SURF_RETENUE := 1.2e6      # m2
const CAP_PRISE := 2.5           # m3/s
const DEBIT_FORAGES := 0.06      # m3/s
const BV_KM2 := 110.0
const COEF_ECOULEMENT := 0.20
const PROFILS := {
	"ingenieur": {"nom": "Ingénieur du génie rural", "desc": "Ouvrages 15 % moins chers."},
	"agronome": {"nom": "Agronome", "desc": "Rendements +10 %, conseil agricole deux fois plus rapide."},
	"sociologue": {"nom": "Sociologue rural", "desc": "L'adhésion monte plus vite ; une équipe de médiation dès le départ."},
	"economiste": {"nom": "Économiste", "desc": "Budget annuel +15 %, les prix se calment plus vite."},
}

var rng := RandomNumberGenerator.new()
var climat: Dictionary = {}
var culture: Dictionary = {}
var defs: Dictionary = {}       # id -> définition d'initiative
var ordre_defs: Array = []
var ev_defs: Array = []

# ---- état (sauvegardé) ----
var graine := 1
var id_climat := "san_pedro"
var difficulte := 1
var profil := "ingenieur"
var decade := 0
var annee0 := 2027
var budget := 400.0             # millions de FCFA
var reputation := 70.0
var tension_prix := 0.0         # % de hausse des prix
var risque := 0.0               # risque de détournement 0..100
var detournement := 0.0         # 0..100
var zones: Array = []
var achetes: Dictionary = {}    # id -> {"p": progression globale, "z": {indice zone: progression}}
var equipes: Array = []         # {"type", "zone", "dest", "reste"}
var journal: Array = []
var evenement: Dictionary = {}
var ev_vus: Array = []
var prochain_ev := 9
var fin := ""
var contour := PackedVector2Array()
var riviere := PackedVector2Array()
var retenue := 0.0
var apport_prec := 0.0
var facteur_pluie := 1.0
var crue_T := 1.0
var crue_dec := -1
var evac_T := 10.0              # période de retour de la crue que supporte le barrage
var barrage_fragile := false
var contre_saison := 0.0        # part des surfaces cultivée en saison sèche sans barrage
var part_s2 := 0.0              # part réellement repiquée pour la saison sèche en cours
var tour_eau_prov := 0
var panne_pompe := 0
var semis1 := 9                 # décade de l'année du semis de saison des pluies
var depense_totale := 0.0
var production_t := 0.0
var causes: Dictionary = {}     # compteurs pour le bilan final
var eau: Dictionary = {}        # derniers chiffres de la décade (pour l'affichage)

const _ETAT := ["graine", "id_climat", "difficulte", "profil", "decade", "annee0", "budget", "reputation", "tension_prix",
	"risque", "detournement", "zones", "achetes", "equipes", "journal", "evenement", "ev_vus", "prochain_ev", "fin", "contour",
	"riviere", "retenue", "apport_prec", "facteur_pluie", "crue_T", "crue_dec", "evac_T", "barrage_fragile", "contre_saison",
	"part_s2", "tour_eau_prov", "panne_pompe", "semis1", "depense_totale", "production_t", "causes", "eau"]

# ------------------------------------------------------------------ chargement

static func lire_json(chemin: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(chemin))

func charger_donnees() -> void:
	var c: Dictionary = lire_json("res://donnees/climat.json")
	climat = c[id_climat]
	culture = lire_json("res://donnees/cultures.json")["riz_irrigue"]
	defs.clear()
	ordre_defs.clear()
	for d in lire_json("res://donnees/initiatives.json")["initiatives"]:
		defs[d["id"]] = d
		ordre_defs.append(d["id"])
	ev_defs = lire_json("res://donnees/evenements.json")["evenements"]

func nouvelle(p_graine: int, p_climat: String, p_difficulte: int, p_profil: String) -> void:
	graine = p_graine
	id_climat = p_climat
	difficulte = p_difficulte
	profil = p_profil
	rng.seed = graine
	charger_donnees()
	budget = [520.0, 420.0, 340.0][difficulte]
	reputation = [80.0, 70.0, 62.0][difficulte]
	_generer_carte()
	# semis de saison des pluies : premier mois où la pluie dépasse 100 mm
	var pl: Array = climat["pluie_mm"]
	for m in 12:
		if float(pl[m]) >= 100.0:
			semis1 = m * 3
			break
	_tirer_annee()
	if profil == "sociologue":
		equipes.append({"type": "mediation", "zone": _zone_ville(), "dest": -1, "reste": 0})
	noter("Le projet démarre. Commence par les études et l'information des villages.")

func sauver(chemin: String) -> void:
	var d := {}
	for k in _ETAT:
		d[k] = get(k)
	d["rng"] = rng.state
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	if f:
		f.store_var(d)

func restaurer(chemin: String) -> bool:
	if not FileAccess.file_exists(chemin):
		return false
	var f := FileAccess.open(chemin, FileAccess.READ)
	var d: Variant = f.get_var()
	if typeof(d) != TYPE_DICTIONARY or not d.has("zones"):
		return false
	for k in _ETAT:
		if d.has(k):
			set(k, d[k])
	charger_donnees()
	rng.seed = graine
	rng.state = d.get("rng", rng.state)
	return true

# ------------------------------------------------------------------ carte

func _generer_carte() -> void:
	var centre := Vector2(500, 300)
	contour = PackedVector2Array()
	var n := 30
	var dephasage := rng.randf() * TAU
	for i in n:
		var a := TAU * i / n
		var r := 1.0 + 0.10 * sin(3.0 * a + dephasage) + 0.06 * sin(5.0 * a + 2.0 * dephasage) + rng.randf_range(-0.03, 0.03)
		contour.append(centre + Vector2(cos(a) * 430.0, sin(a) * 255.0) * r)
	# rivière du nord (amont) au sud (aval)
	riviere = PackedVector2Array()
	var x := 500.0 + rng.randf_range(-120, 120)
	for k in 9:
		var y := 20.0 + 70.0 * k
		riviere.append(Vector2(x, y))
		x = clamp(x + rng.randf_range(-70, 70), 300.0, 700.0)
	# germes des zones : meilleur candidat parmi plusieurs tirages
	var germes: Array = []
	while germes.size() < 11:
		var meilleur := Vector2.ZERO
		var dmax := -1.0
		for essai in 40:
			var p := Vector2(rng.randf_range(90, 910), rng.randf_range(60, 540))
			if not Geometry2D.is_point_in_polygon(p, contour):
				continue
			var dmin := 1e9
			for g in germes:
				dmin = min(dmin, p.distance_to(g))
			if dmin > dmax:
				dmax = dmin
				meilleur = p
		germes.append(meilleur)
	zones.clear()
	for i in germes.size():
		var cell := PackedVector2Array([Vector2(-50, -50), Vector2(1050, -50), Vector2(1050, 650), Vector2(-50, 650)])
		for j in germes.size():
			if j != i:
				cell = _demi_plan(cell, germes[i], germes[j])
		var morceaux := Geometry2D.intersect_polygons(cell, contour)
		var poly := cell
		var amax := 0.0
		for m in morceaux:
			var a := _aire(m)
			if a > amax:
				amax = a
				poly = m
		zones.append({"id": i, "centre": _centroide(poly), "poly": poly, "voisins": [], "dist_riv": _dist_riviere(germes[i]),
			"adhesion": rng.randf_range(22, 34), "etat": 100.0, "eau": 0.0, "sat": 1.0, "incident": {}, "stabilisee": false,
			"compteur": 0, "etr": 0.0, "etm": 0.0, "etr_p": 0.0, "etm_p": 0.0, "rdt": 0.0, "sel": 0.0, "en_culture": false})
	# voisinages : deux germes sont voisins si un point de la carte les a comme deux plus proches à égalité
	for gx in range(0, 1000, 12):
		for gy in range(0, 600, 12):
			var p := Vector2(gx, gy)
			if not Geometry2D.is_point_in_polygon(p, contour):
				continue
			var a1 := -1
			var a2 := -1
			var d1 := 1e9
			var d2 := 1e9
			for i in germes.size():
				var d: float = p.distance_to(germes[i])
				if d < d1:
					d2 = d1; a2 = a1; d1 = d; a1 = i
				elif d < d2:
					d2 = d; a2 = i
			if a2 >= 0 and d2 - d1 < 14.0:
				if not zones[a1]["voisins"].has(a2):
					zones[a1]["voisins"].append(a2)
					zones[a2]["voisins"].append(a1)
	# types selon la distance à la rivière
	var idx: Array = range(zones.size())
	idx.sort_custom(func(a, b): return zones[a]["centre"].distance_to(centre) < zones[b]["centre"].distance_to(centre))
	var ville: int = idx[0]
	idx.erase(ville)
	idx.sort_custom(func(a, b): return zones[a]["dist_riv"] < zones[b]["dist_riv"])
	var types := {}
	types[ville] = "ville"
	for k in idx.size():
		var t := "plaine"
		if k < 4:
			t = "bas_fond"
		elif k >= idx.size() - 2:
			t = "versant"
		elif k == 5 or k == 7:
			t = "village"
		types[idx[k]] = t
	var sols := ["argileux", "argileux", "limoneux", "limoneux", "sableux"]
	var compte := {}
	for z in zones:
		var t: String = types[z["id"]]
		z["type"] = t
		z["riveraine"] = z["dist_riv"] < 95.0
		match t:
			"bas_fond":
				z["surface"] = float(rng.randi_range(18, 30) * 10); z["sol"] = sols[rng.randi_range(0, 2)]
			"plaine":
				z["surface"] = float(rng.randi_range(30, 50) * 10); z["sol"] = sols[rng.randi_range(1, 4)]
			"versant":
				z["surface"] = float(rng.randi_range(8, 14) * 10); z["sol"] = sols[rng.randi_range(2, 4)]
			"village":
				z["surface"] = float(rng.randi_range(6, 10) * 10); z["sol"] = sols[rng.randi_range(1, 3)]
			_:
				z["surface"] = 60.0; z["sol"] = "limoneux"
		z["pop"] = int(z["surface"] * rng.randf_range(4, 7)) + (9000 if t == "ville" else (1800 if t == "village" else 0))
		var c: Vector2 = z["centre"]
		var dir := ""
		if c.y < 230: dir = "Nord"
		elif c.y > 370: dir = "Sud"
		if c.x < 400: dir += ("-" if dir != "" else "") + "Ouest"
		elif c.x > 600: dir += ("-" if dir != "" else "") + "Est"
		if dir == "": dir = "Centre"
		var nom: String = NOMS_TYPE[t] + " " + dir
		compte[nom] = int(compte.get(nom, 0)) + 1
		if compte[nom] > 1:
			nom += " %d" % compte[nom]
		z["nom"] = nom
	# rang d'éloignement du chef-lieu (ordre de déploiement) et rang amont → aval
	var rang := {ville: 0}
	var file := [ville]
	while not file.is_empty():
		var a: int = file.pop_front()
		for b in zones[a]["voisins"]:
			if not rang.has(b):
				rang[b] = rang[a] + 1
				file.append(b)
	for z in zones:
		z["rang"] = int(rang.get(z["id"], 5))
		z["amont"] = z["centre"].y

func _demi_plan(poly: PackedVector2Array, a: Vector2, b: Vector2) -> PackedVector2Array:
	# garde la partie du polygone plus proche de a que de b
	var m := (a + b) * 0.5
	var nrm := (b - a).normalized()
	var res := PackedVector2Array()
	var nb := poly.size()
	for i in nb:
		var p := poly[i]
		var q := poly[(i + 1) % nb]
		var dp := (p - m).dot(nrm)
		var dq := (q - m).dot(nrm)
		if dp <= 0.0:
			res.append(p)
		if (dp < 0.0 and dq > 0.0) or (dp > 0.0 and dq < 0.0):
			res.append(p + (q - p) * (dp / (dp - dq)))
	return res

func _aire(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		var q := p[(i + 1) % p.size()]
		s += p[i].x * q.y - q.x * p[i].y
	return abs(s) * 0.5

func _centroide(p: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for v in p:
		c += v
	return c / max(p.size(), 1)

func _dist_riviere(p: Vector2) -> float:
	var d := 1e9
	for i in riviere.size() - 1:
		d = min(d, p.distance_to(Geometry2D.get_closest_point_to_segment(p, riviere[i], riviere[i + 1])))
	return d

func _zone_ville() -> int:
	for z in zones:
		if z["type"] == "ville":
			return z["id"]
	return 0

# ------------------------------------------------------------------ initiatives

func fait(id: String) -> bool:
	return achetes.has(id) and float(achetes[id]["p"]) >= 1.0

## Niveau de déploiement d'une initiative dans une zone (0..1)
func niv(id: String, zi: int) -> float:
	if not achetes.has(id):
		return 0.0
	if defs[id]["portee"] == "globale":
		return 1.0 if float(achetes[id]["p"]) >= 1.0 else 0.0
	return float(achetes[id]["z"].get(zi, 0.0))

func concerne(id: String, z: Dictionary) -> bool:
	var d: Dictionary = defs[id]
	if not d.has("types"):
		return true
	return d["types"].has(z["type"]) or (d["types"].has("riveraine") and z["riveraine"])

func prix(id: String) -> float:
	var c := float(defs[id]["cout"]) * (1.0 + tension_prix / 100.0)
	if profil == "ingenieur" and defs[id]["onglet"] == "ouvrages":
		c *= 0.85
	return ceil(c)

## "" si achetable, sinon la raison du refus
func blocage(id: String) -> String:
	if achetes.has(id):
		return "Déjà lancé"
	for r in defs[id]["requis"]:
		if not achetes.has(r):
			return "Nécessite : " + str(defs[r]["nom"])
	if id == "o_pompe" and not (achetes.has("o_prise") or achetes.has("o_barrage")):
		return "Nécessite une prise ou un barrage"
	if prix(id) > budget:
		return "Budget insuffisant"
	return ""

func acheter(id: String) -> bool:
	if blocage(id) != "":
		return false
	var c := prix(id)
	budget -= c
	depense_totale += c
	achetes[id] = {"p": 0.0, "z": {}}
	tension_prix += c * 0.09
	risque = min(100.0, risque + c * (0.035 if fait("g_marches") else 0.07))
	if id == "o_barrage":
		evac_T = 100.0 if fait("e_hydro") else 10.0
		if not fait("e_hydro"):
			_cause("barrage_sans_hydro")
		if not fait("e_eie"):
			reputation -= 4.0
			_cause("barrage_sans_eie")
			noter("Barrage lancé sans étude d'impact : le bailleur le reproche au projet.")
	noter("Lancé : %s (%d M FCFA)." % [defs[id]["nom"], int(c)])
	return true

func _cause(c: String) -> void:
	causes[c] = int(causes.get(c, 0)) + 1

func _deployer() -> void:
	var vit := 1.0 - detournement / 160.0
	for id in achetes:
		var d: Dictionary = defs[id]
		var a: Dictionary = achetes[id]
		var duree := float(d["duree"])
		if id == "g_conseil" and profil == "agronome":
			duree *= 0.5
		if d["portee"] == "globale":
			if float(a["p"]) < 1.0:
				a["p"] = min(1.0, float(a["p"]) + vit / duree)
				if float(a["p"]) >= 1.0:
					_termine(id)
			continue
		if float(a["p"]) >= 1.0:
			continue
		# déploiement zone par zone, du chef-lieu vers l'extérieur
		var ordre: Array = []
		for z in zones:
			if concerne(id, z) and float(a["z"].get(z["id"], 0.0)) < 1.0:
				ordre.append(z)
		if ordre.is_empty():
			a["p"] = 1.0
			noter("Terminé partout : %s." % d["nom"])
			continue
		ordre.sort_custom(func(x, y): return x["rang"] * 100 + x["id"] < y["rang"] * 100 + y["id"])
		var fronts := 2
		for k in min(fronts, ordre.size()):
			var z: Dictionary = ordre[k]
			var v: float = vit * (1.0 + 0.6 * niv("o_pistes", z["id"]))
			if not z["incident"].is_empty() and d["onglet"] == "ouvrages":
				v *= 0.4
			a["z"][z["id"]] = min(1.0, float(a["z"].get(z["id"], 0.0)) + v / duree)

func _termine(id: String) -> void:
	noter("Terminé : %s." % defs[id]["nom"])
	match id:
		"o_evac":
			evac_T = 100.0
		"g_mediation":
			equipes.append({"type": "mediation", "zone": _zone_ville(), "dest": -1, "reste": 0})
		"g_brigade":
			equipes.append({"type": "brigade", "zone": _zone_ville(), "dest": -1, "reste": 0})

# ------------------------------------------------------------------ équipes

func envoyer(ei: int, zi: int) -> void:
	var e: Dictionary = equipes[ei]
	if e["zone"] == zi:
		return
	e["dest"] = zi
	e["reste"] = 1 + int(zones[e["zone"]]["centre"].distance_to(zones[zi]["centre"]) / 350.0)

func equipe_dans(zi: int, type: String) -> bool:
	for e in equipes:
		if e["zone"] == zi and e["dest"] < 0 and e["type"] == type:
			return true
	return false

# ------------------------------------------------------------------ calendrier et climat

func annee() -> int:
	return annee0 + decade / DEC_AN

func mois() -> int:
	return (decade % DEC_AN) / 3

func date_texte() -> String:
	return "%s décade de %s %d" % [["1re", "2e", "3e"][decade % 3], MOIS[mois()], annee()]

func _tirer_annee() -> void:
	facteur_pluie = clamp(rng.randfn(1.0, 0.16 + 0.03 * difficulte), 0.6, 1.4)
	# pluie journalière maximale de l'année, tirée dans une loi de Gumbel (cours d'hydrologie)
	var u := clampf(rng.randf(), 0.001, 0.999)
	crue_T = 1.0 / (1.0 - u)
	var pl: Array = climat["pluie_mm"]
	var mmax := 0
	for m in 12:
		if float(pl[m]) > float(pl[mmax]):
			mmax = m
	crue_dec = (decade / DEC_AN) * DEC_AN + mmax * 3 + rng.randi_range(0, 2)

## Jour de culture (1..120) de la saison en cours, ou 0 hors saison. saison : 1 pluies, 2 sèche.
func jour_culture(saison: int) -> int:
	var d := decade % DEC_AN
	var debut := semis1 if saison == 1 else (semis1 + 18) % DEC_AN
	var k := (d - debut + DEC_AN) % DEC_AN
	return k * 10 + 5 if k < 12 else 0

func saison_seche() -> bool:
	return float(climat["pluie_mm"][mois()]) < 70.0

## Besoin brut de pointe estimé (L/s/ha) : débit fictif continu du mois le plus exigeant
func qfc_pointe() -> float:
	var q := 0.0
	for m in 12:
		var etc := Eau.etc(float(climat["et0_mm_j"][m]), float(culture["kc_mid"]))
		var net := Eau.besoin_net(etc, Eau.pluie_efficace_mensuelle(float(climat["pluie_mm"][m])) / 30.0) + 2.0
		q = max(q, Eau.debit_fictif_continu(Eau.besoin_brut(net, 0.5)))
	return q

func efficience(z: Dictionary) -> float:
	var zi: int = z["id"]
	var e := 0.45 + 0.15 * niv("o_revet", zi) + 0.08 * niv("g_form", zi) + 0.07 * niv("g_aue", zi)
	if not fait("e_topo"):
		e *= 0.85
	if z["sol"] == "sableux" and niv("o_revet", zi) < 0.5:
		e -= 0.08
	return clamp(e, 0.25, 0.8)

func acces_gravitaire(z: Dictionary) -> bool:
	if fait("o_barrage") and (z["type"] == "bas_fond" or z["type"] == "plaine"):
		return true
	if fait("o_prise") and (z["type"] == "bas_fond" or (z["type"] == "plaine" and z["riveraine"])):
		return true
	return false

func _mode_eau(z: Dictionary) -> String:
	if acces_gravitaire(z): return "gravitaire"
	if fait("o_pompe") and (fait("o_prise") or fait("o_barrage")): return "pompe"
	if fait("o_forages"): return "forage"
	return "aucun"

## Besoin brut d'une campagne de saison sèche (m3/ha) et ressource attendue (m3), d'après les normales.
func bilan_previsionnel() -> Dictionary:
	var debut := (semis1 + 18) % DEC_AN
	var besoin_ha := 0.0
	var apports := 0.0
	for k in 12:
		var m := ((debut + k) % DEC_AN) / 3
		var pl := float(climat["pluie_mm"][m]) / 3.0
		var etc := Eau.etc(float(climat["et0_mm_j"][m]), Eau.kc_du_jour(k * 10 + 5, culture["durees_stades"], culture["kc_ini"], culture["kc_mid"], culture["kc_fin"])) * 10.0
		var net := Eau.besoin_net(etc + 25.0, Eau.pluie_efficace_mensuelle(pl * 3.0) / 3.0)
		besoin_ha += Eau.mm_vers_m3(Eau.besoin_brut(net, 0.55), 1.0)
		var ap := COEF_ECOULEMENT * pl / 1000.0 * BV_KM2 * 1.0e6
		apports += ap if fait("o_barrage") else min(ap * 0.7, CAP_PRISE * 864000.0)
	var ressource := 0.0
	if fait("o_barrage"): ressource = retenue + apports * 0.8
	elif fait("o_prise"): ressource = apports
	if fait("o_forages"): ressource += DEBIT_FORAGES * 864000.0 * 12.0
	var surface := 0.0
	for z in zones:
		if _mode_eau(z) != "aucun":
			surface += surface_equipee(z)
	return {"besoin_ha": besoin_ha, "ressource": ressource, "surface": surface,
		"irrigable": ressource / besoin_ha if besoin_ha > 0.0 else 0.0}

func _planifier_saison_seche() -> void:
	var b := bilan_previsionnel()
	if b["surface"] <= 0.0:
		part_s2 = 0.0
		return
	var conseille: float = clamp(0.85 * b["irrigable"] / b["surface"], 0.0, 1.0)
	if fait("e_clim") and fait("e_hydro"):
		# le projet sait calculer la surface irrigable : il cale le plan de campagne dessus
		part_s2 = conseille
		noter("Saison sèche : %d ha repiqués sur %d équipés, d'après le bilan ressource-besoins." % [int(conseille * b["surface"]), int(b["surface"])])
	else:
		part_s2 = 1.0 if fait("o_barrage") else contre_saison
		if part_s2 > conseille + 0.15:
			_cause("surface_surestimee")
			noter("Saison sèche : les producteurs repiquent %d %% des surfaces sans que personne ait calculé si l'eau suffira." % int(part_s2 * 100.0))

func surface_equipee(z: Dictionary) -> float:
	return float(z["surface"]) * niv("o_canaux", z["id"]) * clamp(float(z["etat"]) / 100.0, 0.0, 1.0)

# ------------------------------------------------------------------ une décade

func avancer() -> void:
	if fin != "" or not evenement.is_empty():
		return
	decade += 1
	if decade % DEC_AN == 0:
		_tirer_annee()
		noter("Nouvelle année : le bailleur fixe la tranche annuelle à %d M FCFA." % int(tranche_annuelle()))
	budget += tranche_annuelle() / DEC_AN
	_deployer()
	for e in equipes:
		if e["dest"] >= 0:
			e["reste"] -= 1
			if e["reste"] <= 0:
				e["zone"] = e["dest"]
				e["dest"] = -1
	_eau_et_cultures()
	_zones_et_incidents()
	if decade == crue_dec:
		_crue()
	_finances_et_confiance()
	if tour_eau_prov > 0: tour_eau_prov -= 1
	if panne_pompe > 0: panne_pompe -= 1
	_evenements()
	_verifier_fin()

func tranche_annuelle() -> float:
	var t: float = [300.0, 250.0, 210.0][difficulte] * (0.55 + reputation / 150.0)
	if profil == "economiste":
		t *= 1.15
	return t

func _eau_et_cultures() -> void:
	var m := mois()
	var pluie := float(climat["pluie_mm"][m]) / 3.0 * facteur_pluie * rng.randf_range(0.65, 1.35)
	var et0 := float(climat["et0_mm_j"][m]) * 10.0
	var peff := Eau.pluie_efficace_mensuelle(pluie * 3.0) / 3.0
	# ressource : écoulement de la décade (coefficient d'écoulement x pluie x bassin versant), lissé
	var apport_brut := COEF_ECOULEMENT * pluie / 1000.0 * BV_KM2 * 1.0e6
	var apport := 0.45 * apport_brut + 0.55 * apport_prec
	apport_prec = apport
	var sec := 864000.0
	if jour_culture(2) == 5:
		_planifier_saison_seche()
	# demandes
	var equitable := tour_eau_prov > 0
	var dem: Array = []
	var total_grav := 0.0
	var total_pompe := 0.0
	var total_forage := 0.0
	for z in zones:
		var zi: int = z["id"]
		var s := surface_equipee(z)
		var j1 := jour_culture(1)
		var j2 := jour_culture(2)
		var part := 1.0
		var j := j1
		if j1 == 0 and j2 > 0:
			j = j2
			part = part_s2 if _mode_eau(z) != "aucun" else 0.0
		z["en_culture"] = j > 0
		var besoin := 0.0
		var etc := 0.0
		if j > 0 and s * part > 0.0:
			etc = Eau.etc(et0 / 10.0, Eau.kc_du_jour(j, culture["durees_stades"], culture["kc_ini"], culture["kc_mid"], culture["kc_fin"])) * 10.0
			var net := Eau.besoin_net(etc + float(PERCOLATION[z["sol"]]) * 10.0, peff)
			besoin = Eau.mm_vers_m3(Eau.besoin_brut(net, efficience(z)), s * part)
		var mode := _mode_eau(z) if besoin > 0.0 else "aucun"
		dem.append({"z": z, "besoin": besoin, "mode": mode, "etc": etc, "part": part, "j": j, "s": s, "recu": 0.0})
		match mode:
			"gravitaire": total_grav += besoin
			"pompe": total_pompe += besoin
			"forage": total_forage += besoin
		if niv("g_aue", zi) < 0.5 and mode != "aucun":
			pass
	var nb_aue := 0
	for z in zones:
		if niv("g_aue", z["id"]) >= 0.5:
			nb_aue += 1
	if nb_aue * 2 >= zones.size():
		equitable = true
	# offre
	var dispo_forage := (DEBIT_FORAGES * sec) if fait("o_forages") else 0.0
	var demande_surface := total_grav + total_pompe
	var manque_f: float = max(total_forage - dispo_forage, 0.0)
	var reste_forage: float = max(dispo_forage - total_forage, 0.0)
	var dispo_surface := 0.0
	var deverse := 0.0
	if fait("o_barrage"):
		var b := Hydrologie.bilan_retenue(retenue, CAP_RETENUE, apport, et0, SURF_RETENUE * clamp(retenue / CAP_RETENUE, 0.2, 1.0), max(demande_surface - reste_forage, 0.0))
		retenue = b[0]
		deverse = b[1]
		dispo_surface = max(demande_surface - reste_forage, 0.0) - float(b[2])
	elif fait("o_prise"):
		dispo_surface = min(apport * 0.7, CAP_PRISE * sec)
	dispo_surface += reste_forage
	var cap_pompe := 1.2 * sec * (0.5 if panne_pompe > 0 else 1.0)
	# répartition de l'eau de surface : équitable (tour d'eau) ou l'amont d'abord
	var servis: Array = dem.filter(func(d): return d["mode"] == "gravitaire" or d["mode"] == "pompe")
	var pompe_utilisee := 0.0
	if equitable:
		var ratio: float = min(1.0, dispo_surface / demande_surface) if demande_surface > 0.0 else 1.0
		for d in servis:
			d["recu"] = d["besoin"] * ratio
	else:
		servis.sort_custom(func(a, b): return a["z"]["amont"] < b["z"]["amont"])
		var r := dispo_surface
		for d in servis:
			d["recu"] = min(d["besoin"], r)
			r -= d["recu"]
	for d in servis:
		if d["mode"] == "pompe":
			var possible: float = max(cap_pompe - pompe_utilisee, 0.0)
			d["recu"] = min(d["recu"], possible)
			pompe_utilisee += d["recu"]
	for d in dem:
		if d["mode"] == "forage":
			d["recu"] = d["besoin"] * (1.0 - manque_f / total_forage if total_forage > 0.0 else 1.0)
	# coût de pompage (FCFA/m3 indicatif : 25 au gasoil, 3 en solaire)
	budget -= pompe_utilisee * (3.0 if fait("o_solaire") else 25.0) / 1.0e6
	# cultures : ETR/ETM cumulés, rendement FAO-33 à la récolte
	var total_besoin := 0.0
	var total_recu := 0.0
	for d in dem:
		var z: Dictionary = d["z"]
		total_besoin += d["besoin"]
		total_recu += d["recu"]
		if d["j"] > 0:
			if d["s"] * d["part"] > 0.0:
				var sat: float = 1.0
				if d["besoin"] > 0.0:
					sat = clamp(d["recu"] / d["besoin"], 0.0, 1.0)
				# la pluie efficace couvre déjà une partie de l'ETc
				var couvert: float = min(1.0, (peff + sat * max(d["etc"] - peff, 0.0)) / d["etc"]) if d["etc"] > 0.0 else 1.0
				z["sat"] = sat
				z["eau"] = lerp(float(z["eau"]), couvert, 0.3)
				z["etm"] += d["etc"]
				z["etr"] += d["etc"] * couvert
			# partie non équipée : riz pluvial, en saison des pluies seulement
			if jour_culture(1) > 0:
				var etc_p := et0 * 1.05
				z["etm_p"] += etc_p
				z["etr_p"] += min(etc_p, peff + 8.0)
			if d["j"] >= 115:
				_recolte(z, d["s"] * d["part"])
	eau = {"pluie": pluie, "apport": apport, "besoin": total_besoin, "recu": total_recu, "retenue": retenue, "deverse": deverse,
		"dispo": dispo_surface + dispo_forage - reste_forage, "pompe": pompe_utilisee}

func _recolte(z: Dictionary, s_irr: float) -> void:
	var zi: int = z["id"]
	var ky := float(culture["ky"])
	var prix_kg := float(culture["prix_fcfa_kg"]) * (1.0 + 0.1 * niv("o_magasin", zi) + (0.1 if fait("g_marche") else 0.0) + 0.05 * niv("o_pistes", zi))
	var prod := 0.0
	if s_irr > 0.0 and z["etm"] > 0.0:
		var rel := Eau.rendement_relatif(z["etr"], z["etm"], ky)
		var pot := 0.5 + 0.28 * niv("o_casiers", zi) * (1.0 if fait("e_topo") else 0.7) + 0.22 * niv("g_conseil", zi)
		pot *= 1.0 - 0.5 * float(z["sel"]) / 100.0
		if profil == "agronome":
			pot *= 1.1
		z["rdt"] = float(culture["rendement_max_t_ha"]) * pot * rel
		prod += z["rdt"] * s_irr
		# la récolte décide de l'humeur de la zone
		if rel < 0.55:
			z["adhesion"] -= 5.0
			reputation -= 0.4
			_cause("mauvaise_recolte")
			noter("%s : récolte très faible (%.1f t/ha), l'eau a manqué." % [z["nom"], z["rdt"]])
		elif z["rdt"] >= 3.5:
			z["adhesion"] += 3.0
		if fait("g_redevance"):
			var taux: float = clamp(float(z["adhesion"]) / 100.0 + 0.2 * niv("g_aue", zi), 0.1, 1.0)
			budget += s_irr * 25000.0 * taux / 1.0e6
			if niv("g_aue", zi) < 0.5:
				z["adhesion"] -= 2.0
	if jour_culture(1) > 0 and z["etm_p"] > 0.0:
		var relp := Eau.rendement_relatif(z["etr_p"], z["etm_p"], ky)
		prod += 1.5 * relp * (float(z["surface"]) - s_irr)
	production_t += prod
	z["revenu"] = prod * 1000.0 * prix_kg / 1.0e6
	z["etr"] = 0.0; z["etm"] = 0.0; z["etr_p"] = 0.0; z["etm_p"] = 0.0

func score(z: Dictionary) -> Dictionary:
	var zi: int = z["id"]
	var reseau: float = 100.0 * (0.5 * niv("o_canaux", zi) + 0.2 * niv("o_revet", zi) + 0.3 * niv("o_casiers", zi)) * clamp(float(z["etat"]) / 100.0, 0.0, 1.0)
	var foncier: float = 100.0 * (0.2 * niv("g_info", zi) + (0.2 if fait("e_foncier") else 0.0) + 0.6 * niv("g_foncier", zi))
	var appui: float = 100.0 * (0.25 * niv("g_coop", zi) + 0.2 * niv("g_form", zi) + 0.25 * niv("g_conseil", zi) + 0.1 * niv("o_magasin", zi) + (0.05 if fait("g_marche") else 0.0) + 0.15 * niv("o_pistes", zi))
	var e: float = 100.0 * float(z["eau"]) * min(1.0, reseau / 50.0)
	return {"eau": e, "reseau": reseau, "foncier": foncier, "appui": appui}

func _zones_et_incidents() -> void:
	var entretien_base := 0.30
	for z in zones:
		var zi: int = z["id"]
		var sc := score(z)
		var indice: float = 0.3 * sc["eau"] + 0.25 * sc["reseau"] + 0.2 * sc["foncier"] + 0.25 * sc["appui"]
		var cible := 14.0 + 0.9 * indice - 0.3 * detournement
		if fait("e_socio"): cible += 4.0
		if profil == "sociologue": cible += 4.0
		var inc: Dictionary = z["incident"]
		if not inc.is_empty():
			cible -= 0.35 * float(inc["gravite"])
		var vit := 0.07 * (1.0 if fait("e_socio") else 0.8) * (1.25 if profil == "sociologue" else 1.0)
		z["adhesion"] = clamp(float(z["adhesion"]) + (cible - float(z["adhesion"])) * vit, 0.0, 100.0)
		# usure des ouvrages
		if niv("o_canaux", zi) > 0.0:
			z["etat"] = max(20.0, float(z["etat"]) - entretien_base * (1.0 - 0.67 * niv("g_entretien", zi)))
			if equipe_dans(zi, "brigade"):
				z["etat"] = min(100.0, float(z["etat"]) + 3.0)
		# sel : eau non analysée + pas de drainage
		if not fait("e_eau") and niv("o_canaux", zi) > 0.5 and z["en_culture"] and annee() - annee0 >= 2:
			z["sel"] = min(100.0, float(z["sel"]) + 0.5 * (1.0 - 0.7 * niv("o_drain", zi)))
		# incident en cours
		if not inc.is_empty():
			var t: String = inc["type"]
			var bon := "mediation" if t.begins_with("conflit") else "brigade"
			var delta := 2.5 + 0.7 * difficulte
			if equipe_dans(zi, bon): delta = -9.0
			elif equipe_dans(zi, "mediation") or equipe_dans(zi, "brigade"): delta = -2.0
			if t == "conflit_foncier" and niv("g_foncier", zi) >= 1.0: delta -= 3.0
			if t == "conflit_eau" and niv("g_aue", zi) >= 1.0: delta -= 3.0
			if t == "degradation" and float(z["etat"]) >= 85.0: delta -= 4.0
			inc["gravite"] = float(inc["gravite"]) + delta
			if t == "degradation": z["etat"] = max(20.0, float(z["etat"]) - 0.6)
			if float(inc["gravite"]) <= 0.0:
				noter("%s : %s réglé." % [z["nom"], str(NOMS_INCIDENT[t]).to_lower()])
				reputation += 0.5
				z["incident"] = {}
			elif float(inc["gravite"]) >= 100.0:
				noter("%s : la situation a dégénéré, des parcelles sont abandonnées." % z["nom"])
				_cause("zone_abandonnee")
				reputation -= 5.0
				z["adhesion"] = max(0.0, float(z["adhesion"]) - 20.0)
				z["etat"] = max(20.0, float(z["etat"]) - 25.0)
				inc["gravite"] = 55.0
			elif float(inc["gravite"]) >= 60.0 and t.begins_with("conflit") and rng.randf() < 0.07:
				var v: Array = z["voisins"]
				var cible_z: Dictionary = zones[v[rng.randi_range(0, v.size() - 1)]]
				if cible_z["incident"].is_empty() and float(cible_z["adhesion"]) < 70.0:
					_incident(cible_z, t, 20.0, "Le conflit s'étend depuis %s." % z["nom"])
		else:
			var equipe := niv("o_canaux", zi)
			if equipe > 0.0 and sc["foncier"] < 50.0 and rng.randf() < 0.03 * (1.0 - sc["foncier"] / 100.0) * (1.0 if fait("e_foncier") else 1.6):
				_incident(z, "conflit_foncier", 20.0, "Les travaux touchent des terres dont les droits n'ont pas été clarifiés.")
				_cause("conflit_foncier")
			elif equipe > 0.3 and z["en_culture"] and float(z["sat"]) < 0.6 and rng.randf() < 0.06 * (1.0 - 0.7 * niv("g_aue", zi)):
				_incident(z, "conflit_eau", 20.0, "L'eau n'arrive plus : l'aval accuse l'amont.")
				_cause("conflit_eau")
			elif equipe > 0.3 and float(z["etat"]) < 62.0 and rng.randf() < 0.04:
				_incident(z, "degradation", 25.0, "Canaux ensablés et brèches : faute d'entretien, le réseau ne tient plus.")
				_cause("degradation")
			elif float(z["sel"]) > 40.0 and rng.randf() < 0.04:
				_incident(z, "salinisation", 30.0, "Des croûtes blanches apparaissent : l'eau d'irrigation n'a jamais été analysée (SAR, conductivité).")
				_cause("salinisation")
		if not z["incident"].is_empty() and z["incident"]["type"] == "salinisation" and equipe_dans(zi, "brigade"):
			z["sel"] = max(0.0, float(z["sel"]) - 6.0)
		# mise en valeur
		var ok: bool = float(z["adhesion"]) >= 68.0 and sc["reseau"] >= 70.0 and sc["foncier"] >= 60.0 and z["incident"].is_empty() and _mode_eau(z) != "aucun" and float(z["eau"]) >= 0.6
		if not z["stabilisee"]:
			z["compteur"] = int(z["compteur"]) + 1 if ok else 0
			if int(z["compteur"]) >= 5:
				z["stabilisee"] = true
				reputation = min(100.0, reputation + 2.5)
				noter("%s est mise en valeur." % z["nom"])
		elif float(z["adhesion"]) < 45.0:
			z["stabilisee"] = false
			z["compteur"] = 0
			reputation -= 3.0
			noter("%s n'est plus considérée comme mise en valeur." % z["nom"])

func _incident(z: Dictionary, type: String, gravite: float, pourquoi: String) -> void:
	z["incident"] = {"type": type, "gravite": gravite}
	noter("Alerte — %s : %s %s" % [z["nom"], str(NOMS_INCIDENT[type]).to_lower() + ".", pourquoi])

func _crue() -> void:
	if crue_T < 4.0:
		return
	var p := Hydrologie.gumbel_quantile(float(climat["pluie_max_jour_moy"]), float(climat["pluie_max_jour_ect"]), max(crue_T, 1.01))
	noter("Crue : %d mm en un jour, période de retour d'environ %d ans (ajustement de Gumbel)." % [int(p), int(round(crue_T))])
	var digue_T := 50.0 if fait("e_hydro") else 10.0
	var touchees := 0
	for z in zones:
		if not (z["type"] == "bas_fond" or z["riveraine"]):
			continue
		var protege: bool = niv("o_digue", z["id"]) >= 1.0 and crue_T <= digue_T
		if protege:
			continue
		var degat := 22.0 * (1.0 - 0.5 * niv("o_drain", z["id"]))
		if niv("o_canaux", z["id"]) > 0.0:
			z["etat"] = max(20.0, float(z["etat"]) - degat)
			z["etr"] = float(z["etr"]) * 0.75
		z["adhesion"] = max(0.0, float(z["adhesion"]) - 4.0)
		touchees += 1
	if touchees > 0:
		_cause("crue_degats")
		noter("%d zones basses inondées. Digues et drainage limitent ces dégâts." % touchees)
	if fait("o_barrage") and (crue_T > evac_T or (barrage_fragile and crue_T > 8.0)):
		retenue = 0.0
		achetes["o_barrage"]["p"] = 0.5
		reputation -= 12.0
		_cause("barrage_rupture")
		var r := Hydrologie.risque_sur_n_ans(evac_T, 10) * 100.0
		noter("L'évacuateur du barrage est submergé : brèche dans la digue, retenue vidée, 9 décades de réparation. Dimensionné pour une crue de %d ans, il avait %d %% de risque d'être dépassé en 10 ans." % [int(evac_T), int(r)])
		for z in zones:
			if z["type"] == "bas_fond":
				z["etat"] = max(20.0, float(z["etat"]) - 20.0)
				z["adhesion"] = max(0.0, float(z["adhesion"]) - 8.0)

func _finances_et_confiance() -> void:
	tension_prix *= 0.90 if profil == "economiste" else 0.93
	risque = max(0.0, risque - 0.25)
	detournement += (risque - detournement) * 0.04
	if fait("g_audit"):
		detournement = max(0.0, detournement - 0.8)
		risque = max(0.0, risque - 0.5)
	var n := float(zones.size())
	var stab := 0.0
	var crises := 0.0
	for z in zones:
		if z["stabilisee"]: stab += 1.0
		if not z["incident"].is_empty(): crises += float(z["incident"]["gravite"]) / 100.0
	var ans := float(decade) / DEC_AN
	var perte := (0.10 + 0.045 * ans + 0.03 * difficulte) * (1.0 - stab / n)
	perte += 0.10 * crises
	perte += pow(detournement / 100.0, 2.0) * 0.9
	if budget < 0.0:
		perte += 0.3
	reputation = clamp(reputation - perte, 0.0, 100.0)

func nb_stabilisees() -> int:
	var k := 0
	for z in zones:
		if z["stabilisee"]: k += 1
	return k

func _verifier_fin() -> void:
	if reputation <= 0.0:
		fin = "defaite"
		noter("Le bailleur retire sa confiance : le projet est clôturé.")
	elif nb_stabilisees() == zones.size():
		fin = "victoire"
		noter("Toutes les zones sont mises en valeur. Le projet est une réussite.")

# ------------------------------------------------------------------ événements à choix

func _evenements() -> void:
	if fin != "" or decade < prochain_ev:
		return
	prochain_ev = decade + rng.randi_range(9, 15)
	var possibles: Array = []
	for e in ev_defs:
		if ev_vus.has(e["id"]):
			continue
		var si: Dictionary = e["si"]
		var ok := true
		for id in si.get("fait", []):
			if not achetes.has(id): ok = false
		for id in si.get("non_fait", []):
			if achetes.has(id): ok = false
		if si.has("en_cours") and not (achetes.has(si["en_cours"]) and float(achetes[si["en_cours"]]["p"]) < 1.0): ok = false
		if si.has("annee_min") and decade < int(si["annee_min"]) * DEC_AN: ok = false
		if si.has("saison_seche") and not saison_seche(): ok = false
		if ok:
			possibles.append(e)
	if possibles.is_empty():
		return
	evenement = possibles[rng.randi_range(0, possibles.size() - 1)]
	ev_vus.append(evenement["id"])

## Applique le choix i de l'événement en cours et renvoie le texte de la suite.
func repondre(i: int) -> String:
	if evenement.is_empty():
		return ""
	var ch: Dictionary = evenement["choix"][i]
	var ef: Dictionary = ch["effets"]
	budget += float(ef.get("budget", 0.0))
	reputation = clamp(reputation + float(ef.get("reputation", 0.0)), 0.0, 100.0)
	tension_prix = max(0.0, tension_prix + float(ef.get("tension", 0.0)))
	risque = clamp(risque + float(ef.get("risque", 0.0)), 0.0, 100.0)
	if ef.has("adhesion"):
		for z in zones:
			z["adhesion"] = clamp(float(z["adhesion"]) + float(ef["adhesion"]), 0.0, 100.0)
	if ef.has("reputation_si_stab"):
		reputation = clamp(reputation + (float(ef["reputation_si_stab"]) if nb_stabilisees() > 0 else -3.0), 0.0, 100.0)
	if ef.has("incident"):
		var cand: Array = zones.filter(func(z): return z["incident"].is_empty() and not z["stabilisee"])
		if not cand.is_empty():
			cand.sort_custom(func(a, b): return a["adhesion"] < b["adhesion"])
			_incident(cand[0], ef["incident"], 30.0, "")
	if ef.has("defaut"): barrage_fragile = true; _cause("compactage")
	if ef.has("contre_saison"): contre_saison = float(ef["contre_saison"])
	if ef.has("tour_eau"): tour_eau_prov = int(ef["tour_eau"])
	if ef.has("panne_pompe"): panne_pompe = int(ef["panne_pompe"])
	if ef.has("accelere"):
		for k in int(ef["accelere"]): _deployer()
	var suite: String = ch["suite"]
	noter("%s — %s" % [evenement["titre"], suite])
	evenement = {}
	return suite

# ------------------------------------------------------------------ journal et bilan

func noter(t: String) -> void:
	journal.append({"d": decade, "t": t})
	if journal.size() > 200:
		journal.pop_front()

## Leçons de fin de partie : ce qui s'est passé et le cours qui l'explique.
func lecons() -> Array:
	var l: Array = []
	if causes.has("barrage_rupture"):
		l.append("Le barrage a cédé lors d'une crue. Un évacuateur se dimensionne sur la crue de projet, estimée par l'ajustement de Gumbel sur les pluies maximales. Cours : Hydrologie appliquée ; Stockage des eaux de surface.")
	elif causes.has("barrage_sans_hydro") and not fait("o_evac"):
		l.append("Ton barrage a été construit sans étude hydrologique : son évacuateur ne supporte qu'une crue décennale, soit %d %% de risque de dépassement en 10 ans. Tu as eu de la chance. Cours : Hydrologie appliquée." % int(Hydrologie.risque_sur_n_ans(10.0, 10) * 100.0))
	if causes.has("conflit_foncier"):
		l.append("%d conflits fonciers ont éclaté dans des zones où les droits n'étaient pas clarifiés avant les travaux. Cours : Droit foncier rural." % causes["conflit_foncier"])
	if causes.has("conflit_eau"):
		l.append("%d conflits d'eau entre amont et aval : sans tour d'eau, l'amont se sert d'abord. Cours : Bases techniques et pilotage de projet d'irrigation." % causes["conflit_eau"])
	if causes.has("mauvaise_recolte"):
		l.append("%d récoltes très faibles par manque d'eau. Le rendement chute selon la loi 1 - Ya/Ym = Ky (1 - ETr/ETm). Cours : Bilan hydrique ; Agro-climatologie." % causes["mauvaise_recolte"])
	if causes.has("salinisation"):
		l.append("Des sols se sont salinisés : l'eau n'avait pas été analysée (conductivité, SAR, RSC) et le drainage manquait. Cours : Qualité des eaux d'irrigation.")
	if causes.has("degradation"):
		l.append("Des réseaux se sont dégradés faute d'entretien : un périmètre sans plan d'entretien perd sa surface irrigable année après année. Cours : Bases techniques et pilotage de projet d'irrigation.")
	if causes.has("crue_degats"):
		l.append("Les crues ont inondé des zones basses non protégées. Cours : Hydrologie appliquée (crue de projet, digues).")
	if causes.has("surface_surestimee"):
		l.append("En saison sèche, on a repiqué plus de surface que la ressource ne pouvait en irriguer. Surface irrigable = volume disponible ÷ besoin brut par hectare : il faut l'étude agro-climatique ET l'étude hydrologique pour le calculer. Cours : Bases techniques de l'irrigation ; Bilan hydrique.")
	if not fait("e_topo") and achetes.has("o_canaux"):
		l.append("Canaux tracés sans levé topographique : pentes mal calées, 15 % d'efficience perdue pendant toute la partie. Cours : Topographie.")
	if detournement > 30.0:
		l.append("Les détournements ont atteint %d %% : dépenser vite sans marchés transparents ni audit ruine la confiance. Cours : Gestion de projet ; Civisme." % int(detournement))
	if l.is_empty():
		l.append("Aucune erreur majeure : études avant travaux, foncier clarifié, eau partagée, ouvrages entretenus.")
	return l
