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
const vec3 BLUE = vec3(0., 0., 1.);

const int RED_I = 0;
const int GREEN_I = 1;
const int BLUE_I = 2;

const vec3 mat[3] = vec3[3](
    RED,
    GREEN,
    BLUE
);
const vec3 unitBox = vec3(0.5, 0.5, 0.5);

float dSphere(vec3 p, float r) {
    return abs(length(p) - r);
}

float dBox(vec3 p, vec3 b) {
    vec3 d = abs(p) - b;
    return length(max(d, 0.0));
}

float dPlane(vec3 p, vec4 n) {
    return abs(dot(p, n.xyz) + n.w);
}

struct Hit {
    float closestDist;
    float secondDist;
    int closestMat;
};

struct Dist {
    float dist;
    int matI;
};

Hit op(Hit acc, Dist dc) {
    Hit res;
    if (acc.closestDist < dc.dist) {
        res = acc;
        if (dc.dist < acc.secondDist) {
            res.secondDist = dc.dist;
        }
    } else {
        res.closestDist = dc.dist;
        res.closestMat = dc.matI;
        res.secondDist = acc.closestDist;
    }
    return res;
}

Hit map(in vec3 pos) {
    Hit res = Hit(1e10, 1e10, 0);
    res = op(res, Dist(dBox(pos - vec3(0.0, 0.0, -1.001), unitBox), RED_I));
    res = op(res, Dist(dBox(pos - vec3(0.0, 0.0, 0.0), unitBox), BLUE_I));
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

    t = 0.0;
    for (int i=0; i<70 && t<tMax; i++) {
        Hit hit = map(rayOrigin + t * rayDir);
        if (abs(hit.closestDist) < 0.0001 * t) {
            color += vec4(mat[hit.closestMat], 1.0);
            t += hit.secondDist;
        } else {
            t += hit.closestDist;
        }
    }
    imageStore(pixels, ivec2(gl_GlobalInvocationID.xy), color);
}
