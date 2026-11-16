extends SceneTree
## Parties automatiques pour vérifier et équilibrer le jeu de stratégie.
## godot --headless --path jeu -s tests/partie_auto.gd -- [verbeux]

const BONNE := ["g_info", "e_topo", "e_foncier", "e_clim", "e_hydro", "e_socio", "o_prise", "o_canaux", "g_foncier", "g_marches",
	"g_mediation", "g_entretien", "e_pedo", "g_aue", "e_eie", "o_casiers", "g_brigade", "g_coop", "e_eau", "g_form", "o_barrage", "g_conseil",
	"o_pompe", "o_pistes", "o_revet", "g_audit", "o_digue", "o_drain", "g_redevance", "o_magasin", "g_marche", "o_solaire", "o_forages"]
const HATIVE := ["o_canaux", "o_barrage", "o_casiers", "o_pompe", "o_revet", "g_redevance", "o_pistes", "o_magasin", "g_conseil", "g_coop"]

func jouer(graine: int, climat: String, diff: int, plan: Array, equipes: bool, verbeux: bool) -> Region:
	var r := Region.new()
	r.nouvelle(graine, climat, diff, "ingenieur")
	var k := 0
	while r.fin == "" and r.decade < 36 * 14:
		if not r.evenement.is_empty():
			r.repondre(0)
		while k < plan.size() and r.blocage(plan[k]) == "":
			r.acheter(plan[k])
			k += 1
		if k < plan.size() and r.achetes.has(plan[k]):
			k += 1
		if equipes:
			for ei in r.equipes.size():
				var e: Dictionary = r.equipes[ei]
				if e["dest"] >= 0:
					continue
				var zi: int = e["zone"]
				var ici: Dictionary = r.zones[zi]["incident"]
				if not ici.is_empty():
					continue
				var best := -1
				var g := 0.0
				for z in r.zones:
					if z["incident"].is_empty():
						continue
					var conflit: bool = str(z["incident"]["type"]).begins_with("conflit")
					if conflit == (e["type"] == "mediation") and float(z["incident"]["gravite"]) > g and not r.equipe_dans(z["id"], e["type"]):
						g = z["incident"]["gravite"]
						best = z["id"]
				if best >= 0:
					r.envoyer(ei, best)
		r.avancer()
		if verbeux and r.decade % 18 == 0:
			var adh := 0.0
			for z in r.zones:
				adh += z["adhesion"]
			print("  an %.1f  budget %5d  rép %5.1f  stab %2d/%d  adh %4.1f  tension %4.1f  dét %4.1f  achats %d/%d  eau %d%%" % [r.decade / 36.0, r.budget, r.reputation,
				r.nb_stabilisees(), r.zones.size(), adh / r.zones.size(), r.tension_prix, r.detournement, k, plan.size(),
				int(100.0 * r.eau.get("recu", 0.0) / max(r.eau.get("besoin", 0.0), 1.0))])
	return r

func _init() -> void:
	var verbeux := OS.get_cmdline_user_args().has("verbeux")
	var ok := 0
	var ko := 0
	for cas in [["rien", [], false, "defaite"], ["hâtive", HATIVE, false, "defaite"], ["bonne", BONNE, true, "victoire"]]:
		for climat in ["san_pedro", "korhogo", "bouake"]:
			for graine in [1, 2, 3]:
				var diff := 1
				var r := jouer(graine, climat, diff, cas[1], cas[2], verbeux and graine == 1 and climat == "korhogo")
				var res: String = r.fin if r.fin != "" else "en cours"
				var bon: bool = res == cas[3]
				if bon: ok += 1
				else: ko += 1
				print("%s %-7s %-10s graine %d → %-9s en %.1f ans  stab %d/%d  rép %d  prod %d t  causes %s" % ["OK   " if bon else "ÉCART", cas[0], climat, graine, res,
					r.decade / 36.0, r.nb_stabilisees(), r.zones.size(), int(r.reputation), int(r.production_t), str(r.causes)])
				if verbeux and graine == 1 and climat == "san_pedro":
					for l in r.lecons():
						print("    • " + l)
	# sauvegarde / restauration et déterminisme
	var a := jouer(5, "man", 1, BONNE.slice(0, 8), false, false)
	var b := jouer(5, "man", 1, BONNE.slice(0, 8), false, false)
	if a.decade == b.decade and is_equal_approx(a.reputation, b.reputation): ok += 1
	else:
		ko += 1; print("ÉCART déterminisme")
	a.sauver("user://test_sauvegarde.dat")
	var c := Region.new()
	if c.restaurer("user://test_sauvegarde.dat") and c.zones.size() == a.zones.size() and is_equal_approx(c.budget, a.budget): ok += 1
	else:
		ko += 1; print("ÉCART sauvegarde")
	print("Parties automatiques : %d conformes, %d écarts" % [ok, ko])
	quit(1 if ko > 0 else 0)
