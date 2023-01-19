//
//  File.swift
//  
//
//  Created by Vaughn on 2023-01-18.
//

import SwiftUI
import Combine

var screenHeight = UIScreen.main.bounds.height
var screenWidth = UIScreen.main.bounds.width

class CameraViewModel: ObservableObject {
    
    var wrapper = CameraWrapper()
    
    @Published private(set) var image: UIImage?
    @Published private(set) var vidURL: String?
    
    @Published private(set) var flashEnabled: Bool = false
    
    private var cancellables: [AnyCancellable] = []
    
    init() {
        
        wrapper.$image
            .debounce(for: .seconds(2.5), scheduler: DispatchQueue.main)
            .map { [weak self] img in
                if img != nil && self!.wrapper.cameraIsBuilt{
                    self?.image = img
                    self?.wrapper.tearDownCamera()
                } else {
                    self?.image = nil
                }
            }.sink { _ in }
            .store(in: &cancellables)
        
        wrapper.$image
            .map { [weak self] img in
                if img == nil && !self!.wrapper.cameraIsBuilt && self!.wrapper.classSetupComplete {
                    self?.image = nil
                    self?.wrapper.buildCamera()
                } else {
                    self?.image = img
                }
            }.sink { _ in }
            .store(in: &cancellables)
        
        wrapper.$flashEnabled
            .map { [weak self] flash in
                if flash {
                    self?.flashEnabled = true
                } else {
                    self?.flashEnabled = false
                }
            }.sink { _ in }
            .store(in: &cancellables)
    }
    
    //proceed to abstract details from CameraWrapper...
}

