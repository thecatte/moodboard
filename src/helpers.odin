package main

import "core:fmt"
import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"

update_window_title :: proc() {
	abs_path, ok := filepath.abs(save_file_path, context.temp_allocator)
	if !ok {
		abs_path = save_file_path
	}
	title := fmt.tprintf("Moodboard - %s", abs_path)
	rl.SetWindowTitle(strings.clone_to_cstring(title, context.temp_allocator))
}

get_mouse_world :: proc() -> rl.Vector2 {
	return rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
}

image_rect :: proc(img: BoardImage) -> rl.Rectangle {
	if img.failed {
		return {img.pos.x, img.pos.y, 300 * img.scale, 150 * img.scale}
	}
	w := f32(img.texture.width) * img.scale
	h := f32(img.texture.height) * img.scale
	return {img.pos.x, img.pos.y, w, h}
}

text_rect :: proc(t: BoardText) -> rl.Rectangle {
	measured := rl.MeasureTextEx(
		rl.GetFontDefault(),
		strings.clone_to_cstring(t.content, context.temp_allocator),
		t.font_size,
		1,
	)
	return {t.pos.x, t.pos.y, measured.x, measured.y}
}

point_in_rect :: proc(p: rl.Vector2, r: rl.Rectangle) -> bool {
	return p.x >= r.x && p.x <= r.x + r.width && p.y >= r.y && p.y <= r.y + r.height
}

model_rect :: proc(m: BoardModel) -> rl.Rectangle {
	w := f32(500) * m.scale
	h := f32(500) * m.scale
	return {m.pos.x, m.pos.y, w, h}
}

// Returns a small square handle at the bottom-right corner of a rect.
// The handle size is expressed in world units based on camera zoom so it
// stays a constant size on screen (~14px).
resize_handle_rect :: proc(r: rl.Rectangle) -> rl.Rectangle {
	sz := 22.0 / camera.zoom
	return {r.x + r.width - sz / 2, r.y + r.height - sz / 2, sz, sz}
}
