//
//  logger.swift
//  AnimatedImageKit-iOS
//
//  Created by Zhu Shengqi on 19/11/2017.
//

import Foundation
import os.log

internal let animatedImage_log = OSLog(subsystem: "com.zetasq.AnimatedImageKit", category: "AnimatedImage")

internal func internalLog(_ type: OSLogType, _ message: String) {
  os_log("%@", log: animatedImage_log, type: type, message)
}

