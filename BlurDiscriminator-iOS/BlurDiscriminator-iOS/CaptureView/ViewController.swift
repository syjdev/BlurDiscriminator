//
//  ViewController.swift
//  BlurDiscriminator-iOS
//
//  Created by syjdev on 2021/01/23.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    @IBOutlet weak var previewContainerView: UIView!
    @IBOutlet weak var pixelVarianceLabel: UILabel!
    
    private let captureSession = CaptureSession(devicePosition: .back)
    private let blurDiscriminator: BlurDiscriminator
    
    
    required init?(coder: NSCoder) {
        do {
            self.blurDiscriminator = try BlurDiscriminator()
        } catch {
            fatalError("failed to initialize BlurDiscriminator. - \(error)")
        }
        
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession.session)
        videoPreviewLayer.frame.size = self.previewContainerView.frame.size
        videoPreviewLayer.videoGravity = .resizeAspect
        self.previewContainerView.layer.addSublayer(videoPreviewLayer)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.captureSession.delegate = self
        self.captureSession.start()
    }
}


extension ViewController: CaptureSessionDelegate {
    func captureSession(_ captureSession: CaptureSession, didOutput sampleBuffer: CMSampleBuffer) {
        
    }
}
