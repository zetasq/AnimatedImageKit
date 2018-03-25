//
//  GIFImageSource.swift
//  AnimatedImageKit-iOS
//
//  Created by Zhu Shengqi on 06/12/2017.
//

import UIKit
import MobileCoreServices

public final class GIFImageSource {
  
  public let posterImage: UIImage
  
  public let loopCount: LoopCount
  
  public let frameCount: Int
  
  public let frameDelays: [Double]
  
  // MARK: - Private Properties
  private let _imageSource: CGImageSource

  // MARK: - Init & Deinit
  public init?(imageData: Data) {
    guard !imageData.isEmpty else {
      internalLog(.error, "Empty GIF data when calling \(#function)")
      return nil
    }
    
    guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, [kCGImageSourceTypeIdentifierHint: kUTTypeGIF, kCGImageSourceShouldCache: false] as CFDictionary) else {
      internalLog(.error, "Failed to create \(CGImageSource.self) when calling \(#function)")
      return nil
    }
    _imageSource = imageSource
    
    guard let sourceType = CGImageSourceGetType(_imageSource), UTTypeConformsTo(sourceType, kUTTypeGIF) else {
      internalLog(.error, "Supplied data is not GIF image when calling \(#function)")
      return nil
    }
    
    guard let imageProperties = CGImageSourceCopyProperties(_imageSource, nil) as? [String: Any] else {
      internalLog(.error, "Cannot get GIF image properties when calling \(#function)")
      return nil
    }
    
    guard let gifDictionary = imageProperties[kCGImagePropertyGIFDictionary as String] as? [String: Any], let gifLoopCount = gifDictionary[kCGImagePropertyGIFLoopCount as String] as? Int else {
      internalLog(.error, "Failed to get GIF image loopCount when calling \(#function)")
      return nil
    }
    self.loopCount = gifLoopCount > 0 ? .finite(gifLoopCount) : .infinity
    
    frameCount = CGImageSourceGetCount(_imageSource)
    guard frameCount > 0 else {
      internalLog(.error, "GIF image's frameCount is zero when calling \(#function)")
      return nil
    }
    
    if frameCount == 1 {
      internalLog(.info, "Get only 1 frame when calling \(#function)")
    }
    
    var tempFrameDelays: [TimeInterval] = []
    var firstFrameImage: UIImage?
    
    for i in 0..<frameCount {
      if i == 0 {
        guard let frameCGImage = CGImageSourceCreateImageAtIndex(_imageSource, 0, nil) else {
          internalLog(.error, "GIF image is corrupted: cannnot get first frame in `CGImageSourceCreateImageAtIndex` when calling \(#function)")
          
          return nil
        }
        
        firstFrameImage = UIImage(cgImage: frameCGImage)
      }
      
      guard let frameProperties = CGImageSourceCopyPropertiesAtIndex(_imageSource, i, nil) as? [String: Any], let gifDictionary = frameProperties[kCGImagePropertyGIFDictionary as String] as? [String: Any] else {
        internalLog(.error, "GIF image is corrupted: cannnot get GIF properties of frame \(i) when calling \(#function)")
        
        return nil
      }
      
      var delayTime: TimeInterval
      
      if let unclampedDelayTime = gifDictionary[kCGImagePropertyGIFUnclampedDelayTime as String] as? TimeInterval {
        delayTime = unclampedDelayTime
      } else if let clampedDelayTime = gifDictionary[kCGImagePropertyGIFDelayTime as String] as? TimeInterval {
        delayTime = clampedDelayTime
      } else {
        delayTime = 0.1
      }
      
      if (delayTime < 0.02 - .leastNormalMagnitude) {
        delayTime = 0.1
      }
      
      tempFrameDelays.append(delayTime)
    }
    
    guard let image = firstFrameImage else {
      internalLog(.error, "GIF image is corrupted: cannnot get first frame when calling \(#function)")
      
      return nil
    }
    posterImage = image
    
    guard frameCount == tempFrameDelays.count else {
      internalLog(.error, "GIF image is corrupted: some frames are missing when calling \(#function)")
      
      return nil
    }
    frameDelays = tempFrameDelays
  }
  
  // MARK: - Public Methods
  public func image(at index: Int) -> CGImage? {
    return CGImageSourceCreateImageAtIndex(_imageSource, index, nil)
  }
  
  
  
}
