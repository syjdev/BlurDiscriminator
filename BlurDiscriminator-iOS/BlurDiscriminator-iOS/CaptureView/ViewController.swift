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
    private let ciContext = CIContext()
    
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
        videoPreviewLayer.videoGravity = .resizeAspectFill
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
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let attachments = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault,
                                                              target: sampleBuffer,
                                                              attachmentMode: kCMAttachmentMode_ShouldPropagate) as? [CIImageOption: Any]
        else {
            return
        }
        
        let ciImage = CIImage(cvImageBuffer: imageBuffer, options: attachments)
        guard let cgImage = self.ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        let result = self.blurDiscriminator.calculateGrayscaledPixelVariance(cgImage: cgImage)
        switch result {
        case .success(let variance):
            DispatchQueue.main.async {
                self.pixelVarianceLabel.text = "\(variance)"
            }
        default:
            break
        }
        
    }
}
