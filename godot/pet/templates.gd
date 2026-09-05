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

const FRAMES := {
	"cat": {
		"idle": [
			"................", ".#.#........#.#.", "#A#A########A#A#", "#BBBBBBBBBBBBBB#",
			"#BEEBBBBBBBBEEB#", "#BEPBBBBBBBBEPE#", "#BBBBBBBBBBBBBB#", "#BBCBBBBBBCBBBB#",
			"#BBBB.AAAA.BBBB#", "#BBBBB....BBBBB#", ".#BBBBBBBBBBBB#.", ".#BBLLLLLLLLBB#.",
			".#DBLLLLLLLLBD#.", ".#BBBBBBBBBBBB#.", "..#BBB#..#BBB#..", "...###....###...",
		],
		"blink": [
			"................", ".#.#........#.#.", "#A#A########A#A#", "#BBBBBBBBBBBBBB#",
			"#B##BBBBBBBB##B#", "#B##BBBBBBBB##B#", "#BBBBBBBBBBBBBB#", "#BBCBBBBBBCBBBB#",
			"#BBBB.AAAA.BBBB#", "#BBBBB....BBBBB#", ".#BBBBBBBBBBBB#.", ".#BBLLLLLLLLBB#.",
			".#DBLLLLLLLLBD#.", ".#BBBBBBBBBBBB#.", "..#BBB#..#BBB#..", "...###....###...",
		],
	},
	"dog": {
		"idle": [
			"................", "##..........##..", "#D#........#D#..", ".#BB######BB#...",
			".#BBBBBBBBBB#...", ".#BEEBBBBEEB#...", ".#BEPBBBBPEB#...", ".#BBBBBBBBBB#...",
			".#BBCBAAABCBB#...", ".#BBB....BBB#...", ".#BBBBBBBBBB#...", "#BBLLLLLLLLBB#..",
			"#DBLLLLLLLLBD#..", ".#BBBBBBBBBB#...", "..#BBB##BBB#....", "...###..###.....",
		],
		"blink": [
			"................", "##..........##..", "#D#........#D#..", ".#BB######BB#...",
			".#BBBBBBBBBB#...", ".#B##BBBB##B#...", ".#B##BBBB##B#...", ".#BBBBBBBBBB#...",
			".#BBCBAAABCBB#...", ".#BBB....BBB#...", ".#BBBBBBBBBB#...", "#BBLLLLLLLLBB#..",
			"#DBLLLLLLLLBD#..", ".#BBBBBBBBBB#...", "..#BBB##BBB#....", "...###..###.....",
		],
	},
	"rabbit": {
		"idle": [
			"..#......#......", ".#A#....#A#.....", ".#B#....#B#.....", ".#B######B#.....",
			".#BBBBBBBB#.....", ".#BEEBBEEB#.....", ".#BEPBBPEB#.....", ".#BBBBBBBB#.....",
			".#BCBAAAABC#....", ".#BBB....B#.....", ".#BBBBBBBB#.....", "#BBLLLLLLBB#....",
			"#DBLLLLLLBD#....", ".#BBBBBBBB#.....", "..#BB##BB#......", "...##..##.......",
		],
		"blink": [
			"..#......#......", ".#A#....#A#.....", ".#B#....#B#.....", ".#B######B#.....",
			".#BBBBBBBB#.....", ".#B##BB##B#.....", ".#B##BB##B#.....", ".#BBBBBBBB#.....",
			".#BCBAAAABC#....", ".#BBB....B#.....", ".#BBBBBBBB#.....", "#BBLLLLLLBB#....",
			"#DBLLLLLLBD#....", ".#BBBBBBBB#.....", "..#BB##BB#......", "...##..##.......",
		],
	},
	"bird": {
		"idle": [
			"................", "....######......", "...#BBBBBB#.....", "..#BBBBBBBB#....",
			"..#BEEBBBEE#....", "..#BEPBBPEP#....", "..#BBBBAAAA#....", "..#BBCBBBAA#....",
			"...#BBBBBB#.....", "...#BLLLLB#.....", "..#DBLLLLBD#....", "..#BBBBBBBB#....",
			"...#D#..#D#.....", "....#....#......", "................", "................",
		],
		"blink": [
			"................", "....######......", "...#BBBBBB#.....", "..#BBBBBBBB#....",
			"..#B##BBB###....", "..#B##BBB###....", "..#BBBBAAAA#....", "..#BBCBBBAA#....",
			"...#BBBBBB#.....", "...#BLLLLB#.....", "..#DBLLLLBD#....", "..#BBBBBBBB#....",
			"...#D#..#D#.....", "....#....#......", "................", "................",
		],
	},
	"hamster": {
		"idle": [
			"................", "...##########...", "..#BBBBBBBBBB#..", ".#BBBBBBBBBBBB#.",
			".#BEEBBBBBEEBB#.", ".#BEPBBBBBPEBB#.", ".#BBBBBBBBBBBB#.", ".#BBCBAAAABCBB#.",
			".#BBBB....BBBB#.", ".#BBLLLLLLLLBB#.", ".#DBLLLLLLLLBD#.", "..#BBBBBBBBBB#..",
			"..#BBB#..#BBB#..", "...###....###...", "................", "................",
		],
		"blink": [
			"................", "...##########...", "..#BBBBBBBBBB#..", ".#BBBBBBBBBBBB#.",
			".#B##BBBBB##BB#.", ".#B##BBBBB##BB#.", ".#BBBBBBBBBBBB#.", ".#BBCBAAAABCBB#.",
			".#BBBB....BBBB#.", ".#BBLLLLLLLLBB#.", ".#DBLLLLLLLLBD#.", "..#BBBBBBBBBB#..",
			"..#BBB#..#BBB#..", "...###....###...", "................", "................",
		],
	},
	"blob": {
		"idle": [
			"................", "....######......", "...#BBBBBB#.....", "..#BBBBBBBB#....",
			".#BBBBBBBBBB#...", ".#BEEBBBBEEB#...", ".#BEPBBBBPEB#...", ".#BBBBBBBBBB#...",
			".#BBCBAAABCB#...", ".#BBB....BBB#...", ".#BBLLLLLLBB#...", "..#DBLLLLBD#....",
			"...#BBBBBB#.....", "....#D##D#......", "................", "................",
		],
		"blink": [
			"................", "....######......", "...#BBBBBB#.....", "..#BBBBBBBB#....",
			".#BBBBBBBBBB#...", ".#B##BBBB##B#...", ".#B##BBBB##B#...", ".#BBBBBBBBBB#...",
			".#BBCBAAABCB#...", ".#BBB....BBB#...", ".#BBLLLLLLBB#...", "..#DBLLLLBD#....",
			"...#BBBBBB#.....", "....#D##D#......", "................", "................",
		],
	},
}

static func pad_row(row: String) -> String:
	return (row + "................").substr(0, 16)

static func get_frame(species: String, pose: String) -> PackedStringArray:
	var selected_pose := pose if pose == "blink" else "idle"
	var frame := PackedStringArray()
	for row in FRAMES[species][selected_pose]:
		frame.append(pad_row(row))
	return frame

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
