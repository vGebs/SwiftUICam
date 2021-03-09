
import SwiftUI
import AVFoundation
import MediaPlayer

// Camera Model...
//------------------------------------------------------------------------------------------------------------------\
//Camera Model ------------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------------------------/
public class SwiftUICamModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate{
        
    //Used to notify UI that frontFlash is active (i.e. picture is being taken)
    @Published var frontFlashActive = false
    
    //Used to enable flash for next picture
    @Published var flashEnabled = true
    
    //Used to notify the takepic-volume-button when the camera is on screen
    @Published var onCameraScreen = true
    
    //Current camera in use [(front of rear) used for front flash in view]
    @Published var currentCamera = CameraSelection.front
    
    //Bool to specify whether a pic was taken
    @Published var picTaken = false
    
    //Bool to specify whether or not a pic was saved
    @Published var picSaved = false
    
    //Pic Data
    @Published var image: UIImage?
    
    
    
    public init(volumeCameraButton: Bool){
        volumeCameraButtonOn = volumeCameraButton
    }
    
    //Core Functionality
    public func takePic(){ prepareToTakePic_() }
    public func retakePic(){ retakePic_() }
    public func savePic(){ savePic_() }
    public func toggleCamera(){ toggleCamera_() }
    
    
    
    //View preview for the UIViewRepresentable
    fileprivate var preview: AVCaptureVideoPreviewLayer!
    
    //Used to Setup an AV Session
    fileprivate var session = AVCaptureSession()
    
    //Used to notify the preview that the user has denied access to the camera
    fileprivate var alert = false
    
    //Used to turn the takepic-volume-button on
    private var volumeCameraButtonOn = false
    
    //Video Setup
    private var videoDevice: AVCaptureDevice?
    private var videoDeviceInput: AVCaptureDeviceInput!
    
    //Used for reading pic data
    private var output = AVCapturePhotoOutput()
    
    private var setupResult = SessionSetupResult.success
    
    //Used to reset the volume after the user took pic w the volume button
    private var audioLevel : Float = 0.0
}



//------------------------------------------------------------------------------------------------------------------\
//Setting view for preview ------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------------------------/
public struct SwiftUICamPreview: UIViewRepresentable {
    
    @EnvironmentObject var camera : SwiftUICamModel
    var view: UIView
    
    public func makeUIView(context: Context) ->  UIView {
        camera.Check()
        if !camera.alert {
            camera.preview = AVCaptureVideoPreviewLayer(session: camera.session)
            camera.preview.frame = view.frame
            
            // Your Own Properties...
            camera.preview.videoGravity = .resizeAspectFill
            camera.preview.cornerRadius = 20
            camera.preview.masksToBounds = true
            view.layer.addSublayer(camera.preview)
            
            camera.listenVolumeButton()

            // starting session
            camera.session.startRunning()
        }
                
        return view
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {
        let brightness = CGFloat(0.35)
        
        //Turns screen brightness all the way up to take front flash pic
        if camera.frontFlashActive {
            UIScreen.main.brightness = CGFloat(1.0)
        } else {
            UIScreen.main.brightness = brightness
        }
    }
}



//------------------------------------------------------------------------------------------------------------------\
//Core functionality-------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------------------------/
extension SwiftUICamModel{
    
    private func prepareToTakePic_(){
        guard let device = videoDevice else {
            return
        }
        
        if device.hasFlash && flashEnabled == true && currentCamera == .rear {
            picTaken.toggle()

            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 1) {
                self.takePic_()
            }
            
            toggleFlash()
            
        } else if flashEnabled == true && currentCamera == .front{
            frontFlashActive = true
            picTaken.toggle()

            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                self.frontFlashActive = false
            }
            
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                self.takePic_()
            }
        
        } else {
            picTaken.toggle()
            takePic_()
        }
        
        picSaved = false
    }
    
    private func takePic_(){
        self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        
        DispatchQueue.global(qos: .background).async {
            self.session.stopRunning()
        }
    }
    
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    
        if error != nil{
            return
        }
        
        print("pic taken...")
        
        //Flip image to save
        if currentCamera == .front {
            if let data = photo.fileDataRepresentation(){
                let image = UIImage(data: data)!
                let ciImage: CIImage = CIImage(cgImage: image.cgImage!).oriented(forExifOrientation: 6)
                let flippedImage = ciImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
                self.image = UIImage.convert(from: flippedImage)
            }
        } else {
            if let data = photo.fileDataRepresentation(){
                self.image = UIImage(data: data)!
            }
        }
    }
    
    private func retakePic_(){
        picSaved = false
        
        DispatchQueue.global(qos: .background).async {
            
            self.session.startRunning()
            
            DispatchQueue.main.async {
                self.picTaken.toggle()
                //clearing ...
                self.image = nil
            }
        }
    }
    
    private func savePic_(){
        if let image = self.image{
            
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        
            print("saved Successfully....")
            picSaved = true
        }
    }
    
    public enum CameraSelection: String {

        /// Camera on the back of the device
        case rear = "rear"

        /// Camera on the front of the device
        case front = "front"
    }
    
    private func toggleCamera_() {
        guard session.isRunning == true else {
            return
        }

        switch currentCamera {
        case .front:
            currentCamera = .rear
        case .rear:
            currentCamera = .front
        }

        session.stopRunning()
        
        DispatchQueue.main.async {

            // remove and re-add inputs and outputs

            for input in self.session.inputs {
                self.session.removeInput(input)
            }

            self.addInputs()

            self.session.startRunning()
        }
    }
}



//------------------------------------------------------------------------------------------------------------------\
//Camera Init -------------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------------------------/
extension SwiftUICamModel {
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    fileprivate func Check(){
        
        // first checking cameras got permission...
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setUp()
            return
            // Setting Up Session
        case .notDetermined:
            // retesting for permission
            AVCaptureDevice.requestAccess(for: .video) { status in
                if status{
                    self.setUp()
                }
            }
        case .denied:
            self.alert.toggle()
            return
            
        default:
            return
        }
    }
    
    func setUp(){
        // setting up camera
        addInputs()
        addOutputs()
    }
    
    fileprivate func addInputs(){
        session.beginConfiguration()
        configureVideoPreset()
        addVideoInput()
        addAudioInput()
        session.commitConfiguration()
    }
    
    private func configureVideoPreset() {
        
        //Sets the video quality to high (other options available)
        session.sessionPreset = AVCaptureSession.Preset(rawValue: AVCaptureSession.Preset.high.rawValue)
        
        
        
        // Commented code below can be used to specify the video quality. For my purposes, I will only be using high. For more info, please check out SwiftyCam by Awalz on Github
        
//        if currentCamera == .front {
//            session.sessionPreset = AVCaptureSession.Preset(rawValue: videoInputPresetFromVideoQuality(quality: .high))
//        } else {
//            if session.canSetSessionPreset(AVCaptureSession.Preset(rawValue: videoInputPresetFromVideoQuality(quality: videoQuality))) {
//                session.sessionPreset = AVCaptureSession.Preset(rawValue: videoInputPresetFromVideoQuality(quality: videoQuality))
//            } else {
//                session.sessionPreset = AVCaptureSession.Preset(rawValue: videoInputPresetFromVideoQuality(quality: .high))
//            }
//        }
        
    }
    
    private func addVideoInput() {
        switch currentCamera {
        case .front:
            videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
//            SwiftyCamViewController.deviceWithMediaType(AVMediaType.video.rawValue, preferringPosition: .front)
        
        case .rear:
            videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
//                SwiftyCamViewController.deviceWithMediaType(AVMediaType.video.rawValue, preferringPosition: .back)
        }

        if let device = videoDevice {
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                    if device.isSmoothAutoFocusSupported {
                        device.isSmoothAutoFocusEnabled = true
                    }
                }

                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }

                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }

                if device.isLowLightBoostSupported {
                    device.automaticallyEnablesLowLightBoostWhenAvailable = true
                }

                device.unlockForConfiguration()
            } catch {
                print("[SwiftyCam]: Error locking configuration")
            }
        }

        do {
            if let videoDevice = videoDevice {
                let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                if session.canAddInput(videoDeviceInput) {
                    session.addInput(videoDeviceInput)
                    self.videoDeviceInput = videoDeviceInput
                } else {
                    print("[SwiftyCam]: Could not add video device input to the session")
                    print(session.canSetSessionPreset(AVCaptureSession.Preset(rawValue: AVCaptureSession.Preset.high.rawValue)))
                    setupResult = .configurationFailed
                    session.commitConfiguration()
                    return
                }
            }
            
        } catch {
            print("[SwiftyCam]: Could not create video device input: \(error)")
            setupResult = .configurationFailed
            return
        }
    }

    /// Add Audio Inputs
    private func addAudioInput() {
        do {
            if let audioDevice = AVCaptureDevice.default(for: AVMediaType.audio){
                let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioDeviceInput) {
                    session.addInput(audioDeviceInput)
                } else {
                    print("[SwiftyCam]: Could not add audio device input to the session")
                }
                
            } else {
                print("[SwiftyCam]: Could not find an audio device")
            }
            
        } catch {
            print("[SwiftyCam]: Could not create audio device input: \(error)")
        }
    }
    
    private func addOutputs(){
        if self.session.canAddOutput(self.output){
            self.session.addOutput(self.output)
        }
    }
}



//------------------------------------------------------------------------------------------------------------------\
//Flash -------------------------------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------------------------/
extension SwiftUICamModel {
    
    //Currently not in use
    public enum FlashMode{
        //Return the equivalent AVCaptureDevice.FlashMode
        var AVFlashMode: AVCaptureDevice.FlashMode {
            switch self {
                case .on:
                    return .on
                case .off:
                    return .off
                case .auto:
                    return .auto
            }
        }
        //Flash mode is set to auto
        case auto
        
        //Flash mode is set to on
        case on
        
        //Flash mode is set to off
        case off
    }
    
    private func toggleFlash(){
       
        let device = AVCaptureDevice.default(for: AVMediaType.video)
        // Check if device has a flash
        if (device?.hasTorch)! {
            do {
                try device?.lockForConfiguration()
                if (device?.torchMode == AVCaptureDevice.TorchMode.on) {
                    device?.torchMode = AVCaptureDevice.TorchMode.off
                } else {
                    do {
                        try device?.setTorchModeOn(level: 1.0)
                    } catch {
                        print("[SwiftyCam]: \(error)")
                    }
                }
                device?.unlockForConfiguration()
            } catch {
                print("[SwiftUICam]: \(error)")
            }
        }
    }
}



//------------------------------------------------------------------------------------------------------------------\
//Click the volume button to snap pic -------------------------------------------------------------------------------
//------------------------------------------------------------------------------------------------------------------/
extension SwiftUICamModel {
    fileprivate func listenVolumeButton(){
             
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(true, options: [])
                audioSession.addObserver(self, forKeyPath: "outputVolume", options: NSKeyValueObservingOptions.new, context: nil)
                audioLevel = audioSession.outputVolume
        } catch {
            print("Error")
        }
    }
    
    //Function is called when the volume button is pressed
    //Fix so that the volume is unaffected when pressing ->  currentAudioLevel = audioLevel, *CLICK* audioLevel = currentAudioLevel (or something like that)
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "outputVolume"{
//                   let audioSession = AVAudioSession.sharedInstance()
//                   if audioSession.outputVolume > audioLevel {
//                        print("Hello")
//                   }
//                   if audioSession.outputVolume < audioLevel {
//                        print("GoodBye")
//                   }
//                   audioLevel = audioSession.outputVolume
//                   print(audioSession.outputVolume)
                
            if picTaken == false && onCameraScreen && volumeCameraButtonOn{
                takePic()
            }
        }
    }
}

extension UIImage{
    static func convert(from ciImage: CIImage) -> UIImage{
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(ciImage, from: ciImage.extent)!
        let image:UIImage = UIImage.init(cgImage: cgImage)
        return image
    }
}

