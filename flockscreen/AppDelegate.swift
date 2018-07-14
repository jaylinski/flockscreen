import Cocoa
import IOKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var statusMenuActivate: NSMenuItem!
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    private lazy var camera = Camera()

    private var active = false
    
    @IBAction func statusMenuActivate(sender: NSMenuItem) {
        // Wait a second until activation to avoid immediate locking
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
            self.active = true
        })
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        statusItem.title = "flockscreen"
        statusItem.menu = statusMenu
        
        NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: { (event: NSEvent?) in
            self.takePictureAndLockScreen()
        })
        
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(self.screenIsLocked(notification:)),
            name: Notification.Name("com.apple.screenIsLocked"),
            object: nil)
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { (event: NSEvent?) -> NSEvent? in
            // TODO Make the deactivation key configurable!
            if (Int(event?.keyCode ?? 0) == 999) {
                // TODO Write deactivation events to log file
                self.active = false
            }
            
            return event
        })
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

