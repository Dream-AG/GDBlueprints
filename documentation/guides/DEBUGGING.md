# Debug graphs

GDBlueprints can pause event execution at graph nodes, step through execution paths, highlight the active node in the editor, and inspect activation-local values. It complements Godot's normal script debugger; generated GDScript remains readable and View Code still opens a node's generated method.

## Set a breakpoint

Execution-capable Flow and Action nodes have a Breakpoint button in their title bar. Enable it, then compile the graph so the breakpoint is included in generated code. The red button is stored with graph metadata and follows normal undo/save behavior.

Run the project from the editor. Just before that node executes, the game pauses and the Runtime Debug Overlay shows the owner, graph-node ID, input pin, execution step, and call depth. The corresponding node turns yellow in the open editor graph. A recently executed node turns green while the game runs.

Ordinary traces are sampled at most ten times per second while connected to Godot's debugger; this is a recent-execution view, not a complete execution history. Breakpoints and step stops are not sampled. The editor pans/selects only at a pause. Release builds skip graph tracing and graph breakpoints. Standalone debug runs still honor breakpoints but do not stream ordinary traces.

Event nodes start execution but do not expose breakpoints. Put the breakpoint on the first connected Flow or Action node. Pure Value nodes are evaluated by their consumers and do not have an independent execution moment, so they also do not expose breakpoints.

After changing breakpoints or graph connections, compile again before running. An already running game uses the last compiled script.

## Continue and step

Use the buttons in the game window's Runtime Debug Overlay:

- Continue resumes normally until another enabled breakpoint.
- Step Into pauses at the next asynchronous graph execution node, including a deeper call path.
- Step Over continues through deeper calls and pauses at the next node at the current call depth or a shallower depth.
- Step Out continues until execution reaches a shallower call depth.

The debugger pauses the SceneTree cooperatively while its overlay continues processing. Godot's editor and generated-script debugger remain available. F8 shows or hides the runtime overlay; hiding it does not resume a paused graph.

Continue preserves any SceneTree pause that was already active before the breakpoint. Breakpoints take priority over Step Over/Out depth filtering. If the graph's execution epoch changes while paused, its cancelled action is skipped on resume. Call depth here is the generated execution-path depth: an ordinary Then continuation can increase it, so Step Over is not identical to stepping over a line of GDScript.

## Inspect values

Each trace captures the current event arguments, function name and arguments, function locals, loop frames, stored call/loop values, and Script Variables marked for the Runtime Debug Overlay. Hover the highlighted editor node for the same compact snapshot. Values are copied into a bounded diagnostic representation: collections show at most 24 entries and three nested levels, and Object values show their class/path rather than executing getters.

This snapshot describes the activation before the highlighted node's body executes. Call Function Result appears on the next node after the call succeeds. Loop Index/Item appears during the loop body. Function locals show the current recursive invocation.

The existing variable/state watch controls remain live while execution runs. The breakpoint snapshot freezes the relevant activation values so they remain readable while paused.

## Synchronous function limitation

Graph functions deliberately compile as ordinary synchronous GDScript methods, so handwritten code can call them without `await`. Awaiting a debugger pause inside one would change that public contract and break callers. Function-body nodes therefore emit traces and green editor highlights, but their breakpoints are trace-only and report a warning. Set a pausing breakpoint on the event path immediately before or after Call Function. Function arguments, locals, results, and recursion depth still appear in trace snapshots.

This boundary also applies to synchronous handwritten methods called by Call Function. Use Custom Events for work that must pause, wait, or be stepped across asynchronous execution.

## Source mapping and failure behavior

Instrumentation uses the graph node's stable saved ID, so editor highlighting survives graph save/reload and node reordering. Runtime messages also carry the scene path and owner-relative NodePath; traces for another selected node do not highlight the wrong graph. If the game runs without the debugger Autoload, generated gameplay checks for it and continues normally.

Debugger snapshots never evaluate arbitrary graph expressions. They read activation dictionaries and explicitly watched members; as in the existing watch overlay, reading a watched GDScript property can invoke that property's getter. Keep watched getters free of gameplay side effects. A missing/freed Object is represented as diagnostic text. Instrumentation still participates in the normal 10,000-step and 128-call-depth execution budget; pausing does not reset that budget.

For a generated-code breakpoint, use View Code and Godot's Script debugger. Graph breakpoints are intended for execution flow and graph-local values. They do not replace physics-frame inspection, rendering tools, the profiler, or network diagnostics.
