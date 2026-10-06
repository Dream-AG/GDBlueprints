# Validation and packaging

These tools live in the single canonical addon. They never require a separate development copy. They create disposable projects for tests; source files and project globals stay untouched. Python 3.11+, Node.js and Godot 4.7.2 are required.

From addons/GDBlueprints, run:

```sh
python tools/validate_release.py --godot GODOT_PATH --checks regressions
python tools/validate_release.py --godot GODOT_PATH --templates TEMPLATE_DIRECTORY --checks exports
python tools/validate_release.py --godot GODOT_PATH --checks packages
```

Use `--checks all` with `--templates` to run everything. Native export checks support Windows/Linux and require both matching standard debug/release export binaries in the template directory. Add `--render` for real graphics, `--node NODE_PATH` when Node.js is not on PATH, and `--logs LOG_DIRECTORY` to choose the report location. Each regression must reach its success marker; exit status alone is insufficient. Fixtures use real resources, but they do not certify all hardware or scene configurations.

Build release artifacts outside the addon:

```sh
python tools/package_release.py --output RELEASE_DIRECTORY
```

The addon ZIP contains addons/GDBlueprints. The source ZIP adds a sample project, root README/license and GitHub workflow. Both contain the same plugin implementation. Generated SHA256 checksums and a manifest describe exact archive contents. Public globals are replaced with an empty sealed template in memory; your installed global_vars.gd is never modified. Caches, credentials, logs and build outputs are excluded. Package validation imports both exact ZIPs into clean projects and checks the registry. Rebuild after any source change.

The source ZIP's workflow runs Windows and Linux validation. A configured workflow is not a passed run: keep Windows 4.7.2 as the verified target until CI establishes more coverage. All tooling stays with the addon so release preparation does not depend on a second source folder.

Before public submission, follow documentation/release.html. Complete a human editor/debugger acceptance pass, verify script edits survive compilation, test an upgrade on a backup and ask an independent developer to install the archive. Add real screenshots and publisher/repository details, retain MIT credits, disclose AI assistance where required, and keep the alpha scope explicit.
