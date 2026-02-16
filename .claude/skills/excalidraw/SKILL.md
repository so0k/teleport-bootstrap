---
name: excalidraw
description: Generate Excalidraw diagrams as .excalidraw JSON files. Use when the user asks to create, update, or modify architecture diagrams, flowcharts, or any visual diagrams. Outputs .excalidraw files that can be converted to PNG with excalirender.
---

# Excalidraw Diagram Generator

Generate `.excalidraw` JSON files for architecture diagrams, flowcharts, and visual documentation.
Convert to PNG locally with `excalirender` — no cloud services needed.

## Workflow

1. Write the `.excalidraw` JSON file to the target path
2. Convert to PNG: `excalirender <file>.excalidraw -o <file>.png -s 2`
3. Reference the PNG in markdown: `![description](<file>.png)`

The `.excalidraw` source files stay in the repo for future editing (open at excalidraw.com or edit JSON directly).

## File Format

```json
{
  "type": "excalidraw",
  "version": 2,
  "source": "https://excalidraw.com",
  "elements": [ ... ],
  "appState": { "viewBackgroundColor": "#ffffff", "gridSize": null },
  "files": {}
}
```

## Element Reference

> Full reference with all examples and edge cases: see `MCP_REFERENCE.md` in this skill directory.
> Below is the practical subset for generating static `.excalidraw` files.

### Required Fields (all elements)
`type`, `id` (unique string), `x`, `y`, `width`, `height`

### Defaults (skip unless overriding)
strokeColor="#1e1e1e", backgroundColor="transparent", fillStyle="solid", strokeWidth=2, roughness=1, opacity=100

### Rectangle
```json
{ "type": "rectangle", "id": "r1", "x": 100, "y": 100, "width": 200, "height": 100,
  "roundness": { "type": 3 }, "backgroundColor": "#a5d8ff", "fillStyle": "solid", "strokeColor": "#4a9eed" }
```

### Ellipse
```json
{ "type": "ellipse", "id": "e1", "x": 100, "y": 100, "width": 150, "height": 150 }
```

### Diamond
```json
{ "type": "diamond", "id": "d1", "x": 100, "y": 100, "width": 150, "height": 150 }
```

### Standalone Text (titles, annotations)
```json
{ "type": "text", "id": "t1", "x": 150, "y": 138, "width": 100, "height": 25,
  "text": "Hello", "fontSize": 20, "fontFamily": 1, "textAlign": "left", "verticalAlign": "top" }
```
- `x` is the LEFT edge. To center at position cx: `x = cx - (text.length * fontSize * 0.5) / 2`
- Do NOT rely on textAlign or width for positioning — they only affect multi-line wrapping

### Text Inside a Shape (containerId pattern)
Standard Excalidraw format — use a separate text element with `containerId`:
```json
{ "type": "rectangle", "id": "box1", "x": 100, "y": 100, "width": 200, "height": 80,
  "backgroundColor": "#a5d8ff", "fillStyle": "solid", "roundness": { "type": 3 }, "strokeColor": "#4a9eed" },
{ "type": "text", "id": "box1_l", "x": 120, "y": 125, "width": 160, "height": 25,
  "text": "Label", "fontSize": 18, "containerId": "box1",
  "fontFamily": 1, "textAlign": "center", "verticalAlign": "middle" }
```

> **Note:** The MCP_REFERENCE.md shows a `"label": { "text": "..." }` shorthand on shapes/arrows.
> That is an MCP-only convenience — it does NOT work in standard `.excalidraw` files.
> Always use the `containerId` pattern above for files that excalirender or excalidraw.com will render.

### Arrow
```json
{ "type": "arrow", "id": "a1", "x": 300, "y": 150, "width": 200, "height": 0,
  "points": [[0,0],[200,0]], "endArrowhead": "arrow", "strokeWidth": 2 }
```
- `points`: array of [dx, dy] offsets from element x,y
- `endArrowhead`: null | "arrow" | "bar" | "dot" | "triangle"
- `strokeStyle`: "solid" (default) | "dashed" | "dotted"

### Arrow Bindings (connect to shapes)
Two binding formats exist. Use `fixedPoint` for explicit anchor control:
```json
"startBinding": { "elementId": "box1", "fixedPoint": [1, 0.5] },
"endBinding": { "elementId": "box2", "fixedPoint": [0, 0.5] }
```
fixedPoint coordinates: top=[0.5,0], bottom=[0.5,1], left=[0,0.5], right=[1,0.5]

Or use the `focus`/`gap` format for auto-routing:
```json
"startBinding": { "elementId": "box1", "focus": 0, "gap": 1 },
"endBinding": { "elementId": "box2", "focus": 0, "gap": 1 }
```

### Arrow with Label
Use a text element with `containerId` pointing to the arrow:
```json
{ "type": "arrow", "id": "a1", "x": 300, "y": 150, "width": 200, "height": 0,
  "points": [[0,0],[200,0]], "endArrowhead": "arrow", "strokeWidth": 2 },
{ "type": "text", "id": "a1_l", "x": 350, "y": 130, "width": 100, "height": 25,
  "text": "connects", "fontSize": 16, "containerId": "a1",
  "fontFamily": 1, "textAlign": "center", "verticalAlign": "middle" }
```

### Multi-segment Arrow (L-shape, Z-shape)
```json
{ "type": "arrow", "id": "a1", "x": 300, "y": 150, "width": -100, "height": 200,
  "points": [[0,0],[0,150],[-100,200]], "endArrowhead": "arrow" }
```
x,y is the first point. Each point in `points` is an offset from x,y. width/height should match the last point's offset.

## Color Palette

### Primary Colors (strokes, accents)
| Name | Hex | Use |
|------|-----|-----|
| Blue | `#4a9eed` | Primary actions, links |
| Amber | `#f59e0b` | Warnings, highlights |
| Green | `#22c55e` | Success, positive |
| Red | `#ef4444` | Errors, negative |
| Purple | `#8b5cf6` | Accents, special |
| Pink | `#ec4899` | Decorative |
| Cyan | `#06b6d4` | Info, secondary |
| Lime | `#84cc16` | Extra |

### Shape Fills (pastel, for backgrounds)
| Color | Hex | Use |
|-------|-----|-----|
| Light Blue | `#a5d8ff` | Input, sources, primary nodes |
| Light Green | `#b2f2bb` | Success, output, completed |
| Light Orange | `#ffd8a8` | Warning, pending, external |
| Light Purple | `#d0bfff` | Processing, middleware, special |
| Light Red | `#ffc9c9` | Error, critical, alerts |
| Light Yellow | `#fff3bf` | Notes, decisions, planning |
| Light Teal | `#c3fae8` | Storage, data, memory |
| Light Pink | `#eebefa` | Analytics, metrics |

### Background Zones (use with opacity: 30-35)
| Color | Hex | Use |
|-------|-----|-----|
| Blue zone | `#dbe4ff` | UI / frontend / terraform layer |
| Purple zone | `#e5dbff` | Logic / agent layer |
| Green zone | `#d3f9d8` | Data / runtime layer |

### Dark Mode
Use a large dark background rectangle as the first element:
```json
{ "type": "rectangle", "id": "darkbg", "x": -500, "y": -500, "width": 3000, "height": 2000,
  "backgroundColor": "#1e1e2e", "fillStyle": "solid", "strokeColor": "transparent", "strokeWidth": 0 }
```

Dark mode fills: Dark Blue `#1e3a5f`, Dark Green `#1a4d2e`, Dark Purple `#2d1b69`, Dark Orange `#5c3d1a`, Dark Red `#5c1a1a`, Dark Teal `#1a4d4d`

Dark mode text: White `#e5e5e5` (primary), Muted `#a0a0a0` (secondary). NEVER use `#555` or darker on dark bg.

## Layout & Sizing Guidelines

### Font Sizes
- **28** — diagram title
- **20** — section headers, prominent labels
- **18** — box labels, shape text
- **16** — annotations, arrow labels, secondary text
- **14** — minimum readable size, use sparingly

### Element Sizing
- Minimum shape size: **120x60** for labeled rectangles
- Leave **30-50px** gaps between elements for arrows + labels
- Prefer fewer, larger elements over many tiny ones

### Z-Order
Element array order = z-order (first = back, last = front).
Draw in this order: background zones → shapes → their contained text → arrows → arrow labels

### Text Contrast
- Never use light gray (#b0b0b0, #999) on white backgrounds
- Minimum text strokeColor on white: `#757575`
- For colored text on light fills, use dark variants: `#15803d` not `#22c55e`, `#2563eb` not `#4a9eed`
- Do NOT use emoji in text — they don't render in Excalidraw's font

### Common Mistakes
- Arrow labels need space — keep labels short or make arrows wider
- Elements overlap when y-coordinates are close — check that text/boxes/labels don't stack
- Pair each shape fill with a matching darker stroke color

## Complete Example

```json
{
  "type": "excalidraw",
  "version": 2,
  "source": "https://excalidraw.com",
  "elements": [
    { "type": "rectangle", "id": "b1", "x": 100, "y": 100, "width": 200, "height": 80,
      "roundness": { "type": 3 }, "backgroundColor": "#a5d8ff", "fillStyle": "solid", "strokeColor": "#4a9eed" },
    { "type": "text", "id": "b1_l", "x": 140, "y": 125, "width": 120, "height": 25,
      "text": "Start", "fontSize": 20, "containerId": "b1",
      "fontFamily": 1, "textAlign": "center", "verticalAlign": "middle" },
    { "type": "rectangle", "id": "b2", "x": 450, "y": 100, "width": 200, "height": 80,
      "roundness": { "type": 3 }, "backgroundColor": "#b2f2bb", "fillStyle": "solid", "strokeColor": "#22c55e" },
    { "type": "text", "id": "b2_l", "x": 490, "y": 125, "width": 120, "height": 25,
      "text": "End", "fontSize": 20, "containerId": "b2",
      "fontFamily": 1, "textAlign": "center", "verticalAlign": "middle" },
    { "type": "arrow", "id": "a1", "x": 300, "y": 140, "width": 150, "height": 0,
      "points": [[0,0],[150,0]], "endArrowhead": "arrow", "strokeWidth": 2,
      "startBinding": { "elementId": "b1", "fixedPoint": [1, 0.5] },
      "endBinding": { "elementId": "b2", "fixedPoint": [0, 0.5] } },
    { "type": "text", "id": "a1_l", "x": 340, "y": 120, "width": 70, "height": 25,
      "text": "connects", "fontSize": 16, "containerId": "a1",
      "fontFamily": 1, "textAlign": "center", "verticalAlign": "middle" }
  ],
  "appState": { "viewBackgroundColor": "#ffffff", "gridSize": null },
  "files": {}
}
```

## MCP-Only Features (NOT for static files)

The `MCP_REFERENCE.md` in this directory documents features that only work with the Excalidraw MCP Desktop app. Do NOT include these in `.excalidraw` files:

- **`cameraUpdate`** — viewport animation pseudo-element (MCP streaming only)
- **`delete`** — element removal pseudo-element (MCP streaming only)
- **`restoreCheckpoint`** — session state restore (MCP only)
- **`label` shorthand** on shapes/arrows — MCP convenience, use `containerId` pattern instead
- **Animation mode** — streaming transform effects (MCP only)
