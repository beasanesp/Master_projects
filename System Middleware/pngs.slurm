#!/bin/bash
#SBATCH --job-name=basic-job          # Job name
#SBATCH --partition=cuda-ext.q        # Partition (queue) name
#SBATCH --array=0-4

module load python3
python $< $@
