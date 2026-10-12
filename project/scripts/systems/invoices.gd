class_name Invoices

## Money owed for jobs delivered on credit. run.invoices holds { id, client, amount, due_day }.
## Each one settles on the morning of its due day, and the buyer may never pay. The outcome comes from the
## run seed, so a reload cannot change it.

const PAY_BONUS := 0.4
const DAYS_TO_PAY := 2
const BASE_DEFAULT_CHANCE := 0.3
## Buyers trust a bigger name, so each street cred rank above the first lowers the chance they skip out.
const DEFAULT_DROP_PER_RANK := 0.025
const MIN_DEFAULT_CHANCE := 0.05


static func default_chance(run: RunState) -> float:
	return maxf(MIN_DEFAULT_CHANCE, BASE_DEFAULT_CHANCE - DEFAULT_DROP_PER_RANK * (StreetCred.rank(run) - 1)) * Edges.default_factor(run)


static func file(run: RunState, id: String, client: String, amount: int) -> Dictionary:
	var invoice := { "id": id, "client": client, "amount": amount, "due_day": run.day + DAYS_TO_PAY }
	run.invoices.append(invoice)
	return invoice


static func owed(run: RunState) -> int:
	var total := 0
	for invoice in run.invoices:
		total += int(invoice.amount)
	return total


## Settles every invoice due today or earlier. Returns each one with a paid flag added.
static func settle(run: RunState) -> Array[Dictionary]:
	var settled: Array[Dictionary] = []
	var waiting: Array[Dictionary] = []
	for invoice in run.invoices:
		if int(invoice.due_day) > run.day:
			waiting.append(invoice)
			continue
		var result := invoice.duplicate()
		result.paid = _roll(run, str(invoice.id)) >= default_chance(run)
		if result.paid:
			run.cash += int(invoice.amount)
			run.profit += int(invoice.amount)
		settled.append(result)
	run.invoices = waiting
	return settled


static func sanitize(source: Dictionary) -> Dictionary:
	var id := str(source.get("id", ""))
	var amount := int(source.get("amount", 0))
	if id.is_empty() or amount <= 0:
		return {}
	return {
		"id": id,
		"client": str(source.get("client", "")),
		"amount": amount,
		"due_day": maxi(1, int(source.get("due_day", 1))),
	}


static func _roll(run: RunState, id: String) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run.price_seed, &"invoice", id])
	return rng.randf()
