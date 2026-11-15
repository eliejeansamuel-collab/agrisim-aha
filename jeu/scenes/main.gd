extends Node3D
## Tranche verticale : aménager un bas-fond rizicole de 5 ha près de San-Pédro.
## Foncier -> études -> besoins en eau -> conception -> campagne -> bilan et débriefing.
## Toute la scène est construite par code ; les règles de calcul sont dans res://moteur.

enum Etape { INTRO, FONCIER, ETUDES, BESOINS, CONCEPTION, CAMPAGNE, BILAN }

# Réalité du terrain, inconnue du joueur tant qu'il n'a pas fait les études
const VRAI := {
	"sol": "argileux", "pente": 0.004, "pente_canal": 0.001,
	"q_riviere": [0.006, 0.004, 0.006, 0.03, 0.10, 0.30, 0.20, 0.06, 0.08, 0.12, 0.08, 0.02],
	"crue_2ans": 0.5, "crue_10ans": 0.9, "crue_50ans": 1.2,
}
# Ce que le joueur « croit » sans étude (estimation à l'œil)
const CROYANCE := {"sol": "limoneux", "pente_canal": 0.0003, "crue": 0.5}
const KS_TERRE := 30.0
const FRUIT := 1.0
const REVANCHE := 0.15
const EFFICIENCE := 0.6
const L_CANAL := 350.0
const L_DIGUETTES := 2450.0
const L_DIGUE := 250.0
const L_DRAIN := 300.0
const SEMIS := [
	{"nom": "1er mai — grande saison des pluies", "jour": 121},
	{"nom": "1er septembre — petite saison des pluies", "jour": 244},
	{"nom": "1er décembre — contre-saison sèche", "jour": 335},
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
var vitesse := 6.0            # jours simulés par seconde
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
var riz_mat: StandardMaterial3D
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
	climat = _json("res://donnees/climat.json").san_pedro
	riz = _json("res://donnees/cultures.json").riz_irrigue
	sols = _json("res://donnees/sols.json")
	couts = _json("res://donnees/couts.json")
	notions = JSON.parse_string(FileAccess.get_file_as_string("res://donnees/notions.json"))
	var graine := OS.get_environment("AGRISIM_GRAINE")
	if graine != "":
		rng.seed = int(graine)
	else:
		rng.randomize()
	_creer_monde()
	_creer_interface()
	_nouvelle_partie()
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
	cam = Camera3D.new()
	cam.far = 3000.0
	cam.fov = 50.0
	add_child(cam)

	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = load("res://scenes/terrain.gdshader")
	terrain_mi = MeshInstance3D.new()
	terrain_mi.material_override = terrain_mat
	add_child(terrain_mi)
	_reconstruire_terrain()
	_creer_riviere()
	_creer_decor()
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
	add_child(mi)


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
	while positions.size() < 700:
		var x := r.randf_range(-395, 395)
		var z := r.randf_range(-395, 395)
		if abs(x - Terrain.x_riviere(z)) > Terrain.DEMI_FOND + 15.0:
			positions.append(Vector3(x, Terrain.hauteur(x, z) + 6.0, z))
	# Quelques palmiers et arbres isolés dans le bas-fond, hors parcelle
	while positions.size() < 740:
		var x2 := r.randf_range(-250, 30)
		var z2 := r.randf_range(-395, 395)
		if abs(x2 - Terrain.x_riviere(z2)) > 20.0:
			positions.append(Vector3(x2, Terrain.hauteur(x2, z2) + 6.0, z2))
	mm.instance_count = positions.size()
	for i in positions.size():
		var s := r.randf_range(0.7, 1.4)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), positions[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat(Color(0.10, 0.33, 0.12))
	add_child(mmi)
	# Village sur le versant ouest
	for i in 7:
		var x := -330.0 + (i % 3) * 22.0
		var z := -60.0 + (i / 3) * 28.0 + (i % 2) * 6.0
		var y := Terrain.hauteur(x, z)
		_boite(self, Vector3(9, 5, 7), Vector3(x, y + 2.5, z), Color(0.80, 0.62, 0.42))
		var toit := MeshInstance3D.new()
		var pr := PrismMesh.new()
		pr.size = Vector3(11, 3.5, 9)
		toit.mesh = pr
		toit.material_override = _mat(Color(0.55, 0.25, 0.15))
		toit.position = Vector3(x, y + 6.7, z)
		add_child(toit)
	# Contour de la parcelle candidate (piquets jaunes)
	var pr2 := Terrain.PARCELLE
	for coin in [pr2.position, Vector2(pr2.end.x, pr2.position.y), pr2.end, Vector2(pr2.position.x, pr2.end.y)]:
		_boite(self, Vector3(1.2, 6, 1.2), Vector3(coin.x, Terrain.hauteur(coin.x, coin.y) + 3.0, coin.y), Color(0.95, 0.80, 0.10))


func _creer_avatar() -> void:
	avatar = Node3D.new()
	var corps := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 1.6
	cap.height = 7.0
	corps.mesh = cap
	corps.material_override = _mat(Color(0.95, 0.45, 0.10))
	corps.position.y = 3.5
	avatar.add_child(corps)
	var tete := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.5
	sph.height = 3.0
	tete.mesh = sph
	tete.material_override = _mat(Color(0.35, 0.22, 0.14))
	tete.position.y = 8.2
	avatar.add_child(tete)
	add_child(avatar)
	avatar.position = Vector3(60, Terrain.hauteur(60, -150), -150)


func _poser_bornes() -> void:
	var pr := Terrain.PARCELLE
	var n := 0
	for i in 9:
		for coin in [Vector2(pr.position.x + pr.size.x * i / 8.0, pr.position.y), Vector2(pr.position.x + pr.size.x * i / 8.0, pr.end.y)]:
			_boite(bornes, Vector3(0.8, 2.4, 0.8), Vector3(coin.x, Terrain.hauteur(coin.x, coin.y) + 1.2, coin.y), Color(0.95, 0.95, 0.95))
			n += 1


func _construire_amenagement() -> void:
	for c in amenagement.get_children():
		c.queue_free()
	Terrain.casiers_niveles = true
	_reconstruire_terrain()
	var pr := Terrain.PARCELLE
	var terre := Color(0.52, 0.38, 0.24)
	# Diguettes : 4 colonnes x 5 rangées de casiers de 50 m
	for i in 5:
		var x := pr.position.x + i * 50.0
		for j in 5:
			var zc := pr.position.y + j * 50.0 + 25.0
			_boite(amenagement, Vector3(1.4, diguette_h * 3.0 + 0.4, 50), Vector3(x, Terrain.hauteur(x + 1.0 if i < 4 else x - 1.0, zc) + diguette_h, zc), terre)
	for j in 6:
		var z := pr.position.y + j * 50.0
		for i in 4:
			var xc := pr.position.x + i * 50.0 + 25.0
			_boite(amenagement, Vector3(50, diguette_h * 3.0 + 0.4, 1.4), Vector3(xc, Terrain.hauteur(xc, z + 1.0 if j < 5 else z - 1.0) + diguette_h, z), terre)
	# Canal d'amenée depuis la prise sur le marigot (amont), puis canal de tête
	var prise := Vector3(Terrain.x_riviere(-330.0) + 6.0, 0, -330.0)
	var tete := Vector3(pr.position.x + 4.0, 0, pr.position.y - 8.0)
	_troncon_canal(prise, tete)
	_troncon_canal(tete, Vector3(pr.end.x, 0, pr.position.y - 8.0))
	_boite(amenagement, Vector3(5, 4, 5), Vector3(prise.x, Terrain.hauteur(prise.x, prise.z) + 1.5, prise.z), Color(0.65, 0.65, 0.65))
	# Digue de protection côté marigot
	if digue_h > 0.05:
		_boite(amenagement, Vector3(2.0 + digue_h * 4.0, digue_h * 2.0, L_DIGUE + 20), Vector3(pr.position.x - 10.0, Terrain.hauteur(pr.position.x - 10.0, 0) + digue_h, 0), Color(0.45, 0.33, 0.20))
	# Drain collecteur à l'aval
	if avec_drain:
		_boite(amenagement, Vector3(pr.size.x + 40, 0.3, 3.0), Vector3(pr.get_center().x + 10, Terrain.hauteur(pr.get_center().x, pr.end.y + 9.0) + 0.1, pr.end.y + 9.0), Color(0.15, 0.30, 0.42))
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
	var touffe := BoxMesh.new()
	touffe.size = Vector3(1.5, 1.0, 1.5)
	var mr := MultiMesh.new()
	mr.transform_format = MultiMesh.TRANSFORM_3D
	mr.mesh = touffe
	mr.instance_count = 40 * 50
	riz_mm = MultiMeshInstance3D.new()
	riz_mm.multimesh = mr
	riz_mat = _mat(Color(0.35, 0.75, 0.25))
	riz_mm.material_override = riz_mat
	amenagement.add_child(riz_mm)
	_maj_parcelle(0.0, 0.0, 0.0)


func _troncon_canal(a: Vector3, b: Vector3) -> void:
	var n: int = int(ceil(a.distance_to(b) / 12.0))
	var angle: float = atan2(b.x - a.x, b.z - a.z)
	for i in n:
		var p: Vector3 = a.lerp(b, (i + 0.5) / n)
		var y := Terrain.hauteur(p.x, p.z)
		var larg: float = canal_b + 2.0 * canal_h + 1.5
		_boite(amenagement, Vector3(larg + 2.0, 0.9, a.distance_to(b) / n + 0.5), Vector3(p.x, y + 0.25, p.z), Color(0.52, 0.38, 0.24), angle)
		_boite(amenagement, Vector3(larg, 0.3, a.distance_to(b) / n + 0.5), Vector3(p.x, y + 0.62, p.z), Color(0.22, 0.48, 0.68), angle)


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
	riz_mat.albedo_color = Color(0.30, 0.72, 0.22).lerp(Color(0.85, 0.72, 0.25), maturite)


# =====================================================================
#  CAMÉRA ET DÉPLACEMENT
# =====================================================================

func _process(delta: float) -> void:
	var dir := Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch))
	cam.position = cam_cible + dir * cam_dist
	cam.look_at(cam_cible)
	if etape == Etape.CAMPAGNE and campagne != null and not en_pause and not campagne.termine and not popup.visible:
		cumul_temps += delta * vitesse
		while cumul_temps >= 1.0 and not campagne.termine and not popup.visible:
			cumul_temps -= 1.0
			_jour_de_campagne()


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
	var tw := create_tween()
	tw.tween_property(avatar, "position", cible, clamp(avatar.position.distance_to(cible) / 120.0, 0.3, 2.5))
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
		btn.custom_minimum_size = Vector2(160, 52)
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
	var noms := ["Arrivée", "1. Foncier", "2. Études", "3. Besoins en eau", "4. Conception", "5. Campagne", "6. Bilan"]
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
	_afficher_popup(bb, [["Fermer", Callable()]])


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
	campagne = null
	avec_drain = false
	digue_h = 0.0
	Terrain.casiers_niveles = false
	_reconstruire_terrain()
	terrain_mat.set_shader_parameter("contours", 0.0)
	for c in amenagement.get_children():
		c.queue_free()
	for c in bornes.get_children():
		c.queue_free()
	eau_mm = null
	riz_mm = null
	nappe_crue.visible = false
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
		Etape.CAMPAGNE: _demarrer_campagne()
		Etape.BILAN: _ecran_bilan()


func _ecran_intro() -> void:
	_vider()
	titre.text = "Le bas-fond de Gabiadji"
	_texte("Tu viens d'obtenir ta licence AHA à l'Université de San-Pédro. Une coopérative te confie [b]%s[/b] pour aménager un bas-fond rizicole de [b]5 ha[/b] (les piquets jaunes), le long d'un marigot.\n\nTon objectif : réussir une campagne de riz irrigué. Chaque décision compte : le foncier, les études, les calculs, les ouvrages.\n\n[i]Explore le terrain : glisse pour tourner, pince pour zoomer, touche le sol pour t'y rendre. Lieu et personnages fictifs ; relief calibré, à remplacer par les données réelles.[/i]" % _fcfa(couts.capital_initial))
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
			return "Pente du bas-fond : [b]%.1f ‰[/b]. Pente disponible le long du tracé du canal : [b]%.1f ‰[/b]. Courbes de niveau (équidistance 0,5 m) affichées. Touche le sol pour lire une altitude précise." % [VRAI.pente * 1000.0, VRAI.pente_canal * 1000.0]
		"sol":
			var s: Dictionary = sols[VRAI.sol]
			return "Sol [b]%s[/b] : CC %d %%, PFP %d %% (en volume), percolation sous lame d'eau [b]%.0f mm/j[/b]. RU sur 50 cm = %.0f mm. Très favorable au riz." % [s.nom, s.cc_pct, s.pfp_pct, s.percolation_mm_j, Eau.reserve_utile(s.cc_pct, s.pfp_pct, 500)]
		"hydro":
			return "Débit prélevable : de [b]4 L/s[/b] (février) à 300 L/s (juin). Crue au droit de la parcelle : [b]%.1f m[/b] (période de retour 2 ans), [b]%.1f m[/b] (10 ans), %.1f m (50 ans)." % [VRAI.crue_2ans, VRAI.crue_10ans, VRAI.crue_50ans]
	return ""


# --- Valeurs « connues » du joueur : mesurées si l'étude est faite, sinon estimées ---
func _sol_connu() -> Dictionary:
	return sols[VRAI.sol] if fait.has("sol") else sols[CROYANCE.sol]

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


func _capacite_canal(pente: float) -> float:
	return Hydraulique.debit_manning(KS_TERRE, canal_b, max(canal_h - REVANCHE, 0.0), FRUIT, pente)


func _cout_travaux() -> Dictionary:
	var t: Dictionary = couts.travaux
	var v_canal: float = Hydraulique.volume_trapeze(canal_b, canal_h, FRUIT, L_CANAL)
	var v_diguettes: float = Hydraulique.volume_trapeze(0.3, diguette_h, 1.0, L_DIGUETTES)
	var v_digue: float = Hydraulique.volume_trapeze(1.0, digue_h, 2.0, L_DIGUE)
	var d := {"Canal d'amenée (%.0f m³)" % v_canal: v_canal * t.terrassement_m3,
		"Ouvrage de prise": float(t.ouvrage_prise),
		"Diguettes et planage des casiers (%.0f m³)" % v_diguettes: v_diguettes * t.terrassement_m3 + 300000.0}
	if digue_h > 0.05:
		d["Digue de protection (%.0f m³)" % v_digue] = v_digue * t.terrassement_m3
	if avec_drain:
		d["Drain collecteur (%.0f m)" % L_DRAIN] = L_DRAIN * t.drain_ml
	return d


func _ecran_conception() -> void:
	_vider()
	for id in ["manning", "drainage"]:
		_vu(id)
	titre.text = "4. Conception des ouvrages"
	var pente := _pente_connue()
	var q := _capacite_canal(pente)
	var h_eau: float = max(canal_h - REVANCHE, 0.0)
	var v: float = q / max(Hydraulique.section_trapeze(canal_b, h_eau, FRUIT), 0.0001)
	var etat := "[color=#8fd18f]suffisant[/color]" if q >= q_projet else "[color=#ff7b7b]insuffisant[/color]"
	if q > q_projet * 2.5:
		etat = "[color=#ffb347]très surdimensionné (argent gaspillé)[/color]"
	var src_pente := "mesurée" if fait.has("topo") else "[color=#ffb347]estimée à l'œil[/color]"
	_texte("[b]Canal d'amenée en terre[/b] (trapèze, fruit 1/1, Ks = 30)\nPente %s : %.1f ‰ · revanche %.0f cm\nHauteur d'eau = %.2f m → capacité [b]%.1f L/s[/b] pour un débit de projet de %.1f L/s : %s\nVitesse : %.2f m/s%s" % [src_pente, pente * 1000.0, REVANCHE * 100.0, h_eau, q * 1000.0, q_projet * 1000.0, etat, v, "  [color=#ffb347](> 0,8 m/s : risque d'érosion en terre)[/color]" if v > 0.8 else ""])
	_curseur("Largeur au plafond : %.2f m" % canal_b, 0.2, 0.8, 0.05, canal_b, func(x): canal_b = x; _ecran_conception())
	_curseur("Profondeur totale du canal : %.2f m" % canal_h, 0.2, 0.6, 0.05, canal_h, func(x): canal_h = x; _ecran_conception())
	_curseur("Hauteur des diguettes : %.0f cm" % (diguette_h * 100.0), 0.10, 0.35, 0.05, diguette_h, func(x): diguette_h = x; _ecran_conception())
	var crue_txt := "Crue de référence : %.1f m (2 ans), %.1f m (10 ans)." % [VRAI.crue_2ans, VRAI.crue_10ans] if fait.has("hydro") else "[color=#ffb347]Pas d'étude hydrologique : les anciens parlent d'environ %.1f m d'eau certaines années.[/color]" % CROYANCE.crue
	_texte(crue_txt)
	_curseur("Digue de protection côté marigot : %.1f m" % digue_h, 0.0, 1.5, 0.1, digue_h, func(x): digue_h = x; _ecran_conception())
	_bouton(("☑ " if avec_drain else "☐ ") + "Drain collecteur à l'aval (réseau de colature)", func():
		avec_drain = not avec_drain
		_ecran_conception())
	var total := 0.0
	var devis := "[b]Devis estimatif[/b]\n"
	var cd := _cout_travaux()
	for k in cd:
		devis += "%s : %s\n" % [k, _fcfa(cd[k])]
		total += cd[k]
	var camp: float = _charges_campagne_ha() * 5.0
	devis += "[b]Total travaux : %s[/b]\nCharges de la campagne à prévoir : %s" % [_fcfa(total), _fcfa(camp)]
	if tresorerie < total + camp:
		devis += "\n[color=#ffb347]Trésorerie insuffisante : la microfinance prêtera le complément (intérêts 12 %% sur la campagne).[/color]"
	_texte(devis)
	_bouton("Voir le calcul de Manning-Strickler", func():
		var s: float = Hydraulique.section_trapeze(canal_b, h_eau, FRUIT)
		var pm: float = Hydraulique.perimetre_trapeze(canal_b, h_eau, FRUIT)
		_afficher_popup("[b][font_size=24]Capacité du canal[/font_size][/b]\n\nSection mouillée S = (b + m·h)·h = (%.2f + 1 × %.2f) × %.2f = [b]%.3f m²[/b]\nPérimètre mouillé P = b + 2h√(1 + m²) = [b]%.3f m[/b]\nRayon hydraulique Rh = S ÷ P = [b]%.3f m[/b]\nQ = Ks · S · Rh^(2/3) · √I = 30 × %.3f × %.3f × %.4f = [b]%.4f m³/s = %.1f L/s[/b]\n\nLa hauteur d'eau est la profondeur moins la revanche (15 à 20 cm dans ton cours).\n\n[color=#1F4E79][i]Dans ton cours : L3 — Bases techniques, ch. 6 ; L2 — Hydraulique générale, ch. 5 (écoulements à surface libre).\nValeur indicative : Ks = 30 pour un canal en terre.[/i][/color]" % [canal_b, h_eau, h_eau, s, pm, s / max(pm, 0.001), s, pow(s / max(pm, 0.001), 2.0 / 3.0), sqrt(pente), q, q * 1000.0], [["Fermer", Callable()]]))
	_bouton("Lancer les travaux puis la campagne", func():
		for k in cd:
			_payer(k, cd[k], "travaux")
		jours_ecoules += 45
		_aller(Etape.CAMPAGNE))


func _charges_campagne_ha() -> float:
	var s := 0.0
	for k in couts.campagne_par_ha:
		s += couts.campagne_par_ha[k]
	return s


# =====================================================================
#  CAMPAGNE
# =====================================================================

func _demarrer_campagne() -> void:
	_construire_amenagement()
	for id in ["bilan", "stress", "aue"]:
		_vu(id)
	_payer("Intrants et main-d'œuvre de la campagne (5 ha)", _charges_campagne_ha() * 5.0, "campagne")
	var meteo := Meteo.new(climat, rng.randi())
	var jour_semis: int = SEMIS[semis_idx].jour
	meteo.secheresse_debut = ((jour_semis + 52 - 1) % 365) + 1
	meteo.secheresse_duree = 15
	campagne = Campagne.new(riz, meteo)
	var sol: Dictionary = sols[VRAI.sol]
	campagne.surface_ha = 5.0
	campagne.ru_mm = Eau.reserve_utile(sol.cc_pct, sol.pfp_pct, 500)
	campagne.percolation_mm_j = sol.percolation_mm_j
	campagne.hauteur_diguette_mm = diguette_h * 1000.0
	campagne.q_canal_m3_s = _capacite_canal(VRAI.pente_canal)
	campagne.efficience = EFFICIENCE
	campagne.q_riviere_m3_s = VRAI.q_riviere
	campagne.drainage_mm_j = 25.0 if avec_drain else 0.0
	campagne.hauteur_digue_m = digue_h
	campagne.jour_semis = jour_semis
	# Crue : tirage selon la saison (aucune en contre-saison sèche)
	var tirage := rng.randf()
	if semis_idx == 0 or (semis_idx == 1 and tirage < 0.6):
		campagne.crue_jour = rng.randi_range(32, 46)
		campagne.crue_duree = 4
		var t2 := rng.randf()
		campagne.crue_hauteur_m = VRAI.crue_2ans if t2 < 0.55 else (VRAI.crue_10ans if t2 < 0.9 else VRAI.crue_50ans)
	campagne.demarrer()
	en_pause = false
	cumul_temps = 0.0
	_ecran_campagne()


func _ecran_campagne() -> void:
	_vider()
	titre.text = "5. Campagne de riz"
	_texte("")
	var ligne := HBoxContainer.new()
	panneau.add_child(ligne)
	for v in [["Pause", 0.0], ["×1", 6.0], ["×3", 18.0]]:
		var b := Button.new()
		b.text = v[0]
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var vv: float = v[1]
		b.pressed.connect(func():
			en_pause = vv == 0.0
			if vv > 0.0:
				vitesse = vv)
		ligne.add_child(b)
	_texte("")


func _jour_de_campagne() -> void:
	var j := campagne.jour + 1
	# Litige foncier au jour 25
	if j == 25 and rng.randf() < _risque_litige():
		litige_jours_restants = 12
		_payer("Règlement du litige foncier", couts.litige, "campagne")
		evenements.append("litige")
		_afficher_popup("[b][font_size=24]Litige foncier[/font_size][/b]\n\nUn membre de la famille détentrice conteste ton droit d'exploiter la parcelle et fait fermer ta prise d'eau. Il faut 12 jours de médiation chez le chef de village et %s de frais pour reprendre.\n\nRisque de litige au départ : %d %%." % [_fcfa(couts.litige), int(_risque_litige() * 100.0)], [["Continuer", Callable()]])
	var q_normal := _capacite_canal(VRAI.pente_canal) + (0.008 if motopompe else 0.0)
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
	jours_ecoules += 1
	_maj_hud()
	if panneau.get_child_count() >= 3:
		var etat := "[color=#8fd18f]confort hydrique[/color]" if l.ks > 0.99 else "[color=#ff7b7b]STRESS HYDRIQUE (Ks = %.2f)[/color]" % l.ks
		if l.submerge:
			etat = "[color=#ff7b7b]CASIERS SUBMERGÉS PAR LA CRUE[/color]"
		(panneau.get_child(0) as RichTextLabel).text = "[b]Jour %d / %d[/b] — stade : %s\nPluie : %.0f mm · ET0 : %.1f mm · Kc : %.2f\nIrrigation : %.1f mm · Lame d'eau : [b]%.0f mm[/b]\nÉtat : %s" % [campagne.jour, campagne.duree(), _stade(campagne.jour), l.pluie, l.et0, l.kc, l.irrigation, l.lame, etat]
		(panneau.get_child(2) as RichTextLabel).text = "[b]Bilan d'eau cumulé (mm)[/b]\nPluie %.0f + irrigation %.0f\n= ETr %.0f + percolation %.0f + drainage %.0f + débordement %.0f + stock\nJours de stress : %d · de submersion : %d · de débordement : %d\nCapacité du canal : %.1f L/s%s" % [campagne.tot.pluie, campagne.tot.irrigation, campagne.tot.etr, campagne.tot.percolation, campagne.tot.drainage, campagne.tot.debordement, campagne.jours_stress, campagne.jours_submersion, campagne.jours_debordement, campagne.q_canal_m3_s * 1000.0, "  (prise fermée : litige)" if litige_jours_restants > 0 else ""]
	if campagne.termine:
		_aller(Etape.BILAN)


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
	titre.text = "6. Bilan de campagne"
	var r := campagne.resultat()
	var recettes: float = r.production_t * 1000.0 * riz.prix_fcfa_kg
	var redevance: float = campagne.tot.preleve_m3 * couts.eau_redevance_m3
	_payer("Redevance eau (%.0f m³)" % campagne.tot.preleve_m3, redevance, "campagne")
	var invest := 0.0
	var ch_camp := 0.0
	for c in charges:
		if c[2] == "campagne":
			ch_camp += c[1]
		else:
			invest += c[1]
	var interets := 0.0
	if tresorerie < 0.0:
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
	var deb := _debriefing(r, ratio)
	_bouton("Lire le débriefing du professeur", func(): _afficher_popup(deb, [["Fermer", Callable()]]))
	_bouton("Rejouer avec d'autres choix", _nouvelle_partie)
	_sauvegarder(r, total)


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
		if semis_idx == 2: causes.append("en contre-saison le marigot ne fournit que 4 à 6 L/s")
		if evenements.has("litige"): causes.append("ta prise est restée fermée 12 jours pendant le litige")
		if causes.is_empty(): causes.append("la poche de sécheresse a dépassé la capacité du réseau")
		bb += "[b]%d. Stress hydrique : %d jours, rendement réduit à %d %% sur ce critère[/b]\n[u]Ce qui s'est passé[/u] : le riz a manqué d'eau.\n[u]Pourquoi[/u] : %s.\n[u]Ce que dit ton cours[/u] : besoin brut = besoin net ÷ efficience ; le Qfc sert à dimensionner les canaux (L3 Bases techniques, ch. 1 et 4). L'étude hydrologique vérifie que la ressource couvre les besoins durant toute la campagne (ch. 5.1.3).\n[u]Ce qu'il fallait faire[/u] : dimensionner le canal sur le besoin de pointe, et choisir une date de repiquage compatible avec le débit du marigot.\n\n" % [n, campagne.jours_stress, int(r.rel_eau * 100.0), ", ".join(causes)]
	if campagne.jours_submersion > 0:
		n += 1
		bb += "[b]%d. Submersion par la crue : %d jours[/b]\n[u]Ce qui s'est passé[/u] : une crue de %.1f m a dépassé ta digue de %.1f m.\n[u]Pourquoi[/u] : %s.\n[u]Ce que dit ton cours[/u] : une crue décennale a 10 %% de chances de se produire chaque année ; le choix de la période de retour est un compromis entre coût et risque (L3 Hydrologie appliquée, 3e partie).\n[u]Ce qu'il fallait faire[/u] : caler la digue sur la crue de projet choisie, plus une revanche.\n\n" % [n, campagne.jours_submersion, campagne.crue_hauteur_m, digue_h, "tu n'avais pas d'étude hydrologique" if not fait.has("hydro") else "tu as accepté le risque d'une crue plus rare que ta crue de projet"]
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
		bb += "[b]%d. Sol non étudié[/b]\n[u]Ce qui s'est passé[/u] : tu as calculé avec une percolation de 6 mm/j (sol jugé limoneux) alors que le sol est argileux (2 mm/j).\n[u]Ce que dit ton cours[/u] : la texture commande l'infiltration et la rétention (L3 Bases techniques, ch. 3 ; L2 Pédogenèse).\n[u]Ce qu'il fallait faire[/u] : une étude pédologique à %s évite de surdimensionner tout le réseau.\n\n" % [n, _fcfa(couts.etudes.pedologie)]
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


func _pilote_auto(mode: String) -> void:
	var bon := mode == "bon"
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
	semis_idx = 0 if bon else 2
	_aller(Etape.BESOINS)
	var perc: float = _sol_connu().percolation_mm_j
	q_projet = Eau.debit_equipement(Eau.debit_fictif_continu(_besoin_brut_pointe(perc)), 5.0)
	quiz_juste = bon
	if bon:
		canal_b = 0.2; canal_h = 0.30; diguette_h = 0.20; avec_drain = true; digue_h = 1.0
	else:
		canal_b = 0.2; canal_h = 0.20; diguette_h = 0.10; avec_drain = false; digue_h = 0.0
	_aller(Etape.CONCEPTION)
	await get_tree().create_timer(0.3).timeout
	await _capture(mode + "_3_conception")
	var cd := _cout_travaux()
	for k in cd:
		_payer(k, cd[k], "travaux")
	vitesse = 60.0
	_aller(Etape.CAMPAGNE)
	cam_dist = 260.0
	cam_pitch = 0.6
	var pris := false
	while not campagne.termine:
		if popup.visible:
			popup.visible = false
		if campagne.jour >= 70 and not pris:
			pris = true
			await _capture(mode + "_4_campagne")
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	await _capture(mode + "_5_bilan")
	popup_texte.text = _debriefing(campagne.resultat(), 1.0)
	print("AUTO ", mode, " : ", campagne.resultat(), " tresorerie=", tresorerie, " evenements=", evenements, " bilan=", campagne.erreur_bilan())
	get_tree().quit()
