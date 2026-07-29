import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Open the macOS app at the approved 1030 x 1200 content size. AppKit
    // persists any size/position changes the user makes afterwards.
    let frameAutosaveName = "KapiNoteMainWindowV4"
    let restoredSavedFrame = self.setFrameUsingName(frameAutosaveName)

    if !restoredSavedFrame {
      let contentSize = NSSize(width: 1030, height: 1200)
      let windowFrame = self.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize))
      self.setFrame(NSRect(origin: self.frame.origin, size: windowFrame.size), display: true)
      self.center()
    }

    self.setFrameAutosaveName(frameAutosaveName)

    if let visibleFrame = NSScreen.main?.visibleFrame {
      self.contentMinSize = NSSize(
        width: min(800, visibleFrame.width - 48),
        height: min(680, visibleFrame.height - 32)
      )
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
