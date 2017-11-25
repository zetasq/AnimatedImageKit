//
//  AnimatedImage.swift
//  AnimatedImageKit-iOS
//
//  Created by Zhu Shengqi on 12/11/2017.
//

import UIKit
import ImageIO
import MobileCoreServices
import os.log
/// An `FLAnimatedImage`'s job is to deliver frames in a highly performant way and works in conjunction with `FLAnimatedImageView`.
///
///  It subclasses `NSObject` and not `UIImage` because it's only an "image" in the sense that a sea lion is a lion.
///
///  It tries to intelligently choose the frame cache size depending on the image and memory situation with the goal to lower CPU usage for smaller ones, lower memory usage for larger ones and always deliver frames for high performant play-back.
///
///  Note: `posterImage`, `size`, `loopCount`, `delayTimes` and `frameCount` don't change after successful initialization.
public class AnimatedImage {
  // MARK: - Subtypes
  
  
  /// An animated image's data size (dimensions * frameCount) category; its value is the max allowed memory (in MB).
  /// E.g.: A 100x200px GIF with 30 frames is ~2.3MB in our pixel format and would fall into the `FLAnimatedImageDataSizeCategoryAll` category.
  ///
  /// - all: All frames permanently in memory (be nice to the CPU)
  /// - `default`: A frame cache of default size in memory (usually real-time performance and keeping low memory profile)
  /// - onDemand: Only keep one frame at the time in memory (easier on memory, slowest performance)
  enum DataSizeCategory: CGFloat {
    case all = 10
    case `default` = 75
    case onDemand = 250
  }
  
  
  /// FrameCAcheSize
  ///
  /// - noLimit: 0 means no specific limit
  /// - lowMemory: The minimum frame cache size; this will produce frames on-demand.
  /// - growAfterMemoryWarning: If we can produce the frames faster than we consume, one frame ahead will already result in a stutter-free playback.
  /// - `default`: Build up a comfy buffer window to cope with CPU hiccups etc.
  enum FrameCacheSize: Int {
    case noLimit = 0
    case lowMemory = 1
    case growAfterMemoryWarning = 2
    case `default` = 5
  }
  
  // MARK: - Class Properties
  /// This is how the fastest browsers do it as per 2012: <http://nullsleep.tumblr.com/post/16524517190/animated-gif-minimum-frame-delay-browser-compatibility>
  public static let MinimumFrameDelayTime: TimeInterval = 0.02
  
  private static var allAnimatedImagesWeak = NSHashTable<AnimatedImage>.weakObjects()
  
  // MARK: - Public Properties
  /// The data the receiver was initialized with; read-only
  public let data: Data
  
  /// Allow to cap the cache size; 0 means no specific limit (default)
  public var maxFrameCacheSize: Int = 0 {
    didSet {
      // Remember whether the new cap will cause the current cache size to shrink; then we'll make sure to purge from the cache if needed.
      if maxFrameCacheSize != oldValue && maxFrameCacheSize < currentFrameCacheSize {
        purgeFrameCacheIfNeeded()
      }
    }
  }
  
  /// Guaranteed to be loaded; usually equivalent to `-imageLazilyCachedAtIndex:0`
  public let posterImage: UIImage
  
  /// 0 means repeating the animation indefinitely
  public let loopCount: Int
  
  public var delayTimesForIndices: [Int: TimeInterval] = [:]
  
  public let frameCount: Int
  
  // MARK: - Private Properties
  /// The optimal number of frames to cache based on image size & number of frames; never changes
  private var frameCacheSizeOptimal: Int
  
  /// Enables predrawing of images to improve performance.
  private let predrawingEnabled: Bool
  
  /// Allow to cap the cache size e.g. when memory warnings occur; 0 means no specific limit (default)
  private var frameCacheSizeMaxInternal: Int = 0 {
    didSet {
      // Remember whether the new cap will cause the current cache size to shrink; then we'll make sure to purge from the cache if needed.
      if frameCacheSizeMaxInternal != oldValue && frameCacheSizeMaxInternal < currentFrameCacheSize {
        purgeFrameCacheIfNeeded()
      }
    }
  }
  
  /// Most recently requested frame index
  private var requestedFrameIndex: Int = 0
  
  
  /// Index of non-purgable poster image; never changes
  private let posterImageFrameIndex: Int
  
  private var cachedFramesForIndices: [Int: UIImage] = [:]
  
  /// Indexes of cached frames
  private var cachedFrameIndices: IndexSet = .init()
  
  /// Indexes of frames that are currently produced in the background
  private var requestedFrameIndices: IndexSet = .init()
  
  /// Default index set with the full range of indexes; never changes
  private let allFramesIndexSet: IndexSet
  
  private var memoryWarningCount: Int = 0
  
  private let serialQueue = DispatchQueue(label: "com.zetasq.AnimatedImageQueue")
  
  private let imageSource: CGImageSource
  
  
  /// The weak proxy is used to break retain cycles with delayed actions from memory warnings.
  //  private let weakProxy: WeakProxy<AnimatedImage>
  
  #if DEBUG
  public weak var debug_delegate: AnimatedImageDebugDelegate?
  #endif
  
  // MARK: - Init & Deinit
  
  // On success, the initializers return an `FLAnimatedImage` with all fields initialized, on failure they return `nil` and an error will be logged.
  public convenience init?(gifData: Data) {
    self.init(gifData: gifData, optimalFrameCacheSize: 0, predrawingEnabled: true)
  }
  
  // Pass 0 for optimalFrameCacheSize to get the default, predrawing is enabled by default.
  public init?(gifData: Data, optimalFrameCacheSize: Int, predrawingEnabled: Bool) {
    guard !gifData.isEmpty else {
      os_log("No animated GIF data supplied", log: animatedImage_log, type: .error)
      return nil
    }
    
    self.data = gifData
    self.predrawingEnabled = predrawingEnabled
    
    // TODO: Add initializer for reading gif data from URL
    guard let imageSource = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
      os_log("Failed to call CGImageSourceCreateWithData for animated GIF data", log: animatedImage_log, type: .error)
      return nil
    }
    
    // Early return if not GIF
    guard let imageSourceContainerType = CGImageSourceGetType(imageSource), UTTypeConformsTo(imageSourceContainerType, kUTTypeGIF) else {
      os_log("Supplied data is not GIF", log: animatedImage_log, type: .error)
      return nil
    }
    
    self.imageSource = imageSource
    
    // Get `LoopCount`
    // Note: 0 means repeating the animation indefinitely.
    // Image properties example:
    // {
    //     FileSize = 314446;
    //     "{GIF}" = {
    //         HasGlobalColorMap = 1;
    //         LoopCount = 0;
    //     };
    // }
    guard let imageProperties = CGImageSourceCopyProperties(imageSource, nil) as? [String: Any] else {
      os_log("Failed to call CGImageSourceCopyProperties", log: animatedImage_log, type: .error)
      return nil
    }
    
    guard let loopCount = (imageProperties[kCGImagePropertyGIFDictionary as String] as? [String: Any])?[kCGImagePropertyGIFLoopCount as String] as? Int else {
      os_log("Failed to read loopCount from GIF image properties", log: animatedImage_log, type: .error)
      return nil
    }
    self.loopCount = loopCount
    
    // Iterate through frame images
    let imageCount = CGImageSourceGetCount(imageSource)
    guard imageCount > 0 else {
      os_log("CGImageSourceGetCount returns non-positive value", log: animatedImage_log, type: .error)
      return nil
    }
    if imageCount == 1 {
      os_log("The GIF only contains a single frame", log: animatedImage_log, type: .info)
    }
    
    var skippedFrameCount = 0
    var delayTimesForIndices: [Int: TimeInterval] = .init(minimumCapacity: imageCount)
    
    var posterImage: UIImage?
    var posterImageFrameIndex: Int?
    
    for i in 0..<imageCount {
      autoreleasepool {
        if let frameCGImage = CGImageSourceCreateImageAtIndex(imageSource, i, nil) {
          let frameUIImage = UIImage(cgImage: frameCGImage)
          
          if posterImage == nil {
            posterImage = frameUIImage
            // Remember index of poster image so we never purge int; also add it to the cache
            posterImageFrameIndex = i
          }
          
          // Get `DelayTime`
          // Note: It's not in (1/100) of a second like still falsely described in the documentation as per iOS 8 (rdar://19507384) but in seconds stored as `kCFNumberFloat32Type`.
          // Frame properties example:
          // {
          //     ColorModel = RGB;
          //     Depth = 8;
          //     PixelHeight = 960;
          //     PixelWidth = 640;
          //     "{GIF}" = {
          //         DelayTime = "0.4";
          //         UnclampedDelayTime = "0.4";
          //     };
          // }
          
          let frameProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, i, nil) as! [String: Any]
          let framePropertiesGIF = frameProperties[kCGImagePropertyGIFDictionary as String] as! [String: Any]
          
          // Try to use the unclamped delay time; fall back to the normal delay time.
          var delayTime: TimeInterval = 0
          if let unclampedDelayTime = framePropertiesGIF[kCGImagePropertyGIFUnclampedDelayTime as String] as? TimeInterval {
            delayTime = unclampedDelayTime
          }
          
          if delayTime == 0 {
            if let
              normalDelayTime =  framePropertiesGIF[kCGImagePropertyGIFDelayTime as String] as? TimeInterval {
              delayTime = normalDelayTime
            }
            
            // If we don't get a delay time from the properties, fall back to `kDelayTimeIntervalDefault` or carry over the preceding frame's value.
            let kDelayTimeIntervalDefault: TimeInterval = 0.1
            if delayTime == 0 {
              if i == 0 || delayTimesForIndices[i-1] == nil {
                os_log("Falling back to default delay time for first frame because none found in GIF properties", log: animatedImage_log, type: .info)
                delayTime = kDelayTimeIntervalDefault
              } else {
                os_log("Falling back to preceding delay time because none found in GIF properties", log: animatedImage_log, type: .info)
                delayTime = delayTimesForIndices[i-1]!
              }
            }
            
            // Support frame delays as low as `MinimumFrameDelayTime`, with anything below being rounded up to `kDelayTimeIntervalDefault` for legacy compatibility.
            // To support the minimum even when rounding errors occur, use an epsilon when comparing. We downcast to float because that's what we get for delayTime from ImageIO.
            if delayTime < AnimatedImage.MinimumFrameDelayTime - .leastNormalMagnitude {
              os_log("Rounding frame's delayTime up to default minimum delayTime", log: animatedImage_log, type: .info)
              delayTime = kDelayTimeIntervalDefault
            }
            delayTimesForIndices[i] = delayTime
          } else {
            skippedFrameCount += 1
            os_log("Frame dropped because failed to call CGImageSourceCreateImageAtIndex", log: animatedImage_log, type: .info)
          }
        }
      }
    }
    
    self.delayTimesForIndices = delayTimesForIndices
    self.frameCount = imageCount
    
    guard posterImage != nil, posterImageFrameIndex != nil else {
      return nil
    }
    self.posterImage = posterImage!
    self.posterImageFrameIndex = posterImageFrameIndex!
    
    // If no value is provided, select a default based on the GIF.
    if optimalFrameCacheSize == 0 {
      // Calculate the optimal frame cache size: try choosing a larger buffer window depending on the predicted image size.
      // It's only dependent on the image size & number of frames and never changes.
      let animatedImageDataSize = CGFloat(posterImage!.cgImage!.bytesPerRow) * posterImage!.size.height * CGFloat(imageCount - skippedFrameCount) / (1024 * 1024)
      if animatedImageDataSize <= DataSizeCategory.all.rawValue {
        self.frameCacheSizeOptimal = imageCount
      } else if animatedImageDataSize <= DataSizeCategory.default.rawValue {
        // This value doesn't depend on device memory much because if we're not keeping all frames in memory we will always be decoding 1 frame up ahead per 1 frame that gets played and at this point we might as well just keep a small buffer just large enough to keep from running out of frames.
        self.frameCacheSizeOptimal = FrameCacheSize.default.rawValue
      } else {
        // The predicted size exceeds the limits to build up a cache and we go into low memory mode from the beginning.
        self.frameCacheSizeOptimal = FrameCacheSize.lowMemory.rawValue
      }
    } else {
      // Use the provided value.
      self.frameCacheSizeOptimal = optimalFrameCacheSize
    }
    // In any case, cap the optimal cache size at the frame count.
    self.frameCacheSizeOptimal = min(self.frameCacheSizeOptimal, imageCount)
    self.cachedFramesForIndices[self.posterImageFrameIndex] = self.posterImage
    self.cachedFrameIndices.insert(self.posterImageFrameIndex)
    
    // Convenience/minor performance optimization; keep an index set handy with the full range to return in `-frameIndexesToCache`.
    
    self.allFramesIndexSet = IndexSet(0..<imageCount)
    NotificationCenter.default.addObserver(self, selector: #selector(self.didReceiveMemoryWarning(_:)), name: .UIApplicationDidReceiveMemoryWarning, object: nil)
  }
  
  // MARK: - Notification Handlers
  @objc
  private func didReceiveMemoryWarning(_ notification: Notification) {
    
  }
  
  // MARK: - Public Methods
  /// Current size of intelligently chosen buffer window; can range in the interval [1..frameCount].
  ///
  /// This is the definite value the frame cache needs to size itself to.
  public var currentFrameCacheSize: Int {
    var cacheSize = frameCacheSizeOptimal
    
    // If set, respect the caps.
    if maxFrameCacheSize > FrameCacheSize.noLimit.rawValue {
      cacheSize = min(cacheSize, maxFrameCacheSize)
    }
    
    if frameCacheSizeMaxInternal > FrameCacheSize.noLimit.rawValue {
      cacheSize = min(cacheSize, frameCacheSizeMaxInternal)
    }
    
    return cacheSize
  }
  
  
  
  
  
  /// Intended to be called from main thread synchronously; will return immediately.
  ///
  /// If the result isn't cached, will return `nil`; the caller should then pause playback, not increment frame counter and keep polling.
  ///
  /// After an initial loading time, depending on `frameCacheSize`, frames should be available immediately from the cache.
  ///
  /// **Note**: both consumer and producer are throttled: consumer by frame timings and producer by the available memory (max buffer window size).
  ///
  /// - Parameter index: frame index
  /// - Returns: the frame image at the index
  public func imageLazilyCached(at index: Int) -> UIImage? {
    guard index < frameCount else {
      os_log("Frame index out of range for animate image", log: animatedImage_log, type: .error)
      return nil
    }
    
    // Remember requested frame index, this influences what we should cache next.
    requestedFrameIndex = index;
    
    #if DEBUG
      debug_delegate?.debug_animatedImage(self, didRequestCachedFrame: index)
    #endif
    
    // Quick check to avoid doing any work if we already have all possible frames cached, a common case.
    if cachedFrameIndices.count < frameCount {
      // If we have frames that should be cached but aren't and aren't requested yet, request them.
      // Exclude existing cached frames, frames already requested, and specially cached poster image.
      var frameIndicesToAddToCache = frameIndicesToCache()
      frameIndicesToAddToCache.subtract(cachedFrameIndices)
      frameIndicesToAddToCache.subtract(requestedFrameIndices)
      frameIndicesToAddToCache.remove(posterImageFrameIndex)
      
      // Asynchronously add frames to our cache
      if !frameIndicesToAddToCache.isEmpty {
        // TODO:
      }
    }
    
    fatalError()
  }
  
  // MARK: - Private Methods
  /// Only called once from `-imageLazilyCachedAtIndex` but factored into its own method for logical grouping.
  private func addFrameIndices(to frameIndicesToAddToCache: IndexSet) {
    // Order matters. First, iterate over the indexes starting from the requested frame index.
    // Then, if there are any indexes before the requested frame index, do those.
    let firstRange = Range(requestedFrameIndex..<frameCount)
    let secondRange = Range(0..<requestedFrameIndex)
    
    if firstRange.count + secondRange.count != frameCount {
      os_log("Two-part frame cache range doesn't equal full range", log: animatedImage_log, type: .error)
    }
    
    // Add to the requested list before we actually kick them off, so they don't get into the queue twice.
    requestedFrameIndices.formUnion(frameIndicesToAddToCache)
    
    // Start streaming requested frames in the background into the cache.
    // Avoid capturing self in the block as there's no reason to keep doing work if the animated image went away.
    serialQueue.async { [weak self] in
      guard let `self` = self else {
        return
      }
      // Produce and cache next needed frame.
      let frameRangeBlock = { (range: CountableRange<Int>) in
        for i in range {
          #if DEBUG
            let predrawBeginTime = CACurrentMediaTime()
          #endif
          
          let image = self.image(at: i)
          
          #if DEBUG
            let predrawDuration = CACurrentMediaTime() - predrawBeginTime
            let slowdownDuration: CFTimeInterval
            
            if let debug_delegate = self.debug_delegate {
              let predrawingSlowdownFactor = debug_delegate.debug_animatedImagePredrawingSlowdownFactor(self)
              slowdownDuration = predrawDuration * (predrawingSlowdownFactor - 1)
              Thread.sleep(forTimeInterval: slowdownDuration)
            } else {
              slowdownDuration = 0
            }
            
            print("Predraw frame \(i) in \((predrawDuration + slowdownDuration) * 1000) ms for animated iamge: \(self)")
          #endif
          
          // The results get returned one by one as soon as they're ready (and not in batch).
          // The benefits of having the first frames as quick as possible outweigh building up a buffer to cope with potential hiccups when the CPU suddenly gets busy.
          if let image = image {
            DispatchQueue.main.async { [weak self] in
              guard let `self` = self else {
                return
              }
              
              self.cachedFramesForIndices[i] = image
              self.cachedFrameIndices.insert(i)
              self.requestedFrameIndices.remove(i)
              
              #if DEBUG
                self.debug_delegate?.debug_animatedImage(self, didUpdateCachedFrames: self.cachedFrameIndices)
              #endif
            }
          }
        }
      }
      for range in frameIndicesToAddToCache.rangeView(of: firstRange) {
        frameRangeBlock(range)
      }
      
      for range in frameIndicesToAddToCache.rangeView(of: secondRange) {
        frameRangeBlock(range)
      }
      
    }
  }
  
  private func image(at index: Int) -> UIImage? {
    // It's very important to use the cached `_imageSource` since the random access to a frame with `CGImageSourceCreateImageAtIndex` turns from an O(1) into an O(n) operation when re-initializing the image source every time.
    guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, index, nil) else {
      return nil
    }
    
    var uiImage = UIImage(cgImage: cgImage)
    // Loading in the image object is only half the work, the displaying image view would still have to synchronosly wait and decode the image, so we go ahead and do that here on the background thread.
    if self.predrawingEnabled {
      uiImage = predrawnImage(from: uiImage)
    }
    
    return uiImage
  }
  
  // Decodes the image's data and draws it off-screen fully in memory; it's thread-safe and hence can be called on a background thread.
  // On success, the returned object is a new `UIImage` instance with the same content as the one passed in.
  // On failure, the returned object is the unchanged passed in one; the data will not be predrawn in memory though and an error will be logged.
  // First inspired by & good Karma to: https://gist.github.com/steipete/1144242
  private func predrawnImage(from imageToPredraw: UIImage) -> UIImage {
    // Always use a device RGB color space for simplicity and predictability what will be going on.
    let deviceRGBColorSpace = CGColorSpaceCreateDeviceRGB()
    
    // Even when the image doesn't have transparency, we have to add the extra channel because Quartz doesn't support other pixel formats than 32 bpp/8 bpc for RGB:
    // kCGImageAlphaNoneSkipFirst, kCGImageAlphaNoneSkipLast, kCGImageAlphaPremultipliedFirst, kCGImageAlphaPremultipliedLast
    // (source: docs "Quartz 2D Programming Guide > Graphics Contexts > Table 2-1 Pixel formats supported for bitmap graphics contexts")
    let numberOfComponents = deviceRGBColorSpace.numberOfComponents + 1 // 4: RGB + A
    
    let width = Int(imageToPredraw.size.width)
    let height = Int(imageToPredraw.size.height)
    let bitsPerComponent = Int(CHAR_BIT)
    
    let bitsPerPixel = bitsPerComponent * numberOfComponents
    let bytesPerPixel = bitsPerPixel / Int(BYTE_SIZE)
    let bytesPerRow = bytesPerPixel * width
    
    var alphaInfo = imageToPredraw.cgImage!.alphaInfo
    // If the alpha info doesn't match to one of the supported formats (see above), pick a reasonable supported one.
    // "For bitmaps created in iOS 3.2 and later, the drawing environment uses the premultiplied ARGB format to store the bitmap data." (source: docs)
    if alphaInfo == .none || alphaInfo == .alphaOnly {
      alphaInfo = .noneSkipFirst
    } else if alphaInfo == .first {
      alphaInfo = .premultipliedFirst
    } else if alphaInfo == .last {
      alphaInfo = .premultipliedLast
    }
    
    // Create our own graphics context to draw to; `UIGraphicsGetCurrentContext`/`UIGraphicsBeginImageContextWithOptions` doesn't create a new context but returns the current one which isn't thread-safe (e.g. main thread could use it at the same time).
    // Note: It's not worth caching the bitmap context for multiple frames ("unique key" would be `width`, `height` and `hasAlpha`), it's ~50% slower. Time spent in libRIP's `CGSBlendBGRA8888toARGB8888` suddenly shoots up -- not sure why.
    guard let bitmapContext = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: deviceRGBColorSpace, bitmapInfo: alphaInfo.rawValue) else {
      os_log("Failed to call CGBitmapContextCreate", log: animatedImage_log, type: .error)
      return imageToPredraw
    }
    
    // Draw image in bitmap context and create image by preserving receiver's properties.
    bitmapContext.draw(imageToPredraw.cgImage!, in: CGRect(x: 0, y: 0, width: imageToPredraw.size.width, height: imageToPredraw.size.height))
    guard let predrawnCGImage = bitmapContext.makeImage() else {
      os_log("Failed to call CGBitmapContextCreateImage", log: animatedImage_log, type: .error)
      return imageToPredraw
    }
    
    let predrawnUIImage = UIImage(cgImage: predrawnCGImage, scale: imageToPredraw.scale, orientation: imageToPredraw.imageOrientation)
    
    return predrawnUIImage
  }
  
  private func frameIndicesToCache() -> IndexSet {
    var indicesToCache: IndexSet
    
    // Quick check to avoid building the index set if the number of frames to cache equals the total frame count.
    if currentFrameCacheSize == frameCount {
      indicesToCache = allFramesIndexSet
    } else {
      indicesToCache = IndexSet()
      
      // Add indexes to the set in two separate blocks- the first starting from the requested frame index, up to the limit or the end.
      // The second, if needed, the remaining number of frames beginning at index zero.
      let firstLength = min(currentFrameCacheSize, frameCount - requestedFrameIndex)
      let firstRange = requestedFrameIndex..<requestedFrameIndex+firstLength
      indicesToCache.insert(integersIn: firstRange)
      
      let secondLength = currentFrameCacheSize - firstLength
      if secondLength > 0 {
        let secondRange = 0..<secondLength
        indicesToCache.insert(integersIn: secondRange)
      }
      
      // Double check our math, before we add the poster image index which may increase it by one.
      if indicesToCache.count != currentFrameCacheSize {
        os_log("Number of frames to cache doesn't equal to expected cache size", log: animatedImage_log, type: .error)
      }
      
      indicesToCache.insert(posterImageFrameIndex)
    }
    
    return indicesToCache
  }
  
  private func purgeFrameCacheIfNeeded() {
    // Purge frames that are currently cached but don't need to be.
    // But not if we're still under the number of frames to cache.
    // This way, if all frames are allowed to be cached (the common case), we can skip all the `NSIndexSet` math below.
    if cachedFrameIndices.count > currentFrameCacheSize {
      var indicesToPurge = cachedFrameIndices
      indicesToPurge.subtract(frameIndicesToCache())
      
      for i in indicesToPurge {
        cachedFrameIndices.remove(i)
        cachedFramesForIndices[i] = nil
        
        // Note: Don't `CGImageSourceRemoveCacheAtIndex` on the image source for frames that we don't want cached any longer to maintain O(1) time access.
        
        #if DEBUG
          DispatchQueue.main.async {
            self.debug_delegate?.debug_animatedImage(self, didUpdateCachedFrames: self.cachedFrameIndices)
          }
        #endif
      }
    }
  }
}

extension AnimatedImage: CustomStringConvertible {
  public var description: String {
    return "\(type(of: self)): size=\(posterImage.size), frameCount=\(self.frameCount)"
  }
}
