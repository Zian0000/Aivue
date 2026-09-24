import AppKit

/// MenuBarExtra may reinterpret the layout of a multi-view label as an icon.
/// Draw the complete, bounded status item as one image so its intrinsic size is stable.
@MainActor enum MenuBarArtwork {
    static func render(
        chatGPT: Int?, showChatGPT: Bool,
        claude: Int?, showClaude: Bool,
        isOffline: Bool, compact: Bool = false
    ) -> NSImage {
        let font = NSFont(name: "Inter-Bold", size: 12) ?? .systemFont(ofSize: 12, weight: .bold)
        let foreground = NSColor(srgbRed: 243 / 255, green: 244 / 255, blue: 246 / 255, alpha: 1)
        let warning = NSColor(srgbRed: 255 / 255, green: 159 / 255, blue: 67 / 255, alpha: 1)
        let background = NSColor(srgbRed: 36 / 255, green: 40 / 255, blue: 49 / 255, alpha: 0.2)
        let height: CGFloat = 22 // The real macOS menu bar is shorter than Figma's 29 pt mockup.
        let iconSize: CGFloat = 15
        let gap: CGFloat = 8

        func label(_ value: String, color: NSColor = foreground) -> NSAttributedString {
            NSAttributedString(string: value, attributes: [.font: font, .foregroundColor: color])
        }

        var parts: [(NSImage?, NSAttributedString)] = []
        if showChatGPT && !compact {
            parts.append((isOffline ? UsageLogos.menuBarChatGPTOffline : UsageLogos.menuBarChatGPT,
                          label(chatGPT.map { "\($0)%" } ?? "--%", color: isOffline ? warning.withAlphaComponent(0.3) : foreground)))
        }
        if showClaude && !compact {
            parts.append((isOffline ? UsageLogos.menuBarClaudeOffline : UsageLogos.menuBarClaude,
                          label(claude.map { "\($0)%" } ?? "--%", color: isOffline ? warning.withAlphaComponent(0.3) : foreground)))
        }

        let leadingWidth: CGFloat = 15
        let partsWidth = parts.reduce(CGFloat.zero) { total, part in
            total + gap + iconSize + 4 + ceil(part.1.size().width)
        }
        let width = 7 + leadingWidth + partsWidth + 7
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { bounds in
            if !compact {
                background.setFill()
                NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7).fill()
            }

            var x: CGFloat = 7
            let leading = isOffline ? UsageLogos.menuBarOffline : UsageLogos.menuBarAivue
            leading?.draw(in: NSRect(x: x, y: (height - 12.674) / 2, width: 15, height: 12.674),
                          from: .zero, operation: .sourceOver, fraction: 1)
            x += leadingWidth
            for (logo, percentage) in parts {
                x += gap
                logo?.draw(in: NSRect(x: x, y: (height - iconSize) / 2, width: iconSize, height: iconSize),
                           from: .zero, operation: .sourceOver, fraction: isOffline ? 0.3 : 1)
                x += iconSize + 4
                percentage.draw(at: NSPoint(x: x, y: (height - percentage.size().height) / 2))
                x += ceil(percentage.size().width)
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}
