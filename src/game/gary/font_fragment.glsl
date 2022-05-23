#version 410 core
out vec4 FragColor;

in vec4 FColor;
in vec2 TextureCoords;

uniform sampler2D Atlas;

void main()
{
    vec4 sampled = vec4(1.0, 1.0, 1.0, texture(Atlas, TextureCoords).r);
    FragColor = FColor * sampled;
    // FragColor = texture(Atlas, TextureCoords) * FColor;
}
