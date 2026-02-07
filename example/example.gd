extends Control
## This file acts as an example of how to use the logger.

## This has to be in a GLOBAL. So that the logger is only shut down when the game closes.
func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		Log.shutdown() # Shuts down the logger.

func _ready() -> void:
	# Below are all the logging functions, they optionally take a channel argument.
	Log.debug("Debug message") # Logs a DEBUG message.
	Log.info("Hello there!") # Logs an INFO message.
	Log.warn("Unexpected introduction detected") # Logs a WARN message.
	Log.error("Failed to provide adequate response") # Logs an ERROR message.
	Log.critical("Entered a State that is impossible, crashing...") # Logs a CRITICAL message.
	# OS.crash("See Above") # Uncomment this line for a manual crash (FAIL-FAST)
	Log.force_flush() # Forcibly flushes the file.

	# Can mute individual channels so logs don't show up for them.
	Log.mute_channel(Log.AUDIO)
	Log.error("Trying to log something for AUDIO", Log.AUDIO)
	Log.unmute_channel(Log.AUDIO)
	Log.error("This one it should actually log", Log.AUDIO)
	Log.force_flush()

	# Or mute all channels
	Log.mute_all()
	Log.info("This should not be logged")
	Log.info("This neither", Log.RENDER)
	Log.unmute_all()
	Log.info("Now this should show up again.")
	Log.info("And also this...", Log.RENDER)

	# When the engine crashes all logs that haven't been flushed yet are flushed.
	Log.info("Now this should be logged too when the engine crashes naturally.")
	Log.debug("And this too.")
	var crash_array: Array = []

	# For the sake of seeing the printed values we'll wait a second here.
	await get_tree().create_timer(0.5).timeout

	@warning_ignore("unused_variable")
	var foo = crash_array[0] # This should crash the engine.
