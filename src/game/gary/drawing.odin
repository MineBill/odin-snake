package gary // Graphics librARY

import gl  "vendor:OpenGL"
import ttf "vendor:stb/truetype"
import "vendor:stb/truetype"

import "core:math/linalg"
import "core:unicode/utf8"
import "core:log"
import "core:c"

Vec2 :: linalg.Vector2f32
Vec3 :: linalg.Vector3f32
Vec4 :: linalg.Vector4f32
Color :: Vec4

Vec2i :: [2]i32
Vec3i :: [3]i32

VERTEX_SRC           := cstring(#load("vertex.glsl"))
SIMPLE_FRAGMENT_SRC  := cstring(#load("fragment.glsl"))
TEXTURE_FRAGMENT_SRC := cstring(#load("texture_fragment.glsl"))
FONT_VERTEX_SRC      := cstring(#load("font_vertex.glsl"))
FONT_FRAGMENT_SRC    := cstring(#load("font_fragment.glsl"))

FONT_SCALE :: 32

Text_Align :: enum {
    CENTER,
    TOP_LEFT,
    TOP_RIGHT,
    BOTTOM_LEFT,
    BOTTOM_RIGHT,
}

Drawing_Context :: struct {
    draw_calls:     u32,
    simple_shader:  Shader,
    texture_shader: Shader,
    vertex_array:   u32,

    font_shader:    Shader,
    font_atlas:     ^Atlas,
    atlas_texture:  Texture_Handle,
}

ctx: Drawing_Context

init :: proc() {
    gl.Enable(gl.CULL_FACE)
    gl.CullFace(gl.FRONT)

    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

    simple_shader  := shader_from_source(&VERTEX_SRC, &SIMPLE_FRAGMENT_SRC)
    texture_shader := shader_from_source(&VERTEX_SRC, &TEXTURE_FRAGMENT_SRC)
    font_shader    := shader_from_source(&FONT_VERTEX_SRC, &FONT_FRAGMENT_SRC)

    t := Vec4 {
        +0.0, +0.0, // Bottom Left
        +1.0, -1.0, // Top Right
    }

    vertices := [?]f32{
        +0.5, +0.5, 0.0, t.z, t.w, // Top Right
        +0.5, -0.5, 0.0, t.z, t.y, // Bottom Right
        -0.5, -0.5, 0.0, t.x, t.y, // Bottom Left
        -0.5, +0.5, 0.0, t.x, t.w, // Top Left
    }

    indices := [?]u32{0, 1, 3, 1, 2, 3}

    vao: u32
    gl.GenVertexArrays(1, &vao)
    gl.BindVertexArray(vao)

    vbo: u32
    gl.GenBuffers(1, &vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(f32), &vertices, gl.STATIC_DRAW)

    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(f32) * 5, 0)
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(f32) * 5, size_of(f32) * 3)

    ebo: u32
    gl.GenBuffers(1, &ebo)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices) * size_of(u32), &indices, gl.STATIC_DRAW)

    load_fonts()
    atlas, ok := make_font_atlas(FONT_SCALE)
    log.info(atlas.max_rune_size)
    assert(ok == true, "Failed to create font atlas")

    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)
    atlas_texture := load_texture(atlas.img.width, atlas.img.height, atlas.img.channels, raw_data(atlas.img.pixels.buf))

    ctx = Drawing_Context{
        simple_shader = simple_shader,
        texture_shader = texture_shader,
        vertex_array = vao,
        font_shader = font_shader,
        font_atlas = atlas,
        atlas_texture = atlas_texture,
    }
}

deinit :: proc() {
    gl.DeleteProgram(ctx.simple_shader)
    gl.DeleteProgram(ctx.texture_shader)
    gl.DeleteProgram(ctx.font_shader)

    gl.DeleteVertexArrays(1, &ctx.vertex_array)

    gl.DeleteTextures(1, &ctx.atlas_texture)

    destroy_fonts()
    delete(glyph_map)
    destroy_atlas(ctx.font_atlas)
}

draw_clear :: proc(clear_color: Color) {
    gl.ClearColor(clear_color.r, clear_color.g, clear_color.b, clear_color.a)
    gl.Clear(gl.COLOR_BUFFER_BIT)
}

draw_begin :: proc(camera: linalg.Matrix4f32) {
    ctx.draw_calls = 0
    // NOTE(minebill): This seems weird
    gl.UseProgram(ctx.simple_shader)
    shader_uniform_mat4(ctx.simple_shader, "View", camera)
    gl.UseProgram(ctx.texture_shader)
    shader_uniform_mat4(ctx.texture_shader, "View", camera)
    gl.UseProgram(ctx.font_shader)
    shader_uniform_mat4(ctx.font_shader, "View", camera)
}

draw_end :: proc() {
}

/// Draws a texture
/// `position`: Screen space position
/// `rotation`: Rotation in radians
/// `modulate`: Optional color modulation
draw_texture :: proc(
    texture: Texture_Handle,
    position: Vec2,
    rotation: f32 = 0.0,
    color: Color = Color{1.0, 1.0, 1.0, 1.0},
    scale: Vec2 = Vec2 {1, 1},
) {
    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, texture)

    gl.UseProgram(ctx.texture_shader)

    gl.BindVertexArray(ctx.vertex_array)

    transform := linalg.matrix4_translate(Vec3{position.x, position.y, 0.0})
    transform = transform * linalg.matrix4_rotate(rotation, Vec3{0, 0, 1})
    transform = transform * linalg.matrix4_scale(Vec3{scale.x, scale.y, 0})
    shader_uniform_mat4(ctx.texture_shader, "Transform", transform)
    shader_uniform_vec4(ctx.texture_shader, "Color", color)
    gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
    ctx.draw_calls += 1
}

draw_quad :: proc(
    position: Vec2,
    rotation: f32 = 0.0,
    color: Color = Color{1.0, 1.0, 1.0, 1.0},
    scale: Vec2 = Vec2 {1, 1},
) {
    gl.BindVertexArray(ctx.vertex_array)
    gl.UseProgram(ctx.simple_shader)
    transform := linalg.matrix4_translate(Vec3{position.x, position.y, 0.0})
    transform = transform * linalg.matrix4_rotate(rotation, Vec3{0, 0, 1})
    transform = transform * linalg.matrix4_scale(Vec3{scale.x, scale.y, 0})
    shader_uniform_mat4(ctx.simple_shader, "Transform", transform)
    shader_uniform_vec4(ctx.simple_shader, "Color", color)
    gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
    ctx.draw_calls += 1
}

draw_quad_points :: proc(
    position: Vec2,
    points: []f32,
    rotation: f32 = 0.0,
    color: Color = Color{1.0, 1.0, 1.0, 1.0},
    scale: Vec2 = Vec2 {1, 1},
) {
    gl.BindVertexArray(0)
    gl.UseProgram(ctx.simple_shader)

    transform := linalg.matrix4_translate(Vec3{position.x, position.y, 0.0})
    transform = transform * linalg.matrix4_rotate(rotation, Vec3{0, 0, 1})
    transform = transform * linalg.matrix4_scale(Vec3{scale.x, scale.y, 1})
    shader_uniform_mat4(ctx.simple_shader, "Transform", transform)
    shader_uniform_vec4(ctx.simple_shader, "Color", color)

    vbo: u32
    gl.GenBuffers(1, &vbo)
    defer gl.DeleteBuffers(1, &vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, len(points) * size_of(f32), raw_data(points), gl.STATIC_DRAW)

    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(f32) * 3, 0)

    gl.DrawArrays(gl.TRIANGLES, 0, i32(len(points)))
    ctx.draw_calls += 1
}

draw_string_absolute :: proc(
    position: Vec2,
    text: string,
    rotation: f32 = 0.0,
    color: Color = Color{1.0, 1.0, 1.0, 1.0},
    scale: Vec2 = Vec2 {1, 1},
) {
    gl.BindVertexArray(0)
    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, ctx.atlas_texture)

    gl.UseProgram(ctx.font_shader)

    transform := linalg.matrix4_translate(Vec3{position.x, position.y, 0.0})
    transform = transform * linalg.matrix4_rotate(rotation, Vec3{0, 0, 1})
    transform = transform * linalg.matrix4_scale(Vec3{scale.x, scale.y, 1})
    shader_uniform_mat4(ctx.font_shader, "Transform", transform)
    shader_uniform_vec4(ctx.font_shader, "Color", color)
    vbo: u32
    gl.GenBuffers(1, &vbo)
    defer gl.DeleteBuffers(1, &vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    buffer_size := len(text) * 4 * 6 * size_of(f32)
    gl.BufferData(gl.ARRAY_BUFFER, buffer_size, nil, gl.DYNAMIC_DRAW)

    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 4, gl.FLOAT, false, size_of(f32) * 4, 0)

    w, h := i32(ctx.font_atlas.img.width), i32(ctx.font_atlas.img.height)
    xpos, ypos: f32
    quad: ttf.aligned_quad
    // NOTE(minebill): This is really stupid,
    // i'm only doing this to fix some weird highlighting in my
    // editor.
    t := text
    for r, index in &t {
        chardata := ctx.font_atlas.chardata[r]

        ttf.GetPackedQuad(
            &chardata,
            w, h,
            0,
            &xpos, &ypos,
            &quad,
            true,
        )

        uv_tl := Vec2{quad.s0, quad.t1}
        uv_br := Vec2{quad.s1, quad.t0}

        x0 := quad.x0
        y0 := (ypos - (ypos + quad.y1))

        x1 := quad.x1
        y1 := (ypos - (ypos + quad.y0))

        vertices := [?]f32{
            x0, y1, uv_tl.x, uv_br.y, // Bottom Left
            x1, y1, uv_br.x, uv_br.y, // Bottom Right
            x0, y0, uv_tl.x, uv_tl.y, // Top Left

            x1, y1, uv_br.x, uv_br.y, // Bottom Right
            x1, y0, uv_br.x, uv_tl.y, // Top Right
            x0, y0, uv_tl.x, uv_tl.y, // Top Left
        }

        offset := index * len(vertices) * size_of(f32)
        gl.BufferSubData(gl.ARRAY_BUFFER, offset, len(vertices) * size_of(f32), &vertices)
    }
    gl.DrawArrays(gl.TRIANGLES, 0, 6 * i32(len(text)))
    ctx.draw_calls += 1
}

draw_string :: proc(
    position: Vec2,
    text: string,
    screen: Vec2,
    text_align: Text_Align = .BOTTOM_LEFT,
    rotation: f32 = 0.0,
    color: Color = Color{1.0, 1.0, 1.0, 1.0},
    scale: Vec2 = Vec2 {1, 1},
) {

    // Assume align of BOTTOM_LEFT
    width := measure_text(text)
    height := f32(ctx.font_atlas.max_rune_size.y)
    pos := screen * position
    switch text_align {
        // Do nothing
        case .BOTTOM_LEFT: unreachable("Not implemented")
        case .BOTTOM_RIGHT:
        pos.x -= width
        case .TOP_LEFT:    unreachable("Not implemented")
        case .TOP_RIGHT:   unreachable("Not implemented")
        case .CENTER:
        pos.x -= width / 2
    }
    draw_string_absolute(pos, text, rotation, color, scale)
}

measure_text :: proc(s: string) -> (width: f32) {
    // FIXME(minebill): Remove this
    ss := s
    for char in &ss {
        data := ctx.font_atlas.chardata[char]
        // NOTE(minebill): How does kerning work in non-monospaced fonts?
        // if index < utf8.rune_count(transmute([]u8)s) - 1 {
        //     next_rune := utf8.rune_at(s, index +  1)
        //     kern := f32(ttf.GetCodepointKernAdvance(fonts[0].info, char, next_rune))
        //     width += kern
        // }
        // kerning := index < utf8.rune_count(transmute([]u8)s) ?
        width += data.xadvance
    }
    return width
}
