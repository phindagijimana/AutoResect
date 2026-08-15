# AutoResection: Pipeline Theory and Usage

This document explains what the **AutoResection** project does, the theory behind the underlying **RAMPS** pipeline, and how to run it on the cluster.

---

## What AutoResection is

**AutoResection** is a thin CLI wrapper around [RAMPS](https://github.com/cnnp-lab/RAMPS) (Resections And Masks in Preoperative Space). It automates environment setup, SLURM job submission, and log monitoring so you can generate a **preoperative-space resection mask** from paired pre-op and post-op T1-weighted MRI.

```bash
./Resect install    # create Python env, install ANTsPy, verify FreeSurfer
./Resect start      # submit RAMPS on the cluster
./Resect logs       # view SLURM output
./Resect status     # last subject and job id
```

Primary output:

```text
outputs/<id>/RAMPS_Resection_Mask_Output/RAMP_The_resection_mask_in_PRE.nii.gz
```

The wrapper does **not** change the RAMPS algorithm. It handles install, paths, FreeSurfer setup, and cluster execution.

---

## The scientific question RAMPS answers

After epilepsy surgery, researchers often need to know: **which voxels in the pre-operative brain were removed?**

That is different from tracing the **post-operative cavity**. After surgery the brain sags, swells, and shifts into the hole. A post-op cavity mask therefore differs in volume and extent from the tissue that was actually resected. Poor pre/post registration warps the mask further.

**RAMPS** instead answers: *which preoperative tissue is missing after surgery?* That is the mask needed for connectomics, outcome prediction, and any analysis performed on the preoperative scan.

| Approach | What it measures | Best for |
|---|---|---|
| Post-op cavity mask | The hole visible after surgery | Post-op anatomy studies |
| **RAMPS (pre-op mask)** | Tissue that was removed, in native pre-op space | Outcome models, network analysis on pre-op MRI |

---

## Inputs and priors

### Required

- Preoperative T1-weighted MRI (`.nii.gz`)
- Postoperative T1-weighted MRI with a visible resection
- Output folder

### Strongly recommended

- Subject ID
- **Hemisphere** of resection: `L` or `R`
- **Lobe(s)** of resection: `T` (temporal), `F` (frontal), `O` (occipital), `P` (parietal); combine as needed (e.g. `TF`)

Temporal lobe in RAMPS also includes subcortex and insula. Lobe and hemisphere priors restrict the search to the surgically plausible region. RAMPS can run without them, but performance drops on some cases.

### What RAMPS is not

RAMPS is designed for **epilepsy-surgery resection cavities**, not general TBI lesions, stroke, or tumor resections. Always visually inspect output masks before using them in analysis.

---

## Pipeline overview

RAMPS has three phases and fourteen steps. It is built in Python on **FreeSurfer / SynthStrip / SynthSeg / ANTs / nibabel**. There is no deep-learning resection model; the method combines robust preprocessing, deformable registration, and statistical tissue classification.

```
Pre + Post T1
      │
      ▼
┌─────────────────┐
│  A. Prepare     │  resample, bias correct, skull-strip, segment, lobe atlas
└────────┬────────┘
         ▼
┌─────────────────┐
│  B. Register    │  ANTs SyN: align post-op brain to pre-op
└────────┬────────┘
         ▼
┌─────────────────┐
│  C. Classify    │  find cavity, subtract images, grow mask in pre-op space
└────────┬────────┘
         ▼
  Resection mask in PRE space
```

---

## Part A — Data preparation (Steps 1–5)

**Goal:** Produce clean, comparable brain images and an anatomical map of where resection *could* have occurred.

### Step 1 — Resolution normalization

Both scans are resampled to **1 × 1 × 1 mm** voxels with a **256³** field of view. Images stay in their original coordinate space; only voxel size and FOV are standardized.

### Step 2 — Bias correction

**ANTs N4** bias-field correction removes slow intensity non-uniformity. The top 1% of voxel intensities are clipped to the median to suppress outliers.

### Step 3 — Brain extraction (SynthStrip)

**SynthStrip** removes skull, eyes, and other non-brain tissue. RAMPS uses a variant that keeps the pial surface near the resection cavity intact, avoiding a skull strip that cuts deep into the surgical hole.

### Step 4 — Regional segmentation (SynthSeg)

**SynthSeg** parcellates the brain into atlas regions. Regions are merged into a grey-matter lobe map:

- Frontal, parietal, temporal, occipital, insula, subcortical
- Excluded: ventricles, brainstem, cerebellum (resection cannot occur there)

The brain image is multiplied by this atlas to remove residual non-brain tissue around the cavity.

### Step 5 — Lobe of resection prior

The lobe atlas is dilated through white matter to create a full-lobe map. It is split into two binary masks:

1. **Resected lobe + hemisphere** (user-specified)
2. **All other lobes**

Later classification steps are restricted to the resected region. This prevents the algorithm from locking onto intensity differences caused by bias fields or misregistration elsewhere in the brain.

---

## Part B — Registration (Step 6)

**Goal:** Align post-operative anatomy to pre-operative anatomy despite sagging and swelling.

**ANTs SyN** (rigid + deformable B-spline) registers the post-op brain to the pre-op brain. This registration method was chosen because it remains stable when post-op images show brain shift, sagging, or edema.

The computed transforms are saved and used to warp post-op-derived labels and images into pre-op space.

**Misregistration is the main failure mode** for automated resection tools. RAMPS invests heavily in this step because poor alignment makes normal tissue look "missing" in the subtraction image.

---

## Part C — Cavity classification (Steps 7–14)

**Goal:** Delineate the resection cavity in the post-operative image, then expand it to the **pre-operative tissue boundary**.

All of the following occurs after registration, with the post-op brain aligned to pre-op coordinates.

### Step 7 — Intensity rescaling

Both images are rescaled to **[0, 1]** so CSF, grey matter, and white matter have comparable intensities across timepoints.

### Step 8 — Atropos with priors (cavity vs tissue)

**ANTs Atropos** (prior-initialized mixture modeling) runs within the resected lobe. Priors are:

- Ventricles → CSF class
- Tissue in non-resected lobes → remaining brain tissue

Voxels in the resected lobe are classified into **cavity** vs **non-resected tissue**.

### Step 9 — CSF vs damaged tissue

A second Atropos pass (2-class k-means, no priors) runs **inside** the Step 8 cavity. The cluster with the lowest median intensity is labeled true **CSF**, separating fluid from damaged or edematous tissue.

### Step 10 — Image subtraction

The rescaled post-op image is subtracted from the rescaled pre-op image:

- Same tissue class at the same location → difference ≈ 0
- CSF (post-op) overlapping former tissue (pre-op) → large difference

This highlights brain sagging and the true resected region. The subtraction image is masked to pre-op brain tissue.

### Step 11 — Grow mask through subtraction image

Atropos runs again on the subtraction image, restricted to the resected lobe. The **largest connected component** becomes the candidate resection mask.

### Step 12 — Misregistration cleanup

Poor registration can attach thin "bridges" of misaligned tissue to the main mask (often just a few voxels wide). RAMPS erodes the mask, then re-dilates carefully: if expansion reveals a small isolated cluster, further growth into that region is blocked.

### Step 13 — Boundary dilation

To reach the true tissue boundary, directional dilation is applied: if a mask-edge voxel is within **3 voxels** of CSF, all voxels between the edge and the CSF are added. Dilation stops before entering unresected tissue.

### Step 14 — Final cleaning and resampling

Small holes are filled with ANTs morphology. The mask is clipped to the resected lobe. Finally, it is resampled back to **native pre-op resolution**.

**Deliverable:** `RAMP_The_resection_mask_in_PRE.nii.gz`

---

## Key design choices

| Choice | Why it matters |
|---|---|
| Pre-op space, not post-op cavity | Matches tissue used in outcome and network studies |
| Heavy investment in SyN registration | Misregistration is the dominant error source |
| Lobe + hemisphere prior | Prevents locking onto the wrong intensity cluster |
| Subtraction + two-stage Atropos | Separates CSF cavity from damaged tissue and sagging |
| Erode–dilate cleanup | Removes thin misalignment tails attached to the real cavity |
| No DL resection model | Reuses scanner-agnostic tools (SynthStrip, SynthSeg, ANTs) |

---

## Why lobe and hemisphere priors matter

Without priors, the largest intensity-difference cluster in the brain might be a bias artifact, ventricular shift, or registration error far from the surgical site. Supplying hemisphere and lobe information tells RAMPS *where* to look.

In the original paper (N = 87), lobe/hemisphere priors significantly improved Dice, overlap, and false discovery rate compared to image-only RAMPS, with no meaningful loss on miss rate.

---

## Published performance (Simpson et al. 2025)

Reference: *Automated generation of epilepsy surgery resection masks: The RAMPS pipeline.* Imaging Neuroscience, 3. [doi:10.1162/IMAG.a.147](https://doi.org/10.1162/IMAG.a.147)

Gold standard: manual pre-op-space masks by three trained raters (N = 87, 70 TLE, 17 ETLE).

| Cohort | Median Dice | Overlap | Miss rate | FDR |
|---|---|---|---|---|
| TLE (n = 70) | **0.86** | 76% | 7% | 16% |
| ETLE (n = 17) | 0.71–0.72 | 55% | 7% | 40% |

Compared to other pre-op-space tools (Epic-CHOP, ResectVol) on 62 cases all pipelines could run:

| Pipeline | Dice | Overlap | Miss rate | FDR |
|---|---|---|---|---|
| **RAMPS + lobe/hemisphere** | **0.86** | **76%** | 7% | 17% |
| Epic-CHOP | 0.72 | 56% | 38% | 4% |
| ResectVol | 0.72 | 56% | 38% | 7% |

RAMPS tends to produce **slightly larger** masks than manual raters (low miss rate, moderate false discovery rate). Most of the manual mask falls inside the RAMPS mask, so a rater can trim rather than redraw missing tissue.

**TLE is easier than ETLE** because temporal resections have clearer anatomical boundaries and more predictable sagging patterns. The authors recommend visual review of every mask.

---

## Local validation (EPISURG sub-0316)

A successful run on the local EPISURG sample (`sub-0316`, right temporal-frontal resection) produced:

| Metric | Value |
|---|---|
| RAMPS mask volume | ~37 ml (pre-op tissue) |
| EPISURG post-op cavity seg | ~22 ml |
| Volume ratio | ~1.67× (expected: pre-op tissue > post-op hole) |
| Approximate Dice vs EPISURG seg | ~0.81 |
| Approximate overlap | ~77% |
| Mask outside R+TF ROI prior | ~5% |

The EPISURG segmentation is a **post-op cavity**, not a true pre-op gold standard, so volume and overlap metrics should be interpreted cautiously. Spatial localization (right hemisphere, ~6 mm center-of-mass distance) was consistent with the surgical prior.

---

## Running AutoResection

### Install

```bash
./Resect install
```

Creates `env/` with ANTsPy and verifies FreeSurfer (`mri_synthstrip`, `mri_synthseg`) and license at `~/.freesurfer/license.txt`.

### Start (cluster)

```bash
./Resect start
```

Defaults: EPISURG `sub-0316`, hemisphere `R`, lobe `TF`, `interactive` partition.

Override paths and priors:

```bash
./Resect start \
  --pre /path/pre_t1.nii.gz \
  --post /path/post_t1.nii.gz \
  --id sub-001 \
  --hemi L \
  --lobe T \
  --partition interactive
```

### Local (no SLURM)

```bash
./Resect start --local
```

### Monitor

```bash
./Resect logs       # latest stdout/stderr
./Resect logs -f    # follow log
./Resect status     # last job id and config
```

---

## Requirements

- Python 3.9
- FreeSurfer 7.4+ with SynthStrip and SynthSeg
- FreeSurfer license at `~/.freesurfer/license.txt`
- Pre-op and post-op T1 `.nii.gz`
- Hemisphere (`L`/`R`) and lobe code (`T`, `F`, `O`, `P`)

EPISURG MRI cannot be redistributed (data-use agreement). Keep it under `data/EPISURG_sample/` locally.

---

## Limitations

1. Designed for epilepsy surgery cavities, not TBI, stroke, or tumor resections.
2. Performance is best for **temporal lobe epilepsy (TLE)**; extra-temporal cases need extra care.
3. Requires paired pre-op and post-op T1 with a visible resection.
4. Lobe/hemisphere priors improve accuracy but must be supplied (or inferred from clinical notes).
5. Masks should always be **visually inspected** before use in research or clinical workflows.
6. Not yet validated for LiTT ablations, disconnections, or post-op CT.

---

## Citation

If you use RAMPS, cite:

> Simpson C, Hall G, Duncan JS, Wang Y, Taylor PN. Automated generation of epilepsy surgery resection masks: The RAMPS pipeline. *Imaging Neuroscience (Camb).* 2025. doi: [10.1162/IMAG.a.147](https://doi.org/10.1162/IMAG.a.147)

For extended paper notes and literature context, see [`autoLesion.md`](autoLesion.md).
