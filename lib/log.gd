extends Logger
class_name Log
## Custom Log class to aid in debugging.
##
## Heavily based on the Log.gd in https://forum.godotengine.org/t/how-to-use-the-new-logger-class-in-godot-4-5/127006

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

static var _buffer_size: int
static var _event_strings: PackedStringArray = Event.keys()

static var _log_file: FileAccess
static var _is_valid: bool
static var _mutex: Mutex = Mutex.new()

## Minimum log level to include in the log file.
static var _min_log_level: Event = Event.INFO

static func _static_init() -> void:
	if not OS.is_debug_build():
		_min_log_level = Event.WARN # If Release build only include WARN and up.

	_log_file = _create_log_file()
	_is_valid = _log_file and _log_file.is_open()
	if _is_valid:
		OS.add_logger(Log.new())
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
			#error("Failed to clean up old log (%s): %s" % [error_string(err), path])
		else:
			pass
			#info("Cleaned up old log: %s" % path)

## Returns a GDScript Backtrace that can be used in the logs.
static func _get_gdscript_backtrace(script_backtraces: Array[ScriptBacktrace]) -> String:
	var gdscript := script_backtraces.find_custom(func(backtrace: ScriptBacktrace) -> bool:
		return backtrace.get_language_name() == "GDScript")
	return "Backtrace N/A" if gdscript == -1 else str(script_backtraces[gdscript])

## Formats a Log message properly.
static func _format_log_message(message: String, event: Event) -> String:
	return "[{time}] {event}: {message}".format({
		"time": Time.get_time_string_from_system(),
		"event": _event_strings[event],
		"message": message
	})

## Adds a message to the log file, thread-safe.
static func _add_message_to_file(message: String, event: Event) -> void:
	_mutex.lock()
	if _is_valid:
		if not message.is_empty():
			_is_valid = _log_file.store_line(message)
			_buffer_size += 1
		if _buffer_size >= _MAX_BUFFER_SIZE or event in _FLUSH_EVENTS:
			_log_file.flush()
			_buffer_size = 0
	_mutex.unlock()

## Prints a single message and event.
static func _print_event(message: String, event: Event) -> void:
	var message_lines := message.split("\n")
	message_lines[0] = "[b][color=%s]%s[/color][/b]" % [EVENT_COLORS[event], message_lines[0]]
	print_rich.call_deferred("[lang=tlh]%s[/lang]" % "\n".join(message_lines))

## Logs an actual engine error.
func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	if not _is_valid:
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
	_add_message_to_file(message, event)

func _log_message(message: String, log_message_error: bool) -> void:
	if not _is_valid or message.begins_with("[lang=tlh]"):
		return
	var event := Event.ERROR if log_message_error else Event.INFO
	message = _format_log_message(message.trim_suffix('\n'), event)
	_add_message_to_file(message, event)

# Send and info message to the log.
static func info(message: String) -> void:
	var event := Event.INFO
	if not _is_valid or event < _min_log_level:
		return
	
	message = _format_log_message(message, event)
	_add_message_to_file(message, event)
	_print_event(message, event)

## Send a Warn message to the log.
static func warn(message: String) -> void:
	var event := Event.WARN
	if not _is_valid or event < _min_log_level:
		return
	
	message = _format_log_message(message, event)
	_add_message_to_file(message, event)
	_print_event(message, event)

## Send an Error message to the log.
static func error(message: String) -> void:
	var event := Event.ERROR
	if not _is_valid or event < _min_log_level:
		return
	
	message = _format_log_message(message, event)
	var script_backtraces := Engine.capture_script_backtraces()
	message += '\n' + _get_gdscript_backtrace(script_backtraces)
	_add_message_to_file(message, event)
	_print_event(message, event)

## Send a Critical message to the log.
static func critical(message: String) -> void:
	var event := Event.CRITICAL
	if not _is_valid or event < _min_log_level:
		return
	
	message = _format_log_message(message, event)
	var script_backtraces := Engine.capture_script_backtraces()
	message += '\n' + _get_gdscript_backtrace(script_backtraces)
	_add_message_to_file(message, event)
	_print_event(message, event)

## Forcibly flush the log file.
static func force_flush() -> void:
	_add_message_to_file("", Event.FORCE_FLUSH)
