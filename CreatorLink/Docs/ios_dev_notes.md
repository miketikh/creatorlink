# iOS Development Notes

Quick reference for common patterns and issues in this project.

## Project Info

- **Project Path:** `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink.xcodeproj`
- **Scheme:** `CreatorLink`

## Build Workflow

- **Always rebuild ALL running simulators** when making changes (use parallel build_run_sim calls)

## Debugging Workflow

- **MCP tools available:** Use XcodeBuildMCP tools for building, running, and log capture
- **Standard debug pattern:**
  1. Add print logs to relevant code paths
  2. Rebuild app
  3. Start log capture: `start_sim_log_cap` with `captureConsole: true`
  4. Perform the action to debug
  5. Stop log capture: `stop_sim_log_cap` to retrieve and analyze logs

## Critical SwiftUI Bugs to Avoid

- **List not updating:** Custom `Hashable`/`Equatable` must include ALL properties that affect UI rendering, not just `id`
- **Firestore listeners with @Observable:** Use `MainActor.assumeIsolated` in listener callbacks for @MainActor classes, not `Task { @MainActor }`
- **Listener lifecycle:** Check if listener exists before recreating to avoid removing active listeners

## Modern iOS Patterns (iOS 17+)

- Use `@Observable` with `@State` for ViewModels (replaces @StateObject/@ObservedObject)
- `.task` modifier runs every time view appears - guard against re-running initialization logic
