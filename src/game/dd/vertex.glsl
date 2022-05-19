#version 410 core
layout (location = 0) in vec3 aPos;
uniform mat4 View;
uniform mat4 Transform;
uniform vec4 Color;

out vec4 FColor;

void main()
{
    FColor = Color;
    gl_Position = View * Transform * vec4(aPos, 1.0);
}
