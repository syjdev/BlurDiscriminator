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
        
        let imageWidth = 224
        let imageHeight = 224
        
        guard let imageData = originImage.pngData() else {
            print("Failed to read image data.")
            exit(1)
        }

        // 이미지 소스 생성
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            print("Failed to create image source.")
            exit(1)
        }

        // 이미지 옵션 설정
        let options: [CFString: Any] = [
            kCGImageSourceShouldAllowFloat as CFString: true, // 부동 소수점 형식의 픽셀 데이터를 허용
        ]

        // 이미지 소스에서 CGImage 생성
        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) else {
            print("Failed to create CGImage.")
            exit(1)
        }

        guard let resized = cgImage.resizeWithPadding(width: imageWidth, height: imageHeight)
        else {
            fatalError("couldn't make the resized image.")
        }
//        self.inputImageView.contentMode = .scaleAspectFit
        self.inputImageView.image = UIImage(cgImage: resized)
        
        let startTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        if let observation = blurDiscriminator.predict(input: resized) {
            self.elapsedTimeLabel.text = String(format: "Time to predict : %.3f ms", (CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            self.outputImageView.image = UIImage(cgImage: observation.blurMap)
        }
    }
}
