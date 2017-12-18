//
//  GraphView.swift
//  iOSDemo
//
//  Created by Zhu Shengqi on 17/12/2017.
//

import UIKit

final class GraphView: UIView {
  
  override static var layerClass: AnyClass {
    return CAShapeLayer.self
  }
  
  var numberOfDisplayedDataPoints = 50 {
    didSet {
      if numberOfDisplayedDataPoints <= 1 {
        numberOfDisplayedDataPoints = 10
      }
      setNeedsLayout()
    }
  }
  
  var maxDataPoint: CGFloat = 100 {
    didSet {
      if maxDataPoint <= 0 {
        maxDataPoint = _dataPoints.reduce(0, +)
      }
      setNeedsLayout()
    }
  }
  
  var fillColor: CGColor? {
    get {
      return shapeLayer.fillColor
    }
    set {
      shapeLayer.fillColor = newValue
    }
  }
  
  var maxHeightScaleFactor: CGFloat = 0.9 {
    didSet {
      setNeedsLayout()
    }
  }
  
  private var _dataPoints: [CGFloat] = []
  
  private var shapeLayer: CAShapeLayer {
    return self.layer as! CAShapeLayer
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    
    shapeLayer.masksToBounds = true
    shapeLayer.borderWidth = 1
    shapeLayer.borderColor = UIColor(white: 0.8, alpha: 1).cgColor
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func add(_ dataPoint: CGFloat) {
    if _dataPoints.count >= numberOfDisplayedDataPoints {
      _dataPoints.remove(at: 0)
    }
    
    _dataPoints.append(dataPoint)
    setNeedsLayout()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    
    let graphStepWidth = bounds.width / CGFloat(numberOfDisplayedDataPoints - 1)
    let scaleFactor: CGFloat
    if maxDataPoint > 0 {
      scaleFactor = bounds.height * maxHeightScaleFactor / maxDataPoint
    } else {
      scaleFactor = 0
    }
    
    var currentX: CGFloat = bounds.minX
    
    let path = UIBezierPath()
    path.move(to: CGPoint(x: currentX, y: bounds.maxY))
    
    for i in 0..<numberOfDisplayedDataPoints {
      let graphHeight: CGFloat
      if i < _dataPoints.count {
        graphHeight = 1 + max(2, _dataPoints[i] * scaleFactor)
      } else {
        graphHeight = 1
      }
      
      let graphY = bounds.maxY - graphHeight
      path.addLine(to: CGPoint(x: currentX, y: graphY))
      currentX += graphStepWidth
    }
    
    path.addLine(to: CGPoint(x: currentX, y: bounds.maxY))
    shapeLayer.path = path.cgPath
  }
}
