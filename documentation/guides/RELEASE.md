# Release and publishing

## Milestone 7 scope

Version 0.10.0-alpha supplies reproducible source/addon packaging, an empty distributable globals template, isolated regression runners, native debug/release export fixtures, repository contribution templates and Windows/Linux CI configuration. Release builds disable debugger UI, frame scanning and F8 input handling. Graph metadata and stable IDs remain compatible.

The certified target is Godot 4.7.2 on Windows x86_64. Linux CI is configured but must pass on GitHub before Linux is advertised. macOS, mobile, Web, console platforms and other engine versions are unverified. Exporting a package is not evidence that it runs on another OS.

## Install and upgrade

Install the addon archive's `addons/GDBlueprints` folder. The source release archive also contains an example project and developer tools. Use exact path capitalization, including on case-sensitive filesystems. Back up your project before upgrading and preserve `addons/GDBlueprints/global_vars.gd`: it contains your project globals. The public archive intentionally includes an empty template; blindly overwriting it loses project declarations. Do not package a working project's globals as a public release.

Disable the plugin before removing it. Generated gameplay scripts still depend on runtime helpers under the addon, so removing the addon from a game with compiled graphs is not supported. Release exports may retain source graph metadata and editor resources; the smoke preset favors compatibility over minimum package size. Do not treat a game export as a way to hide proprietary source data.

## Release validation

The addon's tools/validate_release.py runs regression scripts in disposable projects with private editor settings and requires successful completion markers. Its export checks build and execute real debug/release binaries, including gameplay, persistence, audio, animation and camera fixtures. Package checks build reproducible archives and import the exact ZIPs into clean projects. Headless checks do not replace a human editor/debugger acceptance pass.

tools/package_release.py creates addon/source ZIPs, checksums and a per-file manifest. It sanitizes global_vars.gd in memory, preserving the installed project's declarations. Caches, logs and credentials are excluded. See [Release tools](../tools/RELEASE_TOOLS.md) for commands. Review unfamiliar contributions separately; packaging checks are not a comprehensive security audit.

## Before a public alpha

- Run the GitHub workflow on the exact commit/tag you intend to release. Resolve failures before broadening supported platforms.
- Perform manual editor checks: breakpoints/highlighting, Undo/Redo, external-script preservation, save/reopen, keyboard gameplay and upgrading a backed-up project. Keep the alpha label and publish the actual runtime test scope described in [Maintenance and coverage](maintenance.html).
- Choose the public maintainer/publisher identity and repository URL. Retain the full MIT license and upstream credits. Review project-specific data and commit history before pushing.
- Add screenshots of the actual editor graph and both demos, plus a short installation/use video if helpful. Prepare a square icon for the listing.
- Publish the repository and release tag, then use that exact revision/archive in the submission. Complete the submission account fields yourself.

The current [Asset Store submission guide](https://docs.godotengine.org/en/latest/community/asset_store/submitting_to_asset_store.html) describes publisher information, Addon asset type, license, source link, media, version uploads and mandatory AI-use disclosure when applicable. This project used AI assistance in development; disclose that accurately. For the older Asset Library workflow, follow its [submission guide](https://docs.godotengine.org/en/latest/community/asset_library/submitting_to_assetlib.html) and select the exact download commit. Requirements can change; check the active submission form before uploading.

## Next development work

Prioritize independent alpha feedback, representative fixtures for complex AnimationTree, split-screen and hardware-dependent operations, and removal of remaining ambiguous name-based targeting. Design multiplayer authority, replication and RPC separately before adding network nodes. Expand node coverage by Godot gameplay capability with explicit failure behavior, rather than promising automatic Unreal API parity.
