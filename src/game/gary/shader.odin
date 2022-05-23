package gary

import "core:log"
import gl "vendor:OpenGL"
import "core:math/linalg"

Shader :: u32

shader_from_source :: proc(vertex_src: ^cstring, frag_src: ^cstring) -> Shader {
    vertex := gl.CreateShader(gl.VERTEX_SHADER)
    defer gl.DeleteShader(vertex)
    gl.ShaderSource(vertex, 1, vertex_src, nil)
    gl.CompileShader(vertex)
    shader_report_compilation_error(vertex)

    frag := gl.CreateShader(gl.FRAGMENT_SHADER)
    defer gl.DeleteShader(frag)
    gl.ShaderSource(frag, 1, frag_src, nil)
    gl.CompileShader(frag)
    shader_report_compilation_error(frag)

    program := gl.CreateProgram()
    gl.AttachShader(program, vertex)
    gl.AttachShader(program, frag)
    gl.LinkProgram(program)
    return program
}

shader_uniform_vec2 :: proc(shader: Shader, name: string, vec: Vec2) {
    gl.UseProgram(shader)
    if loc := gl.GetUniformLocation(shader, cstring(raw_data(name))); loc != -1 {
        gl.Uniform2f(loc, vec.x, vec.y)
    } else {
        log.warnf("Shader uniform not found `%v`", name)
    }
}

shader_uniform_vec3 :: proc(shader: Shader, name: string, vec: Vec3) {
    gl.UseProgram(shader)
    if loc := gl.GetUniformLocation(shader, cstring(raw_data(name))); loc != -1 {
        gl.Uniform3f(loc, vec.x, vec.y, vec.z)
    } else {
        log.warnf("Shader uniform not found `%v`", name)
    }
}

shader_uniform_vec4 :: proc(shader: Shader, name: string, vec: Vec4) {
    gl.UseProgram(shader)
    if loc := gl.GetUniformLocation(shader, cstring(raw_data(name))); loc != -1 {
        gl.Uniform4f(loc, vec.x, vec.y, vec.z, vec.w)
    } else {
        log.warnf("Shader uniform not found `%v`", name)
    }
}

shader_uniform_mat4 :: proc(program: Shader, name: string, mat: linalg.Matrix4f32) {
    m := mat
    gl.UseProgram(program)
    if loc := gl.GetUniformLocation(program, cstring(raw_data(name))); loc != -1 {
        gl.UniformMatrix4fv(loc, 1, false, cast([^]f32)&m)
    } else {
        log.warnf("Shader uniform not found `%v`", name)
    }
}

@(private = "file")
shader_report_compilation_error :: proc(shader: Shader) {
    success := i32(0)
    message := [512]u8{}
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success)
    if (success == 0) {
        gl.GetShaderInfoLog(shader, 512, nil, &message[0])
        log.errorf("Shader error: %s\n", message)
    }
}
