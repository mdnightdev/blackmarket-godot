class_name Format


static func money(amount: int) -> String:
	var digits := str(absi(amount))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	var prefix := "-$" if amount < 0 else "$"
	return prefix + digits + grouped


## Gains carry a plus sign, for example +$1,200, -$300 and $0.
static func signed_money(amount: int) -> String:
	return "+%s" % money(amount) if amount > 0 else money(amount)


## Keeps big amounts short enough for the top bar: $9,850, $12.4k, $1.2M.
static func money_short(amount: int) -> String:
	var size := absi(amount)
	if size < 10_000:
		return money(amount)
	var prefix := "-$" if amount < 0 else "$"
	if size < 1_000_000:
		return prefix + _one_decimal(size / 1000.0) + "k"
	return prefix + _one_decimal(size / 1_000_000.0) + "M"


## Countdown form of a duration, for example 4:05.
static func clock(seconds: float) -> String:
	var whole := maxi(0, ceili(seconds))
	return "%d:%02d" % [floori(whole / 60.0), whole % 60]


static func _one_decimal(value: float) -> String:
	var text := "%.1f" % (floorf(value * 10.0) / 10.0)
	return text.trim_suffix(".0")
