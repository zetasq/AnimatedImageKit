//
//  PlayPauseButton.swift
//  iOSDemo
//
//  Created by Zhu Shengqi on 26/11/2017.
//

import UIKit

private let kScale: CGFloat = 1
private let kBorderSize: CGFloat = 32 * kScale
private let kBorderWidth: CGFloat = 2 * kScale
private let kSize: CGFloat = kBorderSize + kBorderWidth

private let kPauseLineWidth: CGFloat = 4 * kScale
private let kPauseLineHeight: CGFloat = 15 * kScale
private let kPauseLinesSpace: CGFloat = 4 * kScale
private let kPlayTriangleOffsetX: CGFloat = 1 * kScale
private let kPlayTriangleTipOffsetX: CGFloat = 2 * kScale

private let p1: CGPoint = CGPoint(x: 0, y: 0)
private let p2: CGPoint = CGPoint(x: kPauseLineWidth, y: 0)
private let p3: CGPoint = CGPoint(x: kPauseLineWidth, y: kPauseLineHeight)
private let p4: CGPoint = CGPoint(x: 0, y: kPauseLineHeight)
private let p5: CGPoint = CGPoint(x: kPauseLineWidth + kPauseLinesSpace, y: 0)
private let p6: CGPoint = CGPoint(x: kPauseLineWidth + kPauseLinesSpace + kPauseLineWidth, y: 0)
private let p7: CGPoint = CGPoint(x: kPauseLineWidth + kPauseLinesSpace + kPauseLineWidth, y: kPauseLineHeight)
private let p8: CGPoint = CGPoint(x: kPauseLineWidth + kPauseLinesSpace, y: kPauseLineHeight)


//
//  Displays a  ⃝ with either the ► (play) or ❚❚ (pause) icon and nicely morphs between the two states.
//
class PlayPauseButton: UIControl {
  
  enum AnimationStyle {
    case split
    case splitAndRotate
  }
  
  // MARK: - Public Properties
  var color: UIColor = UIColor(white: 0.04, alpha: 1) {
    didSet {
      if color != oldValue {
        setNeedsLayout()
      }
    }
  }
  
  var animationStyle: AnimationStyle = .splitAndRotate
  
  private var _paused: Bool = true
  var isPaused: Bool {
    get {
      return _paused
    }
    set {
      if _paused != newValue {
        set(paused: newValue, animated: false)
      }
    }
  }
  
  // MARK: - Private Properties
  private var borderShapeLayer: CAShapeLayer?
  private var playPauseShapeLayer: CAShapeLayer?
  
  private lazy var pauseBezierPath: UIBezierPath = {
    let path = UIBezierPath()
    
    path.move(to: p1)
    path.addLine(to: p2)
    path.addLine(to: p3)
    path.addLine(to: p4)
    path.close()
    
    path.move(to: p5)
    path.addLine(to: p6)
    path.addLine(to: p7)
    path.addLine(to: p8)
    path.close()
    
    return path
  }()
  
  
  private lazy var pauseRotateBezierPath: UIBezierPath = {
    let path = UIBezierPath()
    
    path.move(to: p7)
    path.addLine(to: p8)
    path.addLine(to: p5)
    path.addLine(to: p6)
    path.close()
    
    path.move(to: p3)
    path.addLine(to: p4)
    path.addLine(to: p1)
    path.addLine(to: p2)
    path.close()
    
    return path
  }()
  
  private lazy var playBezierPath: UIBezierPath = {
    let path = UIBezierPath()
    
    let kPauseLinesHalfSpace: CGFloat = floor(kPauseLinesSpace / 2)
    let kPauseLineHalfHeight: CGFloat = floor(kPauseLineHeight / 2)
    
    let _p1 = CGPoint(x: p1.x + kPlayTriangleOffsetX, y: p1.y)
    var _p2 = CGPoint(x: p2.x + kPauseLinesHalfSpace, y: p2.y)
    var _p3 = CGPoint(x: p3.x + kPauseLinesHalfSpace, y: p3.y)
    let _p4 = CGPoint(x: p4.x + kPlayTriangleOffsetX, y: p4.y)
    
    var _p5 = CGPoint(x: p5.x - kPauseLinesHalfSpace, y: p5.y)
    var _p6 = CGPoint(x: p6.x + kPlayTriangleTipOffsetX, y: p6.y)
    var _p7 = CGPoint(x: p7.x + kPlayTriangleTipOffsetX, y: p7.y)
    var _p8 = CGPoint(x: p8.x - kPauseLinesHalfSpace, y: p8.y)
    
    let kPlayTriangleWidth: CGFloat = _p6.x - _p1.x
    
    _p2.y += kPauseLineHalfHeight * (_p2.x - kPlayTriangleOffsetX) / kPlayTriangleWidth
    _p3.y -= kPauseLineHalfHeight * (_p3.x - kPlayTriangleOffsetX) / kPlayTriangleWidth
    
    _p5.y += kPauseLineHalfHeight * (_p5.x - kPlayTriangleOffsetX) / kPlayTriangleWidth
    
    _p6.y = kPauseLineHalfHeight
    _p7.y = kPauseLineHalfHeight
    
    _p8.y -= kPauseLineHalfHeight * (_p8.x - kPlayTriangleOffsetX) / kPlayTriangleWidth
    
    path.move(to: _p1)
    path.addLine(to: _p2)
    path.addLine(to: _p3)
    path.addLine(to: _p4)
    path.close()
    
    path.move(to: _p5)
    path.addLine(to: _p6)
    path.addLine(to: _p7)
    path.addLine(to: _p8)
    path.close()
    
    return path
  }()
  
  private lazy var playRotateBezierPath: UIBezierPath = {
    let path = UIBezierPath()
    
    let kPauseLineHalfHeight: CGFloat = floor(kPauseLineHeight / 2)
    
    let _p1 = CGPoint(x: p6.x + kPlayTriangleTipOffsetX, y: kPauseLineHalfHeight)
    let _p2 = _p1
    let _p3 = CGPoint(x: p1.x + kPlayTriangleOffsetX, y: kPauseLineHalfHeight)
    let _p4 = CGPoint(x: p1.x + kPlayTriangleOffsetX, y: p1.y)
    let _p5 = _p1
    let _p6 = _p1
    let _p7 = CGPoint(x: p4.x + kPlayTriangleOffsetX, y: p4.y)
    let _p8 = _p3
    
    path.move(to: _p1)
    path.addLine(to: _p2)
    path.addLine(to: _p3)
    path.addLine(to: _p4)
    path.close()
    
    path.move(to: _p5)
    path.addLine(to: _p6)
    path.addLine(to: _p7)
    path.addLine(to: _p8)
    path.close()
    
    return path
  }()
  
  // MARK: - Init & Deinit
  override init(frame: CGRect) {
    super.init(frame: frame)
    
    sizeToFit()
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - UIView Overrides
  override func tintColorDidChange() {
    super.tintColorDidChange()
    setNeedsLayout()
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    return CGSize(width: kSize, height: kSize)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    if (borderShapeLayer == nil) {
      borderShapeLayer = CAShapeLayer()
      
      let borderRect = bounds.insetBy(dx: ceil(kBorderWidth / 2), dy: ceil(kBorderWidth / 2))
      borderShapeLayer!.path = UIBezierPath(ovalIn: borderRect).cgPath
      borderShapeLayer!.lineWidth = kBorderWidth
      borderShapeLayer?.fillColor = UIColor.clear.cgColor
      
      layer.addSublayer(borderShapeLayer!)
    }
    borderShapeLayer!.strokeColor = color.cgColor
    
    if (playPauseShapeLayer == nil) {
      playPauseShapeLayer = CAShapeLayer()
      
      var playPauseRect = CGRect.zero
      playPauseRect.origin.x = floor((bounds.width - (kPauseLineWidth + kPauseLinesSpace + kPauseLineWidth)) / 2)
      
      playPauseRect.origin.y = floor((bounds.height - kPauseLineHeight) / 2)
      
      playPauseRect.size.width = kPauseLineWidth + kPauseLinesSpace + kPauseLineWidth + kPlayTriangleTipOffsetX
      
      playPauseRect.size.height = kPauseLineHeight
      
      playPauseShapeLayer?.frame = playPauseRect
      
      let path = isPaused ? playRotateBezierPath : pauseBezierPath
      playPauseShapeLayer!.path = path.cgPath
      
      layer.addSublayer(playPauseShapeLayer!)
    }
    playPauseShapeLayer!.fillColor = color.cgColor
  }
  
  // MARK: - Public Methods
  
  func set(paused: Bool, animated: Bool) {
    guard _paused != paused else {
      return
    }
    
    _paused = paused
    
    let fromPath: UIBezierPath
    let toPath: UIBezierPath
    
    switch animationStyle {
    case .split:
      fromPath = isPaused ? pauseBezierPath : playBezierPath
      toPath = isPaused ? playBezierPath : pauseBezierPath
    case .splitAndRotate:
      fromPath = isPaused ? pauseBezierPath : playRotateBezierPath
      toPath = isPaused ? playRotateBezierPath : pauseRotateBezierPath
    }
    
    guard animated else {
      playPauseShapeLayer?.path = toPath.cgPath
      return
    }
    
    let morphAnimation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.path))
    
    morphAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
    
    morphAnimation.isRemovedOnCompletion = false
    morphAnimation.fillMode = kCAFillModeForwards
    
    morphAnimation.duration = 0.3
    morphAnimation.fromValue = fromPath.cgPath
    morphAnimation.toValue = toPath.cgPath
    
    playPauseShapeLayer!.add(morphAnimation, forKey: nil)
  }
  
}
