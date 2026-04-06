// CGSPrivate.swift
// Private AX bridge function for getting a CGWindowID from an AXUIElement.
//
// _AXUIElementGetWindow is the only reliable way to map from the Accessibility
// world (AXUIElement) to the CoreGraphics world (CGWindowID).

import ApplicationServices

/// Extracts the native CGWindowID from an AXUIElement window reference.
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(
    _ element: AXUIElement,
    _ outWindowID: UnsafeMutablePointer<CGWindowID>
) -> AXError
