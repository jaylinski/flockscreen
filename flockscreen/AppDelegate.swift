import Cocoa
import IOKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var statusMenuActivate: NSMenuItem!
    @IBOutlet weak var statusMenuTrusted: NSMenuItem!
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    private lazy var camera = Camera()

    private var active = false
    private var processTrusted = false
    
    @IBAction func statusMenuActivate(sender: NSMenuItem) {
        // Wait a second until activation to avoid immediate locking
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
            self.active = true
        })
    }
    
    @IBAction func statusMenuTrusted(_ sender: Any) {
        // TODO Directly open the security settings
        NSWorkspace.shared.launchApplication("System preferences")
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusItem.title = "flockscreen"
        statusItem.menu = statusMenu
        
        self.checkPrivileges()
        
        NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: { (event: NSEvent?) in
            self.takePictureAndLockScreen()
        })
        
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { (event: NSEvent?) in
            // TODO Make the deactivation key configurable!
            if (Int(event?.keyCode ?? 0) == 44) {
                // TODO Write deactivation events to log file
                self.active = false
            }

            self.takePictureAndLockScreen()
        })
        
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(self.screenIsLocked(notification:)),
            name: Notification.Name("com.apple.screenIsLocked"),
            object: nil)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // TODO Write termination to log file
    }
    
    func applicationWillResignActive(_ aNotification: Notification) {
        self.takePictureAndLockScreen()
    }
    
    @objc func screenIsLocked(notification: Notification) {
        self.active = false
    }
    
    func checkPrivileges() {
        self.processTrusted = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        self.statusMenuTrusted.state = NSControl.StateValue(self.processTrusted ? 1 : 0)
    }
    
    func takePictureAndLockScreen() {
        if active {
            self.takePicture()
            self.lockScreen()
        }
    }
    
    func takePicture() {
        camera.captureStillImage()
        
        debugPrint("Took a picture")
    }

    func lockScreen() {
        System.lock()
        self.active = false
        
        debugPrint("Locked screen and deactivated locking")
    }
}

