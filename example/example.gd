extends Control

func _ready() -> void:
	Log.info("Hello there!")
	Log.warn("Unexpected introduction detected")
	Log.error("Failed to provide adequate response")
	Log.critical("Crashing...")
	Log.force_flush()
