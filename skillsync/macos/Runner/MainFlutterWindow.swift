import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Set initial window size
    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
    let windowWidth: CGFloat = 1200
    let windowHeight: CGFloat = 750
    let windowX = (screenFrame.width - windowWidth) / 2 + screenFrame.origin.x
    let windowY = (screenFrame.height - windowHeight) / 2 + screenFrame.origin.y
    self.setFrame(NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight), display: true)

    // Set minimum size
    self.minSize = NSSize(width: 900, height: 600)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
