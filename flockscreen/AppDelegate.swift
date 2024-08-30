import AVKit
import Cocoa
import IOKit
import os
import UserNotifications

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate {
    
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var statusMenuActivate: NSMenuItem!
    @IBOutlet weak var statusMenuKeyboardTrigger: NSMenuItem!
    @IBOutlet weak var statusMenuVideoCapture: NSMenuItem!
    @IBOutlet weak var statusMenuNotificationAlertStyle: NSMenuItem!
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let lockTriggerNotificationCategory = "LOCK_TRIGGERED"
    let lockTriggerNotificationAction = "OPEN_CAPTURED_PHOTO"
    let lockTriggerNotificationUserInfoKey = "PHOTO_URL"
    
    private lazy var photoCapture = PhotoCaptureProcessor()
    private let logger = Logger()
    
    private var lockActive: Bool = false
    private var lockTriggered: Bool = false
    private var lockDelay: Int = 1
    
    @IBAction func statusMenuActivate(_ sender: Any) {
        // Wait a second until activation to avoid immediate locking
        // TODO Make delay configurable
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(self.lockDelay), execute: {
            self.activateLock()
        })
    }
    
    @IBAction func statusMenuAbout(_ sender: Any) {
        // TODO Localize
        NSApp.orderFrontStandardAboutPanel(self)
    }
    
    @IBAction func statusMenuKeyboardTrigger(_ sender: Any) {
        let alert = NSAlert()
        alert.messageText = String(localized: "How to enable the keyboard trigger")
        alert.informativeText = String(localized: "In system settings, go to 'Privacy & Security → Accessibility' and add 'flockscreen'.")
        alert.runModal()
        
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane"))
    }
    
    @IBAction func statusMenuVideoCaptureTrigger(_ sender: Any) {
        // Once the user denied the camera permission, we can't prompt the user again, so just show an info-box
        let alert = NSAlert()
        alert.messageText = String(localized: "How to grant access to the camera")
        alert.informativeText = String(localized: "In system settings, go to 'Privacy & Security → Camera' and allow 'flockscreen'.")
        alert.runModal()
        
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane"))
    }
    
    @IBAction func statusMenuNotificationAlertStyleTrigger(_ sender: Any) {
        // macOS doesn't allow us to send persistent notifications, the user has to activate it
        let alert = NSAlert()
        alert.messageText = String(localized: "How to enable notification alerts")
        alert.informativeText = String(localized: "In system settings, go to 'Notifications → flockscreen' and set notifications to 'Alerts'.")
        alert.runModal()
        
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Notifications.prefPane"))
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        self.checkPrivileges()
        self.registerNotificationAction()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.image = NSImage(named: NSImage.lockUnlockedTemplateName)
        statusItem.menu = statusMenu
        statusMenu.delegate = self
        
        NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: { (event: NSEvent?) in
            guard self.lockActive else { return }
            
            debugPrint("Trigger: mouse")
            self.takePictureAndLockScreen()
        })
        
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { (event: NSEvent?) in
            guard self.lockActive else { return }
            
            // TODO Make the deactivation key configurable!
            if Int(event?.keyCode ?? 0) == 44 { // Key 44: j
                self.logger.notice("Lock manually defused")
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
    
    func menuWillOpen(_ menu: NSMenu) {
        // Check notification settings
        UNUserNotificationCenter.current().getNotificationSettings() { settings in
            let alertEnabled = settings.alertStyle == UNAlertStyle.alert
            self.statusMenuNotificationAlertStyle.state = NSControl.StateValue(alertEnabled ? 1 : 0)
            self.statusMenuNotificationAlertStyle.isEnabled = !alertEnabled
        }
        
        // Check camera permissions
        let avCaptureDeviceAuthorization = AVCaptureDevice.authorizationStatus(for: .video)
        let avCaptureDeviceAuthorized = avCaptureDeviceAuthorization == AVAuthorizationStatus.authorized
        self.statusMenuVideoCapture.state = NSControl.StateValue(avCaptureDeviceAuthorized ? 1 : 0)
        self.statusMenuVideoCapture.isEnabled = !avCaptureDeviceAuthorized
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        self.logger.notice("Terminated")
    }
    
    func applicationWillResignActive(_ aNotification: Notification) {
        self.takePictureAndLockScreen()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        if response.actionIdentifier == self.lockTriggerNotificationAction {
            let photoUrl = URL(string: userInfo[self.lockTriggerNotificationUserInfoKey] as! String)
            
            guard let unwrappedPhotoUrl = photoUrl else {
                debugPrint("Invalid photo URL")
                completionHandler()
                return
            }
            
            NSWorkspace.shared.open(unwrappedPhotoUrl)
        }
        
        completionHandler()
    }
    
    // This makes the notification stick until it is dismissed (alert)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.list, .banner])
    }
    
    @objc func screenIsLocked(notification: Notification) -> Void {
        self.deactivateLock()
    }
    
    @objc func screenIsUnlocked(notification: Notification) -> Void {
        guard self.lockTriggered else { return }
        
        self.lockTriggered = false
    }
    
    func checkPrivileges() -> Void {
        let processTrusted: Bool = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        self.statusMenuKeyboardTrigger.state = NSControl.StateValue(processTrusted ? 1 : 0)
        self.statusMenuKeyboardTrigger.isEnabled = !processTrusted
        debugPrint("AXIsProcessTrustedWithOptions: " + processTrusted.description)
        
        let avCaptureDeviceAuthorization = AVCaptureDevice.authorizationStatus(for: .video)
        let avCaptureDeviceAuthorized = avCaptureDeviceAuthorization == AVAuthorizationStatus.authorized
        debugPrint("AVAuthorizationStatus: " + avCaptureDeviceAuthorized.description)
        
        if avCaptureDeviceAuthorization == AVAuthorizationStatus.notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                self.statusMenuVideoCapture.state = NSControl.StateValue(granted ? 1 : 0)
                self.statusMenuVideoCapture.isEnabled = !granted
                if granted {
                    debugPrint("Granted access to AV capture device")
                } else {
                    debugPrint("Denied access to AV capture device")
                }
            }
        }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { (granted, error) in
            if let error = error {
                debugPrint("Grant for notification center failed: " + error.localizedDescription)
            }
            
            if granted {
                debugPrint("Granted access to notification center")
            } else {
                debugPrint("Denied access to notification center")
            }
        }
    }
    
    func registerNotificationAction() -> Void {
        let openImageAction = UNNotificationAction(identifier: self.lockTriggerNotificationAction, title: String("Open photo"), options: [])
        let lockTriggerCategory =
        UNNotificationCategory(identifier: self.lockTriggerNotificationCategory,
                               actions: [openImageAction],
                               intentIdentifiers: [],
                               hiddenPreviewsBodyPlaceholder: "",
                               options: .customDismissAction)
        
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self
        notificationCenter.setNotificationCategories([lockTriggerCategory])
    }
    
    func takePictureAndLockScreen() -> Void {
        guard self.lockActive else { return }
        
        self.lockTriggered = true
        self.lockScreen()
        self.takePicture()
    }
    
    func deliverNotification(photoUrl: URL) -> Void {
        let content = UNMutableNotificationContent()
        content.title = NSString.localizedUserNotificationString(forKey: String(localized: "Lock was triggered!"), arguments: nil)
        content.body = NSString.localizedUserNotificationString(forKey: String(localized: "Captured photo and saved it to pictures folder."), arguments: nil)
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = self.lockTriggerNotificationCategory
        content.userInfo = [self.lockTriggerNotificationUserInfoKey: photoUrl.absoluteString]
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request, withCompletionHandler: { (error) in
            if let error = error {
                debugPrint("Sending notification failed: " + error.localizedDescription)
            }
            debugPrint("Sent notification")
        })
    }
    
    func takePicture() -> Void {
        photoCapture.captureStillImage { url in
            self.deliverNotification(photoUrl: url)
        }
        
        debugPrint("Tried to take a picture")
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

