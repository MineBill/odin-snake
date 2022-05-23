#version 410 core
layout (location = 0) in vec4 VertexData;

uniform mat4 View;
uniform vec4 Color;
// NOTE(minebill): Maybe this can be use later
// to position text in world coordinates but let's
// ignore it for now to keep things simple
// uniform mat4 Transform;

out vec4 FColor;
out vec2 TextureCoords;

void main()
{
    FColor = Color;
    TextureCoords = VertexData.zw;
    gl_Position = View * vec4(VertexData.xy, 0.0,  1.0);
}
