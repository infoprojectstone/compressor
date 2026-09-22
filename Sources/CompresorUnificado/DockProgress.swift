import AppKit

enum DockProgress {
    static func update(_ value: Double) {
        DispatchQueue.main.async {
            let tile = NSApp.dockTile
            let view: DockTileProgressView
            if let existing = tile.contentView as? DockTileProgressView { view = existing }
            else { view = DockTileProgressView(frame: NSRect(x: 0, y: 0, width: 128, height: 128)); tile.contentView = view }
            view.progress = value
            tile.display()
        }
    }
    static func clear() {
        DispatchQueue.main.async { NSApp.dockTile.contentView = nil; NSApp.dockTile.display() }
    }
}

private final class DockTileProgressView: NSView {
    var progress: Double = 0 { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 8, dy: 8)
        NSApp.applicationIconImage.draw(in:r)
        NSColor.black.withAlphaComponent(0.35).setFill(); NSBezierPath(roundedRect:NSRect(x:20,y:14,width:88,height:12),xRadius:6,yRadius:6).fill()
        NSColor.white.setFill(); NSBezierPath(roundedRect:NSRect(x:22,y:16,width:max(8,84 * progress),height:8),xRadius:4,yRadius:4).fill()
    }
}
