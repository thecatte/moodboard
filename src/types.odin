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

SelectionKind :: enum {
	None,
	Image,
	Text,
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
camera: rl.Camera2D
selection: Selection
is_dragging: bool
drag_offset: rl.Vector2

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
