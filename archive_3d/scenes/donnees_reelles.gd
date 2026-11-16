class_name DonneesReelles
extends Node
## Relief et climat réels d'un point de Côte d'Ivoire, téléchargés quand le téléphone est connecté,
## gardés en cache pour le jeu hors ligne, et rafraîchis à la reconnexion.
##  - Relief : Copernicus DEM GLO-90 (90 m) via l'API d'altitude Open-Meteo (100 points par requête).
##  - Climat : normales mensuelles NASA POWER (communauté AG) ; l'ET0 est calculée par Penman-Monteith.
## Attribution obligatoire : programme Copernicus, Open-Meteo, NASA POWER (voir CREDITS.md).

signal termine(ok: bool, message: String)

const N := 20                 # grille N x N sur la fenêtre de 800 m
const FENETRE_M := 800.0
const MOIS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
const JOURS_MOIS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const MILIEU_MOIS := [15, 46, 74, 105, 135, 166, 196, 227, 258, 288, 319, 349]

var url_altitude := "https://api.open-meteo.com/v1/elevation"
var url_climat := "https://power.larc.nasa.gov/api/temporal/climatology/point"
var en_cours := false
var http: HTTPRequest

func _ready() -> void:
	if OS.get_environment("AGRISIM_URL_ALT") != "":
		url_altitude = OS.get_environment("AGRISIM_URL_ALT")
	if OS.get_environment("AGRISIM_URL_CLIM") != "":
		url_climat = OS.get_environment("AGRISIM_URL_CLIM")
	http = HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	DirAccess.make_dir_recursive_absolute("user://sites")

static func chemin_cache(id: String) -> String:
	return "user://sites/%s.json" % id

## Données en cache pour ce lieu ({} si aucune)
static func lire_cache(id: String) -> Dictionary:
	if not FileAccess.file_exists(chemin_cache(id)):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(chemin_cache(id)))
	return d if d is Dictionary else {}

func _requete(url: String) -> Variant:
	if http.request(url) != OK:
		return null
	var r: Array = await http.request_completed
	if r[0] != HTTPRequest.RESULT_SUCCESS or r[1] != 200:
		return null
	return JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())

## Télécharge relief et climat, écrit le cache, émet `termine`
func telecharger(id: String, ville: Dictionary) -> void:
	if en_cours:
		return
	en_cours = true
	var lat0: float = ville.lat
	var lon0: float = ville.lon
	var dlat: float = FENETRE_M / 111320.0
	var dlon: float = FENETRE_M / (111320.0 * cos(deg_to_rad(lat0)))
	var lats: Array = []
	var lons: Array = []
	for iz in N:        # z croissant = vers le sud
		for ix in N:    # x croissant = vers l'est
			lats.append("%.5f" % (lat0 + dlat * (0.5 - float(iz) / (N - 1))))
			lons.append("%.5f" % (lon0 + dlon * (float(ix) / (N - 1) - 0.5)))
	var alt: Array = []
	var i := 0
	while i < lats.size():
		var rep = await _requete("%s?latitude=%s&longitude=%s" % [url_altitude, ",".join(lats.slice(i, i + 100)), ",".join(lons.slice(i, i + 100))])
		if rep == null or not (rep is Dictionary) or not rep.has("elevation"):
			return _fin(false, "Relief : serveur injoignable")
		alt.append_array(rep.elevation)
		i += 100
	if alt.size() != N * N:
		return _fin(false, "Relief : réponse incomplète")
	var rep2 = await _requete("%s?parameters=PRECTOTCORR,T2M_MAX,T2M_MIN,RH2M,WS2M,ALLSKY_SFC_SW_DWN&community=AG&longitude=%.4f&latitude=%.4f&format=JSON" % [url_climat, lon0, lat0])
	var climat := {}
	if rep2 is Dictionary and rep2.has("properties") and rep2.properties.has("parameter"):
		climat = convertir_climat(rep2.properties.parameter, lat0, _moyenne(alt), ville.nom)
	if climat.is_empty():
		return _fin(false, "Climat : serveur injoignable ou réponse inattendue")
	var d := {"id": id, "nom": ville.nom, "lat": lat0, "lon": lon0, "date": Time.get_date_string_from_system(),
		"n": N, "altitudes": alt, "climat": climat}
	var f := FileAccess.open(chemin_cache(id), FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	_fin(true, "Données réelles enregistrées")

func _fin(ok: bool, message: String) -> void:
	en_cours = false
	termine.emit(ok, message)

static func _moyenne(v: Array) -> float:
	var s := 0.0
	for x in v:
		s += float(x)
	return s / max(v.size(), 1)

## Normales NASA POWER -> format du jeu. Pluie en mm/j -> mm/mois ; ET0 par Penman-Monteith FAO-56.
static func convertir_climat(p: Dictionary, lat: float, altitude: float, nom: String) -> Dictionary:
	for cle in ["PRECTOTCORR", "T2M_MAX", "T2M_MIN", "RH2M", "WS2M", "ALLSKY_SFC_SW_DWN"]:
		if not p.has(cle) or not p[cle].has("JAN"):
			return {}
	var c := {"nom": nom + " (données réelles)", "zone": "Normales NASA POWER au point choisi", "latitude": lat,
		"altitude_m": altitude, "statut": "donnée réelle (réanalyse satellitaire)",
		"source": "NASA POWER, climatologie mensuelle, communauté AG. Jours de pluie estimés à partir du total mensuel.",
		"pluie_mm": [], "jours_pluie": [], "et0_mm_j": [], "tmin": [], "tmax": [], "vent_m_s": [], "humidite_pct": [], "rayonnement_mj": []}
	for m in 12:
		var k: String = MOIS[m]
		var pluie: float = max(float(p.PRECTOTCORR[k]), 0.0) * JOURS_MOIS[m]
		var rs: float = float(p.ALLSKY_SFC_SW_DWN[k])
		if rs < 10.0:   # sécurité : valeur en kWh/m2/j au lieu de MJ/m2/j
			rs *= 3.6
		var tmin: float = p.T2M_MIN[k]
		var tmax: float = p.T2M_MAX[k]
		var hr: float = p.RH2M[k]
		var et0: float = Eau.et0_penman_monteith(tmin, tmax, hr, hr, float(p.WS2M[k]), rs, lat, altitude, MILIEU_MOIS[m])
		c.pluie_mm.append(pluie)
		c.jours_pluie.append(clamp(round(pluie / 14.0), 1.0, 25.0))
		c.et0_mm_j.append(et0)
		c.tmin.append(tmin)
		c.tmax.append(tmax)
		c.vent_m_s.append(float(p.WS2M[k]))
		c.humidite_pct.append(hr)
		c.rayonnement_mj.append(rs)
	return c
