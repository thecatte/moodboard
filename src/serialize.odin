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

	for &t in texts {
		delete(t.content)
	}
	clear(&texts)

	selection = {}

	content := string(data)
	for line in strings.split_lines_iterator(&content) {
		if len(line) == 0 do continue

		if strings.has_prefix(line, "camera ") {
			rest := line[7:]
			parts := strings.split(rest, " ", context.temp_allocator)
			if len(parts) >= 3 {
				cx, _ := strconv.parse_f64(parts[0])
				cy, _ := strconv.parse_f64(parts[1])
				cz, _ := strconv.parse_f64(parts[2])
				camera.target = {f32(cx), f32(cy)}
				camera.zoom = f32(cz)
				if camera.zoom <= 0 do camera.zoom = 1
			}
		} else if strings.has_prefix(line, "image ") {
			rest := line[6:]
			space1 := strings.index(rest, " ")
			if space1 < 0 do continue
			space2 := strings.index(rest[space1 + 1:], " ")
			if space2 < 0 do continue
			space2 += space1 + 1
			space3 := strings.index(rest[space2 + 1:], " ")
			if space3 < 0 do continue
			space3 += space2 + 1

			px, _ := strconv.parse_f64(rest[:space1])
			py, _ := strconv.parse_f64(rest[space1 + 1:space2])
			sc, _ := strconv.parse_f64(rest[space2 + 1:space3])
			path := rest[space3 + 1:]

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
		} else if strings.has_prefix(line, "text ") {
			rest := line[5:]
			space1 := strings.index(rest, " ")
			if space1 < 0 do continue
			space2 := strings.index(rest[space1 + 1:], " ")
			if space2 < 0 do continue
			space2 += space1 + 1
			space3 := strings.index(rest[space2 + 1:], " ")
			if space3 < 0 do continue
			space3 += space2 + 1

			px, _ := strconv.parse_f64(rest[:space1])
			py, _ := strconv.parse_f64(rest[space1 + 1:space2])
			fs, _ := strconv.parse_f64(rest[space2 + 1:space3])
			raw_text := rest[space3 + 1:]

			decoded, _ := strings.replace_all(raw_text, "\\n", "\n", context.temp_allocator)

			append(
				&texts,
				BoardText {
					content = strings.clone(decoded),
					pos = {f32(px), f32(py)},
					font_size = f32(fs),
				},
			)
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
