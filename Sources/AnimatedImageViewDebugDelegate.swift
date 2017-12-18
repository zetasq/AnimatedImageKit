//
//  AnimatedImageViewDebugDelegate.swift
//  AnimatedImageKit-iOS
//
//  Created by Zhu Shengqi on 16/12/2017.
//

import Foundation

#if DEBUG
  public protocol AnimatedImageViewDebugDelegate: class {
    
    func debug_animatedImageView(_ animatedImageView: AnimatedImageView, waitingForFrameAt index: Int, duration: TimeInterval)
    
  }
#endif
