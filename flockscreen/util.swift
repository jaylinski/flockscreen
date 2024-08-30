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

class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    var captureSession: AVCaptureSession?
    var photoPath: URL?
    let photoCaptureDelay: DispatchTimeInterval = .milliseconds(500)
    let picturesDirectory = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
    
    func captureStillImage(completion: @escaping ((URL) -> Void)) {
        self.captureSession = AVCaptureSession()
        let captureDevice = AVCaptureDevice.default(for: AVMediaType.video)
        let photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        let photoOutput = AVCapturePhotoOutput()
        
        guard let photoSession = self.captureSession else {
            debugPrint("Invalid capture session")
            return
        }
        
        guard let captureDevice = captureDevice else {
            debugPrint("Couldn't find a capture device")
            return
        }
        
        guard AVCaptureDevice.authorizationStatus(for: .video) == AVAuthorizationStatus.authorized else {
            debugPrint("Access to video capture device not granted")
            return
        }
        
        guard photoSession.canAddOutput(photoOutput) else {
            debugPrint("Can't add output to capture session")
            return
        }
        
        photoSession.sessionPreset = AVCaptureSession.Preset.photo
        photoSession.addOutput(photoOutput)
        photoSession.commitConfiguration()
        
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
            
            if photoSession.canAddInput(captureDeviceInput) {
                photoSession.addInput(captureDeviceInput)
            } else {
                debugPrint("Can't add input to capture session")
                return
            }
            
            // The startRunning() method is a blocking call which can take some time, therefore start the session
            // on a serial dispatch queue so that we don’t block the main queue (which keeps the UI responsive).
            DispatchQueue.main.async(execute: {
                photoSession.startRunning()
                
                // Wait for the camera to adjust the exposure
                DispatchQueue.main.asyncAfter(deadline: .now() + self.photoCaptureDelay, execute: {
                    let time = NSDate().timeIntervalSince1970
                    self.photoPath = self.picturesDirectory.appendingPathComponent("flockscreen.\(time).jpg", isDirectory: false)
                    photoOutput.capturePhoto(with: photoSettings, delegate: self)
                    completion(self.photoPath!)
                })
            })
        } catch {
            debugPrint(AVCaptureSessionErrorKey.description)
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            debugPrint(error!)
            return
        }
        
        let imageData = photo.fileDataRepresentation()
        ((try? imageData?.write(to: self.photoPath!)) as ()??)
        
        if let photoSession = self.captureSession {
            if photoSession.isRunning {
                photoSession.stopRunning()
            }
        }
    }
}
