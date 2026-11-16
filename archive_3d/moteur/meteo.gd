class_name Meteo
extends RefCounted
## Générateur de météo journalière calibré sur des normales mensuelles (fichier de données).
## Pluie : occurrence aléatoire (jours de pluie / jours du mois), hauteur de loi exponentielle.

var normales: Dictionary
var rng := RandomNumberGenerator.new()
var secheresse_debut := -1   # jour de l'année (1-365) de début d'une sécheresse imposée
var secheresse_duree := 0
var facteur_pluie := 1.0     # année sèche < 1 < année humide
var facteur_et0 := 1.0

const JOURS_MOIS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

func _init(p_normales: Dictionary, graine: int = 1) -> void:
	normales = p_normales
	rng.seed = graine

static func mois_du_jour(jour_annee: int) -> int:
	var j := ((jour_annee - 1) % 365) + 1
	for m in 12:
		if j <= JOURS_MOIS[m]:
			return m
		j -= JOURS_MOIS[m]
	return 11

## Renvoie {pluie, et0, tmin, tmax} pour un jour de l'année (1-365)
func jour(jour_annee: int) -> Dictionary:
	var m := mois_du_jour(jour_annee)
	var p_humide: float = float(normales.jours_pluie[m]) / JOURS_MOIS[m]
	var pluie := 0.0
	if rng.randf() < p_humide:
		var moy: float = float(normales.pluie_mm[m]) / max(float(normales.jours_pluie[m]), 1.0)
		pluie = -moy * log(max(1.0 - rng.randf(), 1e-9)) * facteur_pluie
	var et0: float = normales.et0_mm_j[m] * rng.randf_range(0.85, 1.15) * facteur_et0
	var j := ((jour_annee - 1) % 365) + 1
	if secheresse_debut > 0 and j >= secheresse_debut and j < secheresse_debut + secheresse_duree:
		pluie = 0.0
		et0 *= 1.15
	return {"pluie": pluie, "et0": et0, "tmin": normales.tmin[m], "tmax": normales.tmax[m]}
