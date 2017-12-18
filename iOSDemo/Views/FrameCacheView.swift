//
//  FrameCacheView.swift
//  iOSDemo
//
//  Created by Zhu Shengqi on 16/12/2017.
//

import UIKit
import AnimatedImageKit

final class FrameCacheView: UIView {
  
  var image: AnimatedImage? {
    didSet {
      guard image !== oldValue else {
        return
      }
      
      for subview in self.subviews {
        subview.removeFromSuperview()
      }
      
      for _ in 0..<(image?.frameCount ?? 0) {
        let frameView = UIView()
        frameView.layer.borderWidth = 1
        frameView.layer.borderColor = UIColor(white: 0.8, alpha: 1).cgColor
        addSubview(frameView)
      }
      
      setNeedsLayout()
    }
  }
  
  var cachedFramesIndices: IndexSet = .init() {
    didSet {
      if cachedFramesIndices != oldValue {
        setNeedsLayout()
      }
    }
  }
  
  var requestedFrameIndex: Int = -1 {
    didSet {
      if requestedFrameIndex != oldValue {
        setNeedsLayout()
      }
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    
    backgroundColor = .clear
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    guard let image = image else {
      return
    }
    
    let totalDelayTime = image.frameDelays.reduce(0, +)
    
    var x: CGFloat = 0
    
    for (i, subview) in self.subviews.enumerated() {
      let isRequestedFrame = i == requestedFrameIndex
      let isCached = cachedFramesIndices.contains(i)
      
      let fillColor: UIColor
      if isCached {
        fillColor = UIColor(white: 1, alpha: 0.5)
      } else if isRequestedFrame {
        fillColor = UIColor(red: 0.8, green: 0.15, blue: 0.15, alpha: 0.6)
      } else {
        fillColor = .clear
      }
      
      subview.backgroundColor = fillColor
      
      let width = self.bounds.size.width * CGFloat(image.frameDelays[i] / totalDelayTime)
      subview.frame = CGRect(x: x, y: 0, width: width + subview.layer.borderWidth, height: self.bounds.height)
      
      x += width
    }
  }
  
}
