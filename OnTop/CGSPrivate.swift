// CGSPrivate.swift
// Private AX bridge function for getting a CGWindowID from an AXUIElement.
//
// _AXUIElementGetWindow is the only reliable way to map from the Accessibility
// world (AXUIElement) to the CoreGraphics world (CGWindowID).
//
// NOTE: CGSSetWindowLevel was attempted and confirmed non-functional for
// cross-process windows. It returns 0 (success) but inspection via
// CGWindowListCopyWindowInfo shows layerBefore=0 and layerAfter=0 —
// the WindowServer silently ignores the call for windows it doesn't own.
// Removed CGSSetWindowLevel and CGSMainConnectionID accordingly.

import ApplicationServices

/// Extracts the native CGWindowID from an AXUIElement window reference.
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(
    _ element: AXUIElement,
    _ outWindowID: UnsafeMutablePointer<CGWindowID>
) -> AXError
