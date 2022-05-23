package gary

import ttf "vendor:stb/truetype"
import "core:os"
import "core:math"
import "core:log"
import "core:fmt"

import "core:image"
import "core:image/netpbm"
import "core:slice"

// These runes are always going to be added to the glyph map
BASIC_RUNES :: "abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789 .,:;({[<>]})?!+-*/=@#$%^&~`\""

Font :: struct {
    filename: string,
    data:     []u8,
    info:     ^ttf.fontinfo,
    in_use:   bool,

    ascent:   f32,
    descent:  f32,
}

Glyph :: struct {
    font:     int,
    glyph_id: i32,
}

Glyph_Metrics :: struct {
    scale:             f32,

    advance_width:     f32,
    left_side_bearing: f32,
}

glyph_map: map[rune]Glyph

NUM_FONTS :: 1
fonts: [NUM_FONTS]Font

font_names := [NUM_FONTS]string{
    "../assets/JetBrainsMono-Regular.ttf",
}

get_all_unique_runes_to_load :: proc() {
    for r in BASIC_RUNES do if r not_in glyph_map {
        glyph_map[r] = Glyph{}
    }
  // add other characters you're going to use
}

load_fonts :: proc() {
    // Set up glyphs
    get_all_unique_runes_to_load()

    log.infof("Found %v unique codepoints to load from fonts.", len(glyph_map))

    glyphs_found := 0

    ok: bool

    font_loop: for font_path, i in font_names {
        if fonts[i].info, fonts[i].data, ok = load_font(font_path); !ok {
            continue
        }
        log.infof("Loading font[%v] %v: %v\n", i, font_path, ok)
        fonts[i].filename = font_path

        ascent, descent, linegap: i32
        ttf.GetFontVMetrics(fonts[i].info, &ascent, &descent, &linegap)

        fonts[i].ascent  = f32(ascent)
        fonts[i].descent = f32(descent)

        // Try to look up glyphs that don't yet have a font/glyph set
        for r, g in glyph_map do if g.glyph_id == 0 {
            glyph_id := ttf.FindGlyphIndex(fonts[i].info, r)

            if glyph_id != 0 {
                // Mark font as in use
                fonts[i].in_use = true

                // Updqte rune to point at font and glyph id
                glyph_map[r] = Glyph{
                    font     = i,
                    glyph_id = glyph_id,
                }

                glyphs_found += 1
                if glyphs_found == len(glyph_map) {
                    // We have them all, no need to check any further fonts.
                    break font_loop
                }
            }
        }
    }

    for r, g in glyph_map {
        if g.glyph_id == 0 {
            log.errorf("Glyph for %v not found in any of the fonts.\n", r)
        }
    }
}

make_image :: proc(width, height, channels: int) -> (img: ^image.Image) {
    bytes_needed := image.compute_buffer_size(width, height, channels, 8)
    img = new_clone(image.Image{
        width    = width,
        height   = height,
        channels = channels,
        depth    = 8,
    })
    resize(&img.pixels.buf, bytes_needed)
    return
}

Atlas :: struct {
    img:           ^image.Image,
    ctx:           ^ttf.pack_context,
    chardata:      map[rune]ttf.packedchar,
    max_rune_size: [2]int,
}

destroy_atlas :: proc(atlas: ^Atlas) {
    image.destroy(atlas.img)
    ttf.PackEnd(atlas.ctx)

    delete(atlas.chardata)

    free(atlas.ctx)
    free(atlas)
}

make_font_atlas :: proc(point_size: f32, padding := 1, oversample := u32(1)) -> (atlas: ^Atlas, ok: bool) {
    MAX_WIDTH  :: 4096

    atlas = new(Atlas)
    atlas.ctx = new(ttf.pack_context)

    log.infof("Building font atlas for point size %v\n", point_size)

    /*
        Calculate necessary atlas size, roughly.
    */
    total_size: [2]i32

    for r, g in glyph_map {
        font_info := fonts[g.font].info

        scale := ttf.ScaleForPixelHeight(font_info, point_size)

        bottom_left: [2]i32
        top_right:   [2]i32

        ttf.GetGlyphBitmapBox(font_info, transmute(i32)r, scale, scale, &bottom_left.x, &bottom_left.y, &top_right.x, &top_right.y)

        size := top_right - bottom_left

        total_size.y  = max(total_size.y, size.y)
        total_size.x += size.x
    }

    total_pixels := total_size.x * total_size.y
    square_size  := math.sqrt(f32(total_pixels))

    width := int(math.round(square_size)) + 1
    pot   := 1

    for pot < width && pot <= MAX_WIDTH {
        pot <<= 1
    }

    width = pot

    height := int(math.round(f32(total_pixels) / f32(width) + point_size)) + 1

    width  *= int(oversample)
    height *= int(oversample)

    log.infof("\tWidth: %v, Heigth: %v", width, height)

    atlas.img = make_image(width, height, 1)

    stride := width

    // Gather glyph ranges per font and render them into the font packer.
    if ttf.PackBegin(atlas.ctx, &atlas.img.pixels.buf[0], i32(width), i32(height), i32(stride), i32(padding), nil) != 1 {
        log.error("PackBegin failed")
        return atlas, false
    }

    ttf.PackSetOversampling(atlas.ctx, u32(oversample), u32(oversample))

    for font, font_idx in fonts do if font.in_use {
        runes_in_font: [dynamic]rune
        defer delete(runes_in_font)

        for r, g in glyph_map do if g.font == font_idx {
            append(&runes_in_font, r)
        }
        slice.sort(runes_in_font[:])

        char_data := make([]ttf.packedchar, len(runes_in_font))
        defer delete(char_data)

        range := ttf.pack_range{
            font_size = point_size,
            array_of_unicode_codepoints = &runes_in_font[0],
            num_chars = i32(len(runes_in_font)),
            chardata_for_range = &char_data[0],
        }

        if ttf.PackFontRanges(atlas.ctx, &font.data[0], 0, &range, 1) != 1 {
            log.error("Packing glyphs failed")
            return atlas, false
        }

        for r, i in runes_in_font {
            atlas.chardata[r] = char_data[i]

            atlas.max_rune_size.x = max(atlas.max_rune_size.x, int(char_data[i].x1 - char_data[i].x0))
            atlas.max_rune_size.y = max(atlas.max_rune_size.y, int(char_data[i].y1 - char_data[i].y0))
        }
    }
    return atlas, true
}

load_font :: proc(file: string) -> (font: ^ttf.fontinfo, data: []u8, ok: bool) {
    data = os.read_entire_file(file) or_return

    font = new(ttf.fontinfo)
    res := ttf.InitFont(font, &data[0], 0)

    return font, data, bool(res)
}

destroy_fonts :: proc() {
    for font in fonts {
        destroy_font(font.info)
        delete(font.data)
    }
}

destroy_font :: proc(font: ^ttf.fontinfo) {
    if font == nil {
        return
    }
    free(font)
}

get_glyph_metrics :: proc(font: ^ttf.fontinfo, char: rune, scale: f32) -> (res: Glyph_Metrics) {
    w, l: i32
    ttf.GetCodepointHMetrics(font, char, &w, &l)

    res = Glyph_Metrics{
        scale             = scale,
        advance_width     = math.round(f32(w) * scale),
        left_side_bearing = math.round(f32(l) * scale),
    }
    return
}

get_rune_advance :: proc(char, next: rune, point_size: f32) -> (kern: int) {
    char_glyph, next_glyph := glyph_map[char],        glyph_map[next]
    char_font,  next_font  := fonts[char_glyph.font], fonts[next_glyph.font]

    char_k := ttf.GetCodepointKernAdvance(char_font.info, char, next)
    next_k := ttf.GetCodepointKernAdvance(next_font.info, char, next)

    char_scale := ttf.ScaleForPixelHeight(char_font.info, point_size)
    next_scale := ttf.ScaleForPixelHeight(next_font.info, point_size)

    if abs(char_k) >= abs(next_k) {
        return int(math.round(f32(char_k) * char_scale))
    } else {
        return int(math.round(f32(next_k) * next_scale))
    }
    unreachable()
}

@(private="file")
font_demo :: proc() {
    defer destroy_fonts()
    defer delete(glyph_map)

    load_fonts()

    atlas, ok := make_font_atlas(32)
    defer destroy_atlas(atlas)

    if !ok {
        return
    }

    foozle := "Foozle!"

    xpos, ypos: f32
    q: ttf.aligned_quad

    w, h := i32(atlas.img.width), i32(atlas.img.height)

    for r in foozle {
        chardata := atlas.chardata[r]
        ttf.GetPackedQuad(
            &chardata,
            w, h,
            0,
            &xpos, &ypos,
            &q,
            true, // align to integer
        )
        fmt.printf("%v: %v\n", r, q)
    }

    err := netpbm.save("font.pgm", atlas.img)
    fmt.printf("font.pgm: %v\n", err)
}
