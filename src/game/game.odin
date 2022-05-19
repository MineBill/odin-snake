package game

import "core:log"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:runtime"
import "core:math/rand"
import "vendor:stb/image"

import "vendor:glfw"
import gl "vendor:OpenGL"
import "dd"

DEBUG_EVENTS :: false

CAMERA_SIZE :: 5.0

GRID_WIDTH :: 8
GRID_HEIGHT :: 8
GRID_SIZE :: dd.Vec2{GRID_WIDTH, GRID_HEIGHT}

COLOR_DARK :: dd.Color{0.2, 0.2, 0.2, 1.0}
COLOR_LIGHT_DARK :: dd.Color{0.4, 0.4, 0.4, 1.0}
COLOR_YELLOW :: dd.Color{0.98, 0.753, 0.231, 1.0}
COLOR_RED :: dd.Color{0.98, 0.353, 0.231, 1.0}

PLAYER_MOVE_TIME :: 0.3
PLAYER_HEAD_COLOR :: COLOR_YELLOW
PLAYER_TAIL_COLOR :: dd.Color{0.3, 0.6, 0.2, 1.0}

Event_Kind :: enum {
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

check_out_of_bounds :: proc(pos, min, max: dd.Vec2) -> bool {
    return pos.x < min.x || pos.y < min.y || pos.x >= max.x || pos.y >= max.y
}

check_position :: proc(a, b: dd.Vec2) -> bool {
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
    state.window_size = dd.Vec2{f32(width), f32(height)}

    state.camera.projection = create_camera_projection(state.camera.size, state.window_size.x,
        state.window_size.y)
}

glfw_mouse_moved :: proc "c" (window: glfw.WindowHandle, x, y: f64) {
    state := cast(^Game_State)glfw.GetWindowUserPointer(window)
    state.mouse_position = dd.Vec2{f32(x) / WINDOW_WIDTH, f32(-y) / WINDOW_HEIGHT}
}

init :: proc(state: ^Game_State) {
    glfw.SetWindowUserPointer(state.window_handle, state)

    glfw.SetKeyCallback(state.window_handle, glfw_key)
    glfw.SetWindowSizeCallback(state.window_handle, glfw_resized)
    glfw.SetCursorPosCallback(state.window_handle, glfw_mouse_moved)
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
        dd.Vec3{camera.position.x, camera.position.y, 0.0},
    )
    transform = linalg.matrix4_rotate_f32(camera.rotation, {0, 0, 1}) * linalg.matrix4_inverse_f32(
                   transform)
    return camera.projection * transform
}

game_init :: proc(state: ^Game_State) {
    log.info("Initializing game stuff")
    init(state)
    glfw.SwapInterval(-1)

    state.drawing_context = dd.draw_init()

    state.camera.size = 6.0
    state.camera.projection = create_camera_projection(state.camera.size, state.window_size.x,
        state.window_size.y)
    state.camera.position = dd.Vec2{0, 0}
    state.camera.rotation = 0.0
    state.next_apple = GRID_SIZE - dd.Vec2{1, 1}
}

game_deinit :: proc(state: ^Game_State) {
}

game_main_loop :: proc(state: ^Game_State) -> Run_State {
    ret := update(state)
    render(state)
    return ret
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
            case glfw.KEY_S:
                state.player.direction = {0, -1}
            case glfw.KEY_D:
                state.player.direction = {1, 0}
            case glfw.KEY_A:
                state.player.direction = {-1, 0}
            case glfw.KEY_ESCAPE:
                glfw.SetWindowShouldClose(state.window_handle, true)
            }
        }
    }

    state.running_time += state.delta

    if state.running_time - state.previous_move_time > PLAYER_MOVE_TIME {
        state.previous_move_time = state.running_time

        old_pos := state.player.position
        state.player.position += state.player.direction

        for piece in &state.player.tail {
            if check_position(state.player.position, piece) {
                return .Stop
            }
        }

        if check_out_of_bounds(state.player.position, {0.0, 0.0}, GRID_SIZE) {
            state.player.position = old_pos
            return .Stop
        }

        if check_position(state.player.position, state.next_apple) {
            append(&state.player.tail, dd.Vec2{})
            state.next_apple = dd.Vec2 {
                f32(rand.int31() % GRID_WIDTH),
                f32(rand.int31() % GRID_HEIGHT),
            }
        }

        previous_pos := old_pos
        for piece in &state.player.tail {
            previous_pos, piece = piece, previous_pos
            // temp := piece
            // piece = previous_pos
            // previous_pos = temp
        }
    }

    return .Continue
}

UNIT_SIZE :: dd.Vec2{1.0, 1.0}

render :: proc(state: ^Game_State) {
    glfw.SetWindowTitle(
        state.window_handle,
        cast(cstring)raw_data(fmt.tprintf("Delta: %v", state.delta)))

    dd.draw_begin(
        &state.drawing_context,
        camera_get_transform(&state.camera),
        dd.Color{0.1, 0.1, 0.1, 1})

    for x in 0 ..< GRID_WIDTH {
        for y in 0 ..< GRID_HEIGHT {
            position := dd.Vec2{f32(x), f32(y)} - GRID_SIZE / 2 + UNIT_SIZE / 2
            dd.draw_quad(
                ctx = &state.drawing_context,
                position = position,
                color = (x + y) % 2 == 0 ? COLOR_DARK : COLOR_LIGHT_DARK)
        }
    }

    for piece in state.player.tail {
        dd.draw_quad(
            &state.drawing_context,
            piece + UNIT_SIZE / 2 - GRID_SIZE / 2, 0.0, PLAYER_TAIL_COLOR)
    }
    dd.draw_quad(
        &state.drawing_context,
        state.player.position + UNIT_SIZE / 2 - GRID_SIZE / 2, 0.0, PLAYER_HEAD_COLOR)

    dd.draw_quad(
        &state.drawing_context,
        state.next_apple + UNIT_SIZE / 2 - GRID_SIZE / 2, 0.0, COLOR_RED)

    // NOTE(minebill): This would be cool to do
    // dd.draw_text(
    //     &state.drawing_context,
    //     "KEKW PEPEGAS",
    // )

    dd.draw_end()
}
