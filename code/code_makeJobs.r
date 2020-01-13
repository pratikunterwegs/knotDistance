# make multiple r scripts and matching batch files

library(glue)

shebang <- readLines("code/job_template.sh")
writeLines(shebang, con="code/overall_job.sh")

for (i in 1:10) {
  
  {
    src <- glue('code/source(func_ctmm.r)')
    text <- glue('do_ctmm("filename{i}.csv")')
    rfile <- glue('code/script{i}.R')
    writeLines(c(src, text), con=rfile)
  }
  
  {
    
    job <- glue('code/Rscript {rfile}')
    jobfile <- glue('code/job{i}.sh')
    writeLines(c(shebang, job), con=jobfile)
  }
 
  
  write(glue('sbatch {jobfile}'), file ="code/overall_job.sh", append = TRUE)
}
