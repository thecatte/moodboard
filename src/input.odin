package main

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

handle_drop :: proc() {
	if !rl.IsFileDropped() do return

	dropped := rl.LoadDroppedFiles()
	defer rl.UnloadDroppedFiles(dropped)

	world_mouse := get_mouse_world()

	for i in 0 ..< dropped.count {
		path := dropped.paths[i]
		tex := rl.LoadTexture(path)

		append(
			&images,
			BoardImage {
				texture = tex,
				pos = world_mouse,
				scale = 1.0,
				path = strings.clone(string(path)),
				failed = tex.id == 0,
			},
		)
		unsaved_changes = true
		if tex.id == 0 {
			fmt.printf("Could not load: %s\n", path)
		}
	}
}

handle_input :: proc() {
	world_mouse := get_mouse_world()
	screen_mouse := rl.GetMousePosition()

	// ── Text input mode ──
	if text_input_active {
		// Gather typed characters
		for {
			ch := rl.GetCharPressed()
			if ch == 0 do break
			if text_input_len < TEXT_INPUT_MAX - 1 {
				text_input_buf[text_input_len] = u8(ch)
				text_input_len += 1
			}
		}
		// Backspace
		if rl.IsKeyPressed(.BACKSPACE) && text_input_len > 0 {
			text_input_len -= 1
		}
		// Confirm with Enter
		if rl.IsKeyPressed(.ENTER) && text_input_len > 0 {
			typed := string(text_input_buf[:text_input_len])
			append(
				&texts,
				BoardText{content = strings.clone(typed), pos = text_input_world, font_size = 24},
			)
			text_input_active = false
			text_input_len = 0
			unsaved_changes = true
		}
		// Cancel with Escape
		if rl.IsKeyPressed(.ESCAPE) {
			text_input_active = false
			text_input_len = 0
		}
		return // Don't process other input while typing
	}

	// ── Panning (middle mouse) ──
	if rl.IsMouseButtonPressed(.MIDDLE) {
		is_panning = true
		pan_start_mouse = screen_mouse
		pan_start_target = camera.target
	}
	if is_panning {
		if rl.IsMouseButtonDown(.MIDDLE) {
			delta := screen_mouse - pan_start_mouse
			camera.target = pan_start_target - delta / camera.zoom
			unsaved_changes = true
		}
		if rl.IsMouseButtonReleased(.MIDDLE) {
			is_panning = false
		}
		return // don't handle other clicks while panning
	}

	// ── Zoom (mouse wheel, only when not dragging) ──
	if rl.IsKeyPressed(.ONE) {
		camera.zoom = 1.0
		unsaved_changes = true
	}
	if rl.IsKeyPressed(.TWO) {
		camera.zoom = 0.5
		unsaved_changes = true
	}
	if rl.IsKeyPressed(.C) {
		camera.target = {0, 0}
		unsaved_changes = true
	}
	wheel := rl.GetMouseWheelMove()
	if wheel != 0 {
		unsaved_changes = true
		if selection.kind == .Image && selection.index >= 0 && selection.index < len(images) {
			// Scale the selected image
			img := &images[selection.index]
			img.scale += wheel * 0.05 * img.scale
			img.scale = max(img.scale, 0.05)
		} else {
			// Zoom camera
			camera.zoom += wheel * 0.1 * camera.zoom
			camera.zoom = clamp(camera.zoom, 0.1, 10.0)
		}
	}

	// ── Delete selected (X key) ──
	if rl.IsKeyPressed(.X) {
		#partial switch selection.kind {
		case .Image:
			if selection.index >= 0 && selection.index < len(images) {
				if images[selection.index].texture.id > 0 {
					rl.UnloadTexture(images[selection.index].texture)
				}
				delete(images[selection.index].path)
				ordered_remove(&images, selection.index)
				selection = {}
				is_dragging = false
				unsaved_changes = true
			}
		case .Text:
			if selection.index >= 0 && selection.index < len(texts) {
				delete(texts[selection.index].content)
				ordered_remove(&texts, selection.index)
				selection = {}
				is_dragging = false
				unsaved_changes = true
			}
		}
	}

	// ── Start text input mode (T key) ──
	if rl.IsKeyPressed(.T) {
		text_input_active = true
		text_input_len = 0
		text_input_world = world_mouse
	}

	// ── Save (Ctrl+S) ──
	if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.S) {
		save_board()
	}

	// ── Load (Ctrl+L) ──
	if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.L) {
		load_board()
	}

	// ── Export (Ctrl+E) ──
	if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.E) {
		export_board()
	}

	// ── Click to select / start drag ──
	if rl.IsMouseButtonPressed(.LEFT) {
		hit := false

		// Check images in reverse (topmost first)
		#reverse for &img, i in images {
			if point_in_rect(world_mouse, image_rect(img)) {
				selection = {
					kind  = .Image,
					index = i,
				}
				is_dragging = true
				drag_offset = world_mouse - img.pos
				hit = true
				break
			}
		}

		// Check texts if no image hit
		if !hit {
			#reverse for &t, i in texts {
				if point_in_rect(world_mouse, text_rect(t)) {
					selection = {
						kind  = .Text,
						index = i,
					}
					is_dragging = true
					drag_offset = world_mouse - t.pos
					hit = true
					break
				}
			}
		}

		if !hit {
			selection = {}
			is_dragging = false
		}
	}

	// ── Drag selected item ──
	if is_dragging && rl.IsMouseButtonDown(.LEFT) {
		#partial switch selection.kind {
		case .Image:
			if selection.index >= 0 && selection.index < len(images) {
				images[selection.index].pos = world_mouse - drag_offset
				unsaved_changes = true
			}
		case .Text:
			if selection.index >= 0 && selection.index < len(texts) {
				texts[selection.index].pos = world_mouse - drag_offset
				unsaved_changes = true
			}
		}
	}

	if rl.IsMouseButtonReleased(.LEFT) {
		is_dragging = false
	}
}
