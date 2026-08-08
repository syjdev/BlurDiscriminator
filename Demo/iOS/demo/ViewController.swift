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
    let imageNames = ["cc0_cherry_blossom", "cc0_flower_bokeh", "cc0_ant_sunflower", "cc0_highway_bokeh", "cc0_misty_river", "cc0_street_bokeh",
                      "cc0_morning_coffee", "cc0_love_in_a_cup", "cc0_dew_grass", "cc0_panning_gulls", "cc0_clover_closeup", "cc0_icicles"]
//    let imageNames = ["cc0_dew_grass"]

    //cc0_dew_grass
    private var currentImageIndex: Int = 0
    private let blurDiscriminator = BlurDiscriminator()

    @IBAction func didClickRunButton(_ sender: UIButton) {
        let selectedImageName = self.imageNames[currentImageIndex]
        currentImageIndex = (currentImageIndex + 1) % imageNames.count

        guard let originImage = UIImage(named: selectedImageName)?.orientedUp() else {
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


private extension UIImage {
    /// Returns an image whose pixel buffer is oriented `.up`, so `cgImage` matches what is displayed.
    ///
    /// `UIImage(named:)` honours a photo's EXIF orientation when drawing, but `.cgImage` exposes the
    /// raw (possibly rotated) pixel buffer with no orientation. Feeding that raw buffer to the model
    /// while showing the EXIF-corrected image makes the blur map look rotated. Normalising here keeps
    /// the model input and the displayed image aligned.
    func orientedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
