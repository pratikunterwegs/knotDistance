# make multiple r scripts and matching batch files

library(stringr)
library(glue)

shebang <- readLines("code/template_job.sh")
writeLines(shebang, con="code/overall_job.sh")

datafiles <- list.files("data/", pattern = "whole_season")

# **BETTER JOB NAME**

for (i in length(datafiles)) {
  
  id <- str_pad(i, 3, pad = "0")
  {
    src <- glue('source("code/code_doCtmm.r")')
    text <- glue('do_ctmm("data/{datafiles[i]}")')
    rfile <- glue('code/script_{id}.R')
    writeLines(c(src, text), con=rfile)
  }
  
  {
    
    job <- glue('Rscript {rfile}')
    jobfile <- glue('code/job_{id}.sh')
    writeLines(c(shebang, job), con=jobfile)
  }
 
  
  write(glue('sbatch {jobfile}'), file ="code/overall_job.sh", append = TRUE)
}
