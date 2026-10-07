extends GutTest


func test_money_small_values_have_no_separator() -> void:
	assert_eq(Format.money(0), "$0")
	assert_eq(Format.money(999), "$999")


func test_money_groups_thousands() -> void:
	assert_eq(Format.money(1000), "$1,000")
	assert_eq(Format.money(1234567), "$1,234,567")


func test_money_negative_values() -> void:
	assert_eq(Format.money(-2500), "-$2,500")
