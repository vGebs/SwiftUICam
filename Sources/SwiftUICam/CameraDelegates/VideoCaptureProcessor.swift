//
//  VideoCaptureProcessor.swift
//  
//
//  Created by Vaughn on 2023-01-18.
//

import AVFoundation

class VideoCaptureProcessor: NSObject {
    private(set) var uid: String
    private let completionHandler: (URL, Error?) -> Void
    var outputFileURL: URL?
    
    init(uid: String, completionHandler: @escaping (URL, Error?) -> Void){
        self.uid = uid
        self.completionHandler = completionHandler
    }
}

extension VideoCaptureProcessor: AVCaptureFileOutputRecordingDelegate {
    
    /// - Tag: DidStartRecording
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        // Enable the Record button to let the user stop recording.
        print("VideoCaptureProcessor: Did start recording")
    }
    
    /// - Tag: DidFinishRecording
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        // Note: Because we use a unique file path for each recording, a new recording won't overwrite a recording mid-save.
        
        print("VideoCaptureProcessor: Did finish recording")
        
        if let error = error {
            print("VideoCaptureProcessor-ERROR: Movie file finishing error -> \(String(describing: error))")
            return completionHandler(outputFileURL, error)
        } else {
            return completionHandler(outputFileURL, error)
        }
    }
}

