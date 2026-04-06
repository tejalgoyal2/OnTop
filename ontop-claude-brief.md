# OnTop — Claude Code Build Brief

> Status: brainstorming-to-build handoff
> 
> Important: some details below may be incomplete or slightly inaccurate because this brief combines public repo information, inferred behavior, and product decisions made during planning. Claude should treat this as the intended direction, not as a rigid source of truth. Claude should fetch and inspect the inspiration repository directly before making implementation decisions.

## Primary inspiration repo

- Source repo: https://github.com/itsabhishekolkha/AlwaysOnTop
- README page: https://github.com/itsabhishekolkha/AlwaysOnTop/blob/main/README.md
- License page: https://github.com/itsabhishekolkha/AlwaysOnTop/blob/main/LICENSE

## What we are building

We are building a **menu-bar-only macOS utility** called **OnTop**.

The purpose is simple:
- Let the user pin the **frontmost window** so it stays above other normal windows.
- Keep the app **small, fast, and low-overhead**.
- Avoid turning this into a complex window manager.
- Support a maximum of **3 pinned windows**.
- Support **priority levels** so pinned windows can also stay ordered relative to each other.

## Core user use cases

### Use case 1 — AI coding workflow
The user is working in a browser-based AI chat that occupies most of the screen, but wants a small Terminal window to remain visible at all times. When the browser becomes active, the Terminal should not disappear behind it.

### Use case 2 — File/reference workflow
The user wants a Finder window, notes window, or another small utility window floating while working in another app.

### Use case 3 — Small video/reference player
The user wants a small video/reference window to remain visible regardless of which app is currently focused.

## Product principles

1. **Menu bar only**
   - No Dock icon.
   - Prefer a clean menu bar workflow.
   - Preferences/settings can be opened from the menu bar.

2. **Pin the frontmost window**
   - If the user presses the shortcut while focused on an app/window, that frontmost window should be pinned.
   - No complicated window picker is required for v1 unless implementation needs a fallback.

3. **Stay light on CPU and memory**
   - This is critical.
   - The app must not become a bottleneck on macOS.
   - Avoid constant polling if possible.
   - Prefer event-driven behavior and minimal work while idle.
   - Cap scope at 3 pinned windows to keep state management and reordering simple.

4. **Keep the UI minimal**
   - Menu bar for main controls.
   - Optional tiny preferences/settings window.
   - No heavy dashboard or large management UI.

5. **Reimplementation, not a direct copy**
   - This project is inspired by the public AlwaysOnTop repo.
   - We plan to reimplement cleanly.
   - A short acknowledgment in the final README is acceptable and desirable.

## Naming

- Final app name: **OnTop**

### Must-have features
- Menu bar app only.
- Pin the **frontmost** window using a keyboard shortcut.
- Unpin the frontmost pinned window using a keyboard shortcut or menu action.
- Show pinned windows in menu bar UI.
- Support up to **3 pinned windows** maximum.
- Support window priority levels, for example:
  - Level 1
  - Level 2
  - Level 3
- If multiple pinned windows overlap, the higher level should remain above the lower level.
- Customizable keyboard shortcuts.
- Launch at login.
- Accessibility permission onboarding.
- Optional persistence/restore only if it does **not** noticeably hurt performance or stability.

### Nice-to-have features
- Pause all pins temporarily.
- Unpin all.
- Show current pinned window titles/app names in the menu.
- Small confirmation feedback when pin/unpin succeeds.
- Restore remembered pinned items on app relaunch only if practical and reliable.

### Non-goals
- No tiling window management.
- No snapping layouts.
- No advanced workspace automation.
- No rules engine.
- No support for more than 3 pinned windows.
- No bloated multi-panel UI.
- No background behavior that aggressively scans all windows all the time.

## Performance constraints (important)

Claude should optimize around the following:
- **Near-zero idle CPU usage**.
- Minimal timer usage.
- Avoid tight polling loops.
- Reapply z-order only when needed.
- Keep internal state tiny.
- Handle app/window closures gracefully without expensive rescans.
- Favor reliability over cleverness.
- Keep startup fast.
- If persistence/restore adds too much complexity or overhead, make it optional or omit it.

### Practical performance guidance
- Use event-driven macOS APIs where possible.
- Watch only the necessary windows.
- Limit tracked pinned windows to 3.
- Clean up observers/state as soon as windows close or apps terminate.
- Do not build a generic window-indexing engine if a smaller targeted implementation works.

## UX direction

### Menu bar actions
Recommended menu items:
- Pin Frontmost Window
- Unpin Frontmost Window
- Pinned Windows
- Set Level (1/2/3)
- Pause All Pins
- Unpin All
- Preferences
- Launch at Login
- Quit OnTop

### Shortcut behavior
Recommended behavior:
- One shortcut to pin/unpin the current frontmost window.
- Optional shortcuts for level assignment.
- All shortcuts should be user-customizable.
- Pick defaults that avoid common conflicts.
- a small sound to indicate we used it, or something visual or a small border around the app - which ever is optimal

### Preferences window
Keep this very small. Suggested settings:
- Toggle launch at login
- Edit shortcut(s)
- Toggle remember pinned windows across relaunch
- Maybe choose whether to show notifications/feedback

## Proposed behavior model

### Pinning model
When the user presses the pin shortcut:
1. Detect the current frontmost window.
2. If it is not pinned and pin capacity is below 3, pin it.
3. If it is already pinned, unpin it (or optionally keep pin/unpin as separate actions; Claude can decide the cleanest UX).
4. Assign a default level if needed.

### Layer/priority model
- Pinned windows should stay above normal windows.
- Among pinned windows, a higher level should stay above a lower level.
- If macOS imposes constraints, Claude should implement the most reliable approximation possible and document any limitations.

### Persistence model
- Remember pinned windows/settings only if feasible without heavy monitoring.
- If exact window restoration is fragile, store lightweight metadata and restore conservatively.
- If restore behavior is unreliable, it is acceptable to persist preferences but not auto-restore live window pins.

## Technical expectations for Claude Code

Claude should:
- Inspect the inspiration repo directly before implementation.
- Review the Swift/macOS project structure.
- Reuse ideas, not blindly copy architecture.
- Keep the codebase small and maintainable.
- Prefer native APIs and a straightforward design.
- Document any macOS API limitations around always-on-top behavior, fullscreen spaces, or inter-window ordering.

### Architecture suggestions
Possible high-level modules:
- `App/MenuBar` — status bar item, menu, preferences entry points
- `Permissions` — accessibility onboarding/checks
- `Hotkeys` — global shortcut registration and customization
- `WindowTracking` — frontmost window detection, tracked pinned windows, cleanup
- `PinningEngine` — apply/remove window levels and relative ordering
- `Persistence` — lightweight settings and optional restore metadata
- `PreferencesUI` — minimal settings window

Claude does not need to follow these names exactly.

## How the inspiration project currently presents itself

Based on the public repository page and README, the inspiration project currently describes itself roughly as:
- a lightweight macOS app,
- intended to keep a chosen window/app always visible,
- with menu bar integration,
- customizable shortcuts,
- launch-at-login support,
- accessibility permission requirements,
- theme/customization options,
- and persistence for last pinned app/window behavior.

The public README copy also appears somewhat rough and could be tightened for clarity, so Claude should inspect the actual code and not rely purely on the README wording.

## Inspiration repo structure

Claude should fetch this repo directly and verify everything before acting.

Public tree fetched from GitHub API at planning time:

- `.DS_Store`
- `.gitattributes`
- `.github`
- `.github/ISSUE_TEMPLATE`
- `.github/ISSUE_TEMPLATE/bug_report.md`
- `.github/ISSUE_TEMPLATE/feature_request.md`
- `AlwaysOnTop`
- `AlwaysOnTop.xcodeproj`
- `AlwaysOnTop.xcodeproj/project.pbxproj`
- `AlwaysOnTop.xcodeproj/project.xcworkspace`
- `AlwaysOnTop.xcodeproj/project.xcworkspace/contents.xcworkspacedata`
- `AlwaysOnTop.xcodeproj/project.xcworkspace/xcshareddata`
- `AlwaysOnTop.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist`
- `AlwaysOnTop.xcodeproj/project.xcworkspace/xcshareddata/swiftpm`
- `AlwaysOnTop.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- `AlwaysOnTop.xcodeproj/project.xcworkspace/xcuserdata`
- `AlwaysOnTop.xcodeproj/project.xcworkspace/xcuserdata/abhishekolkha.xcuserdatad`
- `AlwaysOnTop.xcodeproj/project.xcworkspace/xcuserdata/abhishekolkha.xcuserdatad/UserInterfaceState.xcuserstate`
- `AlwaysOnTop.xcodeproj/xcuserdata`
- `AlwaysOnTop.xcodeproj/xcuserdata/abhishekolkha.xcuserdatad`
- `AlwaysOnTop.xcodeproj/xcuserdata/abhishekolkha.xcuserdatad/xcschemes`
- `AlwaysOnTop.xcodeproj/xcuserdata/abhishekolkha.xcuserdatad/xcschemes/xcschememanagement.plist`
- `AlwaysOnTop/AlwaysOnTop.entitlements`
- `AlwaysOnTop/AlwaysOnTopApp.swift`
- `AlwaysOnTop/Assets.xcassets`
- `AlwaysOnTop/Assets.xcassets/AccentColor.colorset`
- `AlwaysOnTop/Assets.xcassets/AccentColor.colorset/Contents.json`
- `AlwaysOnTop/Assets.xcassets/AppIcon.appiconset`
- `AlwaysOnTop/Assets.xcassets/AppIcon.appiconset/1024-mac.png`
- `AlwaysOnTop/Assets.xcassets/AppIcon.appiconset/128-mac.png`
- `AlwaysOnTop/Assets.xcassets/AppIcon.appiconset/16-mac.png`
- `AlwaysOnTop/Assets.xcassets/AppIcon.appiconset/256-mac.png`
- `AlwaysOnTop/Assets.xcassets/AppIcon.appiconset/32-mac.png`
- `AlwaysOnTop/Assets.xcassets/AppIcon.appiconset/512-mac.png`
- `AlwaysOnTop/Assets.xcassets/AppIcon.appiconset/64-mac.png`
- `AlwaysOnTop/Assets.xcassets/AppIcon.appiconset/Contents.json`
- `AlwaysOnTop/Assets.xcassets/Contents.json`
- `AlwaysOnTop/Info.plist`
- `AlwaysOnTop/Preview Content`
- `AlwaysOnTop/Preview Content/Preview Assets.xcassets`
- `AlwaysOnTop/Preview Content/Preview Assets.xcassets/Contents.json`
- `AlwaysOnTopTests`
- `AlwaysOnTopTests/AlwaysOnTopTests.swift`
- `AlwaysOnTopUITests`
- `AlwaysOnTopUITests/AlwaysOnTopUITests.swift`
- `AlwaysOnTopUITests/AlwaysOnTopUITestsLaunchTests.swift`
- `LICENSE`
- `Main`
- `Main/SettingsView.swift`
- `Main/WindowManager.swift`
- `README.md`
- `Utils`
- `Utils/AppDelegate.swift`
- `Utils/Constants.swift`
- `Utils/ThemeManager.swift`

## README / positioning for OnTop

Recommended product positioning:
- “Keep your small utility windows visible while you work.”
- “Pin your frontmost macOS window above the rest.”
- “Built for AI chat + Terminal, reference windows, and floating video workflows.”
- “Fast, lightweight, and intentionally minimal.”
(these are ideas, but i would like to put somehting eye catching and maybe sarcastic idk - a good line)

### Suggested README sections
- What OnTop is
- Why it exists / workflows it helps
- Features
- Install
- Permissions
- Usage
- Shortcuts
- Performance philosophy
- Known limitations
- Inspiration acknowledgment (keep it very small minimal maybe just say inspired from {repo link})
- License

## Attribution / licensing guidance

Because the inspiration repo is MIT-licensed, Claude should be careful about attribution if any code is copied or adapted.

Recommended approach:
- Prefer a clean reimplementation.
- If any code or substantial portions are reused, preserve required license/copyright notices.
- Even if reimplemented from scratch, include a brief acknowledgment such as:
  - “Inspired by AlwaysOnTop by Abhishek Olkha.”

Claude should verify the exact license obligations directly from the source repo before finalizing.

## Known constraints / caution notes

- Some assumptions in this brief may be wrong or outdated.
- The source repository may change after this brief is written.
- macOS window behavior can vary by app and by fullscreen mode.
- Inter-window ordering among third-party app windows may have edge cases.
- Claude should verify current feasibility, limitations, and exact implementation details before coding.

## Expected deliverables from Claude Code

1. A new macOS app project named **OnTop**.
2. Menu bar only behavior (no Dock icon).
3. Frontmost-window pin/unpin flow.
4. Support for up to 3 pinned windows.
5. Level ordering between pinned windows.
6. Custom shortcuts.
7. Lightweight preferences window.
8. Launch-at-login support.
9. A clean README.
10. Notes about performance decisions and tradeoffs.
11. Short acknowledgment of inspiration.

## Suggested implementation priorities

### Phase 1
- Create menu bar app shell
- Add accessibility permission flow
- Detect frontmost window
- Pin/unpin one window reliably

### Phase 2
- Add support for up to 3 pinned windows
- Add level ordering
- Add pinned windows list in menu

### Phase 3
- Add custom shortcut management
- Add preferences window
- Add launch at login

### Phase 4
- Add lightweight persistence if it does not harm performance/stability
- Improve polish and edge-case handling
- Finalize README and acknowledgment

## Final instruction to Claude

Please fetch and inspect the inspiration repository directly before making assumptions:
- https://github.com/itsabhishekolkha/AlwaysOnTop

Use this brief as product direction, not as an exact technical spec. If any item here conflicts with reality, API limitations, or a cleaner implementation path, choose the simpler and more reliable approach and document the deviation.
