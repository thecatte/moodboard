# Moodboard

A fast, lightweight, and interactive digital moodboard application written in [Odin](https://odin-lang.org/) and powered by [Raylib](https://www.raylib.com/).

Moodboard allows you to quickly lay out images and text on an infinite 2D canvas. Whether you're brainstorming a design, planning a level, or just throwing ideas together, it's designed to stay out of your way and let you work efficiently.

## Features

- **Infinite Canvas**: Pan and zoom around a free-form workspace.
- **Drag & Drop support**: Easily drag images from your file manager directly into the application window.
- **Rich Media**: Supports loading and scaling different image formats (.png, .jpg) via Raylib.
- **Text Annotation**: Click to type text notes anywhere on the board.
- **JSON-like Save System**: Boards are saved to a plain text `.moodboard` format, making them easy to track, backup, or share.
- **Auto-Export to PNG**: Render your entire board to a high-quality `.png` image with a single keystroke.
- **Lightweight**: Written in systems-level Odin, it consumes minimal resources and launches instantly.

![screenshot](screenshots/screenshot1.png "Moodboard Screenshot")


## Controls

| Action | Input |
| --- | --- |
| **Select / Move item** | `Left Mouse Button` (Hold & Drag) |
| **Pan camera** | `Middle Mouse Button` (Hold & Drag) |
| **Scale Selection** | `Mouse Wheel` (while an image is selected) |
| **Zoom in / out** | `Mouse Wheel` |
| **Reset Zoom (1x)** | `1` |
| **Set Zoom (0.5x)** | `2` |
| **Center Camera** | `C` |
| **Add Text** | `T` (Starts typing mode, press `Enter` to place, `Esc` to cancel) |
| **Delete Selected** | `X` |
| **Save Board** | `Ctrl + S` |
| **Reload Board** | `Ctrl + L` |
| **Export to PNG** | `Ctrl + E` |

## Getting Started

### Prerequisites

To build and run from source, you will need:
- The [Odin Compiler](https://odin-lang.org/) installed.
- Dependecies required by `vendor:raylib` (usually just basic OpenGL/X11 development libraries on Linux).

### Building

You can quickly compile the application using the Odin CLI:

```bash
odin build src -out:moodboard
```

### Running

To launch a new, fresh moodboard:

```bash
./moodboard
```

*Note: By default, this creates a new save file uniquely named based on the current timestamp (e.g., `YYYY-MM-DD-HH-MM-SS-mb.moodboard`).*

To load an existing board file, simply pass the path as an argument:

```bash
./moodboard ./saves/my_board.moodboard
```

## Known Limitations

- **This is slopware, use at your own risk.**
- Multi-line text inputs are not currently supported in the typing interface natively.
- Image paths in `.moodboard` files are saved as absolute paths from where they were dragged. Moving the image files externally may cause them to display as "failed to load".

## License

This project is open-source. Feel free to use, modify, and distribute!
