//
//  GIFImage.swift
//  AnimatedImageKit-iOS
//
//  Created by Zhu Shengqi on 05/12/2017.
//

import UIKit

public final class AnimatedImage {
  
  // MARK: - Subtypes
  public enum FrameCachePolicy {
    case greedy
    case limited(count: Int)
  }
  
  // MARK: - Public Properties
  
  #if DEBUG
  public weak var debugDelegate: AnimatedImageDebugDelegate?
  #endif
  
  public let frameCachePolicy: FrameCachePolicy
  
  public var posterImage: UIImage {
    return _imageSource.posterImage
  }
  
  public var size: CGSize {
    return _imageSource.posterImage.size
  }
  
  public var memoryUsage: CGFloat {
    let posterImageSize = _imageSource.posterImage.size
    
    return posterImageSize.width * posterImageSize.height * CGFloat(4) * CGFloat(_frameIndexToImageCache.count) / CGFloat(1024 * 1024)
  }
  
  public var loopCount: LoopCount {
    return _imageSource.loopCount
  }
  
  public var frameCount: Int {
    return _imageSource.frameCount
  }
  
  public var frameDelays: [Double] {
    return _imageSource.frameDelays
  }

  public private(set) lazy var frameDelayGCD: TimeInterval = {
    let kGCDPrecision: TimeInterval = 2.0 / 0.02
    
    var scaledGCD = lrint(_imageSource.frameDelays[0] * kGCDPrecision)
    
    for delay in _imageSource.frameDelays {
      scaledGCD = GCD(lrint(delay * kGCDPrecision), scaledGCD)
    }
    
    return TimeInterval(scaledGCD) / kGCDPrecision
  }()
  
  // MARK: - Private Properties
  private let _imageSource: GIFImageSource
  
  private let _queue = DispatchQueue(label: "com.AnimatedImage.serialQueue")
  
  //  private var _cacheWindowStartIndex: Int
  //  private var _cacheWindowSize: Int
  
  private var _frameIndexToImageCache: [Int: UIImage] = [:]
  
  private var _backgroundLastRequestedFrameIndex: Int?
  private var _backgroundCachedFrameIndices: IndexSet = IndexSet()
  private var _backgroundMaxCachedFrameCount: Int
  private var _backgroundLastMemoryWarningTimestamp: Timestamp?
  
  // MARK: - Init & Deinit
  public init?(gifData: Data, frameCachePolicy: FrameCachePolicy = .greedy) {
    guard let gifImageSource = GIFImageSource(imageData: gifData) else {
      return nil
    }
    self.frameCachePolicy = frameCachePolicy
    _imageSource = gifImageSource

    _frameIndexToImageCache[0] = _imageSource.posterImage
    _backgroundCachedFrameIndices.insert(0)
    
    switch self.frameCachePolicy {
    case .greedy:
      _backgroundMaxCachedFrameCount = _imageSource.frameCount
    case .limited(let count):
      _backgroundMaxCachedFrameCount = max(1, count)
    }
    
    prepareImages(from: 0)
    
    NotificationCenter.default.addObserver(self, selector: #selector(self.didReceiveMemoryWarning(_:)), name: .UIApplicationDidReceiveMemoryWarning, object: nil)
  }
  
  // MARK: - Public Methods
  public func imageCached(at index: Int) -> UIImage? {
    assert(Thread.isMainThread)
    assert(index < _imageSource.frameCount)
    
    guard index < _imageSource.frameCount else {
      return nil
    }
    
    #if DEBUG
      debugDelegate?.debug_animatedImage(self, didRequestCachedFrameAt: index)
    #endif
    
    prepareImages(from: index)
    
    return _frameIndexToImageCache[index]
  }
  
  // MARK: - Private Methods
  private func prepareImages(from index: Int) {
    assert(Thread.isMainThread)
    
    _queue.async { [weak self] in
      guard let `self` = self else {
        return
      }
      
      guard self._backgroundLastRequestedFrameIndex != index else {
        return
      }
      
      let adjustedIndex: Int // The index needs to be adjusted for later use
      
      if index == 0 {
        if self._imageSource.frameCount <= 1 {
          return
        } else {
          adjustedIndex = 1
        }
      } else {
        adjustedIndex = index
      }
      
      self._backgroundLastRequestedFrameIndex = adjustedIndex
      
      let couldIncreaseThreshold: Bool
      switch self.frameCachePolicy {
      case .greedy:
        couldIncreaseThreshold = self._backgroundMaxCachedFrameCount < self._imageSource.frameCount
      case .limited(let count):
        couldIncreaseThreshold = self._backgroundMaxCachedFrameCount < min(count, self._imageSource.frameCount)
      }
      
      if couldIncreaseThreshold {
        if let lastWarningTimestamp = self._backgroundLastMemoryWarningTimestamp {
          let now = Timestamp()
          let safeInterval = Int(5 + arc4random_uniform(5))
          
          if now.seconds(since: lastWarningTimestamp) > safeInterval {
            
            self._backgroundMaxCachedFrameCount += 1
          }
        } else {
          self._backgroundMaxCachedFrameCount += 1
        }
      }
      
      let preferredPrefetchCount = max(1, min(self._backgroundMaxCachedFrameCount, Int(ceil(1 / self._imageSource.frameDelays[adjustedIndex]))))
      
      for i in adjustedIndex..<adjustedIndex+preferredPrefetchCount {
        let validIdx = i % self._imageSource.frameCount

        guard !self._backgroundCachedFrameIndices.contains(validIdx) else {
          continue
        }
        
        guard let image = self.generateImage(at: validIdx) else {
          continue
        }
        
        self._backgroundCachedFrameIndices.insert(validIdx)
        
        DispatchQueue.main.async { [validIdx, weak self] in
          guard let `self` = self else {
            return
          }
          
          self._frameIndexToImageCache[validIdx] = image
        }
      }
      
      self.purgeCachedFramesIfNeeded()
      
      #if DEBUG
        let indices = self._backgroundCachedFrameIndices
        DispatchQueue.main.async { [weak self] in
          guard let `self` = self else {
            return
          }
          
          self.debugDelegate?.debug_animatedImage(self, didUpdateCachedFramesAt: indices)
        }
      #endif
    }
  }
  
  private func generateImage(at index: Int) -> UIImage? {
    guard let cgImage = _imageSource.image(at: index) else {
      return nil
    }
    
    let uiImage = UIImage(cgImage: cgImage)
    return uiImage.predrawImage() ?? uiImage
  }
  
  // MARK: - Notification Handlers
  @objc
  private func didReceiveMemoryWarning(_ notification: Notification) {
    assert(Thread.isMainThread)
    
    _queue.async { [weak self] in
      guard let `self` = self else {
        return
      }
      
      self._backgroundLastMemoryWarningTimestamp = Timestamp()
      
      guard self._backgroundCachedFrameIndices.count > 1 else {
        return
      }
      
      self._backgroundMaxCachedFrameCount = max(1, self._backgroundMaxCachedFrameCount / 2)
      
      self.purgeCachedFramesIfNeeded()
      
      #if DEBUG
        let indices = self._backgroundCachedFrameIndices
        DispatchQueue.main.async { [weak self] in
          guard let `self` = self else {
            return
          }
          
          self.debugDelegate?.debug_animatedImage(self, didUpdateCachedFramesAt: indices)
        }
      #endif
    }
  }
  
  /// Must be called from the internal queue
  private func purgeCachedFramesIfNeeded() {
    guard _backgroundCachedFrameIndices.count > _backgroundMaxCachedFrameCount else {
      return
    }
    
    guard let lastRequestedFrameIndex = self._backgroundLastRequestedFrameIndex else {
      return
    }
    
    let reservedFrameIndices: IndexSet
    
    let pivotIndex = lastRequestedFrameIndex
    if pivotIndex + self._backgroundMaxCachedFrameCount > self._imageSource.frameCount {
      let firstPart = IndexSet(integersIn: pivotIndex..<self._imageSource.frameCount)
      let secondPart = IndexSet(integersIn: 0..<(pivotIndex + self._backgroundMaxCachedFrameCount - self._imageSource.frameCount))
      
      reservedFrameIndices = firstPart.union(secondPart)
    } else {
      reservedFrameIndices = IndexSet(integersIn: pivotIndex..<pivotIndex+self._backgroundMaxCachedFrameCount)
    }
    
    let redundantIndices = IndexSet(integersIn: 1..<self._imageSource.frameCount).subtracting(reservedFrameIndices)
    
    for i in redundantIndices {
      if self._backgroundCachedFrameIndices.contains(i) {
        self._backgroundCachedFrameIndices.remove(i)
        
        DispatchQueue.main.async { [i, weak self] in
          guard let `self` = self else {
            return
          }
          
          self._frameIndexToImageCache[i] = nil
        }
      }
    }
  }
  
}
