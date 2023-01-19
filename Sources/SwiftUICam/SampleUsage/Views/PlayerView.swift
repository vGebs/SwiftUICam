//
//  File.swift
//  
//
//  Created by Vaughn on 2023-01-18.
//

import SwiftUI
import AVFoundation
import AVKit

struct PlayerView: UIViewRepresentable {
    var url: URL
    
    init(url: String) {
        self.url = URL(string: url)!
    }
    
    init(url: URL) {
        self.url = url
    }
    
    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<PlayerView>) { }

    func makeUIView(context: Context) -> UIView {
        return LoopingPlayerUIView(url: url)
    }
}

class LoopingPlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    
    private var url: URL?
    
    func setup() {
        // Load the resource -> h
        //let fileUrl = Bundle.main.url(forResource: "NAME OF VIDEO", withExtension: "TYPE OF VIDEO")!
        
        //Load video
        
        let fileUrl = URL(fileURLWithPath: url!.path)
        let asset = AVAsset(url: fileUrl)
        let item = AVPlayerItem(asset: asset)
        
        // Setup the player
        let player = AVQueuePlayer()
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.masksToBounds = true
        playerLayer.cornerRadius = 20
        
        layer.addSublayer(playerLayer)
        
        // Create a new player looper with the queue player and template item
        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        // Start the movie
        player.play()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(url: URL) {
        self.url = url
        super.init(frame: CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight))
        self.setup()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

