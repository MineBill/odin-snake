#version 410 core
uniform sampler2D Texture;

out vec4 FragColor;
in vec4 FColor;
in vec2 FTextureCoords;

void main()
{
    FragColor = texture(Texture, FTextureCoords) * FColor;
}
