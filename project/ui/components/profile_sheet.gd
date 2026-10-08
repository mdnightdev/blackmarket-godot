class_name ProfileSheet
extends BottomSheet

const HEAT_HIGH := 70

@onready var _margin: MarginContainer = %Margin
@onready var _portrait: TextureRect = %Portrait
@onready var _name_label: Label = %NameLabel
@onready var _rank_label: Label = %RankLabel
@onready var _where_label: Label = %WhereLabel
@onready var _rows: VBoxContainer = %Rows
@onready var _heat_value: Label = %HeatValue
@onready var _heat_bar: ProgressBar = %HeatBar
@onready var _cred_value: Label = %CredValue
@onready var _cred_bar: ProgressBar = %CredBar
@onready var _motto: Label = %Motto

var _heat_fill: StyleBoxFlat


func _ready() -> void:
	super()
	_heat_fill = _heat_bar.get_theme_stylebox("fill").duplicate()
	_heat_bar.add_theme_stylebox_override("fill", _heat_fill)
	_heat_bar.max_value = Heat.MAX
	GameState.run_changed.connect(_on_run_changed)
	%BagLink.pressed.connect(GameOverlay.open_bag)
	%JobsLink.pressed.connect(GameOverlay.open_jobs)
	%SettingsLink.pressed.connect(SceneRouter.go_to.bind(SceneRouter.SETTINGS_SCREEN))
	%QuitLink.pressed.connect(_quit_to_title)


func open_profile() -> void:
	SafeArea.apply_top_margin(_margin, 24)
	_refresh()
	open_sheet()


func _on_run_changed() -> void:
	if visible:
		_refresh.call_deferred()


func _refresh() -> void:
	var run := GameState.run
	if run == null:
		return
	var player := Content.player(run.player_id)
	_portrait.texture = player.portrait if player != null else null
	_name_label.text = player.display_name if player != null else ""
	_motto.text = "\"%s\"" % player.tagline if player != null and not player.tagline.is_empty() else ""
	_motto.visible = not _motto.text.is_empty()

	var rank := StreetCred.rank(run)
	_rank_label.text = StreetCred.rank_name(rank).to_upper()
	var district := GameState.current_district()
	_where_label.text = "Day %d, %s. %s" % [run.day, RunState.phase_name(run.phase), district.display_name if district != null else ""]

	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_add_stat("Cash", Format.money(run.cash))
	if run.stashed_cash > 0:
		_add_stat("In the stash", Format.money(run.stashed_cash))
	if run.debt > 0:
		_add_stat("Owed to the Shark", Format.money(run.debt))
	_add_stat("Net worth", Format.money(Campaign.net_worth(run)))
	_add_stat("Districts held", "%d" % Turf.held_count(run))

	_heat_bar.value = run.heat
	_heat_value.text = "%d / %d" % [run.heat, Heat.MAX]
	_heat_fill.bg_color = Palette.RISK_HIGH if run.heat >= HEAT_HIGH else Palette.PEACH

	var floor_cred := int(StreetCred.RANKS[rank - 1].cred)
	var next_cred := StreetCred.next_rank_cred(rank)
	if next_cred < 0:
		_cred_bar.max_value = 1
		_cred_bar.value = 1
		_cred_value.text = "%d, top rank" % run.street_cred
	else:
		_cred_bar.max_value = next_cred - floor_cred
		_cred_bar.value = run.street_cred - floor_cred
		_cred_value.text = "%d / %d to %s" % [run.street_cred, next_cred, StreetCred.rank_name(rank + 1)]


func _add_stat(caption: String, value: String) -> void:
	var row := HBoxContainer.new()
	var caption_label := Label.new()
	caption_label.theme_type_variation = &"MutedLabel"
	caption_label.text = caption
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := Label.new()
	value_label.theme_type_variation = &"StatValueLabel"
	value_label.text = value
	row.add_child(caption_label)
	row.add_child(value_label)
	_rows.add_child(row)


func _quit_to_title() -> void:
	GameState.save_run()
	close()
	SceneRouter.go_to(SceneRouter.TITLE_SCREEN)
