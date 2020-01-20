#### code to do jobs on the cluster

# load libs
library(ssh)
library(stringr)
library(glue)

# connect to peregrine
s <- ssh_connect("p284074@peregrine.hpc.rug.nl")
# ssh_exec_wait(s, command = "dos2unix code/job*")

# read in data names
data_files <- list.files("data/watlas/", pattern = "whole_season",
                         full.names = TRUE)
# get bird ids
data_ids <- str_extract(data_files, "(tx_\\d+)") %>% str_sub(-3,-1)

#### transfer files and process using ctmm
for(i in 1:length(data_files)){
  # make directory if non-existent
  ssh_exec_wait(s, command = "mkdir -p data/watlas")
  
  # list files already present
  files_on_prg <- ssh_exec_internal(s, command = "ls data/watlas")
  files_on_prg <- rawToChar(files_on_prg$stdout) %>% str_split("\n")
  
  if(!data_files[i] %in% files_on_prg){
    # upload data file for processing
    scp_upload(s, data_files[i], to = "data/watlas/")
  }
  
  # make job file
  {
    shebang <- readLines("code/template_job.sh")
    text <- glue('Rscript code/code_doCtmm.r {data_files[i]}')
    jobfile <- glue('code/job_ctmm_{data_ids[i]}.sh')
    
    writeLines(c(shebang, text), con = jobfile)
  }
  
  # process using ctmm
  ssh_exec_wait(s, command = glue('sbatch {jobfile}'))
}

# ends here
