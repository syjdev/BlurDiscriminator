//
//  ViewController.swift
//  demo
//
//  Created by syjdev on 2021/07/12.
//

import UIKit
import BlurDiscriminatorKit


class ViewController: UIViewController {
    @IBOutlet weak var inputImageView: UIImageView!
    @IBOutlet weak var outputImageView: UIImageView!
    @IBOutlet weak var elapsedTimeLabel: UILabel!
    let imageNames = ["dut_test_0041", "motion0296", "dut_test_0044", "motion0293", "dut_test_0055", "dut_test_0132", "out_of_focus0691", "dut_test_0184", "dut_test_0189", "out_of_focus0697"]
    private var currentImageIndex: Int = 0
    private let blurDiscriminator = BlurDiscriminator()

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
            guard let observation = try? await blurDiscriminator.predict(input: cgImage) else { return }
            self.elapsedTimeLabel.text = String(format: "elapsed time : %.3f ms", (CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            self.outputImageView.image = UIImage(cgImage: observation.blurMap)
        }
    }
}
