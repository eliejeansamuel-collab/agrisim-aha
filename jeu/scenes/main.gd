extends Control
## AgriSim AHA — jeu de stratégie : interface tactile (carte, initiatives, équipes, événements).
## Toute la simulation est dans moteur/region.gd ; ce fichier ne fait qu'afficher et transmettre les ordres.

const SAUVEGARDE := "user://partie.dat"
const DUREES := [0.0, 1.6, 0.7, 0.22]
const ONGLETS := [["etudes", "Études"], ["ouvrages", "Ouvrages"], ["organisation", "Organisation"]]
const CLIMATS := [["san_pedro", "San-Pédro"], ["abidjan", "Abidjan"], ["man", "Man"], ["bouake", "Bouaké"], ["korhogo", "Korhogo"]]
const C_FOND := Color(0.07, 0.10, 0.12)
const C_PANNEAU := Color(0.11, 0.15, 0.18, 0.97)
const C_ACCENT := Color(0.95, 0.72, 0.22)
const C_EAU := Color(0.25, 0.6, 0.9)

var r: Region
var vitesse := 0
var chrono := 0.0
var zone_sel := -1
var mode_carte := 0            # 0 adhésion, 1 eau, 2 réseau
var onglet := "etudes"
var init_sel := ""
var temps := 0.0
var choix_depart := {"climat": "san_pedro", "difficulte": 1, "profil": "ingenieur"}

var carte: Control
var barre: HBoxContainer
var l_date: Label
var l_budget: Label
var l_stab: Label
var jauge: ProgressBar
var b_vitesse: Array = []
var bandeau: Label
var p_zone: PanelContainer
var couche: Control             # panneaux plein écran
var bas: HBoxContainer
var auto := ""
var auto_etape := 0
var auto_attente := 0.0

func _ready() -> void:
	var th := Theme.new()
	th.default_font_size = 20
	theme = th
	set_anchors_preset(Control.PRESET_FULL_RECT)
	carte = Control.new()
	carte.set_anchors_preset(Control.PRESET_FULL_RECT)
	carte.draw.connect(_dessiner_carte)
	carte.gui_input.connect(_toucher_carte)
	add_child(carte)
	_construire_hud()
	couche = Control.new()
	couche.set_anchors_preset(Control.PRESET_FULL_RECT)
	couche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(couche)
	auto = OS.get_environment("AGRISIM_AUTO")
	_ecran_depart()

# ------------------------------------------------------------------ aides d'interface

func _style(c: Color, rayon := 10, marge := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(rayon)
	s.set_content_margin_all(marge)
	return s

func _bouton(texte: String, action: Callable, largeur := 0.0, couleur := Color(0.2, 0.27, 0.32)) -> Button:
	var b := Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(largeur, 54)
	b.add_theme_stylebox_override("normal", _style(couleur))
	b.add_theme_stylebox_override("hover", _style(couleur.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", _style(couleur.lightened(0.25)))
	b.add_theme_stylebox_override("disabled", _style(couleur.darkened(0.35)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if action.is_valid():
		b.pressed.connect(action)
	return b

func _texte(t: String, taille := 20, couleur := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _panneau(c := C_PANNEAU) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(c, 14, 16))
	return p

func _vider(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

func _plein_ecran(titre: String, avec_fermer := true) -> VBoxContainer:
	_vider(couche)
	couche.mouse_filter = Control.MOUSE_FILTER_STOP
	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, 0.6)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	couche.add_child(voile)
	var p := _panneau()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.offset_left = 40; p.offset_top = 24; p.offset_right = -40; p.offset_bottom = -24
	couche.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	var t := _texte(titre, 28, C_ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	if avec_fermer:
		var f := _bouton("Fermer", _fermer, 130, Color(0.45, 0.2, 0.2))
		f.name = "Fermer"
		h.add_child(f)
	return v

func _fermer() -> void:
	_vider(couche)
	couche.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ouvert() -> bool:
	return couche.get_child_count() > 0

# ------------------------------------------------------------------ écran de départ

func _ecran_depart() -> void:
	barre.visible = false; bas.visible = false; bandeau.visible = false; p_zone.visible = false
	var v := _plein_ecran("AgriSim AHA — Aménager une région", false)
	v.add_child(_texte("Tu diriges un projet d'aménagement hydro-agricole en Côte d'Ivoire. Finance des études, des ouvrages et l'organisation des producteurs pour mettre en valeur toutes les zones avant que le bailleur ne perde confiance. La carte est fictive ; le climat suit des ordres de grandeur de la région choisie.", 19))
	var lignes := [
		["Région (climat)", "climat", CLIMATS],
		["Difficulté", "difficulte", [[0, "Facile"], [1, "Normale"], [2, "Difficile"]]],
		["Profil du chef de projet", "profil", Region.PROFILS.keys().map(func(k): return [k, Region.PROFILS[k]["nom"]])],
	]
	for ligne in lignes:
		v.add_child(_texte(ligne[0], 18, C_ACCENT))
		var h := HFlowContainer.new()
		v.add_child(h)
		for opt in ligne[2]:
			var actif: bool = choix_depart[ligne[1]] == opt[0]
			var cle: String = ligne[1]
			var val: Variant = opt[0]
			h.add_child(_bouton(opt[1], func(): choix_depart[cle] = val; _ecran_depart(), 170, Color(0.2, 0.5, 0.3) if actif else Color(0.2, 0.27, 0.32)))
	v.add_child(_texte(Region.PROFILS[choix_depart["profil"]]["desc"], 18, Color(0.8, 0.85, 0.9)))
	var esp := Control.new()
	esp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(esp)
	var h2 := HBoxContainer.new()
	h2.add_theme_constant_override("separation", 16)
	v.add_child(h2)
	var bc := _bouton("Commencer", _commencer, 260, Color(0.2, 0.5, 0.3))
	bc.name = "Commencer"
	h2.add_child(bc)
	if FileAccess.file_exists(SAUVEGARDE):
		h2.add_child(_bouton("Reprendre la partie", _reprendre, 260))

func _commencer() -> void:
	r = Region.new()
	var g := int(OS.get_environment("AGRISIM_GRAINE")) if OS.get_environment("AGRISIM_GRAINE") != "" else randi()
	r.nouvelle(g, choix_depart["climat"], choix_depart["difficulte"], choix_depart["profil"])
	_entrer_en_jeu()

func _reprendre() -> void:
	r = Region.new()
	if r.restaurer(SAUVEGARDE):
		_entrer_en_jeu()
	else:
		_commencer()

func _entrer_en_jeu() -> void:
	_fermer()
	barre.visible = true; bas.visible = true; bandeau.visible = true
	zone_sel = -1
	_vitesse(0)
	_rafraichir()

# ------------------------------------------------------------------ HUD

func _construire_hud() -> void:
	barre = HBoxContainer.new()
	barre.set_anchors_preset(Control.PRESET_TOP_WIDE)
	barre.offset_left = 10; barre.offset_right = -10; barre.offset_top = 8
	barre.add_theme_constant_override("separation", 10)
	add_child(barre)
	l_date = _texte("", 20)
	l_date.custom_minimum_size.x = 300
	l_date.autowrap_mode = TextServer.AUTOWRAP_OFF
	barre.add_child(l_date)
	var noms := ["Pause", ">", ">>", ">>>"]
	for i in 4:
		var b := _bouton(noms[i], _vitesse.bind(i), 74)
		b_vitesse.append(b)
		barre.add_child(b)
	l_budget = _texte("", 22, C_ACCENT)
	l_budget.custom_minimum_size.x = 190
	l_budget.autowrap_mode = TextServer.AUTOWRAP_OFF
	barre.add_child(l_budget)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barre.add_child(vb)
	var lc := _texte("Confiance du bailleur", 15, Color(0.8, 0.85, 0.9))
	vb.add_child(lc)
	jauge = ProgressBar.new()
	jauge.custom_minimum_size = Vector2(160, 20)
	jauge.show_percentage = false
	jauge.add_theme_stylebox_override("background", _style(Color(0.2, 0.2, 0.2), 6, 0))
	vb.add_child(jauge)
	l_stab = _texte("", 20)
	l_stab.autowrap_mode = TextServer.AUTOWRAP_OFF
	barre.add_child(l_stab)
	barre.add_child(_bouton("Menu", _menu, 90))

	bas = HBoxContainer.new()
	bas.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bas.offset_left = 10; bas.offset_bottom = -44; bas.offset_top = -104
	bas.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bas.add_theme_constant_override("separation", 8)
	add_child(bas)
	for o in ONGLETS:
		var b := _bouton(o[1], _ouvrir_initiatives.bind(o[0]), 150, Color(0.16, 0.36, 0.42))
		b.name = "Onglet_" + o[0]
		bas.add_child(b)
	bas.add_child(_bouton("Eau", _panneau_eau, 90, Color(0.15, 0.3, 0.5)))
	bas.add_child(_bouton("Journal", _panneau_journal, 110))
	var bm := _bouton("Carte : adhésion", Callable(), 200)
	bm.pressed.connect(func():
		mode_carte = (mode_carte + 1) % 3
		bm.text = "Carte : " + ["adhésion", "eau", "réseau"][mode_carte])
	bas.add_child(bm)

	bandeau = _texte("", 17, Color(0.9, 0.9, 0.8))
	bandeau.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bandeau.offset_left = 12; bandeau.offset_right = -12; bandeau.offset_top = -36; bandeau.offset_bottom = -6
	bandeau.autowrap_mode = TextServer.AUTOWRAP_OFF
	bandeau.clip_text = true
	add_child(bandeau)

	p_zone = _panneau()
	p_zone.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	p_zone.offset_left = -360; p_zone.offset_right = -10; p_zone.offset_top = 78; p_zone.offset_bottom = -44
	p_zone.visible = false
	add_child(p_zone)

func _vitesse(v: int) -> void:
	vitesse = v
	for i in 4:
		b_vitesse[i].add_theme_stylebox_override("normal", _style(Color(0.2, 0.5, 0.3) if i == v else Color(0.2, 0.27, 0.32)))

func _menu() -> void:
	_vitesse(0)
	var v := _plein_ecran("Menu")
	v.add_child(_texte("La partie est enregistrée automatiquement. Tu peux la reprendre depuis l'écran de départ.", 19))
	v.add_child(_bouton("Enregistrer et revenir à l'écran de départ", func(): r.sauver(SAUVEGARDE); r = null; _ecran_depart(), 520))
	v.add_child(_texte("Comment jouer : lance des initiatives (Études, Ouvrages, Organisation). Elles se déploient zone par zone depuis le chef-lieu. Une zone est mise en valeur quand elle est équipée, alimentée en eau, que le foncier est sécurisé et que la population adhère. Touche une zone pour voir ce qui lui manque et y envoyer une équipe en cas de crise. Dépenser vite fait monter les prix et le risque de détournement.", 18, Color(0.8, 0.85, 0.9)))

func _process(dt: float) -> void:
	temps += dt
	carte.queue_redraw()
	if r == null:
		if auto != "":
			_pilote(dt)
		return
	if auto != "":
		_pilote(dt)
	if vitesse > 0 and r.fin == "" and r.evenement.is_empty() and not _ouvert():
		chrono += dt
		if chrono >= DUREES[vitesse]:
			chrono = 0.0
			_decade()

func _decade() -> void:
	r.avancer()
	if r.decade % 3 == 0:
		r.sauver(SAUVEGARDE)
	_rafraichir()
	if not r.evenement.is_empty():
		_popup_evenement()
	elif r.fin != "":
		_ecran_fin()

func _rafraichir() -> void:
	if r == null:
		return
	l_date.text = r.date_texte()
	l_budget.text = "%d M FCFA" % int(r.budget)
	l_budget.add_theme_color_override("font_color", Color(0.95, 0.4, 0.35) if r.budget < 0 else C_ACCENT)
	jauge.value = r.reputation
	var cj := Color(0.3, 0.75, 0.4) if r.reputation > 50 else (Color(0.9, 0.7, 0.2) if r.reputation > 25 else Color(0.9, 0.3, 0.25))
	jauge.add_theme_stylebox_override("fill", _style(cj, 6, 0))
	l_stab.text = "Zones : %d/%d" % [r.nb_stabilisees(), r.zones.size()]
	if not r.journal.is_empty():
		bandeau.text = r.journal[-1]["t"]
	if zone_sel >= 0:
		_panneau_zone()

# ------------------------------------------------------------------ carte

func _transfo() -> Array:
	var s := carte.size
	var haut := 70.0
	var basm := 110.0
	var ech: float = min(s.x / 1000.0, (s.y - haut - basm) / 600.0)
	var orig := Vector2((s.x - 1000.0 * ech) * 0.5, haut + (s.y - haut - basm - 600.0 * ech) * 0.5)
	if p_zone.visible:
		orig.x = max(0.0, orig.x - 150.0)
	return [ech, orig]

func _couleur_zone(z: Dictionary) -> Color:
	var v := 0.0
	match mode_carte:
		0: v = float(z["adhesion"]) / 100.0
		1: v = float(z["eau"]) if r.niv("o_canaux", z["id"]) > 0.0 else 0.0
		2: v = r.score(z)["reseau"] / 100.0
	var bas_c := Color(0.42, 0.25, 0.18)
	var mil := Color(0.62, 0.55, 0.25)
	var haut_c := Color(0.25, 0.55, 0.28)
	if mode_carte == 1:
		bas_c = Color(0.4, 0.33, 0.25); mil = Color(0.3, 0.45, 0.55); haut_c = Color(0.2, 0.5, 0.85)
	var c := bas_c.lerp(mil, v * 2.0) if v < 0.5 else mil.lerp(haut_c, (v - 0.5) * 2.0)
	if z["stabilisee"] and mode_carte == 0:
		c = Color(0.2, 0.68, 0.35)
	return c

func _dessiner_carte() -> void:
	if r == null:
		return
	var t := _transfo()
	var ech: float = t[0]
	var orig: Vector2 = t[1]
	var police := ThemeDB.fallback_font
	for z in r.zones:
		var pts := PackedVector2Array()
		for p in z["poly"]:
			pts.append(orig + p * ech)
		if pts.size() < 3:
			continue
		carte.draw_colored_polygon(pts, _couleur_zone(z))
		pts.append(pts[0])
		carte.draw_polyline(pts, Color(0.05, 0.07, 0.08), 3.0 if z["id"] != zone_sel else 2.0, true)
	if zone_sel >= 0:
		var ps := PackedVector2Array()
		for p in r.zones[zone_sel]["poly"]:
			ps.append(orig + p * ech)
		ps.append(ps[0])
		carte.draw_polyline(ps, Color.WHITE, 4.0, true)
	# rivière, barrage, prise
	var riv := PackedVector2Array()
	for p in r.riviere:
		if Geometry2D.is_point_in_polygon(p, r.contour):
			riv.append(orig + p * ech)
	if riv.size() >= 2:
		carte.draw_polyline(riv, C_EAU, 6.0 * ech + 2.0, true)
		if r.achetes.has("o_barrage"):
			var pb := riv[1]
			var plein: float = clamp(r.retenue / Region.CAP_RETENUE, 0.0, 1.0)
			carte.draw_circle(pb + Vector2(0, -16 * ech), (14.0 + 16.0 * plein) * ech, Color(C_EAU, 0.85 if r.fait("o_barrage") else 0.3))
			carte.draw_line(pb + Vector2(-26, 4) * ech, pb + Vector2(26, 4) * ech, Color(0.75, 0.75, 0.7), 7.0 * ech, true)
		if r.achetes.has("o_prise"):
			var pp := riv[min(3, riv.size() - 1)]
			carte.draw_rect(Rect2(pp - Vector2(9, 9) * ech, Vector2(18, 18) * ech), Color(0.85, 0.85, 0.8) if r.fait("o_prise") else Color(0.5, 0.5, 0.5))
	# étiquettes, incidents, équipes
	for z in r.zones:
		var c: Vector2 = orig + z["centre"] * ech
		var nom: String = z["nom"]
		var taille := int(clamp(15.0 * ech + 3.0, 12.0, 20.0))
		var larg := police.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		carte.draw_string_outline(police, c + Vector2(-larg * 0.5, -6), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, 4, Color(0, 0, 0, 0.7))
		carte.draw_string(police, c + Vector2(-larg * 0.5, -6), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color.WHITE)
		# petite barre d'équipement
		var eq := r.niv("o_canaux", z["id"])
		if eq > 0.0:
			carte.draw_rect(Rect2(c + Vector2(-24, 2), Vector2(48, 6)), Color(0, 0, 0, 0.5))
			carte.draw_rect(Rect2(c + Vector2(-24, 2), Vector2(48 * eq, 6)), Color(0.85, 0.85, 0.8))
		if z["stabilisee"]:
			_etoile(c + Vector2(0, 26), 11.0, Color(1, 0.9, 0.3))
		var inc: Dictionary = z["incident"]
		if not inc.is_empty():
			var pc := c + Vector2(0, 30)
			var puls := 1.0 + 0.15 * sin(temps * 5.0)
			var g: float = float(inc["gravite"]) / 100.0
			carte.draw_circle(pc, 17.0 * puls, Color(0.85, 0.15, 0.1, 0.9))
			carte.draw_arc(pc, 21.0, -PI / 2, -PI / 2 + TAU * g, 24, Color(1, 0.85, 0.3), 4.0, true)
			carte.draw_string(police, pc + Vector2(-4, 8), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	for i in r.equipes.size():
		var e: Dictionary = r.equipes[i]
		var pz: Vector2 = orig + r.zones[e["zone"]]["centre"] * ech + Vector2(-34 + 30 * (i % 3), -46)
		if e["dest"] >= 0:
			var pd: Vector2 = orig + r.zones[e["dest"]]["centre"] * ech + Vector2(0, -46)
			carte.draw_dashed_line(pz, pd, Color(1, 1, 1, 0.6), 2.0, 8.0)
		var ce := Color(0.3, 0.55, 0.95) if e["type"] == "mediation" else Color(0.95, 0.6, 0.2)
		carte.draw_circle(pz, 14.0, Color.WHITE)
		carte.draw_circle(pz, 12.0, ce)
		carte.draw_string(police, pz + Vector2(-7, 7), "M" if e["type"] == "mediation" else "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

func _etoile(c: Vector2, rayon: float, couleur: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + TAU * i / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * (rayon if i % 2 == 0 else rayon * 0.45))
	carte.draw_colored_polygon(pts, couleur)

func _toucher_carte(ev: InputEvent) -> void:
	if r == null or _ouvert():
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var t := _transfo()
		var p: Vector2 = (ev.position - t[1]) / t[0]
		zone_sel = -1
		for z in r.zones:
			if Geometry2D.is_point_in_polygon(p, z["poly"]):
				zone_sel = z["id"]
		p_zone.visible = zone_sel >= 0
		if zone_sel >= 0:
			_panneau_zone()

# ------------------------------------------------------------------ panneau de zone

func _barre_valeur(v: VBoxContainer, nom: String, val: float, couleur: Color) -> void:
	var h := HBoxContainer.new()
	v.add_child(h)
	var l := _texte(nom, 17)
	l.custom_minimum_size.x = 110
	h.add_child(l)
	var pb := ProgressBar.new()
	pb.value = val
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(120, 18)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.add_theme_stylebox_override("background", _style(Color(0.2, 0.2, 0.2), 5, 0))
	pb.add_theme_stylebox_override("fill", _style(couleur, 5, 0))
	h.add_child(pb)
	var n := _texte("%d" % int(val), 17)
	n.custom_minimum_size.x = 36
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(n)

func _panneau_zone() -> void:
	_vider(p_zone)
	var z: Dictionary = r.zones[zone_sel]
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p_zone.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	v.add_child(_texte(z["nom"], 23, C_ACCENT))
	var sol: String = ("sol " + str(z["sol"])) if r.fait("e_pedo") else "sol inconnu (étude pédologique)"
	v.add_child(_texte("%s · %d ha · %s" % [Region.NOMS_TYPE[z["type"]], int(z["surface"]), sol], 16, Color(0.8, 0.85, 0.9)))
	if z["stabilisee"]:
		v.add_child(_texte("Zone mise en valeur", 18, Color(0.4, 0.9, 0.5)))
	var s := r.score(z)
	_barre_valeur(v, "Adhésion", z["adhesion"], Color(0.3, 0.7, 0.4))
	_barre_valeur(v, "Eau", s["eau"], C_EAU)
	_barre_valeur(v, "Réseau", s["reseau"], Color(0.8, 0.8, 0.75))
	_barre_valeur(v, "Foncier", s["foncier"], Color(0.75, 0.55, 0.3))
	_barre_valeur(v, "Appui", s["appui"], Color(0.7, 0.5, 0.8))
	var modes := {"gravitaire": "par gravité", "pompe": "par pompage", "forage": "par forages", "aucun": "aucun accès à l'eau"}
	v.add_child(_texte("Équipé : %d ha · alimentation %s" % [int(r.surface_equipee(z)), modes[r._mode_eau(z)]], 16))
	v.add_child(_texte("Efficience du réseau : %d %% · état des ouvrages : %d %%" % [int(r.efficience(z) * 100.0), int(z["etat"])], 16))
	if float(z["rdt"]) > 0.0:
		v.add_child(_texte("Dernier rendement irrigué : %.1f t/ha" % z["rdt"], 16))
	# ce qui manque
	var manque: Array = []
	if s["reseau"] < 70.0: manque.append("réseau (canaux, casiers)")
	if r._mode_eau(z) == "aucun": manque.append("accès à l'eau")
	elif float(z["eau"]) < 0.6: manque.append("eau en quantité suffisante")
	if s["foncier"] < 60.0: manque.append("foncier sécurisé")
	if float(z["adhesion"]) < 68.0: manque.append("adhésion (68 au moins)")
	if not z["stabilisee"] and not manque.is_empty():
		v.add_child(_texte("Il manque : " + ", ".join(manque) + ".", 16, Color(0.95, 0.75, 0.5)))
	var inc: Dictionary = z["incident"]
	if not inc.is_empty():
		v.add_child(_texte("%s — gravité %d %%" % [Region.NOMS_INCIDENT[inc["type"]], int(inc["gravite"])], 18, Color(1, 0.45, 0.4)))
		v.add_child(_texte("À traiter par : " + ("une équipe de médiation" if str(inc["type"]).begins_with("conflit") else "une brigade d'entretien"), 16))
	for i in r.equipes.size():
		var e: Dictionary = r.equipes[i]
		var nom := ("Médiation" if e["type"] == "mediation" else "Brigade") + " %d" % (i + 1)
		if e["zone"] == zone_sel and e["dest"] < 0:
			v.add_child(_texte(nom + " : sur place", 16, Color(0.6, 0.85, 1)))
		elif e["dest"] == zone_sel:
			v.add_child(_texte(nom + " : en route", 16, Color(0.6, 0.85, 1)))
		else:
			v.add_child(_bouton("Envoyer %s ici" % nom, func(): r.envoyer(i, zone_sel); _panneau_zone(), 0, Color(0.2, 0.35, 0.55)))
	if r.equipes.is_empty() and not inc.is_empty():
		v.add_child(_texte("Tu n'as aucune équipe : voir l'onglet Organisation.", 16, Color(0.95, 0.75, 0.5)))

# ------------------------------------------------------------------ initiatives

func _ouvrir_initiatives(o: String) -> void:
	onglet = o
	var v := _plein_ecran("Initiatives — budget %d M FCFA" % int(r.budget))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	for og in ONGLETS:
		h.add_child(_bouton(og[1], _ouvrir_initiatives.bind(og[0]), 190, Color(0.16, 0.36, 0.42) if og[0] == o else Color(0.2, 0.27, 0.32)))
	var info := _texte("Prix : +%d %%   ·   Détournements : %d %%" % [int(r.tension_prix), int(r.detournement)], 18, Color(0.95, 0.75, 0.5) if r.tension_prix > 15 or r.detournement > 20 else Color(0.8, 0.85, 0.9))
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(info)
	var corps := HBoxContainer.new()
	corps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corps.add_theme_constant_override("separation", 14)
	v.add_child(corps)
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_stretch_ratio = 1.25
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	corps.add_child(sc)
	var grille := GridContainer.new()
	grille.columns = 2
	grille.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grille.add_theme_constant_override("h_separation", 8)
	grille.add_theme_constant_override("v_separation", 8)
	sc.add_child(grille)
	var premier := ""
	for id in r.ordre_defs:
		var d: Dictionary = r.defs[id]
		if d["onglet"] != o:
			continue
		if premier == "":
			premier = id
		var etat := "%d M" % int(r.prix(id))
		var coul := Color(0.2, 0.27, 0.32)
		if r.achetes.has(id):
			var p := _progression(id)
			etat = "fait" if p >= 1.0 else "en cours %d %%" % int(p * 100.0)
			coul = Color(0.18, 0.42, 0.26) if p >= 1.0 else Color(0.35, 0.38, 0.2)
		elif r.blocage(id) != "":
			coul = Color(0.16, 0.18, 0.2)
		if id == init_sel:
			coul = coul.lightened(0.18)
		var b := _bouton("%s\n%s" % [d["nom"], etat], func(): init_sel = id; _ouvrir_initiatives(o), 0, coul)
		b.name = "Init_" + id
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 70
		b.add_theme_font_size_override("font_size", 18)
		grille.add_child(b)
	if init_sel == "" or r.defs[init_sel]["onglet"] != o:
		init_sel = premier
	# détail
	var pd := _panneau(Color(0.14, 0.19, 0.23))
	pd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corps.add_child(pd)
	var vd := VBoxContainer.new()
	vd.add_theme_constant_override("separation", 10)
	pd.add_child(vd)
	var d: Dictionary = r.defs[init_sel]
	vd.add_child(_texte(d["nom"], 24, C_ACCENT))
	vd.add_child(_texte(d["desc"], 18))
	vd.add_child(_texte("Cours : " + str(d["cours"]), 16, Color(0.6, 0.85, 1)))
	vd.add_child(_texte("Portée : " + ("toute la région, %d décades" % int(d["duree"]) if d["portee"] == "globale" else "zone par zone depuis le chef-lieu, %d décades par zone" % int(d["duree"])), 16, Color(0.8, 0.85, 0.9)))
	var esp := Control.new()
	esp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vd.add_child(esp)
	var bl := r.blocage(init_sel)
	if r.achetes.has(init_sel):
		vd.add_child(_texte("Avancement : %d %%" % int(_progression(init_sel) * 100.0), 20, Color(0.5, 0.9, 0.6)))
	else:
		if bl != "":
			vd.add_child(_texte(bl, 18, Color(1, 0.55, 0.45)))
		var ba := _bouton("Lancer — %d M FCFA" % int(r.prix(init_sel)), func(): r.acheter(init_sel); _rafraichir(); _ouvrir_initiatives(o), 0, Color(0.2, 0.5, 0.3))
		ba.name = "Lancer"
		ba.disabled = bl != ""
		vd.add_child(ba)

func _progression(id: String) -> float:
	var a: Dictionary = r.achetes[id]
	if r.defs[id]["portee"] == "globale" or float(a["p"]) >= 1.0:
		return float(a["p"])
	var s := 0.0
	var n := 0
	for z in r.zones:
		if r.concerne(id, z):
			n += 1
			s += float(a["z"].get(z["id"], 0.0))
	return s / max(n, 1)

# ------------------------------------------------------------------ eau, journal

func _panneau_eau() -> void:
	var v := _plein_ecran("Ressource en eau et besoins")
	var e: Dictionary = r.eau
	var q := r.qfc_pointe()
	var lignes: Array = []
	lignes.append("Pluie de la décade : %d mm (mois de %s, année %s)." % [int(e.get("pluie", 0.0)), Region.MOIS[r.mois()], "humide" if r.facteur_pluie > 1.1 else ("sèche" if r.facteur_pluie < 0.9 else "normale")])
	if r.fait("e_hydro"):
		lignes.append("Apport de la rivière : %.2f m³/s en moyenne sur la décade." % (float(e.get("apport", 0.0)) / 864000.0))
	else:
		lignes.append("Apport de la rivière : inconnu. Il faut une étude hydrologique pour le mesurer.")
	if r.achetes.has("o_barrage"):
		lignes.append("Retenue : %.1f millions de m³ sur %.1f (%d %%). Évacuateur dimensionné pour une crue de période de retour %d ans." % [r.retenue / 1e6, Region.CAP_RETENUE / 1e6, int(100.0 * r.retenue / Region.CAP_RETENUE), int(r.evac_T)])
	if r.fait("e_clim"):
		lignes.append("Débit fictif continu de pointe : %.2f L/s/ha (ETc du riz, pluie efficace, percolation, efficience 50 %%)." % q)
	else:
		lignes.append("Débit fictif continu de pointe : environ %.1f L/s/ha — estimation grossière, sans étude agro-climatique." % (q * 0.65))
	var be := float(e.get("besoin", 0.0))
	lignes.append("Besoin brut de la décade : %.2f millions de m³ · servi : %d %%." % [be / 1e6, int(100.0 * float(e.get("recu", 0.0)) / be) if be > 0.0 else 100])
	if r.fait("e_clim") and r.fait("e_hydro"):
		var b := r.bilan_previsionnel()
		lignes.append("Saison sèche : besoin brut d'environ %d m³/ha ; ressource attendue %.1f millions de m³ ; surface irrigable ≈ %d ha pour %d ha équipés et raccordés." % [int(b["besoin_ha"]), b["ressource"] / 1e6, int(b["irrigable"]), int(b["surface"])])
	else:
		lignes.append("Saison sèche : la surface irrigable ne peut pas être calculée sans les études agro-climatique et hydrologique.")
	var partage := 0
	for z in r.zones:
		if r.niv("g_aue", z["id"]) >= 0.5: partage += 1
	lignes.append("Partage de l'eau : " + ("tour d'eau, répartition équitable." if partage * 2 >= r.zones.size() or r.tour_eau_prov > 0 else "l'amont (le nord) se sert d'abord ; l'aval prend ce qui reste."))
	if e.get("pompe", 0.0) > 0.0:
		lignes.append("Pompage : %d milliers de m³ cette décade, %s." % [int(e["pompe"] / 1000.0), "solaire" if r.fait("o_solaire") else "au gasoil"])
	for l in lignes:
		v.add_child(_texte(l, 19))

func _panneau_journal() -> void:
	var v := _plein_ecran("Journal du projet")
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var vv := VBoxContainer.new()
	vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vv)
	for i in range(r.journal.size() - 1, max(-1, r.journal.size() - 60), -1):
		var j: Dictionary = r.journal[i]
		var dd: int = j["d"]
		vv.add_child(_texte("%s %d — %s" % [Region.MOIS[(dd % 36) / 3], r.annee0 + dd / 36, j["t"]], 17))

# ------------------------------------------------------------------ événements, fin

func _popup_evenement() -> void:
	var ev: Dictionary = r.evenement
	var v := _plein_ecran(ev["titre"], false)
	v.add_child(_texte(ev["texte"], 21))
	var esp := Control.new()
	esp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(esp)
	for i in ev["choix"].size():
		var b := _bouton(ev["choix"][i]["texte"], func():
			var lecon: String = ev["lecon"]
			var suite := r.repondre(i)
			_rafraichir()
			var v2 := _plein_ecran(ev["titre"], false)
			v2.add_child(_texte(suite, 21))
			if lecon != "":
				v2.add_child(_texte(lecon, 18, Color(0.6, 0.85, 1)))
			var e2 := Control.new()
			e2.size_flags_vertical = Control.SIZE_EXPAND_FILL
			v2.add_child(e2)
			var bc := _bouton("Continuer", _fermer, 0, Color(0.2, 0.5, 0.3))
			bc.name = "Continuer"
			v2.add_child(bc), 0, Color(0.2, 0.35, 0.5))
		b.name = "Choix%d" % i
		v.add_child(b)

func _ecran_fin() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAUVEGARDE))
	var gagne := r.fin == "victoire"
	var v := _plein_ecran("Région mise en valeur" if gagne else "Projet clôturé par le bailleur", false)
	v.add_child(_texte("%.1f ans de projet · %d zones sur %d mises en valeur · %d M FCFA dépensés · %d tonnes de paddy produites." % [r.decade / 36.0, r.nb_stabilisees(), r.zones.size(), int(r.depense_totale), int(r.production_t)], 19))
	v.add_child(_texte("Ce que la partie t'apprend", 20, C_ACCENT))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var vv := VBoxContainer.new()
	vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vv.add_theme_constant_override("separation", 10)
	sc.add_child(vv)
	for l in r.lecons():
		vv.add_child(_texte("• " + l, 18))
	var b := _bouton("Nouvelle partie", func(): r = null; _ecran_depart(), 0, Color(0.2, 0.5, 0.3))
	b.name = "Nouvelle"
	v.add_child(b)

# ------------------------------------------------------------------ pilote automatique (tests et captures)

const PLAN := ["g_info", "e_topo", "e_foncier", "e_clim", "e_hydro", "e_socio", "o_prise", "o_canaux", "g_foncier", "g_marches",
	"g_mediation", "g_entretien", "e_pedo", "g_aue", "e_eie", "o_casiers", "g_brigade", "g_coop", "e_eau", "g_form", "o_barrage",
	"g_conseil", "o_pompe", "o_pistes", "o_revet", "g_audit", "o_digue", "o_drain", "g_redevance", "o_magasin", "g_marche"]

func _capture(nom: String) -> void:
	var dossier := OS.get_environment("AGRISIM_CAPTURES")
	if dossier == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dossier + "/" + nom + ".png")

func _clic(n: Node) -> bool:
	# vrai clic simulé au centre d'un contrôle, comme un doigt
	if n == null or not (n is Control) or not n.is_visible_in_tree():
		return false
	var p: Vector2 = n.get_global_rect().get_center()
	for presse in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = presse
		ev.position = p
		ev.global_position = p
		Input.parse_input_event(ev)
	return true

func _pilote(dt: float) -> void:
	auto_attente -= dt
	if auto_attente > 0.0:
		return
	auto_attente = 0.25
	if auto == "clics":
		_pilote_clics()
		return
	# mode « demo » : joue le plan en accéléré par appels directs et prend des captures
	match auto_etape:
		0:
			_capture("1_depart"); auto_etape = 1; auto_attente = 0.6
		1:
			_commencer(); auto_etape = 2
		2:
			var arret := int(OS.get_environment("AGRISIM_ARRET")) if OS.get_environment("AGRISIM_ARRET") != "" else 70
			while r.fin == "" and r.decade < arret:
				_tour_auto()
			_rafraichir()
			for z in r.zones:
				if not z["incident"].is_empty():
					zone_sel = z["id"]
			if zone_sel < 0: zone_sel = 3
			p_zone.visible = true
			_panneau_zone()
			auto_etape = 3; auto_attente = 0.6
		3:
			_capture("2_carte"); auto_etape = 4; auto_attente = 0.6
		4:
			init_sel = "o_barrage"; _ouvrir_initiatives("ouvrages"); auto_etape = 5; auto_attente = 0.6
		5:
			_capture("3_initiatives"); auto_etape = 6; auto_attente = 0.6
		6:
			_panneau_eau(); auto_etape = 7; auto_attente = 0.6
		7:
			_capture("4_eau"); auto_etape = 8; auto_attente = 0.6
		8:
			_fermer()
			r.evenement = r.ev_defs[0]
			_popup_evenement(); auto_etape = 9; auto_attente = 0.6
		9:
			_capture("5_evenement"); auto_etape = 10; auto_attente = 0.6
		10:
			r.evenement = {}
			while r.fin == "" and r.decade < 36 * 14:
				_tour_auto()
			if r.fin == "": r.fin = "defaite"
			_ecran_fin(); auto_etape = 11; auto_attente = 0.6
		11:
			_capture("6_fin"); auto_etape = 12; auto_attente = 0.8
		12:
			print("PILOTE demo terminé : ", r.fin, " décade ", r.decade)
			get_tree().quit()

var _plan_k := 0
func _tour_auto() -> void:
	if not r.evenement.is_empty():
		r.repondre(0)
	while _plan_k < PLAN.size() and (r.achetes.has(PLAN[_plan_k]) or r.blocage(PLAN[_plan_k]) == ""):
		if not r.achetes.has(PLAN[_plan_k]):
			r.acheter(PLAN[_plan_k])
		_plan_k += 1
	for ei in r.equipes.size():
		var e: Dictionary = r.equipes[ei]
		if e["dest"] >= 0 or not r.zones[e["zone"]]["incident"].is_empty():
			continue
		for z in r.zones:
			if not z["incident"].is_empty() and str(z["incident"]["type"]).begins_with("conflit") == (e["type"] == "mediation") and not r.equipe_dans(z["id"], e["type"]):
				r.envoyer(ei, z["id"])
				break
	r.avancer()

func _pilote_clics() -> void:
	# parcours par vrais clics : départ, achat d'une initiative, sélection d'une zone, vitesse, événement
	match auto_etape:
		0:
			if _clic(couche.find_child("Commencer", true, false)): auto_etape = 1
		1:
			if r != null and _clic(bas.find_child("Onglet_organisation", true, false)): auto_etape = 2
		2:
			if _clic(couche.find_child("Init_g_info", true, false)): auto_etape = 3
		3:
			if _clic(couche.find_child("Lancer", true, false)): auto_etape = 4
		4:
			if not r.achetes.has("g_info"):
				print("ÉCHEC clics : achat non pris en compte"); get_tree().quit(1)
			if _clic(couche.find_child("Fermer", true, false)): auto_etape = 5
		5:
			# toucher le centre d'une zone sur la carte
			var t := _transfo()
			var p: Vector2 = t[1] + r.zones[2]["centre"] * t[0]
			for presse in [true, false]:
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = presse; ev.position = p; ev.global_position = p
				Input.parse_input_event(ev)
			auto_etape = 6
		6:
			if zone_sel != 2:
				print("ÉCHEC clics : zone non sélectionnée (", zone_sel, ")"); get_tree().quit(1)
			_clic(b_vitesse[3]); auto_etape = 7
		7:
			if vitesse != 3:
				print("ÉCHEC clics : vitesse"); get_tree().quit(1)
			if _ouvert():
				var c := couche.find_child("Choix0", true, false)
				if c: _clic(c)
				else: _clic(couche.find_child("Continuer", true, false))
			if r.decade >= 30:
				print("PILOTE clics réussi : décade ", r.decade, ", événements vus ", r.ev_vus.size())
				get_tree().quit()
