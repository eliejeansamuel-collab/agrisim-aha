extends Node3D
## Tranche verticale : aménager un bas-fond rizicole de 5 ha près de San-Pédro.
## Foncier -> études -> besoins en eau -> conception -> campagne -> bilan et débriefing.
## Toute la scène est construite par code ; les règles de calcul sont dans res://moteur.

enum Etape { INTRO, FONCIER, ETUDES, BESOINS, CONCEPTION, RECRUTEMENT, TRAVAUX, CAMPAGNE, BILAN }

# Réalité du terrain, inconnue du joueur tant qu'il n'a pas fait les études
var VRAI := {}
# Ce que le joueur « croit » sans étude (estimation à l'œil)
var CROYANCE := {}
# --- Configuration du site (écran « Nouveau projet ») ---
var site := {"mode": "exercice", "ville": "san_pedro", "region": "san_pedro", "topo": "bas_fond", "texture": "argileux", "structure": "polyedrique",
	"profondeur": 50, "pluie_pct": 100.0, "et0_pct": 100.0, "secheresse_j": 15.0, "crues_pct": 100.0}
var climats: Dictionary
var topos: Dictionary
var topo: Dictionary
var decor: Node3D
const KS_TERRE := 30.0
const FRUIT := 1.0
const REVANCHE := 0.15
const EFFICIENCE := 0.6
const L_CANAL := 350.0
const L_DIGUETTES := 2450.0
const L_DIGUE := 250.0
const L_DRAIN := 300.0
const SEMIS := [
	{"nom": "1er mai", "jour": 121},
	{"nom": "1er juillet", "jour": 182},
	{"nom": "1er septembre", "jour": 244},
	{"nom": "1er décembre", "jour": 335},
]
const DEMARCHES := [
	{"id": "coutumier", "nom": "Rencontrer le chef de terre et identifier les détenteurs de droits coutumiers", "cout": "enquete_coutumiere", "jours": 3, "risque": 0.25},
	{"id": "comite", "nom": "Faire constater l'accord par le comité villageois de gestion foncière", "cout": "comite_villageois", "jours": 7, "risque": 0.15},
	{"id": "certificat", "nom": "Vérifier s'il existe un certificat foncier sur la parcelle", "cout": "certificat_foncier", "jours": 5, "risque": 0.10},
	{"id": "bornage", "nom": "Géomètre-expert : délimitation et bornage", "cout": "geometre_bornage", "jours": 10, "risque": 0.10},
	{"id": "notaire", "nom": "Bail écrit devant notaire, enregistré", "cout": "notaire_bail", "jours": 7, "risque": 0.15},
]
const ETUDES := [
	{"id": "topo", "nom": "Étude topographique (levé, nivellement, courbes de niveau)", "cout": "topographie", "jours": 10},
	{"id": "sol", "nom": "Étude pédologique (texture, réserve utile, percolation)", "cout": "pedologie", "jours": 8},
	{"id": "hydro", "nom": "Étude hydrologique (débits du marigot, crues)", "cout": "hydrologie", "jours": 12},
]

var etape: int = Etape.INTRO
var climat: Dictionary
var riz: Dictionary
var sols: Dictionary
var couts: Dictionary
var notions: Array
var rng := RandomNumberGenerator.new()

# --- État de la partie ---
var tresorerie := 0.0
var jours_ecoules := 0
var fait := {}                # démarches et études réalisées
var charges: Array = []       # [libellé, montant, catégorie]
var semis_idx := 0
var q_projet := 0.0           # débit de projet retenu (m3/s)
var quiz_juste := false
var canal_b := 0.3
var canal_h := 0.3
var diguette_h := 0.20
var avec_drain := false
var digue_h := 0.0
var campagne: Campagne
var vitesse := 1.0 / 30.0     # jours simulés par seconde (par défaut : 1 jour = 30 s)
var adduction := "canal"      # canal en terre | conduite pvc
var pvc_dn := 160
var barrage_h := 0.0          # hauteur du petit barrage (0 = aucun)
var source_eau := "gravite"   # gravite | pompe
var pompe_q := 8.0            # L/s
var part_solaire := 0.0       # % de l'énergie de pompage couverte par le solaire
var batterie_kwh := 0.0
var equipe := {"manoeuvres": 12, "macons": 2, "chef": true, "pelle": false, "riziculteurs": 5}
var repas := true
var lots: Array = []
var groupes := {}
var chantier := {"jour": 0, "debut": 0, "fini": false, "salaires": 0.0}
var chantier_meteo: Meteo
var pluie_forte := false
var retard_j := 0
var salaires_campagne := 0.0
var carburant_fcfa := 0.0
var energie_kwh := {"solaire": 0.0, "thermique": 0.0}
var preleve_veille := 0.0
var heures_rizi := 0.0
var budget_illimite := false
const FENETRE_CHANTIER := 75  # jours disponibles entre l'ouverture du chantier et le repiquage prévu
var en_pause := false
var cumul_temps := 0.0
var evenements: Array = []
var litige_jours_restants := 0
var motopompe := false
var notions_vues := {}

# --- Scène ---
var cam: Camera3D
var cam_cible := Vector3(140, 10.7, 0)
var cam_yaw := -0.6
var cam_pitch := 0.75
var cam_dist := 430.0
var touches := {}
var appui_pos := Vector2.ZERO
var appui_bouge := 0.0
var terrain_mi: MeshInstance3D
var terrain_mat: ShaderMaterial
var avatar: Node3D
var amenagement: Node3D
var eau_mm: MultiMeshInstance3D
var riz_mm: MultiMeshInstance3D
var riz_mat: ShaderMaterial
var monde: MondeVivant
var reel: DonneesReelles
var villes: Dictionary
var etat_reseau := ""
var heure_libre := 9.0
var eau_mat: StandardMaterial3D
var nappe_crue: MeshInstance3D
var bornes: Node3D
# --- Interface ---
var hud: Label
var info: Label
var panneau: VBoxContainer
var titre: Label
var popup: PanelContainer
var popup_texte: RichTextLabel
var popup_boutons: HBoxContainer


func _ready() -> void:
	climats = _json("res://donnees/climat.json")
	topos = _json("res://donnees/topographies.json")
	topos.erase("_note")
	villes = _json("res://donnees/villes.json")
	villes.erase("_note")
	reel = DonneesReelles.new()
	add_child(reel)
	reel.termine.connect(_donnees_reelles_recues)
	climat = climats.san_pedro
	topo = topos.bas_fond
	riz = _json("res://donnees/cultures.json").riz_irrigue
	sols = _json("res://donnees/sols.json")
	couts = _json("res://donnees/couts.json")
	notions = JSON.parse_string(FileAccess.get_file_as_string("res://donnees/notions.json"))
	var graine := OS.get_environment("AGRISIM_GRAINE")
	if graine != "":
		rng.seed = int(graine)
	else:
		rng.randomize()
	var cfg := OS.get_environment("AGRISIM_SITE").split(",", false)
	if cfg.size() >= 5:
		site.region = cfg[0]; site.topo = cfg[1]; site.texture = cfg[2]; site.structure = cfg[3]; site.profondeur = int(cfg[4])
	if cfg.size() >= 9:
		site.pluie_pct = float(cfg[5]); site.et0_pct = float(cfg[6]); site.secheresse_j = float(cfg[7]); site.crues_pct = float(cfg[8])
	_creer_monde()
	_creer_interface()
	_nouvelle_partie()
	if not DonneesReelles.lire_cache(site.ville).is_empty():
		reel.telecharger(site.ville, villes[site.ville])
	if OS.get_environment("AGRISIM_AUTO") != "":
		_pilote_auto(OS.get_environment("AGRISIM_AUTO"))


func _json(chemin: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(chemin))


# =====================================================================
#  MONDE 3D
# =====================================================================

func _creer_monde() -> void:
	var env := Environment.new()
	var ciel := Sky.new()
	var mat_ciel := ProceduralSkyMaterial.new()
	mat_ciel.sky_top_color = Color(0.30, 0.55, 0.90)
	mat_ciel.sky_horizon_color = Color(0.80, 0.88, 0.95)
	mat_ciel.ground_horizon_color = Color(0.80, 0.88, 0.95)
	mat_ciel.ground_bottom_color = Color(0.62, 0.74, 0.80)
	ciel.sky_material = mat_ciel
	env.background_mode = Environment.BG_SKY
	env.sky = ciel
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.35
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var soleil := DirectionalLight3D.new()
	soleil.rotation = Vector3(-0.9, 0.7, 0)
	soleil.light_energy = 0.75
	soleil.shadow_enabled = true
	soleil.directional_shadow_max_distance = 900.0
	add_child(soleil)
	monde = MondeVivant.new()
	add_child(monde)
	monde.installer(env, mat_ciel, soleil)
	cam = Camera3D.new()
	cam.far = 3000.0
	cam.fov = 50.0
	add_child(cam)

	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = load("res://scenes/terrain.gdshader")
	terrain_mi = MeshInstance3D.new()
	terrain_mi.material_override = terrain_mat
	add_child(terrain_mi)
	decor = Node3D.new()
	add_child(decor)
	_creer_avatar()

	bornes = Node3D.new()
	add_child(bornes)
	amenagement = Node3D.new()
	add_child(amenagement)
	nappe_crue = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(560, Terrain.TAILLE)
	nappe_crue.mesh = pm
	nappe_crue.material_override = _mat(Color(0.45, 0.36, 0.22, 0.85), true)
	nappe_crue.visible = false
	add_child(nappe_crue)


func _mat(couleur: Color, transparent := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = 0.9
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.15
	return m


func _boite(parent: Node3D, taille: Vector3, pos: Vector3, couleur: Color, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = _mat(couleur)
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi


func _reconstruire_terrain() -> void:
	terrain_mi.mesh = Terrain.creer_maillage()


func _creer_riviere() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := -Terrain.TAILLE / 2.0
	while z < Terrain.TAILLE / 2.0:
		var z2 := z + 8.0
		var a := Vector3(Terrain.x_riviere(z) - 5.0, Terrain.hauteur(Terrain.x_riviere(z), z) + 0.55, z)
		var b := Vector3(Terrain.x_riviere(z) + 5.0, a.y, z)
		var c := Vector3(Terrain.x_riviere(z2) - 5.0, Terrain.hauteur(Terrain.x_riviere(z2), z2) + 0.55, z2)
		var d := Vector3(Terrain.x_riviere(z2) + 5.0, c.y, z2)
		for v in [a, b, c, b, d, c]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
		z = z2
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat(Color(0.20, 0.45, 0.62, 0.9), true)
	decor.add_child(mi)


func _creer_decor() -> void:
	# Arbres des versants (cônes) en MultiMesh
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 5.0
	cone.height = 14.0
	cone.radial_segments = 6
	cone.rings = 1
	mm.mesh = cone
	var positions: Array = []
	var r := RandomNumberGenerator.new()
	r.seed = 11
	var essais := 0
	var n_versant: int = 700 if Terrain.H_VERSANT > 1.0 else 120
	while positions.size() < n_versant and essais < 20000:
		essais += 1
		var x := r.randf_range(-395, 395)
		var z := r.randf_range(-395, 395)
		var loin: bool = abs(x - Terrain.x_riviere(z)) > Terrain.DEMI_FOND + 15.0
		if Terrain.H_VERSANT <= 1.0:
			loin = x > 260.0 or x < -60.0
		if loin and abs(x - Terrain.x_riviere(z)) > 20.0 and Vector2(x + 310.0, z + 25.0).length() > 60.0:
			positions.append(Vector3(x, Terrain.hauteur(x, z) + 6.0, z))
	# Quelques palmiers et arbres isolés dans le bas-fond, hors parcelle
	var cible_n: int = positions.size() + 40
	essais = 0
	while positions.size() < cible_n and essais < 5000:
		essais += 1
		var x2 := r.randf_range(-250, 30)
		var z2 := r.randf_range(-395, 395)
		if abs(x2 - Terrain.x_riviere(z2)) > 20.0:
			positions.append(Vector3(x2, Terrain.hauteur(x2, z2) + 6.0, z2))
	var modeles_arbres: Array = [Modeles.maillage("tree_single_A", 16.0), Modeles.maillage("tree_single_B", 13.0)]
	if modeles_arbres[0].is_empty() or modeles_arbres[1].is_empty():
		mm.instance_count = positions.size()
		for i in positions.size():
			var s := r.randf_range(0.7, 1.4)
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), positions[i]))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _mat(Color(0.10, 0.33, 0.12))
		decor.add_child(mmi)
	else:
		for v in 2:
			var ma: Dictionary = modeles_arbres[v]
			var liste: Array = []
			for i in positions.size():
				if i % 2 == v:
					liste.append(positions[i])
			var mm2 := MultiMesh.new()
			mm2.transform_format = MultiMesh.TRANSFORM_3D
			mm2.mesh = ma.mesh
			mm2.instance_count = liste.size()
			for i in liste.size():
				var s2: float = ma.echelle * r.randf_range(0.75, 1.35)
				var pos: Vector3 = liste[i] - Vector3(0, 6.0, 0)
				pos.y -= ma.base * s2
				mm2.set_instance_transform(i, Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s2, s2, s2)), pos))
			var mmi2 := MultiMeshInstance3D.new()
			mmi2.multimesh = mm2
			decor.add_child(mmi2)
	# Rochers épars
	for i in 14:
		var xr := r.randf_range(-390, 390)
		var zr := r.randf_range(-390, 390)
		if Terrain.PARCELLE.grow(30).has_point(Vector2(xr, zr)) or abs(xr - Terrain.x_riviere(zr)) < 15.0:
			continue
		var roc := Modeles.decor("rock_single_A", r.randf_range(2.5, 5.0))
		if roc != null:
			roc.position = Vector3(xr, Terrain.hauteur(xr, zr) - 0.3, zr)
			roc.rotation.y = r.randf() * TAU
			decor.add_child(roc)
	# Village sur le versant ouest
	var types := ["building_home_A_yellow", "building_home_B_yellow", "building_home_A_yellow", "building_home_B_yellow", "building_home_B_yellow", "building_home_A_yellow", "building_home_A_yellow"]
	for i in 7:
		var x := -335.0 + (i % 3) * 26.0
		var z := -65.0 + (i / 3) * 30.0 + (i % 2) * 6.0
		var y := Terrain.hauteur(x, z)
		var maison := Modeles.decor(types[i], 13.0 if i != 6 else 9.0)
		if maison != null:
			maison.position = Vector3(x, y - 0.4, z)
			maison.rotation.y = r.randf_range(-0.5, 0.5) + PI / 2.0
			decor.add_child(maison)
		else:
			_boite(decor, Vector3(9, 5, 7), Vector3(x, y + 2.5, z), Color(0.80, 0.62, 0.42))
	var puits := Modeles.decor("building_well_yellow", 6.0)
	if puits != null:
		puits.position = Vector3(-300, Terrain.hauteur(-300, -20) - 0.3, -20)
		decor.add_child(puits)
	# Campement de chantier : tente (repos), tonneaux et caisses (repas), palettes et sacs (aire de battage)
	for objet in [["tent", 9.0, monde.point_repos + Vector3(0, 0, -8)], ["barrel", 3.0, monde.point_repas + Vector3(-12, 0, 0)],
			["crate_A_big", 3.0, monde.point_repas + Vector3(-12, 0, 5)], ["bucket_water", 2.0, monde.point_repas + Vector3(-9, 0, 2)],
			["pallet", 1.0, monde.point_stock], ["sack", 2.6, monde.point_stock + Vector3(2, 0.9, 0)], ["sack", 2.6, monde.point_stock + Vector3(-2, 0.9, 1)]]:
		var o := Modeles.decor(objet[0], objet[1])
		if o != null:
			var pp: Vector3 = objet[2]
			o.position = Vector3(pp.x, Terrain.hauteur(pp.x, pp.z) + pp.y * 0.0 + (0.9 if objet[0] == "sack" else 0.0), pp.z)
			decor.add_child(o)
	# Contour de la parcelle candidate (piquets jaunes)
	var pr2 := Terrain.PARCELLE
	for coin in [pr2.position, Vector2(pr2.end.x, pr2.position.y), pr2.end, Vector2(pr2.position.x, pr2.end.y)]:
		_boite(decor, Vector3(1.2, 6, 1.2), Vector3(coin.x, Terrain.hauteur(coin.x, coin.y) + 3.0, coin.y), Color(0.95, 0.80, 0.10))


func _creer_avatar() -> void:
	avatar = Modeles.personnage(0, 8.0)
	if avatar == null:
		avatar = Node3D.new()
		var corps := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 1.6
		cap.height = 7.0
		corps.mesh = cap
		corps.material_override = _mat(Color(0.95, 0.45, 0.10))
		corps.position.y = 3.5
		avatar.add_child(corps)
	# Repère au-dessus de la tête pour retrouver son personnage
	var repere := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 1.4
	cone.bottom_radius = 0.0
	cone.height = 2.4
	repere.mesh = cone
	var mr := StandardMaterial3D.new()
	mr.albedo_color = Color(1.0, 0.55, 0.05)
	mr.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	repere.material_override = mr
	repere.position.y = 11.0
	avatar.add_child(repere)
	add_child(avatar)
	avatar.position = Vector3(60, Terrain.hauteur(60, -150), -150)


func _poser_bornes() -> void:
	var pr := Terrain.PARCELLE
	var n := 0
	for i in 9:
		for coin in [Vector2(pr.position.x + pr.size.x * i / 8.0, pr.position.y), Vector2(pr.position.x + pr.size.x * i / 8.0, pr.end.y)]:
			_boite(bornes, Vector3(0.8, 2.4, 0.8), Vector3(coin.x, Terrain.hauteur(coin.x, coin.y) + 1.2, coin.y), Color(0.95, 0.95, 0.95))
			n += 1


func _groupe(id: String) -> Node3D:
	var g := Node3D.new()
	amenagement.add_child(g)
	groupes[id] = g
	return g


## Construit tous les ouvrages (rangés par lot de travaux) sur le relief courant
func _construire_amenagement() -> void:
	for c in amenagement.get_children():
		amenagement.remove_child(c)
		c.queue_free()
	groupes = {}
	var pr := Terrain.PARCELLE
	var terre := Color(0.52, 0.38, 0.24)
	# Diguettes : 4 colonnes x 5 rangées de casiers de 50 m
	var g := _groupe("diguettes")
	for i in 5:
		var x := pr.position.x + i * 50.0
		for j in 5:
			var zc := pr.position.y + j * 50.0 + 25.0
			_boite(g, Vector3(1.4, diguette_h * 3.0 + 0.4, 50), Vector3(x, Terrain.hauteur(x + 1.0 if i < 4 else x - 1.0, zc) + diguette_h, zc), terre)
	for j in 6:
		var z := pr.position.y + j * 50.0
		for i in 4:
			var xc := pr.position.x + i * 50.0 + 25.0
			_boite(g, Vector3(50, diguette_h * 3.0 + 0.4, 1.4), Vector3(xc, Terrain.hauteur(xc, z + 1.0 if j < 5 else z - 1.0) + diguette_h, z), terre)
	# Prise sur le marigot
	var prise := Vector3(Terrain.x_riviere(-330.0) + 6.0, 0, -330.0)
	var tete := Vector3(pr.position.x + 4.0, 0, pr.position.y - 8.0)
	g = _groupe("prise")
	_boite(g, Vector3(5, 4, 5), Vector3(prise.x, Terrain.hauteur(prise.x, prise.z) + 1.5, prise.z), Color(0.65, 0.65, 0.65))
	# Canal d'amenée ou conduite, puis canal de tête
	g = _groupe("canal")
	_troncon_canal(g, prise, tete)
	_troncon_canal(g, tete, Vector3(pr.end.x, 0, pr.position.y - 8.0))
	# Digue de protection côté marigot (par tronçons)
	if digue_h > 0.05:
		g = _groupe("digue")
		for k in 10:
			var zd: float = pr.position.y - 10.0 + (k + 0.5) * (L_DIGUE + 20.0) / 10.0
			_boite(g, Vector3(2.0 + digue_h * 4.0, digue_h * 2.0, (L_DIGUE + 20.0) / 10.0 + 0.3), Vector3(pr.position.x - 10.0, Terrain.hauteur(pr.position.x - 10.0, zd) + digue_h, zd), Color(0.45, 0.33, 0.20))
	# Drain collecteur à l'aval
	if avec_drain:
		g = _groupe("drain")
		for k in 8:
			var xd: float = pr.position.x - 10.0 + (k + 0.5) * (pr.size.x + 40.0) / 8.0
			_boite(g, Vector3((pr.size.x + 40.0) / 8.0 + 0.3, 0.3, 3.0), Vector3(xd, Terrain.hauteur(xd, pr.end.y + 9.0) + 0.1, pr.end.y + 9.0), Color(0.15, 0.30, 0.42))
	# Petit barrage en terre et sa retenue, à l'amont
	if barrage_h > 0.0:
		g = _groupe("barrage")
		var xb: float = Terrain.x_riviere(-378.0)
		var yb: float = Terrain.hauteur(xb + 20.0, -378.0)
		for k in 8:
			_boite(g, Vector3(70.0 / 8.0 + 0.2, barrage_h * 3.0, Hydrologie.crete_knappen(barrage_h) + barrage_h * 3.0), Vector3(xb - 35.0 + (k + 0.5) * 70.0 / 8.0, yb + barrage_h * 0.5, -378.0), Color(0.48, 0.36, 0.22))
		var lac := MeshInstance3D.new()
		var pl := PlaneMesh.new()
		pl.size = Vector2(80, 22)
		lac.mesh = pl
		lac.material_override = _mat(Color(0.20, 0.45, 0.65, 0.85), true)
		lac.position = Vector3(xb, yb + barrage_h * 0.9, -391.0)
		g.add_child(lac)
	# Station de pompage, champ solaire, local batterie, câble
	if source_eau == "pompe":
		g = _groupe("energie")
		var ys: float = Terrain.hauteur(prise.x + 14.0, -322.0)
		_boite(g, Vector3(4, 3, 3), Vector3(prise.x + 8.0, ys + 1.5, -326.0), Color(0.85, 0.35, 0.15))          # pompe
		if batterie_kwh > 0.0:
			_boite(g, Vector3(5, 4, 5), Vector3(prise.x + 16.0, ys + 2.0, -326.0), Color(0.90, 0.90, 0.85))      # local batterie
		if part_solaire > 1.0:
			var n_p: int = int(ceil(_kwc() * 1000.0 / 550.0))
			_boite(g, Vector3(0.4, 0.4, 16), Vector3(prise.x + 12.0, ys + 0.3, -316.0), Color(0.1, 0.1, 0.1))    # câble
			for k in n_p:
				var px: float = prise.x + 12.0 + (k % 6) * 5.2
				var pz: float = -306.0 + (k / 6) * 7.0
				var pan := _boite(g, Vector3(4.6, 0.25, 5.6), Vector3(px, Terrain.hauteur(px, pz) + 2.2, pz), Color(0.08, 0.12, 0.35))
				pan.rotation.x = deg_to_rad(12.0)
	# Lames d'eau des casiers et touffes de riz
	var plan := PlaneMesh.new()
	plan.size = Vector2(48.4, 48.4)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = plan
	mm.instance_count = 20
	eau_mm = MultiMeshInstance3D.new()
	eau_mm.multimesh = mm
	eau_mat = _mat(Color(0.25, 0.50, 0.70, 0.75), true)
	eau_mm.material_override = eau_mat
	amenagement.add_child(eau_mm)
	var touffe := _mesh_touffe()
	var mr := MultiMesh.new()
	mr.transform_format = MultiMesh.TRANSFORM_3D
	mr.mesh = touffe
	mr.instance_count = 40 * 50
	riz_mm = MultiMeshInstance3D.new()
	riz_mm.multimesh = mr
	riz_mat = ShaderMaterial.new()
	riz_mat.shader = load("res://scenes/riz.gdshader")
	riz_mm.material_override = riz_mat
	amenagement.add_child(riz_mm)
	_maj_parcelle(0.0, 0.0, 0.0)


## Touffe de riz : 6 feuilles effilées qui s'écartent (hauteur 1, de y = -0,5 à +0,5)
func _mesh_touffe() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 6:
		var a: float = TAU * k / 6.0 + 0.3
		var dehors := Vector3(cos(a), 0, sin(a))
		var cote := Vector3(-sin(a), 0, cos(a))
		var p0 := dehors * 0.08 - Vector3(0, 0.5, 0)
		var p1 := dehors * 0.45 + Vector3(0, 0.05, 0)
		var p2 := dehors * (0.95 if k % 2 == 0 else 0.6) + Vector3(0, 0.5 if k % 2 == 0 else 0.35, 0)
		for tri in [[p0 - cote * 0.07, p0 + cote * 0.07, p1 + cote * 0.13], [p0 - cote * 0.07, p1 + cote * 0.13, p1 - cote * 0.13], [p1 - cote * 0.13, p1 + cote * 0.13, p2]]:
			for v in tri:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	return st.commit()


func _troncon_canal(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var n: int = int(ceil(a.distance_to(b) / 12.0))
	var angle: float = atan2(b.x - a.x, b.z - a.z)
	for i in n:
		var p: Vector3 = a.lerp(b, (i + 0.5) / n)
		var y := Terrain.hauteur(p.x, p.z)
		var seg := Node3D.new()
		parent.add_child(seg)
		if adduction == "pvc":
			_boite(seg, Vector3(pvc_dn / 1000.0 * 6.0, pvc_dn / 1000.0 * 6.0, a.distance_to(b) / n + 0.5), Vector3(p.x, y + 0.5, p.z), Color(0.35, 0.40, 0.48), angle)
		else:
			var larg: float = canal_b + 2.0 * canal_h + 1.5
			_boite(seg, Vector3(larg + 2.0, 0.9, a.distance_to(b) / n + 0.5), Vector3(p.x, y + 0.25, p.z), Color(0.52, 0.38, 0.24), angle)
			_boite(seg, Vector3(larg, 0.3, a.distance_to(b) / n + 0.5), Vector3(p.x, y + 0.62, p.z), Color(0.22, 0.48, 0.68), angle)


## Met à jour l'eau des casiers (lame en mm) et la croissance du riz (0..1) et sa maturité (0..1)
func _maj_parcelle(lame_mm: float, croissance: float, maturite: float) -> void:
	if eau_mm == null:
		return
	var pr := Terrain.PARCELLE
	var k := 0
	for i in 4:
		for j in 5:
			var c := Vector3(pr.position.x + i * 50.0 + 25.0, 0, pr.position.y + j * 50.0 + 25.0)
			c.y = Terrain.hauteur(c.x, c.z) + 0.03 + lame_mm / 1000.0 * 3.0
			eau_mm.multimesh.set_instance_transform(k, Transform3D(Basis(), c))
			k += 1
	eau_mm.visible = lame_mm > 0.5
	eau_mat.albedo_color.a = clamp(0.35 + lame_mm / 200.0, 0.35, 0.85)
	k = 0
	var haut: float = 0.05 + croissance * 3.2
	for i in 40:
		for j in 50:
			var x := pr.position.x + i * 5.0 + 2.5
			var z := pr.position.y + j * 5.0 + 2.5
			var y := Terrain.hauteur(x, z)
			riz_mm.multimesh.set_instance_transform(k, Transform3D(Basis().scaled(Vector3(1, haut, 1)), Vector3(x, y + haut / 2.0, z)))
			k += 1
	riz_mm.visible = croissance > 0.0
	var cr: Color = Color(0.30, 0.72, 0.22).lerp(Color(0.85, 0.72, 0.25), maturite)
	riz_mat.set_shader_parameter("couleur", Vector3(cr.r, cr.g, cr.b))


# =====================================================================
#  CAMÉRA ET DÉPLACEMENT
# =====================================================================

func _process(delta: float) -> void:
	var dir := Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch))
	cam.position = cam_cible + dir * cam_dist
	cam.look_at(cam_cible)
	# Horloge : pendant le chantier et la campagne, l'heure suit le temps simulé ; sinon elle s'écoule doucement
	var en_cours: bool = (etape == Etape.TRAVAUX and not chantier.fini) or (etape == Etape.CAMPAGNE and campagne != null and not campagne.termine)
	if en_cours:
		monde.heure = fmod(6.0 + cumul_temps * 24.0, 24.0)
		monde.ouvriers_actifs = true
	else:
		heure_libre = fmod(heure_libre + delta * 24.0 / 240.0, 24.0)
		monde.heure = heure_libre
		monde.ouvriers_actifs = false
		monde.il_pleut = false
	if OS.get_environment("AGRISIM_HEURE") != "":
		monde.heure = float(OS.get_environment("AGRISIM_HEURE"))
	monde.maj(delta, cam_cible)
	if en_cours and not en_pause and not popup.visible:
		var dj: float = delta * vitesse
		monde.simuler_agents(dj * 24.0, pluie_forte)
		cumul_temps += dj
		while cumul_temps >= 1.0 and not popup.visible:
			cumul_temps -= 1.0
			if not _avancer_un_jour():
				break


## Fait passer un jour (chantier ou campagne). Renvoie faux quand il n'y a plus rien à simuler.
func _avancer_un_jour() -> bool:
	if etape == Etape.TRAVAUX and not chantier.fini:
		_jour_de_travaux()
		return true
	if etape == Etape.CAMPAGNE and campagne != null and not campagne.termine:
		_jour_de_campagne()
		return true
	return false


func _passer_jours(n: int) -> void:
	for k in n:
		if popup.visible:
			break
		monde.simuler_agents(24.0, pluie_forte)
		if not _avancer_un_jour():
			break


func _barre_temps() -> void:
	var ligne := HBoxContainer.new()
	panneau.add_child(ligne)
	for v in [["Pause", 0.0], ["1 j = 2 min", 1.0 / 120.0], ["1 j = 30 s", 1.0 / 30.0], ["1 j = 5 s", 0.2], ["Rapide", 4.0]]:
		var b := Button.new()
		b.text = v[0]
		b.custom_minimum_size = Vector2(0, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 14)
		var vv: float = v[1]
		b.pressed.connect(func():
			en_pause = vv == 0.0
			if vv > 0.0:
				vitesse = vv)
		ligne.add_child(b)
	var l2 := HBoxContainer.new()
	panneau.add_child(l2)
	for v in [["Passer 1 jour", 1], ["Passer 10 jours", 10]]:
		var b := Button.new()
		b.text = v[0]
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nn: int = v[1]
		b.pressed.connect(func(): _passer_jours(nn))
		l2.add_child(b)
	var l3 := HBoxContainer.new()
	panneau.add_child(l3)
	for v in [["Travail normal", "auto"], ["Tous à table", "manger"], ["Repos", "repos"], ["Forcer", "forcer"]]:
		var b := Button.new()
		b.text = v[0]
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 14)
		var oo: String = v[1]
		b.pressed.connect(func():
			monde.ordre_a_tous(oo)
			info.text = "Ordre donné à toute l'équipe : %s. Touche un ouvrier pour lui parler." % v[0].to_lower())
		l3.add_child(b)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = max(40.0, cam_dist * 0.9)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = min(900.0, cam_dist * 1.1)
	if ev is InputEventMagnifyGesture:
		cam_dist = clamp(cam_dist / ev.factor, 40.0, 900.0)
	if ev is InputEventScreenTouch:
		if ev.pressed:
			touches[ev.index] = ev.position
			appui_pos = ev.position
			appui_bouge = 0.0
		else:
			touches.erase(ev.index)
			if appui_bouge < 14.0 and touches.is_empty():
				_toucher_terrain(ev.position)
	if ev is InputEventScreenDrag:
		appui_bouge += ev.relative.length()
		if touches.size() >= 2:
			var autre: Vector2 = Vector2.ZERO
			for k in touches:
				if k != ev.index:
					autre = touches[k]
			var avant: float = (touches[ev.index] as Vector2).distance_to(autre)
			var apres: float = ev.position.distance_to(autre)
			if avant > 1.0:
				cam_dist = clamp(cam_dist * avant / max(apres, 1.0), 40.0, 900.0)
		else:
			cam_yaw -= ev.relative.x * 0.006
			cam_pitch = clamp(cam_pitch + ev.relative.y * 0.005, 0.15, 1.45)
		touches[ev.index] = ev.position


func _toucher_terrain(pos_ecran: Vector2) -> void:
	var p = Terrain.lancer_rayon(cam.project_ray_origin(pos_ecran), cam.project_ray_normal(pos_ecran))
	if p == null:
		return
	var cible: Vector3 = p
	if monde.ouvriers_actifs:
		var ia: int = monde.agent_proche(cible)
		if ia >= 0:
			_fiche_ouvrier(ia)
			return
	var tw := create_tween()
	var duree: float = clamp(avatar.position.distance_to(cible) / 45.0, 0.4, 8.0)
	avatar.rotation.y = atan2(cible.x - avatar.position.x, cible.z - avatar.position.z)
	Modeles.jouer(avatar, "Walking_A")
	tw.tween_property(avatar, "position", cible, duree)
	tw.tween_callback(func(): Modeles.jouer(avatar, "Idle"))
	tw.parallel().tween_property(self, "cam_cible", cible, 0.8)
	var dans: bool = Terrain.PARCELLE.has_point(Vector2(cible.x, cible.z))
	var lieu := "dans la parcelle" if dans else "hors parcelle"
	if fait.has("topo"):
		info.text = "Altitude : %.2f m (levé topographique) — %s" % [cible.y, lieu]
	else:
		info.text = "Altitude : environ %d m (estimation à l'œil, ± 1 m) — %s" % [int(round(cible.y)), lieu]


# =====================================================================
#  INTERFACE
# =====================================================================

func _fiche_ouvrier(i: int) -> void:
	var a: Dictionary = monde.agents[i]
	var etats := {"travaille": "au travail", "mange": "en train de manger", "repos": "se repose", "dort": "dort", "absent": "absent aujourd'hui"}
	var avis := "En forme."
	if a.fatigue > 80.0: avis = "« Patron, je n'en peux plus. »"
	elif a.faim > 75.0: avis = "« J'ai faim, on mange quand ? »"
	elif a.fatigue > 55.0: avis = "« Ça commence à tirer. »"
	var bb := "[b][font_size=26]%s[/font_size][/b] — %s\n\nEn ce moment : [b]%s[/b]\nFatigue : [b]%d %%[/b] · Faim : [b]%d %%[/b]\nConsigne : %s\n\n%s\n\n[i]Chaque ouvrier décide seul de manger ou de se reposer selon ses besoins, sauf si tu lui donnes un ordre. Un ouvrier épuisé ne vient pas le lendemain.[/i]" % [a.nom, a.role, etats[a.etat], int(a.fatigue), int(a.faim), {"auto": "il s'organise seul", "manger": "aller manger", "repos": "se reposer", "forcer": "ne pas s'arrêter"}[a.ordre], avis]
	_afficher_popup(bb, [["Repose-toi", func(): a.ordre = "repos"], ["Va manger", func(): a.ordre = "manger"], ["Au travail", func(): a.ordre = "auto"], ["Fermer", Callable()]])


func _creer_interface() -> void:
	var couche := CanvasLayer.new()
	add_child(couche)
	var racine := Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 19
	racine.theme = theme
	couche.add_child(racine)

	hud = Label.new()
	hud.position = Vector2(14, 8)
	hud.add_theme_font_size_override("font_size", 20)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 6)
	racine.add_child(hud)
	info = Label.new()
	info.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	info.position = Vector2(14, -40)
	info.add_theme_color_override("font_outline_color", Color.BLACK)
	info.add_theme_constant_override("outline_size", 6)
	info.text = "Glisse pour tourner, pince ou molette pour zoomer, touche le sol pour t'y rendre."
	racine.add_child(info)

	var cadre := PanelContainer.new()
	cadre.anchor_left = 0.62
	cadre.anchor_right = 1.0
	cadre.anchor_bottom = 1.0
	cadre.offset_left = 0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.15, 0.93)
	style.set_content_margin_all(14)
	cadre.add_theme_stylebox_override("panel", style)
	racine.add_child(cadre)
	var col := VBoxContainer.new()
	cadre.add_child(col)
	titre = Label.new()
	titre.add_theme_font_size_override("font_size", 24)
	titre.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
	titre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(titre)
	var defil := ScrollContainer.new()
	defil.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(defil)
	panneau = VBoxContainer.new()
	panneau.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panneau.add_theme_constant_override("separation", 8)
	defil.add_child(panneau)
	var bas := HBoxContainer.new()
	col.add_child(bas)
	var b_codex := Button.new()
	b_codex.text = "Codex"
	b_codex.custom_minimum_size = Vector2(0, 46)
	b_codex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_codex.pressed.connect(_ouvrir_codex)
	bas.add_child(b_codex)
	var b_compta := Button.new()
	b_compta.text = "Comptes"
	b_compta.custom_minimum_size = Vector2(0, 46)
	b_compta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_compta.pressed.connect(_ouvrir_comptes)
	bas.add_child(b_compta)

	popup = PanelContainer.new()
	popup.anchor_left = 0.08
	popup.anchor_right = 0.92
	popup.anchor_top = 0.08
	popup.anchor_bottom = 0.92
	var st2 := StyleBoxFlat.new()
	st2.bg_color = Color(0.97, 0.95, 0.90)
	st2.set_content_margin_all(18)
	st2.set_corner_radius_all(10)
	popup.add_theme_stylebox_override("panel", st2)
	popup.visible = false
	racine.add_child(popup)
	var pc := VBoxContainer.new()
	popup.add_child(pc)
	popup_texte = RichTextLabel.new()
	popup_texte.bbcode_enabled = true
	popup_texte.size_flags_vertical = Control.SIZE_EXPAND_FILL
	popup_texte.add_theme_color_override("default_color", Color(0.12, 0.12, 0.12))
	pc.add_child(popup_texte)
	popup_boutons = HBoxContainer.new()
	popup_boutons.alignment = BoxContainer.ALIGNMENT_END
	popup_boutons.add_theme_constant_override("separation", 8)
	pc.add_child(popup_boutons)


func _vider() -> void:
	for c in panneau.get_children():
		panneau.remove_child(c)
		c.queue_free()


func _texte(bb: String) -> RichTextLabel:
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.text = bb
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panneau.add_child(t)
	return t


func _bouton(texte: String, action: Callable, actif := true) -> Button:
	var b := Button.new()
	b.text = texte
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 52)
	b.disabled = not actif
	b.pressed.connect(action)
	panneau.add_child(b)
	return b


func _curseur(etiquette: String, mini: float, maxi: float, pas: float, valeur: float, action: Callable) -> void:
	var l := Label.new()
	l.text = etiquette
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panneau.add_child(l)
	var s := HSlider.new()
	s.min_value = mini
	s.max_value = maxi
	s.step = pas
	s.value = valeur
	s.custom_minimum_size = Vector2(0, 36)
	s.value_changed.connect(action)
	panneau.add_child(s)


func _afficher_popup(bb: String, boutons: Array) -> void:
	popup_texte.text = bb
	for c in popup_boutons.get_children():
		popup_boutons.remove_child(c)
		c.queue_free()
	for b in boutons:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(130, 52)
		var action: Callable = b[1]
		btn.pressed.connect(func():
			popup.visible = false
			if action.is_valid():
				action.call())
		popup_boutons.add_child(btn)
	popup.visible = true


func _fcfa(v: float) -> String:
	var s := str(int(round(abs(v))))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out + " FCFA"


func _maj_hud() -> void:
	var noms := ["Arrivée", "1. Foncier", "2. Études", "3. Besoins en eau", "4. Conception", "5. Équipe", "6. Chantier", "7. Campagne", "8. Bilan"]
	hud.text = "%s   |   Trésorerie : %s   |   Jour %d du projet" % [noms[etape], _fcfa(tresorerie), jours_ecoules]


func _payer(libelle: String, montant: float, categorie: String, jours := 0) -> void:
	tresorerie -= montant
	jours_ecoules += jours
	charges.append([libelle, montant, categorie])
	_maj_hud()


func _vu(id: String) -> void:
	notions_vues[id] = true


func _ouvrir_codex() -> void:
	var bb := "[b][font_size=26]Codex — notions rencontrées[/font_size][/b]\n\n"
	var n := 0
	for no in notions:
		if notions_vues.has(no.id):
			n += 1
			var etiq: String = "Dans ton cours" if no.provenance == "cours" else "Approfondissement (hors cours)"
			bb += "[b]%s[/b]\n%s\n[color=#1F4E79][i]%s — %s[/i][/color]\n\n" % [no.titre, no.texte, etiq, no.ref]
	if n == 0:
		bb += "Aucune notion débloquée pour l'instant. Avance dans le projet."
	_afficher_popup(bb, [["Fermer", Callable()]])


func _ouvrir_comptes() -> void:
	var bb := "[b][font_size=26]Comptes du projet[/font_size][/b]\n\n[table=2]"
	for c in charges:
		bb += "[cell]%s   [/cell][cell]%s[/cell]" % [c[0], _fcfa(-c[1])]
	bb += "[/table]\n\n[b]Trésorerie : %s[/b]\n[i]Tous les coûts sont des valeurs indicatives, modifiables dans donnees/couts.json.[/i]" % _fcfa(tresorerie)
	_afficher_popup(bb, [["Ajouter 5 000 000 FCFA", func():
			tresorerie += 5000000.0
			charges.append(["Apport au budget", -5000000.0, "apport"])
			_maj_hud()
			_ouvrir_comptes()],
		["Budget illimité : %s" % ("OUI" if budget_illimite else "non"), func():
			budget_illimite = not budget_illimite
			_ouvrir_comptes()],
		["Fermer", Callable()]])


# =====================================================================
#  DÉROULEMENT
# =====================================================================

func _nouvelle_partie() -> void:
	tresorerie = couts.capital_initial
	jours_ecoules = 0
	fait = {}
	charges = []
	evenements = []
	notions_vues = {}
	quiz_juste = false
	motopompe = false
	litige_jours_restants = 0
	retard_j = 0
	lots = []
	groupes = {}
	chantier = {"jour": 0, "debut": 0, "fini": false, "salaires": 0.0}
	barrage_h = 0.0
	source_eau = "gravite"
	adduction = "canal"
	part_solaire = 0.0
	batterie_kwh = 0.0
	campagne = null
	avec_drain = false
	digue_h = 0.0
	terrain_mat.set_shader_parameter("contours", 0.0)
	for c in amenagement.get_children():
		c.queue_free()
	for c in bornes.get_children():
		c.queue_free()
	eau_mm = null
	riz_mm = null
	nappe_crue.visible = false
	_generer_site()
	_aller(Etape.INTRO)


func _aller(e: int) -> void:
	etape = e
	_maj_hud()
	match e:
		Etape.INTRO: _ecran_intro()
		Etape.FONCIER: _ecran_foncier()
		Etape.ETUDES: _ecran_etudes()
		Etape.BESOINS: _ecran_besoins()
		Etape.CONCEPTION: _ecran_conception()
		Etape.RECRUTEMENT: _ecran_recrutement()
		Etape.TRAVAUX: _demarrer_travaux()
		Etape.CAMPAGNE: _demarrer_campagne()
		Etape.BILAN: _ecran_bilan()


## Construit la réalité du terrain à partir de la configuration choisie
func _generer_site() -> void:
	climat = climats[site.region]
	topo = topos[site.topo]
	Terrain.vider_grille()
	var cache := DonneesReelles.lire_cache(site.ville)
	if site.mode == "reel" and not cache.is_empty():
		# Relief et climat réels du lieu (cache local : fonctionne hors connexion)
		climat = cache.climat
		Terrain.DEMI_FOND = 400.0
		Terrain.H_VERSANT = 0.0
		Terrain.charger_grille(cache.altitudes, int(cache.n))
		var pentes: Array = Terrain.pentes_parcelle()
		var modele: String = "plaine" if pentes[0] + pentes[1] < 0.003 else ("versant" if pentes[1] > 0.025 else ("vallee_pentue" if pentes[0] > 0.01 else "bas_fond"))
		topo = topos[modele].duplicate()
		topo.nom = "Relief réel (satellite, maille 90 m)"
		topo.description = "Pentes mesurées sur la parcelle : %.1f ‰ en long, %.1f ‰ en travers. Comportement hydrologique rapproché du type « %s »." % [pentes[0] * 1000.0, pentes[1] * 1000.0, topos[modele].nom.to_lower()]
		topo.pente_long = pentes[0]
		topo.pente_trans = pentes[1]
		topo.pente_canal = clamp(pentes[0] * 0.3, 0.0002, 0.004)
		topo.demi_fond = 400.0
		topo.h_versant = 0.0
	var tex: Dictionary = sols.textures[site.texture]
	var stru: Dictionary = sols.structures[site.structure]
	var sol := {"nom": tex.nom, "structure_nom": stru.nom, "cc_pct": tex.cc_pct, "pfp_pct": tex.pfp_pct,
		"percolation_mm_j": tex.percolation_mm_j * stru.percolation_x, "fertilite": stru.fertilite,
		"profondeur_cm": site.profondeur}
	# Débit prélevable du marigot : dépend de la pluie du mois et du mois précédent, et de la taille du bassin
	var q: Array = []
	for m in 12:
		var lag: float = (0.6 * climat.pluie_mm[m] + 0.4 * climat.pluie_mm[(m + 11) % 12]) * site.pluie_pct / 100.0
		q.append(0.0254 * pow(lag / 100.0, 2) * topo.bassin)
	var kc: float = float(topo.crue_facteur) * site.crues_pct / 100.0
	VRAI = {"sol": sol, "pente": topo.pente_long, "pente_canal": topo.pente_canal, "q_riviere": q,
		"crue_2ans": 0.5 * kc, "crue_10ans": 0.9 * kc, "crue_50ans": 1.2 * kc}
	var lim: Dictionary = sols.textures.limoneux
	CROYANCE = {"sol": {"nom": lim.nom, "percolation_mm_j": lim.percolation_mm_j}, "pente_canal": float(topo.pente_canal) * 0.3, "crue": 0.5}
	if Terrain.grille_n == 0:
		Terrain.configurer(topo)
	_reconstruire_terrain()
	for c in decor.get_children():
		c.queue_free()
	_creer_riviere()
	_creer_decor()
	avatar.position = Vector3(60, Terrain.hauteur(60, -150), -150)
	cam_cible = Vector3(140, Terrain.hauteur(140, 0), 0)


func _donnees_reelles_recues(ok: bool, message: String) -> void:
	if ok:
		site.mode = "reel"
		etat_reseau = "Connecté : données mises à jour."
		if etape == Etape.INTRO:
			_generer_site()
	else:
		etat_reseau = "Hors connexion (%s). %s" % [message, "Le jeu continue avec les dernières données enregistrées." if not DonneesReelles.lire_cache(site.ville).is_empty() else "Le jeu continue avec le site d'exercice."]
	if etape == Etape.INTRO:
		_ecran_intro()


func _suivant(liste: Array, valeur) -> Variant:
	return liste[(liste.find(valeur) + 1) % liste.size()]


## Indice de difficulté du site (0 à 100), pour information
func _difficulte() -> int:
	var d := 0.0
	d += clamp((VRAI.sol.percolation_mm_j - 2.0) * 2.0, 0.0, 30.0)
	d += clamp(_volume_planage() / 400.0, 0.0, 20.0)
	d += clamp(15.0 * (100.0 / max(site.pluie_pct, 10.0) - 0.8), 0.0, 15.0)
	d += clamp(site.secheresse_j / 3.0, 0.0, 12.0)
	d += clamp(VRAI.crue_10ans * 10.0, 0.0, 15.0)
	d += 8.0 if float(climat.pluie_mm.min()) < 10.0 else 0.0
	return int(clamp(d, 0.0, 100.0))


func _ecran_intro() -> void:
	_vider()
	titre.text = "Nouveau projet"
	_texte("Tu es jeune diplômé AHA de l'Université de San-Pédro. Une coopérative te confie [b]%s[/b] pour aménager [b]5 ha[/b] de riz irrigué (piquets jaunes). Choisis le site : chaque combinaison donne un problème d'ingénieur différent." % _fcfa(couts.capital_initial))
	var total_pluie := 0.0
	for v in climat.pluie_mm:
		total_pluie += v
	var v: Dictionary = villes[site.ville]
	var cache := DonneesReelles.lire_cache(site.ville)
	_bouton("Lieu : %s (%.2f° N, %.2f° O)" % [v.nom, v.lat, -v.lon], func():
		site.ville = _suivant(villes.keys(), site.ville)
		site.region = villes[site.ville].climat_exercice
		if DonneesReelles.lire_cache(site.ville).is_empty():
			site.mode = "exercice"
		etat_reseau = ""
		_generer_site(); _ecran_intro())
	var etat := "Aucune donnée réelle enregistrée pour ce lieu." if cache.is_empty() else "Données réelles enregistrées le %s : utilisables hors connexion." % cache.date
	if etat_reseau != "":
		etat += "\n" + etat_reseau
	_texte("[color=#9fd3ff]%s[/color]" % etat)
	_bouton("Téléchargement en cours…" if reel.en_cours else ("Télécharger le relief et le climat réels (satellite)" if cache.is_empty() else "Mettre à jour les données réelles"), func():
		etat_reseau = ""
		reel.telecharger(site.ville, villes[site.ville])
		_ecran_intro(), not reel.en_cours)
	if not cache.is_empty():
		_bouton("Terrain utilisé : %s" % ("RÉEL (satellite)" if site.mode == "reel" else "site d'exercice au choix"), func():
			site.mode = "exercice" if site.mode == "reel" else "reel"
			_generer_site(); _ecran_intro())
	if site.mode == "reel" and not cache.is_empty():
		_texte("[b]%s[/b] · %.0f mm/an · altitude %.0f m\n[b]%s[/b]\n%s\n[i]Le satellite ne voit pas le sol sous la surface : choisis-le ci-dessous. Le marigot est placé par convention.[/i]" % [climat.nom, total_pluie * site.pluie_pct / 100.0, climat.altitude_m, topo.nom, topo.description])
	else:
		_bouton("Région climatique : %s\n%s · %.0f mm/an" % [climat.nom, climat.zone, total_pluie * site.pluie_pct / 100.0], func():
			site.region = _suivant(climats.keys(), site.region); _generer_site(); _ecran_intro())
		_bouton("Relief : %s\n%s" % [topo.nom, topo.description], func():
			site.topo = _suivant(topos.keys(), site.topo); _generer_site(); _ecran_intro())
	_bouton("Texture du sol : %s" % sols.textures[site.texture].nom, func():
		site.texture = _suivant(sols.textures.keys(), site.texture); _generer_site(); _ecran_intro())
	_bouton("Structure du sol : %s" % sols.structures[site.structure].nom, func():
		site.structure = _suivant(sols.structures.keys(), site.structure); _generer_site(); _ecran_intro())
	_bouton("Profondeur utile du sol : %d cm" % site.profondeur, func():
		site.profondeur = int(_suivant([30, 50, 80], site.profondeur)); _generer_site(); _ecran_intro())
	_texte("[b]Climat de l'année[/b]")
	_curseur("Pluie : %.0f %% de la normale" % site.pluie_pct, 50, 150, 5, site.pluie_pct, func(x): site.pluie_pct = x; _generer_site(); _ecran_intro())
	_curseur("Évapotranspiration (ET0) : %.0f %% de la normale" % site.et0_pct, 80, 130, 5, site.et0_pct, func(x): site.et0_pct = x; _ecran_intro())
	_curseur("Poche de sécheresse en pleine campagne : %.0f jours" % site.secheresse_j, 0, 40, 5, site.secheresse_j, func(x): site.secheresse_j = x; _ecran_intro())
	_curseur("Hauteur des crues : %.0f %% de la normale" % site.crues_pct, 0, 200, 10, site.crues_pct, func(x): site.crues_pct = x; _generer_site(); _ecran_intro())
	_texte("[b]Difficulté du site : %d / 100[/b]\n[i]Lieux et personnages fictifs. Relief et climats calibrés, valeurs indicatives à remplacer par les données réelles.[/i]" % _difficulte())
	_bouton("Tirer un site au hasard", func():
		site.region = climats.keys()[rng.randi() % climats.size()]
		site.topo = topos.keys()[rng.randi() % topos.size()]
		site.texture = sols.textures.keys()[rng.randi() % 3]
		site.structure = sols.structures.keys()[rng.randi() % 3]
		site.profondeur = [30, 50, 80][rng.randi() % 3]
		site.pluie_pct = float(rng.randi_range(12, 26) * 5)
		site.secheresse_j = float(rng.randi_range(0, 6) * 5)
		_generer_site(); _ecran_intro())
	_bouton("Commencer par le foncier", func(): _aller(Etape.FONCIER))


func _ecran_foncier() -> void:
	_vider()
	_vu("foncier")
	titre.text = "1. Sécuriser le terrain"
	_texte("Le bas-fond appartient, selon la coutume, à une grande famille du village. Avant d'investir, sécurise ton droit d'usage. Chaque démarche coûte du temps et de l'argent ; chaque démarche sautée augmente le risque de litige.")
	for d in DEMARCHES:
		var montant: float = couts.foncier[d.cout]
		if fait.has(d.id):
			_texte("[color=#8fd18f]✔ %s[/color]" % d.nom)
		else:
			var dd: Dictionary = d
			_bouton("%s\n%s · %d jours" % [d.nom, _fcfa(montant), d.jours], func():
				_payer("Foncier : " + dd.id, montant, "foncier", dd.jours)
				fait[dd.id] = true
				if dd.id == "bornage":
					_poser_bornes()
				_ecran_foncier())
	_texte("[i]Procédure simplifiée pour le jeu. Les textes en vigueur (loi n° 98-750 modifiée, rôle de l'AFOR) sont à vérifier avant tout projet réel.[/i]")
	_bouton("Conclure le bail (loyer annuel : %s) et passer aux études" % _fcfa(couts.foncier.loyer_annuel_ha * 5.0), func():
		_payer("Loyer annuel 5 ha", couts.foncier.loyer_annuel_ha * 5.0, "campagne")
		_aller(Etape.ETUDES))


func _risque_litige() -> float:
	var r := 0.80
	for d in DEMARCHES:
		if fait.has(d.id):
			r -= d.risque
	return max(r, 0.03)


func _ecran_etudes() -> void:
	_vider()
	_vu("etudes")
	titre.text = "2. Études préalables"
	_texte("« La réussite d'un projet d'irrigation dépend fortement de la qualité des études réalisées avant les travaux. » Tu peux commander chaque étude, ou t'en passer et décider à l'œil.")
	for e in ETUDES:
		var montant: float = couts.etudes[e.cout]
		if fait.has(e.id):
			_texte("[color=#8fd18f]✔ %s[/color]\n%s" % [e.nom, _resultat_etude(e.id)])
		else:
			var ee: Dictionary = e
			_bouton("%s\n%s · %d jours" % [e.nom, _fcfa(montant), e.jours], func():
				_payer("Étude : " + ee.id, montant, "etudes", ee.jours)
				fait[ee.id] = true
				if ee.id == "topo":
					terrain_mat.set_shader_parameter("contours", 1.0)
				if ee.id == "sol":
					_vu("texture")
					_vu("ru")
				if ee.id == "hydro":
					_vu("retour")
				_ecran_etudes())
	_bouton("Passer au calcul des besoins en eau", func(): _aller(Etape.BESOINS))


func _resultat_etude(id: String) -> String:
	match id:
		"topo":
			return "Pente du terrain : [b]%.1f ‰[/b] en long, [b]%.1f ‰[/b] en travers. Pente disponible le long du tracé du canal : [b]%.1f ‰[/b]. Planage des casiers : environ [b]%.0f m³[/b]. Courbes de niveau affichées ; touche le sol pour lire une altitude précise." % [VRAI.pente * 1000.0, topo.pente_trans * 1000.0, VRAI.pente_canal * 1000.0, _volume_planage()]
		"sol":
			var s: Dictionary = VRAI.sol
			return "Sol [b]%s[/b], structure %s, profondeur utile %d cm. CC %d %%, PFP %d %% (en volume), percolation sous lame d'eau [b]%.0f mm/j[/b]. RU = %.0f mm. %s" % [s.nom, s.structure_nom, s.profondeur_cm, s.cc_pct, s.pfp_pct, s.percolation_mm_j, Eau.reserve_utile(s.cc_pct, s.pfp_pct, s.profondeur_cm * 10.0), "Très favorable au riz." if s.percolation_mm_j <= 3.0 else ("Acceptable pour le riz." if s.percolation_mm_j <= 8.0 else "Sol très filtrant : le riz en casiers consommera énormément d'eau.")]
		"hydro":
			var qmin: float = VRAI.q_riviere.min()
			var qmax: float = VRAI.q_riviere.max()
			var mois := ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]
			var crue_t := "Pas de crue à craindre sur ce site." if VRAI.crue_10ans <= 0.0 else "Crue au droit de la parcelle : [b]%.1f m[/b] (période de retour 2 ans), [b]%.1f m[/b] (10 ans), %.1f m (50 ans), durée %d jours." % [VRAI.crue_2ans, VRAI.crue_10ans, VRAI.crue_50ans, topo.crue_duree]
			return "Débit prélevable : de [b]%.1f L/s[/b] (%s) à %.0f L/s (%s). %s" % [qmin * 1000.0, mois[VRAI.q_riviere.find(qmin)], qmax * 1000.0, mois[VRAI.q_riviere.find(qmax)], crue_t]
	return ""


# --- Valeurs « connues » du joueur : mesurées si l'étude est faite, sinon estimées ---
func _sol_connu() -> Dictionary:
	return VRAI.sol if fait.has("sol") else CROYANCE.sol

func _pente_connue() -> float:
	return VRAI.pente_canal if fait.has("topo") else CROYANCE.pente_canal

func _besoin_brut_pointe(perc: float) -> float:
	var jour_semis: int = SEMIS[semis_idx].jour
	var et0_max := 0.0
	for j in range(jour_semis + 50, jour_semis + 90):
		et0_max = max(et0_max, climat.et0_mm_j[Meteo.mois_du_jour(j)])
	return Eau.besoin_brut(Eau.etc(et0_max, riz.kc_mid) + perc, EFFICIENCE)

func _et0_pointe() -> float:
	var jour_semis: int = SEMIS[semis_idx].jour
	var et0_max := 0.0
	for j in range(jour_semis + 50, jour_semis + 90):
		et0_max = max(et0_max, climat.et0_mm_j[Meteo.mois_du_jour(j)])
	return et0_max


func _ecran_besoins() -> void:
	_vider()
	for id in ["etc", "brut", "qfc"]:
		_vu(id)
	titre.text = "3. Besoins en eau"
	_texte("Choisis d'abord la date de repiquage du riz (cycle de 120 jours).")
	for i in SEMIS.size():
		var ii := i
		_bouton(("● " if i == semis_idx else "○ ") + SEMIS[i].nom, func():
			semis_idx = ii
			_ecran_besoins())
	var sol := _sol_connu()
	var perc: float = sol.percolation_mm_j
	var et0 := _et0_pointe()
	var origine := "mesurée par l'étude de sol" if fait.has("sol") else "[color=#ffb347]estimée à l'œil (sol jugé limoneux)[/color]"
	_texte("[b]Données de pointe (mi-saison, période sans pluie)[/b]\nET0 = %.1f mm/j · Kc mi-saison = %.2f\nPercolation = %.0f mm/j, %s\nEfficience du gravitaire = %.2f · Surface = 5 ha\n\n[b]À toi : quel débit de projet pour le canal d'amenée ?[/b]" % [et0, riz.kc_mid, perc, origine, EFFICIENCE])
	var juste: float = Eau.debit_equipement(Eau.debit_fictif_continu(_besoin_brut_pointe(perc)), 5.0)
	var sans_eff: float = Eau.debit_equipement(Eau.debit_fictif_continu(Eau.etc(et0, riz.kc_mid) + perc), 5.0)
	var sans_perc: float = Eau.debit_equipement(Eau.debit_fictif_continu(Eau.besoin_brut(Eau.etc(et0, riz.kc_mid), EFFICIENCE)), 5.0)
	var choix := [[sans_perc, false, "Tu as oublié la percolation : en rizière, l'eau qui s'infiltre sous la lame doit aussi être compensée."],
		[juste, true, ""], [sans_eff, false, "Tu as oublié l'efficience : besoin brut = besoin net ÷ efficience. Le canal en terre perd de l'eau."]]
	for c in choix:
		var cc: Array = c
		_bouton("%.1f L/s" % (cc[0] * 1000.0), func():
			q_projet = cc[0]
			quiz_juste = cc[1]
			var bb := "[b][font_size=24]%s[/font_size][/b]\n\n" % ("Exact !" if cc[1] else "Pas tout à fait.")
			if not cc[1]:
				bb += cc[2] + "\n\nTu peux garder ta valeur (et en subir les conséquences) ou recommencer.\n\n"
			bb += _calcul_besoins(et0, perc)
			var btns := [["Continuer vers la conception", func(): _aller(Etape.CONCEPTION)]]
			if not cc[1]:
				btns.push_front(["Recommencer", Callable()])
			_afficher_popup(bb, btns))


func _calcul_besoins(et0: float, perc: float) -> String:
	var etc_v: float = Eau.etc(et0, riz.kc_mid)
	var net: float = etc_v + perc
	var brut: float = Eau.besoin_brut(net, EFFICIENCE)
	var qfc: float = Eau.debit_fictif_continu(brut)
	return "[b]Voir le calcul[/b]\n1. ETc = Kc × ET0 = %.2f × %.1f = [b]%.2f mm/j[/b]\n2. Besoin net de la rizière = ETc + percolation − pluie efficace = %.2f + %.0f − 0 = [b]%.2f mm/j[/b]\n3. Besoin brut = besoin net ÷ efficience = %.2f ÷ %.2f = [b]%.2f mm/j[/b]\n4. Débit fictif continu = besoin brut × 10 000 ÷ 86 400 = [b]%.2f L/s/ha[/b]\n5. Débit de projet = %.2f × 5 ha = [b]%.1f L/s[/b]\n\n[color=#1F4E79][i]Dans ton cours : L3 — Bases techniques et pilotage de projet d'irrigation, ch. 1 (Qfc) et ch. 4 (ETc, besoin net et brut).\nSimplification du jeu : pluie efficace prise à 0 (poche de sécheresse) ; la mise en eau initiale n'est pas comptée.[/i][/color]" % [riz.kc_mid, et0, etc_v, etc_v, perc, net, net, EFFICIENCE, brut, qfc, qfc, qfc * 5.0]


func _efficience() -> float:
	var e: float = 0.72 if adduction == "pvc" else EFFICIENCE
	return e - (0.0 if equipe.chef else 0.06)   # sans chef de chantier : malfaçons, fuites


## Débit que l'adduction peut amener à la parcelle (m3/s)
func _capacite_canal(pente: float) -> float:
	if source_eau == "pompe":
		return pompe_q / 1000.0
	if adduction == "pvc":
		return Hydraulique.debit_conduite(pvc_dn / 1000.0, L_CANAL, pente * L_CANAL + 0.5)
	return Hydraulique.debit_manning(KS_TERRE, canal_b, max(canal_h - REVANCHE, 0.0), FRUIT, pente)


# --- Pompage ---
func _hmt() -> float:
	var q: float = pompe_q / 1000.0
	var pdc: float = Hydraulique.perte_charge_lineaire(q, pvc_dn / 1000.0, L_CANAL, 0.00001) if adduction == "pvc" else 1.0
	return Hydraulique.hmt(4.0, pdc)

func _puissance_pompe() -> float:
	return Hydraulique.puissance_pompe_kw(pompe_q / 1000.0, _hmt(), couts.energie.rendement_pompe)

func _kwh_par_m3() -> float:
	return _puissance_pompe() / (pompe_q / 1000.0 * 3600.0)

func _ensoleillement(mois: int) -> float:   # kWh/m2/jour
	var r: Array = climat.get("rayonnement_mj", [])
	return float(r[mois]) / 3.6 if r.size() == 12 else 4.8

func _kwc() -> float:
	var e_jour: float = q_projet * 86400.0 * _kwh_par_m3()
	return part_solaire / 100.0 * e_jour / (4.8 * float(couts.energie.ratio_performance))

func _heures_pompage() -> float:
	if part_solaire < 99.0:
		return 24.0                      # le moteur thermique tourne quand il faut
	return clamp(8.0 + batterie_kwh / max(_puissance_pompe(), 0.01), 8.0, 24.0)


func _volume_barrage() -> float:
	return barrage_h * (Hydrologie.crete_knappen(barrage_h) + 2.25 * barrage_h) * 80.0

func _capacite_retenue() -> float:
	return Hydrologie.volume_retenue(150.0, 80.0, barrage_h)


## Achats de matériel et de matériaux (la main-d'œuvre est payée au temps passé, pendant le chantier)
func _cout_travaux() -> Dictionary:
	var t: Dictionary = couts.travaux
	var e: Dictionary = couts.energie
	var d := {"Ouvrage de prise (ciment, vannes)": float(t.ouvrage_prise)}
	if adduction == "pvc":
		d["Conduite PVC DN %d, %.0f m" % [pvc_dn, L_CANAL]] = L_CANAL * float(couts.pvc_m[str(pvc_dn)])
	if avec_drain:
		d["Buses et ouvrages du drain"] = L_DRAIN * 300.0
	if barrage_h > 0.0:
		d["Déversoir et vidange du barrage"] = float(couts.barrage_ouvrages)
	if source_eau == "pompe":
		if part_solaire > 1.0:
			d["Électropompe %.1f kW" % _puissance_pompe()] = float(e.electropompe_base) + _puissance_pompe() * float(e.electropompe_par_kw)
			d["Panneaux solaires %.1f kWc (posés)" % _kwc()] = _kwc() * 1000.0 * float(e.panneaux_fcfa_wc)
		if part_solaire < 99.0:
			d["Motopompe diesel"] = float(e.motopompe)
		if batterie_kwh > 0.0:
			d["Batterie lithium %.0f kWh" % batterie_kwh] = batterie_kwh * float(e.batterie_fcfa_kwh)
	return d


## Lots de travaux : volume (m3 ou jours de maçon), rôle, zone où l'on voit les ouvriers
func _creer_lots() -> Array:
	var pr := Terrain.PARCELLE
	var xr: float = Terrain.x_riviere(-330.0)
	var l: Array = []
	l.append({"id": "prise", "nom": "Ouvrage de prise", "total": 20.0, "role": "maçon", "pelle": false, "zone": Rect2(xr, -338, 14, 12)})
	if barrage_h > 0.0:
		l.append({"id": "barrage", "nom": "Barrage en terre (%.1f m)" % barrage_h, "total": _volume_barrage(), "role": "manœuvre", "pelle": true, "zone": Rect2(xr - 35, -385, 70, 16)})
	l.append({"id": "planage", "nom": "Planage des casiers", "total": _volume_planage(), "role": "manœuvre", "pelle": true, "zone": pr})
	l.append({"id": "diguettes", "nom": "Diguettes", "total": Hydraulique.volume_trapeze(0.3, diguette_h, 1.0, L_DIGUETTES), "role": "manœuvre", "pelle": false, "zone": pr})
	if adduction == "pvc":
		l.append({"id": "canal", "nom": "Tranchée et pose de la conduite", "total": L_CANAL * 0.45, "role": "manœuvre", "pelle": false, "zone": Rect2(xr + 5, -330, 35, 200)})
	else:
		l.append({"id": "canal", "nom": "Canal d'amenée", "total": Hydraulique.volume_trapeze(canal_b, canal_h, FRUIT, L_CANAL), "role": "manœuvre", "pelle": false, "zone": Rect2(xr + 5, -330, 35, 200)})
	if digue_h > 0.05:
		l.append({"id": "digue", "nom": "Digue de protection", "total": Hydraulique.volume_trapeze(1.0, digue_h, 2.0, L_DIGUE), "role": "manœuvre", "pelle": true, "zone": Rect2(pr.position.x - 16, pr.position.y, 12, pr.size.y)})
	if avec_drain:
		l.append({"id": "drain", "nom": "Drain collecteur", "total": L_DRAIN * 0.5, "role": "manœuvre", "pelle": false, "zone": Rect2(pr.position.x, pr.end.y + 4, pr.size.x, 10)})
	if source_eau == "pompe":
		l.append({"id": "energie", "nom": "Station de pompage" + (" et champ solaire" if part_solaire > 1.0 else ""), "total": 6.0 + _kwc() * 1.5, "role": "maçon", "pelle": false, "zone": Rect2(xr + 10, -322, 40, 26)})
	for x in l:
		x["fait"] = 0.0
	return l


func _volume_manoeuvres(liste: Array) -> float:
	var v := 0.0
	for x in liste:
		if x.role == "manœuvre":
			v += x.total
	return v


func _salaires_chantier_jour() -> float:
	var sm: Dictionary = couts.salaires_mensuels
	var n: int = int(equipe.manoeuvres) + int(equipe.macons)
	return (equipe.manoeuvres * sm.manoeuvre + equipe.macons * sm.macon + (sm.chef_chantier if equipe.chef else 0.0)) / 30.0 \
		+ (float(couts.pelle_jour) if equipe.pelle else 0.0) + (n * float(couts.energie.repas_jour) if repas else 0.0)


## Durée prévisionnelle du chantier (jours), sans pluie ni fatigue : volume ÷ (effectif × rendement)
func _duree_prevue() -> float:
	var l := _creer_lots()
	var pm: float = equipe.manoeuvres * float(couts.productivite.manoeuvre_m3_j) * (1.2 if equipe.chef else 1.0)
	var v_pelle := 0.0
	var v_main := 0.0
	var j_macon := 0.0
	for x in l:
		if x.role == "maçon": j_macon += x.total
		elif x.pelle and equipe.pelle: v_pelle += x.total
		else: v_main += x.total
	var j_terre: float = v_main / max(pm, 0.1) + (v_pelle / (float(couts.productivite.pelle_m3_j) + pm) if equipe.pelle else 0.0)
	return max(j_terre, j_macon / max(float(equipe.macons), 1.0))


func _ecran_conception() -> void:
	_vider()
	for id in ["manning", "drainage"]:
		_vu(id)
	titre.text = "4. Conception des ouvrages"
	var pente := _pente_connue()
	var q := _capacite_canal(pente)
	var etat := "[color=#8fd18f]suffisant[/color]" if q >= q_projet else "[color=#ff7b7b]insuffisant[/color]"
	if q > q_projet * 2.5:
		etat = "[color=#ffb347]très surdimensionné (argent gaspillé)[/color]"
	var src_pente := "mesurée" if fait.has("topo") else "[color=#ffb347]estimée à l'œil[/color]"
	_texte("[b]Débit de projet : %.1f L/s[/b] — ton système amène [b]%.1f L/s[/b] : %s" % [q_projet * 1000.0, q * 1000.0, etat])
	# --- Source d'eau ---
	_bouton("Alimentation : %s" % ("POMPAGE dans le marigot" if source_eau == "pompe" else "GRAVITAIRE (prise + pente naturelle)"), func():
		source_eau = "gravite" if source_eau == "pompe" else "pompe"
		_ecran_conception())
	if source_eau == "pompe":
		_vu("pompage")
		_curseur("Débit de la pompe : %.1f L/s" % pompe_q, 2.0, 40.0, 0.5, pompe_q, func(x): pompe_q = x; _ecran_conception())
		_texte("HMT = 4,0 m de relevage + pertes de charge = [b]%.1f m[/b]\nPuissance absorbée = ρ·g·Q·HMT ÷ rendement = [b]%.2f kW[/b]\nÉnergie : %.3f kWh par m³ pompé" % [_hmt(), _puissance_pompe(), _kwh_par_m3()])
		_curseur("Part de l'énergie fournie par le solaire : %.0f %%" % part_solaire, 0, 100, 10, part_solaire, func(x): part_solaire = x; _ecran_conception())
		if part_solaire > 1.0:
			_vu("solaire")
			_texte("Champ solaire nécessaire : [b]%.1f kWc[/b] (≈ %d panneaux de 550 Wc), soit %s\nHeures de pompage possibles par jour : [b]%.0f h[/b]%s" % [_kwc(), int(ceil(_kwc() * 1000.0 / 550.0)), _fcfa(_kwc() * 1000.0 * float(couts.energie.panneaux_fcfa_wc)), _heures_pompage(), "" if part_solaire < 99.0 else " (100 % solaire : au fil du soleil, sauf batterie)"])
			_curseur("Batterie : %.0f kWh (%s)" % [batterie_kwh, _fcfa(batterie_kwh * float(couts.energie.batterie_fcfa_kwh))], 0, 30, 1, batterie_kwh, func(x): batterie_kwh = x; _ecran_conception())
		if part_solaire < 99.0:
			_texte("Gasoil : %d FCFA/L, environ %.1f L par jour de pointe pour la part thermique." % [int(couts.energie.gasoil_fcfa_l), (1.0 - part_solaire / 100.0) * q_projet * 86400.0 * _kwh_par_m3() * float(couts.energie.conso_l_par_kwh)])
	# --- Transport ---
	_bouton("Transport de l'eau : %s" % ("CONDUITE PVC enterrée (peu de pertes)" if adduction == "pvc" else "CANAL EN TERRE (pertes par infiltration)"), func():
		adduction = "canal" if adduction == "pvc" else "pvc"
		_ecran_conception())
	if adduction == "pvc":
		_vu("conduite")
		_bouton("Diamètre : DN %d — %s le mètre" % [pvc_dn, _fcfa(float(couts.pvc_m[str(pvc_dn)]))], func():
			pvc_dn = int(_suivant([110, 160, 200, 250], pvc_dn))
			_ecran_conception())
		if source_eau != "pompe":
			_texte("Charge disponible : pente %s %.1f ‰ × %.0f m + 0,5 m. Le débit est celui qui consomme toute cette charge en pertes de charge (Darcy-Weisbach)." % [src_pente, pente * 1000.0, L_CANAL])
	elif source_eau != "pompe":
		var h_eau: float = max(canal_h - REVANCHE, 0.0)
		var v: float = q / max(Hydraulique.section_trapeze(canal_b, h_eau, FRUIT), 0.0001)
		_texte("Trapèze, fruit 1/1, Ks = 30, pente %s %.1f ‰, revanche %.0f cm. Vitesse : %.2f m/s%s" % [src_pente, pente * 1000.0, REVANCHE * 100.0, v, "  [color=#ffb347](> 0,8 m/s : érosion)[/color]" if v > 0.8 else ""])
	if adduction == "canal":
		_curseur("Largeur au plafond du canal : %.2f m" % canal_b, 0.2, 2.0, 0.05, canal_b, func(x): canal_b = x; _ecran_conception())
		_curseur("Profondeur totale du canal : %.2f m" % canal_h, 0.2, 1.0, 0.05, canal_h, func(x): canal_h = x; _ecran_conception())
	# --- Stockage ---
	_curseur("Petit barrage en terre sur le marigot : %s" % ("aucun" if barrage_h <= 0.0 else "%.1f m de haut" % barrage_h), 0.0, 5.0, 0.5, barrage_h, func(x): barrage_h = x; _ecran_conception())
	if barrage_h > 0.0:
		_vu("retenue")
		_texte("Largeur en crête (Knappen) : %.1f m · remblai : %.0f m³ · retenue : [b]%.0f m³[/b], soit %.0f jours de besoin de pointe." % [Hydrologie.crete_knappen(barrage_h), _volume_barrage(), _capacite_retenue(), _capacite_retenue() / max(q_projet * 86400.0, 1.0)])
	# --- Parcelle ---
	_curseur("Hauteur des diguettes : %.0f cm" % (diguette_h * 100.0), 0.10, 0.35, 0.05, diguette_h, func(x): diguette_h = x; _ecran_conception())
	var crue_txt := ("Pas de crue à craindre sur ce site." if VRAI.crue_10ans <= 0.0 else "Crue de référence : %.1f m (2 ans), %.1f m (10 ans)." % [VRAI.crue_2ans, VRAI.crue_10ans]) if fait.has("hydro") else "[color=#ffb347]Pas d'étude hydrologique : les anciens parlent d'environ %.1f m d'eau certaines années.[/color]" % CROYANCE.crue
	_texte(crue_txt)
	_curseur("Digue de protection côté marigot : %.1f m" % digue_h, 0.0, 1.5, 0.1, digue_h, func(x): digue_h = x; _ecran_conception())
	_bouton(("☑ " if avec_drain else "☐ ") + "Drain collecteur à l'aval (réseau de colature)", func():
		avec_drain = not avec_drain
		_ecran_conception())
	var total := 0.0
	var devis := "[b]Achats de matériel[/b]\n"
	var cd := _cout_travaux()
	for k in cd:
		devis += "%s : %s\n" % [k, _fcfa(cd[k])]
		total += cd[k]
	var l := _creer_lots()
	devis += "[b]Total matériel : %s[/b]\nTerrassements à faire : [b]%.0f m³[/b] (la main-d'œuvre se règle à l'étape suivante)." % [_fcfa(total), _volume_manoeuvres(l)]
	_texte(devis)
	if source_eau != "pompe" and adduction == "canal":
		_bouton("Voir le calcul de Manning-Strickler", func():
			var h_eau: float = max(canal_h - REVANCHE, 0.0)
			var sm: float = Hydraulique.section_trapeze(canal_b, h_eau, FRUIT)
			var pm: float = Hydraulique.perimetre_trapeze(canal_b, h_eau, FRUIT)
			_afficher_popup("[b][font_size=24]Capacité du canal[/font_size][/b]\n\nSection mouillée S = (b + m·h)·h = [b]%.3f m²[/b]\nPérimètre mouillé P = b + 2h√(1 + m²) = [b]%.3f m[/b]\nRayon hydraulique Rh = S ÷ P = [b]%.3f m[/b]\nQ = Ks · S · Rh^(2/3) · √I = [b]%.1f L/s[/b]\n\n[color=#1F4E79][i]Dans ton cours : L3 — Bases techniques, ch. 6 ; L2 — Hydraulique générale, ch. 5. Ks = 30 : valeur indicative.[/i][/color]" % [sm, pm, sm / max(pm, 0.001), q * 1000.0], [["Fermer", Callable()]]))
	_bouton("Passer au recrutement de l'équipe", func(): _aller(Etape.RECRUTEMENT))


# =====================================================================
#  ÉQUIPE ET CHANTIER
# =====================================================================

func _ecran_recrutement() -> void:
	_vider()
	for id in ["chantier", "contrats"]:
		_vu(id)
	titre.text = "5. Recruter l'équipe"
	var sm: Dictionary = couts.salaires_mensuels
	var village := Vector3(-320, Terrain.hauteur(-320, -40), -40)
	if cam_cible.distance_to(village) > 5.0 and etape == Etape.RECRUTEMENT:
		var tw := create_tween()
		tw.tween_property(self, "cam_cible", village, 1.2)
		tw.parallel().tween_property(avatar, "position", village + Vector3(14, 0, 10), 1.5)
	_texte("Tu es au village. Les [b]manœuvres[/b] se recrutent ici, avec l'accord du chef de village ; les [b]maçons[/b] et le [b]chef de chantier[/b] viennent de la ville ; la pelle mécanique se loue à la journée.\nLe chantier ouvre [b]%d jours[/b] avant la date de repiquage prévue (%s). S'il finit en retard, le repiquage glisse d'autant." % [FENETRE_CHANTIER, SEMIS[semis_idx].nom])
	_curseur("Manœuvres : %d — %s par mois chacun" % [equipe.manoeuvres, _fcfa(sm.manoeuvre)], 4, 20, 1, equipe.manoeuvres, func(x): equipe.manoeuvres = int(x); _ecran_recrutement())
	_curseur("Maçons : %d — %s par mois chacun" % [equipe.macons, _fcfa(sm.macon)], 1, 4, 1, equipe.macons, func(x): equipe.macons = int(x); _ecran_recrutement())
	_bouton(("☑ " if equipe.chef else "☐ ") + "Chef de chantier — %s par mois (rendement +20 %%, moins de malfaçons)" % _fcfa(sm.chef_chantier), func():
		equipe.chef = not equipe.chef; _ecran_recrutement())
	_bouton(("☑ " if equipe.pelle else "☐ ") + "Pelle mécanique — %s par jour (planage, digue, barrage)" % _fcfa(couts.pelle_jour), func():
		equipe.pelle = not equipe.pelle; _ecran_recrutement())
	_bouton(("☑ " if repas else "☐ ") + "Repas servis sur place — %s par personne et par jour (sinon ils rentrent manger au village)" % _fcfa(couts.energie.repas_jour), func():
		repas = not repas; _ecran_recrutement())
	_curseur("Riziculteurs pour la campagne : %d — %s par mois chacun (repère : 1 par hectare)" % [equipe.riziculteurs, _fcfa(sm.riziculteur)], 2, 8, 1, equipe.riziculteurs, func(x): equipe.riziculteurs = int(x); _ecran_recrutement())
	var d := _duree_prevue()
	var couleur := "#8fd18f" if d <= FENETRE_CHANTIER else "#ff7b7b"
	_texte("[b]Prévision[/b] (hors pluie et fatigue)\nDurée du chantier : [color=%s][b]%.0f jours[/b][/color] pour %d disponibles\nCoût journalier : %s → environ [b]%s[/b]\nDurée = volume ÷ (effectif × %.0f m³ par personne et par jour)\n[i]Salaires et rendements indicatifs, à vérifier (minimum légal en vigueur).[/i]" % [couleur, d, FENETRE_CHANTIER, _fcfa(_salaires_chantier_jour()), _fcfa(_salaires_chantier_jour() * d), float(couts.productivite.manoeuvre_m3_j)])
	_bouton("Signer les contrats et ouvrir le chantier", func(): _aller(Etape.TRAVAUX))


func _demarrer_travaux() -> void:
	var cd := _cout_travaux()
	for k in cd:
		_payer(k, cd[k], "travaux")
	lots = _creer_lots()
	chantier = {"jour": 0, "debut": (int(SEMIS[semis_idx].jour) - FENETRE_CHANTIER + 365) % 365, "fini": false, "salaires": 0.0}
	chantier_meteo = Meteo.new(climat, rng.randi())
	chantier_meteo.facteur_pluie = site.pluie_pct / 100.0
	var roles: Array = []
	for k in int(equipe.manoeuvres): roles.append("manœuvre")
	for k in int(equipe.macons): roles.append("maçon")
	monde.repas_fournis = repas
	var premier = _lot_courant("manœuvre")
	monde.zone = premier.zone if premier != null else lots[0].zone
	monde.anim_travail = "2H_Melee_Attack_Chop"
	monde.creer_equipe(roles)
	Terrain.casiers_niveles = false
	_construire_amenagement()
	_maj_progression()
	en_pause = false
	cumul_temps = 0.0
	pluie_forte = false
	cam_cible = Vector3(100, Terrain.hauteur(100, -100), -100)
	_vider()
	titre.text = "6. Chantier"
	_texte("")
	_barre_temps()
	_texte("")


func _lot_courant(role: String) -> Variant:
	for x in lots:
		if x.role == role and x.fait < x.total:
			return x
	return null


func _jour_de_travaux() -> void:
	chantier.jour += 1
	var w := chantier_meteo.jour(chantier.debut + chantier.jour)
	# Travail réellement fourni aujourd'hui par les agents (heures efficaces)
	var h_man: float = monde.relever_travail("manœuvre")
	var h_mac: float = monde.relever_travail("maçon")
	var cap: float = h_man / 8.0 * float(couts.productivite.manoeuvre_m3_j) * (1.2 if equipe.chef else 1.0)
	var cap_pelle: float = (float(couts.productivite.pelle_m3_j) * (0.3 if pluie_forte else 1.0)) if equipe.pelle else 0.0
	var cap_mac: float = h_mac / 8.0
	var planage_avant: bool = _lot_fini("planage")
	for x in lots:
		var reste: float = x.total - x.fait
		if reste <= 0.0:
			continue
		if x.role == "maçon":
			var f: float = min(reste, cap_mac)
			x.fait += f
			cap_mac -= f
		else:
			if x.pelle and cap_pelle > 0.0:
				var fp: float = min(reste, cap_pelle)
				x.fait += fp
				cap_pelle -= fp
				reste -= fp
			var fm: float = min(reste, cap)
			x.fait += fm
			cap -= fm
	var cout_j := _salaires_chantier_jour()
	chantier.salaires += cout_j
	tresorerie -= cout_j
	jours_ecoules += 1
	if _lot_fini("planage") and not planage_avant:
		Terrain.casiers_niveles = true
		_reconstruire_terrain()
		_construire_amenagement()
	_maj_progression()
	for m in monde.evenements_agents:
		info.text = m
	monde.evenements_agents.clear()
	pluie_forte = w.pluie > 10.0
	monde.il_pleut = w.pluie > 4.0
	monde.nebulosite = clamp(0.2 + w.pluie / 25.0, 0.0, 1.0)
	var lm = _lot_courant("manœuvre")
	if lm != null:
		monde.zone = lm.zone
	_maj_hud()
	if panneau.get_child_count() >= 5:
		var txt := "[b]Jour %d du chantier[/b] — repiquage prévu dans %d jours\nMétéo : %s\nÉquipe : %s\n" % [chantier.jour, FENETRE_CHANTIER - chantier.jour, "pluie forte, terrassements ralentis" if pluie_forte else ("pluie" if monde.il_pleut else "temps sec"), monde.resume_equipe()]
		(panneau.get_child(0) as RichTextLabel).text = txt
		var t2 := "[b]Avancement des ouvrages[/b]\n"
		for x in lots:
			var pc: float = x.fait / max(x.total, 0.001) * 100.0
			t2 += "%s %s : %d %%\n" % ["✔" if pc >= 99.9 else "▸", x.nom, int(pc)]
		t2 += "Dépensé en salaires, engins et repas : %s" % _fcfa(chantier.salaires)
		(panneau.get_child(panneau.get_child_count() - 1) as RichTextLabel).text = t2
	var tout := true
	for x in lots:
		if x.fait < x.total - 0.001:
			tout = false
	if tout:
		_fin_travaux()


func _lot_fini(id: String) -> bool:
	for x in lots:
		if x.id == id:
			return x.fait >= x.total - 0.001
	return true


## Les ouvrages apparaissent au fur et à mesure de l'avancement de leur lot
func _maj_progression() -> void:
	for x in lots:
		if not groupes.has(x.id):
			continue
		var g: Node3D = groupes[x.id]
		var n: int = g.get_child_count()
		var visibles: int = int(round(x.fait / max(x.total, 0.001) * n))
		for k in n:
			(g.get_child(k) as Node3D).visible = k < visibles


func _fin_travaux() -> void:
	chantier.fini = true
	retard_j = max(0, int(chantier.jour) - FENETRE_CHANTIER)
	charges.append(["Salaires, engins et repas du chantier (%d jours)" % chantier.jour, chantier.salaires, "travaux"])
	monde.ouvriers_actifs = false
	var msg := "Les ouvrages sont terminés en [b]%d jours[/b] (prévision : %.0f)." % [chantier.jour, _duree_prevue()]
	if retard_j > 0:
		msg += "\n\n[color=#b03030][b]Retard de %d jours[/b][/color] sur la date de repiquage : le riz sera repiqué plus tard dans la saison, avec les conséquences climatiques que cela implique." % retard_j
		evenements.append("retard")
	else:
		msg += "\n\nTu es dans les temps : il restait %d jours de marge." % (FENETRE_CHANTIER - int(chantier.jour))
	msg += "\n\nMain-d'œuvre, engins et repas : %s." % _fcfa(chantier.salaires)
	_afficher_popup("[b][font_size=24]Réception des travaux[/font_size][/b]\n\n" + msg, [["Lancer la campagne", func(): _aller(Etape.CAMPAGNE)]])


## Volume de terre à déplacer pour mettre à plat 20 casiers de 50 m x 50 m (ordre de grandeur)
func _volume_planage() -> float:
	return 20.0 * 2500.0 * 50.0 * (float(topo.pente_long) + float(topo.pente_trans)) / 12.0


func _charges_campagne_ha() -> float:
	var s := 0.0
	for k in couts.campagne_par_ha:
		s += couts.campagne_par_ha[k]
	return s


# =====================================================================
#  CAMPAGNE
# =====================================================================

func _demarrer_campagne() -> void:
	if eau_mm == null or not is_instance_valid(eau_mm):
		Terrain.casiers_niveles = true
		_reconstruire_terrain()
		_construire_amenagement()
	for id in groupes:
		for c in groupes[id].get_children():
			c.visible = true
	for id in ["bilan", "stress", "aue"]:
		_vu(id)
	_payer("Intrants de la campagne (5 ha) : semences, engrais, protection, battage", _charges_campagne_ha() * 5.0, "campagne")
	var meteo := Meteo.new(climat, rng.randi())
	var jour_semis: int = int(SEMIS[semis_idx].jour) + retard_j
	meteo.secheresse_debut = ((jour_semis + 52 - 1) % 365) + 1
	campagne = Campagne.new(riz, meteo)
	var sol: Dictionary = VRAI.sol
	meteo.facteur_pluie = site.pluie_pct / 100.0
	meteo.facteur_et0 = site.et0_pct / 100.0
	meteo.secheresse_duree = int(site.secheresse_j)
	campagne.surface_ha = 5.0
	campagne.facteur_fertilite = sol.fertilite
	campagne.ru_mm = Eau.reserve_utile(sol.cc_pct, sol.pfp_pct, sol.profondeur_cm * 10.0)
	campagne.percolation_mm_j = sol.percolation_mm_j
	campagne.hauteur_diguette_mm = diguette_h * 1000.0
	campagne.q_canal_m3_s = _capacite_canal(VRAI.pente_canal)
	campagne.efficience = _efficience()
	if barrage_h > 0.0:
		campagne.retenue_capacite_m3 = _capacite_retenue()
		campagne.retenue_surface_m2 = 12000.0
		# remplissage initial selon la pluie des deux mois précédant le repiquage
		var p2: float = (float(climat.pluie_mm[Meteo.mois_du_jour(jour_semis + 335)]) + float(climat.pluie_mm[Meteo.mois_du_jour(jour_semis + 305)])) * site.pluie_pct / 100.0
		campagne.retenue_m3 = campagne.retenue_capacite_m3 * clamp(p2 / 200.0, 0.1, 1.0)
	campagne.q_riviere_m3_s = VRAI.q_riviere
	campagne.drainage_mm_j = float(topo.drainage_naturel) + (float(topo.drain_capacite) if avec_drain else 0.0)
	campagne.hauteur_digue_m = digue_h
	campagne.jour_semis = jour_semis
	# Crue : tirage selon la saison (aucune en contre-saison sèche)
	var tirage := rng.randf()
	# Probabilité de crue : selon le site et selon la pluie du mois (aucune en saison sèche)
	var pluie_cycle: float = climat.pluie_mm[Meteo.mois_du_jour(jour_semis + 40)] * site.pluie_pct / 100.0
	var proba: float = float(topo.crue_proba) * clamp((pluie_cycle - 60.0) / 140.0, 0.0, 1.0)
	if VRAI.crue_10ans > 0.0 and tirage < proba:
		campagne.crue_jour = rng.randi_range(32, 46)
		campagne.crue_duree = int(topo.crue_duree)
		var t2 := rng.randf()
		campagne.crue_hauteur_m = VRAI.crue_2ans if t2 < 0.55 else (VRAI.crue_10ans if t2 < 0.9 else VRAI.crue_50ans)
	campagne.demarrer()
	var roles: Array = []
	for k in int(equipe.riziculteurs): roles.append("riziculteur")
	monde.zone = Terrain.PARCELLE
	monde.repas_fournis = repas
	monde.anim_travail = "PickUp"
	monde.creer_equipe(roles)
	salaires_campagne = 0.0
	carburant_fcfa = 0.0
	energie_kwh = {"solaire": 0.0, "thermique": 0.0}
	preleve_veille = 0.0
	heures_rizi = 0.0
	pluie_forte = false
	cam_cible = Vector3(140, Terrain.hauteur(140, 0), 0)
	en_pause = false
	cumul_temps = 0.0
	_ecran_campagne()


func _ecran_campagne() -> void:
	_vider()
	titre.text = "7. Campagne de riz"
	_texte("")
	_barre_temps()
	_texte("")


## Volume que la pompe peut fournir aujourd'hui (m3) et énergie solaire disponible (kWh)
func _pompage_du_jour(jour_annee: int, pluvieux: bool) -> Array:
	var e_sol: float = _kwc() * _ensoleillement(Meteo.mois_du_jour(jour_annee)) * float(couts.energie.ratio_performance) * (0.5 if pluvieux else 1.0)
	var v: float = pompe_q / 1000.0 * 3600.0 * _heures_pompage()
	if part_solaire >= 99.0:
		v = min(v, e_sol / max(_kwh_par_m3(), 0.0001))
	return [v, e_sol]


func _jour_de_campagne() -> void:
	var j := campagne.jour + 1
	# Litige foncier au jour 25
	if j == 25 and rng.randf() < _risque_litige():
		litige_jours_restants = 12
		_payer("Règlement du litige foncier", couts.litige, "campagne")
		evenements.append("litige")
		_afficher_popup("[b][font_size=24]Litige foncier[/font_size][/b]\n\nUn membre de la famille détentrice conteste ton droit d'exploiter la parcelle et fait fermer ta prise d'eau. Il faut 12 jours de médiation chez le chef de village et %s de frais pour reprendre.\n\nRisque de litige au départ : %d %%." % [_fcfa(couts.litige), int(_risque_litige() * 100.0)], [["Continuer", Callable()]])
	var q_normal := _capacite_canal(VRAI.pente_canal) + (0.008 if motopompe else 0.0)
	var pomp: Array = [0.0, 0.0]
	if source_eau == "pompe":
		pomp = _pompage_du_jour(campagne.jour_semis + j - 1, monde.il_pleut)
		q_normal = pomp[0] / 86400.0 + (0.008 if motopompe else 0.0)
	if litige_jours_restants > 0:
		campagne.q_canal_m3_s = 0.0
		litige_jours_restants -= 1
	else:
		campagne.q_canal_m3_s = q_normal
	# Début de la poche de sécheresse : décision du joueur si l'eau manque
	if j == 52 and not motopompe:
		var ja := campagne.jour_semis + j - 1
		var besoin: float = Eau.etc(climat.et0_mm_j[Meteo.mois_du_jour(ja)], riz.kc_mid) + campagne.percolation_mm_j
		if campagne.apport_max_mm(ja) < besoin:
			evenements.append("penurie")
			_afficher_popup("[b][font_size=24]Poche de sécheresse[/font_size][/b]\n\nPlus de pluie depuis plusieurs jours, et ton réseau n'apporte que [b]%.1f mm/j[/b] pour un besoin de [b]%.1f mm/j[/b].\n\nQue fais-tu ?" % [campagne.apport_max_mm(ja), besoin],
				[["Louer une motopompe (%s)" % _fcfa(150000.0), func():
					motopompe = true
					_payer("Location d'une motopompe", 150000.0, "campagne")],
				["Organiser un tour d'eau et attendre", Callable()]])
	var l := campagne.jour_suivant()
	if l.is_empty():
		return
	# Énergie de pompage du jour : le solaire d'abord, le gasoil pour le reste
	if source_eau == "pompe":
		var e: float = (campagne.tot.preleve_m3 - preleve_veille) * _kwh_par_m3()
		var e_s: float = min(e, pomp[1])
		energie_kwh.solaire += e_s
		energie_kwh.thermique += e - e_s
		var cout_c: float = (e - e_s) * float(couts.energie.conso_l_par_kwh) * float(couts.energie.gasoil_fcfa_l)
		carburant_fcfa += cout_c
		tresorerie -= cout_c
	preleve_veille = campagne.tot.preleve_m3
	# Riziculteurs : salaires au jour le jour, heures réellement travaillées
	var sal_j: float = equipe.riziculteurs * float(couts.salaires_mensuels.riziculteur) / 30.0 + (equipe.riziculteurs * float(couts.energie.repas_jour) if repas else 0.0)
	salaires_campagne += sal_j
	tresorerie -= sal_j
	heures_rizi += monde.relever_travail("riziculteur")
	monde.mode_recolte = campagne.jour > campagne.duree() - 10
	pluie_forte = l.pluie > 10.0
	for m in monde.evenements_agents:
		info.text = m
	monde.evenements_agents.clear()
	if campagne.crue_jour == campagne.jour:
		evenements.append("crue")
		var protege: bool = digue_h >= campagne.crue_hauteur_m
		_afficher_popup("[b][font_size=24]Crue du marigot[/font_size][/b]\n\nL'eau monte de [b]%.1f m[/b] au droit de ta parcelle pendant %d jours.\n\n%s" % [campagne.crue_hauteur_m, campagne.crue_duree, "Ta digue de %.1f m tient : les casiers sont protégés." % digue_h if protege else "Ta digue (%.1f m) est trop basse : les casiers sont submergés." % digue_h], [["Continuer", Callable()]])
	# Affichage 3D
	var d := float(campagne.duree())
	var croissance: float = clamp(campagne.jour / (d * 0.6), 0.0, 1.0) * (0.55 + 0.45 * Eau.rendement_relatif(campagne.tot.etr, campagne.tot.etm, riz.ky))
	var maturite: float = clamp((campagne.jour - d * 0.75) / (d * 0.25), 0.0, 1.0)
	_maj_parcelle(l.lame, croissance, maturite)
	var en_crue: bool = campagne.crue_jour > 0 and campagne.jour >= campagne.crue_jour and campagne.jour < campagne.crue_jour + campagne.crue_duree
	nappe_crue.visible = en_crue
	if en_crue:
		var hc: float = campagne.crue_hauteur_m
		nappe_crue.position = Vector3(40 if l.submerge else -120, Terrain.hauteur(140, 0) + (hc * 0.8 if l.submerge else -0.2), 0)
		(nappe_crue.mesh as PlaneMesh).size = Vector2(620 if l.submerge else 300, Terrain.TAILLE)
	monde.il_pleut = l.pluie > 4.0
	monde.nebulosite = clamp(0.2 + l.pluie / 25.0, 0.0, 1.0)
	var vents: Array = climat.get("vent_m_s", [])
	monde.vent = clamp((float(vents[Meteo.mois_du_jour(campagne.jour_semis + campagne.jour)]) if vents.size() == 12 else 2.0) / 2.0 + (0.8 if monde.il_pleut else 0.0), 0.3, 2.5)
	riz_mat.set_shader_parameter("vent", monde.vent)
	jours_ecoules += 1
	_maj_hud()
	if panneau.get_child_count() >= 5:
		var etat := "[color=#8fd18f]confort hydrique[/color]" if l.ks > 0.99 else "[color=#ff7b7b]STRESS HYDRIQUE (Ks = %.2f)[/color]" % l.ks
		if l.submerge:
			etat = "[color=#ff7b7b]CASIERS SUBMERGÉS PAR LA CRUE[/color]"
		(panneau.get_child(0) as RichTextLabel).text = "[b]Jour %d / %d[/b] — stade : %s\nAux champs : %s\nÉquipe : %s\nPluie : %.0f mm · ET0 : %.1f mm · Kc : %.2f\nIrrigation : %.1f mm · Lame d'eau : [b]%.0f mm[/b]\nÉtat : %s" % [campagne.jour, campagne.duree(), _stade(campagne.jour), _travail_du_jour(campagne.jour), monde.resume_equipe(), l.pluie, l.et0, l.kc, l.irrigation, l.lame, etat]
		(panneau.get_child(panneau.get_child_count() - 1) as RichTextLabel).text = "[b]Bilan d'eau cumulé (mm)[/b]\nPluie %.0f + irrigation %.0f\n= ETr %.0f + percolation %.0f + drainage %.0f + débordement %.0f + stock\nJours de stress : %d · de submersion : %d · de débordement : %d\nCapacité du canal : %.1f L/s%s" % [campagne.tot.pluie, campagne.tot.irrigation, campagne.tot.etr, campagne.tot.percolation, campagne.tot.drainage, campagne.tot.debordement, campagne.jours_stress, campagne.jours_submersion, campagne.jours_debordement, campagne.q_canal_m3_s * 1000.0, "  (prise fermée : litige)" if litige_jours_restants > 0 else ""] + ("\nRetenue : %.0f m³ sur %.0f" % [campagne.retenue_m3, campagne.retenue_capacite_m3] if barrage_h > 0.0 else "") + ("\nÉnergie de pompage : %.0f kWh solaires, %.0f kWh au gasoil (%s)" % [energie_kwh.solaire, energie_kwh.thermique, _fcfa(carburant_fcfa)] if source_eau == "pompe" else "")
	if campagne.termine:
		_aller(Etape.BILAN)


func _travail_du_jour(j: int) -> String:
	var d: Array = riz.durees_stades
	if j <= 5: return "repiquage"
	if j <= d[0] + d[1]: return "désherbage et surveillance de la lame d'eau"
	if j <= d[0] + d[1] + d[2]: return "tours d'eau, surveillance des ravageurs"
	if j <= campagne.duree() - 10: return "gardiennage contre les oiseaux"
	return "assec puis récolte"


func _stade(j: int) -> String:
	var d: Array = riz.durees_stades
	if j <= d[0]: return "initial (reprise)"
	if j <= d[0] + d[1]: return "développement (tallage)"
	if j <= d[0] + d[1] + d[2]: return "mi-saison (floraison)"
	return "fin de saison (maturation)"


# =====================================================================
#  BILAN ET DÉBRIEFING
# =====================================================================

func _ecran_bilan() -> void:
	_vider()
	for id in ["ky", "van"]:
		_vu(id)
	titre.text = "8. Bilan de campagne"
	# Main-d'œuvre de campagne : le manque d'heures de travail (désherbage, surveillance) pèse sur le rendement
	var ratio_mo: float = clamp(heures_rizi / (5.0 * 5.0 * campagne.duree()), 0.0, 1.0)
	campagne.facteur_fertilite = float(VRAI.sol.fertilite) * (0.6 + 0.4 * ratio_mo)
	charges.append(["Salaires et repas des riziculteurs", salaires_campagne, "campagne"])
	if carburant_fcfa > 0.0:
		charges.append(["Gasoil de pompage", carburant_fcfa, "campagne"])
	monde.ouvriers_actifs = false
	var r := campagne.resultat()
	var recettes: float = r.production_t * 1000.0 * riz.prix_fcfa_kg
	var redevance: float = campagne.tot.preleve_m3 * couts.eau_redevance_m3
	_payer("Redevance eau (%.0f m³)" % campagne.tot.preleve_m3, redevance, "campagne")
	var invest := 0.0
	var ch_camp := 0.0
	for c in charges:
		if c[2] == "apport":
			continue
		if c[2] == "campagne":
			ch_camp += c[1]
		else:
			invest += c[1]
	var interets := 0.0
	if tresorerie < 0.0 and not budget_illimite:
		interets = -tresorerie * 0.12
		_payer("Intérêts du prêt de campagne (12 %)", interets, "campagne")
		ch_camp += interets
	tresorerie += recettes
	charges.append(["Vente du paddy (%.1f t)" % r.production_t, -recettes, "recette"])
	_maj_hud()
	var marge: float = recettes - ch_camp
	var flux: Array = [-invest]
	for i in 5:
		flux.append(2.0 * marge)
	var van: float = Economie.van(flux, 0.10)
	var tri: float = Economie.tri(flux)
	var delai: float = Economie.delai_recuperation(flux)
	# Notes sur 20 par critère
	var n_dem := 0
	for d in DEMARCHES:
		if fait.has(d.id): n_dem += 1
	var n_et := 0
	for e in ETUDES:
		if fait.has(e.id): n_et += 1
	var q_vrai_besoin: float = Eau.debit_equipement(Eau.debit_fictif_continu(_besoin_brut_pointe(campagne.percolation_mm_j)), 5.0)
	var ratio: float = _capacite_canal(VRAI.pente_canal) / q_vrai_besoin
	var note_diag := 20.0 * n_et / 3.0
	var note_calc := (10.0 if quiz_juste else 0.0) + (10.0 if ratio >= 1.0 and ratio <= 1.8 else (5.0 if ratio >= 0.8 and ratio <= 2.5 else 0.0))
	var note_fonc := 20.0 * n_dem / 5.0
	var note_rent: float = clamp(marge / 2500000.0 * 20.0, 0.0, 20.0)
	var note_dur: float = clamp((8.0 if avec_drain else 0.0) + (6.0 if campagne.jours_debordement == 0 else 0.0) + (6.0 if campagne.jours_submersion == 0 else 0.0), 0.0, 20.0)
	var total := (note_diag + note_calc + note_fonc + note_rent + note_dur) / 5.0
	_texte("[b]Rendement : %.2f t/ha[/b] (potentiel %.1f) — production %.1f t de paddy\nRecettes : %s\nCharges de campagne : %s\n[b]Marge de la campagne : %s[/b]\nInvestissement (foncier, études, travaux) : %s\n\n[b]Sur 5 ans à 2 campagnes par an[/b] (taux 10 %%)\nVAN : %s · TRI : %s · Récupération : %s\nPatrimoine en fin de campagne (trésorerie + ouvrages réalisés) : [b]%s[/b]\n\nEau prélevée : %.0f m³ — productivité : %.2f kg de paddy par m³\nÉcart de fermeture du bilan d'eau : %.3f mm" % [r.rendement_t_ha, riz.rendement_max_t_ha, r.production_t, _fcfa(recettes), _fcfa(ch_camp), _fcfa(marge), _fcfa(invest), _fcfa(van), ("%.0f %%" % (tri * 100.0)) if not is_nan(tri) else "aucun", ("%.1f ans" % delai) if delai >= 0.0 else "jamais", _fcfa(tresorerie + _valeur_ouvrages()), campagne.tot.preleve_m3, r.productivite_eau_kg_m3, campagne.erreur_bilan()])
	_texte("[b]Évaluation : %.1f / 20[/b]\nDiagnostic (études) : %.0f · Calculs : %.0f · Sécurité foncière : %.0f · Rentabilité : %.0f · Durabilité : %.0f" % [total, note_diag, note_calc, note_fonc, note_rent, note_dur])
	var extra := ""
	if ratio_mo < 0.9:
		extra += "\nMain-d'œuvre : seulement %d %% des heures de travail nécessaires ont été fournies." % int(ratio_mo * 100.0)
	if source_eau == "pompe":
		extra += "\nPompage : %.0f kWh solaires et %.0f kWh au gasoil (%s)." % [energie_kwh.solaire, energie_kwh.thermique, _fcfa(carburant_fcfa)]
	if retard_j > 0:
		extra += "\nRepiquage retardé de %d jours par le chantier." % retard_j
	if extra != "":
		_texte("[b]Équipe, énergie, délais[/b]" + extra)
	var deb := _debriefing(r, ratio)
	_bouton("Lire le débriefing du professeur", func(): _afficher_popup(deb, [["Fermer", Callable()]]))
	_bouton("Rejouer avec d'autres choix", _nouvelle_partie)
	_sauvegarder(r, total)


func _q_min_cycle() -> float:
	var q := 1.0e9
	for j in range(campagne.jour_semis, campagne.jour_semis + campagne.duree(), 15):
		q = min(q, VRAI.q_riviere[Meteo.mois_du_jour(j)])
	return q

func _riviere_insuffisante() -> bool:
	var besoin: float = Eau.debit_equipement(Eau.debit_fictif_continu(_besoin_brut_pointe(campagne.percolation_mm_j)), 5.0)
	return _q_min_cycle() < besoin


func _valeur_ouvrages() -> float:
	var v := 0.0
	for c in charges:
		if c[2] == "travaux":
			v += c[1]
	return v


func _debriefing(r: Dictionary, ratio: float) -> String:
	var bb := "[b][font_size=26]Débriefing[/font_size][/b]\n\n"
	var n := 0
	if campagne.jours_stress > 5:
		n += 1
		var causes: Array = []
		if ratio < 1.0: causes.append("ton canal ne passe que %.0f %% du débit nécessaire" % (ratio * 100.0))
		if _riviere_insuffisante(): causes.append("à cette saison le marigot ne fournit pas le débit nécessaire (minimum %.1f L/s sur le cycle)" % (_q_min_cycle() * 1000.0))
		if evenements.has("litige"): causes.append("ta prise est restée fermée 12 jours pendant le litige")
		if causes.is_empty(): causes.append("la poche de sécheresse a dépassé la capacité du réseau")
		bb += "[b]%d. Stress hydrique : %d jours, rendement réduit à %d %% sur ce critère[/b]\n[u]Ce qui s'est passé[/u] : le riz a manqué d'eau.\n[u]Pourquoi[/u] : %s.\n[u]Ce que dit ton cours[/u] : besoin brut = besoin net ÷ efficience ; le Qfc sert à dimensionner les canaux (L3 Bases techniques, ch. 1 et 4). L'étude hydrologique vérifie que la ressource couvre les besoins durant toute la campagne (ch. 5.1.3).\n[u]Ce qu'il fallait faire[/u] : dimensionner le canal sur le besoin de pointe, et choisir une date de repiquage compatible avec le débit du marigot.\n\n" % [n, campagne.jours_stress, int(r.rel_eau * 100.0), ", ".join(causes)]
	if campagne.jours_submersion > 0:
		n += 1
		bb += "[b]%d. Submersion par la crue : %d jours[/b]\n[u]Ce qui s'est passé[/u] : une crue de %.1f m a dépassé ta digue de %.1f m.\n[u]Pourquoi[/u] : %s.\n[u]Ce que dit ton cours[/u] : une crue décennale a 10 %% de chances de se produire chaque année ; le choix de la période de retour est un compromis entre coût et risque (L3 Hydrologie appliquée, 3e partie).\n[u]Ce qu'il fallait faire[/u] : caler la digue sur la crue de projet choisie, plus une revanche.\n\n" % [n, campagne.jours_submersion, campagne.crue_hauteur_m, digue_h, "tu n'avais pas d'étude hydrologique" if not fait.has("hydro") else ("ta digue est plus basse que la crue de période de retour 2 ans annoncée par l'étude (%.1f m)" % VRAI.crue_2ans if digue_h < VRAI.crue_2ans else "tu as accepté le risque d'une crue plus rare que ta crue de projet")]
	if campagne.jours_debordement > 0:
		n += 1
		bb += "[b]%d. Débordement des diguettes : %d jours[/b]\n[u]Ce qui s'est passé[/u] : les fortes pluies ont fait passer l'eau par-dessus les diguettes.\n[u]Pourquoi[/u] : %s.\n[u]Ce que dit ton cours[/u] : l'irrigation doit indissociablement s'accompagner d'un réseau de colature (L3 Bases techniques, ch. 2).\n[u]Ce qu'il fallait faire[/u] : prévoir un drain collecteur et des diguettes d'au moins 20 cm.\n\n" % [n, campagne.jours_debordement, "pas de drain pour évacuer l'excès" if not avec_drain else "diguettes trop basses"]
	if evenements.has("litige"):
		n += 1
		bb += "[b]%d. Litige foncier[/b]\n[u]Ce qui s'est passé[/u] : ton droit d'usage a été contesté en pleine campagne.\n[u]Pourquoi[/u] : démarches foncières incomplètes au départ.\n[u]Ce que disent les textes[/u] (approfondissement, à vérifier) : les droits coutumiers se constatent par le certificat foncier ; un accord écrit, constaté et borné limite les contestations.\n[u]Ce qu'il fallait faire[/u] : identifier tous les détenteurs, passer par le comité villageois, borner, écrire le bail.\n\n" % n
	if ratio > 2.5:
		n += 1
		bb += "[b]%d. Canal surdimensionné[/b]\n[u]Ce qui s'est passé[/u] : ton canal passe %.1f fois le débit nécessaire.\n[u]Pourquoi[/u] : %s.\n[u]Ce qu'il fallait faire[/u] : viser le débit de projet avec une marge raisonnable ; chaque m³ de terrassement coûte.\n\n" % [n, ratio, "pente du tracé sous-estimée faute de levé topographique" if not fait.has("topo") else "dimensions trop généreuses"]
	if not fait.has("sol"):
		n += 1
		bb += "[b]%d. Sol non étudié[/b]\n[u]Ce qui s'est passé[/u] : tu as calculé avec une percolation de %.0f mm/j (sol jugé limoneux à l'œil) alors que la vraie valeur est %.0f mm/j (sol %s, structure %s).\n[u]Ce que dit ton cours[/u] : la texture commande l'infiltration et la rétention (L3 Bases techniques, ch. 3 ; L2 Pédogenèse).\n[u]Ce qu'il fallait faire[/u] : une étude pédologique à %s évite de surdimensionner tout le réseau.\n\n" % [n, CROYANCE.sol.percolation_mm_j, VRAI.sol.percolation_mm_j, VRAI.sol.nom.to_lower(), VRAI.sol.structure_nom, _fcfa(couts.etudes.pedologie)]
	if n == 0:
		bb += "Rien à redire : diagnostic complet, calculs justes, ouvrages bien dimensionnés. Essaie maintenant la contre-saison sèche, ou supprime une étude pour voir ce qu'elle t'apportait."
	return bb


func _sauvegarder(r: Dictionary, note: float) -> void:
	var f := FileAccess.open("user://derniere_partie.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"fait": fait, "semis": semis_idx, "canal_b": canal_b, "canal_h": canal_h,
			"diguette_h": diguette_h, "drain": avec_drain, "digue_h": digue_h, "resultat": r, "note": note,
			"charges": charges, "evenements": evenements}, "  "))


# =====================================================================
#  PILOTE AUTOMATIQUE (tests et captures d'écran)
# =====================================================================

func _capture(nom: String) -> void:
	var dossier := OS.get_environment("AGRISIM_CAPTURES")
	if dossier == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dossier + "/" + nom + ".png")


func _boutons() -> Array:
	var b: Array = []
	for c in panneau.get_children():
		if c is Button and not c.is_queued_for_deletion():
			b.append(c)
	return b


## Parcours par de vrais clics sur les boutons (vérifie les branchements de l'interface)
func _pilote_clics() -> void:
	await get_tree().create_timer(0.5).timeout
	_boutons()[_boutons().size() - 1].pressed.emit()
	while _boutons().size() > 1:
		_boutons()[0].pressed.emit()
		await get_tree().process_frame
	_boutons()[0].pressed.emit()
	while _boutons().size() > 1:
		_boutons()[0].pressed.emit()
		await get_tree().process_frame
	await _capture("clics_1_etudes")
	_boutons()[0].pressed.emit()
	await get_tree().process_frame
	_boutons()[5].pressed.emit()
	await get_tree().create_timer(0.2).timeout
	await _capture("clics_2_calcul_besoins")
	popup_boutons.get_child(popup_boutons.get_child_count() - 1).pressed.emit()
	await get_tree().process_frame
	var bs := _boutons()
	bs[bs.size() - 2].pressed.emit()
	await get_tree().create_timer(0.2).timeout
	await _capture("clics_3_manning")
	popup_boutons.get_child(0).pressed.emit()
	_boutons()[_boutons().size() - 1].pressed.emit()
	await get_tree().process_frame
	_boutons()[_boutons().size() - 1].pressed.emit()
	await get_tree().process_frame
	vitesse = 60.0
	while etape != Etape.BILAN:
		if popup.visible:
			popup_boutons.get_child(0).pressed.emit()
		await get_tree().process_frame
	await get_tree().process_frame
	_boutons()[0].pressed.emit()
	await get_tree().create_timer(0.2).timeout
	await _capture("clics_4_debriefing")
	popup_boutons.get_child(0).pressed.emit()
	_ouvrir_codex()
	await get_tree().create_timer(0.2).timeout
	await _capture("clics_5_codex")
	print("CLICS : ", campagne.resultat(), " evenements=", evenements, " tresorerie=", tresorerie)
	get_tree().quit()


func _pilote_auto(mode: String) -> void:
	if mode == "clics":
		_pilote_clics()
		return
	var bon := mode == "bon" or mode == "reel"
	if mode == "reel":
		site.ville = OS.get_environment("AGRISIM_VILLE") if OS.get_environment("AGRISIM_VILLE") != "" else "man"
		reel.telecharger(site.ville, villes[site.ville])
		var res: Array = await reel.termine
		print("RESEAU ", res, " cache=", not DonneesReelles.lire_cache(site.ville).is_empty())
		if not DonneesReelles.lire_cache(site.ville).is_empty():
			site.mode = "reel"
		_generer_site()
		_ecran_intro()
		print("SITE ", topo.nom, " | ", topo.description, " | pluie an=", climat.pluie_mm, " et0=", climat.et0_mm_j)
	await get_tree().create_timer(0.5).timeout
	await _capture(mode + "_1_arrivee")
	_aller(Etape.FONCIER)
	if bon:
		for d in DEMARCHES:
			_payer("Foncier : " + d.id, couts.foncier[d.cout], "foncier", d.jours)
			fait[d.id] = true
		_poser_bornes()
		_ecran_foncier()
	_payer("Loyer annuel 5 ha", couts.foncier.loyer_annuel_ha * 5.0, "campagne")
	_aller(Etape.ETUDES)
	if bon:
		for e in ETUDES:
			_payer("Étude : " + e.id, couts.etudes[e.cout], "etudes", e.jours)
			fait[e.id] = true
		terrain_mat.set_shader_parameter("contours", 1.0)
		_ecran_etudes()
	cam_dist = 300.0
	await get_tree().create_timer(0.3).timeout
	await _capture(mode + "_2_etudes")
	semis_idx = 0 if bon else 3
	if OS.get_environment("AGRISIM_SEMIS") != "":
		semis_idx = int(OS.get_environment("AGRISIM_SEMIS"))
	_aller(Etape.BESOINS)
	var perc: float = _sol_connu().percolation_mm_j
	q_projet = Eau.debit_equipement(Eau.debit_fictif_continu(_besoin_brut_pointe(perc)), 5.0)
	quiz_juste = bon
	if bon:
		# L'ingénieur soigneux : plus petit canal qui passe 1,2 fois le débit de projet, digue calée sur la crue décennale
		diguette_h = 0.20; avec_drain = true
		digue_h = ceil((VRAI.crue_10ans + 0.1) * 10.0) / 10.0 if VRAI.crue_10ans > 0.0 else 0.0
		var trouve := false
		for hh in [0.25, 0.3, 0.35, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]:
			for bb in [0.2, 0.3, 0.4, 0.6, 0.8, 1.0, 1.5, 2.0]:
				canal_b = bb; canal_h = hh
				if not trouve and _capacite_canal(VRAI.pente_canal) >= 1.2 * q_projet:
					trouve = true
					break
			if trouve:
				break
	else:
		canal_b = 0.2; canal_h = 0.20; diguette_h = 0.10; avec_drain = false; digue_h = 0.0
	_aller(Etape.CONCEPTION)
	await get_tree().create_timer(0.3).timeout
	await _capture(mode + "_3_conception")
	var opts := OS.get_environment("AGRISIM_OPTIONS")
	if "pompe" in opts:
		source_eau = "pompe"; pompe_q = ceil(q_projet * 1000.0 * 1.2); part_solaire = 60.0; batterie_kwh = 5.0
	if "pvc" in opts:
		adduction = "pvc"
	if "barrage" in opts:
		barrage_h = 3.0
	equipe.chef = bon
	equipe.pelle = bon
	equipe.manoeuvres = 14 if bon else 5
	_aller(Etape.RECRUTEMENT)
	await get_tree().create_timer(0.3).timeout
	await _capture(mode + "_3b_equipe")
	vitesse = 0.5
	_aller(Etape.TRAVAUX)
	cam_dist = 300.0
	var vu := false
	while etape == Etape.TRAVAUX:
		if chantier.jour >= 6 and not vu:
			vu = true
			cam_cible = Vector3(140, Terrain.hauteur(140, 0), 0)
			await get_tree().create_timer(0.4).timeout
			await _capture(mode + "_3c_chantier")
			vitesse = 60.0
		if popup.visible:
			print("CHANTIER ", chantier.jour, " jours, salaires=", chantier.salaires, " retard=", retard_j)
			popup_boutons.get_child(0).pressed.emit()
		await get_tree().process_frame
	vitesse = 60.0
	cam_dist = 260.0
	cam_pitch = 0.6
	var pris := false
	while not campagne.termine:
		if popup.visible:
			popup.visible = false
		if campagne.jour >= 70 and not pris:
			pris = true
			await _capture(mode + "_4_campagne")
			# Gros plans pour contrôler les modèles 3D
			var v_avant := vitesse
			vitesse = 0.02
			monde.heure_agents = 9.0
			for ag in monde.agents:
				ag.etat = "travaille"
				ag.fatigue = 20.0
				ag.faim = 20.0
			await get_tree().create_timer(3.0).timeout
			var d_avant := cam_dist
			var c_avant := cam_cible
			var p_avant := cam_pitch
			cam_cible = (monde.ouvriers[0] as Node3D).position + Vector3(0, 3, 0)
			cam_dist = 42.0
			cam_pitch = 0.35
			await get_tree().create_timer(1.0).timeout
			await _capture(mode + "_4c_zoom_ouvriers")
			cam_cible = Vector3(-315, Terrain.hauteur(-315, -30) + 4.0, -30)
			cam_dist = 90.0
			await get_tree().create_timer(0.5).timeout
			await _capture(mode + "_4d_zoom_village")
			cam_cible = monde.point_repos + Vector3(0, 3, 0)
			cam_dist = 55.0
			await get_tree().create_timer(0.5).timeout
			await _capture(mode + "_4e_zoom_campement")
			cam_dist = d_avant; cam_cible = c_avant; cam_pitch = p_avant
			vitesse = v_avant
			_fiche_ouvrier(1)
			await get_tree().create_timer(0.2).timeout
			await _capture(mode + "_4b_ouvrier")
			popup.visible = false
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	await _capture(mode + "_5_bilan")
	popup_texte.text = _debriefing(campagne.resultat(), 1.0)
	print("AUTO ", mode, " : ", campagne.resultat(), " tresorerie=", tresorerie, " evenements=", evenements, " bilan=", campagne.erreur_bilan())
	get_tree().quit()
