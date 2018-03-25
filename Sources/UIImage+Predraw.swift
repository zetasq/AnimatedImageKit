//
//  UIImage+Predraw.swift
//  AnimatedImageKit-iOS
//
//  Created by Zhu Shengqi on 10/12/2017.
//

import UIKit

extension UIImage {
  
  public final func predrawImage() -> UIImage? {
    // Always use a device RGB color space for simplicity and predictability what will be going on.
    let deviceRGBColorSpace = CGColorSpaceCreateDeviceRGB()
    
    // Even when the image doesn't have transparency, we have to add the extra channel because Quartz doesn't support other pixel formats than 32 bpp/8 bpc for RGB:
    // kCGImageAlphaNoneSkipFirst, kCGImageAlphaNoneSkipLast, kCGImageAlphaPremultipliedFirst, kCGImageAlphaPremultipliedLast
    // (source: docs "Quartz 2D Programming Guide > Graphics Contexts > Table 2-1 Pixel formats supported for bitmap graphics contexts")
    let numberOfComponents = deviceRGBColorSpace.numberOfComponents + 1 // 4: RGB + A
    
    let widthInPixel = Int(self.size.width * self.scale)
    let heightInPixel = Int(self.size.height * self.scale)
    let bitsPerComponent = Int(CHAR_BIT)
    
    let bitsPerPixel = bitsPerComponent * numberOfComponents
    let bytesPerPixel = bitsPerPixel / Int(BYTE_SIZE)
    let bytesPerRow = bytesPerPixel * widthInPixel
    
    var alphaInfo = self.cgImage!.alphaInfo
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
    guard let bitmapContext = CGContext(data: nil, width: widthInPixel, height: heightInPixel, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: deviceRGBColorSpace, bitmapInfo: alphaInfo.rawValue) else {
      internalLog(.error, "Failed to call CGBitmapContextCreate")

      return nil
    }
    
    // Draw image in bitmap context and create image by preserving receiver's properties.
    bitmapContext.draw(self.cgImage!, in: CGRect(x: 0, y: 0, width: widthInPixel, height: heightInPixel))
    guard let predrawnCGImage = bitmapContext.makeImage() else {
      internalLog(.error, "Failed to call CGBitmapContextCreateImage")
      return nil
    }
    
    let predrawnUIImage = UIImage(cgImage: predrawnCGImage, scale: UIScreen.main.scale, orientation: self.imageOrientation)
    
    return predrawnUIImage
  }
  
}
