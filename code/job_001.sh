#! /bin/bash
#SBATCH --job-name=try_ctmm
#SBATCH --time=00:01:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=1000
#SBATCH --partition=short

pwd
module load R/3.6.1-foss-2018a
module load GEOS/3.6.2-foss-2018a-Python-3.6.4
module load GDAL/3.0.2-foss-2018a-Python-3.6.4
ml list

Rscript code/script_001.R
