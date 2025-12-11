import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    
    // Set default window size to 1200x800
    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
    let windowWidth: CGFloat = 1200
    let windowHeight: CGFloat = 800
    let windowX = (screenFrame.width - windowWidth) / 2 + screenFrame.origin.x
    let windowY = (screenFrame.height - windowHeight) / 2 + screenFrame.origin.y
    let windowFrame = NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight)
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
