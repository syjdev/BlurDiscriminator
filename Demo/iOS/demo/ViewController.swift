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
    @IBOutlet weak var runButton: UIButton!
    let imageNames = ["cc0_cherry_blossom", "cc0_flower_bokeh", "cc0_ant_sunflower", "cc0_highway_bokeh", "cc0_misty_river", "cc0_street_bokeh",
                      "cc0_morning_coffee", "cc0_love_in_a_cup", "cc0_dew_grass", "cc0_panning_gulls", "cc0_clover_closeup", "cc0_icicles"]

    private var currentImageIndex: Int = 0
    private let blurDiscriminator = BlurDiscriminator()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Load the model up front so the first "Run" measures inference only, not model loading.
        runButton.isEnabled = false
        elapsedTimeLabel.text = "Loading model…"
        Task {
            do {
                try await blurDiscriminator.prepare()
                elapsedTimeLabel.text = "Ready"
            } catch {
                elapsedTimeLabel.text = "Failed to load the model: \(error)"
            }
            runButton.isEnabled = true
        }
    }

    @IBAction func didClickRunButton(_ sender: UIButton) {
        let selectedImageName = self.imageNames[currentImageIndex]
        currentImageIndex = (currentImageIndex + 1) % imageNames.count

        guard let originImage = UIImage(named: selectedImageName) else {
            fatalError("couldn't find the image.")
        }

        guard let cgImage = originImage.cgImage else {
            fatalError("couldn't get the image's pixels.")
        }

        // `cgImage` is the raw (possibly rotated) pixel buffer, while the image view honours the
        // photo's EXIF orientation. Passing the orientation lets the model read the raw pixels
        // rotated, so the blur map lines up with what is displayed — without redrawing the photo.
        let orientation = CGImagePropertyOrientation(originImage.imageOrientation)

        // One prediction at a time, and the input/output pair is shown together once it is ready,
        // so the screen never pairs an image with another image's blur map.
        runButton.isEnabled = false
        Task {
            defer { runButton.isEnabled = true }

            let startTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
            do {
                let observation = try await blurDiscriminator.predict(input: cgImage, orientation: orientation)
                let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

                inputImageView.image = originImage
                outputImageView.image = UIImage(cgImage: observation.blurMap)
                elapsedTimeLabel.text = String(format: "elapsed time : %.3f ms\nblur ratio : %.1f %%",
                                               elapsed, observation.blurRatio() * 100)
            } catch {
                elapsedTimeLabel.text = "Prediction failed: \(error)"
            }
        }
    }
}


private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
