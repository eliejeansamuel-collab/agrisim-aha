class_name Economie
extends RefCounted
## Évaluation financière d'un projet. Méthodes standard (approfondissement :
## le cours « Gestion et évaluation de projet » de L2 n'est pas encore fourni).

## VAN : flux[0] est l'investissement (négatif), flux[i] le flux net de l'année i
static func van(flux: Array, taux: float) -> float:
	var v := 0.0
	for i in flux.size():
		v += flux[i] / pow(1.0 + taux, i)
	return v

## TRI par dichotomie ; renvoie NAN s'il n'existe pas entre -99 % et 1000 %
static func tri(flux: Array) -> float:
	var lo := -0.99
	var hi := 10.0
	if van(flux, lo) * van(flux, hi) > 0.0:
		return NAN
	for i in 100:
		var mid := (lo + hi) / 2.0
		if van(flux, lo) * van(flux, mid) <= 0.0:
			hi = mid
		else:
			lo = mid
	return (lo + hi) / 2.0

## Délai de récupération simple (années), -1 si jamais récupéré
static func delai_recuperation(flux: Array) -> float:
	var cumul := 0.0
	for i in flux.size():
		var avant := cumul
		cumul += flux[i]
		if cumul >= 0.0 and i > 0:
			return float(i - 1) + (-avant) / flux[i]
	return -1.0

## Annuité constante d'un emprunt
static func annuite(capital: float, taux: float, n: int) -> float:
	if taux == 0.0:
		return capital / n
	return capital * taux / (1.0 - pow(1.0 + taux, -n))

static func amortissement_lineaire(valeur: float, duree_ans: int) -> float:
	return valeur / duree_ans

static func marge_brute(recettes: float, charges_variables: float) -> float:
	return recettes - charges_variables

static func cout_par_hectare(charges: float, surface_ha: float) -> float:
	return charges / surface_ha

## Seuil de rentabilité en quantité : charges fixes / (prix - coût variable unitaire)
static func seuil_rentabilite(charges_fixes: float, prix: float, cout_var_unitaire: float) -> float:
	return charges_fixes / (prix - cout_var_unitaire)
