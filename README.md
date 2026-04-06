# OnTop

> A macOS menu bar utility that keeps any window floating above everything else.
> Born out of frustration. Kept alive by curiosity about what Apple lets you do — and what it doesn't.

---

## What it does

Pin up to 3 windows to always float above every other app on your screen. Works on every Space, through full-screen apps, across dual monitors. Click through it normally — the original window handles all input. Three priority levels let you stack pinned windows above each other.

**Shortcut:** `⌃⌥P` to pin/unpin the frontmost window (customizable in Preferences).

---

## Installation

> Requires macOS 13.0+ and Xcode 15+.

```bash
git clone https://github.com/your-username/OnTop.git
cd OnTop
./setup.sh          # installs XcodeGen, generates .xcodeproj, opens Xcode
```

Hit **⌘R** in Xcode. Grant Accessibility access when prompted. Grant Screen Recording on the first pin.

No App Store. No notarization. Just build it yourself.

---

## The journey (or: what Apple actually lets you do)

This app started as a reimplementation of [AlwaysOnTop](https://github.com/itsabhishekolkha/AlwaysOnTop) with cleaner architecture. That project uses AppleScript to `activate` the target app every second — which works but steals focus constantly. Surely there's a better way.

Spoiler: there is. But finding it took three completely different approaches.

### Attempt 1: `CGSSetWindowLevel` — the dream

macOS has a private CoreGraphics API called `CGSSetWindowLevel`. You give it a window ID and a level, and theoretically the window moves to that layer in the global window stack. `kCGFloatingWindowLevel` (3) puts things above all normal apps. This felt like exactly the right tool.

```swift
@_silgen_name("CGSSetWindowLevel")
func CGSSetWindowLevel(_ connection: Int32, _ windowID: CGWindowID, _ level: Int32) -> Int32

let result = CGSSetWindowLevel(CGSMainConnectionID(), windowID, Int32(kCGFloatingWindowLevel))
// result = 0. Success! ...right?
```

The call returned `0` every time. No error. We log the before/after window level via `CGWindowListCopyWindowInfo`:

```
layerBefore=0  layerAfter=0
```

**Both zero.** The WindowServer accepted the call politely and did absolutely nothing. It turns out `CGSSetWindowLevel` validates that your CG connection owns the target window — and if it doesn't, it silently succeeds but ignores the request. Apple's sandboxing at the compositor level. Not documented anywhere.

### Attempt 2: `kAXRaiseAction` — the workaround

The Accessibility framework has a higher trust level with the WindowServer (hence why Accessibility permission exists at all). `AXUIElementPerformAction(window, kAXRaiseAction)` brings a foreign window to the global Z-front. No ownership check. This actually worked.

The strategy: listen for `NSWorkspace.didActivateApplicationNotification` and re-raise all pinned windows every time the user switches apps.

```swift
func reapplyAll() {
    for w in sorted(pinned, by: level) {
        AXUIElementPerformAction(w.axElement, kAXRaiseAction as CFString)
    }
}
```

Cross-screen: perfect. Pin a Terminal on your external monitor — it stayed above Xcode on the MacBook screen every time.

Same screen: broken. When you click into a different app on the same display, `didActivateApplicationNotification` fires — but the OS finishes bringing that app's windows to front *after* our notification handler returns. We raise the pinned window, then macOS raises the newly active app on top of it. We lose the race every time.

A delayed second raise (`DispatchQueue.main.asyncAfter(deadline: .now() + 0.12)`) helped slightly but felt like duct tape. The fundamental problem: we're fighting the window server on its own turf.

### Attempt 3: Own the window — `NSWindow` overlay

Here's the realization that changed everything: **we can't permanently change another process's window level. But we can create our own `NSWindow` at any level we want, because *we* own it.**

For each pinned window, we create a companion `OverlayWindow` — a borderless, click-through `NSWindow` at `kCGFloatingWindowLevel`. Our process owns it. The OS will never override its level based on what the user clicks on. It's permanently floating.

The overlay shows a live capture of the original window via `CGWindowListCreateImageFromArray`, refreshed at 10fps. This API captures the window's backing buffer directly — it works even when the original window is behind other apps, because macOS maintains each window's offscreen buffer regardless of visibility.

```swift
// Our window. Our rules.
let overlay = OverlayWindow(windowID: pinnedID, level: .floating)

// Captures the original window's pixels from its backing buffer.
// Works even when the original is completely hidden behind other apps.
let cgImage = CGWindowListCreateImageFromArray(.null, [windowID], .bestResolution)
```

Click-through is one flag:
```swift
overlay.ignoresMouseEvents = true
```

Show on every Space and through full-screen apps:
```swift
overlay.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
```

**It just works.** Same screen, cross-screen, Mission Control, full-screen apps. No races. No polling for "am I still on top". Zero focus stealing. The level is set once and never touched again.

### Comparison

| | AlwaysOnTop | OnTop v1 (kAXRaise) | OnTop v2 (Overlay) |
|---|---|---|---|
| Mechanism | AppleScript `activate` | `kAXRaiseAction` | Own `NSWindow` at floating level |
| Same-screen reliable | ✗ (race) | ✗ (race) | ✓ (permanent) |
| Focus stealing | Yes | No | No |
| Click-through | No | No | Yes |
| CPU per pinned window | High (AppleScript IPC) | Low (event-driven) | ~0.3% (10fps GPU blit) |
| Requires Screen Recording | No | No | Yes |

The Screen Recording permission is the trade-off. `CGWindowListCreateImageFromArray` requires it on macOS 14+. You're granting access to capture any window's pixels. We only use it for the pinned window, but the permission is broad. That's an Apple decision, not ours.

---

## Why Apple doesn't give us a proper API for this

Every major OS has a "window always on top" concept. Windows has `HWND_TOPMOST`. Linux window managers have `_NET_WM_STATE_ABOVE`. macOS has... nothing. No public API to elevate a window you don't own.

The closest thing is `NSWindow.level`, but that only works for windows your process owns. For foreign windows, you get `CGSSetWindowLevel` (broken, as we learned) or `kAXRaiseAction` (stateless, lossy). Neither is a proper solution.

The charitable interpretation: macOS prioritizes user intent over developer intent. If the user clicks on Xcode, they want Xcode in front. An app silently overriding that is a UX anti-pattern.

The less charitable interpretation: Apple wants you in the App Store, where "always on top" would fail app review anyway.

We found the only real solution: don't touch the other app's window. Make a new window that looks like it and put that on top instead. The whole approach is a workaround for a missing API, implemented with two APIs (AX + Screen Capture) that were designed for completely different things.

Classic macOS.

---

## Features

- **Pin / Unpin** the frontmost window with `⌃⌥P` or from the menu bar
- **3 priority levels** — pin multiple windows and control their stacking order
- **Pause / Resume** — temporarily hide all overlays without unpinning
- **Launch at Login** — via `SMAppService`, the modern macOS 13+ native approach
- **Click-through overlays** — the original window receives all mouse events
- **Multi-Space / Full-screen** — overlays follow via `canJoinAllSpaces`
- **Auto-cleanup** — detects closed/quit windows via a 3s sweep timer

---

## Architecture

```
OnTopApp.swift              @main entry, delegates to AppDelegate
AppDelegate.swift           Startup, permission gates, preferences window
MenuBarController.swift     NSStatusItem, NSMenu (rebuilt on open), all user actions
WindowTracker.swift         AX frontmost-window detection + closed-window cleanup
OverlayWindowManager.swift  10fps capture timer, OverlayWindow lifecycle
OverlayWindow.swift         Borderless click-through NSWindow at floating level
PinnedWindowsStore.swift    Source of truth: max-3 pinned windows, PinLevel enum
PermissionsManager.swift    Accessibility + Screen Recording prompts
ShortcutManager.swift       KeyboardShortcuts global hotkey (⌃⌥P default)
LoginItemManager.swift      SMAppService launch-at-login
CGSPrivate.swift            _AXUIElementGetWindow (AX→CG bridge, private API)
```

---

## Requirements

- macOS 13.0+
- Accessibility permission (to detect the frontmost window)
- Screen Recording permission (to capture window pixels for the overlay)
- Not sandboxed (App Store distribution not intended)

---

## Credits

Inspired by [AlwaysOnTop](https://github.com/itsabhishekolkha/AlwaysOnTop) by @itsabhishekolkha.
Built with [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by @sindresorhus.
Built using Claude Code (Anthropic) — because vibe coding is a legitimate engineering strategy.

---

*If Apple ever adds a public `NSWindow.pinAboveAll()` API, this entire project becomes one line of code. Until then, here we are.*
