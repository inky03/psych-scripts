#pragma header

uniform vec3 r;
uniform vec3 g;
uniform vec3 b;
uniform float a;
uniform float dim;
uniform float mult;
uniform float pixel;

float round(float n) {
    return floor(n + .5);
}
void main() {
    vec2 uv = openfl_TextureCoordv.xy;
	if (pixel > 1.0) {
		vec2 blocks = openfl_TextureSize / vec2(pixel);
		uv = vec2(round(uv.x * blocks.x), round(uv.y * blocks.y)) / blocks;
	}
	vec4 color = flixel_texture2D(bitmap, uv);
	color.rgb = min(color.r * r + color.g * g + color.b * b, vec3(1.0)) * vec3(a);
	color.a *= a * dim;
	gl_FragColor = color;
}