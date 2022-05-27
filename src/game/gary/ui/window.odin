package ui
// import "core:math/linalg"
import ".."

// Vec2 :: linalg.Vector2f32
Vec2 :: gary.Vec2
Vec3 :: gary.Vec3
Rect :: gary.Vec4
Color :: gary.Color

Button_Id :: int
Window_Id :: int

Window :: struct {
    pos:         Vec2,
    size:        Vec2,
    drag_offset: Vec2,
    dragged:     bool,
    resized:     bool,
}

UI_State :: struct {
    mouse:         Vec2,
    mouse_down:    bool,
    mouse_up:      bool,

    active_button: Button_Id,
    hot_button:    Button_Id,

    hot_window:    Window_Id,
    active_window: Window_Id,
    windows:       map[Window_Id]^Window,
}

global_ui_state: UI_State

@(private)
rect_has_point :: proc(rect: Rect, point: Vec2) -> bool {
    return point.x > rect.x &&
           point.y > rect.y &&
           point.x < rect.x + rect.z &&
           point.y < rect.y + rect.w
}


start :: proc() {
    global_ui_state.hot_button = 0
    global_ui_state.hot_window = 0
}

end :: proc() {
    if !global_ui_state.mouse_down {
        global_ui_state.active_button = 0
        global_ui_state.active_window = 0
    }
    global_ui_state.mouse_down = false
    global_ui_state.mouse_up   = false
}

button :: proc(id: Button_Id, text: string, pos: Vec2) -> bool {
    using gary

    BUTTON_NORMAL_COLOR  :: Color{0.3, 0.3, 0.3, 1.0}
    BUTTON_HOT_COLOR     :: Color{0.4, 0.4, 0.4, 1.0}
    BUTTON_PRESSED_COLOR :: Color{0.1, 0.1, 0.1, 1.0}

    BUTTON_PADDING :: Vec2{10, 10}
    rect := Rect{}
    rect.xy = cast([2]f32)(pos - BUTTON_PADDING)
    rect.zw = cast([2]f32)(Vec2{measure_text(text), f32(gary.ctx.font_atlas.max_rune_size.y)} + BUTTON_PADDING)

    if rect_has_point(rect, global_ui_state.mouse) {
        global_ui_state.hot_button = id
        if global_ui_state.mouse_down {
            global_ui_state.active_button = id
            draw_quad_size(position = rect.xy, size = rect.zw, color = BUTTON_PRESSED_COLOR)
        } else {
            draw_quad_size(position = rect.xy, size = rect.zw, color = BUTTON_HOT_COLOR)
        }
    } else {
        draw_quad_size(position = rect.xy, size = rect.zw, color = BUTTON_NORMAL_COLOR)
    }

    draw_string_absolute(Vec2{pos.x, pos.y}, text)

    if global_ui_state.active_button == id &&
       global_ui_state.hot_button == id &&
       !global_ui_state.mouse_down {
        return true
    }

    return false
}

window :: proc(id: Window_Id, text: string, size := Vec2{100, 150}) {
    using gary

    WINDOW_BG_COLOR :: Color{0.4, 0.1, 0.1, 1.0}
    WINDOW_RESIZE_RECT_COLOR :: Color{0.8, 0.4, 0.4, 1.0}
    WINDOW_RESIZE_RECT_HOT_COLOR :: Color{1.0, 0.6, 0.6, 1.0}

    TITLE_BAR_BG_COLOR :: Color{0.3, 0.1, 0.1, 1.0}
    TITLE_BAR_HEIGHT :: 20

    win, ok := global_ui_state.windows[id]
    if !ok {
        // FIXME(minebill): Free this
        win = new(Window)
        win^ = Window{Vec2{}, size, Vec2{}, false, false}
        global_ui_state.windows[id] = win
    }

    resize_handle_rect := Rect{
        win.pos.x + win.size.x - 10,
        win.pos.y + win.size.y - 10,
        10, 10,
    }

    // Title bar
    title_bar_rect := Rect{
        win.pos.x, win.pos.y,
        win.size.x, TITLE_BAR_HEIGHT,
    }
    draw_quad_size(
        position = title_bar_rect.xy,
        size     = title_bar_rect.zw,
        color    = TITLE_BAR_BG_COLOR,
    )

    if win.dragged {
        if global_ui_state.mouse_up {
            win.dragged = false
        }
        win.pos = global_ui_state.mouse - win.drag_offset
    } else {
        if global_ui_state.active_window == 0 {
            if rect_has_point(title_bar_rect, global_ui_state.mouse) {
                global_ui_state.hot_window = id
                if global_ui_state.mouse_down {
                    global_ui_state.active_window = id
                    win.drag_offset = global_ui_state.mouse - win.pos
                    win.dragged = true
                }
            }
        }
    }

    // Content window
    draw_quad_size(
        position = Vec2{win.pos.x, win.pos.y + TITLE_BAR_HEIGHT},
        size     = Vec2{win.size.x, win.size.y - TITLE_BAR_HEIGHT},
        color    = WINDOW_BG_COLOR,
    )

    // Resize handle
    if win.resized {
        if global_ui_state.mouse_up {
            win.resized = false
        }
        win.size = global_ui_state.mouse - win.pos
        draw_quad_size(position = resize_handle_rect.xy, size = resize_handle_rect.zw, color = WINDOW_RESIZE_RECT_COLOR)
    } else {
        if global_ui_state.active_window == 0 {
            if rect_has_point(resize_handle_rect, global_ui_state.mouse) {
                global_ui_state.hot_window = id
                if global_ui_state.mouse_down {
                    global_ui_state.active_window = id
                    win.resized = true
                }

                draw_quad_size(position = resize_handle_rect.xy, size = resize_handle_rect.zw, color = WINDOW_RESIZE_RECT_HOT_COLOR)
            }
        }
    }
}
