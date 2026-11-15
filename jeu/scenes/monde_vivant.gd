class_name MondeVivant
extends Node3D
## Tout ce qui rend le monde vivant : course du soleil et de la lune, couleur du ciel, nuages,
## pluie, ouvriers au travail. N'influence pas les calculs : il les montre.

var heure := 9.0            # 0 à 24
var nebulosite := 0.3       # 0 ciel clair, 1 couvert
var il_pleut := false
var vent := 1.0
var ouvriers_actifs := false

var env: Environment
var mat_ciel: ProceduralSkyMaterial
var soleil: DirectionalLight3D
var lune: DirectionalLight3D
var disque_soleil: MeshInstance3D
var disque_lune: MeshInstance3D
var nuages: Array = []
var pluie: CPUParticles3D
var ouvriers: Array = []
var rng := RandomNumberGenerator.new()

const JOUR_HAUT := Color(0.30, 0.55, 0.90)
const JOUR_HORIZON := Color(0.80, 0.88, 0.95)
const AUBE_HORIZON := Color(0.98, 0.62, 0.35)
const NUIT_HAUT := Color(0.04, 0.06, 0.16)
const NUIT_HORIZON := Color(0.14, 0.18, 0.32)

func installer(p_env: Environment, p_ciel: ProceduralSkyMaterial, p_soleil: DirectionalLight3D) -> void:
	env = p_env
	mat_ciel = p_ciel
	soleil = p_soleil
	rng.seed = 4
	lune = DirectionalLight3D.new()
	lune.light_color = Color(0.60, 0.70, 1.0)
	lune.light_energy = 0.0
	add_child(lune)
	disque_soleil = _disque(60.0, Color(1.0, 0.95, 0.70))
	disque_lune = _disque(38.0, Color(0.92, 0.94, 1.0))
	# Nuages : amas de sphères aplaties
	for i in 16:
		var n := Node3D.new()
		for k in 3:
			var mi := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = rng.randf_range(35, 60)
			s.height = s.radius * 0.9
			s.radial_segments = 10
			s.rings = 5
			mi.mesh = s
			mi.position = Vector3(rng.randf_range(-50, 50), rng.randf_range(-6, 6), rng.randf_range(-30, 30))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.add_child(mi)
		n.position = Vector3(rng.randf_range(-1500, 1500), rng.randf_range(400, 520), rng.randf_range(-1500, 1500))
		add_child(n)
		nuages.append(n)
	var mat_n := StandardMaterial3D.new()
	mat_n.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_n.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_n.albedo_color = Color(1, 1, 1, 0.9)
	for n in nuages:
		for c in n.get_children():
			c.material_override = mat_n
	set_meta("mat_nuage", mat_n)
	# Pluie
	pluie = CPUParticles3D.new()
	var goutte := BoxMesh.new()
	goutte.size = Vector3(0.25, 7.0, 0.25)
	pluie.mesh = goutte
	var mg := StandardMaterial3D.new()
	mg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mg.albedo_color = Color(0.75, 0.85, 1.0, 0.55)
	pluie.material_override = mg
	pluie.amount = 500
	pluie.lifetime = 1.6
	pluie.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	pluie.emission_box_extents = Vector3(260, 2, 260)
	pluie.direction = Vector3(0.15, -1, 0)
	pluie.spread = 2.0
	pluie.gravity = Vector3.ZERO
	pluie.initial_velocity_min = 110.0
	pluie.initial_velocity_max = 130.0
	pluie.emitting = false
	add_child(pluie)
	# Ouvriers
	var chemises := [Color(0.85, 0.20, 0.20), Color(0.95, 0.85, 0.20), Color(0.20, 0.45, 0.85), Color(0.95, 0.95, 0.95), Color(0.60, 0.25, 0.70)]
	for i in 10:
		var o := Node3D.new()
		var corps := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 1.1
		cap.height = 4.6
		corps.mesh = cap
		corps.position.y = 2.3
		var m := StandardMaterial3D.new()
		m.albedo_color = chemises[i % chemises.size()]
		corps.material_override = m
		o.add_child(corps)
		var chapeau := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.2
		cyl.bottom_radius = 2.0
		cyl.height = 1.0
		chapeau.mesh = cyl
		chapeau.position.y = 5.0
		var mc := StandardMaterial3D.new()
		mc.albedo_color = Color(0.85, 0.72, 0.45)
		chapeau.material_override = mc
		o.add_child(chapeau)
		o.visible = false
		o.set_meta("cible", Vector3.ZERO)
		o.set_meta("pause", 0.0)
		add_child(o)
		ouvriers.append(o)

func _disque(rayon: float, couleur: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = rayon
	s.height = rayon * 2.0
	mi.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = couleur
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func fait_jour() -> bool:
	return heure > 6.2 and heure < 18.0

func maj(delta: float, centre: Vector3) -> void:
	# Soleil : se lève à l'est (+x) à 6 h, culmine à 12 h, se couche à l'ouest à 18 h
	var a: float = (heure - 6.0) / 12.0 * PI
	var dir_soleil := Vector3(cos(a), sin(a), 0.25).normalized()
	var dir_lune := Vector3(cos(a + PI), sin(a + PI), -0.2).normalized()
	var haut: float = clamp(dir_soleil.y, 0.0, 1.0)
	var jour: float = smoothstep(-0.08, 0.25, dir_soleil.y)
	var couvert: float = clamp(nebulosite, 0.0, 1.0)
	soleil.look_at_from_position(dir_soleil * 100.0, Vector3.ZERO, Vector3.UP if abs(dir_soleil.y) < 0.99 else Vector3.RIGHT)
	soleil.light_energy = (0.15 + 0.65 * haut) * jour * (1.0 - 0.5 * couvert)
	soleil.light_color = Color(1.0, 0.72, 0.50).lerp(Color(1, 1, 1), smoothstep(0.0, 0.45, dir_soleil.y))
	soleil.visible = dir_soleil.y > -0.08
	lune.look_at_from_position(dir_lune * 100.0, Vector3.ZERO, Vector3.UP if abs(dir_lune.y) < 0.99 else Vector3.RIGHT)
	lune.light_energy = 0.45 * clamp(dir_lune.y, 0.0, 1.0) * (1.0 - jour)
	lune.visible = lune.light_energy > 0.005
	disque_soleil.position = centre + dir_soleil * 1900.0
	disque_soleil.visible = dir_soleil.y > -0.05
	disque_lune.position = centre + dir_lune * 1900.0
	disque_lune.visible = dir_lune.y > -0.05
	# Ciel
	var aube: float = (1.0 - abs(jour - 0.5) * 2.0)
	var gris := Color(0.55, 0.58, 0.62)
	var haut_c := NUIT_HAUT.lerp(JOUR_HAUT, jour).lerp(gris, couvert * 0.6 * jour)
	var hor_c := NUIT_HORIZON.lerp(JOUR_HORIZON, jour).lerp(AUBE_HORIZON, aube * 0.7).lerp(gris, couvert * 0.5 * jour)
	mat_ciel.sky_top_color = haut_c
	mat_ciel.sky_horizon_color = hor_c
	mat_ciel.ground_horizon_color = hor_c
	mat_ciel.ground_bottom_color = hor_c.darkened(0.25)
	env.ambient_light_energy = lerp(0.22, 0.35, jour)
	# Nuages : dérivent avec le vent ; leur nombre visible suit la nébulosité
	var mat_n: StandardMaterial3D = get_meta("mat_nuage")
	var teinte: float = lerp(0.18, 1.0, jour) * (1.0 - 0.45 * couvert)
	mat_n.albedo_color = Color(teinte, teinte, teinte * 1.03, 0.9)
	for i in nuages.size():
		var n: Node3D = nuages[i]
		n.position.x += delta * (6.0 + 5.0 * vent)
		if n.position.x > 1550.0:
			n.position.x = -1550.0
		n.visible = float(i) / nuages.size() < 0.15 + couvert * 0.85
	pluie.emitting = il_pleut
	pluie.position = centre + Vector3(0, 170, 0)
	# Ouvriers : au champ le jour pendant la campagne, au campement la nuit
	var au_travail: bool = ouvriers_actifs and fait_jour() and not il_pleut
	var pr := Terrain.PARCELLE
	for o in ouvriers:
		var n: Node3D = o
		n.visible = ouvriers_actifs and fait_jour()
		if not au_travail:
			continue
		var p: float = n.get_meta("pause")
		if p > 0.0:
			n.set_meta("pause", p - delta)
			n.scale.y = 0.78 + 0.10 * sin(Time.get_ticks_msec() / 160.0 + n.position.x)   # penché sur les plants
			continue
		n.scale.y = 1.0
		var cible: Vector3 = n.get_meta("cible")
		var plat := Vector3(cible.x - n.position.x, 0, cible.z - n.position.z)
		if cible == Vector3.ZERO or plat.length() < 2.0:
			n.set_meta("cible", Vector3(rng.randf_range(pr.position.x + 4, pr.end.x - 4), 0, rng.randf_range(pr.position.y + 4, pr.end.y - 4)))
			n.set_meta("pause", rng.randf_range(1.0, 3.5))
			continue
		var pas: Vector3 = plat.normalized() * 14.0 * delta
		n.position.x += pas.x
		n.position.z += pas.z
		n.position.y = Terrain.hauteur(n.position.x, n.position.z)

func placer_ouvriers() -> void:
	var pr := Terrain.PARCELLE
	for o in ouvriers:
		var x := rng.randf_range(pr.position.x + 4, pr.end.x - 4)
		var z := rng.randf_range(pr.position.y + 4, pr.end.y - 4)
		o.position = Vector3(x, Terrain.hauteur(x, z), z)
		o.set_meta("cible", Vector3.ZERO)
