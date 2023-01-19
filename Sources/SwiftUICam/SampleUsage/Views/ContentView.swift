//
//  File.swift
//  
//
//  Created by Vaughn on 2023-01-18.
//

import SwiftUI

@available(iOS 14.0, *)
struct ContentView: View {
    @StateObject var camera = CameraViewModel()
    
    var body: some View {
        ZStack {
            CameraView(camera: camera)
            
            if (camera.image != nil || camera.vidURL != nil) {
                PicTakenView(camera: camera.wrapper)
            }
        }
    }
}

struct PicTakenView: View {
    
    @ObservedObject var camera: CameraWrapper
    
    var body: some View {
        ZStack {
            if camera.image != nil {
                
                VStack{
                    Image(uiImage: camera.image!)
                        .resizable()
                        .scaledToFill()
                        .frame(width: screenWidth, height: screenHeight)
                        .cornerRadius(20)
                        .edgesIgnoringSafeArea(.all)
                    
                    Spacer()
                }
                .edgesIgnoringSafeArea(.all)
                VStack {
                    HStack {
                        Button(action: {
                            camera.deleteAsset()
                        }) {
                            Text("Delete")
                        }
                        .padding()
                        
                        Spacer()
                        
                        Button(action: {
                            camera.saveAsset()
                        }) {
                            Text("Save to photos")
                        }
                        .padding()
                    }
                    .padding(.top, 50)
                    Spacer()
                }
            }
            
            if let url = camera.videoURL {
                VStack {
                    PlayerView(url: url)
                        .frame(height: screenHeight)
                        .cornerRadius(20)
                        .edgesIgnoringSafeArea(.all)
                        
                    Spacer()
                }
                VStack {
                    HStack {
                        Button(action: {
                            camera.deleteAsset()
                        }) {
                            Text("Delete")
                        }
                        
                        .padding()
                        
                        Spacer()
                        
                        Button(action: {camera.saveAsset()}) {
                            Text("Save to photos")
                        }
                        .padding()
                    }
                    .padding(.top, 50)
                    
                    Spacer()
                }
            }
        }
    }
}
