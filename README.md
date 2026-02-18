# roblox-libs

Shared Roblox/Luau libraries for use across projects via git submodule.

## Libraries

| Library | Type | Description |
|---------|------|-------------|
| **ServiceLoader** | Source | Two-phase module initializer (Require → Init → Start) for single-script Rojo architecture |
| **ProfileSystem** | Source | Player profile lifecycle integrating ProfileStore + Replica (load, replicate, cleanup) |
| **ProfileStore** | Submodule | Periodic DataStore saving with session locking ([MadStudioRoblox/ProfileStore](https://github.com/MadStudioRoblox/ProfileStore)) |
| **Replica** | Submodule | Server-to-client state replication ([MadStudioRoblox/Replica](https://github.com/MadStudioRoblox/Replica)) |

## Usage

Add as a git submodule in your project's `vendor/` directory:

```bash
git submodule add https://github.com/batteryday/roblox-libs.git vendor/roblox-libs
git submodule update --init --recursive
```

Then map the libraries in your `default.project.json` (Rojo config).
