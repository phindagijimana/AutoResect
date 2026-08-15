#!/usr/bin/env bash
set -euo pipefail
ROOT="/mnt/nfs/home/urmc-sh.rochester.edu/pndagiji/Documents/AutoLesion"
ENV="$ROOT/env"
mkdir -p "$ROOT/.pip-tmp"
export TMPDIR="$ROOT/.pip-tmp"
python3.9 -m venv "$ENV"
"$ENV/bin/python" -m pip install --upgrade pip wheel
"$ENV/bin/python" -m pip install "numpy==1.23.5" "antspyx==0.5.4" "nibabel==5.0.1" "pandas==2.0.3" "scipy==1.10.1"
"$ENV/bin/python" -c "import ants,nibabel,pandas,scipy; print('ants', ants.__version__)"
echo "OK: $ENV"
