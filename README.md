# AutoResection

CLI around [RAMPS](https://github.com/cnnp-lab/RAMPS): build a **preoperative-space** resection mask from a pre-op and post-op T1.

```bash
./Resect install
./Resect start
./Resect logs
```

## Commands

| Command | What it does |
|---|---|
| `./Resect install` | Create `env/`, install ANTsPy, check FreeSurfer |
| `./Resect start` | Submit RAMPS on the cluster (`interactive` partition) |
| `./Resect logs` | Print the latest SLURM stdout/stderr |
| `./Resect logs -f` | Follow the log |
| `./Resect status` | Last subject config and job id |

`start` defaults to the local EPISURG sample `sub-0316` (right hemisphere, temporal+frontal). Override as needed:

```bash
./Resect start \
  --pre /path/pre_t1.nii.gz \
  --post /path/post_t1.nii.gz \
  --id sub-001 \
  --hemi L \
  --lobe T \
  --partition interactive
```

Run in the foreground (no SLURM):

```bash
./Resect start --local
```

## Requirements

- Python 3.9
- FreeSurfer 7.4+ (`mri_synthstrip`, `mri_synthseg`) and a license at `~/.freesurfer/license.txt`
- `FREESURFER_HOME` if FreeSurfer is not in the default lab path
- Pre-op **and** post-op T1 `.nii.gz`
- Hemisphere `L` or `R` and lobe letters `T` `F` `O` `P` (combine, e.g. `TF`)

The mask is written to:

```text
outputs/<id>/RAMPS_Resection_Mask_Output/RAMP_The_resection_mask_in_PRE.nii.gz
```

SLURM logs: `outputs/logs/`.

## Notes

- RAMPS is for **epilepsy-surgery cavities**, not general TBI lesions.
- EPISURG MRI is not in git (data-use agreement). Keep it under `data/EPISURG_sample/` locally.
- Cite Simpson et al., Imaging Neuroscience 2025 (`IMAG.a.147`) if you use RAMPS.

Paper notes: [`autoLesion.md`](autoLesion.md)
