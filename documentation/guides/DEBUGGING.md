# Debug graphs

GDBlueprints uses Godot's normal Script debugger for breakpoints. Graph nodes do not have breakpoint buttons and breakpoint state is not stored in graph metadata.

## Set a breakpoint

1. Apply Code so the graph and generated GDScript match.
2. Select the graph node and use View Code to open its generated function.
3. Click the gutter beside the generated line where execution should pause.
4. Run the project as a debug build and inspect it with Godot's Debugger panels.

Recompiling a graph replaces its sealed generated region. If the generated line moves, set the gutter breakpoint again. Keep handwritten helpers outside the generated markers; they can use ordinary Godot breakpoints without being replaced by graph compilation.

## Execution highlighting and traces

Debug builds emit sampled, non-blocking execution traces while Godot's debugger is connected. The editor uses the saved graph-node ID and scene path to highlight the recently executed node. Traces are sampled at most ten times per second, so the highlight is a recent-execution view rather than a complete history.

Generated trace calls never pause the SceneTree and do not add an `await` boundary. Release builds skip trace capture. If the debugger Autoload is absent, generated gameplay continues normally.

## Watch values and state

Enable the watch control beside a graph variable, global variable, or state to show it in the Runtime Debug Overlay. Press F8 while a debug build is running to show or hide the overlay. Activation snapshots can show event arguments, function arguments and locals, loop data, captured results, and explicitly watched values from the latest sampled execution.

Snapshots never evaluate arbitrary graph expressions. Reading a watched GDScript property can invoke its getter, so watched getters should not change gameplay state. Missing or freed Objects appear as diagnostic text. Snapshots are bounded to keep large containers and recursive data from flooding the debugger.

## Functions and generated code

Graph functions remain ordinary synchronous GDScript methods, so handwritten code can call them without `await`. Use View Code and a Godot gutter breakpoint to pause inside them. Custom Events remain the right choice for work that intentionally waits across frames.

Generated functions keep stable names derived from saved graph-node IDs. This makes source navigation predictable across ordinary saves, although recompiling can still move line numbers. Do not edit the sealed generated region to add debugging code; use the Script debugger, watches, or a handwritten helper outside the markers.

Godot's profiler, monitors, remote scene tree, rendering debugger, physics inspection, and network tools remain the authoritative tools for engine-level behavior.
