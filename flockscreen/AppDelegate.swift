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

    @IBAction func statusMenuActivate(_ sender: Any) {
        // Wait a second until activation to avoid immediate locking
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
            self.activateLock()
        })
    }

    @IBAction func statusMenuTrusted(_ sender: Any) {
        // TODO Directly open the security settings
        NSWorkspace.shared.launchApplication("System preferences")
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusItem.image = NSImage(named: NSImage.Name.lockUnlockedTemplate)
        statusItem.menu = statusMenu

        self.checkPrivileges()

        NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: { (event: NSEvent?) in
            self.takePictureAndLockScreen()
        })

        NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { (event: NSEvent?) in
            // TODO Make the deactivation key configurable!
            if (Int(event?.keyCode ?? 0) == 44) {
                // TODO Write deactivation events to log file
                self.deactivateLock()
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
        self.deactivateLock()
    }

    func checkPrivileges() {
        self.processTrusted = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        self.statusMenuTrusted.state = NSControl.StateValue(self.processTrusted ? 1 : 0)
    }

    func takePictureAndLockScreen() {
        if active {
            self.takePicture()
            self.lockScreen()
            self.deliverNotification()
        }
    }
    
    func deliverNotification() -> Void {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
            let notification = NSUserNotification()
            notification.title = "Screen Lock triggered!"
            notification.subtitle = "Captured image and saved it to pictures folder."
            notification.soundName = NSUserNotificationDefaultSoundName
            NSUserNotificationCenter.default.deliver(notification)
        })
    }

    func takePicture() {
        camera.captureStillImage()

        debugPrint("Took a picture")
    }

    func activateLock() {
        self.active = true
        self.statusItem.image = NSImage(named: NSImage.Name.lockLockedTemplate)
    }

    func deactivateLock() {
        self.active = false
        self.statusItem.image = NSImage(named: NSImage.Name.lockUnlockedTemplate)
    }

    func lockScreen() {
        System.lock()

        // Avoid immediate re-locking after unlocking the system lock.
        self.deactivateLock()

        debugPrint("Locked screen and deactivated locking")
    }
}

