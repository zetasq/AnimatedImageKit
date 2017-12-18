//
//  AnimatedImageDebugDelegate.swift
//  AnimatedImageKit-iOS
//
//  Created by Zhu Shengqi on 12/11/2017.
//

import UIKit

#if DEBUG

  public protocol AnimatedImageDebugDelegate: class {
    
    func debug_animatedImage(_ animatedImage: AnimatedImage, didUpdateCachedFramesAt cachedFramesIndices: IndexSet)
    
    func debug_animatedImage(_ animatedImage: AnimatedImage, didRequestCachedFrameAt index: Int)
    
//    func debug_animatedImagePredrawingSlowdownFactor(_ animatedImage: AnimatedImage) -> Double
//    
  }
  
#endif
