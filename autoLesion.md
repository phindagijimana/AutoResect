# AutoLesion: Key Ideas from Source Papers

Summary of papers in `Source_papers/`, focused on automated delineation of resected brain tissue after epilepsy surgery.

---

## Paper

**Simpson, C., Hall, G., Duncan, J. S., Wang, Y., & Taylor, P. N. (2025).**  
*Automated generation of epilepsy surgery resection masks: The RAMPS pipeline.*  
Imaging Neuroscience, 3.  
https://doi.org/10.1162/IMAG.a.147  
Code: https://github.com/cnnp-lab/RAMPS

---

## Why this problem matters

Surgical removal of epileptic foci frees only about **50%** of patients from seizures. Retrospective studies therefore re-examine preoperative MRI to find biomarkers that predict outcome. Those analyses need an accurate **3D resection mask**: a binary volume labeling which preoperative voxels were later removed.

Manual masks are the current default, but they are:

- time-consuming
- dependent on neuroanatomy and surgical expertise
- inconsistent across raters (inter-rater Dice ? 0.80)

Automation is needed to scale cohort studies, lower the expertise barrier, and make prior work easier to replicate.

---

## Core idea: mask in *preoperative* space

Most existing tools fill the **postoperative cavity**. That looks good when compared to other post-op masks (Dice ~0.74–0.82), but it is the wrong target for most science:

- After surgery the brain **sags, swells, or shifts** into the cavity.
- A post-op cavity mask therefore differs in volume and extent from the tissue that was actually removed.
- Poor pre/post registration warps the mask further.

**RAMPS (Resections And Masks in Preoperative Space)** instead answers: *which preoperative tissue is missing after surgery?*  
That is the mask needed for connectomics, outcome prediction, and any analysis of the preoperative scan.

---

## What RAMPS needs

**Required**

- Preoperative T1-weighted MRI
- Postoperative T1-weighted MRI with a visible resection
- Output folder

**Recommended (strongly)**

- Subject ID
- Hemisphere (`L`, `R`, or both)
- Lobe(s) of resection (`T`, `F`, `O`, `P`; temporal also includes subcortex and insula)

Lobe/hemisphere priors keep the search in the correct region. RAMPS can run without them, but performance drops on some cases.

---

## Pipeline (3 parts, 14 steps)

Built in Python on **FreeSurfer / SynthStrip / SynthSeg / ANTs / nibabel**. No deep-learning resection model; the method is statistical segmentation plus careful registration.

### Part A — Data preparation

1. Resample both scans to **1 mm³**, 256³ FOV (original space preserved).
2. **N4 bias correction**; clip top 1% intensities to the median.
3. **SynthStrip** skull-stripping (robust across scanners).
4. **SynthSeg** regional labels, then merge into a grey-matter lobe atlas (frontal, parietal, temporal, occipital, insula, subcortex; exclude ventricles, brainstem, cerebellum). Multiply the brain image by this atlas to clean residual non-brain tissue around the cavity.
5. Dilate the lobe atlas through white matter. Split into: *resected lobe/hemisphere* vs *everything else*.

### Part B — Registration

6. Align post-op brain to pre-op with **ANTs SyN** (rigid + deformable). Chosen because it holds up under sagging/swelling. Transforms also move post-op products into pre-op space.

### Part C — Cavity classification in pre-op space

7. Rescale both images to [0, 1] so CSF / GM / WM intensities match.
8. **ANTs Atropos** (prior-initialized) in the resected lobe: priors are ventricles (CSF) and tissue in non-resected lobes. Split voxels into cavity vs remaining tissue.
9. Second Atropos (no prior, 2-class k-means) inside that cavity: lowest-intensity cluster = true CSF vs damaged tissue.
10. **Image subtraction** (pre ? post). Same tissue class ? 0; CSF overlapping former tissue ? 0. This marks sagging and the true resected region.
11. Atropos on the subtraction image, restricted to the resected lobe; keep the **largest connected component**.
12. **Cavity cleaning**: erode then carefully re-dilate so thin “bridges” of misregistration (a few voxels) are cut off and not grown into.
13. **Boundary dilation**: if a mask-edge voxel is within 3 voxels of CSF, fill the gap — extend to the tissue boundary without growing into unresected tissue.
14. Fill small holes, restrict to the resected lobe, resample back to native pre-op resolution.

---

## Key design choices

| Choice | Why it matters |
|---|---|
| Pre-op space, not post-op cavity | Matches the tissue used in outcome / network studies |
| Heavy investment in alignment | Misregistration is the main failure mode of competing tools |
| Lobe + hemisphere prior | Prevents the largest intensity-difference cluster from being bias artifact elsewhere |
| Subtraction + two-stage Atropos | Separates true CSF cavity from damaged tissue and sagging |
| Erode–dilate cleanup | Removes thin misalignment “tails” attached to the real cavity |
| No DL resection model | Uses existing, scanner-agnostic tools (SynthStrip, SynthSeg, ANTs) |

---

## Data and evaluation

- **N = 87** epilepsy surgery cases, no exclusion criteria
- 70 TLE, 17 ETLE; multi-center (mostly Chalfont; also Iowa, Penn, Mayo)
- Gold standard: manual pre-op-space masks by 3 trained raters, filtered to brain tissue, 1 mm³
- Metrics:
  - **Dice (DSC)**: 0–0.6 poor, 0.6–0.7 good, 0.7–0.8 high, >0.8 excellent
  - **Overlap**, **miss rate** (manual tissue missed), **FDR** (extra non-resected tissue)

---

## Results

### vs manual masks (N = 87)

| Cohort | Median DSC (IQR) | Overlap | Miss rate | FDR |
|---|---|---|---|---|
| TLE (n=70) | **0.86 (0.078)** | 76% | 7% | 16% |
| ETLE (n=17) | **0.71–0.72 (0.32)** | 55% | 7% | 40% |

- TLE: 97% of cases DSC ? 0.7; only 1 poor (DSC < 0.6)
- ETLE: 53% DSC ? 0.7; 6 poor
- TLE performance matches **inter-rater variability (~0.80)** — human-level on the common surgery
- RAMPS tends to be **slightly larger** than manual masks (low miss, moderate FDR). Most of the gold-standard mask is inside the RAMPS mask, so a rater can trim rather than redraw.
- Captures ~93% of TLE and ~90% of ETLE manual volume

### vs other pre-op-space pipelines (N = 62 that all tools could run)

| Pipeline | DSC | Overlap | Miss rate | FDR |
|---|---|---|---|---|
| **RAMPS + lobe/hemisphere** | **0.86** | **76%** | 7% | 17% |
| RAMPS, images only | 0.86 | 75% | **6%** | 18% |
| Epic-CHOP (Cahill 2019) | 0.72 | 56% | 38% | **4%** |
| ResectVol (Casseb 2021) | 0.72 | 56% | 38% | 7% |

- RAMPS significantly better on DSC, overlap, and miss rate (p < 0.001)
- Epic-CHOP / ResectVol have **lower FDR** because they produce **smaller** masks — they miss a lot of resected tissue (38% miss)
- Epic-CHOP / ResectVol failed to process 25/87 cases on default settings; RAMPS ran on all
- Lobe/hemisphere priors significantly improve DSC, overlap, and FDR vs RAMPS without priors

### Unusual cases (all DSC ? 0.80)

Small lesionectomy, second surgery, preoperative cavernoma, extreme sagging into CSF, contrast-agent injection.

---

## Why RAMPS beats Epic-CHOP and ResectVol

Those tools also subtract aligned pre/post images (SPM12, MATLAB). Failures typically come from **alignment**:

- Incomplete correction of sagging ? **too-small** masks (ResectVol)
- Surface misalignment treated as cavity ? **noisy surface** (Epic-CHOP)

RAMPS spends more effort on SyN registration and then uses lobe-restricted, multi-step cavity classification. Its typical error is the opposite: **over-extension**, which is easier to edit.

---

## Why TLE is easier than ETLE

- TLE has clear anatomical boundaries; variation is mostly anterior–posterior; sagging is mostly superior–inferior.
- ETLE varies in size and location, and is more affected by ventricular dilation and 3-axis shift.
- Human raters do **not** show this TLE/ETLE gap (inter-rater DSC ~0.81 both). The gap is specific to automated methods.

---

## Limitations (from the paper)

1. Compared to a **single** manual mask; there is no unique gold standard.
2. Metrics assume the manual mask is correct; in some cases RAMPS may be *more* accurate than the rater.
3. Cohort is dominated by **anterior temporal lobe resection**.
4. Optional lobe/hemisphere input is a burden other tools do not require (though it is easy to get from notes or a glance at the scan).
5. Not yet designed for **LiTT ablations**, **disconnections**, or **post-op CT** (authors flag these as future work).
6. DSC is biased toward larger resections (Spearman r ? 0.39 with volume).

**Authors still recommend visual review of every mask.**

---

## Landscape of related tools

| Category | Examples | Typical output space |
|---|---|---|
| Deep / machine learning | Arnold 2022; Pérez-García 2021; Casseb 2024 | Usually **post-op** cavity |
| Semi-automated | Billardello 2022; Wilke 2011 | Mixed |
| Fully automated statistical | Epic-CHOP; ResectVol; **RAMPS** | Pre-op (these three) |

Post-op DL methods can look strong on post-op Dice, but they do not solve brain-shift mismatch with preoperative anatomy.

---

## Takeaways for an AutoLesion project

1. **Target space is the product.** If downstream work uses preoperative MRI (networks, FCD, outcome models), generate the mask in **pre-op space**, not the post-op hole.
2. **Registration quality dominates** lesion/resection accuracy. Treat SyN (or equivalent) as first-class, not a preprocessing afterthought.
3. **Priors help:** hemisphere + lobe (or a coarse ROI) stop the algorithm from locking onto the wrong intensity cluster.
4. **Subtract after intensity matching**, then classify the difference — a robust alternative to training a resection-specific network when data are limited.
5. Report **miss rate and FDR**, not only Dice. Dice hides whether the mask is too small or too large.
6. Expect **TLE >> ETLE**. Extra-temporal and small/atypical lesions need extra care (or human trim).
7. Prefer **slight over-segmentation** if a human will QC: trimming is cheaper than painting missed tissue.
8. Reuse **scanner-agnostic** building blocks (SynthStrip, SynthSeg, ANTs) rather than scanner-specific intensity models.
9. Always **QC visually**; automation is for scale, not for unsupervised clinical use.
10. Open implementation to extend: LiTT, disconnection, CT, and multi-rater consensus labels are the natural next steps.

---

## Suggested reading order from the paper’s citations

- **Taylor et al., 2018 / 2024** — why resection masks matter; IDEAS dataset (public pre-op MRI)
- **Cahill et al., 2019 (Epic-CHOP)** and **Casseb et al., 2021 (ResectVol)** — previous pre-op-space statistical pipelines
- **Courtney et al., 2024** — head-to-head of four automated methods vs manual
- **Arnold et al., 2022; Pérez-García et al., 2021** — DL post-op cavity segmentation
- **Hoopes et al., 2022 (SynthStrip); Billot et al., 2023 (SynthSeg)** — the robust preprocessing RAMPS depends on
