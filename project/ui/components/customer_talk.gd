class_name CustomerTalk

## Customer orders on the phone: reading the order, taking it, picking where to buy and the trips that follow.

const PORTRAIT: Texture2D = preload("res://assets/portraits/customer_silhouette.svg")
const ACCEPT: StringName = &"accept"
const DECLINE: StringName = &"decline"
const LATER: StringName = &"later"


## Customers have no CharacterDef, so each conversation gets a speaker with the silhouette.
class Speaker extends SpeakerDef:
	func title() -> String:
		return "Customer"


static func speaker(order: Dictionary) -> SpeakerDef:
	var customer := Speaker.new()
	customer.id = StringName(str(order.get("customer", "")))
	customer.display_name = Customers.customer_name(order)
	customer.portrait = PORTRAIT
	return customer


static func open(offer_id: String) -> void:
	var run := GameState.run
	var offer := Customers.find_offer(run, offer_id)
	if offer.is_empty():
		return
	var choices: Array[DialogueChoice] = [
		DialogueChoice.new(ACCEPT, "Accept", Customers.can_accept(run)),
		DialogueChoice.new(DECLINE, "Decline"),
		DialogueChoice.new(LATER, "Later", true, true),
	]
	GameOverlay.talk(speaker(offer), _pitch(offer), choices, _on_offer_choice.bind(offer_id), _terms(run, offer))


## Buying from a source the player picked on the quote sheet. Dealers here open their market, anywhere else
## the trip is offered, even when the price there is still unknown.
static func pick_source(order_id: String, quote: Dictionary) -> void:
	var run := GameState.run
	var order := Customers.find(run, order_id)
	if order.is_empty():
		return
	if str(quote.source) == CustomerQuotes.BAG:
		head_to_customer(order)
		return
	var district := Content.district(StringName(str(quote.district)))
	var dealer := Content.dealer(StringName(str(quote.source)))
	if district == null or dealer == null:
		return
	if district.id != run.district_id:
		TripTalk.offer(district)
	elif not bool(quote.open):
		var line := "%s is not dealing right now. I will try another time." % dealer.display_name
		GameOverlay.talk(Content.player(run.player_id), line, TripTalk.continue_only(), TripTalk.end)
	else:
		GameState.trading_with = dealer.id
		SceneRouter.go_to(SceneRouter.MARKET_SCREEN)


## In the customer's district the handover card comes up, anywhere else the trip there is offered.
static func head_to_customer(order: Dictionary, line := "") -> void:
	var run := GameState.run
	if StringName(str(order.district)) == run.district_id:
		GameState.queue_handover(str(order.id))
		return
	var district := Content.district(StringName(str(order.district)))
	if district != null:
		TripTalk.offer(district, line)


## Asked once, when the bag first holds every unit of an accepted order.
static func announce_stocked(order_id: String) -> void:
	var order := Customers.find(GameState.run, order_id)
	if order.is_empty() or not Customers.is_stocked(GameState.run, order):
		return
	var line := "You have the %s for %s. Head to %s now?" % [Customers.goods_label(order), Customers.customer_name(order), Customers.district_name(order)]
	head_to_customer(order, line)


static func _pitch(offer: Dictionary) -> String:
	var customer := Content.customer(StringName(str(offer.customer)))
	var opener := customer.line + " " if customer != null else ""
	return "%s%s in %s. %s each, street %s. %s in total." % [
		opener, Customers.goods_label(offer), Customers.district_name(offer), Format.money(int(offer.unit_price)),
		Format.money(int(offer.street_price)), Format.money(Customers.total(offer)),
	]


static func _terms(run: RunState, offer: Dictionary) -> String:
	var terms: Array[String] = []
	if not Customers.can_accept(run):
		terms.append("You already have %d customer orders. Finish one first." % Customers.MAX_ACTIVE)
	if bool(offer.rush):
		terms.append("Rush order.")
	terms.append("Due by %s if you take it now." % Calendar.describe(Calendar.stamp(run) + int(offer.lead)).to_lower())
	terms.append(Customers.tell(offer))
	return " ".join(terms)


static func _on_offer_choice(choice: StringName, offer_id: String) -> void:
	match choice:
		ACCEPT:
			_accept(offer_id)
		DECLINE:
			GameState.decline_customer_offer(offer_id)
			GameOverlay.end_talk()
		_:
			GameOverlay.end_talk()


## Taking the order where the customer waits with the goods in the bag goes straight to the handover card.
static func _accept(offer_id: String) -> void:
	if not GameState.accept_customer_offer(offer_id):
		GameOverlay.say("Too slow. That order is gone.", TripTalk.continue_only(), TripTalk.end)
		return
	AudioService.play_sfx(Sfx.FAVOUR_TAKEN)
	GameOverlay.end_talk()
	var order := Customers.find(GameState.run, offer_id)
	if not order.is_empty() and not Customers.can_hand_over(GameState.run, order):
		GameOverlay.open_quotes(offer_id)
