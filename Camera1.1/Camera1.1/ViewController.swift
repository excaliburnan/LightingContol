//
//  ViewController.swift
//  Camera1.1
//
//  Created by Fei on 14/12/15.
//  Copyright © 2015 Fei. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    let captureSession = AVCaptureSession()
    var previewLayer : AVCaptureVideoPreviewLayer?
    // If we find a device we'll store it here for later use
    var captureDevice : AVCaptureDevice?
    let screenWidth = UIScreen.mainScreen().bounds.size.width
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        captureSession.sessionPreset = AVCaptureSessionPresetHigh
        
        let devices = AVCaptureDevice.devices()
        // Loop through all the capture devices on this phone
        for device in devices {
            // Make sure this particular device supports video
            if (device.hasMediaType(AVMediaTypeVideo)) {
                // Finally check the position and confirm we've got the back camera
                if(device.position == AVCaptureDevicePosition.Back) {
                    captureDevice = device as? AVCaptureDevice
                    if captureDevice != nil {
                        print("Capture device found")
                        beginSession()
                    }
                }
            }
        }
        
    }
    
    func touchPercent(touch : UITouch) -> CGPoint {
        // Get the dimensions of the screen in points
        let screenSize = UIScreen.mainScreen().bounds.size
        // Create an empty CGPoint object set to 0, 0
        var touchPer = CGPointZero
        // Set the x and y values to be the value of the tapped position, divided by the width height of the screen, ranging from 0 to 1
        touchPer.x = touch.locationInView(self.view).x / screenSize.width
        touchPer.y = touch.locationInView(self.view).y / screenSize.height
        // Return the populated CGPoint
        return touchPer
    }
    
    func focusTo(value : Float) {
        if let device = captureDevice {
            do {
                try device.lockForConfiguration()
                device.setFocusModeLockedWithLensPosition(value, completionHandler: { (time) -> Void in
                    //
                })
                device.unlockForConfiguration()
            } catch {
                print(error)
            }
        }
    }
    
    func updateDeviceSettings(focusValue : Float, isoValue : Float) {
        if let device = captureDevice {
            do {
                try device.lockForConfiguration()
                device.setFocusModeLockedWithLensPosition(focusValue, completionHandler: { (time) -> Void in
                    //
                })
                // Adjust the iso to clamp between minIso and maxIso based on the active format
                let minISO = device.activeFormat.minISO
                let maxISO = device.activeFormat.maxISO
                let clampedISO = isoValue * (maxISO - minISO) + minISO
                
                // 0~10, 0~1000
                let timescale = Int32(isoValue * 1000)
                let exposure = CMTimeMake(1, timescale)
                device.setExposureModeCustomWithDuration(exposure, ISO: clampedISO, completionHandler: { (time) -> Void in
                })
//                device.setExposureModeCustomWithDuration(AVCaptureExposureDurationCurrent, ISO: clampedISO, completionHandler: { (time) -> Void in
//                    //
//                })
                device.unlockForConfiguration()
            } catch {
                print(error)
            }
        }
    }
    
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?){
        if let touch = touches.first {
            let touchPer = touchPercent(touch)
            updateDeviceSettings(Float(touchPer.x), isoValue: Float(touchPer.y))
//            let touchcent = touch.locationInView(self.view).x / screenWidth
//            focusTo(Float(touchcent))
        }
        super.touchesBegan(touches, withEvent:event)
    }

    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?){
        if let touch = touches.first {
            let touchPer = touchPercent(touch)
            updateDeviceSettings(Float(touchPer.x), isoValue: Float(touchPer.y))
//            let touchcent = touch.locationInView(self.view).x / screenWidth
//            focusTo(Float(touchcent))
        }
        super.touchesMoved(touches, withEvent:event)
    }
    
    
    func configureDevice() {
        if let device = captureDevice {
            do {
                try device.lockForConfiguration()
                device.focusMode = .Locked
                device.unlockForConfiguration()
            } catch {
                print(error)
            }
        }
    }
    
    func beginSession() {
        configureDevice()
        var possibleCameraInput: AnyObject?
        do{
            possibleCameraInput = try AVCaptureDeviceInput(device: captureDevice)
        }
        catch let error as NSError {
            // Handle any errors
            print(error)
        }
        if let backCameraInput = possibleCameraInput as? AVCaptureDeviceInput {
            if captureSession.canAddInput(backCameraInput) {
                captureSession.addInput(backCameraInput)
            }
        }
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.view.layer.addSublayer(previewLayer!)
        previewLayer?.frame = self.view.layer.frame
        captureSession.startRunning()
    }
    
    
}
