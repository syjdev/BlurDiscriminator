//
//  ViewController.swift
//  demo
//
//  Created by syjdev on 2021/07/12.
//

import UIKit
import BlurDiscriminatorKit
import Accelerate


class ViewController: UIViewController {
    @IBOutlet weak var inputImageView: UIImageView!
    @IBOutlet weak var outputImageView: UIImageView!
    @IBOutlet weak var elapsedTimeLabel: UILabel!
    let imageNames = ["dut_test_0041", "dut_test_0044", "dut_test_0055", "dut_test_0132", "dut_test_0184", "dut_test_0189"]
    private var currentImageIndex: Int = 0
    var blurDiscriminator: BlurDiscriminator!

    override func viewDidLoad() {
        super.viewDidLoad()
        if blurDiscriminator == nil {
            blurDiscriminator = BlurDiscriminator(modelPath: Bundle.main.path(forResource: "blur_segmentation_qat", ofType: "tflite") ?? "",
                                                  numberOfThread: 2)
        }
    }
    

    @IBAction func didClickRunButton(_ sender: UIButton) {
        let selectedImageName = self.imageNames[currentImageIndex]
        currentImageIndex = (currentImageIndex + 1) % imageNames.count
        
        guard let originImage = UIImage(named: selectedImageName) else {
            fatalError("couldn't find the image.")
        }

        guard let cgImage = originImage.cgImage else {
            fatalError("couldn't make the resized image.")
        }

        self.inputImageView.image = originImage

        let startTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        Task {
            guard let observation = await blurDiscriminator.predict(input: cgImage) else { return }
            self.elapsedTimeLabel.text = String(format: "elapsed time : %.3f ms", (CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            self.outputImageView.image = UIImage(cgImage: observation.blurMap)
        }
    }
}
