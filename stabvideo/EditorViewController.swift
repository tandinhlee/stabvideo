//
//  EditorViewController.swift
//  stabvideo
//
//  Created by Dinh Le on 1/17/19.
//  Copyright © 2019 Dinh Le. All rights reserved.
//

import UIKit
import Photos
import IHProgressHUD

class EditorViewController: UIViewController {
    var selectedVideo: PHAsset!
    var radiusValue:Float = 500
    @IBOutlet weak var radiusLabel: UILabel!
    @IBOutlet weak var slider: UISlider!
    @IBAction func valueChange(_ sender: UISlider) {
        let newValue = sender.value
        radiusValue = newValue
        radiusLabel.text = String.localizedStringWithFormat("%.0f", radiusValue);
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        slider.minimumValue = 200;
        slider.maximumValue = 2000;
        slider.value = radiusValue;
        radiusLabel.text = String.localizedStringWithFormat("%.0f", radiusValue);
        // Do any additional setup after loading the view.
    }
    
    @IBAction func startStabilization(_ sender: Any) {
        // HAVE URL NOW
        let ocwrapper = OpenCVWrapper()
        IHProgressHUD.show(withStatus: "Stabilization in progress")
        ocwrapper.stabilizationVideo(selectedVideo,withRadiusMS: radiusValue) { (isSuccess) in
            if isSuccess {
                IHProgressHUD.dismiss()
                IHProgressHUD.showSuccesswithStatus("Success to stabilize video. \nPlease check new video in photo library.")
            } else {
                IHProgressHUD.dismiss()
                IHProgressHUD.showError(withStatus: "Fail to stabilize video.")
            }
        }
        
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    func getFrameRateVideoAsset(asset: PHAsset) -> NSInteger {
//        let options: PHVideoRequestOptions = PHVideoRequestOptions()
        return 0
    }
}
