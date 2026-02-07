extends Logger
class_name Log
## Custom Log class to aid in debugging.
##
## Heavily based on the Log.gd in https://forum.godotengine.org/t/how-to-use-the-new-logger-class-in-godot-4-5/127006
## Added Things like minimum Log Level to include, Threaded logging, etc...

enum Event {
	INFO,
	WARN,
	ERROR,
	CRITICAL,
	FORCE_FLUSH
}

const _LOG_DIR: String = "user://logs/"
const _LOG_EXTENSION: String = "log"

const _MAX_LOG_FILES: int = 5
const _MAX_BUFFER_SIZE: int = 10

## Which events cause a flush to the log file.
const _FLUSH_EVENTS: PackedByteArray = [
	Event.ERROR,
	Event.CRITICAL,
	Event.FORCE_FLUSH
]

## Colors associated with each event.
const EVENT_COLORS: Dictionary[Event, String] = {
	Event.INFO: "lime_green",
	Event.WARN: "gold",
	Event.ERROR: "tomato",
	Event.CRITICAL: "crimson"
}

static var _event_strings: PackedStringArray = Event.keys()

static var _log_file: FileAccess
static var _thread: Thread
static var _semaphore: Semaphore
static var _mutex: Mutex = Mutex.new()
static var _exit_thread: bool = false
static var _message_queue: Array[Dictionary] = []
static var _is_logger_active: bool = false

## Minimum log level to include in the log file.
static var _min_log_level: Event = Event.INFO

static func _static_init() -> void:
	if not OS.is_debug_build():
		_min_log_level = Event.WARN # If Release build only include WARN and up.

	_log_file = _create_log_file()
	var is_valid: bool = _log_file and _log_file.is_open()
	if is_valid:
		_is_logger_active = true

		_semaphore = Semaphore.new()
		_thread = Thread.new()
		_thread.start(_thread_worker)

		OS.add_logger(Log.new())
		info("Logger Initialized...")

		_remove_old_log_files()

## Creates a new log file for the current Date and Time.
static func _create_log_file() -> FileAccess:
	# Create the logging directory if it does not exist yet.
	if not DirAccess.dir_exists_absolute(_LOG_DIR):
		DirAccess.make_dir_recursive_absolute(_LOG_DIR)

	var file_name := "%s.%s" % [Time.get_datetime_string_from_system().replace(":", "-"), _LOG_EXTENSION]
	var file_path := _LOG_DIR.path_join(file_name)
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	return file

## Removes the oldest log files when the amount exceeds _MAX_LOG_FILES
static func _remove_old_log_files() -> void:
	var log_file_paths: Array[String] = []
	for file: String in DirAccess.get_files_at(_LOG_DIR):
		if file.get_extension().to_lower() == _LOG_EXTENSION:
			log_file_paths.append(_LOG_DIR.path_join(file))
	while log_file_paths.size() > _MAX_LOG_FILES:
		var path: String = log_file_paths.pop_front()
		var err := DirAccess.remove_absolute(path)
		if err:
			pass
			error("Failed to clean up old log (%s): %s" % [error_string(err), path])
		else:
			pass
			info("Cleaned up old log: %s" % path)

# -- Helper Functions -- #

## Returns a GDScript Backtrace that can be used in the logs.
static func _get_gdscript_backtrace(script_backtraces: Array[ScriptBacktrace]) -> String:
	var gdscript := script_backtraces.find_custom(func(backtrace: ScriptBacktrace) -> bool:
		return backtrace.get_language_name() == "GDScript")
	return "Backtrace N/A" if gdscript == -1 else str(script_backtraces[gdscript])

## Formats a Log message properly.
static func _format_log_message(message: String, event: Event) -> String:
	return "[{time}] [{event}] {message}".format({
		"time": Time.get_time_string_from_system(),
		"event": _event_strings[event],
		"message": message
	})

# -- Engine Interception -- #

## Logs an actual engine error.
func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	if not _is_logger_active:
		return
	var event := Event.WARN if error_type == ERROR_TYPE_WARNING else Event.ERROR
	var message := "[{time}] {event}: {rationale}\n{code}\n{file}:{line} @ {function}()".format({
		"time": Time.get_time_string_from_system(),
		"event": _event_strings[event],
		"rationale": rationale,
		"code": code,
		"file": file,
		"line": line,
		"function": function,
 	})
	if event == Event.ERROR:
		message += '\n' + _get_gdscript_backtrace(script_backtraces)
	_add_message_to_file_queue(message, event)

func _log_message(message: String, log_message_error: bool) -> void:
	if not _is_logger_active or message.begins_with("[lang=tlh]"):
		return
	var event := Event.ERROR if log_message_error else Event.INFO
	message = _format_log_message(message.trim_suffix('\n'), event)
	_add_message_to_file_queue(message, event)

# -- Custom Logging -- #

static func _log(message: String, event: Event) -> void:
	if not _is_logger_active or event < _min_log_level: return

	message = _format_log_message(message, event)

	if event >= Event.ERROR:
		var script_backtraces := Engine.capture_script_backtraces()
		message += '\n' + _get_gdscript_backtrace(script_backtraces)

	_add_message_to_file_queue(message, event)
	_print_event(message, event)

# Send and info message to the log.
static func info(message: String) -> void:
	_log(message, Event.INFO)

## Send a Warn message to the log.
static func warn(message: String) -> void:
	_log(message, Event.WARN)

## Send an Error message to the log.
static func error(message: String) -> void:
	_log(message, Event.ERROR)

## Send a Critical message to the log.
static func critical(message: String) -> void:
	_log(message, Event.CRITICAL)

## Forcibly flush the log file.
static func force_flush() -> void:
	_add_message_to_file_queue("", Event.FORCE_FLUSH)

# -- Printing & File -- #

## Adds a message to the log file, thread-safe.
static func _add_message_to_file_queue(message: String, event: Event) -> void:
	_mutex.lock()
	_message_queue.append({"msg": message, "flush": (event >= Event.ERROR)})
	_mutex.unlock()

	_semaphore.post() # Wake up the worker.

## Prints a single message and event.
static func _print_event(message: String, event: Event) -> void:
	var message_lines := message.split("\n")
	message_lines[0] = "[b][color=%s]%s[/color][/b]" % [EVENT_COLORS[event], message_lines[0]]
	print_rich.call_deferred("[lang=tlh]%s[/lang]" % "\n".join(message_lines))

## -- Multi-Threading -- ##

## The Threaded worker that will write all of the logs to a file without blocking
## the main thread.
static func _thread_worker() -> void:
	var buffer_size: int = 0

	while true:
		_semaphore.wait()
		
		_mutex.lock()
		if _exit_thread and _message_queue.is_empty():
			_mutex.unlock()
			break # This is the exact exit condition (end of program and everything printed)
		
		# Grab a duplicate of the message queue and clear it.
		var local_queue = _message_queue.duplicate()
		_message_queue.clear()
		_mutex.unlock()

		if _log_file:
			for entry in local_queue:
				# If message is empty we don't have anything to store.
				if entry.msg:
					_log_file.store_line(entry.msg)
					buffer_size += 1

				# We flush if the message needs flushing or the buffer size is exceeded.
				if entry.flush or buffer_size >= _MAX_BUFFER_SIZE:
					_log_file.flush()
					buffer_size = 0

# -- Shutdown -- #

## Safely shuts down the Logging Thread and the logger itself.
static func shutdown() -> void:
	if not _is_logger_active: return

	info("Shutting down logger...")

	# Force a flush.
	force_flush()

	_mutex.lock()
	_exit_thread = true
	_mutex.unlock()

	_semaphore.post() # Wake up the Thread one last time.
	_thread.wait_to_finish()

	if _log_file:
		_log_file.close()
	_is_logger_active = false
	
