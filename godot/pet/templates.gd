class_name PetTemplates
extends RefCounted

# Source: src/pet/templates.ts
# Source: shared/types.ts DEFAULT_COLORS / SPECIES_LABELS

static var SPECIES: PackedStringArray = PackedStringArray(["cat", "dog", "rabbit", "bird", "hamster", "blob"])

const SPECIES_LABELS := {
	"cat": "小猫",
	"dog": "小狗",
	"rabbit": "兔子",
	"bird": "小鸟",
	"hamster": "仓鼠",
	"blob": "软萌团",
}

const DEFAULT_COLORS := {
	"cat": {
		"outline": "#3D2C29", "body": "#F4A261", "shadow": "#E0762F", "light": "#FFE0B8",
		"accent": "#E76F51", "eye": "#FFF8F0", "pupil": "#2B211E", "blush": "#FFB4C8",
	},
	"dog": {
		"outline": "#3D2C29", "body": "#D4A373", "shadow": "#B07D4F", "light": "#F5E1C8",
		"accent": "#8B5E3C", "eye": "#FFF8F0", "pupil": "#2B211E", "blush": "#FFB4C8",
	},
	"rabbit": {
		"outline": "#3D2C29", "body": "#F3D6D8", "shadow": "#E2B3B8", "light": "#FFF4F5",
		"accent": "#E8919A", "eye": "#FFF8F0", "pupil": "#2B211E", "blush": "#FFB4C8",
	},
	"bird": {
		"outline": "#3D2C29", "body": "#8ED8C4", "shadow": "#5FB89F", "light": "#E4FFF6",
		"accent": "#F4A261", "eye": "#FFF8F0", "pupil": "#2B211E", "blush": "#FFB4C8",
	},
	"hamster": {
		"outline": "#3D2C29", "body": "#F2C6A0", "shadow": "#D59A6A", "light": "#FFE9D2",
		"accent": "#E76F51", "eye": "#FFF8F0", "pupil": "#2B211E", "blush": "#FFB4C8",
	},
	"blob": {
		"outline": "#3D2C29", "body": "#FFC2D4", "shadow": "#F49AB3", "light": "#FFE6F0",
		"accent": "#FF8FAB", "eye": "#FFF8F0", "pupil": "#2B211E", "blush": "#FF9EBB",
	},
}

const PIXEL_KEYS := {
	"#": "outline",
	"B": "body",
	"D": "shadow",
	"L": "light",
	"A": "accent",
	"E": "eye",
	"P": "pupil",
	"C": "blush",
}

const CAT_IDLE := [
			"................", ".#.#........#.#.", "#A#A########A#A#", "#BBBBBBBBBBBBBB#",
			"#BEEBBBBBBBBEEB#", "#BEPBBBBBBBBEPE#", "#BBBBBBBBBBBBBB#", "#BBCBBBBBBCBBBB#",
			"#BBBB.AAAA.BBBB#", "#BBBBB....BBBBB#", ".#BBBBBBBBBBBB#.", ".#BBLLLLLLLLBB#.",
			".#DBLLLLLLLLBD#.", ".#BBBBBBBBBBBB#.", "..#BBB#..#BBB#..", "...###....###...",
]

const CAT_BLINK := [
			"................", ".#.#........#.#.", "#A#A########A#A#", "#BBBBBBBBBBBBBB#",
			"#B##BBBBBBBB##B#", "#B##BBBBBBBB##B#", "#BBBBBBBBBBBBBB#", "#BBCBBBBBBCBBBB#",
			"#BBBB.AAAA.BBBB#", "#BBBBB....BBBBB#", ".#BBBBBBBBBBBB#.", ".#BBLLLLLLLLBB#.",
			".#DBLLLLLLLLBD#.", ".#BBBBBBBBBBBB#.", "..#BBB#..#BBB#..", "...###....###...",
]

const CAT_TALK := [
	"................", ".#.#........#.#.", "#A#A########A#A#", "#BBBBBBBBBBBBBB#",
	"#BEEBBBBBBBBEEB#", "#BEPBBBBBBBBEPE#", "#BBBBBBBBBBBBBB#", "#BBCBBBBBBCBBBB#",
	"#BBBB.AAAA.BBBB#", "#BBBBB.AA.BBBBB#", ".#BBBB....BBBB#.", ".#BBLLLLLLLLBB#.",
	".#DBLLLLLLLLBD#.", ".#BBBBBBBBBBBB#.", "..#BBB#..#BBB#..", "...###....###...",
]

const DOG_IDLE := [
			"................", "##..........##..", "#D#........#D#..", ".#BB######BB#...",
			".#BBBBBBBBBB#...", ".#BEEBBBBEEB#...", ".#BEPBBBBPEB#...", ".#BBBBBBBBBB#...",
			".#BBCBAAABCBB#...", ".#BBB....BBB#...", ".#BBBBBBBBBB#...", "#BBLLLLLLLLBB#..",
			"#DBLLLLLLLLBD#..", ".#BBBBBBBBBB#...", "..#BBB##BBB#....", "...###..###.....",
]

const DOG_BLINK := [
			"................", "##..........##..", "#D#........#D#..", ".#BB######BB#...",
			".#BBBBBBBBBB#...", ".#B##BBBB##B#...", ".#B##BBBB##B#...", ".#BBBBBBBBBB#...",
			".#BBCBAAABCBB#...", ".#BBB....BBB#...", ".#BBBBBBBBBB#...", "#BBLLLLLLLLBB#..",
			"#DBLLLLLLLLBD#..", ".#BBBBBBBBBB#...", "..#BBB##BBB#....", "...###..###.....",
]

const DOG_TALK := [
	"................", "##..........##..", "#D#........#D#..", ".#BB######BB#...",
	".#BBBBBBBBBB#...", ".#BEEBBBBEEB#...", ".#BEPBBBBPEB#...", ".#BBBBBBBBBB#...",
	".#BBCBAAABCBB#...", ".#BBB.AA.BBB#...", ".#BBBB..BBBB#...", "#BBLLLLLLLLBB#..",
	"#DBLLLLLLLLBD#..", ".#BBBBBBBBBB#...", "..#BBB##BBB#....", "...###..###.....",
]

const RABBIT_IDLE := [
			"..#......#......", ".#A#....#A#.....", ".#B#....#B#.....", ".#B######B#.....",
			".#BBBBBBBB#.....", ".#BEEBBEEB#.....", ".#BEPBBPEB#.....", ".#BBBBBBBB#.....",
			".#BCBAAAABC#....", ".#BBB....B#.....", ".#BBBBBBBB#.....", "#BBLLLLLLBB#....",
			"#DBLLLLLLBD#....", ".#BBBBBBBB#.....", "..#BB##BB#......", "...##..##.......",
]

const RABBIT_BLINK := [
			"..#......#......", ".#A#....#A#.....", ".#B#....#B#.....", ".#B######B#.....",
			".#BBBBBBBB#.....", ".#B##BB##B#.....", ".#B##BB##B#.....", ".#BBBBBBBB#.....",
			".#BCBAAAABC#....", ".#BBB....B#.....", ".#BBBBBBBB#.....", "#BBLLLLLLBB#....",
			"#DBLLLLLLBD#....", ".#BBBBBBBB#.....", "..#BB##BB#......", "...##..##.......",
]

const RABBIT_TALK := [
	"..#......#......", ".#A#....#A#.....", ".#B#....#B#.....", ".#B######B#.....",
	".#BBBBBBBB#.....", ".#BEEBBEEB#.....", ".#BEPBBPEB#.....", ".#BBBBBBBB#.....",
	".#BCBAAAABC#....", ".#BBB.AA.B#.....", ".#BBBB..BB#.....", "#BBLLLLLLBB#....",
	"#DBLLLLLLBD#....", ".#BBBBBBBB#.....", "..#BB##BB#......", "...##..##.......",
]

const BIRD_IDLE := [
			"................", "....######......", "...#BBBBBB#.....", "..#BBBBBBBB#....",
			"..#BEEBBBEE#....", "..#BEPBBPEP#....", "..#BBBBAAAA#....", "..#BBCBBBAA#....",
			"...#BBBBBB#.....", "...#BLLLLB#.....", "..#DBLLLLBD#....", "..#BBBBBBBB#....",
			"...#D#..#D#.....", "....#....#......", "................", "................",
]

const BIRD_BLINK := [
			"................", "....######......", "...#BBBBBB#.....", "..#BBBBBBBB#....",
			"..#B##BBB###....", "..#B##BBB###....", "..#BBBBAAAA#....", "..#BBCBBBAA#....",
			"...#BBBBBB#.....", "...#BLLLLB#.....", "..#DBLLLLBD#....", "..#BBBBBBBB#....",
			"...#D#..#D#.....", "....#....#......", "................", "................",
]

const BIRD_TALK := [
	"................", "....######......", "...#BBBBBB#.....", "..#BBBBBBBB#....",
	"..#BEEBBBEE#....", "..#BEPBBPEP#....", "..#BBBB.AAA#....", "..#BBCBB.AA#....",
	"...#BBBBBB#.....", "...#BLLLLB#.....", "..#DBLLLLBD#....", "..#BBBBBBBB#....",
	"...#D#..#D#.....", "....#....#......", "................", "................",
]

const HAMSTER_IDLE := [
			"................", "...##########...", "..#BBBBBBBBBB#..", ".#BBBBBBBBBBBB#.",
			".#BEEBBBBBEEBB#.", ".#BEPBBBBBPEBB#.", ".#BBBBBBBBBBBB#.", ".#BBCBAAAABCBB#.",
			".#BBBB....BBBB#.", ".#BBLLLLLLLLBB#.", ".#DBLLLLLLLLBD#.", "..#BBBBBBBBBB#..",
			"..#BBB#..#BBB#..", "...###....###...", "................", "................",
]

const HAMSTER_BLINK := [
			"................", "...##########...", "..#BBBBBBBBBB#..", ".#BBBBBBBBBBBB#.",
			".#B##BBBBB##BB#.", ".#B##BBBBB##BB#.", ".#BBBBBBBBBBBB#.", ".#BBCBAAAABCBB#.",
			".#BBBB....BBBB#.", ".#BBLLLLLLLLBB#.", ".#DBLLLLLLLLBD#.", "..#BBBBBBBBBB#..",
			"..#BBB#..#BBB#..", "...###....###...", "................", "................",
]

const HAMSTER_TALK := [
	"................", "...##########...", "..#BBBBBBBBBB#..", ".#BBBBBBBBBBBB#.",
	".#BEEBBBBBEEBB#.", ".#BEPBBBBBPEBB#.", ".#BBBBBBBBBBBB#.", ".#BBCBAAAABCBB#.",
	".#BBBB.AA.BBBB#.", ".#BBLLLLLLLLBB#.", ".#DBLLLLLLLLBD#.", "..#BBBBBBBBBB#..",
	"..#BBB#..#BBB#..", "...###....###...", "................", "................",
]

const BLOB_IDLE := [
			"................", "....######......", "...#BBBBBB#.....", "..#BBBBBBBB#....",
			".#BBBBBBBBBB#...", ".#BEEBBBBEEB#...", ".#BEPBBBBPEB#...", ".#BBBBBBBBBB#...",
			".#BBCBAAABCB#...", ".#BBB....BBB#...", ".#BBLLLLLLBB#...", "..#DBLLLLBD#....",
			"...#BBBBBB#.....", "....#D##D#......", "................", "................",
]

const BLOB_BLINK := [
			"................", "....######......", "...#BBBBBB#.....", "..#BBBBBBBB#....",
			".#BBBBBBBBBB#...", ".#B##BBBB##B#...", ".#B##BBBB##B#...", ".#BBBBBBBBBB#...",
			".#BBCBAAABCB#...", ".#BBB....BBB#...", ".#BBLLLLLLBB#...", "..#DBLLLLBD#....",
			"...#BBBBBB#.....", "....#D##D#......", "................", "................",
]

const BLOB_TALK := [
	"................", "....######......", "...#BBBBBB#.....", "..#BBBBBBBB#....",
	".#BBBBBBBBBB#...", ".#BEEBBBBEEB#...", ".#BEPBBBBPEB#...", ".#BBBBBBBBBB#...",
	".#BBCBAAABCB#...", ".#BBB.AA.BBB#...", ".#BBLL..LLBB#...", "..#DBLLLLBD#....",
	"...#BBBBBB#.....", "....#D##D#......", "................", "................",
]

const BOWL := [
	[10, 12, "#"], [11, 12, "#"], [12, 12, "#"], [9, 13, "#"], [10, 13, "A"],
	[11, 13, "A"], [12, 13, "A"], [13, 13, "#"], [10, 14, "#"], [11, 14, "#"],
	[12, 14, "#"],
]

const ZZZ := [
	[13, 0, "A"], [14, 0, "A"], [15, 0, "A"], [14, 1, "A"], [13, 2, "A"],
	[14, 2, "A"], [15, 2, "A"],
]

const STRETCH := [
	[0, 1, "#"], [1, 0, "#"], [1, 1, "B"], [2, 1, "#"], [13, 1, "#"],
	[14, 0, "#"], [14, 1, "B"], [15, 1, "#"],
]

const KEYBOARD := [
	[5, 12, "D"], [6, 12, "B"], [7, 12, "D"], [2, 14, "#"], [3, 14, "L"],
	[4, 14, "#"], [5, 14, "L"], [6, 14, "#"], [7, 14, "L"], [8, 14, "#"],
	[9, 14, "L"], [10, 14, "#"], [11, 14, "L"], [12, 14, "#"], [3, 15, "#"],
	[4, 15, "#"], [5, 15, "#"], [6, 15, "#"], [7, 15, "#"], [8, 15, "#"],
	[9, 15, "#"], [10, 15, "#"], [11, 15, "#"],
]

const PHONE := [
	[11, 8, "#"], [12, 8, "#"], [13, 8, "#"], [11, 9, "#"], [12, 9, "L"],
	[13, 9, "#"], [11, 10, "#"], [12, 10, "A"], [13, 10, "#"], [11, 11, "#"],
	[12, 11, "L"], [13, 11, "#"], [11, 12, "#"], [12, 12, "A"], [13, 12, "#"],
	[11, 13, "#"], [12, 13, "#"], [13, 13, "#"],
]

const SNACK := [
	[2, 12, "#"], [3, 12, "A"], [4, 12, "#"], [1, 13, "#"], [2, 13, "A"],
	[3, 13, "A"], [4, 13, "A"], [5, 13, "#"], [2, 14, "#"], [3, 14, "A"],
	[4, 14, "#"],
]

const GAMEPAD := [
	[3, 13, "#"], [4, 13, "D"], [5, 13, "L"], [6, 13, "L"], [7, 13, "L"],
	[8, 13, "D"], [9, 13, "#"], [3, 14, "#"], [4, 14, "A"], [5, 14, "#"],
	[6, 14, "#"], [7, 14, "#"], [8, 14, "A"], [9, 14, "#"],
]

const SWEAT := [
	[1, 2, "L"], [0, 3, "L"], [1, 4, "L"],
]

const WAVE := [
	[13, 1, "#"], [14, 0, "#"], [15, 1, "#"], [13, 2, "#"], [14, 2, "A"],
	[15, 2, "#"], [14, 3, "B"], [13, 3, "#"], [15, 3, "#"], [14, 4, "#"],
]

const COFFEE := [
	[12, 6, "L"], [13, 7, "L"], [12, 8, "L"], [10, 11, "#"], [11, 11, "#"],
	[12, 11, "#"], [9, 12, "#"], [10, 12, "D"], [11, 12, "D"], [12, 12, "D"],
	[13, 12, "#"], [14, 12, "#"], [9, 13, "#"], [10, 13, "D"], [11, 13, "A"],
	[12, 13, "D"], [13, 13, "#"], [14, 13, "#"], [10, 14, "#"], [11, 14, "#"],
	[12, 14, "#"], [13, 14, "#"],
]

const TOILET := [
	[12, 5, "L"], [13, 6, "L"], [12, 7, "L"], [1, 11, "#"], [2, 11, "L"],
	[3, 11, "#"], [0, 12, "#"], [1, 12, "L"], [2, 12, "L"], [3, 12, "L"],
	[4, 12, "#"], [1, 13, "#"], [2, 13, "A"], [3, 13, "#"], [2, 14, "#"],
]

static var FRAMES := {
	"cat": species_poses(CAT_IDLE, CAT_BLINK, CAT_TALK),
	"dog": species_poses(DOG_IDLE, DOG_BLINK, DOG_TALK),
	"rabbit": species_poses(RABBIT_IDLE, RABBIT_BLINK, RABBIT_TALK),
	"bird": species_poses(BIRD_IDLE, BIRD_BLINK, BIRD_TALK),
	"hamster": species_poses(HAMSTER_IDLE, HAMSTER_BLINK, HAMSTER_TALK),
	"blob": species_poses(BLOB_IDLE, BLOB_BLINK, BLOB_TALK),
}

static func pad_row(row: String) -> String:
	return (row + "................").substr(0, 16)

static func neighbor_fill(grid: Array, x: int, y: int) -> String:
	var directions: Array[Vector2i] = [
		Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP,
	]
	for direction in directions:
		var neighbor: Vector2i = Vector2i(x, y) + direction
		if (
			neighbor.y >= 0
			and neighbor.y < grid.size()
			and neighbor.x >= 0
			and neighbor.x < 16
			and grid[neighbor.y][neighbor.x] == "A"
		):
			return "A"
	return "B"

static func visit_outside(
	grid: Array,
	outside: Array,
	stack: Array[Vector2i],
	x: int,
	y: int
) -> void:
	if x < 0 or y < 0 or x >= 16 or y >= grid.size():
		return
	if outside[y][x] or grid[y][x] != ".":
		return
	outside[y][x] = true
	stack.push_back(Vector2i(x, y))

static func fill_interior_holes(rows: Array) -> Array:
	var grid: Array = []
	for row in rows:
		grid.append(Array(pad_row(row).split("")))
	var height := grid.size()
	var outside: Array = []
	for _y in height:
		var outside_row: Array[bool] = []
		outside_row.resize(16)
		outside.append(outside_row)
	var stack: Array[Vector2i] = []
	for x in 16:
		visit_outside(grid, outside, stack, x, 0)
		visit_outside(grid, outside, stack, x, height - 1)
	for y in height:
		visit_outside(grid, outside, stack, 0, y)
		visit_outside(grid, outside, stack, 15, y)
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		visit_outside(grid, outside, stack, cell.x - 1, cell.y)
		visit_outside(grid, outside, stack, cell.x + 1, cell.y)
		visit_outside(grid, outside, stack, cell.x, cell.y - 1)
		visit_outside(grid, outside, stack, cell.x, cell.y + 1)
	for y in height:
		for x in 16:
			if grid[y][x] == "." and not outside[y][x]:
				grid[y][x] = neighbor_fill(grid, x, y)
	var result: Array = []
	for row in grid:
		result.append("".join(row))
	return result

static func normalize(rows: Array) -> Array:
	var padded: Array = []
	for row in rows:
		padded.append(pad_row(row))
	return fill_interior_holes(padded)

static func overlay(base: Array, cells: Array) -> Array:
	var grid: Array = []
	for row in normalize(base):
		grid.append(Array(row.split("")))
	for cell in cells:
		var x: int = cell[0]
		var y: int = cell[1]
		if y < 0 or y >= grid.size() or x < 0 or x >= 16:
			continue
		grid[y][x] = cell[2]
	var rows: Array = []
	for row in grid:
		rows.append("".join(row))
	return fill_interior_holes(rows)

static func species_poses(idle: Array, blink: Array, talk: Array) -> Dictionary:
	return {
		"idle": normalize(idle),
		"blink": normalize(blink),
		"talk": normalize(talk),
		"drink": overlay(blink, BOWL),
		"sleep": overlay(blink, ZZZ),
		"wake": overlay(idle, STRETCH),
		"type": overlay(idle, KEYBOARD),
		"phone": overlay(idle, PHONE),
		"snack": overlay(idle, SNACK),
		"peek": overlay(idle, SWEAT),
		"game": overlay(idle, GAMEPAD),
		"wave": overlay(idle, WAVE),
		"coffee": overlay(idle, COFFEE),
		"toilet": overlay(blink, TOILET),
	}

static func get_frame(species: String, pose: String) -> PackedStringArray:
	var selected_species := species if FRAMES.has(species) else "blob"
	var poses: Dictionary = FRAMES[selected_species]
	var selected_pose := pose if poses.has(pose) else "idle"
	var frame := PackedStringArray()
	for row in poses[selected_pose]:
		frame.append(pad_row(row))
	return frame

static func colors_for(species: String, colors: Dictionary) -> Dictionary:
	var selected_species := species if DEFAULT_COLORS.has(species) else "blob"
	var result: Dictionary = DEFAULT_COLORS[selected_species].duplicate(true)
	for key in result:
		if colors.has(key) and colors[key] is String:
			result[key] = colors[key]
	return result

static func paint_image(frame: PackedStringArray, colors: Dictionary, pixel_size: int) -> Image:
	var image := Image.create(16 * pixel_size, 16 * pixel_size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(mini(frame.size(), 16)):
		var row := pad_row(frame[y])
		for x in range(16):
			var code := row.substr(x, 1)
			if code == ".":
				continue
			var color := Color.html(colors[PIXEL_KEYS[code]])
			image.fill_rect(Rect2i(x * pixel_size, y * pixel_size, pixel_size, pixel_size), color)
	return image

static func opaque_count(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				count += 1
	return count
