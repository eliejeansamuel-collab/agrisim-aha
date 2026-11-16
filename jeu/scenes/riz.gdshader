shader_type spatial;
render_mode cull_disabled;
// Touffes de riz qui ondulent sous le vent (onde cohérente à travers la parcelle)
uniform vec3 couleur : source_color = vec3(0.30, 0.72, 0.22);
uniform float vent = 1.0;
void vertex() {
	float i = floor(float(INSTANCE_ID) / 50.0);
	float j = mod(float(INSTANCE_ID), 50.0);
	float phase = i * 0.35 + j * 0.22;
	float haut = VERTEX.y + 0.5;                 // 0 au pied, 1 au sommet
	VERTEX.x += haut * sin(TIME * 2.4 + phase) * 0.45 * vent;
	VERTEX.z += haut * cos(TIME * 1.7 + phase * 1.3) * 0.25 * vent;
}
void fragment() {
	ALBEDO = couleur * (0.75 + 0.25 * COLOR.r);
	ROUGHNESS = 0.9;
}
