#! /bin/bash
#SBATCH --job-name=try_ctmm
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=1000
#SBATCH --partition=short

pwd
module load R/3.6.1-foss-2018a
ml list

sbatch code/job_001.sh
sbatch code/job_002.sh
sbatch code/job_003.sh
sbatch code/job_004.sh
sbatch code/job_005.sh
sbatch code/job_006.sh
sbatch code/job_007.sh
sbatch code/job_008.sh
sbatch code/job_009.sh
sbatch code/job_010.sh
