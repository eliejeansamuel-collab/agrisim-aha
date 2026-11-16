shader_type spatial;
// Relief avec courbes de niveau activables (après l'étude topographique)
uniform float contours = 0.0;
uniform float equidistance = 0.5;
varying float altitude;
void vertex() { altitude = VERTEX.y; }
void fragment() {
	float v = altitude / equidistance;
	float f = abs(fract(v - 0.5) - 0.5) / max(fwidth(v), 0.0001);
	float ligne = 1.0 - clamp(f, 0.0, 1.0);
	ALBEDO = mix(COLOR.rgb, vec3(0.30, 0.16, 0.05), ligne * contours);
	ROUGHNESS = 1.0;
}
