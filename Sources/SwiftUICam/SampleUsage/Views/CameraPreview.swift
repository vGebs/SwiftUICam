//
//  File.swift
//  
//
//  Created by Vaughn on 2023-01-18.
//

import SwiftUI

struct SwiftUICamPreview: UIViewRepresentable {
    
    @ObservedObject var camera: CameraWrapper
    var view: UIView

    func makeUIView(context: Context) ->  UIView {
        return camera.makeUIView(view)
    }

    func updateUIView(_ uiView: UIView, context: Context) { }
}
