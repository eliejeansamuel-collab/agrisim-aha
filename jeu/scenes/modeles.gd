class_name Modeles
extends RefCounted
## Chargement des modèles 3D libres de droits (KayKit, CC0) et mise à l'échelle du monde.

const DOSSIER_P := "res://ressources/personnages/"
const DOSSIER_D := "res://ressources/decor/"
const PERSONNAGES := ["Rogue", "Barbarian"]

static var _cache := {}

static func scene(chemin: String) -> PackedScene:
	if not _cache.has(chemin):
		_cache[chemin] = load(chemin) if ResourceLoader.exists(chemin) else null
	return _cache[chemin]

static func _aabb(n: Node, t: Transform3D, box: Array) -> void:
	if n is Node3D:
		t = t * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var a: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
		box[0] = a if box[0] == null else (box[0] as AABB).merge(a)
	for c in n.get_children():
		_aabb(c, t, box)

## Instance d'un modèle, mise à l'échelle pour faire `hauteur` mètres de haut, pieds à y = 0
static func instance(chemin: String, hauteur: float) -> Node3D:
	var ps := scene(chemin)
	if ps == null:
		return null
	var n: Node3D = ps.instantiate()
	var box: Array = [null]
	_aabb(n, Transform3D.IDENTITY.affine_inverse() * n.transform.affine_inverse(), box)
	var pivot := Node3D.new()
	pivot.add_child(n)
	if box[0] != null:
		var a: AABB = box[0]
		var k: float = hauteur / max(a.size.y, 0.001)
		n.scale = Vector3(k, k, k)
		n.position.y = -a.position.y * k
	return pivot

## Maillage d'un décor pour les MultiMesh : {mesh, echelle, base} ; dictionnaire vide si le modèle manque
static func maillage(nom: String, hauteur: float) -> Dictionary:
	var ps := scene(DOSSIER_D + nom + ".gltf")
	if ps == null:
		return {}
	var n: Node = ps.instantiate()
	var mi := _premier_mesh(n)
	if mi == null:
		n.free()
		return {}
	var a: AABB = mi.mesh.get_aabb()
	var res := {"mesh": mi.mesh, "echelle": hauteur / max(a.size.y, 0.001), "base": a.position.y}
	n.free()
	return res

## Élément de décor (maison, tente, sac…) mis à l'échelle ; null si le modèle manque
static func decor(nom: String, hauteur: float) -> Node3D:
	return instance(DOSSIER_D + nom + ".gltf", hauteur)

static func _premier_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		return n
	for c in n.get_children():
		var r := _premier_mesh(c)
		if r != null:
			return r
	return null

## Personnage animé : cache les armes et accessoires de combat, renvoie le pivot
static func personnage(i: int, hauteur: float) -> Node3D:
	var p := instance(DOSSIER_P + PERSONNAGES[i % PERSONNAGES.size()] + ".glb", hauteur)
	if p == null:
		return null
	p.set_meta("anim", true)
	_cacher_accessoires(p)
	var ap := lecteur(p)
	if ap != null:
		for a in ["Walking_A", "Walking_B", "Idle", "Sit_Floor_Idle", "Lie_Idle", "PickUp", "Interact", "2H_Melee_Attack_Chop", "Use_Item", "Cheer"]:
			if ap.has_animation(a):
				ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	return p

static func _cacher_accessoires(n: Node) -> void:
	if n is BoneAttachment3D or (n is MeshInstance3D and n.get_parent() is BoneAttachment3D):
		var nom := String(n.name).to_lower()
		for mot in ["hand", "slot", "knife", "crossbow", "axe", "mug", "shield", "sword", "staff", "wand", "spellbook", "throwable", "cape", "hat"]:
			if mot in nom and not ("head" in nom):
				(n as Node3D).visible = false
	for c in n.get_children():
		_cacher_accessoires(c)

static func lecteur(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := lecteur(c)
		if r != null:
			return r
	return null

static func jouer(pivot: Node3D, anim: String, vitesse: float = 1.0) -> void:
	var ap := lecteur(pivot)
	if ap != null and ap.has_animation(anim) and (ap.current_animation != anim or not ap.is_playing()):
		ap.play(anim, 0.25, vitesse)
