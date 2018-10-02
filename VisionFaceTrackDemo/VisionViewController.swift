//
//  VisionViewController.swift
//  VisionFaceTrackDemo
//
//  Created by David Rynn on 10/1/18.
//  Copyright © 2018 David Rynn. All rights reserved.
//

import UIKit
import AVKit
import Vision

class VisionViewController: UIViewController {

    @IBOutlet weak var previewView: UIView!
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var session: AVCaptureSession?
    private var frontCamera: AVCaptureDevice?
    private var frontCameraResolution: CGPoint?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoDataOutputQueue: DispatchQueue?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAVCaptureSession()
    }
    
    // MARK: AVCapture Setup
    
    /// - Tag: CreateCaptureSession
    fileprivate func setupAVCaptureSession(){
        let captureSession = AVCaptureSession()
        do {
            let inputDevice = try self.getCameraAndResolution(for: captureSession)
            self.configureVideoDataOuput(for: inputDevice.device, resolution: inputDevice.resolution, captureSession: captureSession)
            self.designatePreviewLayer(for: captureSession)
            self.session = captureSession
        } catch let executionError as NSError {
            self.presentError(executionError)
        } catch {
            self.presentErrorAlert(message: "An unexpected failure has occured")
        }
        
        self.teardownAVCapture()
        
        self.session = nil
    }
    
    fileprivate func designatePreviewLayer(for captureSession: AVCaptureSession) {
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer = videoPreviewLayer
        
        videoPreviewLayer.name = "CameraPreview"
        videoPreviewLayer.backgroundColor = UIColor.green.cgColor
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
    }
    
    fileprivate func teardownAVCapture() {
        self.videoDataOutput = nil
        self.videoDataOutputQueue = nil
        if let previewLayer = self.previewLayer {
            previewLayer.removeFromSuperlayer()
            self.previewLayer = nil
        }
    }
    
    fileprivate func getCameraAndResolution(for captureSession: AVCaptureSession) throws -> (device: AVCaptureDevice, resolution: CGPoint) {
        //discoverySession discovers which devices are available for the requiest, like a query
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front)
        if let frontCamera = deviceDiscoverySession.devices.first, let cameraInput = try? AVCaptureDeviceInput(device: frontCamera) {
            if captureSession.canAddInput(cameraInput) {
                captureSession.addInput(cameraInput)
            }
            
            if let highestResolutionAndFormat = self.getHighestResolution420FormatAndFormat(for: frontCamera) {
                try frontCamera.lockForConfiguration()
                frontCamera.activeFormat = highestResolutionAndFormat.format
                frontCamera.unlockForConfiguration()
                return (frontCamera, highestResolutionAndFormat.resolution)
            }
        }
            
        throw NSError(domain: "ViewController", code: 1, userInfo: nil)
    }
    
    fileprivate func getHighestResolution420FormatAndFormat(for device: AVCaptureDevice) -> (resolution: CGPoint, format: AVCaptureDevice.Format)? {
        var highestResolutionFormat: AVCaptureDevice.Format?
        var highestResolutionDimensions = CMVideoDimensions(width: 0, height: 0)
        
        device.formats.forEach { format in
            let deviceFormat = format as AVCaptureDevice.Format
            let deviceFormatDescription = deviceFormat.formatDescription
            if CMFormatDescriptionGetMediaType(deviceFormatDescription) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
                let candidateDimension = CMVideoFormatDescriptionGetDimensions(deviceFormatDescription)
                if (highestResolutionFormat == nil) || (candidateDimension.width > highestResolutionDimensions.width) {
                    highestResolutionDimensions = candidateDimension
                    highestResolutionFormat = deviceFormat
                }
            }
        }
        if let highestResolutionFormat = highestResolutionFormat {
            let resolution = CGPoint(x: CGFloat(highestResolutionDimensions.width), y: CGFloat(highestResolutionDimensions.height))
            return (resolution: resolution, format: highestResolutionFormat)
        }
        return nil
    }
    
    // MARK: Helper Methods for Error Presentation
    
    fileprivate func presentErrorAlert(withTitle title: String = "Unexpected Failure", message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        self.present(alertController, animated: true)
    }
    
    fileprivate func presentError(_ error: NSError) {
        self.presentErrorAlert(withTitle: "Failed with error \(error.code)", message: error.localizedDescription)
    }


}

extension VisionViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    fileprivate func configureVideoDataOuput(for inputDevice: AVCaptureDevice, resolution: CGPoint, captureSession: AVCaptureSession) {
        //outputs video data that is process-able by apis.
        let videoDataOutput = AVCaptureVideoDataOutput()
        
        //discards video data that is not processed before next frame is processed.
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        /* Create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured.
         * A serial dispatch queue must be used to guarantee that video frames will be delivered in order. */
        let videoDataOutputQueue = DispatchQueue(label: "edu.self.VisionFaceTrackDemo")
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
        if let captureConnection = videoDataOutput.connection(with: .video) {
            captureConnection.isEnabled = true
            //conditional is probably not necessary - see docs\
            //intrisics refers to digital equivalent of 3d stats information from traditional camera
            if captureConnection.isCameraIntrinsicMatrixDeliverySupported {
                captureConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
        }
        self.videoDataOutput = videoDataOutput
        self.videoDataOutputQueue = videoDataOutputQueue
        
    }
}
