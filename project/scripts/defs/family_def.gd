class_name FamilyDef
extends Resource

@export var id: StringName
@export var chinese_name: String
@export var pinyin: String
@export var english_name: String
@export var emblem: Texture2D
## Character who hands out favours and leads shakedowns.
@export var lieutenant: StringName
## Family that loses standing when the player works for this one.
@export var rival: StringName
## Districts the family runs. Shakedowns only happen here.
@export var home_districts: Array[StringName] = []


## Characters, pinyin and English, for example "青龙会 Qīnglóng Huì · Azure Dragon Society".
func full_name() -> String:
	return "%s %s · %s" % [chinese_name, pinyin, english_name]
