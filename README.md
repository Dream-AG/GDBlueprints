# GDBlueprints

GDBlueprints is a visual scripting addon for Godot 4. It gives Unreal Engine users a familiar node-graph workflow while generating ordinary GDScript and using Godot's scenes, nodes, signals, resources, and debugger.

## Status

The current release is **0.10.1-alpha** and is validated against **Godot 4.7.2 on Windows x86_64**. Its 172 registered node definitions, compiler, typed data flow, functions, events, script interoperability, persistence, and representative 2D/3D gameplay paths pass the included automated suite. This is an alpha release, not a claim of full Unreal Blueprint parity or certification for every game, platform, or node configuration.

## What it provides

- Visual event graphs with typed value pins and structured execution flow.
- Custom events, typed graph functions, loops, branches, switches, sequence, delay, cancellation, and reusable templates.
- Reflection-based access to Godot properties, methods, and signals, including direct scene-node references.
- Nodes for common 2D, 3D, UI, audio, animation, persistence, camera, input, physics, and scene operations.
- Safe coexistence with handwritten GDScript: generated code stays inside sealed regions while your code remains editable in Godot or an external editor.
- Automatic discovery of project-local custom node definitions from `res://gdblueprints_nodes/`.
- Offline documentation and exact per-node reference pages.

## Install

1. Download the addon release ZIP and copy its `addons/GDBlueprints` folder into your Godot project.
2. In **Project > Project Settings > Plugins**, enable **GDBlueprints**.
3. Select a scene node and open the GDBlueprints bottom panel.
4. Add an event and actions, connect their execution pins, then compile and save.

Keep the folder name and capitalization exactly `addons/GDBlueprints`. Back up your project before upgrading, and preserve your project-specific `global_vars.gd` when replacing an existing install.

## Start here

- [Start Here](documentation/guides/START_HERE.md)
- [User Guide](documentation/guides/USER_GUIDE.md)
- [Godot for Unreal Users](documentation/guides/GODOT_FOR_UNREAL_USERS.md)
- [GDScript Interoperability](documentation/guides/GDSCRIPT_INTEROP.md)
- [Node Reference](documentation/NODE_INDEX.md)
- [Execution Model](documentation/guides/EXECUTION_MODEL.md)
- [Testing and Current Limits](documentation/guides/TESTING_AND_VALIDATION.md)
- [Release and Publishing](documentation/guides/RELEASE.md)

The built offline manual starts at `documentation/index.html`.

## Add a blueprint node

Read [Creating Blueprint Nodes](documentation/guides/NODE_DEFINITION_API.md). In the common case, a collaborator adds one `.gd` file that inherits the appropriate GDBlueprints base class, supplies a stable ID and metadata, declares its pins, and generates its Godot operation. The registry discovers it automatically; no central menu file needs editing. New execution semantics or shared runtime behavior require compiler/runtime support and tests in addition to the definition file.

## Validation and support boundary

The repository includes source loading, registry, generated-code, compiler, editor, persistence, gameplay, native-resource, export, documentation, and clean-package checks. The generated-code audit proves that every registered node has at least one configuration that emits parseable GDScript; it does not prove every property combination or scene-dependent behavior. Linux CI must pass before Linux is advertised. macOS, mobile, Web, consoles, multiplayer workflows, and several advanced Godot systems remain unverified or incomplete. See [Maintenance and Coverage](documentation/guides/MAINTENANCE.md) for the exact tested scope.

When reporting a bug, include the Godot version, operating system, scene setup, graph steps, generated error, and the smallest project that reproduces it.

## Contributing

Read [Contributing](documentation/guides/CONTRIBUTING.md), follow the stable-ID and pin-contract rules, document Godot terminology and failure behavior, and run the relevant validation suite before opening a pull request.

## License and attribution

GDBlueprints is released under the MIT License. It began from hoverbox's Logic Bricks project; retained upstream attribution and license details are in [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
