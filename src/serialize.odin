package main

import "core:fmt"
import "core:math"
import "core:os"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

save_board :: proc() {
	b := strings.builder_make(context.temp_allocator)

	// Camera
	fmt.sbprintf(&b, "camera %f %f %f\n", camera.target.x, camera.target.y, camera.zoom)

	// Images
	for &img in images {
		fmt.sbprintf(&b, "image %f %f %f %s\n", img.pos.x, img.pos.y, img.scale, img.path)
	}

	// Texts
	for &t in texts {
		// Encode newlines as \n in save file
		safe, _ := strings.replace_all(t.content, "\n", "\\n", context.temp_allocator)
		fmt.sbprintf(&b, "text %f %f %f %s\n", t.pos.x, t.pos.y, t.font_size, safe)
	}

	// Models
	for &m in models {
		fmt.sbprintf(
			&b,
			"model %f %f %f %f %f %f %f %s\n",
			m.pos.x,
			m.pos.y,
			m.scale,
			m.rotation.x,
			m.rotation.y,
			m.rotation.z,
			m.cam.fovy,
			m.path,
		)
	}

	data := strings.to_string(b)
	ok := os.write_entire_file(save_file_path, transmute([]u8)data)
	if ok {
		fmt.println("Board saved.")
		unsaved_changes = false
	} else {
		fmt.println("Failed to save board.")
	}
}

load_board :: proc() {
	data, ok := os.read_entire_file(save_file_path, context.temp_allocator)
	if !ok {
		fmt.println("No save file found.")
		return
	}

	// Clear existing state
	for &img in images {
		if img.texture.id > 0 {
			rl.UnloadTexture(img.texture)
		}
		delete(img.path)
	}
	clear(&images)

	for &m in models {
		if m.model.meshCount > 0 do rl.UnloadModel(m.model)
		if m.render_target.id > 0 do rl.UnloadRenderTexture(m.render_target)
		delete(m.path)
	}
	clear(&models)

	for &t in texts {
		delete(t.content)
	}
	clear(&texts)

	selection = {}

	content := string(data)
	for line in strings.split_lines_iterator(&content) {
		line := strings.trim_space(line)
		if len(line) == 0 do continue

		fields := strings.fields(line, context.temp_allocator)
		if len(fields) < 2 do continue

		kind := fields[0]

		if kind == "camera" && len(fields) >= 4 {
			cx, _ := strconv.parse_f64(fields[1])
			cy, _ := strconv.parse_f64(fields[2])
			cz, _ := strconv.parse_f64(fields[3])
			camera.target = {f32(cx), f32(cy)}
			camera.zoom = f32(cz)
			if camera.zoom <= 0 do camera.zoom = 1
		} else if kind == "image" && len(fields) >= 5 {
			px, _ := strconv.parse_f64(fields[1])
			py, _ := strconv.parse_f64(fields[2])
			sc, _ := strconv.parse_f64(fields[3])
			// Path is everything from fields[4] onwards
			path := strings.join(fields[4:], " ", context.temp_allocator)

			cpath := strings.clone_to_cstring(path, context.temp_allocator)
			tex := rl.LoadTexture(cpath)

			append(
				&images,
				BoardImage {
					texture = tex,
					pos = {f32(px), f32(py)},
					scale = tex.id == 0 ? 1.0 : f32(sc),
					path = strings.clone(path),
					failed = tex.id == 0,
				},
			)
			if tex.id == 0 {
				fmt.printf("Failed to load image: %s\n", path)
			}
		} else if kind == "text" && len(fields) >= 5 {
			px, _ := strconv.parse_f64(fields[1])
			py, _ := strconv.parse_f64(fields[2])
			fs, _ := strconv.parse_f64(fields[3])
			// Content is everything from fields[4] onwards
			raw_text := strings.join(fields[4:], " ", context.temp_allocator)
			decoded, _ := strings.replace_all(raw_text, "\\n", "\n", context.temp_allocator)

			append(
				&texts,
				BoardText {
					content = strings.clone(decoded),
					pos = {f32(px), f32(py)},
					font_size = f32(fs),
				},
			)
		} else if kind == "model" && len(fields) >= 8 {
			px, _ := strconv.parse_f64(fields[1])
			py, _ := strconv.parse_f64(fields[2])
			sc, _ := strconv.parse_f64(fields[3])
			rx, _ := strconv.parse_f64(fields[4])
			ry, _ := strconv.parse_f64(fields[5])
			rz, _ := strconv.parse_f64(fields[6])

			fovy: f64 = 45.0
			path_idx: int = 7

			// If we have 9 fields, fields[7] might be fovy
			// New format: model px py sc rx ry rz fovy path (9 fields if path has no space)
			// Old format: model px py sc rx ry rz path (8 fields if path has no space)
			// Let's check if the 8th field (fields[7]) is a number or looks like a path
			f, f_ok := strconv.parse_f64(fields[7])
			if f_ok && len(fields) >= 9 {
				fovy = f
				path_idx = 8
			}

			path := strings.join(fields[path_idx:], " ", context.temp_allocator)

			cpath := strings.clone_to_cstring(path, context.temp_allocator)
			mdl := rl.LoadModel(cpath)

			bbox := rl.GetModelBoundingBox(mdl)
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
			cam.fovy = f32(fovy)
			cam.projection = .PERSPECTIVE

			append(
				&models,
				BoardModel {
					model = mdl,
					pos = {f32(px), f32(py)},
					scale = f32(sc),
					rotation = {f32(rx), f32(ry), f32(rz)},
					path = strings.clone(path),
					failed = mdl.meshCount == 0,
					render_target = target,
					cam = cam,
				},
			)

			if mdl.meshCount == 0 {
				fmt.printf("Failed to load model: %s\n", path)
			}
		}
	}

	fmt.println("Board loaded.")
	unsaved_changes = false
}

export_board :: proc() {
	if len(images) == 0 && len(texts) == 0 {
		fmt.println("Nothing to export.")
		return
	}

	min_x: f32 = 1e9
	min_y: f32 = 1e9
	max_x: f32 = -1e9
	max_y: f32 = -1e9

	for img in images {
		if img.failed do continue
		r := image_rect(img)
		min_x = min(min_x, r.x)
		min_y = min(min_y, r.y)
		max_x = max(max_x, r.x + r.width)
		max_y = max(max_y, r.y + r.height)
	}

	for m in models {
		if m.failed do continue
		r := model_rect(m)
		min_x = min(min_x, r.x)
		min_y = min(min_y, r.y)
		max_x = max(max_x, r.x + r.width)
		max_y = max(max_y, r.y + r.height)
	}

	for t in texts {
		r := text_rect(t)
		min_x = min(min_x, r.x)
		min_y = min(min_y, r.y)
		max_x = max(max_x, r.x + r.width)
		max_y = max(max_y, r.y + r.height)
	}

	padding: f32 = 50.0
	min_x -= padding
	min_y -= padding
	max_x += padding
	max_y += padding

	width := i32(math.ceil(max_x - min_x))
	height := i32(math.ceil(max_y - min_y))

	if width <= 0 || height <= 0 do return

	if width > 16384 do width = 16384
	if height > 16384 do height = 16384

	target := rl.LoadRenderTexture(width, height)
	if target.id == 0 {
		fmt.println("Failed to create render texture for export.")
		return
	}
	defer rl.UnloadRenderTexture(target)

	export_cam: rl.Camera2D
	export_cam.target = {min_x, min_y}
	export_cam.offset = {0, 0}
	export_cam.zoom = 1.0
	export_cam.rotation = 0.0

	rl.BeginTextureMode(target)
	rl.ClearBackground({30, 30, 30, 255})
	rl.BeginMode2D(export_cam)

	for img in images {
		if !img.failed {
			rl.DrawTextureEx(img.texture, img.pos, 0, img.scale, rl.WHITE)
		}
	}
	for m in models {
		if !m.failed {
			r := model_rect(m)
			source := rl.Rectangle {
				0,
				0,
				f32(m.render_target.texture.width),
				-f32(m.render_target.texture.height),
			}
			dest := r
			origin := rl.Vector2{0, 0}
			rl.DrawTexturePro(m.render_target.texture, source, dest, origin, 0.0, rl.WHITE)
		}
	}
	for t in texts {
		cstr := strings.clone_to_cstring(t.content, context.temp_allocator)
		rl.DrawTextEx(rl.GetFontDefault(), cstr, t.pos, t.font_size, 1, rl.WHITE)
	}

	rl.EndMode2D()
	rl.EndTextureMode()

	img_data := rl.LoadImageFromTexture(target.texture)
	defer rl.UnloadImage(img_data)

	rl.ImageFlipVertical(&img_data)

	export_path := save_file_path
	if strings.has_suffix(save_file_path, ".moodboard") {
		export_path = strings.concatenate(
			{save_file_path[:len(save_file_path) - 10], ".png"},
			context.temp_allocator,
		)
	} else {
		export_path = strings.concatenate({save_file_path, ".png"}, context.temp_allocator)
	}

	cpath := strings.clone_to_cstring(export_path, context.temp_allocator)
	if rl.ExportImage(img_data, cpath) {
		fmt.printfln("Exported board to %s", export_path)
	} else {
		fmt.printfln("Failed to export board to %s", export_path)
	}
}
