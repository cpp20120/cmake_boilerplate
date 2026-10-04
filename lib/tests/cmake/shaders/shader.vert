#version 450
#extension GL_GOOGLE_include_directive : require
#include "common.glsl"
void main() { gl_Position = vec4(SHIFT * FACTOR); }
