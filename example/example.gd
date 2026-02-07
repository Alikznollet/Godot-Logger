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
	Log.force_flush() # Forcibly flushes the file.

	# Logs DEBUG messages, these are the most frequent.
	for i in range(5):
		Log.debug("Debug %d" % i)

	# Can mute individual channels so logs don't show up for them.
	Log.mute_channel(Log.AUDIO)
	Log.error("Trying to log something for AUDIO", Log.AUDIO)
	Log.unmute_channel(Log.AUDIO)
	Log.error("This one it should actually log", Log.AUDIO)
	Log.force_flush()

	# When logging a CRITICAL message usually best practice would be to crash the engine.
	# We'd rather fail fast than continue with corrupted state.
	Log.critical("Entered a State that is impossible, crashing...") # Logs a CRITICAL message.
	# OS.crash("See Above") # Uncomment this line for a manual crash (FAIL-FAST)

	Log.info("Now this should be logged too when the engine crashes naturally.")
	Log.debug("And this too.")
	var crash_array: Array = []

	@warning_ignore("unused_variable")
	var foo = crash_array[0] # This should crash the engine.
