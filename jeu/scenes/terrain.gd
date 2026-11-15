class_name Terrain
extends RefCounted
## Relief du bas-fond (procédural, calibré : vallée à fond plat, pente longitudinale 0,4 %).
## À REMPLACER par un modèle numérique de terrain réel (Copernicus GLO-30 / SRTM) : voir ROADMAP.md.

const TAILLE := 800.0
const PENTE_LONG := 0.004
const DEMI_FOND := 270.0
# Parcelle de 5 ha : 200 m x 250 m
const PARCELLE := Rect2(40.0, -125.0, 200.0, 250.0)

static var bruit: FastNoiseLite
## Vrai après les travaux : chaque casier de 50 m est plané à son altitude moyenne (nivellement)
static var casiers_niveles := false

static func _bruit() -> FastNoiseLite:
	if bruit == null:
		bruit = FastNoiseLite.new()
		bruit.seed = 2026
		bruit.frequency = 0.008
		bruit.fractal_octaves = 3
	return bruit

static func x_riviere(z: float) -> float:
	return 14.0 * sin(z / 95.0) + 5.0 * sin(z / 37.0)

static func hauteur(x: float, z: float) -> float:
	if casiers_niveles and PARCELLE.has_point(Vector2(x, z)):
		var cx: float = PARCELLE.position.x + (floor((x - PARCELLE.position.x) / 50.0) + 0.5) * 50.0
		var cz: float = PARCELLE.position.y + (floor((z - PARCELLE.position.y) / 50.0) + 0.5) * 50.0
		return _hauteur_naturelle(cx, cz)
	return _hauteur_naturelle(x, z)

static func _hauteur_naturelle(x: float, z: float) -> float:
	var d: float = abs(x - x_riviere(z))
	var h := 12.0 - PENTE_LONG * (z + TAILLE / 2.0)
	h += 0.0025 * min(d, DEMI_FOND)                    # légère pente transversale vers le marigot
	if d > DEMI_FOND:
		var t: float = (d - DEMI_FOND) / 130.0
		h += pow(t, 1.5) * 16.0 + _bruit().get_noise_2d(x, z) * 5.0 * min(t, 1.0)
	h += _bruit().get_noise_2d(x * 3.0, z * 3.0) * 0.12  # micro-relief
	h -= 1.3 * exp(-pow(d / 7.0, 2))                   # lit du marigot
	return h

static func creer_maillage(n: int = 110) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pas := TAILLE / n
	for iz in n:
		for ix in n:
			var x0 := -TAILLE / 2.0 + ix * pas
			var z0 := -TAILLE / 2.0 + iz * pas
			var p := [Vector2(x0, z0), Vector2(x0 + pas, z0), Vector2(x0, z0 + pas),
				Vector2(x0 + pas, z0), Vector2(x0 + pas, z0 + pas), Vector2(x0, z0 + pas)]
			for q in p:
				var y := hauteur(q.x, q.y)
				st.set_color(_couleur(q.x, q.y, y))
				st.add_vertex(Vector3(q.x, y, q.y))
	st.generate_normals()
	return st.commit()

static func _couleur(x: float, z: float, y: float) -> Color:
	var d: float = abs(x - x_riviere(z))
	var v: float = _bruit().get_noise_2d(x * 2.0, z * 2.0) * 0.06
	if d < 9.0:
		return Color(0.45, 0.36, 0.22)
	if d < DEMI_FOND:
		return Color(0.42 + v, 0.58 + v, 0.24)      # herbes du bas-fond
	var t: float = clamp((d - DEMI_FOND) / 130.0, 0.0, 1.0)
	return Color(0.42, 0.58, 0.24).lerp(Color(0.16 + v, 0.40 + v, 0.14), t)  # forêt des versants

## Intersection d'un rayon avec le relief (marche le long du rayon)
static func lancer_rayon(origine: Vector3, direction: Vector3) -> Variant:
	var t := 0.0
	while t < 1500.0:
		var p := origine + direction * t
		if abs(p.x) < TAILLE / 2.0 and abs(p.z) < TAILLE / 2.0 and p.y <= hauteur(p.x, p.z):
			return Vector3(p.x, hauteur(p.x, p.z), p.z)
		t += 1.5
	return null
