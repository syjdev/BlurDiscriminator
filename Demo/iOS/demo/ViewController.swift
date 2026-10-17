//
//  ViewController.swift
//  demo
//
//  Created by syjdev on 2021/07/12.
//

import PhotosUI
import UIKit
import BlurDiscriminatorKit


class ViewController: UIViewController {
    private enum Phase {
        case loadingModel
        case ready
        case analyzing
        case loadFailed
    }

    private let blurDiscriminator = BlurDiscriminator()
    private var samples = Sample.loadBundled()
    private var selectedIndex = 0
    private var phase = Phase.loadingModel {
        didSet { updateControls() }
    }

    private let scrollView = UIScrollView()
    private let galleryView = UICollectionView(frame: .zero, collectionViewLayout: ViewController.makeGalleryLayout())
    private let panelsStack = UIStackView()
    private let photoPanel = ImagePanel(title: "Photo")
    private let blurMapPanel = ImagePanel(title: "Blur Map",
                                          placeholder: "Tap Run to see which regions are out of focus.",
                                          footer: BlurMapLegendView())
    private let statusLabel = UILabel()
    private let timingView = TimingBreakdownView()
    private let runButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        buildLayout()
        configureRunButton()
        updatePanelsAxis()
        select(sampleAt: 0)
        loadModel()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updatePanelsAxis()
    }

    // MARK: - Model

    private func loadModel() {
        phase = .loadingModel
        showError(nil)
        Task {
            do {
                try await blurDiscriminator.prepare()
                // Core ML's first prediction pays for one-time setup. Spend it on a blank image here,
                // so the first measured Run is as fast as the ones after it.
                if let blank = Self.makeBlankImage() {
                    _ = try await blurDiscriminator.predict(input: blank)
                }
                phase = .ready
            } catch {
                showError("Couldn't load the model: \(error)")
                phase = .loadFailed
            }
        }
    }

    private func runPrediction() {
        let image = samples[selectedIndex].image
        guard let cgImage = image.cgImage else {
            showError("Couldn't read the image's pixels.")
            return
        }
        // `cgImage` is the raw (possibly rotated) pixel buffer, while the image view honours the
        // photo's EXIF orientation. Passing the orientation lets the model read the raw pixels
        // rotated, so the blur map lines up with what is displayed — without redrawing the photo.
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        // One prediction at a time, and the gallery is locked meanwhile, so the result always
        // belongs to the photo on screen.
        phase = .analyzing
        showError(nil)
        Task {
            defer { phase = .ready }

            let clock = ContinuousClock()
            let start = clock.now
            do {
                let observation = try await blurDiscriminator.predict(input: cgImage, orientation: orientation)
                let elapsed = clock.now - start

                blurMapPanel.image = UIImage(cgImage: observation.blurMap)
                blurMapPanel.detail = "\(observation.blurMap.width) × \(observation.blurMap.height) px"
                timingView.show(observation.timings, total: elapsed)
                revealResult()
            } catch {
                showError("Prediction failed: \(error)")
            }
        }
    }

    /// Scrolls the blur map and the timings into view if the screen is too short to show them.
    private func revealResult() {
        view.layoutIfNeeded()
        let result = blurMapPanel.convert(blurMapPanel.bounds, to: scrollView)
            .union(timingView.convert(timingView.bounds, to: scrollView))
        scrollView.scrollRectToVisible(result, animated: true)
    }

    // MARK: - Selection

    private func select(sampleAt index: Int) {
        selectedIndex = index
        let image = samples[index].image
        photoPanel.image = image
        photoPanel.detail = "\(Int(image.size.width * image.scale)) × \(Int(image.size.height * image.scale)) px"

        // Clear the previous result so a photo is never shown next to another photo's blur map.
        blurMapPanel.image = nil
        blurMapPanel.detail = nil
        timingView.reset()
        showError(nil)

        galleryView.selectItem(at: Self.indexPath(forSample: index), animated: false, scrollPosition: [])
    }

    private func addPickedPhoto(_ image: UIImage) {
        samples.insert(Sample(title: "Your photo", image: image), at: 0)
        galleryView.insertItems(at: [Self.indexPath(forSample: 0)])
        select(sampleAt: 0)
        galleryView.scrollToItem(at: Self.indexPath(forSample: 0), at: .centeredHorizontally, animated: true)
    }

    private func presentPhotoPicker() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: - State

    private func updateControls() {
        runButton.isEnabled = phase == .ready || phase == .loadFailed
        runButton.setNeedsUpdateConfiguration()
        galleryView.isUserInteractionEnabled = phase != .analyzing
        galleryView.alpha = phase == .analyzing ? 0.5 : 1
    }

    private func showError(_ message: String?) {
        statusLabel.text = message
        statusLabel.isHidden = message == nil
    }

    // MARK: - Layout

    private func buildLayout() {
        let titleLabel = UILabel()
        titleLabel.text = "Blur Discriminator"
        titleLabel.font = .preferredFont(forTextStyle: .largeTitle).bold()
        titleLabel.adjustsFontForContentSizeCategory = true

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Choose an image, then tap Run to find its blurry regions."
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        galleryView.backgroundColor = .clear
        galleryView.showsHorizontalScrollIndicator = false
        galleryView.clipsToBounds = false
        galleryView.dataSource = self
        galleryView.delegate = self
        galleryView.register(ThumbnailCell.self, forCellWithReuseIdentifier: ThumbnailCell.reuseIdentifier)
        galleryView.register(AddPhotoCell.self, forCellWithReuseIdentifier: AddPhotoCell.reuseIdentifier)
        galleryView.heightAnchor.constraint(equalToConstant: ThumbnailCell.size).isActive = true

        panelsStack.addArrangedSubview(photoPanel)
        panelsStack.addArrangedSubview(blurMapPanel)
        panelsStack.spacing = 16

        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = .systemRed
        statusLabel.numberOfLines = 0

        let contentStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, galleryView,
                                                          panelsStack, statusLabel, timingView])
        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.setCustomSpacing(4, after: titleLabel)
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 20, bottom: 20, trailing: 20)

        scrollView.alwaysBounceVertical = true
        scrollView.addSubview(contentStack)
        view.addSubview(scrollView)
        view.addSubview(runButton)

        let safeArea = view.safeAreaLayoutGuide
        for subview in [scrollView, contentStack, runButton] {
            subview.translatesAutoresizingMaskIntoConstraints = false
        }
        let fullWidthButton = runButton.widthAnchor.constraint(equalTo: safeArea.widthAnchor, constant: -40)
        fullWidthButton.priority = .defaultHigh
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: runButton.topAnchor, constant: -12),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            runButton.centerXAnchor.constraint(equalTo: safeArea.centerXAnchor),
            runButton.widthAnchor.constraint(lessThanOrEqualToConstant: 480),
            fullWidthButton,
            runButton.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -12),
        ])
    }

    private func configureRunButton() {
        runButton.configurationUpdateHandler = { [unowned self] button in
            var configuration = UIButton.Configuration.tinted()
            configuration.buttonSize = .large
            configuration.cornerStyle = .fixed
            configuration.background.cornerRadius = 12
            configuration.background.strokeWidth = 1.5
            configuration.background.strokeColor = button.isEnabled ? .tintColor : .systemGray3
            configuration.imagePadding = 8
            switch phase {
            case .loadingModel:
                configuration.title = "Loading…"
                configuration.showsActivityIndicator = true
            case .ready:
                configuration.title = "Run"
            case .analyzing:
                configuration.title = "Running…"
                configuration.showsActivityIndicator = true
            case .loadFailed:
                configuration.title = "Retry Loading"
            }
            button.configuration = configuration
        }
        runButton.addAction(UIAction { [unowned self] _ in
            if phase == .loadFailed {
                loadModel()
            } else {
                runPrediction()
            }
        }, for: .primaryActionTriggered)
        updateControls()
    }

    /// Side by side when there is room for it (landscape iPhone, iPad), stacked otherwise.
    private func updatePanelsAxis() {
        let sideBySide = traitCollection.verticalSizeClass == .compact || traitCollection.horizontalSizeClass == .regular
        panelsStack.axis = sideBySide ? .horizontal : .vertical
        panelsStack.distribution = sideBySide ? .fillEqually : .fill
        panelsStack.alignment = sideBySide ? .top : .fill
    }

    private static func makeGalleryLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: ThumbnailCell.size, height: ThumbnailCell.size)
        layout.minimumLineSpacing = 10
        return layout
    }

    /// The gallery shows the "add photo" cell first, then the samples.
    private static func indexPath(forSample index: Int) -> IndexPath {
        IndexPath(item: index + 1, section: 0)
    }

    private static func makeBlankImage() -> CGImage? {
        let context = CGContext(data: nil, width: 224, height: 224, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        return context?.makeImage()
    }
}


// MARK: - Gallery

extension ViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        samples.count + 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.item == 0 {
            return collectionView.dequeueReusableCell(withReuseIdentifier: AddPhotoCell.reuseIdentifier, for: indexPath)
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ThumbnailCell.reuseIdentifier,
                                                      for: indexPath) as! ThumbnailCell
        cell.show(samples[indexPath.item - 1])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if indexPath.item == 0 {
            presentPhotoPicker()
            return false
        }
        return true
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        select(sampleAt: indexPath.item - 1)
    }
}


extension ViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
            return
        }
        // The loaded UIImage keeps the photo's EXIF orientation, which `runPrediction` passes on.
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            let image = object as? UIImage
            Task { @MainActor in
                guard let self else { return }
                if let image {
                    self.addPickedPhoto(image)
                } else {
                    self.showError("Couldn't load the photo: \(error.map { "\($0)" } ?? "unsupported format")")
                }
            }
        }
    }
}


/// An image the demo can analyze, bundled or picked from the photo library.
private struct Sample {
    let title: String
    let image: UIImage

    private static let bundledNames = ["cc0_cherry_blossom", "cc0_flower_bokeh", "cc0_ant_sunflower", "cc0_highway_bokeh",
                                       "cc0_misty_river", "cc0_street_bokeh", "cc0_morning_coffee", "cc0_love_in_a_cup",
                                       "cc0_dew_grass", "cc0_panning_gulls", "cc0_clover_closeup", "cc0_icicles"]

    static func loadBundled() -> [Sample] {
        bundledNames.map { name in
            guard let image = UIImage(named: name) else {
                fatalError("couldn't find the image `\(name)`.")
            }
            // "cc0_cherry_blossom" → "Cherry blossom"
            let words = name.dropFirst("cc0_".count).replacingOccurrences(of: "_", with: " ")
            return Sample(title: words.prefix(1).uppercased() + words.dropFirst(), image: image)
        }
    }
}


private final class AddPhotoCell: UICollectionViewCell {
    static let reuseIdentifier = "AddPhotoCell"

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .tertiarySystemFill
        contentView.layer.cornerRadius = 10
        contentView.layer.cornerCurve = .continuous

        let symbol = UIImageView(image: UIImage(systemName: "photo.badge.plus"))
        symbol.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title2)
        symbol.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(symbol)
        NSLayoutConstraint.activate([
            symbol.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            symbol.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])

        isAccessibilityElement = true
        accessibilityLabel = "Choose from photo library"
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


private final class ThumbnailCell: UICollectionViewCell {
    static let reuseIdentifier = "ThumbnailCell"
    static let size: CGFloat = 64

    private let imageView = UIImageView()
    private var thumbnailTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .secondarySystemBackground
        imageView.frame = contentView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(imageView)
        contentView.clipsToBounds = true
        contentView.layer.cornerRadius = 10
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderColor = UIColor.tintColor.cgColor

        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isSelected: Bool {
        didSet {
            contentView.layer.borderWidth = isSelected ? 3 : 0
            accessibilityTraits = isSelected ? [.button, .selected] : .button
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailTask?.cancel()
        imageView.image = nil
    }

    func show(_ sample: Sample) {
        accessibilityLabel = sample.title
        // Decode a small thumbnail off the main thread instead of scaling the full photo on screen.
        let pixels = Self.size * 3
        thumbnailTask = Task { [weak self, image = sample.image] in
            let thumbnail = await image.byPreparingThumbnail(ofSize: CGSize(width: pixels, height: pixels))
            guard !Task.isCancelled else { return }
            self?.imageView.image = thumbnail
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        contentView.layer.borderColor = UIColor.tintColor.cgColor
    }
}


private extension UIFont {
    func bold() -> UIFont {
        fontDescriptor.withSymbolicTraits(.traitBold).map { UIFont(descriptor: $0, size: 0) } ?? self
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
