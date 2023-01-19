//
//  PhotoCaptureProcessor.swift
//  
//
//  Created by Vaughn on 2023-01-18.
//

import AVFoundation

class PhotoCaptureProcessor: NSObject {
    private(set) var requestedPhotoSettings: AVCapturePhotoSettings
    
    private let completionHandler: (PhotoCaptureProcessor) -> Void
        
    var photoData: Data?
    
    private var livePhotoCompanionMovieURL: URL?
    
    private var semanticSegmentationMatteDataArray = [Data]()
    private var maxPhotoProcessingTime: CMTime?

    init(with requestedPhotoSettings: AVCapturePhotoSettings, completionHandler: @escaping (PhotoCaptureProcessor) -> Void) {
        
        self.requestedPhotoSettings = requestedPhotoSettings
        self.completionHandler = completionHandler
    }
    
    private func didFinish() {
        completionHandler(self)
    }
}

extension PhotoCaptureProcessor: AVCapturePhotoCaptureDelegate {
    /*
     This extension adopts all of the AVCapturePhotoCaptureDelegate protocol methods.
     */
    
    /// - Tag: WillBeginCapture
    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {

        maxPhotoProcessingTime = resolvedSettings.photoProcessingTimeRange.start + resolvedSettings.photoProcessingTimeRange.duration
    }
    
    /// - Tag: WillCapturePhoto
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        //willCapturePhotoAnimation()
    }
    
    /// - Tag: DidFinishProcessingPhoto
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {

        if let error = error {
            print("Error capturing photo: \(error)")
            return
        } else {
            photoData = photo.fileDataRepresentation()
        }
    }
    
    /// - Tag: DidFinishRecordingLive
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings) {
        //livePhotoCaptureHandler(false)
    }
    
    /// - Tag: DidFinishProcessingLive
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, duration: CMTime, photoDisplayTime: CMTime, resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if error != nil {
            print("Error processing Live Photo companion movie: \(String(describing: error))")
            return
        }
        livePhotoCompanionMovieURL = outputFileURL
    }
    
    /// - Tag: DidFinishCapture
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            didFinish()
            return
        }

        if let _ = photoData {
            didFinish()
            return
        } else {
            print("No photo data resource")
            didFinish()
            return
        }
    }
}
