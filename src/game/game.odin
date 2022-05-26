package game

import "core:log"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:runtime"
import "core:math/rand"
import "core:image/png"
import "core:c"

import "vendor:glfw"
import "vendor:stb/image"
import gl "vendor:OpenGL"
import "gary"
import "gary/ui"

Vec2 :: gary.Vec2
Vec3 :: gary.Vec3
Color :: gary.Color

DEBUG_EVENTS :: false

GRID_WIDTH  :: 10
GRID_HEIGHT :: 10
GRID_SIZE   :: Vec2{GRID_WIDTH, GRID_HEIGHT}
UNIT_SIZE   :: Vec2{1.0, 1.0}
CAMERA_SIZE :: 6
UI_CAMERA_SIZE :: CAMERA_SIZE

COLOR_DARK       :: Color{0.2, 0.2, 0.2, 1.0}
COLOR_LIGHT_DARK :: Color{0.4, 0.4, 0.4, 1.0}
COLOR_YELLOW     :: Color{0.98, 0.753, 0.231, 1.0}
COLOR_RED        :: Color{0.98, 0.353, 0.231, 1.0}
COLOR_WHITE      :: Color{1.0, 1.0, 1.0, 1.0}

PLAYER_MOVE_TIME  :: 0.2
PLAYER_HEAD_COLOR :: COLOR_YELLOW
PLAYER_TAIL_COLOR :: Color{0.3, 0.6, 0.2, 1.0}

Event_Kind :: enum u8 {
    KEY_UP,
    KEY_DOWN,
    KEY_REPEAT,

    WINDOW_RESIZED,
}

Event :: struct {
    kind: Event_Kind,
    key:  int,
}

Key_Event :: struct {
    key: int,
}
Window_Resized_Event :: struct {}

Kek :: union {
    Key_Event,
    Window_Resized_Event,
}

check_out_of_bounds :: proc(pos, min, max: Vec2) -> bool {
    return pos.x < min.x || pos.y < min.y || pos.x >= max.x || pos.y >= max.y
}

check_position :: proc(a, b: Vec2) -> bool {
    return a.x == b.x && a.y == b.y
}

// glfw events

glfw_key :: proc "cdecl" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
    // NOTE(minebill): Maybe this is not needed? 
    // (It actually is needed to call create_camera but is it actually needed?)
    context = runtime.default_context()
    state := cast(^Game_State)glfw.GetWindowUserPointer(window)
    switch action {
        case glfw.PRESS:
        append(&state.events, Event{
            kind = .KEY_DOWN,
            key = int(key),
        })
        case glfw.RELEASE:
        append(&state.events, Event{
            kind = .KEY_UP,
            key = int(key),
        })
        case glfw.REPEAT:
        append(&state.events, Event{
            kind = .KEY_REPEAT,
            key = int(key),
        })
    }
}

What :: []i32{1, 2}

glfw_resized :: proc "cdecl" (window: glfw.WindowHandle, width, height: i32) {
    // NOTE(minebill): Maybe this is not needed? 
    // (It actually is needed to call create_camera but is it actually needed?)
    context = runtime.default_context()
    state := cast(^Game_State)glfw.GetWindowUserPointer(window)
    gl.Viewport(0, 0, width, height)
    state.window_size = Vec2{f32(width), f32(height)}

    state.game_camera.projection = create_camera_projection(state.game_camera.size, state.window_size.x,
        state.window_size.y)
    state.ui_camera.projection = create_orthographic_projection(
        0, state.window_size.x,
        0, state.window_size.y,
        -1, 1,
    )
}

glfw_mouse_moved :: proc "c" (window: glfw.WindowHandle, x, y: f64) {
    state := cast(^Game_State)glfw.GetWindowUserPointer(window)
    state.mouse_position = Vec2{f32(x) / WINDOW_WIDTH, f32(-y) / WINDOW_HEIGHT}
}

create_orthographic_projection :: proc "contextless" (
    left,
    right,
    bottom,
    up,
    near,
    far: f32,
) -> (
    m: linalg.Matrix4f32,
) {
    //odinfmt: disable
    m = linalg.Matrix4f32{
        2 / (right - left), 0                , 0                , -(right + left) / (right - left),
        0                 , 2 / (up - bottom), 0                , -(up + bottom) / (up - bottom),
        0                 , 0                , -2 / (far - near), -(far + near) / (far - near),
        0                 , 0                , 0                , 1,
    }
    //odinfmt: enable
    return
}

create_camera_projection :: proc(size, width, height: f32) -> linalg.Matrix4f32 {
    aspect := width / height
    projection := create_orthographic_projection(
        -aspect * size,
        aspect * size,
        -size,
        size,
        -1.0,
        1.0,
    )
    return projection
}

camera_get_transform :: proc(camera: ^Camera) -> linalg.Matrix4f32 {
    transform := linalg.matrix4_translate(
        Vec3{camera.position.x, camera.position.y, 0.0},
    )
    transform = linalg.matrix4_rotate_f32(camera.rotation, {0, 0, 1}) * linalg.matrix4_inverse_f32(
                   transform)
    return camera.projection * transform
}

game_init :: proc(state: ^Game_State) {
    log.info("Initializing game stuff")
    glfw.SetWindowUserPointer(state.window_handle, state)
    glfw.SetKeyCallback(state.window_handle, glfw_key)
    glfw.SetWindowSizeCallback(state.window_handle, glfw_resized)
    glfw.SetCursorPosCallback(state.window_handle, glfw_mouse_moved)

    glfw.SwapInterval(-1)

    gary.init()

    state.game_camera = Camera {
        size = CAMERA_SIZE,
        projection = create_camera_projection(
            CAMERA_SIZE,
            state.window_size.x,
            state.window_size.y,
        ),
        position = Vec2{0, 0},
        rotation = 0.0,
    }

    state.ui_camera = Camera {
        size = UI_CAMERA_SIZE,
        projection = create_orthographic_projection(
            0, state.window_size.x,
            0, state.window_size.y,
            -1, 1,
        ),
    }

    state.next_apple = GRID_SIZE - Vec2{1, 1}

    if image, err := png.load_from_bytes(#load("../../assets/snake_head.png")); err == nil {
        log.infof("Channels: %v", image.channels)
        state.snake_texture = gary.load_texture(image.width, image.height, image.channels, raw_data(image.pixels.buf))
        // delete(image.pixels.buf)
    } else {
        log.error(err)
    }

    if image, err := png.load_from_bytes(#load("../../assets/apple.png")); err == nil {
        log.infof("Channels: %v", image.channels)
        state.apple_texture = gary.load_texture(image.width, image.height, image.channels, raw_data(image.pixels.buf))
        // delete(image.pixels.buf)
    } else {
        log.error(err)
    }
}

game_deinit :: proc(state: ^Game_State) {
    delete(state.events)
    gary.deinit()
}

game_main_loop :: proc(state: ^Game_State) -> Run_State {
    ret := update(state)
    render(state)
    return ret
}

update_player :: proc(state: ^Game_State) -> Run_State {
    old_pos := state.player.position
    state.player.position += state.player.direction

    for piece in &state.player.tail {
        if check_position(state.player.position, piece) {
            return .Stop
        }
    }

    if check_out_of_bounds(state.player.position, {0.0, 0.0}, GRID_SIZE) {
        state.player.position = old_pos
        log.infof("Score: %v", len(state.player.tail))
        return .Stop
    }

    if check_position(state.player.position, state.next_apple) {
        append(&state.player.tail, Vec2{})
        state.next_apple = Vec2 {
            f32(rand.int31() % GRID_WIDTH),
            f32(rand.int31() % GRID_HEIGHT),
        }
    }

    previous_pos := old_pos
    for piece in &state.player.tail {
        previous_pos, piece = piece, previous_pos
    }
    return .Continue
}

update :: proc(state: ^Game_State) -> Run_State {
    for len(state.events) > 0 {
        event := pop_front(&state.events)
        when DEBUG_EVENTS {
            log.infof("Processing event: %#v", event)
        }

        #partial switch event.kind {
        case .KEY_DOWN:
            old_pos := state.player.position
            switch event.key {

            case glfw.KEY_W:
            state.player.direction = {0, 1}
            if update_player(state) != .Continue {
                return .Stop

            }

            case glfw.KEY_S:
            state.player.direction = {0, -1}
            if update_player(state) != .Continue {
                return .Stop
            }

            case glfw.KEY_D:
            state.player.direction = {1, 0}
            if update_player(state) != .Continue {
                return .Stop
            }

            case glfw.KEY_A:
            state.player.direction = {-1, 0}
            if update_player(state) != .Continue {
                return .Stop
            }

            case glfw.KEY_ESCAPE:
            glfw.SetWindowShouldClose(state.window_handle, true)
        }
        }
    }

    state.running_time += state.delta

    // if state.running_time - state.previous_move_time > PLAYER_MOVE_TIME {
    //     state.previous_move_time = state.running_time

    //     if update_player(state) != .Continue {
    //         return .Stop
    //     }
    // }

    return .Continue
}

render :: proc(state: ^Game_State) {
    using state
    using gary
    // I use bspwm on linux so the titlebar is not visible
    when ODIN_OS == .Windows {
        glfw.SetWindowTitle(
            window_handle,
            cast(cstring)raw_data(fmt.tprintf("Delta: %v", delta)))
    }

    draw_clear(Color{0.1, 0.1, 0.1, 1.0})
    draw_begin(
        camera_get_transform(&game_camera),
    )

    for x in 0 ..< GRID_WIDTH {
        for y in 0 ..< GRID_HEIGHT {
            position := Vec2{f32(x), f32(y)} - GRID_SIZE / 2 + UNIT_SIZE / 2
            draw_quad(
                position = position,
                color = ((x + y) % 2 == 0) ? COLOR_DARK : COLOR_LIGHT_DARK)
        }
    }

    for piece in state.player.tail {
        draw_quad(
            piece + UNIT_SIZE / 2 - GRID_SIZE / 2, 0.0, PLAYER_TAIL_COLOR)
    }

    player_draw_pos := player.position + UNIT_SIZE / 2 - GRID_SIZE / 2
    draw_texture(
        snake_texture,
        player_draw_pos, 0.0, PLAYER_HEAD_COLOR)

    draw_string_absolute(
        player_draw_pos,
        "Player",
        0.0,
        COLOR_RED,
        Vec2{1, 1} / 32,
    )

    draw_texture(
        apple_texture,
        next_apple + UNIT_SIZE / 2 - GRID_SIZE / 2, 0.0)


    draw_begin(camera_get_transform(&ui_camera))

    draw_quad_points(
        position = Vec2{0, 0},
        points = []f32{
            0, 0, 0,
            1, 1, 0,
            1, 0, 0,
            0, 0, 0,
            0, 1, 0,
            1, 1, 0,
        },
        scale = Vec2{1, 1},
        color = COLOR_RED,
    )

    draw_string(
        Vec2{0.5, 1},
        fmt.tprintf("Score: %v", len(state.player.tail)),
        window_size,
        Text_Align.Top_Center,
    )
}
