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
//    let imageNames = ["png_image", "png_image", "png_image", "png_image", "png_image", "png_image", "png_image", "png_image"]
    let imageNames = ["png_image", "image_f67_origin", "image_f264_horizontal_fliped", "image_f477_origin", "keyboard_image", "weeds", "star_cup"]
    var blurDiscriminator: BlurDiscriminator!

    override func viewDidLoad() {
        super.viewDidLoad()
        if blurDiscriminator == nil {
            blurDiscriminator = BlurDiscriminator(modelPath: Bundle.main.path(forResource: "blur_segmentation_quantized", ofType: "tflite") ?? "",
                                                  numberOfThread: 2)
        }
    }
    

    @IBAction func didClickRunButton(_ sender: UIButton) {
        let selectedImageName = self.imageNames[Int.random(in: 0..<imageNames.count)]
        
        guard let originImage = UIImage(named: selectedImageName) else {
            fatalError("couldn't find the image.")
        }

        guard let cgImage = originImage.cgImage else {
            fatalError("couldn't make the resized image.")
        }

        self.inputImageView.image = originImage
        
        let startTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        if let observation = blurDiscriminator.predict(input: cgImage) {
            self.elapsedTimeLabel.text = String(format: "Time to predict : %.3f ms", (CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            self.outputImageView.image = UIImage(cgImage: observation.blurMap)
        }
    }
}
