# Sample data for AutoLesion / RAMPS

Two public datasets are here. RAMPS needs a **pre-op T1** and a **post-op T1**. Only EPISURG provides both in this folder.

## Layout

```
data/
  IDEAS_sample/          # paper's official pre-op MRI (no post-op T1)
    sub-1/anat/          # T1w + FLAIR
    sub-2/anat/
    docs/
  EPISURG_sample/        # pre + post T1, plus post-op cavity segmentations
    EPISURG/README.md
    EPISURG/subjects/sub-0240/
    EPISURG/subjects/sub-0316/
```

## IDEAS (Taylor et al., 2025) — cited by the RAMPS paper

OpenNeuro [ds005602](https://openneuro.org/datasets/ds005602), CC0.

- What we downloaded: 2 subjects, preoperative 3D T1w and FLAIR (~18 MB).
- Full release: 442 patients (+ 100 controls on the project site). OpenNeuro has **pre-op T1/FLAIR only**.
- Post-op T1 is **not** in the public OpenNeuro dump, so RAMPS cannot be run on IDEAS alone.
- Resection masks and clinical tables (side/lobe of surgery, outcomes) are on Figshare via [cnnp-lab.com/ideas-data](https://www.cnnp-lab.com/ideas-data). Those links are private-link pages and were not downloaded here.

Cite: Taylor et al., *The imaging database for epilepsy and surgery (IDEAS).* Epilepsia 66(2):471–481.

To pull more subjects from OpenNeuro S3 (no login):

```bash
curl -fL -o sub-10_T1w.nii.gz \
  https://s3.amazonaws.com/openneuro.org/ds005602/sub-10/anat/sub-10_T1w.nii.gz
```

## EPISURG (Pérez-García et al., 2020) — runnable RAMPS sample

UCL RDR / Figshare, [10.5522/04/9996158.v1](https://doi.org/10.5522/04/9996158.v1), CC BY-NC-SA 4.0.

- Full archive is one 5.4 GB zip (430 post-op T1s; 269 also have pre-op).
- What we extracted: **sub-0240** and **sub-0316**, each with pre-op T1, post-op T1, and a rater cavity mask (`*-seg-1.nii.gz` in **post-op** space).
- Those segmentations are post-op cavity labels, not RAMPS-style pre-op-space resection masks.

**Data-use terms (from the dataset):** do not re-identify subjects; cite the papers below; do not redistribute the MRI files.

Cite:

- Pérez-García et al., MICCAI 2020. https://doi.org/10.1007/978-3-030-59716-0_12
- Pérez-García et al., EPISURG dataset. https://doi.org/10.5522/04/9996158.v1

Example RAMPS command after you inspect hemisphere/lobe (replace `R` / `T` as needed):

```bash
python RAMPS/RAMP.py \
  data/EPISURG_sample/EPISURG/subjects/sub-0316/preop/sub-0316_preop-t1mri-1.nii.gz \
  data/EPISURG_sample/EPISURG/subjects/sub-0316/postop/sub-0316_postop-t1mri-1.nii.gz \
  outputs/sub-0316 \
  sub-0316 \
  R T
```

RAMPS itself also needs FreeSurfer, SynthSeg models, and the `requirements.txt` environment; see `RAMPS/README.md`.
