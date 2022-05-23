package game

import "vendor:glfw"
import "core:math/linalg"
import "gary"

Camera :: struct {
    projection: linalg.Matrix4f32,
    position:   Vec2,
    rotation:   f32,
    size:       f32,
}

Player :: struct {
    position:  Vec2,
    direction: Vec2,
    tail:      [dynamic]Vec2,
}

Game_State :: struct {
    window_handle:      glfw.WindowHandle,
    drawing_context:    gary.Drawing_Context,
    mouse_position:     Vec2,
    camera:             Camera,
    window_size:        Vec2,
    player:             Player,
    events:             [dynamic]Event,
    delta:              f64,
    previous_move_time: f64,
    running_time:       f64,
    next_apple:         Vec2,
    apple_texture:      gary.Texture_Handle,
    snake_texture:      gary.Texture_Handle,
}
