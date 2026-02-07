# Godot-Logger

My personal logging solution in Godot. Makes use of the new Logger class and multi-threading in Godot v4.5+. The logger is a single script that can be found in ```/lib/log.gd```, with an example of the features in ```/example/example.gd```. All *variables* that can be tinkered with should be at the top of the file.

Writing the logs is done on a separate thread, ensuring the main thread can keep running the application.

Feel free to use and modify this in any way, any suggestions are also always welcome.

## Usage Notes

To use just **drag and drop** ``log.gd`` into your project and change following project settings:

- ``` Project Settings > Debug > Settings > GDScript > Always Track Call Stacks ``` = **ENABLED**
- ``` Project Settings > Debug > File Logging ``` = **DISABLED**

The logger should then be available for use anywhere in the project.

To make sure that the logger shuts down properly on program *exit* the ``_notification`` function as seen in ``example.gd`` should be implemented.

It's generally best practice to crash the engine with ``OS.crash("")`` after logging a CRITICAL event, since this type of event usually means the application has corrupted state. 



