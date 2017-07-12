//
//  ListViewController.swift
//  ClassicPhotos
//
//  Created by Richard Turton on 03/07/2014.
//  Copyright (c) 2014 raywenderlich. All rights reserved.
//

import UIKit
import CoreImage

let dataSourceURL = URL(string:"http://www.raywenderlich.com/downloads/ClassicPhotosDictionary.plist")

class ListViewController: UITableViewController {
  var photos = [PhotoRecord]()
  let pendingOperations = PendingOperations()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.title = "Classic Photos"
    fetchPhotoDetails()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  // #pragma mark - Table view data source
  
  override func tableView(_ tableView: UITableView?, numberOfRowsInSection section: Int) -> Int {
    return photos.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "CellIdentifier", for: indexPath) 
    
    if cell.accessoryView == nil {
      let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
      cell.accessoryView = indicator
    }
    let indicator = cell.accessoryView as! UIActivityIndicatorView
    
    let photoDetails = photos[indexPath.row]
    
    cell.textLabel?.text = photoDetails.name
    cell.imageView?.image = photoDetails.image
    
    switch photoDetails.state {
    case .filtered:
      indicator.stopAnimating()
    case .failed:
      indicator.stopAnimating()
      cell.textLabel?.text = "Failed to load"
    case .new, .downloaded:
      indicator.startAnimating()
      if (!tableView.isDragging && !tableView.isDecelerating) {
        startOperationsForPhotoRecord(photoDetails,indexPath: indexPath)
      }
    }
    
    return cell
  }
  
  func fetchPhotoDetails() {
    let request = URLRequest(url:dataSourceURL!)
    UIApplication.shared.isNetworkActivityIndicatorVisible = true
    
    NSURLConnection.sendAsynchronousRequest(request, queue: OperationQueue.main) { [weak self] response, data, error in
      if let data = data {
        do {
          let datasourceDictionary = try PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: nil) as! NSDictionary
          
          for item in datasourceDictionary {
            let name = item.key as? String
            let url = URL(string: item.value as? String ?? "")
            if let name = name, let url = url {
              let photoRecord = PhotoRecord(name: name, url: url)
              self?.photos.append(photoRecord)
            }
          }
          self?.tableView.reloadData()
        } catch let error {
          let alert = UIAlertView(title: "Oops!",
                                  message: error.localizedDescription,
                                  delegate:nil, cancelButtonTitle:"OK")
          alert.show()
        }
      } else if let error = error {
        let alert = UIAlertView(title: "Oops!",
                                message: error.localizedDescription,
                                delegate:nil, cancelButtonTitle:"OK")
        alert.show()
      }
      UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
  }
  
  func startOperationsForPhotoRecord(_ photoDetails: PhotoRecord, indexPath: IndexPath) {
    switch (photoDetails.state) {
    case .new:
      startDownloadForRecord(photoDetails, indexPath: indexPath)
    case .downloaded:
      startFiltrationForRecord(photoDetails, indexPath: indexPath)
    default:
      NSLog("do nothing")
    }
  }
  
  func startDownloadForRecord(_ photoDetails: PhotoRecord, indexPath: IndexPath){
    if pendingOperations.downloadsInProgress[indexPath] != nil { return }
    
    let downloader = ImageDownloader(photoRecord: photoDetails)
    downloader.completionBlock = {
      if downloader.isCancelled { return }
      
      DispatchQueue.main.async { [weak self] in
        _ = self?.pendingOperations.downloadsInProgress.removeValue(forKey: indexPath)
        self?.tableView.reloadRows(at: [indexPath], with: .fade)
      }
    }
    
    pendingOperations.downloadsInProgress[indexPath] = downloader
    pendingOperations.downloadQueue.addOperation(downloader)
  }
  
  func startFiltrationForRecord(_ photoDetails: PhotoRecord, indexPath: IndexPath) {
    if pendingOperations.filtrationsInProgress[indexPath] != nil { return }
    
    let filterer = ImageFiltration(photoRecord: photoDetails)
    filterer.completionBlock = {
      if filterer.isCancelled { return }
      
      DispatchQueue.main.async { [weak self] in
        _ = self?.pendingOperations.filtrationsInProgress.removeValue(forKey: indexPath)
        self?.tableView.reloadRows(at: [indexPath], with: .fade)
      }
    }
    
    pendingOperations.filtrationsInProgress[indexPath] = filterer
    pendingOperations.filtrationQueue.addOperation(filterer)
  }
  
  override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    suspendAllOperations()
  }
  
  override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if !decelerate {
      loadImagesForOnscreenCells()
      resumeAllOperations()
    }
  }
  
  override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    loadImagesForOnscreenCells()
    resumeAllOperations()
  }
  
  func suspendAllOperations () {
    pendingOperations.downloadQueue.isSuspended = true
    pendingOperations.filtrationQueue.isSuspended = true
  }
  
  func resumeAllOperations () {
    pendingOperations.downloadQueue.isSuspended = false
    pendingOperations.filtrationQueue.isSuspended = false
  }

  func loadImagesForOnscreenCells () {
    if let pathsArray = tableView.indexPathsForVisibleRows {
      var allPendingOperations = Set(pendingOperations.downloadsInProgress.keys)
      allPendingOperations = allPendingOperations.union(pendingOperations.filtrationsInProgress.keys)
      
      var toBeCancelled = allPendingOperations
      let visiblePaths = Set(pathsArray)
      toBeCancelled = toBeCancelled.subtracting(visiblePaths)
      
      var toBeStarted = visiblePaths
      toBeStarted = toBeStarted.subtracting(allPendingOperations)
      
      for indexPath in toBeCancelled {
        if let pendingDownload = pendingOperations.downloadsInProgress[indexPath] {
          pendingDownload.cancel()
        }
        pendingOperations.downloadsInProgress.removeValue(forKey: indexPath)
        if let pendingFiltration = pendingOperations.filtrationsInProgress[indexPath] {
          pendingFiltration.cancel()
        }
        pendingOperations.filtrationsInProgress.removeValue(forKey: indexPath)
      }
      
      for indexPath in toBeStarted {
        let indexPath = indexPath as IndexPath
        let recordToProcess = self.photos[indexPath.row]
        startOperationsForPhotoRecord(recordToProcess, indexPath: indexPath)
      }
    }
  }
  
}
