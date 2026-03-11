package main

import rl "vendor:raylib"

BoardImage :: struct {
	texture: rl.Texture2D,
	pos:     rl.Vector2,
	scale:   f32,
	path:    string,
	failed:  bool,
}

BoardText :: struct {
	content:   string,
	pos:       rl.Vector2,
	font_size: f32,
}

BoardModel :: struct {
	model:         rl.Model,
	pos:           rl.Vector2,
	scale:         f32,
	rotation:      rl.Vector3,
	path:          string,
	failed:        bool,
	render_target: rl.RenderTexture2D,
	cam:           rl.Camera3D,
}

SelectionKind :: enum {
	None,
	Image,
	Text,
	Model,
}

Selection :: struct {
	kind:  SelectionKind,
	index: int,
}

save_file_path: string = "mb.moodboard"
TEXT_INPUT_MAX :: 256
unsaved_changes: bool = false

images: [dynamic]BoardImage
texts: [dynamic]BoardText
models: [dynamic]BoardModel
camera: rl.Camera2D
selection: Selection
is_dragging: bool
drag_offset: rl.Vector2

// Resize handle state
is_resizing: bool
resize_start_mouse_dist: f32 // distance from anchor at the moment resize started
resize_start_scale: f32 // scale at the moment resize started
last_click_time: f64 // time of last LMB click for double-click detection

// Text input mode
text_input_active: bool
text_input_buf: [TEXT_INPUT_MAX]u8
text_input_len: int
text_input_world: rl.Vector2 // world position where text will be placed

// Panning state
is_panning: bool
pan_start_mouse: rl.Vector2
pan_start_target: rl.Vector2

// Exit prompt
show_exit_prompt: bool = false
