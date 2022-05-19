package game

import "vendor:glfw"
import "core:math/linalg"
import "dd"

Camera :: struct {
    projection: linalg.Matrix4f32,
    position:   dd.Vec2,
    rotation:   f32,
    size:       f32,
}

Player :: struct {
    position:  dd.Vec2,
    direction: dd.Vec2,
    tail:      [dynamic]dd.Vec2,
}

Game_State :: struct {
    window_handle:      glfw.WindowHandle,
    drawing_context:    dd.Drawing_Context,
    mouse_position:     dd.Vec2,
    camera:             Camera,
    window_size:        dd.Vec2,
    player:             Player,
    events:             [dynamic]Event,
    delta:              f64,
    previous_move_time: f64,
    running_time:       f64,
    next_apple:         dd.Vec2,
}
