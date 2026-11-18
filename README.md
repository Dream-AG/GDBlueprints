<img width="1141" height="373" alt="Screenshot 2026-10-26 094224" src="https://github.com/user-attachments/assets/fd670b8c-4a82-40bc-bc05-8476f1e7e6a4" />

# GDBlueprints

GDBlueprints is a visual scripting addon for Godot 4. It is meant to mimic Unreal Engine's Blueprints in both nodes and functionality, while adhering to Godot's workflow. Every node compiles to GDScript, so this is not a unique programming language.

## Status

THIS IS STILL A WORK-IN-PROGRESS. It so far has 100+ registered node definitions, compiler, typed data flow, functions, events, script interoperability, persistence, and representative 2D/3D gameplay paths; but if far short of Unreal Engine's full node suite. It is currently functional based on limited testing, but it does produce errors despite compiling functional GDScript. But what Godot game doesn't ship with GDScript errors ;)

I am continuing to develop this slowly, but since some may find value in it's current state and may want to build on top of this, I am releasing this framework now.

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

## License and attribution

GDBlueprints is released under the MIT License. It began from Bri the 3D Guy's Logic Bricks project; retained upstream attribution and license details are in LICENSE and THIRD_PARTY_NOTICES.md.
