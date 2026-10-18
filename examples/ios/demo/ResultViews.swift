//
//  ResultViews.swift
//  demo
//

import UIKit
import PixelBlurDetectorKit


/// A titled image box: the photo or its blur map.
final class ImagePanel: UIView {
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let imageView = UIImageView()
    private let placeholderLabel = UILabel()

    var image: UIImage? {
        get { imageView.image }
        set {
            imageView.image = newValue
            placeholderLabel.isHidden = newValue != nil
        }
    }

    /// Secondary text next to the title, e.g. the pixel size.
    var detail: String? {
        get { detailLabel.text }
        set { detailLabel.text = newValue }
    }

    init(title: String, placeholder: String? = nil, footer: UIView? = nil) {
        super.init(frame: .zero)

        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        detailLabel.font = .monospacedDigitSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .caption1).pointSize,
                                                      weight: .regular)
        detailLabel.textColor = .secondaryLabel
        detailLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let header = UIStackView(arrangedSubviews: [titleLabel, UIView(), detailLabel])
        header.alignment = .firstBaseline
        header.spacing = 8

        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .secondarySystemBackground
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.layer.cornerCurve = .continuous
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = title
        imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 2.0 / 3.0).isActive = true

        placeholderLabel.text = placeholder
        placeholderLabel.font = .preferredFont(forTextStyle: .subheadline)
        placeholderLabel.adjustsFontForContentSizeCategory = true
        placeholderLabel.textColor = .secondaryLabel
        placeholderLabel.textAlignment = .center
        placeholderLabel.numberOfLines = 0
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        imageView.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: 24),
            placeholderLabel.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -24),
        ])

        let stack = UIStackView(arrangedSubviews: [header, imageView] + (footer.map { [$0] } ?? []))
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


/// The key for reading a blur map: dark is sharp, bright is blurry.
final class BlurMapLegendView: UIView {
    private final class GradientView: UIView {
        override class var layerClass: AnyClass { CAGradientLayer.self }
    }

    init() {
        super.init(frame: .zero)

        let gradient = GradientView()
        let gradientLayer = gradient.layer as! CAGradientLayer
        gradientLayer.colors = [UIColor.black.cgColor, UIColor.white.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.layer.cornerRadius = 3
        gradient.layer.borderWidth = 1 / UIScreen.main.scale
        gradient.layer.borderColor = UIColor.separator.cgColor
        gradient.clipsToBounds = true
        gradient.heightAnchor.constraint(equalToConstant: 6).isActive = true

        let sharpLabel = Self.makeLabel("Sharp")
        let blurryLabel = Self.makeLabel("Blurry")
        let row = UIStackView(arrangedSubviews: [sharpLabel, gradient, blurryLabel])
        row.alignment = .center
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        isAccessibilityElement = true
        accessibilityLabel = "Dark areas are sharp, bright areas are blurry."
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func makeLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .caption1)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }
}


/// Where the time of one prediction went: the model itself versus the work around it.
final class TimingBreakdownView: UIView {
    private let preprocessingValue = UILabel()
    private let inferenceValue = UILabel()
    private let postprocessingValue = UILabel()
    private let otherValue = UILabel()
    private let totalValue = UILabel()

    init() {
        super.init(frame: .zero)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous

        let titleLabel = UILabel()
        titleLabel.text = "Elapsed Time"
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true

        let separator = UIView()
        separator.backgroundColor = .separator
        separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true

        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            Self.makeRow("Preprocessing", "Orient, resize and pad to the model input", preprocessingValue),
            Self.makeRow("Model inference", "Core ML prediction", inferenceValue, emphasized: true),
            Self.makeRow("Postprocessing", "Crop the output and build the blur map", postprocessingValue),
            Self.makeRow("Other", "Queueing and thread hand-offs", otherValue),
            separator,
            Self.makeRow("Total", nil, totalValue, emphasized: true),
        ])
        stack.axis = .vertical
        stack.spacing = 10
        stack.setCustomSpacing(14, after: titleLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])

        reset()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// - Parameters:
    ///   - timings: The stages measured inside the framework.
    ///   - total: The end-to-end time of the `predict` call; whatever the stages don't cover is "Other".
    func show(_ timings: BlurObservation.Timings, total: Duration) {
        preprocessingValue.text = Self.format(timings.preprocessing)
        inferenceValue.text = Self.format(timings.inference)
        postprocessingValue.text = Self.format(timings.postprocessing)
        otherValue.text = Self.format(max(total - timings.total, .zero))
        totalValue.text = Self.format(total)
    }

    func reset() {
        for label in [preprocessingValue, inferenceValue, postprocessingValue, otherValue, totalValue] {
            label.text = "—"
        }
    }

    private static func format(_ duration: Duration) -> String {
        let (seconds, attoseconds) = duration.components
        let milliseconds = Double(seconds) * 1_000 + Double(attoseconds) / 1e15
        return String(format: "%.2f ms", milliseconds)
    }

    private static func makeRow(_ title: String, _ subtitle: String?, _ valueLabel: UILabel,
                                emphasized: Bool = false) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        if emphasized {
            titleLabel.font = .systemFont(ofSize: titleLabel.font.pointSize, weight: .semibold)
        }

        let labels = UIStackView(arrangedSubviews: [titleLabel])
        labels.axis = .vertical
        labels.spacing = 2
        if let subtitle {
            let subtitleLabel = UILabel()
            subtitleLabel.text = subtitle
            subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
            subtitleLabel.textColor = .secondaryLabel
            subtitleLabel.numberOfLines = 0
            labels.addArrangedSubview(subtitleLabel)
        }

        let size = UIFont.preferredFont(forTextStyle: .subheadline).pointSize
        valueLabel.font = .monospacedDigitSystemFont(ofSize: size, weight: emphasized ? .semibold : .regular)
        valueLabel.textAlignment = .right
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [labels, valueLabel])
        row.alignment = .firstBaseline
        row.spacing = 12
        return row
    }
}
