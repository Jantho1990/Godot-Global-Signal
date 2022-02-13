extends LineEdit

signal text_updated(text_value)


# Called when the node enters the scene tree for the first time.
func _ready():
	GlobalSignal.add_emitter("text_updated", self)
	GlobalSignal.emit_signal_when_ready("text_updated", ["text in _ready()"], self)
	connect("text_changed", self, "_on_Text_changed")


func _on_Text_changed(_value):
	emit_signal("text_updated", text)
