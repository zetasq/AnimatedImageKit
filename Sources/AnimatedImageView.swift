//
//  AnimatedImageView.swift
//  AnimatedImageKit-iOS
//
//  Created by Zhu Shengqi on 25/11/2017.
//

import UIKit
import os.log

#if DEBUG
  public protocol AnimatedImageViewDebugDelegate: class {
    
    func debug_animatedImageView(_ animatedImageView: AnimatedImageView, waitingForFrameAt index: Int, duration: TimeInterval)
    
  }
#endif

public final class AnimatedImageView: UIImageView {
  
  // MARK: - Class Methods
  private static var defaultRunLoopMode: RunLoopMode {
    return ProcessInfo.processInfo.activeProcessorCount > 1 ? .commonModes : .defaultRunLoopMode
  }
  
  // MARK: - Public Properties
  public var animatedImage: AnimatedImage? {
    didSet {
      guard animatedImage !== oldValue else {
        return
      }
      
      if animatedImage != nil {
        super.image = nil
        super.isHighlighted = false
        invalidateIntrinsicContentSize()
      } else {
        stopAnimating()
      }
      
      currentFrame = animatedImage?.posterImage
      currentFrameIndex = 0
      
      if (animatedImage?.loopCount ?? 0) > 0 {
        loopCountdown = animatedImage?.loopCount ?? 0
      } else {
        loopCountdown = .max
      }
      
      accumulator = 0
      
      updateShouldAnimate()
      if shouldAnimate {
        startAnimating()
      }
      
      layer.setNeedsDisplay()
    }
  }
  
  public var loopCompletionBlock: ((Int) -> Void)?
  
  public private(set) var currentFrame: UIImage?
  
  public private(set) var currentFrameIndex: Int = 0
  
  public var runLoopMode: RunLoopMode = AnimatedImageView.defaultRunLoopMode {
    didSet {
      if ![RunLoopMode.defaultRunLoopMode, RunLoopMode.commonModes].contains(runLoopMode) {
        assert(false, "Invalid run loop mode: \(runLoopMode)")
        runLoopMode = .defaultRunLoopMode
      }
    }
  }
  
  // MARK: - Private Properties
  private var loopCountdown: Int = 0
  
  private var accumulator: TimeInterval = 0
  
  private var displayLink: CADisplayLink?
  
  private var shouldAnimate: Bool = false
  
  private var needsDisplayWhenImageBecomesAvailable: Bool = false
  
  #if DEBUG
  private weak var debug_delegate: AnimatedImageViewDebugDelegate?
  #endif
  
  // MARK: - Init & Deinit
  public override init(image: UIImage?) {
    super.init(image: image)
    
    self.accessibilityIgnoresInvertColors = true
  }
  
  public override init(image: UIImage?, highlightedImage: UIImage?) {
    super.init(image: image, highlightedImage: highlightedImage)
    
    self.accessibilityIgnoresInvertColors = true
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    
    self.accessibilityIgnoresInvertColors = true
  }
  
  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)

    self.accessibilityIgnoresInvertColors = true
  }
  
  deinit {
    displayLink?.invalidate()
  }
  
  // MARK: - View Hierarchy Changes
  public override func didMoveToSuperview() {
    super.didMoveToSuperview()
    
    updateShouldAnimate()
    if shouldAnimate {
      startAnimating()
    } else {
      stopAnimating()
    }
  }
  
  public override func didMoveToWindow() {
    super.didMoveToWindow()
    
    updateShouldAnimate()
    if shouldAnimate {
      startAnimating()
    } else {
      stopAnimating()
    }
  }
  
  // MARK: - UIView Overrides
  override public var alpha: CGFloat {
    didSet {
      updateShouldAnimate()
      if shouldAnimate {
        startAnimating()
      } else {
        stopAnimating()
      }
    }
  }
  
  override public var isHidden: Bool {
    didSet {
      updateShouldAnimate()
      if shouldAnimate {
        startAnimating()
      } else {
        stopAnimating()
      }
    }
  }
  
  // MARK: - AutoLayout
  public override var intrinsicContentSize: CGSize {
    var size = super.intrinsicContentSize
    
    if animatedImage != nil {
      size = image?.size ?? .zero
    }
    
    return size
  }
  
  // MARK: - UIImageView Overrides
  public override var image: UIImage? {
    get {
      if animatedImage != nil {
        return currentFrame
      } else {
        return super.image
      }
    }
    set {
      if newValue != nil {
        animatedImage = nil
      }
      super.image = newValue
    }
  }
  
  // MARK: - Animating Images
  private func frameDelayGCD() -> TimeInterval {
    let kGCDPrecision: TimeInterval = 2.0 / AnimatedImage.MinimumFrameDelayTime
    
    guard let delays = animatedImage?.delayTimesForIndices.values else {
      return 0
    }
    
    var scaledGCD = lrint((delays.first ?? 0) * kGCDPrecision)
    for value in delays {
      scaledGCD = GCD(lrint(value * kGCDPrecision), scaledGCD)
    }
    
    return TimeInterval(scaledGCD) / kGCDPrecision
  }
  
  public override func startAnimating() {
    guard animatedImage != nil else {
      super.startAnimating()
      return
    }
    
    if displayLink == nil {
      let weakProxy = WeakProxy(target: self)
      displayLink = CADisplayLink(target: weakProxy, selector: #selector(self.displayDidRefresh(_:)))
      
      displayLink!.add(to: .main, forMode: runLoopMode)
    }
    
    let kDisplayRefreshRate: TimeInterval = 60
    displayLink!.preferredFramesPerSecond = max(Int(frameDelayGCD() * kDisplayRefreshRate), 1)
    
    displayLink!.isPaused = false
  }
  
  public override func stopAnimating() {
    if animatedImage != nil {
      displayLink?.isPaused = true
    } else {
      super.stopAnimating()
    }
  }
  
  public override var isAnimating: Bool {
    if animatedImage != nil {
      return displayLink != nil && !displayLink!.isPaused
    } else {
      return super.isAnimating
    }
  }
  
  // MARK: - Highlighted Image Unsupported
  public override var isHighlighted: Bool {
    get {
      return super.isHighlighted
    }
    set {
      if animatedImage == nil {
        super.isHighlighted = newValue
      }
    }
  }
  
  // MARK: - Animation
  private func updateShouldAnimate() {
    let isVisible = window != nil && superview != nil && !isHidden && alpha > 0
    shouldAnimate = animatedImage != nil && isVisible
  }
  
  @objc
  private func displayDidRefresh(_ displayLink: CADisplayLink) {
    guard shouldAnimate else {
      os_log("Trying to animate image when we shouldn't", log: animatedImage_log, type: .error)
      return
    }
    
    guard let delayTime = animatedImage?.delayTimesForIndices[currentFrameIndex] else {
      currentFrameIndex += 1
      return
    }
    
    guard let image = animatedImage?.imageLazilyCached(at: currentFrameIndex) else {
      os_log("Waiting for frame for animated image", log: animatedImage_log, type: .debug)
      
      #if DEBUG
        debug_delegate?.debug_animatedImageView(self, waitingForFrameAt: currentFrameIndex, duration: displayLink.duration * TimeInterval(displayLink.preferredFramesPerSecond))
      #endif
      
      return
    }
    
    os_log("Showing frame for animated image", log: animatedImage_log, type: .debug)
    currentFrame = image
    if needsDisplayWhenImageBecomesAvailable {
      layer.setNeedsDisplay()
      needsDisplayWhenImageBecomesAvailable = false
    }
    
    accumulator += displayLink.duration * TimeInterval(displayLink.preferredFramesPerSecond)
    
    while accumulator >= delayTime {
      accumulator -= delayTime
      currentFrameIndex += 1;
      
      if currentFrameIndex >= animatedImage?.frameCount ?? 0 {
        loopCountdown -= 1
        loopCompletionBlock?(loopCountdown)
        
        if loopCountdown == 0 {
          stopAnimating()
          return
        }
        
        currentFrameIndex = 0
      }
      
      needsDisplayWhenImageBecomesAvailable = true
    }
  }
  
  public override func display(_ layer: CALayer) {
    layer.contents = image?.cgImage
  }
}
