//
//  File.swift
//  
//
//  Created by Vaughn on 2023-01-18.
//

import SwiftUI

extension UIImage {
    static func convert(from ciImage: CIImage) -> UIImage{
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(ciImage, from: ciImage.extent)!
        let image:UIImage = UIImage.init(cgImage: cgImage)
        return image
    }
}
