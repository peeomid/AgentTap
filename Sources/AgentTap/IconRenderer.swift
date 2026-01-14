import AppKit

enum IconRenderer {
    static func makeNormalIcon() -> NSImage {
        makeSymbol(name: "eye") ?? fallbackCircle()
    }

    static func makeAlertIcon(phase: Double = 0) -> NSImage {
        makeSymbol(name: "eye.trianglebadge.exclamationmark") ?? makeSymbol(name: "exclamationmark.circle") ?? fallbackCircle()
    }

    private static func makeSymbol(name: String) -> NSImage? {
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return nil }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }

    private static func fallbackCircle() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(ovalIn: rect.insetBy(dx: 3, dy: 3))
        NSColor.labelColor.setStroke()
        path.lineWidth = 2
        path.stroke()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
