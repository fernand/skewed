#version 430
layout(local_size_x = 32, local_size_y = 32) in;
layout(rgba32f, binding = 0) uniform image2D pixels;
layout(rgba32f, binding = 1) uniform image2D skyMap;
layout(std430, binding = 0) readonly buffer data
{
    vec4 nxNyHalfHeight;
    vec4 eye;
    vec4 u;
    vec4 v;
    vec4 w;
};

const float PI = 3.1415926535897932384626433832795;
const int NUM_ITER = 10000;
const float STEP = 0.05;
const float BOX_R2 = 100.0;

const float SPH_R = 0.25;
const vec3 SPH_1 = vec3(0., 0., 1.25);
const vec3 SPH_2 = vec3(0., 0., -1.25);
const vec4 RED = vec4(1., 0., 0., 1.);
const vec4 GREEN = vec4(0., 1., 0., 1.);

void main() {
    vec4 color = vec4(0.0, 0.0, 0.0, 1.0);
    float nx = nxNyHalfHeight.x;
    float ny = nxNyHalfHeight.y;
    float halfHeight = nxNyHalfHeight.z;
    vec3 origin = eye.xyz;
    float halfWidth = halfHeight * float(nx) / ny;
    float s = float(gl_GlobalInvocationID.x) / nx;
    float t = float(gl_GlobalInvocationID.y) / ny;

    vec3 lowerLeftCorner = origin - halfWidth * u.xyz - halfHeight * v.xyz - w.xyz;
    vec3 horizontal = 2.0 * halfWidth * u.xyz;
    vec3 vertical = 2.0 * halfHeight * v.xyz;

    vec3 direction = normalize(lowerLeftCorner + s * horizontal + t * vertical - origin);
    vec3 point = origin;
    vec3 prevPoint;
    float prevSqrNorm;
    float sqrNorm = dot(point, point);
    float distSinceLastTurn = 0.0;

    for (int i=0; i<NUM_ITER; i++) {
        prevPoint = point;
        prevSqrNorm = sqrNorm;
        point += STEP * direction;
        sqrNorm = dot(point, point);
        
        if (sqrNorm > BOX_R2) {
            break;
        } else if (length(point - SPH_1) <= SPH_R) {
            color = RED;
            break;
        } else if (length(point - SPH_2) <= SPH_R) {
            color = GREEN;
            break;
        }
    }
    imageStore(pixels, ivec2(gl_GlobalInvocationID.xy), color);
}
