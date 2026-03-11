package main

import "core:math"
import "core:strings"
import rl "vendor:raylib"

draw :: proc() {
	rl.BeginDrawing()
	defer rl.EndDrawing()
	rl.ClearBackground({30, 30, 30, 255})

	// ── World space ──
	rl.BeginMode2D(camera)
	{
		// Draw grid
		draw_grid()

		// Draw images
		for &img, i in images {
			if img.failed {
				r := image_rect(img)
				rl.DrawRectangleLinesEx(r, 2.0 / camera.zoom, rl.RED)

				text_scale := img.scale
				rl.DrawTextEx(
					rl.GetFontDefault(),
					"failed to load",
					{img.pos.x + 10 * text_scale, img.pos.y + 10 * text_scale},
					20 * text_scale,
					1,
					rl.RED,
				)

				cpath := strings.clone_to_cstring(img.path, context.temp_allocator)
				rl.DrawTextEx(
					rl.GetFontDefault(),
					cpath,
					{img.pos.x + 10 * text_scale, img.pos.y + 40 * text_scale},
					14 * text_scale,
					1,
					rl.RED,
				)
			} else {
				rl.DrawTextureEx(img.texture, img.pos, 0, img.scale, rl.WHITE)
			}

			// Selection border
			if selection.kind == .Image && selection.index == i {
				r := image_rect(img)
				pad: f32 = img.failed ? 4.0 : 0.0
				rl.DrawRectangleLinesEx(
					{r.x - pad, r.y - pad, r.width + pad * 2, r.height + pad * 2},
					2.0 / camera.zoom,
					{0, 180, 255, 255},
				)
			}
		}

		// Draw texts
		for &t, i in texts {
			cstr := strings.clone_to_cstring(t.content, context.temp_allocator)
			rl.DrawTextEx(rl.GetFontDefault(), cstr, t.pos, t.font_size, 1, rl.WHITE)

			// Selection border
			if selection.kind == .Text && selection.index == i {
				r := text_rect(t)
				pad :: 4
				rl.DrawRectangleLinesEx(
					{r.x - pad, r.y - pad, r.width + pad * 2, r.height + pad * 2},
					2.0 / camera.zoom,
					{0, 180, 255, 255},
				)
			}
		}
	}
	rl.EndMode2D()

	// ── Screen-space HUD ──
	if show_exit_prompt {
		draw_exit_prompt()
	} else if text_input_active {
		draw_text_input_box()
	} else {
		draw_hud()
	}
}

draw_grid :: proc() {
	GRID_SIZE :: 100
	GRID_COLOR :: rl.Color{50, 50, 50, 255}

	// Compute visible area
	tl := rl.GetScreenToWorld2D({0, 0}, camera)
	br := rl.GetScreenToWorld2D({f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}, camera)

	start_x := int(math.floor(tl.x / GRID_SIZE)) * GRID_SIZE
	end_x := int(math.ceil(br.x / GRID_SIZE)) * GRID_SIZE
	start_y := int(math.floor(tl.y / GRID_SIZE)) * GRID_SIZE
	end_y := int(math.ceil(br.y / GRID_SIZE)) * GRID_SIZE

	for x := start_x; x <= end_x; x += GRID_SIZE {
		if x == 0 {
			rl.DrawLineEx({0.0, tl.y}, {0.0, br.y}, 3.0 / camera.zoom, GRID_COLOR)
		} else {
			rl.DrawLineV({f32(x), tl.y}, {f32(x), br.y}, GRID_COLOR)
		}
	}
	for y := start_y; y <= end_y; y += GRID_SIZE {
		if y == 0 {
			rl.DrawLineEx({tl.x, 0.0}, {br.x, 0.0}, 3.0 / camera.zoom, GRID_COLOR)
		} else {
			rl.DrawLineV({tl.x, f32(y)}, {br.x, f32(y)}, GRID_COLOR)
		}
	}
}

draw_hud :: proc() {
	y: i32 = 10
	gap: i32 = 20
	color :: rl.Color{200, 200, 200, 180}

	rl.DrawText("Drag & drop images onto the window", 10, y, 16, color); y += gap
	rl.DrawText("LMB: select / move  |  Scroll: scale selected / zoom", 10, y, 16, color); y += gap
	rl.DrawText("MMB: pan  |  T: add text  |  X: delete selected", 10, y, 16, color); y += gap
	rl.DrawText("Ctrl+S: save  |  Ctrl+L: load  |  Ctrl+E: export PNG", 10, y, 16, color); y += gap

	if unsaved_changes {
		rl.DrawText("Unsaved changes", 10, y, 16, rl.RED)
	} else {
		rl.DrawText("All changes saved", 10, y, 16, rl.GREEN)
	}
	y += gap
}

draw_text_input_box :: proc() {
	BOX_W :: 400
	BOX_H :: 40
	sx := f32(rl.GetScreenWidth()) / 2 - BOX_W / 2
	sy := f32(rl.GetScreenHeight()) / 2 - BOX_H / 2

	rl.DrawRectangleRounded({sx, sy, BOX_W, BOX_H}, 0.2, 8, {50, 50, 50, 230})
	rl.DrawRectangleRoundedLinesEx({sx, sy, BOX_W, BOX_H}, 0.2, 8, 2, {0, 180, 255, 255})

	typed := string(text_input_buf[:text_input_len])
	display := strings.clone_to_cstring(typed, context.temp_allocator)

	// Blinking cursor
	cursor_suffix: cstring = (int(rl.GetTime() * 2) % 2 == 0) ? "_" : " "
	full := strings.clone_to_cstring(
		strings.concatenate({typed, string(cursor_suffix)}, context.temp_allocator),
		context.temp_allocator,
	)

	rl.DrawText(full, i32(sx) + 10, i32(sy) + 12, 20, rl.WHITE)

	// Label
	rl.DrawText(
		"Type text, Enter to confirm, Esc to cancel",
		i32(sx),
		i32(sy) - 20,
		14,
		{200, 200, 200, 180},
	)
}

draw_exit_prompt :: proc() {
	BOX_W :: 500
	BOX_H :: 120
	sx := f32(rl.GetScreenWidth()) / 2 - BOX_W / 2
	sy := f32(rl.GetScreenHeight()) / 2 - BOX_H / 2

	rl.DrawRectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight(), {0, 0, 0, 150})

	rl.DrawRectangleRounded({sx, sy, BOX_W, BOX_H}, 0.2, 8, {50, 50, 50, 255})
	rl.DrawRectangleRoundedLinesEx({sx, sy, BOX_W, BOX_H}, 0.2, 8, 2, {255, 100, 100, 255})

	msg: cstring = "You have unsaved changes!"
	rl.DrawText(msg, i32(sx) + 120, i32(sy) + 30, 20, rl.WHITE)

	sub: cstring = "Save and Exit (Y)  |  Exit without saving (N)  |  Cancel (Esc)"
	rl.DrawText(sub, i32(sx) + 35, i32(sy) + 75, 16, {200, 200, 200, 255})
}
