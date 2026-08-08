<div align = "right">
  <img src="https://img.shields.io/badge/Python-3.7-4AA02C?style=flat" />
  <img src="https://img.shields.io/badge/TFLite-2.4.2-BF53FF?style=flat" />
</div>
<br />

# Intro

__BlurDiscriminator__ is a project that based Deep-Learning for detection blurry image.<br />
BlurDiscriminator classify clear pixels & blurry pixels of image, as below.

<div align = "center">
<img src="https://user-images.githubusercontent.com/17686601/140477196-da561240-2644-4b1a-a2ff-f62e48b94452.png" width="80%"/>
</div>

# Usage

- [iOS](Demo/iOS)

# Dataset

The model was trained on two datasets:

- [CUHK Blur Detection Dataset](http://www.cse.cuhk.edu.hk/~leojia/projects/dblurdetect/dataset.html) (Shi et al., CVPR 2014)
- [DUT-DBD Dataset](http://ice.dlut.edu.cn/ZhaoWenda/BTBCRLNet.html) (Zhao et al., CVPR 2018)

Both are research datasets — see [`MODEL_LICENSE.md`](MODEL_LICENSE.md) for usage terms. <br />

# License

The **source code** is licensed under the **Apache License 2.0** — see
[`LICENSE`](LICENSE) and [`NOTICE`](NOTICE). It may be reused in closed-source
and commercial applications.

The **bundled ML models** (`BlurSegmentation.mlpackage`,
`model/blur_segmentation_qat.tflite`) are **NOT** covered by Apache-2.0. They were
trained on the CUHK Blur Detection Dataset (CVPR 2014) and the DUT-DBD Dataset
(CVPR 2018), and are provided for **research / non-commercial use only**. See
[`MODEL_LICENSE.md`](MODEL_LICENSE.md) before embedding a model in a commercial
product.

The **demo/test images** are CC0 / public-domain images from Wikimedia Commons
(see [`CREDITS.md`](CREDITS.md)) — not dataset images.

```
Copyright 2021 syjdev

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
