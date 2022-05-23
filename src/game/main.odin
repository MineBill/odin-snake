package game

import "core:log"
import "core:time"
import gl "vendor:OpenGL"
import "vendor:glfw"

WINDOW_WIDTH :: 480
WINDOW_HEIGHT :: 480
WINDOW_TITLE :: "OpenGL in Odin"

Run_State :: enum {
    Stop,
    Continue,
}

load_opengl :: proc() {
    log.info("Loading OpenGL 4.6")
    gl.load_up_to(4, 6, glfw.gl_set_proc_address)
}

create_window :: proc(title: string, width, height: i32) -> glfw.WindowHandle {
    log.info("Initializing GLFW")
    if !bool(glfw.Init()) {
        log.errorf("Failed to initialize GLFW", glfw.GetError())
        return nil
    }

    glfw.WindowHint(glfw.RESIZABLE, 0)
    handle := glfw.CreateWindow(width, height, cstring(raw_data(title)), nil, nil)
    if handle == nil {
        description, code := glfw.GetError()
        log.error("Failed to create GLFW window. Description: `%v` Code: `%v`", description, code)
        return nil
    }

    return handle
}

main :: proc() {
    context.logger = log.create_console_logger(opt = {.Level})
    log.info("Initializing")
    state := Game_State{}

    state.window_handle = create_window(WINDOW_TITLE, WINDOW_WIDTH, WINDOW_HEIGHT)
    width, height := glfw.GetWindowSize(state.window_handle)
    state.window_size = Vec2{f32(width), f32(height)}

    glfw.MakeContextCurrent(state.window_handle)
    load_opengl()

    game_init(&state)

    time_previous: time.Tick
    time_now: time.Tick

    t := time.now()
    for !glfw.WindowShouldClose(state.window_handle) {
        glfw.PollEvents()

        time_previous = time_now
        time_now = time.tick_now()
        diff := time.tick_diff(time_previous, time_now)
        state.delta = time.duration_seconds(diff)

        if game_main_loop(&state) == .Stop {
            log.info("Game requested .Stop")
            break
        }


        glfw.SwapBuffers(state.window_handle)
    }
    log.info("Terminating")

    game_deinit(&state)
}
