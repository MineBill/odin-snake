#version 410 core
layout (location = 0) in vec3 VertexPosition;
layout (location = 1) in vec2 TextureCoords;

uniform mat4 View;
uniform mat4 Transform;
uniform vec4 Color;

out vec4 FColor;
out vec2 FTextureCoords;

void main()
{
    FColor = Color;
    FTextureCoords = TextureCoords;
    gl_Position = View * Transform * vec4(VertexPosition, 1.0);
}
