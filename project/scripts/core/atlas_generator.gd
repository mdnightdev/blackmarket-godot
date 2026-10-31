class_name AtlasGenerator
extends RefCounted

const TILE_SIZE := 128
const COLS := 10
const ROWS := 8
const ATLAS_PATH := "res://assets/items/items_atlas.png"

static var _cached_texture: Texture2D = null

static func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path)
		if t != null:
			return t
	var local := path.replace("res://", "project/")
	if FileAccess.file_exists(local):
		var img := Image.load_from_file(local)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


static func get_atlas_texture() -> Texture2D:
	if _cached_texture != null:
		return _cached_texture

	_cached_texture = _load_tex(ATLAS_PATH)
	if _cached_texture != null:
		return _cached_texture

	var fallback_paths := [
		"project/assets/items/items_atlas.png",
		"assets/items/items_atlas.png"
	]
	for p: String in fallback_paths:
		_cached_texture = _load_tex(p)
		if _cached_texture != null:
			return _cached_texture

	return null


static func get_atlas_subtexture(col: int, row: int) -> AtlasTexture:
	var atlas := get_atlas_texture()
	var sub := AtlasTexture.new()
	sub.atlas = atlas
	sub.region = Rect2(col * TILE_SIZE, row * TILE_SIZE, TILE_SIZE, TILE_SIZE)
	return sub


static func get_sample_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []

	# Side-by-side comparison: Current Photo vs Standalone 3D Prop
	var ammo_photo := _load_tex("res://assets/items/ammo_9mm.jpg")
	var ammo_3d := _load_tex("res://assets/items/prop_ammo_9mm.jpg")
	var phone_photo := _load_tex("res://assets/items/burner_phones.jpg")
	var phone_3d := _load_tex("res://assets/items/prop_burner_phone.jpg")

	if ammo_photo != null and ammo_3d != null:
		entries.append({
			"icon": ammo_photo,
			"title": "[Photo] 9mm Ammo",
			"tier": "Current Photo Card",
			"count": "x24",
			"price": "$80",
			"desc": "Current style: square camera photo with flat background filling the whole box."
		})
		entries.append({
			"icon": ammo_3d,
			"title": "[3D Prop] 9mm Ammo",
			"tier": "3D Standalone Prop",
			"count": "x24",
			"price": "$80",
			"desc": "New style: standalone 3D metal crate prop with isometric perspective and contact shadow."
		})

	if phone_photo != null and phone_3d != null:
		entries.append({
			"icon": phone_photo,
			"title": "[Photo] Burner Phone",
			"tier": "Current Photo Card",
			"count": "x4",
			"price": "$100",
			"desc": "Current style: square camera photo with flat background filling the whole box."
		})
		entries.append({
			"icon": phone_3d,
			"title": "[3D Prop] Burner Phone",
			"tier": "3D Standalone Prop",
			"count": "x4",
			"price": "$100",
			"desc": "New style: standalone 3D tactical flip phone with backlit keypad and clean depth."
		})

	# Full 80-item atlas entries
	var data_dir := "res://data/items/"
	var dir := DirAccess.open(data_dir)
	if dir != null:
		var file_names: Array[String] = []
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if fname.ends_with(".tres"):
				file_names.append(fname)
			fname = dir.get_next()
		dir.list_dir_end()
		file_names.sort()

		for i in file_names.size():
			var fn := file_names[i]
			var item_res: Resource = ResourceLoader.load(data_dir + fn)
			if item_res == null:
				continue
			var col := i % COLS
			var row := i / COLS
			var sub := get_atlas_subtexture(col, row)
			var display: String = item_res.get("display_name")
			var desc: String = item_res.get("description")
			var tier_int: int = item_res.get("tier") if item_res.get("tier") != null else 1
			var tier_label := "Tier %d" % tier_int
			var base_price: int = item_res.get("base_price") if item_res.get("base_price") != null else 0
			var price_str := "$%d" % base_price
			entries.append({
				"icon": sub,
				"title": display,
				"tier": tier_label,
				"count": "x1",
				"price": price_str,
				"desc": desc
			})

	return entries
