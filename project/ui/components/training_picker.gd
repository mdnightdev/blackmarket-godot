class_name TrainingPicker
extends AmountPicker

## Pays for men in the Gym. They join the outfit the moment the order goes through.

const FIRST_PICK := 1000

var _course: Gym.Course


func open(course: Gym.Course) -> void:
	_course = course
	_option_check.set_pressed_no_signal(false)
	_option_check.visible = false
	_present(str(Gym.COURSES[course].name), TurfSection.per_man(Gym.price_per_thousand(course)), FIRST_PICK)


func _most() -> int:
	return Gym.most(GameState.run, _course)


func _describe(men: int) -> void:
	var run := GameState.run
	var tier: Army.Tier = Gym.COURSES[_course].tier
	_summary_label.text = "You will have %s %s." % [Format.count(Army.count(run, tier) + men), Army.TIER_NAMES[tier]]
	if men > 0:
		_confirm_button.text = "%s %s for %s" % ["Hire" if _course == Gym.Course.LUNATICS else "Train", Format.count(men), Format.money(Gym.price(_course, men))]
		return
	match Gym.check(run, _course, 1):
		Gym.Result.NOT_ENOUGH_MEN:
			_confirm_button.text = "No fit Lunatics"
		Gym.Result.OUTFIT_FULL:
			_confirm_button.text = "Expand outfit first"
		Gym.Result.NOT_ENOUGH_CASH:
			_confirm_button.text = "Not enough cash"
		_:
			_confirm_button.text = "Pick how many"


func _submit(men: int) -> bool:
	if GameState.enroll_training(_course, men) != Gym.Result.OK:
		return false
	AudioService.play_sfx(Sfx.COINS_OUT)
	return true
