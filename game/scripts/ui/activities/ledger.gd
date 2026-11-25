## "Write it in the book, I'll pay later": a neighbour asks for credit.
## What they had and the price of each, and what the book already holds.
## Give credit (then write the sum in the book, digit by digit) or ask for
## cash. Skipping writes the right sum.
extends "res://scripts/ui/activity.gd"

## Who asks, what they had ([[name, price]]), the bill, all still owed.
var who := ""
var items: Array = []
var bill := 0
var owed := 0
## Read by the scene after `done`: credit given or not, the sum written.
var give := true
var written := -1
var _entry := ""
var _col: VBoxContainer
var _sum: Label


func _build() -> void:
	set_hint(s.t("act_ledger_ask", {"name": who}))
	_col = VBoxContainer.new()
	_col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_col.offset_left = 12
	_col.offset_right = -12
	_col.add_theme_constant_override("separation", 6)
	canvas.add_child(_col)
	for it in items:
		_col.add_child(Look.label(s.t("ledgerItem", {"item": str(it[0]), "n": int(it[1])}), 17))
	_col.add_child(Look.label(s.t("ledgerOwed", {"n": owed}), 15, false, Look.MUTED))
	add_button("ledger_give", Look.PARROT, _to_book)
	add_button("ledger_cash", Look.SKY.darkened(0.15), _cash)


func _tick(_dt: float) -> void:
	if t > 30.0:
		_quick()


func _cash() -> void:
	give = false
	finish(1.0)


## Credit given: now write the sum on the book's page.
func _to_book() -> void:
	for b in buttons.get_children():
		b.queue_free()
	for k in _col.get_children():
		k.queue_free()
	set_hint(s.t("act_ledger_write", {"name": who}))
	var page := PanelContainer.new()
	page.add_theme_stylebox_override("panel", Look.card(Color("FBF3DC"), 8, 2))
	var line := Look.label("", 20, true)
	page.add_child(line)
	_sum = line
	_col.add_child(page)
	var keys := GridContainer.new()
	keys.columns = 4
	keys.add_theme_constant_override("h_separation", 6)
	keys.add_theme_constant_override("v_separation", 6)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "del", "ok"]:
		var label: String = s.t("ledger_" + k) if k in ["del", "ok"] else k
		var colour := Look.PARROT if k == "ok" else (Look.VERMILION if k == "del" else Look.OUTLINE.lerp(Color.WHITE, 0.25))
		var b := Look.button(label, colour, 18)
		b.custom_minimum_size = Vector2(0, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_key.bind(k))
		keys.add_child(b)
	_col.add_child(keys)
	_show()


func _key(k: String) -> void:
	buzz(10)
	if k == "del":
		_entry = _entry.substr(0, maxi(0, _entry.length() - 1))
	elif k == "ok":
		if _entry == "":
			return
		written = int(_entry)
		finish(1.0 if written == bill else 0.3)
		return
	elif _entry.length() < 4:
		_entry += k
	_show()


func _show() -> void:
	if _sum != null:
		_sum.text = s.t("ledgerLine", {"name": who, "n": _entry if _entry != "" else "_"})


## Skipped: credit, and the right sum written.
func _quick() -> void:
	quick = true
	give = true
	written = bill
	finish(0.5)
