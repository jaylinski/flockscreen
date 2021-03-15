import AVKit
import Cocoa
import IOKit
import UserNotifications

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var statusMenuActivate: NSMenuItem!
    @IBOutlet weak var statusMenuKeyboardTrigger: NSMenuItem!

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    private lazy var photoCapture = PhotoCaptureProcessor()

    private var lockActive: Bool = false
    private var lockTriggered: Bool = false
    private var lockDelay: Int = 1

    @IBAction func statusMenuActivate(_ sender: Any) {
        // Wait a second until activation to avoid immediate locking
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(self.lockDelay), execute: {
            self.activateLock()
        })
    }
    
    @IBAction func statusMenuAbout(_ sender: Any) {
        NSApp.orderFrontStandardAboutPanel(self)
    }

    @IBAction func statusMenuKeyboardTrigger(_ sender: Any) {
        let alert = NSAlert()
        alert.messageText = "How to enable the keyboard trigger" // TODO localize
        alert.informativeText = "Go to 'Privacy → Accessibility' and add 'flockscreen'." // TODO localize
        alert.runModal()
        
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane"))
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        self.checkPrivileges()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.image = NSImage(named: NSImage.lockUnlockedTemplateName)
        statusItem.menu = statusMenu

        NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: { (event: NSEvent?) in
            guard self.lockActive else { return }
            
            debugPrint("Trigger: mouse")
            self.takePictureAndLockScreen()
        })

        NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { (event: NSEvent?) in
            guard self.lockActive else { return }
            
            // TODO Make the deactivation key configurable!
            if Int(event?.keyCode ?? 0) == 44 { // Key 44: j
                // TODO Write deactivation events to log file
                return self.deactivateLock()
            }
            
            debugPrint("Trigger: keyboard")
            self.takePictureAndLockScreen()
        })

        // If the system locks itself, we can safely deactivate our fake lock
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(self.screenIsLocked(notification:)),
            name: Notification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        
        // If the system is unlocked, tell the user if the lock was triggered
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(self.screenIsUnlocked(notification:)),
            name: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // TODO Write termination to log file
    }

    func applicationWillResignActive(_ aNotification: Notification) {
        self.takePictureAndLockScreen()
    }

    @objc func screenIsLocked(notification: Notification) -> Void {
        self.deactivateLock()
    }
    
    @objc func screenIsUnlocked(notification: Notification) -> Void {
        guard self.lockTriggered else { return }
        
        self.lockTriggered = false
        self.deliverNotification()
    }

    func checkPrivileges() -> Void {
        let processTrusted: Bool = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        self.statusMenuKeyboardTrigger.state = NSControl.StateValue(processTrusted ? 1 : 0)
        debugPrint("AXIsProcessTrustedWithOptions: " + processTrusted.description)

        if AVCaptureDevice.authorizationStatus(for: .video) == AVAuthorizationStatus.notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                debugPrint("Granted access to video capture device")
            }
        }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { (granted, error) in
            if let error = error {
                debugPrint("Grant for notification center failed: " + error.localizedDescription)
            }
            
            if granted {
                debugPrint("Granted access to notification center")
            } else {
                debugPrint("Grant for notification center not given")
            }
        }
    }

    func takePictureAndLockScreen() -> Void {
        guard self.lockActive else { return }

        self.lockTriggered = true
        self.lockScreen()
        self.takePicture()
    }
    
    func deliverNotification() -> Void {
        let content = UNMutableNotificationContent()
        content.title = NSString.localizedUserNotificationString(forKey: "Lock was triggered!", arguments: nil)
        content.body = NSString.localizedUserNotificationString(forKey: "Captured image and saved it to pictures folder.", arguments: nil)
        content.sound = UNNotificationSound.default
        // TODO Add "Open" action which opens the captured image
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request, withCompletionHandler: { (error) in
            if let error = error {
                debugPrint("Sending notification failed: " + error.localizedDescription)
            }
            debugPrint("Sent notification")
        })
    }

    func takePicture() -> Void {
        photoCapture.captureStillImage()

        debugPrint("Took a picture")
    }

    func activateLock() -> Void {
        guard !self.lockActive else { return }
        
        debugPrint("Lock activated")
        
        self.lockActive = true
        self.statusItem.button?.image = NSImage(named: NSImage.lockLockedTemplateName)
    }

    func deactivateLock() -> Void {
        guard self.lockActive else { return }
        
        debugPrint("Lock deactivated")
        
        self.lockActive = false
        self.statusItem.button?.image = NSImage(named: NSImage.lockUnlockedTemplateName)
    }

    func lockScreen() -> Void {
        System.lock()
        
        debugPrint("Locked screen")

        // Avoid immediate re-locking after unlocking the system lock.
        self.deactivateLock()
    }
}

