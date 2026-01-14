import AppKit

enum IconRenderer {
    /// Normal state: three concentric circles
    static func makeNormalIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let center = CGPoint(x: 9, y: 9)

        // Outer circle: r=7, stroke-width=1.5, opacity=0.4
        let outerPath = NSBezierPath()
        outerPath.appendArc(withCenter: center, radius: 7, startAngle: 0, endAngle: 360)
        NSColor.labelColor.withAlphaComponent(0.4).setStroke()
        outerPath.lineWidth = 1.5
        outerPath.stroke()

        // Middle circle: r=4, stroke-width=1.5, opacity=0.7
        let middlePath = NSBezierPath()
        middlePath.appendArc(withCenter: center, radius: 4, startAngle: 0, endAngle: 360)
        NSColor.labelColor.withAlphaComponent(0.7).setStroke()
        middlePath.lineWidth = 1.5
        middlePath.stroke()

        // Inner filled circle: r=1.5
        let innerPath = NSBezierPath()
        innerPath.appendArc(withCenter: center, radius: 1.5, startAngle: 0, endAngle: 360)
        NSColor.labelColor.setFill()
        innerPath.fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    /// Asking permission state: pulsing green circle animation
    /// - Parameter phase: Animation phase from 0 to 1 (controls pulse radius)
    static func makeAlertIcon(phase: Double = 0) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let center = CGPoint(x: 9, y: 9)

        // Outer circle: r=7, stroke-width=1.5, opacity=0.4
        let outerPath = NSBezierPath()
        outerPath.appendArc(withCenter: center, radius: 7, startAngle: 0, endAngle: 360)
        NSColor.labelColor.withAlphaComponent(0.4).setStroke()
        outerPath.lineWidth = 1.5
        outerPath.stroke()

        // Middle circle: r=4, stroke-width=1.5, opacity=0.7
        let middlePath = NSBezierPath()
        middlePath.appendArc(withCenter: center, radius: 4, startAngle: 0, endAngle: 360)
        NSColor.labelColor.withAlphaComponent(0.7).setStroke()
        middlePath.lineWidth = 1.5
        middlePath.stroke()

        // Animated green pulse circle
        // Phase 0-0.4: r grows from 2 to 7
        // Phase 0.4-0.7: r stays at 7
        // Phase 0.7-1.0: r shrinks from 7 to 2
        let pulseRadius: CGFloat
        let pulseOpacity: CGFloat

        if phase < 0.4 {
            let t = phase / 0.4
            pulseRadius = 2 + (7 - 2) * CGFloat(t)
            pulseOpacity = 0.9 - 0.2 * CGFloat(t)
        } else if phase < 0.7 {
            pulseRadius = 7
            pulseOpacity = 0.7
        } else {
            let t = (phase - 0.7) / 0.3
            pulseRadius = 7 - (7 - 2) * CGFloat(t)
            pulseOpacity = 0.7 + 0.2 * CGFloat(t)
        }

        let pulsePath = NSBezierPath()
        pulsePath.appendArc(withCenter: center, radius: pulseRadius, startAngle: 0, endAngle: 360)
        // Green color: #10B981 (Tailwind emerald-500)
        NSColor(red: 0x10/255.0, green: 0xB9/255.0, blue: 0x81/255.0, alpha: pulseOpacity).setFill()
        pulsePath.fill()

        image.unlockFocus()
        // Don't use template mode for colored icon
        image.isTemplate = false
        return image
    }
}
