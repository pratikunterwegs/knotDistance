#! /bin/bash
#SBATCH --job-name=try_ctmm
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=1000
#SBATCH --partition=short

pwd
module load R/3.6.1-foss-2018a
ml list

sbatch code/job1.sh
sbatch code/job2.sh
sbatch code/job3.sh
sbatch code/job4.sh
sbatch code/job5.sh
sbatch code/job6.sh
sbatch code/job7.sh
sbatch code/job8.sh
sbatch code/job9.sh
sbatch code/job10.sh
