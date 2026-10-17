# Model License & Provenance

This document covers the **machine-learning model artifacts** in this
repository — they are licensed **separately** from the source code.

| Artifact | Path |
|---|---|
| Core ML model (float) | `Demo/iOS/BlurDiscriminatorKit/BlurDiscriminatorKit/BlurSegmentation.mlpackage` |
| TensorFlow Lite model (uint8 QAT) | `model/blur_segmentation_qat.tflite` |
| TensorFlow Lite model (float, Android) | `Demo/Android/blurdiscriminatorkit/src/main/assets/blur_segmentation_float.tflite` |

> The **source code** in this repository is licensed under **Apache-2.0**
> (see [`LICENSE`](LICENSE)). The Apache-2.0 license does **not** apply to the
> model artifacts listed above.

## Provenance

These models were trained on **two** academic datasets, **both** of which are
distributed for research with **no explicit license granting commercial use**:

1. **CUHK Blur Detection Dataset**
   (J. Shi, L. Xu, J. Jia, *"Discriminative Blur Detection Features"*, CVPR 2014) —
   <http://www.cse.cuhk.edu.hk/~leojia/projects/dblurdetect/dataset.html>
2. **DUT-DBD Dataset**
   (W. Zhao, F. Zhao, D. Wang, H. Lu, *"Defocus Blur Detection via Multi-stream
   Bottom-Top-Bottom Fully Convolutional Network"*, CVPR 2018) —
   <http://ice.dlut.edu.cn/ZhaoWenda/BTBCRLNet.html>

Because the model derives from both, commercial use requires clearing **both**
datasets — permission for one alone is not sufficient.

## Current status: NON-COMMERCIAL only ⚠️

As of this writing, **commercial-use rights for the underlying dataset have not
been secured**, and the dataset page states no explicit license. Other datasets
from the same lab are marked "cannot be used commercially." Accordingly:

- The model artifacts are provided for **research / non-commercial use only**.
- **Do not embed these models in a closed-source or commercial application.**
- Whether trained model weights constitute a derivative work of their training
  data is a legally unsettled question; this restriction is the conservative,
  good-faith position and is **not legal advice**.

## Demo & test images — resolved (now CC0) ✅

Earlier the repository redistributed original **dataset** images (`dut_test_*`,
`motion*`, `out_of_focus*`) as demo assets and test fixtures. Academic datasets
generally do not grant redistribution rights, so those have been **removed** and
replaced with **CC0 / public-domain** images from Wikimedia Commons (no
attribution required, commercial use allowed). See [`CREDITS.md`](CREDITS.md).

The datasets above therefore now affect **only the trained model weights**, not
the bundled sample images.

> **Note on git history:** the old dataset images still exist in earlier commits.
> Removing them going forward does not purge them from history — a history rewrite
> (`git filter-repo` / BFG) is required to remove them completely.

## To make the model commercially embeddable

One of the following must be resolved **before** shipping the model in a
commercial product:

1. **Obtain written permission / a commercial license** from the authors of
   **both** the CUHK and DUT-DBD datasets for commercial use of models trained on
   them, and record it here (and in `NOTICE`).
2. **Retrain** the model on a dataset whose license permits commercial use (or
   on self-collected data), and replace the artifacts above.

Until then, only the **Apache-2.0-licensed source code** may be reused
commercially — the bundled model may not.
