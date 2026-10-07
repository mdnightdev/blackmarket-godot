extends GutTest


func test_money_small_values_have_no_separator() -> void:
	assert_eq(Format.money(0), "$0")
	assert_eq(Format.money(999), "$999")


func test_money_groups_thousands() -> void:
	assert_eq(Format.money(1000), "$1,000")
	assert_eq(Format.money(1234567), "$1,234,567")


func test_money_negative_values() -> void:
	assert_eq(Format.money(-2500), "-$2,500")


func test_money_short_keeps_small_amounts_exact() -> void:
	assert_eq(Format.money_short(9850), "$9,850")
	assert_eq(Format.money_short(-450), "-$450")


func test_money_short_abbreviates_big_amounts() -> void:
	assert_eq(Format.money_short(12_480), "$12.4k")
	assert_eq(Format.money_short(40_000), "$40k")
	assert_eq(Format.money_short(1_250_000), "$1.2M")
	assert_eq(Format.money_short(-15_000), "-$15k")
