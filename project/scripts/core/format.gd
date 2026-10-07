class_name Format


static func money(amount: int) -> String:
	var digits := str(absi(amount))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	var prefix := "-$" if amount < 0 else "$"
	return prefix + digits + grouped
