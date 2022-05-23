package gary

import gl "vendor:OpenGL"
import "core:image/png"
import "core:log"

Texture_Handle :: u32

@(private)
get_gl_channels :: proc(num: int) -> i32 {
    switch num {
        case 1: return gl.RED
        case 2: return gl.RG
        case 3: return gl.RGB
        case 4: return gl.RGBA
    }
    return 0
}

load_texture :: proc(width, height, channels: int, pixels: rawptr) -> (handle: Texture_Handle) {
    log.infof("Loading image(width: %v, height: %v, channels: %v)", width, height, channels)
    gl.GenTextures(1, &handle)
    gl.BindTexture(gl.TEXTURE_2D, handle)

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    ch := get_gl_channels(channels)
    gl.TexImage2D(gl.TEXTURE_2D, 0, ch, i32(width), i32(height), 0, u32(ch), gl.UNSIGNED_BYTE, pixels)
    gl.GenerateMipmap(gl.TEXTURE_2D)
    return
}
