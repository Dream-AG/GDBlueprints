# Functions and local variables

Functions package reusable synchronous graph behavior. A Function Entry defines an ordinary typed GDScript method on the graph's scene node. Call Function invokes it from another graph path; handwritten code can call the same method normally. The owner must be in the scene tree.

## Build a first function

1. Add Function Entry. Set Function Name to `remember_value`, Parameters to `amount: Int`, Return Type to `Int`, and Locals to `saved: Int`.
2. Click Apply Signature. The entry exposes amount and Local: saved as typed data outputs.
3. Add Set Local, set Local Name to `saved`, and connect entry Then to Set Local In. Connect amount to its Value input.
4. Add Return. Connect Set Local Then to Return In, and Local: saved to Return Value.
5. Add Call Function on an event path. Set Function Name to `remember_value`, leave Target as Self, and click Use Local Definition. This copies and applies the parameter and return types.
6. Connect a value to amount, or enter a numeric expression such as `12`. Continue from Then and read Result. Apply Code.

Handwritten code on the same script can use `var result: int = remember_value(12)`. Other scripts can call `target.remember_value(12)`. Neither requires `await`. Keep handwritten methods outside the generated markers.

## Parameters, locals, and results

Parameters and Locals use comma-separated `name: Type` pairs. Each function has one entry and one public name; functions cannot share a name with a Custom Event. Use `void` when no value should be returned. A void function may end without Return; leave Return Value as `null` when returning explicitly from a void function.

Locals start at their type's default on every call. Set Local updates the current call only. Read the current value from the corresponding Function Entry output. Recursion and nested calls have independent local dictionaries, and Array/Dictionary local defaults are allocated separately. Script Variables remain persistent members on the owner; they are not function locals. Stateful nodes such as Do Once retain their documented per-owner state.

Argument values follow Godot semantics. Arrays, Dictionaries, Resources, and Objects can refer to shared data; passing them does not make a deep copy. Changing an argument collection's contents can therefore affect its caller.

Call Function evaluates its arguments once and captures its return value for the successful Then path. Repeated reads of Result do not call the function again. Use Result only downstream of that successful Then output. To retain a value beyond that path, assign it to a declared function local or Script Variable. Pure data expressions remain evaluated when read; they are not automatically cached.

Set Local and Return accept Variant pins because their expected types come from the enclosing function. Runtime checks enforce the declared local/return types, including Int-to-Float widening. Invalid assignments cancel the function call.

## Calls and failure handling

For Self, Use Local Definition copies the current applied definition. It also works on Call Custom Event. After changing a definition, update affected callers. For another target, connect its Object reference or provide a node path and click Browse Methods. Selecting a method fills its signature and optional defaults; runtime-only targets can still use manual signatures. See [GDScript interoperability](gdscript-interop.html).

Call Function can invoke generated functions or synchronous handwritten methods. It checks argument count and basic types before dispatch, then checks the returned value. Missing targets/methods or incompatible values warn and select Failed. Result is unavailable on Failed. Within a function returning a value, wire both Then and Failed to paths that Return. A cancelled execution context, including an exhausted budget or a state change, stops continuation instead of running Failed.

A direct handwritten call has a normal typed return value, not a Failed pin. If its graph execution is cancelled, it reports an error and returns the declared type's default. Handle invalid targets before invoking methods from handwritten code.

## Synchronous execution and scope

Functions reject Delay and generated action code that waits with `await`. Put waiting work in event graphs, then call a function before or after it. Handwritten methods used through Call Function must also be synchronous. Starting independent background work through a Custom Event does not make a function wait for that event.

Return exits the current function, including its nested loops and Sequence paths. Functions returning a value need Return on every statically checked path. Loops need a Completed return path because they may execute zero times. A shared execution budget covers nested and recursive graph calls, including calls between nodes.

Parameter/local outputs are valid only within their function. Result is valid only after its call succeeds. The compiler rejects out-of-scope uses, undeclared locals, duplicate definitions, and mismatched calls to known Self definitions.

Apply Signature preserves connected wires by parameter/local names when reordered. Removing connected outputs or making directly connected pins incompatible is rejected until those wires are adjusted. Set Local names must also be updated when declarations change. Signature changes use the existing undo/redo snapshot system.

## Compatibility and next steps

Graphs containing function nodes use execution format 4. Earlier releases refuse to save or compile that format. Version 2 ordinary graphs and version 3 parameterized event graphs remain supported.

Signatures include supported Godot types, native typed collections, and explicit integer enums. See [Collections and enums](types-and-enums.html). Method and signal reflection is available in the editor. Function nodes emit debugger traces, while pausing breakpoints stay on asynchronous event paths to preserve synchronous calls; see [Debug graphs](debugging.html). Functions are synchronous instance methods, not static function libraries or arbitrary GDScript-to-graph conversion.
