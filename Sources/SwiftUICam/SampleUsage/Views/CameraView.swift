//
//  File.swift
//  
//
//  Created by Vaughn on 2023-01-18.
//

import SwiftUI

@available(iOS 14.0, *)
struct CameraView: View {
    
    @ObservedObject var camera: CameraViewModel
    @State var verticalZoomOffset: CGSize = .zero
    
    let view = UIView(frame: CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight))
    
    var body: some View {
        ZStack {
            SwiftUICamPreview(camera: camera.wrapper, view: view)
                .ignoresSafeArea(.all, edges: .all)
                .onTapGesture(count: 2) {
                    camera.wrapper.toggleCamera()
                }
                .shadow(radius: 15)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            verticalZoomOffset = gesture.translation
                            camera.wrapper.zoomCamera(factor: -(verticalZoomOffset.height / 15))
                        }
                        .onEnded { _ in
                            verticalZoomOffset = .zero
                        }
                )
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        camera.wrapper.toggleFlash()
                    }){
                        Image(systemName: camera.flashEnabled ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 20, weight: .regular, design: .rounded))
                            .foregroundColor(.blue)
                            .padding(.trailing, 7)
                    }
                }
                
                Spacer()
                
                if camera.image == nil || camera.vidURL == nil {
                    if !camera.wrapper.isRecording {
                        Button(action: {
                            camera.wrapper.capturePhoto()
                        }) {
                            Text("Take Picture")
                        }.padding()
                        
                        Button(action: {
                            camera.wrapper.startRecording()
                        }) {
                            Text("Take Video")
                        }
                    }
                    
                    if camera.wrapper.isRecording {
                        Button(action: {
                            camera.wrapper.stopRecording()
                        }) {
                            Text("Stop taking video")
                        }
                    }
                }
            }
        }
    }
}
