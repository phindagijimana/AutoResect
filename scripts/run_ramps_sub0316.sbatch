#!/bin/bash
#SBATCH --job-name=ramps-0316
#SBATCH --partition=interactive
#SBATCH --cpus-per-task=16
#SBATCH --mem=48G
#SBATCH --time=04:00:00
#SBATCH --output=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/AutoLesion/outputs/sub-0316/%x-%j.out
#SBATCH --error=/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/AutoLesion/outputs/sub-0316/%x-%j.err

set -euo pipefail

ROOT="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/AutoLesion"
ENV="$ROOT/env"
FS="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/others/data_mining/freesurfer"
OUT="$ROOT/outputs/sub-0316"
PRE="$ROOT/data/EPISURG_sample/EPISURG/subjects/sub-0316/preop/sub-0316_preop-t1mri-1.nii.gz"
POST="$ROOT/data/EPISURG_sample/EPISURG/subjects/sub-0316/postop/sub-0316_postop-t1mri-1.nii.gz"

mkdir -p "$OUT" "$ROOT/.pip-tmp"
export TMPDIR="${SLURM_TMPDIR:-$ROOT/.pip-tmp}"
export PIP_CACHE_DIR="$ROOT/.pip-tmp/cache"

if [ ! -x "$ENV/bin/python" ]; then
  python3.9 -m venv "$ENV"
fi
"$ENV/bin/python" -m pip install --upgrade pip wheel
# ANTsPy + scientific stack only. SynthStrip/SynthSeg run via FreeSurfer fspython.
"$ENV/bin/python" -m pip install \
  "numpy==1.23.5" \
  "antspyx==0.5.4" \
  "nibabel==5.0.1" \
  "pandas==2.0.3" \
  "scipy==1.10.1"
"$ENV/bin/python" -c "import ants,nibabel,pandas,scipy; print('ants', ants.__version__)"

export FREESURFER_HOME="$FS"
export FS_LICENSE="${FS_LICENSE:-$HOME/.freesurfer/license.txt}"
export SUBJECTS_DIR="$OUT"
export CUDA_VISIBLE_DEVICES="-1"
export TF_CPP_MIN_LOG_LEVEL=2
export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-16}"
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS="${SLURM_CPUS_PER_TASK:-16}"

set +u
source "$FREESURFER_HOME/SetUpFreeSurfer.sh"
set -u
export PATH="$ENV/bin:$PATH"

echo "host=$(hostname) date=$(date)"
echo "python=$(which python) $(python --version)"
echo "FREESURFER_HOME=$FREESURFER_HOME"
echo "mri_synthstrip=$(which mri_synthstrip)"
echo "mri_synthseg=$(which mri_synthseg)"

echo "=== starting RAMPS sub-0316  hemisphere=R  lobes=TF ==="
python "$ROOT/RAMPS/RAMP.py" \
  "$PRE" \
  "$POST" \
  "$OUT" \
  sub-0316 \
  R \
  TF

echo "=== done $(date) ==="
ls -lh "$OUT/RAMPS_Resection_Mask_Output"
