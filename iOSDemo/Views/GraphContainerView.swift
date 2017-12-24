//
//  GraphView.swift
//  iOSDemo
//
//  Created by Zhu Shengqi on 17/12/2017.
//

import UIKit

final class GraphContainerView: UIView {
  
  enum Style {
    case memoryUsage
    case frameDelay
    
    var hint: String {
      switch self {
      case .memoryUsage:
        return "Memory usage\n(in MB)"
      case .frameDelay:
        return "Frame delay\n(in ms)"
      }
    }
  }
  
  let style: Style
  
  var shouldShowDescription: Bool = true {
    didSet {
      if shouldShowDescription != oldValue {
        descriptionLabel.isHidden = !shouldShowDescription
      }
    }
  }
  
  private lazy var canvasView: UIStackView = {
    let canvasView = UIStackView()
    
    canvasView.axis = .horizontal
    canvasView.alignment = .center
    canvasView.spacing = 5
    canvasView.distribution = .fill
    
    return canvasView
  }()
  
  lazy var graphView: GraphView = {
    let graphView = GraphView()
    
    switch style {
    case .memoryUsage:
      graphView.fillColor = UIColor(white: 1, alpha: 0.5).cgColor
    case .frameDelay:
      graphView.fillColor = UIColor(red: 0.8, green: 0.15, blue: 0.15, alpha: 0.6).cgColor
    }
    
    return graphView
  }()
  
  private lazy var axisLabelStackView: UIStackView = {
    let axisLabelStackView = UIStackView()
    
    axisLabelStackView.axis = .vertical
    axisLabelStackView.alignment = .leading
    axisLabelStackView.spacing = 5
    axisLabelStackView.distribution = .equalSpacing
    
    return axisLabelStackView
  }()
  
  private lazy var topYAxisLabel: UILabel = {
    let axisLabel = UILabel()
    
    axisLabel.backgroundColor = .clear
    axisLabel.textColor = UIColor(white: 0.8, alpha: 1)
    axisLabel.font = UIFont(name: "HelveticaNeue-Medium", size: 13)
    
    return axisLabel
  }()
  
  private lazy var bottomYAxisLabel: UILabel = {
    let axisLabel = UILabel()
    
    axisLabel.backgroundColor = .clear
    axisLabel.textColor = UIColor(white: 0.8, alpha: 1)
    axisLabel.font = UIFont(name: "HelveticaNeue-Medium", size: 13)
    
    axisLabel.text = "0"
    axisLabel.sizeToFit()
    
    return axisLabel
  }()
  
  private lazy var descriptionLabel: UILabel = {
    let descLabel = UILabel()
    
    descLabel.text = self.style.hint
    descLabel.numberOfLines = 0
    descLabel.backgroundColor = .clear
    descLabel.textColor = UIColor(white: 0.8, alpha: 1)
    descLabel.font = UIFont(name: "HelveticaNeue-Medium", size: 13)
    
    descLabel.isHidden = !shouldShowDescription
    
    return descLabel
  }()
  
  private var maxDataPointObservation: NSKeyValueObservation?
  
  init(style: Style) {
    self.style = style
    
    super.init(frame: .zero)
    
    isOpaque = false
    setupUI()
    
    maxDataPointObservation = graphView.observe(\.maxDataPoint, options: [.initial, .new]) { [weak self] _, change in
      guard let `self` = self else {
        return
      }
      
      self.topYAxisLabel.text = String.init(format: "%.1f", change.newValue!)
    }
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setupUI() {
    self.addSubview(canvasView)
    canvasView.translatesAutoresizingMaskIntoConstraints = false
    canvasView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
    canvasView.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
    canvasView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
    canvasView.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
    
    canvasView.addArrangedSubview(graphView)
    graphView.translatesAutoresizingMaskIntoConstraints = false
    graphView.heightAnchor.constraint(equalTo: canvasView.heightAnchor).isActive = true
    
    canvasView.addArrangedSubview(axisLabelStackView)
    axisLabelStackView.translatesAutoresizingMaskIntoConstraints = false
    axisLabelStackView.heightAnchor.constraint(equalTo: canvasView.heightAnchor).isActive = true
    do {
      axisLabelStackView.addArrangedSubview(topYAxisLabel)
      axisLabelStackView.addArrangedSubview(bottomYAxisLabel)
    }
    
    canvasView.addArrangedSubview(descriptionLabel)
  }
  
}
