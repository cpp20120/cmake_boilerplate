#include "common.glsl"
float4 main(float4 position : POSITION) : SV_Position { return position * (SHIFT * FACTOR); }
