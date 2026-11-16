class_name MondeVivant
extends Node3D
## Tout ce qui rend le monde vivant : course du soleil et de la lune, couleur du ciel, nuages,
## pluie, ouvriers au travail. N'influence pas les calculs : il les montre.

var heure := 9.0            # 0 à 24
var nebulosite := 0.3       # 0 ciel clair, 1 couvert
var il_pleut := false
var vent := 1.0
var ouvriers_actifs := false
var zone: Rect2 = Terrain.PARCELLE   # où les ouvriers travaillent
var n_actifs := 10
var mode_recolte := false
var anim_travail := "2H_Melee_Attack_Chop"   # geste de travail : pioche au chantier, cueillette aux champs
var point_stock := Vector3(30, 0, 140)

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
	for i in 24:
		var o: Node3D = Modeles.personnage(i, 7.0)
		if o == null:
			o = Node3D.new()
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
		var chapeau := MeshInstance3D.new()      # chapeau de paille
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.3
		cyl.bottom_radius = 2.3
		cyl.height = 0.9
		chapeau.mesh = cyl
		chapeau.position.y = 7.3 if o.has_meta("anim") else 5.0
		var mc := StandardMaterial3D.new()
		mc.albedo_color = Color(0.88, 0.76, 0.48)
		chapeau.material_override = mc
		o.add_child(chapeau)
		var sac := MeshInstance3D.new()
		var bs := BoxMesh.new()
		bs.size = Vector3(2.2, 1.4, 1.4)
		sac.mesh = bs
		var msac := StandardMaterial3D.new()
		msac.albedo_color = Color(0.88, 0.74, 0.30)
		sac.material_override = msac
		sac.position = Vector3(0, 8.6, 0)
		sac.visible = false
		sac.name = "sac"
		o.add_child(sac)
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
	# Ouvriers : chacun suit son propre état (voir simuler_agents)
	var idx := 0
	for o in ouvriers:
		var n: Node3D = o
		if idx >= agents.size() or idx >= n_actifs or not ouvriers_actifs:
			n.visible = false
			idx += 1
			continue
		var ag: Dictionary = agents[idx]
		idx += 1
		n.visible = ag.etat != "dort" and ag.etat != "absent"
		if not n.visible:
			continue
		var but: Vector3
		if ag.etat == "travaille":
			but = n.get_meta("cible")
			var p: float = n.get_meta("pause")
			var arrive: bool = but == Vector3.ZERO or Vector2(but.x - n.position.x, but.z - n.position.z).length() < 2.0
			var sac: Node3D = n.get_node("sac")
			if not mode_recolte:
				sac.visible = false
			if arrive and p <= 0.0 and mode_recolte and not sac.visible:
				# gerbe coupée : il la porte sur la tête jusqu'à l'aire de battage
				sac.visible = true
				n.set_meta("cible", Vector3(point_stock.x + rng.randf_range(-6, 6), 0, point_stock.z + rng.randf_range(-6, 6)))
				n.set_meta("pause", 0.0)
			elif arrive and p <= 0.0:
				sac.visible = false
				n.set_meta("cible", Vector3(rng.randf_range(zone.position.x, zone.end.x), 0, rng.randf_range(zone.position.y, zone.end.y)))
				n.set_meta("pause", rng.randf_range(1.0, 4.0))
			if p > 0.0:
				n.set_meta("pause", p - delta)
				if n.has_meta("anim"):
					Modeles.jouer(n, anim_travail)
				else:
					n.scale.y = 0.80 + 0.10 * sin(Time.get_ticks_msec() / (140.0 + ag.fatigue * 2.0) + n.position.x)
				continue
			but = n.get_meta("cible")
		elif ag.etat == "mange":
			but = point_repas + Vector3((idx % 5) * 4.0 - 8.0, 0, (idx / 5) * 4.0)
		else:
			but = point_repos + Vector3((idx % 4) * 5.0 - 8.0, 0, (idx / 4) * 5.0)
		var plat := Vector3(but.x - n.position.x, 0, but.z - n.position.z)
		if plat.length() < 2.0:
			if n.has_meta("anim"):
				Modeles.jouer(n, "Use_Item" if ag.etat == "mange" else ("Sit_Floor_Idle" if ag.etat == "repos" else "Idle"))
			else:
				n.scale.y = 0.62 if ag.etat != "travaille" else 1.0   # assis
			continue
		n.scale.y = 1.0
		Modeles.jouer(n, "Walking_B" if ag.fatigue > 70.0 else "Walking_A")
		n.rotation.y = lerp_angle(n.rotation.y, atan2(plat.x, plat.z), min(1.0, delta * 8.0))
		var allure: float = 16.0 * (1.0 - ag.fatigue / 250.0)
		var pas: Vector3 = plat.normalized() * min(allure * delta, plat.length())
		n.position.x += pas.x
		n.position.z += pas.z
		n.position.y = Terrain.hauteur(n.position.x, n.position.z)


# =====================================================================
#  AGENTS : chaque ouvrier a ses besoins et décide seul, sauf ordre contraire
# =====================================================================
const PRENOMS := ["Kouadio", "Awa", "Yao", "Aminata", "Koffi", "Mariam", "Bakary", "Adjoua", "Seydou", "Affoué", "Ibrahim", "Akissi",
	"Moussa", "Fatou", "Konan", "Salimata", "Drissa", "Ama", "Lassina", "Aya", "Siaka", "Rokia", "Tiémoko", "Nafi"]
var agents: Array = []
var point_repas := Vector3(20, 0, -150)
var point_repos := Vector3(20, 0, -110)
var repas_fournis := true
var heure_agents := 6.0
var evenements_agents: Array = []   # messages à afficher par le jeu

## Crée l'équipe : roles = tableau de chaînes (« manœuvre », « maçon », « riziculteur »)
func creer_equipe(roles: Array) -> void:
	agents = []
	for i in min(roles.size(), ouvriers.size()):
		agents.append({"nom": PRENOMS[i % PRENOMS.size()], "role": roles[i], "fatigue": rng.randf_range(0, 15), "faim": rng.randf_range(10, 25),
			"etat": "travaille", "ordre": "auto", "travail_h": 0.0, "absent_demain": false,
			"endurance": rng.randf_range(0.8, 1.25), "appetit": rng.randf_range(0.8, 1.25),
			"seuil_faim": rng.randf_range(60, 80), "seuil_fatigue": rng.randf_range(70, 88)})
	n_actifs = agents.size()
	heure_agents = 6.0
	placer_ouvriers()

func ordre_a_tous(ordre: String) -> void:
	for a in agents:
		a.ordre = ordre

## Fait vivre les agents pendant dt_h heures simulées (par pas d'une demi-heure au plus)
func simuler_agents(dt_h: float, pluie_forte: bool) -> void:
	var reste := dt_h
	while reste > 0.0001:
		var dt: float = min(reste, 0.5)
		reste -= dt
		var avant := heure_agents
		heure_agents = fmod(heure_agents + dt, 24.0)
		var reveil: bool = avant < 6.0 and heure_agents >= 6.0
		var jour: bool = heure_agents >= 6.0 and heure_agents < 18.0
		for a in agents:
			if reveil:
				a.etat = "absent" if a.absent_demain else "travaille"
				a.absent_demain = false
				a.faim = min(a.faim, 20.0)        # petit-déjeuner
			if a.etat == "absent":
				a.fatigue = max(0.0, a.fatigue - 6.0 * dt)
				continue
			if not jour:
				a.etat = "dort"
				a.fatigue = max(0.0, a.fatigue - 9.0 * dt)
				a.faim = min(100.0, a.faim + 1.5 * dt * a.appetit)
				continue
			# Décision : l'ordre du chef d'abord, sinon ses propres besoins
			match a.ordre:
				"repos": a.etat = "repos"
				"manger": a.etat = "mange"
				"forcer": a.etat = "travaille"
				_:
					if a.etat == "mange" and a.faim > 12.0:
						pass
					elif a.etat == "repos" and a.fatigue > 45.0:
						pass
					elif a.faim > a.seuil_faim:
						a.etat = "mange"
					elif a.fatigue > a.seuil_fatigue:
						a.etat = "repos"
					else:
						a.etat = "travaille"
			if a.ordre == "manger" and a.faim <= 10.0:
				a.ordre = "auto"
			if a.ordre == "repos" and a.fatigue <= 20.0:
				a.ordre = "auto"
			match a.etat:
				"travaille":
					var chaleur: float = 1.4 if heure_agents >= 12.0 and heure_agents < 15.0 else 1.0
					a.fatigue = min(100.0, a.fatigue + 6.5 * dt * chaleur / a.endurance)
					a.faim = min(100.0, a.faim + 7.0 * dt * a.appetit)
					var eff: float = clamp(1.0 - max(0.0, a.fatigue - 50.0) / 70.0, 0.3, 1.0) * (0.6 if a.faim > 85.0 else 1.0)
					a.travail_h += dt * eff * (0.3 if pluie_forte else 1.0)
					if a.fatigue >= 100.0 and not a.absent_demain:
						a.absent_demain = true
						evenements_agents.append("%s (%s) est épuisé : il ne viendra pas demain." % [a.nom, a.role])
				"repos":
					a.fatigue = max(0.0, a.fatigue - 22.0 * dt)
					a.faim = min(100.0, a.faim + 3.0 * dt * a.appetit)
				"mange":
					a.faim = max(0.0, a.faim - (70.0 if repas_fournis else 30.0) * dt)   # sans cantine : aller-retour au village
					a.fatigue = max(0.0, a.fatigue - 5.0 * dt)

## Heures de travail efficaces du jour pour un rôle, puis remise à zéro
func relever_travail(role: String) -> float:
	var h := 0.0
	for a in agents:
		if a.role == role:
			h += a.travail_h
			a.travail_h = 0.0
	return h

func resume_equipe() -> String:
	var c := {"travaille": 0, "mange": 0, "repos": 0, "dort": 0, "absent": 0}
	var f := 0.0
	for a in agents:
		c[a.etat] += 1
		f += a.fatigue
	return "%d au travail · %d mangent · %d se reposent · %d absents — fatigue moyenne %d %%" % [c.travaille, c.mange, c.repos, c.absent, int(f / max(agents.size(), 1))]

## Indice de l'agent le plus proche d'un point du terrain (-1 si aucun à moins de 14 m)
func agent_proche(p: Vector3) -> int:
	var best := -1
	var dmin := 14.0
	for i in min(agents.size(), ouvriers.size()):
		var n: Node3D = ouvriers[i]
		if n.visible and n.position.distance_to(p) < dmin:
			dmin = n.position.distance_to(p)
			best = i
	return best


func placer_ouvriers() -> void:
	var pr := zone
	point_repas.y = Terrain.hauteur(point_repas.x, point_repas.z)
	point_repos.y = Terrain.hauteur(point_repos.x, point_repos.z)
	for o in ouvriers:
		var x := rng.randf_range(pr.position.x, pr.end.x)
		var z := rng.randf_range(pr.position.y, pr.end.y)
		o.position = Vector3(x, Terrain.hauteur(x, z), z)
		o.set_meta("cible", Vector3.ZERO)
