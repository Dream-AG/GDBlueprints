# Compatibility and upgrades

## GDBlueprints rename

Install in `addons/GDBlueprints/`. Close Godot before moving an existing installation. Update project, script, scene, resource, and custom-node references to the previous addon directory to `res://addons/GDBlueprints/`, including autoload and enabled-plugin paths. Preserve `.uid` files when moving. Open the editor and let it rescan; do not keep two installed copies. Saved graph metadata keys and stable node IDs remain supported.

New custom nodes should use `res://gdblueprints_nodes/`. Previous extension folders remain discoverable for existing projects. Upstream attribution remains in LICENSE and THIRD_PARTY_NOTICES.md.

## Existing scripts

New compilation uses GDBLUEPRINTS region markers. The compiler and script-rebuild reader accept previous markers; recompilation migrates the region without replacing handwritten code outside it. Mixed or duplicate regions fail validation instead of silently merging generated code.

Back up your project before upgrades. Keep scenes and their attached scripts in source control together. Recompile and test a representative scene after replacing the addon.

## Existing nodes

Compatibility aliases resolve saved IDs. Hidden compatibility definitions stay loadable but are not suggested for new graphs. Creating a subclass uses a new ID and does not change every use of the base node. Add the new type, copy appropriate settings, and reconnect deliberately.

Changing a published node's ID or pin names can break saved graphs. Keep IDs stable; add explicit migrations when changing serialized structure. Defaults are merged with saved properties so newly introduced settings have defined values.

## Milestone 1 execution migration

Version 0.5.0-alpha uses one execution backend. Raw graph saves acquire execution format 2; original stable node IDs and numeric port positions are preserved. Delay adds Cancel as input 1 while In remains input 0. Old chain-only saves lower to ordered execution edges during compilation without modifying their saved dictionaries.

Branch/Cast nodes in older condition-chain graphs retain their multi-input condition interpretation through a compatibility flag. Graphs already saved with explicit execution edges retain native entry behavior. New Branch/Cast nodes use native entry behavior; replace a compatibility node deliberately if you want to change that interpretation. Combine Conditions and Script Controller retain their historical condition/terminal behavior.

Pending latent execution now cancels on owner tree exit and Blueprint state changes, including exit/re-entry and state round trips. New explicit execution paths are ordered and awaited. Version-1 explicit-edge saves retain their previous fire-and-forget fan-out through compatibility flags, so existing delayed sibling paths still start independently. Adding a structured loop makes its Body await completion, including compatibility nodes inside that Body. Replacing old nodes with newly added nodes deliberately adopts the new ordering contract; separate Custom Events are the preferred way to express independent work.

Recompile scenes after upgrading and run your representative fixtures. A newer unsupported execution format, invalid graph, or generated-source parse error stops script replacement. The editor keeps the last compiled-chain metadata when compilation fails; the editable graph remains available for fixing the error.

## 0.6.0 functions, types, and interoperability

Function graphs use execution format 4. Keep scene metadata and compiled scripts together, and do not edit these graphs with an older plugin. Existing signal connections continue discarding arguments until Forward Arguments is enabled. StringName and NodePath now retain their distinct pin types; use explicit conversion when connecting older String-based data to those signatures.

New compiled regions get a checksum. Older regions without one are adopted at their next successful compile; back up any manual edits inside an older region before that compile. Handwritten code belongs outside the markers. GlobalVars preserves handwritten code outside its markers and now records typed declaration metadata as comments.
