//
//  PhotoOperations.swift
//  ClassicPhotos
//
//  Created by Dang Quoc Huy on 7/12/17.
//  Copyright © 2017 raywenderlich. All rights reserved.
//

import UIKit

enum PhotoRecordState {
  case new
  case downloaded
  case filtered
  case failed
}

class PhotoRecord {
  let name: String
  let url: URL
  var state = PhotoRecordState.new
  var image = UIImage(named: "Placeholder")
  
  init(name: String, url: URL) {
    self.name = name
    self.url = url
  }
}

class PendingOperations {
  lazy var downloadsInProgress = [IndexPath: Operation]()
  lazy var downloadQueue: OperationQueue = {
    var queue = OperationQueue()
    queue.name = "Download queue"
//    queue.maxConcurrentOperationCount = 1
    return queue
  }()
  
  lazy var filtrationsInProgress = [IndexPath: Operation]()
  lazy var filtrationQueue: OperationQueue = {
    var queue = OperationQueue()
    queue.name = "Image Filtration queue"
//    queue.maxConcurrentOperationCount = 1
    return queue
  }()
}

class ImageDownloader: Operation {
  let photoRecord: PhotoRecord
  
  init(photoRecord: PhotoRecord) {
    self.photoRecord = photoRecord
  }
  
  override func main() {
    if isCancelled { return }
    
    do {
      let imageData = try Data(contentsOf: photoRecord.url)
      
      if isCancelled { return }
      
      if imageData.count > 0 {
        photoRecord.image = UIImage(data:imageData)
        photoRecord.state = .downloaded
      }
      else
      {
        photoRecord.state = .failed
        photoRecord.image = UIImage(named: "Failed")
      }
    } catch {
      photoRecord.state = .failed
      photoRecord.image = UIImage(named: "Failed")
    }
  }
}

class ImageFiltration: Operation {
  let photoRecord: PhotoRecord
  
  init(photoRecord: PhotoRecord) {
    self.photoRecord = photoRecord
  }
  
  override func main() {
    if isCancelled { return }
    
    if self.photoRecord.state != .downloaded { return }
    
    if let filteredImage = applySepiaFilter(image: photoRecord.image!) {
      photoRecord.image = filteredImage
      photoRecord.state = .filtered
    }
  }
  
  func applySepiaFilter(image:UIImage) -> UIImage? {
    let inputImage = CIImage(data: UIImagePNGRepresentation(image)!)
    
    if isCancelled { return nil }
    
    let context = CIContext(options: nil)
    let filter = CIFilter(name: "CISepiaTone")
    filter?.setValue(inputImage, forKey: kCIInputImageKey)
    filter?.setValue(0.8, forKey: "inputIntensity")
    
    if isCancelled { return nil }
    
    if let outputImage = filter?.outputImage {
      let outImage = context.createCGImage(outputImage, from: outputImage.extent)
      return UIImage(cgImage: outImage!)
    }
    return nil
  }
}
