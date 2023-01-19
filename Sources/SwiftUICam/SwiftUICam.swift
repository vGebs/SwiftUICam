
import AVFoundation
import SwiftUI
import UIKit
import Combine


// MARK: - Camera Protocol
protocol CameraProtocol {
    //View builder
    func makeUIView(_ viewBounds: UIView) -> UIView
    
    //Core Functions
    func capturePhoto()
    func startRecording()
    func stopRecording()
    func deleteAsset()
    func saveAsset()
    func toggleCamera()
    func toggleFlash()
    
    //Assets
    var image: UIImage? { get }
    var videoURL: String? { get }
    
    //State functions
    func tearDownCamera()
    func buildCamera()
}


public class CameraWrapper: ObservableObject, CameraProtocol  {
    
    // MARK: - User interactive Camera States
    
    @Published public private(set) var photoSaved = false
    @Published public private(set) var flashEnabled = false
    @Published public private(set) var isRecording = false
    
    // MARK: - Outputs
    
    @Published public private(set) var image: UIImage?
    @Published public private(set) var videoURL: String?

    
    //MARK: - ViewBuilder
    
    //Call makeUIView inside of your UIViewRepresentable struct
    public func makeUIView(_ viewBounds: UIView) -> UIView { makeUIView_(viewBounds) }
    
    
    //MARK: - Core Functions
    
    public func capturePhoto()                { capturePhoto_()     }
    public func startRecording()              { startRecording_()   }
    public func stopRecording()               { stopRecording_()    }
    public func deleteAsset()                 { deleteAsset_()      }
    public func saveAsset()                   { saveAsset_()        }
    public func toggleCamera()                { toggleCamera_()     }
    public func zoomCamera(factor: CGFloat)   { zoomCamera_(factor) }
    public func toggleFlash()                 { toggleFlash_()      }
    
    
    //MARK: - State Functions
    //Tear down camera when camera is not in use
    public func tearDownCamera() { tearDownCamera_() }
    
    //Build camera once it is needed again
    public func buildCamera() { buildCamera_() }

    
    // MARK: - Session Management
    
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    //Setup result is .success by default
    private var setupResult: SessionSetupResult = .success
    private let session = AVCaptureSession()
    private var isSessionRunning = false
    
    // Communicate with the session and other session objects on this queue.
    private let sessionQueue = DispatchQueue(label: "session queue")
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    
    // MARK: - Capturing Photos/Videos
    @Published public private(set) var cameraIsBuilt = false
    @Published public private(set) var classSetupComplete = false
    private let photoOutput = AVCapturePhotoOutput()
    private var photoOutputEnabled = false
    private var movieFileOutput: AVCaptureMovieFileOutput?
    private var fileOutput: AVCaptureFileOutput?
    private var photoQualityPrioritizationMode: AVCapturePhotoOutput.QualityPrioritization = .balanced
    private var inProgressPhotoCaptureDelegates: [Int64: PhotoCaptureProcessor] = [:]
    private var inProgressVideoCaptureDelegates: [String: VideoCaptureProcessor] = [:]
    fileprivate var preview: AVCaptureVideoPreviewLayer!
    private var backgroundRecordingID: UIBackgroundTaskIdentifier?
    
    // MARK: - KVO and Notifications
    
    private var keyValueObservations = [NSKeyValueObservation]()
    
    
    // MARK: - Current Camera
    
    private enum CurrentCamera {
        case front
        case back
    }
    private var currentCamera: CurrentCamera = .front

    
    // MARK: - Photo Depth
    
    private enum DepthDataDeliveryMode {
        case on
        case off
    }
    private var depthDataDeliveryMode: DepthDataDeliveryMode = .off

    
    // MARK: - Camera Dependent Variables
    
    private var camFlipEnabled: Bool
    private var recordActionEnabled: Bool
    private var cameraButtonEnabled: Bool
    private var captureModeControl: Bool
    private var depthEnabled: Bool
    private var photoQualityPrioritization: Bool
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera, .builtInDualWideCamera], mediaType: .video, position: .unspecified)
    
    private var cancellables: [AnyCancellable] = []
        
    // MARK: - Initializer
    public init() {
        self.camFlipEnabled = false
        self.recordActionEnabled = false
        self.cameraButtonEnabled = false
        self.captureModeControl = false
        //self.livePhotoEnabled = false
        self.depthEnabled = false
        self.photoQualityPrioritization = false
        
        /*
         Setup the capture session.
         In general, it's not safe to mutate an AVCaptureSession or any of its
         inputs, outputs, or connections from multiple threads at the same time.
         
         Don't perform these tasks on the main queue because
         AVCaptureSession.startRunning() is a blocking call that can
         take a long time. Dispatch session setup to the sessionQueue, so
         that the main queue isn't blocked, which keeps the UI responsive.
         */
        sessionQueue.async {
            self.configureSession()
        }
    }
    
    deinit {
        print("CameraWrapper: Deinitializing")
    }
    
    // Call this on the session queue.
    /// - Tag: ConfigureSession
    private func configureSession() {
        
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        
        self.addVideoInput()
        
        self.addAudioInput()
        
        self.addPhotoOutput()
        
        self.addVideoOutput()
        
        session.commitConfiguration()
        
        self.checkSetupResult()
    }
}

// MARK: -------------------------------------------------------------------------------------------->
// MARK: - Initializer helpers ---------------------------------------------------------------------->
// MARK: -------------------------------------------------------------------------------------------->

extension CameraWrapper {
    
    private func addVideoInput() {
        /*
         Do not create an AVCaptureMovieFileOutput when setting up the session because
         Live Photo is not supported when AVCaptureMovieFileOutput is added to the session.
         
         For our sake, we are NOT using LivePhoto, so we are going to init AVCaptureMovieFileOutput
         */
        session.sessionPreset = .photo
        session.sessionPreset = AVCaptureSession.Preset(rawValue: AVCaptureSession.Preset.high.rawValue)
        
        do {
            let defaultVideoDevice = self.selectCamera()
            
            guard let videoDevice = defaultVideoDevice else {
                print("CameraWrapper: Default video device is unavailable.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                print(videoDeviceInput)
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                
            } else {
                print("CameraWrapper: Couldn't add video device input to the session.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        } catch {
            print("CameraWrapper: Couldn't create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
    }
    
    private func selectCamera() -> AVCaptureDevice? {
        var defaultVideoDevice: AVCaptureDevice?
        
        if self.currentCamera == .front {
            if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                defaultVideoDevice = frontCameraDevice
            }
        } else {
            if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                defaultVideoDevice = backCameraDevice
            }
            else if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                defaultVideoDevice = dualCameraDevice
            }
            else if let dualWideCameraDevice = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) {
                defaultVideoDevice = dualWideCameraDevice
            }
        }
        
        return defaultVideoDevice
    }
    
    private func addAudioInput() {
        do {
            let audioDevice = AVCaptureDevice.default(for: .audio)
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice!)
            
            if session.canAddInput(audioDeviceInput) {
                session.addInput(audioDeviceInput)
            } else {
                print("CameraWrapper: Could not add audio device input to the session")
            }
        } catch {
            print("CameraWrapper: Could not create audio device input: \(error)")
        }
    }
    
    private func addPhotoOutput() {
        if !photoOutputEnabled {
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                
                photoOutput.isHighResolutionCaptureEnabled = true
                photoOutput.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliverySupported
                photoOutput.isPortraitEffectsMatteDeliveryEnabled = photoOutput.isPortraitEffectsMatteDeliverySupported
                photoOutput.enabledSemanticSegmentationMatteTypes = photoOutput.availableSemanticSegmentationMatteTypes
                photoOutput.maxPhotoQualityPrioritization = .quality
                depthDataDeliveryMode = photoOutput.isDepthDataDeliverySupported ? .on : .off
                photoQualityPrioritizationMode = .balanced
                
                photoOutputEnabled = true
            } else {
                print("CameraWrapper: Could not add photo output to the session")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        }
    }
    
    private func addVideoOutput() {
        
        let movieFileOutput = AVCaptureMovieFileOutput()
        
        if self.session.canAddOutput(movieFileOutput) {
            self.session.addOutput(movieFileOutput)
            self.session.sessionPreset = .high
            
            if let connection = movieFileOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
            
            self.movieFileOutput = movieFileOutput
            print("CameraWrapper: MovieFileOutput added")
        } else {
            print("CameraWrapper-Error: Failed to add movieFileOutput")
        }
    }
    
    private func checkSetupResult() {
        sessionQueue.async {
            
            switch self.setupResult {
            case .success:
                // Only setup observers and start the session if setup succeeded.
                self.addObservers()
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
                
                DispatchQueue.main.async {
                    self.cameraIsBuilt = true
                    self.classSetupComplete = true
                }

            case .notAuthorized:
                DispatchQueue.main.async {
                    print("CameraWrapper: app doesn't have permission to use the camera, please change privacy settings")
                }
                
            case .configurationFailed:
                DispatchQueue.main.async {
                    print("CameraWrapper: Camera configuration failed, quit and relaunch app")
                }
            }
        }
    }
}


// MARK: ---------------------------------------------------------------------------------------->
// MARK: - Core Functionality ------------------------------------------------------------------->
// MARK: ---------------------------------------------------------------------------------------->

extension CameraWrapper {
    private func makeUIView_(_ viewBounds: UIView) -> UIView{
        
        if self.setupResult != .notAuthorized {
            preview = AVCaptureVideoPreviewLayer(session: session)
            preview.frame = viewBounds.frame

            //Properties
            preview.videoGravity = .resizeAspectFill
            preview.cornerRadius = 20
            preview.masksToBounds = true
            viewBounds.layer.addSublayer(preview)
        }
        
        return viewBounds
    }
    
    private func capturePhoto_() {
        /*
         Retrieve the video preview layer's video orientation on the main queue before
         entering the session queue. Do this to ensure that UI elements are accessed on
         the main thread and session configuration is done on the session queue.
         */
        
        sessionQueue.async {
            
            var photoSettings = AVCapturePhotoSettings()
            
            // Capture HEIF photos when supported. Enable auto-flash and high-resolution photos.
            if  self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            }
            
            if self.videoDeviceInput.device.isFlashAvailable {
                if self.flashEnabled {
                    photoSettings.flashMode = .on
                } else {
                    photoSettings.flashMode = .off
                }
            }
            
            photoSettings.isHighResolutionPhotoEnabled = true
            if let previewPhotoPixelFormatType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
                photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType]
            }
            
            photoSettings.isDepthDataDeliveryEnabled = (self.depthDataDeliveryMode == .on
                                                        && self.photoOutput.isDepthDataDeliveryEnabled)
            
            photoSettings.photoQualityPrioritization = self.photoQualityPrioritizationMode
            
            let photoCaptureProcessor = PhotoCaptureProcessor(
                with: photoSettings,
                completionHandler: { photoCaptureProcessor in
                    
                    if let data = photoCaptureProcessor.photoData {
                        let image = UIImage(data: data)!
                        
                        if self.currentCamera == .front {
                            let ciImage: CIImage = CIImage(cgImage: image.cgImage!).oriented(forExifOrientation: 6)
                            let flippedImage = ciImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
                            self.image = UIImage.convert(from: flippedImage)
                        } else {
                            self.image = image
                        }
                        
                        print("CameraWrapper: Got photo")
                    } else {
                        print("CameraWrapper: Picture was not recieved from photoCaptureProcessor")
                    }
                    
                    // When the capture is complete, remove a reference to the photo capture delegate so it can be deallocated.
                    self.sessionQueue.async {
                        self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = nil
                    }
                })
            
            // Specify the location the photo was taken
            //photoCaptureProcessor.location = self.locationManager.location
            
            // The photo output holds a weak reference to the photo capture delegate and stores it in an array to maintain a strong reference.
            self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = photoCaptureProcessor
            self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
        
        }
    }
    
    private func startRecording_() {
        guard let movieFileOutput = self.movieFileOutput else {
            print("CameraWrapper-Error: MovieFileOutput is nil. Please initialize before using this function.")
            return
        }
        self.isRecording = true
        sessionQueue.async {
            if !movieFileOutput.isRecording {
                if UIDevice.current.isMultitaskingSupported {
                    self.backgroundRecordingID = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
                }
                
                // Update the orientation on the movie file output video connection before recording.
                let movieFileOutputConnection = movieFileOutput.connection(with: AVMediaType.video)
                //movieFileOutputConnection?.videoOrientation = videoPreviewLayerOrientation!
                
                //flip video output if front facing camera is selected
                if self.currentCamera == .front {
                    movieFileOutputConnection?.isVideoMirrored = true
                }
                
                let availableVideoCodecTypes = movieFileOutput.availableVideoCodecTypes
                
                if availableVideoCodecTypes.contains(.hevc) {
                    movieFileOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.hevc], for: movieFileOutputConnection!)
                }
                
                let uid = UUID().uuidString
                
                let videoCaptureProcessor = VideoCaptureProcessor(uid: uid, completionHandler: { vidURL, err in
                    if let err = err {
                        print("CameraWrapper-Error: \(err.localizedDescription)")
                    } else {
                        
                        print("CameraWrapper: Video URL -> \(vidURL)")
                        self.videoURL = vidURL.path
                    }
                })
                
                // Start recording video to a temporary file.
                let outputFileName = NSUUID().uuidString
                let outputFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)
                
                if FileManager.default.fileExists(atPath: outputFilePath) {
                    print("CameraWrapper: File exists at this path")
                    do {
                        try FileManager.default.removeItem(atPath: outputFilePath)
                        print("CameraWrapper: Successfully removed file at location -> \(outputFilePath)")
                        
                        print("CameraWrapper: Starting record")
                        movieFileOutput.startRecording(to: URL(fileURLWithPath: outputFilePath), recordingDelegate: videoCaptureProcessor)
                    } catch {
                        print("CameraWrapper: Could not remove file at url: \(outputFilePath)")
                    }
                } else {
                    self.inProgressVideoCaptureDelegates[uid] = videoCaptureProcessor
                    print("CameraWrapper: Starting record")
                    movieFileOutput.startRecording(to: URL(fileURLWithPath: outputFilePath), recordingDelegate: videoCaptureProcessor)
                }
            }
        }
    }
    
    private func stopRecording_(){
        guard let movieFileOutput = self.movieFileOutput else { return }
        self.isRecording = false
        sessionQueue.async {
            if movieFileOutput.isRecording {
                
                if let currentBackgroundRecordingID = self.backgroundRecordingID {
                    self.backgroundRecordingID = UIBackgroundTaskIdentifier.invalid
                    
                    if currentBackgroundRecordingID != UIBackgroundTaskIdentifier.invalid {
                        UIApplication.shared.endBackgroundTask(currentBackgroundRecordingID)
                    }
                }
                
                movieFileOutput.stopRecording()
                
                print("CameraWrapper: Stopped recording")
            } else {
                print("CameraWrapper: Something went wrong")
            }
        }
    }
    
    private func deleteAsset_() {
        self.image = nil
        cleanup()
        self.videoURL = nil
        self.photoSaved = false
    }
    
    private func cleanup() {
        if let path = videoURL {
            deleteLocalFile(at: URL(fileURLWithPath: path))
        }
    }
    
    private func saveAsset_(){
        if let image = self.image{
            
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            
            print("CameraWrapper: saved Successfully....")
            photoSaved = true
        }
    }
    
    private func toggleCamera_() {
        guard session.isRunning == true else {
            return
        }
        
        switch currentCamera {
        case .front:
            currentCamera = .back
        case .back:
            currentCamera = .front
        }
        
        sessionQueue.async {
            self.session.stopRunning()

            // remove and re-add inputs and outputs
            for input in self.session.inputs {
                self.session.removeInput(input)
            }
            
            self.removeObservers()
            self.configureSession()
            
            self.session.startRunning()
        }
    }
    
    private func zoomCamera_(_ factor: CGFloat) {
        
        if factor < 1.0 {
            do {
                try self.videoDeviceInput.device.lockForConfiguration()
                defer { self.videoDeviceInput.device.unlockForConfiguration() }
                self.videoDeviceInput.device.videoZoomFactor = 1.0
            } catch {
                debugPrint(error)
            }
        }
        
        if factor < self.videoDeviceInput.device.activeFormat.videoMaxZoomFactor && factor >= 1.0 {
            do {
                try self.videoDeviceInput.device.lockForConfiguration()
                defer { self.videoDeviceInput.device.unlockForConfiguration() }
                self.videoDeviceInput.device.videoZoomFactor = factor
            } catch {
                debugPrint(error)
            }
        }
    }
    
    private func toggleFlash_() {
        self.flashEnabled.toggle()
    }
    
    private func tearDownCamera_() {
        if cameraIsBuilt {
            sessionQueue.async {
                if self.setupResult == .success {
                    DispatchQueue.main.async {
                        self.cameraIsBuilt = false
                    }
                    
                    self.session.stopRunning()
                    self.isSessionRunning = self.session.isRunning
                    self.removeObservers()
                    
                }
            }
        }
    }
    
    private func buildCamera_() {
        if !cameraIsBuilt{
            sessionQueue.async {
                // remove and re-add inputs and outputs
                for input in self.session.inputs {
                    self.session.removeInput(input)
                }
                self.configureSession()
                
                self.session.startRunning()
            }
        }
    }
}


// MARK: --------------------------------------------------------------------------------------->
// MARK: - KVO & Notifications ----------------------------------------------------------------->
// MARK: --------------------------------------------------------------------------------------->

extension CameraWrapper {
    /// - Tag: ObserveInterruption
    private func addObservers() {
        let keyValueObservation = session.observe(\.isRunning, options: .new) { _, change in
            guard let isSessionRunning = change.newValue else { return }
            let isDepthDeliveryDataEnabled = self.photoOutput.isDepthDataDeliveryEnabled
            
            DispatchQueue.main.async {
                // Only enable the ability to change camera if the device has more than one camera.
                self.camFlipEnabled = isSessionRunning && self.videoDeviceDiscoverySession.uniqueDevicePositionsCount > 1
                self.recordActionEnabled = isSessionRunning && self.movieFileOutput != nil
                self.cameraButtonEnabled = isSessionRunning
                self.captureModeControl = isSessionRunning
                //self.livePhotoEnabled = isSessionRunning && isLivePhotoCaptureEnabled
                self.depthEnabled = isSessionRunning && isDepthDeliveryDataEnabled
                
                self.photoQualityPrioritization = isSessionRunning
            }
        }
        keyValueObservations.append(keyValueObservation)
        
        let systemPressureStateObservation = videoDeviceInput.observe(\.device.systemPressureState, options: .new) { _, change in
            guard let systemPressureState = change.newValue else { return }
            self.setRecommendedFrameRateRangeForPressureState(systemPressureState: systemPressureState)
        }
        keyValueObservations.append(systemPressureStateObservation)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(subjectAreaDidChange),
                                               name: .AVCaptureDeviceSubjectAreaDidChange,
                                               object: videoDeviceInput.device)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionRuntimeError),
                                               name: .AVCaptureSessionRuntimeError,
                                               object: session)
        
    }
    
    /// - Tag: HandleRuntimeError
    @objc
    func sessionRuntimeError(notification: NSNotification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }
        
        print("CameraWrapper-err: Capture session runtime error: \(error)")
        // If media services were reset, and the last start succeeded, restart the session.
        if error.code == .mediaServicesWereReset {
            sessionQueue.async {
                if self.isSessionRunning {
                    self.session.startRunning()
                    self.isSessionRunning = self.session.isRunning
                }
            }
        }
    }
    
    /// - Tag: HandleSystemPressure
    private func setRecommendedFrameRateRangeForPressureState(systemPressureState: AVCaptureDevice.SystemPressureState) {
        /*
         The frame rates used here are only for demonstration purposes.
         Your frame rate throttling may be different depending on your app's camera configuration.
         */
        let pressureLevel = systemPressureState.level
        if pressureLevel == .serious || pressureLevel == .critical {
            if self.movieFileOutput == nil || self.movieFileOutput?.isRecording == false {
                do {
                    try self.videoDeviceInput.device.lockForConfiguration()
                    print("CameraWrapper-WARNING: Reached elevated system pressure level: \(pressureLevel). Throttling frame rate.")
                    self.videoDeviceInput.device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 20)
                    self.videoDeviceInput.device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 15)
                    self.videoDeviceInput.device.unlockForConfiguration()
                } catch {
                    print("CameraWrapper: Could not lock device for configuration: \(error)")
                }
            }
        } else if pressureLevel == .shutdown {
            print("CameraWrapper: Session stopped running due to shutdown system pressure level.")
        }
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
        
        for keyValueObservation in keyValueObservations {
            keyValueObservation.invalidate()
        }
        keyValueObservations.removeAll()
    }
}

extension CameraWrapper {
    @objc
    func subjectAreaDidChange(notification: NSNotification) {
        let devicePoint = CGPoint(x: 0.5, y: 0.5)
        focus(with: .continuousAutoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: false)
    }
    
    private func focus(with focusMode: AVCaptureDevice.FocusMode,
                       exposureMode: AVCaptureDevice.ExposureMode,
                       at devicePoint: CGPoint,
                       monitorSubjectAreaChange: Bool) {
        
        sessionQueue.async {
            let device = self.videoDeviceInput.device
            do {
                try device.lockForConfiguration()
                
                /*
                 Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
                 Call set(Focus/Exposure)Mode() to apply the new point of interest.
                 */
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = focusMode
                }
                
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = exposureMode
                }
                
                device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
                device.unlockForConfiguration()
            } catch {
                print("CameraWrapper-Error: Could not lock device for configuration: \(error)")
            }
        }
    }
}


func deleteLocalFile(at url: URL) {
    if FileManager.default.fileExists(atPath: url.path) {
        do {
            try FileManager.default.removeItem(atPath: url.path)
            print("URLExtension: Cleared file at url: \(url.path)")
        } catch {
            print("URLExtension: Could not remove file at url: \(url.path)")
            print("URLExtension-err: \(error)")
        }
    }
}
