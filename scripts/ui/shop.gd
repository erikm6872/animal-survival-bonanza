extends CanvasLayer
class_name Shop

## Self-contained, reusable shop overlay — built so any screen can
## instance shop.tscn and call open()/close() without any setup beyond
## that. Deliberately doesn't touch get_tree().paused itself: a caller
## that's already a paused gameplay screen (e.g. the pause menu) stays
## paused around it for free, while a non-gameplay caller (the future
## home screen) was never going to pause the tree in the first place --
## pausing is the caller's concern, not the shop's.
##
## Reads currency/ownership from GameState and the Unlockable list from
## resources/unlockables/ at runtime (see unlockable.gd) rather than
## holding any wiring of its own, so it never needs to change when
## content is added there -- only a new .tres is needed.

const UNLOCKABLES_DIR := "res://resources/unlockables/"

## Lets a caller react to the shop closing (e.g. the pause menu re-showing
## its own panel underneath) without the shop needing to know who opened it.
signal closed

@onready var panel: PanelContainer = $PanelContainer
@onready var currency_label: Label = $PanelContainer/MarginContainer/VBoxContainer/CurrencyLabel
@onready var item_list: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ItemList
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/CloseButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	close_button.pressed.connect(close)
	GameState.currency_changed.connect(_update_currency_label)

func open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_currency_label(GameState.currency)
	_refresh_items()

func close() -> void:
	visible = false
	closed.emit()

func _update_currency_label(amount: int) -> void:
	currency_label.text = "Currency: %d" % amount

func _refresh_items() -> void:
	for child in item_list.get_children():
		child.queue_free()

	var unlockables := _load_unlockables()
	if unlockables.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No items available yet -- check back soon!"
		item_list.add_child(empty_label)
		return

	for unlockable in unlockables:
		item_list.add_child(_build_item_row(unlockable))

func _load_unlockables() -> Array[Unlockable]:
	var result: Array[Unlockable] = []
	var dir := DirAccess.open(UNLOCKABLES_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var resource: Resource = load(UNLOCKABLES_DIR + file_name)
			if resource is Unlockable:
				result.append(resource)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result

func _build_item_row(unlockable: Unlockable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var name_label := Label.new()
	name_label.text = "%s (%d)" % [unlockable.display_name, unlockable.cost]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var buy_button := Button.new()
	var owned := GameState.is_unlocked(unlockable.id)
	buy_button.text = "Owned" if owned else "Buy"
	buy_button.disabled = owned or GameState.currency < unlockable.cost
	buy_button.pressed.connect(_on_buy_pressed.bind(unlockable, buy_button))
	row.add_child(buy_button)

	return row

func _on_buy_pressed(unlockable: Unlockable, button: Button) -> void:
	if GameState.is_unlocked(unlockable.id):
		return
	if not GameState.spend_currency(unlockable.cost):
		return
	GameState.unlock(unlockable.id)
	button.text = "Owned"
	button.disabled = true
