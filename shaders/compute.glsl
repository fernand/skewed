#version 430
layout(local_size_x = 32, local_size_y = 32) in;
layout(rgba32f, binding = 0) uniform image2D pixels;
layout(std430, binding = 0) readonly buffer data
{
    vec4 nxNyHalfHeight;
    vec4 eye;
    vec4 cUp;
    vec4 u;
    vec4 v;
    vec4 w;
};

const float PI = 3.1415926535897932384626433832795;

const vec3 RED = vec3(1., 0., 0.);
const vec3 GREEN = vec3(0., 1., 0.);
const vec3 unitBox = vec3(0.5, 0.5, 0.5);

float sdSphere(vec3 p, float r) {
    return length(p) - r;
}

float sdBox(vec3 p, vec3 b) {
    vec3 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

vec4 opU(vec4 d1, vec4 d2) {
    return (d1.x < d2.x) ? d1 : d2;
}

vec4 map(in vec3 pos) {
    vec4 res = vec4(1e10, 0.0, 0.0, 0.0);
#if 0
    res = opU(res, vec4(sdBox(pos - vec3(0.0, 0.0, 0.0), unitBox), RED));
    res = opU(res, vec4(sdBox(pos - vec3(0.0, 0.0, -2.0), unitBox), RED));
    res = opU(res, vec4(sdBox(pos - vec3(0.0, 0.0, -4.0), unitBox), RED));
    res = opU(res, vec4(sdBox(pos - vec3(-2.0, 0.0, 0.0), unitBox), RED));
    res = opU(res, vec4(sdBox(pos - vec3(-2.0, 0.0, -2.0), unitBox), RED));
    res = opU(res, vec4(sdBox(pos - vec3(-2.0, 0.0, -4.0), unitBox), RED));
    res = opU(res, vec4(sdBox(pos - vec3(2.0, 0.0, 0.0), unitBox), RED));
    res = opU(res, vec4(sdBox(pos - vec3(2.0, 0.0, -2.0), unitBox), RED));
    res = opU(res, vec4(sdBox(pos - vec3(2.0, 0.0, -4.0), unitBox), RED));
#endif
    res = opU(res, vec4(sdSphere(pos - vec3(0.0, 0.0, 0.0), 0.25), RED));
    res = opU(res, vec4(sdSphere(pos - vec3(0.0, 0.0, -2.0), 0.25), RED));
    res = opU(res, vec4(sdSphere(pos - vec3(0.0, 0.0, -4.0), 0.25), RED));
    res = opU(res, vec4(sdSphere(pos - vec3(-2.0, 0.0, 0.0), 0.25), RED));
    res = opU(res, vec4(sdSphere(pos - vec3(-2.0, 0.0, -2.0), 0.25), RED));
    res = opU(res, vec4(sdSphere(pos - vec3(-2.0, 0.0, -4.0), 0.25), RED));
    res = opU(res, vec4(sdSphere(pos - vec3(2.0, 0.0, 0.0), 0.25), RED));
    res = opU(res, vec4(sdSphere(pos - vec3(2.0, 0.0, -2.0), 0.25), RED));
    res = opU(res, vec4(sdSphere(pos - vec3(2.0, 0.0, -4.0), 0.25), RED));
    return res;
}

const float tMax = 15.0;

void main() {
    vec4 color = vec4(0.0, 0.0, 0.0, 1.0);
    float nx = nxNyHalfHeight.x;
    float ny = nxNyHalfHeight.y;
    float halfHeight = nxNyHalfHeight.z;
    vec3 rayOrigin = eye.xyz;
    vec3 up = cUp.xyz;
    float halfWidth = halfHeight * float(nx) / ny;
    float s = float(gl_GlobalInvocationID.x) / nx;
    float t = float(gl_GlobalInvocationID.y) / ny;

    vec3 lowerLeftCorner = rayOrigin - halfWidth * u.xyz - halfHeight * v.xyz - w.xyz;
    vec3 horizontal = 2.0 * halfWidth * u.xyz;
    vec3 vertical = 2.0 * halfHeight * v.xyz;
    vec3 rayDir = normalize(lowerLeftCorner + s * horizontal + t * vertical - rayOrigin);
    float nextJump = 1.0;

    t = 0.0;
    for (int i=0; i<70 && t<tMax; i++) {
        vec4 hit = map(rayOrigin + t * rayDir);
        if (abs(hit.x) < 0.0001 * t) {
            color = vec4(hit.yzw, 1.0);
            break;
        }
        if (abs(hit.x) <= nextJump - t) {
            t += hit.x;
        } else {
            t = nextJump + 1.0;
            nextJump = t + 1.0;
        }
    }
    imageStore(pixels, ivec2(gl_GlobalInvocationID.xy), color);
}
