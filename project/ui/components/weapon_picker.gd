class_name WeaponPicker
extends AmountPicker

## Buys weapons from Rook in any amount, or sells them back to him at half his price.

const FIRST_PICK := 100

var _grade: Armory.Grade
var _selling := false


## on_closed gets true when the deal went through.
func open(grade: Armory.Grade, selling: bool, on_closed: Callable) -> void:
	var run := GameState.run
	var weapon := str(Armory.GRADE_NAMES[grade]).to_lower()
	_grade = grade
	_selling = selling
	_option_check.visible = false
	var owned := Format.count(Armory.count(run, grade))
	if selling:
		_present("Sell %s" % weapon, "Rook pays half his price. You own %s." % owned, FIRST_PICK, on_closed)
	else:
		_present("Buy %s" % weapon, "%s each, and each one arms one man. You own %s." % [Format.money(int(Armory.UNIT_PRICES[grade])), owned], FIRST_PICK, on_closed)


func _most() -> int:
	var run := GameState.run
	return Armory.count(run, _grade) if _selling else Armory.most_affordable(run, _grade)


func _describe(amount: int) -> void:
	var owned := Armory.count(GameState.run, _grade)
	_summary_label.text = "You will have %s." % Format.count(owned - amount if _selling else owned + amount)
	if amount <= 0:
		_confirm_button.text = "Nothing to sell" if _selling else "Not enough cash"
	elif _selling:
		_confirm_button.text = "Sell %s for %s" % [Format.count(amount), Format.money(Armory.sell_price(_grade, amount))]
	else:
		_confirm_button.text = "Buy %s for %s" % [Format.count(amount), Format.money(Armory.price(_grade, amount))]


func _submit(amount: int) -> bool:
	var result := GameState.sell_weapons(_grade, amount) if _selling else GameState.buy_weapons(_grade, amount)
	if result != Armory.Result.OK:
		return false
	AudioService.play_sfx(Sfx.COINS_IN if _selling else Sfx.GEAR_BUY)
	return true
