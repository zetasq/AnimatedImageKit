//
//  DebugView.swift
//  iOSDemo
//
//  Created by Zhu Shengqi on 17/12/2017.
//

import UIKit
import AnimatedImageKit

final class DebugView: UIView {
  // MARK: - Subtypes
  enum Style {
    case `default`
    case condensed
  }
  
  // MARK: - Class Properties
  override static var layerClass: AnyClass {
    return CAGradientLayer.self
  }
  
  // MARK: - Public Properties
  weak var animatedImage: AnimatedImage? {
    didSet {
      guard let image = animatedImage else {
        return
      }
      
      #if DEBUG
        image.debugDelegate = self
      #endif
      memoryUsageView.graphView.numberOfDisplayedDataPoints = image.frameCount * 3
      memoryUsageView.graphView.maxDataPoint = image.size.width * image.size.height * CGFloat(4 * image.frameCount) / CGFloat(1024 * 1024)
      
      frameDelayView.graphView.numberOfDisplayedDataPoints = image.frameCount * 3
      
      frameCacheView.image = image
    }
  }
  weak var animatedImageView: AnimatedImageView? {
    didSet {
      #if DEBUG
        animatedImageView?.debugDelegate = self
      #endif
    }
  }
  
  let style: Style
  
  // MARK: - Private Properties
  private lazy var topStackView: UIStackView = {
    let topStackView = UIStackView()
    
    topStackView.axis = .horizontal
    topStackView.alignment = .center
    topStackView.spacing = 20
    topStackView.distribution = .fillEqually
    
    return topStackView
  }()
  
  private lazy var memoryUsageView: GraphContainerView = {
    let memoryUsageView = GraphContainerView(style: .memoryUsage)
    
    memoryUsageView.shouldShowDescription = style == .default
    
    return memoryUsageView
  }()
  
  private lazy var frameDelayView: GraphContainerView = {
    let frameDelayView = GraphContainerView(style: .frameDelay)
    
    frameDelayView.shouldShowDescription = style == .default
    
    return frameDelayView
  }()
  
  private lazy var bottomStackView: UIStackView = {
    let bottomStackView = UIStackView()
    
    bottomStackView.axis = .horizontal
    bottomStackView.alignment = .center
    bottomStackView.spacing = 10
    bottomStackView.distribution = .fill
    
    return bottomStackView
  }()
  
  private lazy var frameCacheView: FrameCacheView = {
    let frameCacheView = FrameCacheView()
    
    return frameCacheView
  }()
  
  private lazy var playheadView: PlayheadView = {
    let playheadView = PlayheadView()
    
    return playheadView
  }()
  
  private var playheadViewCenterXConstraint: NSLayoutConstraint!
  
  private lazy var playPauseButton: PlayPauseButton = {
    let playPauseButton = PlayPauseButton()
    
    playPauseButton.isPaused = false
    playPauseButton.color = UIColor(white: 0.8, alpha: 1)
    playPauseButton.addTarget(self, action: #selector(self.playPauseButtonPressed(_:)), for: .touchUpInside)
    
    return playPauseButton
  }()
  
  private var gradientLayer: CAGradientLayer {
    return self.layer as! CAGradientLayer
  }
  
  private var currentFrameDelay: TimeInterval = 0
  
  // MARK: - Init & Deinit
  init(style: Style) {
    self.style = style
    
    super.init(frame: .zero)
    
    gradientLayer.colors = [
      UIColor(white: 0, alpha: 0.85).cgColor,
      UIColor(white: 0, alpha: 0).cgColor,
      UIColor(white: 0, alpha: 0).cgColor,
      UIColor(white: 0, alpha: 0.85).cgColor
    ]
    
    gradientLayer.locations = [0, 0.22, 0.78, 1]
    
    setupUI()
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setupUI() {
    self.addSubview(topStackView)
    topStackView.translatesAutoresizingMaskIntoConstraints = false
    topStackView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
    topStackView.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
    topStackView.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
    
    do {
      topStackView.addArrangedSubview(memoryUsageView)
      memoryUsageView.translatesAutoresizingMaskIntoConstraints = false
      memoryUsageView.heightAnchor.constraint(equalToConstant: 50).isActive = true
      
      topStackView.addArrangedSubview(frameDelayView)
      frameDelayView.translatesAutoresizingMaskIntoConstraints = false
      frameDelayView.heightAnchor.constraint(equalToConstant: 50).isActive = true
    }
    
    self.addSubview(bottomStackView)
    bottomStackView.translatesAutoresizingMaskIntoConstraints = false
    bottomStackView.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor).isActive = true
    bottomStackView.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
    bottomStackView.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
    
    do {
      bottomStackView.addArrangedSubview(frameCacheView)
      frameCacheView.translatesAutoresizingMaskIntoConstraints = false
      frameCacheView.heightAnchor.constraint(equalToConstant: 50).isActive = true
      
      bottomStackView.addSubview(playheadView)
      playheadView.translatesAutoresizingMaskIntoConstraints = false
      playheadView.widthAnchor.constraint(equalToConstant: 10).isActive = true
      playheadView.heightAnchor.constraint(equalToConstant: 10).isActive = true
      playheadView.bottomAnchor.constraint(equalTo: frameCacheView.topAnchor).isActive = true
      self.playheadViewCenterXConstraint = playheadView.centerXAnchor.constraint(equalTo: frameCacheView.leftAnchor, constant: 0)
      self.playheadViewCenterXConstraint.isActive = true
      
      bottomStackView.addArrangedSubview(playPauseButton)
      playPauseButton.translatesAutoresizingMaskIntoConstraints = false
      playPauseButton.heightAnchor.constraint(equalTo: frameCacheView.heightAnchor).isActive = true
      playPauseButton.widthAnchor.constraint(equalTo: playPauseButton.heightAnchor).isActive = true
    }
  }
  
  @objc
  private func playPauseButtonPressed(_ button: PlayPauseButton) {
    if playPauseButton.isPaused {
      playPauseButton.set(paused: false, animated: true)
      animatedImageView?.startAnimating()
    } else {
      playPauseButton.set(paused: true, animated: true)
      animatedImageView?.stopAnimating()
    }
  }
}

// MARK: - AnimatedImage DebugDelegate
#if DEBUG
  extension DebugView: AnimatedImageDebugDelegate {
    
    func debug_animatedImage(_ animatedImage: AnimatedImage, didUpdateCachedFramesAt cachedFramesIndices: IndexSet) {
      frameCacheView.cachedFramesIndices = cachedFramesIndices
    }
    
    func debug_animatedImage(_ animatedImage: AnimatedImage, didRequestCachedFrameAt index: Int) {
      guard frameCacheView.requestedFrameIndex != index else {
        return
      }
      
      frameCacheView.requestedFrameIndex = index
      
      let delayTime = animatedImage.frameDelays[index]
      let frameViewRect = frameCacheView.subviews[index].frame
      
      playheadViewCenterXConstraint.constant = frameViewRect.minX
      bottomStackView.layoutIfNeeded()
      
      UIView.animate(withDuration: delayTime, delay: 0, options: [.curveLinear, .beginFromCurrentState], animations: {
        self.playheadViewCenterXConstraint.constant = frameViewRect.maxX
        self.bottomStackView.layoutIfNeeded()
      }, completion: nil)
      
      memoryUsageView.graphView.add(animatedImage.memoryUsage)
      frameDelayView.graphView.add(CGFloat(currentFrameDelay))
      currentFrameDelay = 0
    }
  }
#endif

// MARK: - AnimatedImageView DebugDelegate
extension DebugView: AnimatedImageViewDebugDelegate {
  
  func debug_animatedImageView(_ animatedImageView: AnimatedImageView, waitingForFrameAt index: Int, duration: TimeInterval) {
    currentFrameDelay += duration
  }
  
}
