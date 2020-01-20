#! /bin/bash
#SBATCH --job-name=ctmm_Z058211
#SBATCH --time=00:10:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=9000
#SBATCH --partition=regular

pwd
module load R/3.6.1-foss-2018a
module load GEOS/3.6.2-foss-2018a-Python-3.6.4
module load GDAL/3.0.2-foss-2018a-Python-3.6.4
ml list

Rscript code/code_doCtmmTent.r data/tent/F01_2018-08-16_Z058211.txt
