extends SceneTree
## Tests unitaires du moteur. Lancer : godot --headless --path jeu -s tests/run_tests.gd
## Chaque exemple est vérifié à la main ou tiré d'un exercice corrigé de mes cours.

const E = preload("res://moteur/eau.gd")
const H = preload("res://moteur/hydraulique.gd")
const Y = preload("res://moteur/hydrologie.gd")
const F = preload("res://moteur/economie.gd")
const M = preload("res://moteur/meteo.gd")
const C = preload("res://moteur/campagne.gd")

var ok := 0
var ko := 0

func proche(nom: String, obtenu: float, attendu: float, tol: float) -> void:
	if abs(obtenu - attendu) <= tol:
		ok += 1
	else:
		ko += 1
		print("ÉCHEC  %s : obtenu %f, attendu %f (tol %f)" % [nom, obtenu, attendu, tol])

func egal(nom: String, obtenu, attendu) -> void:
	if obtenu == attendu:
		ok += 1
	else:
		ko += 1
		print("ÉCHEC  %s : obtenu %s, attendu %s" % [nom, str(obtenu), str(attendu)])

func charger(chemin: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(chemin))

func _init() -> void:
	# --- Cours Bases techniques, ch. 2 : exercice d'efficience (2 ha, 5 mm/j, 15 m3/h pendant 8 h)
	proche("volume net 2 ha x 5 mm", E.mm_vers_m3(5.0, 2.0), 100.0, 0.001)
	proche("efficience 100/120", E.efficience(100.0, 15.0 * 8.0), 0.8333, 0.001)
	proche("variante : heures de pompage", E.besoin_brut(100.0, 0.75) / 15.0, 8.889, 0.01)  # 8 h 53
	# --- ch. 3 : RU et RFU
	proche("RU = CC - PFP (30-15) sur 1 m", E.reserve_utile(30, 15, 1000), 150.0, 0.001)
	proche("RFU 50 %", E.rfu(15.0, 0.5), 7.5, 0.001)
	# --- ch. 4 : exercice tomate
	proche("ETc tomate", E.etc(5.0, 1.15), 5.75, 0.001)
	proche("besoin brut tomate", E.besoin_brut(E.besoin_net(5.75, 0.0), 0.90), 6.39, 0.01)
	proche("tour d'eau tomate", E.tour_eau(23.0, 5.75), 4.0, 0.001)
	proche("dose brute tomate", E.besoin_brut(23.0, 0.90), 25.6, 0.05)
	proche("mini exercice ETc", E.etc(5.0, 1.2), 6.0, 0.001)
	# --- ch. 5 : efficiences du périmètre (1500 -> 1300 -> 1150 -> 950 m3)
	proche("Et", E.efficience(1300, 1500), 0.867, 0.001)
	proche("Ed", E.efficience(1150, 1300), 0.885, 0.001)
	proche("Ea", E.efficience(950, 1150), 0.826, 0.001)
	proche("Eg", E.efficience_globale([1300.0 / 1500, 1150.0 / 1300, 950.0 / 1150]), 0.633, 0.001)
	# --- Cours Aménagement : RFU = (0,35 - 0,15) x 600 x 0,6 = 72 mm ; tour d'eau 12 j
	proche("RFU cours Aménagement", E.rfu(E.reserve_utile(35, 15, 600), 0.6), 72.0, 0.001)
	proche("Te = 72/6", E.tour_eau(72.0, 6.0), 12.0, 0.001)
	proche("ETP bac", E.etp_bac(8.0), 6.0, 0.001)
	# --- Débit fictif continu : 8,64 mm/j <=> 1 L/s/ha
	proche("Qfc", E.debit_fictif_continu(8.64), 1.0, 0.0001)
	proche("débit d'équipement 5 ha, 12 h/j", E.debit_equipement(1.0, 5.0, 12.0), 0.010, 0.0001)
	# --- Kc par stades
	proche("Kc initial", E.kc_du_jour(10, [20, 30, 40, 30], 1.05, 1.2, 0.75), 1.05, 0.001)
	proche("Kc milieu de développement", E.kc_du_jour(35, [20, 30, 40, 30], 1.05, 1.2, 0.75), 1.125, 0.001)
	proche("Kc mi-saison", E.kc_du_jour(70, [20, 30, 40, 30], 1.05, 1.2, 0.75), 1.2, 0.001)
	proche("Kc fin", E.kc_du_jour(120, [20, 30, 40, 30], 1.05, 1.2, 0.75), 0.75, 0.001)
	# --- Stress et rendement
	proche("Ks sans stress", E.ks_stress(40, 120, 60), 1.0, 0.001)
	proche("Ks à mi-chemin", E.ks_stress(90, 120, 60), 0.5, 0.001)
	proche("rendement relatif FAO-33", E.rendement_relatif(400, 500, 1.1), 0.78, 0.001)
	# --- Penman-Monteith : FAO-56 exemple 18 (Bruxelles, 6 juillet) -> 3,9 mm/j
	proche("ET0 Penman-Monteith FAO-56 ex. 18",
		E.et0_penman_monteith(12.3, 21.5, 63, 84, 2.078, 22.07, 50.8, 100, 187), 3.88, 0.1)
	proche("Ra FAO-56 ex. 8 (20°S, 3 sept.)", E.ra(-20.0, 246), 32.2, 0.3)
	proche("pluie efficace USDA 100 mm", E.pluie_efficace_mensuelle(100.0), 84.0, 0.001)
	# --- Hydraulique
	proche("Manning canal rectangulaire", H.debit_manning(30, 2.0, 1.0, 0.0, 0.001), 1.195, 0.005)
	proche("hauteur normale (inverse)", H.hauteur_normale(1.195, 30, 2.0, 0.0, 0.001), 1.0, 0.005)
	proche("section trapèze", H.section_trapeze(1.0, 0.5, 1.5), 0.875, 0.0001)
	proche("périmètre trapèze", H.perimetre_trapeze(1.0, 0.5, 1.5), 2.803, 0.001)
	proche("puissance : 1 m3/s à 10 m (cours : 125 kW)", H.puissance_pompe_kw(1.0, 10.0, 0.785), 125.0, 0.5)
	proche("lambda laminaire", H.lambda_pdc(1000, 0.0001, 0.1), 0.064, 0.0001)
	proche("pdc Darcy-Weisbach", H.perte_charge_lineaire(0.01, 0.1, 100.0, 0.0001), 1.83, 0.1)
	proche("pression à 10 m", H.pression_hydrostatique(10.0), 98100.0, 1.0)
	proche("déversoir", H.debit_deversoir(1.0, 0.2, 0.42), 0.1664, 0.001)
	egal("Froude fluvial", H.froude(1.195, 2.0, 1.0, 0.0) < 1.0, true)
	# --- Hydrologie
	proche("Gravelius", Y.gravelius(20.0, 16.0), 1.4, 0.001)
	proche("rationnelle : C=0,5 ; 36 mm/h ; 1 km2", Y.debit_rationnel(0.5, 36.0, 1.0), 5.0, 0.001)
	proche("Kirpich", Y.tc_kirpich_min(1000.0, 0.01), 23.44, 0.1)
	proche("Gumbel T=10", Y.gumbel_quantile(100.0, 20.0, 10.0), 126.09, 0.05)
	proche("risque décennal sur 10 ans", Y.risque_sur_n_ans(10, 10), 0.6513, 0.001)
	proche("Thiessen", Y.thiessen([100, 200], [3, 1]), 125.0, 0.001)
	proche("Turc", Y.etr_turc(1200.0, 27.0), 1062.7, 1.0)
	proche("bilan : infiltration", Y.infiltration_par_bilan(1000, 700, 200), 100.0, 0.001)
	proche("crête Knappen H=9", Y.crete_knappen(9.0), 4.95, 0.001)
	proche("crête Preece H=9", Y.crete_preece(9.0), 4.3, 0.001)
	proche("volume retenue", Y.volume_retenue(267.0, 100.0, 4.0), 40000.0, 0.01)
	proche("SAR", Y.sar(10.0, 4.0, 4.0), 5.0, 0.001)
	proche("RSC", Y.rsc(0.5, 4.0, 2.0, 1.0), 1.5, 0.001)
	egal("classe C2", Y.classe_salinite(500), "C2")
	egal("classe C3", Y.classe_salinite(750), "C3")
	egal("classe S2", Y.classe_sar(12), "S2")
	egal("RSC modéré", Y.classe_rsc(1.5), "léger à modéré")
	var r: Array = Y.bilan_retenue(1000.0, 1200.0, 500.0, 5.0, 10000.0, 100.0)
	proche("retenue : volume", r[0], 1200.0, 0.001)
	proche("retenue : déversé", r[1], 150.0, 0.001)
	# --- Économie
	proche("VAN", F.van([-1000.0, 600.0, 600.0], 0.10), 41.32, 0.01)
	proche("TRI", F.tri([-1000.0, 600.0, 600.0]), 0.1307, 0.001)
	proche("délai de récupération", F.delai_recuperation([-1000.0, 600.0, 600.0]), 1.667, 0.001)
	proche("annuité", F.annuite(1000000.0, 0.10, 5), 263797.0, 1.0)
	proche("seuil de rentabilité", F.seuil_rentabilite(500000.0, 200.0, 100.0), 5000.0, 0.001)
	# --- Campagne : conservation de l'eau et sensibilité
	var climat: Dictionary = charger("res://donnees/climat.json").san_pedro
	var riz: Dictionary = charger("res://donnees/cultures.json").riz_irrigue
	var c1 = C.new(riz, M.new(climat, 7))
	c1.q_canal_m3_s = 0.012
	c1.drainage_mm_j = 20.0
	var r1: Dictionary = c1.simuler_tout()
	proche("bilan d'eau fermé (bien conçu)", c1.erreur_bilan(), 0.0, 0.001)
	egal("campagne de 120 jours", c1.journal.size(), 120)
	egal("bien conçu : rendement > 4 t/ha", r1.rendement_t_ha > 4.0, true)
	var c2 = C.new(riz, M.new(climat, 7))
	c2.q_canal_m3_s = 0.0005   # canal sous-dimensionné
	c2.percolation_mm_j = 20.0 # sol sableux non étudié
	c2.jour_semis = 335        # repiquage en saison sèche
	var r2: Dictionary = c2.simuler_tout()
	proche("bilan d'eau fermé (mal conçu)", c2.erreur_bilan(), 0.0, 0.001)
	egal("mal conçu : rendement plus faible", r2.rendement_t_ha < r1.rendement_t_ha * 0.8, true)
	egal("mal conçu : jours de stress", r2.jours_stress > 10, true)
	var c3 = C.new(riz, M.new(climat, 7))
	c3.q_canal_m3_s = 0.012
	c3.crue_jour = 40; c3.crue_duree = 4; c3.crue_hauteur_m = 0.8; c3.hauteur_digue_m = 0.5
	var r3: Dictionary = c3.simuler_tout()
	egal("crue non protégée : 4 jours de submersion", r3.jours_submersion, 4)
	c3 = C.new(riz, M.new(climat, 7))
	c3.q_canal_m3_s = 0.012
	c3.crue_jour = 40; c3.crue_duree = 4; c3.crue_hauteur_m = 0.8; c3.hauteur_digue_m = 1.0
	egal("crue avec digue suffisante : 0 submersion", c3.simuler_tout().jours_submersion, 0)
	# Même graine => même résultat (reproductibilité)
	var c4 = C.new(riz, M.new(climat, 7))
	c4.q_canal_m3_s = 0.012
	c4.drainage_mm_j = 20.0
	proche("reproductible", c4.simuler_tout().rendement_t_ha, r1.rendement_t_ha, 1e-9)
	print("\nRésultat campagne bien conçue : ", r1)
	print("Totaux (mm) : ", c1.tot)
	print("Résultat campagne mal conçue : ", r2)
	print("\n%d tests réussis, %d échecs" % [ok, ko])
	quit(1 if ko > 0 else 0)
