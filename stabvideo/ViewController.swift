//
//  ViewController.swift
//  stabvideo
//
//  Created by Dinh Le on 1/17/19.
//  Copyright © 2019 Dinh Le. All rights reserved.
//

import UIKit
import Photos

class ViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {

    @IBOutlet weak var collectionView: UICollectionView!
    var videos: PHFetchResult<PHAsset>?
    var selectedVideo: PHAsset?
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showEditor" {
            let destination = segue.destination as! EditorViewController
            destination.selectedVideo = selectedVideo
        }
    }
    @IBAction func startLoadVideo(_ sender: Any) {
        getAssetFromPhoto()
    }
    
    // user photos array in collectionView for disaplying video thumnail
    func getAssetFromPhoto() {
        let options = PHFetchOptions()
        options.sortDescriptors = [ NSSortDescriptor(key: "creationDate", ascending: true) ]
        options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
        videos = PHAsset.fetchAssets(with: options)
        collectionView.reloadData()
    }
    // MARK: UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return videos?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "VideoCollectionViewCell", for: indexPath) as! VideoCollectionViewCell
        let asset = videos?.object(at: indexPath.row)
        if (asset?.mediaType == PHAssetMediaType.video) {
            cell.videoThumbnail.image = asset != nil ? fullResolutionImageData(asset: asset!) : nil
        }
        return cell
    }
    // MARK: UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedVideo =  videos?.object(at: indexPath.row)
        self.performSegue(withIdentifier: "showEditor", sender: self)
    }
    func fullResolutionImageData(asset: PHAsset) -> UIImage? {
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.resizeMode = .none
        options.isNetworkAccessAllowed = false
        options.version = .current
        var image: UIImage? = nil
        _ = PHCachingImageManager().requestImageData(for: asset, options: options) { (imageData, dataUTI, orientation, info) in
            if let data = imageData {
                image = UIImage(data: data)
            }
        }
        return image
    }
}

