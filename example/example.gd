extends Control
## This file acts as an example of how to use the logger.

## This has to be in a GLOBAL. So that the logger is only shut down when the game closes.
func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		Log.shutdown() # Shuts down the logger.

func _ready() -> void:
	Log.info("Hello there!") # Logs an INFO message.
	Log.warn("Unexpected introduction detected") # Logs a WARN message.
	Log.error("Failed to provide adequate response") # Logs an ERROR message.
	Log.critical("Crashing...") # Logs a CRITICAL message.
	Log.force_flush() # Forcibly flushes the file.
