//
//  View2.swift
//  SnapchatCamera
//
//  Created by Jared Davidson on 8/26/15.
//  Copyright (c) 2015 Archetapp. All rights reserved.
//

import UIKit
import AVFoundation

class View2: UIViewController,UIImagePickerControllerDelegate,UINavigationControllerDelegate{
    
    var captureSession : AVCaptureSession?
    var backCamera : AVCaptureDevice?
    var stillImageOutput : AVCaptureStillImageOutput?
    var previewLayer : AVCaptureVideoPreviewLayer?
    var didTakePhoto = Bool()
    
    var exposureDurationContext = 0
    var sessionQueue : dispatch_queue_t?
    
    let kExposureDurationPower = 5
    let kExposureMinimunDuration = 1.0/1500

    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var tempImageView: UIImageView!
    @IBOutlet weak var exposureDurationSlider: UISlider!
    @IBOutlet weak var exposureDurationLabel: UILabel!
    
    @IBOutlet weak var exposureTimeLabel: UILabel!
    @IBOutlet weak var minValue: UILabel!
    @IBOutlet weak var maxValue: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //self.addObservers()

        self.exposureDurationSlider.addTarget(self,action: Selector("sliderValueChanged:"), forControlEvents: UIControlEvents.ValueChanged)

    }
    
    func addObservers() {
        self.addObserver(self, forKeyPath: "backCamera.exposureDuration", options: NSKeyValueObservingOptions.New, context: &exposureDurationContext)
        self.addObserver(self, forKeyPath: "backgroundColor", options: NSKeyValueObservingOptions.Old, context: nil)

    }
    
    func removeObservers() {
        self.removeObserver(self, forKeyPath: "backCamera.exposureDuration", context: &exposureDurationContext)
    }
    
    //only change the Label text
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
       // var oldValue = change? [NSKeyValueChangeOldKey] as? NSValue
        let newValue = change? [NSKeyValueChangeNewKey] as? NSValue
        
        if context == &exposureDurationContext {
            if newValue != nil {
                let newDurationSeconds : Double = CMTimeGetSeconds(newValue!.CMTimeValue) //float64
                // adjust exposure in non-custom mode
                if self.backCamera?.exposureMode != AVCaptureExposureMode.Custom {
                    let minDurationSeconds = max(CMTimeGetSeconds((self.backCamera?.activeFormat.minExposureDuration)!),kExposureMinimunDuration)
                    let maxDurationSeconds = CMTimeGetSeconds(self.backCamera!.activeFormat.maxExposureDuration)
                    let p = (newDurationSeconds - minDurationSeconds) / (maxDurationSeconds - minDurationSeconds) //scale to 0~1
                    self.exposureDurationSlider.value = powf(Float(p), Float(1 / kExposureDurationPower))
                    if (newDurationSeconds < 1) {
                        let digits = max (0, 2 + floor(log10(newDurationSeconds)))
                        let text =  NSString(format: "1/%.*f", digits, 1 / newDurationSeconds) as String
                        self.exposureDurationLabel.text = text
                    }
                    else {
                        self.exposureDurationLabel.text = NSString(format: "%.2f", newDurationSeconds) as String
                    }
                }
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        previewLayer?.frame = cameraView.bounds
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        captureSession?.stopRunning()        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = AVCaptureSessionPresetHigh
        
        self.backCamera = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        
//        do{
//            try self.backCamera?.lockForConfiguration()
//            self.backCamera?.exposureMode = AVCaptureExposureMode.Custom
//            self.backCamera?.unlockForConfiguration()
//        }
//        }catch{
//            print(error)
//        }
        
        var input : AVCaptureInput?
        var globalError : NSError?
        do{
            input = try AVCaptureDeviceInput(device: backCamera)
            try self.backCamera?.lockForConfiguration()
            self.backCamera?.exposureMode = AVCaptureExposureMode.Custom
            self.backCamera?.unlockForConfiguration()
        }
        catch let error as NSError {
            input = nil
            globalError = error
        }
        
        if ( globalError == nil && (captureSession?.canAddInput(input)) != nil) {
            captureSession?.addInput(input)
            stillImageOutput = AVCaptureStillImageOutput()
            stillImageOutput?.outputSettings = [
                AVVideoCodecKey  : AVVideoCodecJPEG,
                AVVideoQualityKey: 0.9
            ]
            if ((captureSession?.canAddOutput(stillImageOutput)) != nil) {
                captureSession?.addOutput(stillImageOutput)
                
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                // The ratio of the video (fill the layer)
                //previewLayer?.videoGravity = AVLayerVideoGravityResize
                previewLayer?.videoGravity = AVLayerVideoGravityResizeAspect
                previewLayer?.connection.videoOrientation = AVCaptureVideoOrientation.Portrait
                cameraView.layer.addSublayer(previewLayer!)
                captureSession?.startRunning()
            }
        }
    }
    
    func didPressTakePhoto(){
        if let videoConnection = stillImageOutput?.connectionWithMediaType(AVMediaTypeVideo){
            videoConnection.videoOrientation = AVCaptureVideoOrientation.Portrait
            stillImageOutput?.captureStillImageAsynchronouslyFromConnection(videoConnection, completionHandler: {
                (sampleBuffer, error) in
                if sampleBuffer != nil {
                    let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
                    let dataProvider  = CGDataProviderCreateWithCFData(imageData)
                    let cgImageRef = CGImageCreateWithJPEGDataProvider(dataProvider, nil, true, .RenderingIntentDefault)
                    let image = UIImage(CGImage: cgImageRef!, scale: 1.0, orientation: UIImageOrientation.Right)
                    self.tempImageView.image = image
                    self.tempImageView.hidden = false
                }
            })
        }
    }
    
    func didPressTakeAnother(){
        if didTakePhoto == true{
            tempImageView.hidden = true
            didTakePhoto = false
        }
        else{
            captureSession?.startRunning()
            didTakePhoto = true
            didPressTakePhoto()
        }        
    }
    
    func sliderValueChanged(sender: UISlider) {
        let control = sender
        let p : Double = pow(Double(control.value), Double(kExposureDurationPower))
        let minDurationSeconds : Double = max(CMTimeGetSeconds((self.backCamera?.activeFormat.minExposureDuration)!),kExposureMinimunDuration)
        let maxDurationSeconds : Double = CMTimeGetSeconds(self.backCamera!.activeFormat.maxExposureDuration)
        let newDurationSeconds : Double = p * (maxDurationSeconds - minDurationSeconds) + minDurationSeconds
        
        if(self.backCamera?.exposureMode == AVCaptureExposureMode.Custom){
            if (newDurationSeconds < 1) {
                let digits = Int(max(0, 2 + floor(log10(newDurationSeconds))))
                let text =  NSString(format: "1/%.*f", digits, 1 / newDurationSeconds) as String
                self.exposureDurationLabel.text = text
            }
            else {
                let text = NSString(format: "%.2f", newDurationSeconds) as String
                self.exposureDurationLabel.text = text
            }
        }
        do {
            try self.backCamera?.lockForConfiguration()
            self.backCamera?.setExposureModeCustomWithDuration(CMTimeMakeWithSeconds(newDurationSeconds, 1000*1000*1000), ISO: AVCaptureISOCurrent, completionHandler: { (time) -> Void in
                //
            })
            self.backCamera?.unlockForConfiguration()
        } catch {
            print(error)
        }
        
    }

    @IBAction func takePhoto() {
        didPressTakeAnother()
    }
    
    @IBAction func viewPhoto() {
        let imageFromsource = UIImagePickerController()
        imageFromsource.delegate = self
        imageFromsource.allowsEditing = false
        imageFromsource.sourceType = UIImagePickerControllerSourceType.PhotoLibrary
        self.presentViewController(imageFromsource, animated: true, completion: nil)        
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingImage image: UIImage,
        info: NSDictionary!) {
        let temp : UIImage = info[UIImagePickerControllerOriginalImage] as! UIImage
        self.tempImageView.image = temp
//        self.tempImageView.hidden = false
        self.dismissViewControllerAnimated(true, completion: {})
    
    }
    
    
    
}
