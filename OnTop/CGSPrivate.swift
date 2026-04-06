// CGSPrivate.swift
// Private CG + AX bridge functions for "always on top".
//
// _AXUIElementGetWindow bridges AXUIElement → CGWindowID.
// CGSSetWindowLevel sets a window's CG level by its windowID.
// CGSMainConnectionID returns the calling process's CG connection handle.
//
// Hypothesis: CGSSetWindowLevel works cross-process — it's a WindowServer call,
// not scoped to the owner process. We're calling it with our own connection ID
// but targeting a foreign window. Let's find out.

import ApplicationServices

/// Extracts the native CGWindowID from an AXUIElement window reference.
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(
    _ element: AXUIElement,
    _ outWindowID: UnsafeMutablePointer<CGWindowID>
) -> AXError

/// Set the CGWindowLevel for any window, identified by its CGWindowID.
/// Returns 0 on success, non-zero on failure.
@_silgen_name("CGSSetWindowLevel")
func CGSSetWindowLevel(_ connection: Int32, _ windowID: CGWindowID, _ level: Int32) -> Int32

/// Returns the CoreGraphics connection ID for the calling process.
@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> Int32
