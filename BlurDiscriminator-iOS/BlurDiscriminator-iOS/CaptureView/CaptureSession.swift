//
//  CaptureSession.swift
//  BlurDiscriminator-iOS
//
//  Created by syjdev on 2021/01/24.
//

import AVFoundation


protocol CaptureSessionDelegate: class {
    func captureSession(_ captureSession: CaptureSession, didOutput sampleBuffer: CMSampleBuffer)
}


class CaptureSession: NSObject {
    private let configurationQueue = DispatchQueue(label: "syjdev.BlurDiscriminator-iOS.CaptureSession.configurationQueue")
    private(set) var devicePosition: AVCaptureDevice.Position
    let session = AVCaptureSession()
    
    weak var delegate: CaptureSessionDelegate?
    
    init(devicePosition: AVCaptureDevice.Position) {
        self.devicePosition = devicePosition
        
        super.init()
    }
    
    func configureSession() {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: self.devicePosition)
        else {
            fatalError("failed to find camera - \(#function)")
        }
        
        self.session.sessionPreset = AVCaptureSession.Preset.hd1280x720
        
        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            
            self.session.beginConfiguration()
            if self.session.canAddInput(cameraInput) {
                self.session.addInput(cameraInput)
            }
            
            let videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as String): Int(kCVPixelFormatType_32BGRA)]
            
            if self.session.canAddOutput(videoDataOutput) {
                videoDataOutput.alwaysDiscardsLateVideoFrames = true
                self.session.addOutput(videoDataOutput)
                
                let connection = videoDataOutput.connection(with: .video)
                connection?.videoOrientation = .portrait
                videoDataOutput.setSampleBufferDelegate(self, queue: self.configurationQueue)
            }
            
            self.session.commitConfiguration()
        } catch {
            fatalError("failed to configure a session - \(#function)")
        }
    }
    
    func start() {
        self.configurationQueue.async {
            self.session.startRunning()
        }
    }
}

extension CaptureSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        self.delegate?.captureSession(self, didOutput: sampleBuffer)
    }
}
