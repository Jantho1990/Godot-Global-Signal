extends Label


# Called when the node enters the scene tree for the first time.
func _ready():
	GlobalSignal.add_listener("text_updated", self, "_on_Text_updated")


func _on_Text_updated(text_value: String):
	text = text_value
