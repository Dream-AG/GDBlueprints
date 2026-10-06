# Execution and loops

Custom Event parameters live in each invocation's execution context, rather than generated script members. They remain available after Delay and through legacy asynchronous fan-out. Call Custom Event does not wait for delayed event work; its Then output follows dispatch. Array, Dictionary, and Object arguments retain Godot reference semantics. See the user guide for typed parameter authoring and edits that preserve connected wires by name.

Graphs using event parameters store execution format version 3. Older plugin releases reject these graphs for saving/compilation. Ordinary graphs without parameter signatures retain version 2 in editor metadata; this release reads both formats.

Function graphs use execution format 4. Their node methods are synchronous, with no await-based traversal. Return ends the current call and exits nested loops/Sequence paths. Calls between graph owners share the execution meter. Function parameters, locals, and captured results belong to the current invocation. See [Functions and locals](functions.html) for the authoring workflow and failure rules.

## One execution model

GDBlueprints compiles connected nodes into GDScript methods. Events and legacy condition adapters start activations; the same execution backend handles their actions. Saved chains from older releases are lowered into this model when compiled.

Within one activation, execution is depth-first and ordered. Multiple wires from one output run in their saved connection order. A connected path finishes, including any Delay, before the next wire runs. Use Sequence when the intended order should be visible on the graph. Separate event activations can run independently and overlap; shared Do Once and Delay state still belongs to the graph node on that scene instance.

Sequence runs Then 0, Then 1, Then 2, and Then 3 in order, skipping unconnected outputs. It awaits each path. For more outputs, connect another Sequence. This explicit awaited ordering differs from Unreal's handling of latent work inside Sequence; independent work should start through separate Custom Events.

## For Loop

Connect an event to In. Set First, Last, and Step, or connect integer values to those pins. Bounds are inclusive: First 0, Last 3, Step 1 visits 0, 1, 2, 3. First 3, Last 0, Step -1 visits 3, 2, 1, 0. A range facing the wrong direction has no iterations and runs Completed immediately. Step cannot be zero.

Body runs once per index and finishes before the next iteration. Index is available as an Int data output inside the Body path. Bounds and Step are evaluated once on entry. Delay inside Body pauses that iteration instead of starting all iterations simultaneously.

## For Each

Connect an Array to Items or enter an Array expression such as `inventory`. The node copies the Array's current list of entries and visits them in order. Changing the source Array during iteration does not add or remove iterations. Contained Objects/Resources remain references, so their own properties may change.

Index and Item are valid inside Body. Body finishes before the next item. Empty arrays run Completed immediately. A value that is not an Array cancels the activation and reports an error; packed-array conversion belongs to the typed-data milestone.

## Break and Continue

Break leaves the innermost active loop and runs that loop's Completed path. Continue skips the remaining Body work and advances to the next iteration. Nested loops keep separate control state and Index/Item values. Completed runs once on normal exhaustion, an empty collection/range, or Break. It does not run after cancellation or budget failure.

Connect these nodes from inside Body, often after a Branch. Do not wire an output back to the loop input. Back-wires are rejected; structural looping is expressed by the loop node itself. Break/Continue outside a loop and loop-data connections outside Body are compile errors. Store an output in a graph variable if you need it after the loop.

## Switches

Switch on Int and Switch on String evaluate Selection once, then run the matching Case 0..3 output or Default. Configure four unique case values. Strings compare exactly, including case; integer switches also accept Godot enum integers. A selection with a different type has no match and goes to Default. Chain another switch from Default for additional cases without changing existing port IDs.

## Delay, cancellation, and state

Delay waits for game time using a SceneTree timer that pauses with the tree. Negative durations become zero and still resume asynchronously. Non-finite durations cancel the activation with an error. Another activation reaching the same Delay while it is waiting is ignored.

Cancel stops that waiting activation without Completed. Other activations remain independent. Tree exit or any Blueprint state change invalidates all pending work on that owner, even if the owner is re-added or the state changes back before the timer fires. A new activation can start immediately after cancellation. Freeing the owner also ends its pending execution. Pause suspends timers; it does not cancel them.

Do Once state persists per node and scene instance. Reset reopens it without running Then. Start Closed requires Reset before the first successful In. A state change cancels pending work but does not implicitly Reset Do Once.

Cancellation stops graph continuations; it does not undo completed actions or stop unrelated audio, tweens, or handwritten coroutines. Custom async node implementations must check their own lifetime before performing work after a wait.

## Safeguards and errors

Each activation is limited to 10,000 node/iteration steps and 128 active execution calls. Delays do not reset the step budget. Synchronous recursive Custom Events share an execution meter so they cannot evade these limits by starting fresh events. Exhaustion reports the offending graph node ID and cancels the activation rather than freezing the editor. Long-running game behavior should use frame/timer events with bounded work per activation.

Compiler validation rejects cyclic wiring, invalid loop scope, duplicate switch cases, unsupported execution kinds, and constant zero steps. Dynamic invalid inputs are reported at runtime. A failed compile leaves handwritten code, the existing generated script, and the last compiled-chain metadata intact.

## Compatibility

Timer Event and One Shot Event preserve their previous event semantics. Combine Conditions still combines event/condition values and supports its saved state settings. Older condition-style Branch/Cast nodes are tagged during migration so multiple inputs keep their previous interpretation. Version-1 explicit-edge saves retain their old non-awaited fan-out outside structured loop bodies. New nodes use the ordered contract above. Script Controller retains its historical terminal script call; use Call Object Method when the call should participate in an action path.

Actions that supply continuous inactive updates still receive them when their condition or branch is inactive. A shared destination executes each time an active path reaches it; Do Once can explicitly limit repeated activation. See [Compatibility](compatibility.html) for upgrade details and [Testing](testing-validation.html) for the automated coverage.
