import AVFoundation

struct System {
    static func lock() {
        let libHandle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY)
        let sym = dlsym(libHandle, "SACLockScreenImmediate")
        typealias myFunction = @convention(c) () -> Void
        let SACLockScreenImmediate = unsafeBitCast(sym, to: myFunction.self)
        SACLockScreenImmediate()
    }
}

class Camera {
    let captureSession = AVCaptureSession()
    let captureImageOutput = AVCaptureStillImageOutput()
    var captureDevice : AVCaptureDevice?
    let picturesDirectory = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
    let stillImageOutput = AVCaptureStillImageOutput()
    
    func captureStillImage() {
        let devices = AVCaptureDevice.devices()
        
        // Find the FaceTime HD camera object
        for device in devices {
            if ((device as AnyObject).hasMediaType(AVMediaType.video)) {
                captureDevice = device
            }
        }
        
        if captureDevice != nil {
            do {
                try captureSession.addInput(AVCaptureDeviceInput(device: captureDevice!))
                captureSession.sessionPreset = AVCaptureSession.Preset.photo
                captureSession.startRunning()
                
                self.stillImageOutput.outputSettings = [AVVideoCodecKey:AVVideoCodecType.jpeg]
                if self.captureSession.canAddOutput(self.stillImageOutput) {
                    self.captureSession.addOutput(self.stillImageOutput)
                }
                if let videoConnection = self.stillImageOutput.connection(with: AVMediaType.video) {
                    // Give camera some time to adjust to light conditions
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2), execute: {
                        self.stillImageOutput.captureStillImageAsynchronously(from: videoConnection) {
                            (imageDataSampleBuffer, error) -> Void in
                            let time = NSDate().timeIntervalSince1970
                            let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer!)
                            let imageUrl = self.picturesDirectory.appendingPathComponent("flockscreen.\(time).jpg", isDirectory: false)
                            try? imageData?.write(to: imageUrl)
                            DispatchQueue.main.async() {
                                self.captureSession.stopRunning()
                            }
                        }
                    })
                }
            } catch {
                print(AVCaptureSessionErrorKey.description)
            }
        }
    }
}
