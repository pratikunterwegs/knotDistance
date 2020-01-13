#! /bin/bash
#SBATCH --job-name=try_ctmm
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=1000
#SBATCH --partition=short

pwd
module load R/3.6.1-foss-2018a
module list
Rscript code_tryCtmm.r