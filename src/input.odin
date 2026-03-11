package main

import "core:fmt"
import "core:math"
import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"

handle_drop :: proc() {
	if !rl.IsFileDropped() do return

	dropped := rl.LoadDroppedFiles()
	defer rl.UnloadDroppedFiles(dropped)

	world_mouse := get_mouse_world()

	for i in 0 ..< dropped.count {
		path := dropped.paths[i]
		ext := strings.to_lower(filepath.ext(string(path)), context.temp_allocator)

		if ext == ".obj" || ext == ".gltf" || ext == ".glb" {
			model := rl.LoadModel(path)

			bbox := rl.GetModelBoundingBox(model)
			center := rl.Vector3 {
				(bbox.max.x + bbox.min.x) / 2.0,
				(bbox.max.y + bbox.min.y) / 2.0,
				(bbox.max.z + bbox.min.z) / 2.0,
			}

			target := rl.LoadRenderTexture(500, 500)

			cam: rl.Camera3D
			cam.position = {center.x + 0.0, center.y + 10.0, center.z + 10.0}
			cam.target = center
			cam.up = {0, 1, 0}
			cam.fovy = 45.0
			cam.projection = .PERSPECTIVE

			append(
				&models,
				BoardModel {
					model = model,
					pos = world_mouse,
					scale = 1.0,
					rotation = {0, 0, 0},
					path = strings.clone(string(path)),
					failed = model.meshCount == 0,
					render_target = target,
					cam = cam,
				},
			)
			unsaved_changes = true
			if model.meshCount == 0 {
				fmt.printf("Could not load model: %s\n", path)
			}
		} else {
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
				fmt.printf("Could not load image: %s\n", path)
			}
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
				BoardText{content = strings.clone(typed), pos = text_input_world, font_size = 32},
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
		// Shift+Scroll on a selected 3D model: zoom its internal camera
		if (rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)) &&
		   selection.kind == .Model &&
		   selection.index >= 0 &&
		   selection.index < len(models) {
			m := &models[selection.index]
			m.cam.fovy -= wheel * 3.0
			m.cam.fovy = clamp(m.cam.fovy, 5.0, 120.0)
			unsaved_changes = true
		} else {
			// Default: zoom canvas
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
		case .Model:
			if selection.index >= 0 && selection.index < len(models) {
				m := models[selection.index]
				if m.model.meshCount > 0 {
					rl.UnloadModel(m.model)
				}
				if m.render_target.id > 0 {
					rl.UnloadRenderTexture(m.render_target)
				}
				delete(m.path)
				ordered_remove(&models, selection.index)
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

	// ── Click to select / start drag / start resize ──
	if rl.IsMouseButtonPressed(.LEFT) {
		hit := false

		now := rl.GetTime()
		is_double := (now - last_click_time) < 0.3
		last_click_time = now

		// First: check if the mouse is on the resize handle of the CURRENT selection
		#partial switch selection.kind {
		case .Image:
			if selection.index >= 0 && selection.index < len(images) {
				img := images[selection.index]
				r := image_rect(img)
				pad: f32 = img.failed ? 4.0 : 0.0
				hr := resize_handle_rect(
					{r.x - pad, r.y - pad, r.width + pad * 2, r.height + pad * 2},
				)
				if point_in_rect(world_mouse, hr) {
					if is_double {
						images[selection.index].scale = 1.0
						unsaved_changes = true
						hit = true
					} else {
						anchor := img.pos
						dist := math.sqrt(
							math.pow(world_mouse.x - anchor.x, 2) +
							math.pow(world_mouse.y - anchor.y, 2),
						)
						if dist > 0.001 {
							is_resizing = true
							resize_start_mouse_dist = dist
							resize_start_scale = img.scale
							hit = true
						}
					}
				}
			}
		case .Model:
			if selection.index >= 0 && selection.index < len(models) {
				m := models[selection.index]
				r := model_rect(m)
				pad: f32 = m.failed ? 4.0 : 0.0
				hr := resize_handle_rect(
					{r.x - pad, r.y - pad, r.width + pad * 2, r.height + pad * 2},
				)
				if point_in_rect(world_mouse, hr) {
					if is_double {
						models[selection.index].scale = 1.0
						unsaved_changes = true
						hit = true
					} else {
						anchor := m.pos
						dist := math.sqrt(
							math.pow(world_mouse.x - anchor.x, 2) +
							math.pow(world_mouse.y - anchor.y, 2),
						)
						if dist > 0.001 {
							is_resizing = true
							resize_start_mouse_dist = dist
							resize_start_scale = m.scale
							hit = true
						}
					}
				}
			}
		case .Text:
			if selection.index >= 0 && selection.index < len(texts) {
				t := texts[selection.index]
				r := text_rect(t)
				pad: f32 = 4.0
				hr := resize_handle_rect(
					{r.x - pad, r.y - pad, r.width + pad * 2, r.height + pad * 2},
				)
				if point_in_rect(world_mouse, hr) {
					if is_double {
						texts[selection.index].font_size = 32.0
						unsaved_changes = true
						hit = true
					} else {
						anchor := t.pos
						dist := math.sqrt(
							math.pow(world_mouse.x - anchor.x, 2) +
							math.pow(world_mouse.y - anchor.y, 2),
						)
						if dist > 0.001 {
							is_resizing = true
							resize_start_mouse_dist = dist
							resize_start_scale = t.font_size
							hit = true
						}
					}
				}
			}
		}

		if !hit {
			// Check models first (topmost)
			#reverse for &m, i in models {
				if point_in_rect(world_mouse, model_rect(m)) {
					selection = {
						kind  = .Model,
						index = i,
					}
					is_dragging = true
					drag_offset = world_mouse - m.pos
					hit = true
					break
				}
			}
		}

		if !hit {
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

	// ── Resize selected item via handle ──
	if is_resizing && rl.IsMouseButtonDown(.LEFT) {
		#partial switch selection.kind {
		case .Image:
			if selection.index >= 0 && selection.index < len(images) {
				anchor := images[selection.index].pos
				dist := math.sqrt(
					math.pow(world_mouse.x - anchor.x, 2) + math.pow(world_mouse.y - anchor.y, 2),
				)
				if resize_start_mouse_dist > 0.001 {
					new_scale := resize_start_scale * (dist / resize_start_mouse_dist)
					images[selection.index].scale = max(new_scale, 0.05)
					unsaved_changes = true
				}
			}
		case .Model:
			if selection.index >= 0 && selection.index < len(models) {
				anchor := models[selection.index].pos
				dist := math.sqrt(
					math.pow(world_mouse.x - anchor.x, 2) + math.pow(world_mouse.y - anchor.y, 2),
				)
				if resize_start_mouse_dist > 0.001 {
					new_scale := resize_start_scale * (dist / resize_start_mouse_dist)
					models[selection.index].scale = max(new_scale, 0.05)
					unsaved_changes = true
				}
			}
		case .Text:
			if selection.index >= 0 && selection.index < len(texts) {
				anchor := texts[selection.index].pos
				dist := math.sqrt(
					math.pow(world_mouse.x - anchor.x, 2) + math.pow(world_mouse.y - anchor.y, 2),
				)
				if resize_start_mouse_dist > 0.001 {
					new_size := resize_start_scale * (dist / resize_start_mouse_dist)
					texts[selection.index].font_size = max(new_size, 6.0)
					unsaved_changes = true
				}
			}
		}
	}

	// ── Drag selected item ──
	if is_dragging && !is_resizing && rl.IsMouseButtonDown(.LEFT) {
		#partial switch selection.kind {
		case .Image:
			if selection.index >= 0 && selection.index < len(images) {
				images[selection.index].pos = world_mouse - drag_offset
				unsaved_changes = true
			}
		case .Model:
			if selection.index >= 0 && selection.index < len(models) {
				models[selection.index].pos = world_mouse - drag_offset
				unsaved_changes = true
			}
		case .Text:
			if selection.index >= 0 && selection.index < len(texts) {
				texts[selection.index].pos = world_mouse - drag_offset
				unsaved_changes = true
			}
		}
	}

	// ── Rotate selected model ──
	if selection.kind == .Model && selection.index >= 0 && selection.index < len(models) {
		if rl.IsMouseButtonDown(.RIGHT) {
			delta := rl.GetMouseDelta()
			models[selection.index].rotation.x += delta.y * 0.01
			models[selection.index].rotation.y += delta.x * 0.01
			unsaved_changes = true
		}
	}

	if rl.IsMouseButtonReleased(.LEFT) {
		is_dragging = false
		is_resizing = false
	}
}
