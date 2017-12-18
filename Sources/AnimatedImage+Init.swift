//
//  AnimatedImage+Init.swift
//  AnimatedImageKit-iOS
//
//  Created by Zhu Shengqi on 17/12/2017.
//

import Foundation

extension AnimatedImage {
  
  public convenience init?(fileName: String, bundle: Bundle, frameCachePolicy: FrameCachePolicy = .greedy) {
    guard let url = bundle.url(forResource: fileName, withExtension: "gif") else {
      return nil
    }
    
    guard let gifData = try? Data(contentsOf: url, options: .mappedIfSafe) else {
      return nil
    }
    
    self.init(gifData: gifData, frameCachePolicy: frameCachePolicy)
  }
  
  
  
}
