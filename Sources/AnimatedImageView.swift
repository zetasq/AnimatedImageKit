//
//  AnimatedImageView.swift
//  AnimatedImageKit-iOS
//
//  Created by Zhu Shengqi on 16/12/2017.
//

import UIKit

public final class AnimatedImageView: UIImageView {
  // MARK: - Class Methods
  private static var defaultRunLoopMode: RunLoopMode {
    return ProcessInfo.processInfo.activeProcessorCount > 1 ? .commonModes : .defaultRunLoopMode
  }
  
  // MARK: - Public Properties
  #if DEBUG
  public weak var debugDelegate: AnimatedImageViewDebugDelegate?
  #endif
  
  public private(set) var currentFrameIndex: Int = 0
  public private(set) var lastFrameImage: UIImage?
  
  public var runLoopMode: RunLoopMode = AnimatedImageView.defaultRunLoopMode {
    didSet {
      if ![RunLoopMode.defaultRunLoopMode, RunLoopMode.commonModes].contains(runLoopMode) {
        assert(false, "Invalid run loop mode: \(runLoopMode)")
        runLoopMode = .defaultRunLoopMode
      }
    }
  }
  
  // MARK: Private Properties
  private var _animatedImage: AnimatedImage?
  
  private var _loopCounter: LoopCounter = .init(loopCount: .infinity)
  
  private var _accumulator: TimeInterval = 0
  
  private var _animationDisplayLink: CADisplayLink?
  
  private var _needsDisplayWhenImageBecomesAvailable: Bool = false
  
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
    _animationDisplayLink?.invalidate()
  }
  
  // MARK: - UIView Overrides
  public override func didMoveToSuperview() {
    super.didMoveToSuperview()
    
    animateIfNeeded()
  }
  
  public override func didMoveToWindow() {
    super.didMoveToWindow()
    
    animateIfNeeded()
  }
  
  public override var alpha: CGFloat {
    didSet {
      animateIfNeeded()
    }
  }
  
  public override var isHidden: Bool {
    didSet {
      animateIfNeeded()
    }
  }
  
  public override var intrinsicContentSize: CGSize {
    if animatedImage != nil {
      return image?.size ?? .zero
    } else {
      return super.intrinsicContentSize
    }
  }
  
  public override func display(_ layer: CALayer) {
    layer.contents = image?.cgImage
  }
  
  // MARK: - UIImageView Overrides
  public override var image: UIImage? {
    get {
      if _animatedImage != nil {
        return lastFrameImage
      } else {
        return super.image
      }
    }
    set {
      stopAnimating()
      
      if newValue != nil {
        animatedImage = nil
      }
      super.image = newValue
    }
  }
  
  public override var isAnimating: Bool {
    if _animatedImage != nil {
      if let displayLink = _animationDisplayLink {
        return !displayLink.isPaused
      } else {
        return false
      }
    } else {
      return super.isAnimating
    }
  }
  
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
  
  public override func startAnimating() {
    guard !isAnimating else {
      return
    }
    
    guard let currentAnimatedImage = _animatedImage else {
      super.startAnimating()
      return
    }
    
    if _animationDisplayLink == nil {
      let weakProxy = WeakProxy(target: self)
      _animationDisplayLink = CADisplayLink(target: weakProxy, selector: #selector(self.displayLinkDidRefresh(_:)))
      _animationDisplayLink!.add(to: .main, forMode: runLoopMode)
    }

    _animationDisplayLink!.preferredFramesPerSecond = max(1, min(60, Int(1.0 / currentAnimatedImage.frameDelayGCD)))
    
    _animationDisplayLink!.isPaused = false
  }
  
  public override func stopAnimating() {
    guard isAnimating else {
      return
    }
    
    guard _animatedImage != nil else {
      super.stopAnimating()
      return
    }
    
    _animationDisplayLink?.isPaused = true
  }
  
  // MARK: - Public Methods
  public var animatedImage: AnimatedImage? {
    get {
      return _animatedImage
    }
    set {
      guard newValue !== _animatedImage else {
        return
      }
      
      if let newAnimatedImage = newValue {
        super.image = nil
        super.isHighlighted = false
        invalidateIntrinsicContentSize()
        
        currentFrameIndex = 0
        lastFrameImage = newAnimatedImage.posterImage
        
        _loopCounter = .init(loopCount: newAnimatedImage.loopCount)
      } else {
        stopAnimating()
        
        currentFrameIndex = 0
        lastFrameImage = nil
        
        _loopCounter = .init(loopCount: .infinity)
      }
      
      _accumulator = 0
      
      _animatedImage = newValue
      
      layer.setNeedsDisplay()
      animateIfNeeded()
    }
  }
  
  
  // MARK: - Action Handlers
  @objc
  private func displayLinkDidRefresh(_ displayLink: CADisplayLink) {
    guard isAnimating else {
      return
    }
    
    guard let currentAnimatedImage = _animatedImage else {
      return
    }
    
    let displayLinkFireInterval = displayLink.duration * 60 / TimeInterval(displayLink.preferredFramesPerSecond)
    
    if let cachedImage = currentAnimatedImage.imageCached(at: currentFrameIndex) {
      lastFrameImage = cachedImage
      
      if _needsDisplayWhenImageBecomesAvailable {
        layer.setNeedsDisplay()
        _needsDisplayWhenImageBecomesAvailable = false
      }
    } else {
      #if DEBUG
        debugDelegate?.debug_animatedImageView(self, waitingForFrameAt: currentFrameIndex, duration: displayLinkFireInterval)
      #endif
    }
    
    var delayTime = currentAnimatedImage.frameDelays[currentFrameIndex]
    
    _accumulator += displayLinkFireInterval
    
    while _accumulator >= delayTime {
      _accumulator -= delayTime
      currentFrameIndex = (currentFrameIndex + 1) % currentAnimatedImage.frameCount
      delayTime = currentAnimatedImage.frameDelays[currentFrameIndex]
      
      if currentFrameIndex == 0 {
        _loopCounter.increaseCount()
        
        if _loopCounter.finished {
          stopAnimating()
          return
        }
      }
      
      _needsDisplayWhenImageBecomesAvailable = true
    }
  }
  
  // MARK: - Private Methods
  private func animateIfNeeded() {
    let isVisible = window != nil && !isHidden && alpha > 0
    
    if _animatedImage != nil && isVisible {
      startAnimating()
    } else {
      stopAnimating()
    }
  }
}
