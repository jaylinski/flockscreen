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
    var captureDevice : AVCaptureDevice?
    let captureSession = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()
    let photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
    let picturesDirectory = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]

    func captureStillImage() {
        // Find the FaceTime HD camera object
        captureDevice = AVCaptureDevice.default(for: AVMediaType.video)
        guard captureDevice != nil else { return }

        do {
            try captureSession.addInput(AVCaptureDeviceInput(device: captureDevice!))

            guard self.captureSession.canAddOutput(photoOutput) else { return }
            self.captureSession.sessionPreset = AVCaptureSession.Preset.photo
            self.captureSession.addOutput(photoOutput)
            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()

            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        } catch {
            print(AVCaptureSessionErrorKey.description)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let time = NSDate().timeIntervalSince1970
        let imageData = photo.fileDataRepresentation()
        let imageUrl = self.picturesDirectory.appendingPathComponent("flockscreen.\(time).jpg", isDirectory: false)
        ((try? imageData?.write(to: imageUrl)) as ()??)
        self.captureSession.stopRunning()
    }
}
