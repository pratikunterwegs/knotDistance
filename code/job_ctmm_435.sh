#! /bin/bash
#SBATCH --job-name=ctmm_435
#SBATCH --time=00:10:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=9000
#SBATCH --partition=regular

pwd
module load R/3.6.1-foss-2018a
module load GEOS/3.6.2-foss-2018a-Python-3.6.4
module load GDAL/3.0.2-foss-2018a-Python-3.6.4
ml list

Rscript code/code_doCtmm.r data/watlas/whole_season_tx_435.csv
