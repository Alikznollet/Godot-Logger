# Godot-Logger

My personal logging solution in Godot. Makes use of the new Logger class and multi-threading in Godot v4.5+. The logger is a single script that can be found in ```/lib/log.gd```, with an example of how to log messages in ```/example/example.gd```. Things such as the minimum log level and the directory where the logs will be written to can be found at the top.

Writing the logs is done on a separate thread, ensuring the main thread can keep running the application.

Feel free to use and modify this in any way, any suggestions are also always welcome.

### Notes

- Make sure to **enable** ``` Project Settings > Debug > Settings > GDScript > Always Track Call Stacks ```, otherwise traces could break in release builds.
- **Disable** the default Godot logging in ``` Project Settings > Debug > File Logging ```. This way logging doesn't happen twice.
- Make sure to call ```Log.shutdown()``` somewhere in an **Autoload**.

