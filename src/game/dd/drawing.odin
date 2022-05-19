package dd

import "core:math/linalg"
import gl "vendor:OpenGL"
import "core:log"

TextureHandle :: u32
Vec2 :: linalg.Vector2f32
Vec3 :: linalg.Vector3f32
Vec4 :: linalg.Vector4f32
Color :: Vec4

VERTEX_SRC := cstring(#load("vertex.glsl"))
FRAGMENT_SRC := cstring(#load("fragment.glsl"))

Drawing_Context :: struct {
    shader:       Shader,
    vertex_array: u32,
}

draw_init :: proc() -> Drawing_Context {
    shader := shader_from_source(&VERTEX_SRC, &FRAGMENT_SRC)

    vertices := [?]f32{+0.5, +0.5, 0.0, +0.5, -0.5, 0.0, -0.5, -0.5, 0.0, -0.5, +0.5, 0.0}

    indices := [?]u32{0, 1, 3, 1, 2, 3}

    gl.UseProgram(shader)

    vao: u32
    gl.GenVertexArrays(1, &vao)
    gl.BindVertexArray(vao)

    vbo: u32
    gl.GenBuffers(1, &vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, len(
            vertices,
        ) *
        size_of(
            f32,
        ), &vertices, gl.STATIC_DRAW)

    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(f32) * 3, 0)
    gl.EnableVertexAttribArray(0)

    ebo: u32
    gl.GenBuffers(1, &ebo)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(
            indices,
        ) *
        size_of(
            u32,
        ), &indices, gl.STATIC_DRAW)

    return Drawing_Context{shader = shader, vertex_array = vao}
}

draw_begin :: proc(ctx: ^Drawing_Context, camera: linalg.Matrix4f32, clear_color: Color) {
    gl.ClearColor(clear_color.r, clear_color.g, clear_color.b, clear_color.a)
    gl.Clear(gl.COLOR_BUFFER_BIT)
    gl.UseProgram(ctx.shader)
    shader_uniform_mat4(ctx.shader, "View", camera)
    gl.BindVertexArray(ctx.vertex_array)
}

draw_end :: proc() {
}

/// Draws a texture
/// `position`: Screen space position
/// `rotation`: Rotation in radians
/// `modulate`: Optional color modulation
draw_texture :: proc(
    using ctx: ^Drawing_Context,
    texture: TextureHandle,
    position: Vec2,
    rotation: f32 = 0.0,
    color: Color = Color{1.0, 1.0, 1.0, 1.0},
) {
    gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
}

draw_quad :: proc(
    using ctx: ^Drawing_Context,
    position: Vec2,
    rotation: f32 = 0.0,
    color: Color = Color{1.0, 1.0, 1.0, 1.0},
) {
    gl.BindVertexArray(ctx.vertex_array)
    transform := linalg.matrix4_translate(Vec3{position.x, position.y, 0.0})
    transform = transform * linalg.matrix4_rotate(rotation, Vec3{0, 0, 1})
    shader_uniform_mat4(shader, "Transform", transform)
    shader_uniform_vec4(shader, "Color", color)
    gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
}
