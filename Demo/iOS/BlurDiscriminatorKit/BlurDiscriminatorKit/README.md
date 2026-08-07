# BlurDiscriminatorKit (Core ML)

이미지의 흐릿한(blur) 영역을 픽셀 단위로 판별하는 iOS 프레임워크입니다.
`snorlax/convert_model.py`로 변환한 Core ML 모델(`BlurSegmentation.mlpackage`)을
프레임워크 내부에 번들로 포함하며, TensorFlow-Lite 경로는 더 이상 사용하지 않습니다.

## 구성

- `BlurDiscriminator.swift` — public actor. 번들된 Core ML 모델을 첫 `predict` 시점에
  lazy 로드해 추론을 수행합니다. 실패는 `BlurDiscriminatorError`로 전달됩니다.
- `BlurObservation.swift` — public 결과 타입. blur map(`CGImage`)과 픽셀 배열,
  `blurRatio(threshold:)`를 제공합니다.
- `CoreMLBlurPredictor.swift` — Vision/Core ML 추론 엔진 (internal).
- `BlurMap.swift` — 모델 출력(sigmoid)을 8-bit grayscale로 변환하는 헬퍼 (internal).
- `BlurSegmentation.mlpackage` — 프레임워크 타겟에 포함되는 Core ML 모델.
  Xcode가 빌드 시 `BlurSegmentation.mlmodelc`로 컴파일해 프레임워크 번들에 넣습니다.

## 모델

- Core ML(mlprogram, FP16), 입력 224×224 RGB (0–255, 1/255 정규화 내장),
  출력 1×224×224×1 float map (밝을수록 blur).
- 재변환:
  ```bash
  cd snorlax
  python convert_model.py            # ./converted/ 아래에 모델 생성
  python convert_model.py --verify   # TF 원본과 출력 비교 검증
  ```
  갱신한 `converted/BlurSegmentation.mlpackage`로 이 디렉토리의 모델을 교체하면 됩니다.

## 사용 예

```swift
import BlurDiscriminatorKit

let discriminator = BlurDiscriminator()

let observation = try await discriminator.predict(input: cgImage)
imageView.image = UIImage(cgImage: observation.blurMap)
print("blur ratio:", observation.blurRatio())  // threshold 기본값 127
```

- 모델이 프레임워크 번들에 포함되므로 앱 타겟에 별도로 모델을 추가할 필요가 없습니다.
  `demo` 앱은 `BlurDiscriminatorKit.framework`를 임베드하는 것만으로 동작합니다.
- 출력 해석: 224×224 grayscale, 밝을수록(>127) blur.
- Core ML 모델은 FP16이라 float 원본 대비 출력 오차가 ~0.003 수준 존재합니다.
  (변환 시 `--coreml-fp32`로 FP32 유지 가능)
