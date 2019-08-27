#include "include/glad/glad.h"
#define GLFW_DLL
#include "include/GLFW/glfw3.h"

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <math.h>

#define PI 3.14159265358979323846f

#include "io.c"
#include "math.c"
#include "opengl.c"

#define NX 2560
#define NY 1440

const float oneRadian = PI / 180.0f;
const float fovy = 45.0f;
const float speed = 0.03f;
const float sensitivity = 0.05f;

float yaw = -90.0f, pitch = 0.0f;
double lastX = NX / 2, lastY = NY / 2;
bool cursorPosSet = false;

v3 cP, cFront, cRight, cUp, wUp;
v3 u, v, w;

static void updateCamera() {
    cFront.x = cosf(pitch * oneRadian) * cosf(yaw * oneRadian);
    cFront.y = sinf(pitch * oneRadian);
    cFront.z = cosf(pitch * oneRadian) * sinf(yaw * oneRadian);
    cFront = normalizeV3(cFront);
    cRight = normalizeV3(crossV3(cFront, wUp));
    cUp = normalizeV3(crossV3(cRight, cFront));
    w = normalizeV3(subtractV3(cP, addV3(cP, cFront)));
    u = normalizeV3(crossV3(cUp, w));
    v = crossV3(w, u);
}

typedef struct {
    float nx;
    float ny;
    float halfHeight;
    float _;
    v4 eye;
    v4 cUp;
    v4 u;
    v4 v;
    v4 w;
} ShaderData;

static ShaderData initShaderData(int nx, int ny) {
    ShaderData shaderData = {0};
    cP = newV3(0.0f, 0.0f, 5.5f);
    wUp = newV3(0.0f, 1.0f, 0.0f);
    updateCamera();
    shaderData.nx = (float)nx;
    shaderData.ny = (float)ny;
    shaderData.halfHeight = tanf(fovy * PI / (180.f * 2.0f));
    shaderData.eye = fromV3(cP);
    shaderData.cUp = fromV3(cUp);
    shaderData.u = fromV3(u);
    shaderData.v = fromV3(v);
    shaderData.w = fromV3(w);
    return shaderData;
}

static void actOnInput(GLFWwindow *window, ShaderData *shaderData) {
    double xpos, ypos;
    glfwGetCursorPos(window, &xpos, &ypos);
    if (!cursorPosSet) {
        lastX = xpos;
        lastY = ypos;
        cursorPosSet = true;
    }
    double xOffset = xpos - lastX;
    double yOffset = lastY - ypos;
    lastX = xpos;
    lastY = ypos;
    yaw += sensitivity * (float)xOffset;
    pitch += sensitivity * (float)yOffset;
    if (pitch > 89.0f) {
        pitch = 89.0f;
    } else if (pitch < -89.0f) {
        pitch = -89.0f;
    }

    updateCamera();

    if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS) {
        cP = addV3(cP, mulV3(speed, cFront));
    }
    if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS) {
        cP = subtractV3(cP, mulV3(speed, cFront));
    }
    if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS) {
        cP = subtractV3(cP, mulV3(speed, cRight));
    }
    if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS) {
        cP = addV3(cP, mulV3(speed, cRight));
    }

    shaderData->eye = fromV3(cP);
    shaderData->cUp = fromV3(cUp);
    shaderData->u = fromV3(u);
    shaderData->v = fromV3(v);
    shaderData->w = fromV3(w);
}

void main() {
    if (!glfwInit()) {
        printf("Could not init GLFW\n");
        exit(-1);
    }
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    GLFWwindow *window = glfwCreateWindow(NX, NY, "Sailing", NULL, NULL);
    if (!window) {
        printf("Could not init GLFW window\n");
        exit(-1);
    }
    glfwMakeContextCurrent(window);
    if (!gladLoadGLLoader((GLADloadproc) glfwGetProcAddress)) {
        printf("Could not init OpenGL context\n");
        exit(-1);
    }

    glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
    if (glfwRawMouseMotionSupported()) {
        glfwSetInputMode(window, GLFW_RAW_MOUSE_MOTION, GLFW_TRUE);
    } else {
        printf("raw mouse motion not supported");
        exit(-1);
    }

    // Create and bind and empty texture
    GLuint outputTextureUnit = 0;
    GLuint outputTextureId;
    glGenTextures(1, &outputTextureId);
    glActiveTexture(GL_TEXTURE0 + outputTextureUnit);
    glBindTexture(GL_TEXTURE_2D, outputTextureId);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, NX, NY, 0, GL_RGBA, GL_FLOAT, NULL);
    glBindImageTexture(outputTextureUnit, outputTextureId, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_RGBA32F);

    GLuint computeShaderId = shaderFromSource("rayTracer", GL_COMPUTE_SHADER, "shaders/compute.glsl");
    GLuint computeProgramId = shaderProgramFromShader(computeShaderId);

    ShaderData shaderData = initShaderData(NX, NY);

    // Create and bind the SSBO
    GLuint ssboLocation = 0;
    GLuint ssboId;
    glGenBuffers(1, &ssboId);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssboId);
    glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(shaderData), &shaderData, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, ssboLocation, ssboId);

    GLuint fboId;
    glGenFramebuffers(1, &fboId);
    glBindFramebuffer(GL_READ_FRAMEBUFFER, fboId);
    glFramebufferTexture2D(GL_READ_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, outputTextureId, 0);

    while(!glfwWindowShouldClose(window)) {
        actOnInput(window, &shaderData);

        glBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, sizeof(shaderData), &shaderData);

        glClear(GL_COLOR_BUFFER_BIT);

        glUseProgram(computeProgramId);
        glDispatchCompute(NX/32, NY/32, 1);
        glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
        glBlitFramebuffer(0, 0, NX, NY, 0, 0, NX, NY, GL_COLOR_BUFFER_BIT, GL_NEAREST);

        glfwSwapBuffers(window);

        glfwPollEvents();
    }

    glfwTerminate();
}
