#!/bin/sh
#SBATCH --job-name=basic-job          # Job name
#SBATCH --partition=nodo.q        # Partition (queue) name



DAT_FILES=$1
PNG_FILES=$2

python plotcounts.py $DAT_FILES $PNG_FILES 

