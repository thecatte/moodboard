package main

import "core:fmt"
import "core:os"
import "core:time"
import rl "vendor:raylib"

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(1280, 720, "Moodboard")
	rl.SetExitKey(.KEY_NULL)
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	// Init camera
	camera = rl.Camera2D {
		offset   = {f32(rl.GetScreenWidth()) / 2, f32(rl.GetScreenHeight()) / 2},
		target   = {0, 0},
		rotation = 0,
		zoom     = 1.0,
	}

	images = make([dynamic]BoardImage)
	texts = make([dynamic]BoardText)
	models = make([dynamic]BoardModel)

	if len(os.args) > 1 {
		save_file_path = os.args[1]
		fmt.printfln("Loading board from %s\n", save_file_path)
		load_board()
	} else {
		// save file should be constructed of date, time and -mb.moodboard
		now := time.now()
		year, month, day := time.date(now)
		hour, minute, second := time.clock_from_time(now)
		save_file_path = fmt.aprintf(
			"%d-%02d-%02d-%02d-%02d-%02d-mb.moodboard",
			year,
			int(month),
			day,
			hour,
			minute,
			second,
		)
	}

	update_window_title()

	for {
		if rl.WindowShouldClose() {
			if unsaved_changes {
				show_exit_prompt = true
			} else {
				break
			}
		}

		// Keep camera offset centered when window resizes
		camera.offset = {f32(rl.GetScreenWidth()) / 2, f32(rl.GetScreenHeight()) / 2}

		if show_exit_prompt {
			if rl.IsKeyPressed(.Y) || rl.IsKeyPressed(.ENTER) {
				save_board()
				break
			}
			if rl.IsKeyPressed(.N) {
				break
			}
			if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.C) {
				show_exit_prompt = false
			}
		} else {
			handle_drop()
			handle_input()
		}

		draw()

		free_all(context.temp_allocator)
	}

	// Cleanup
	for &img in images {
		if img.texture.id > 0 {
			rl.UnloadTexture(img.texture)
		}
		delete(img.path)
	}
	delete(images)

	for &m in models {
		if m.model.meshCount > 0 do rl.UnloadModel(m.model)
		if m.render_target.id > 0 do rl.UnloadRenderTexture(m.render_target)
		delete(m.path)
	}
	delete(models)

	for &t in texts {
		delete(t.content)
	}
	delete(texts)
}
