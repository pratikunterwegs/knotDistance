#### code to do jobs on the cluster

# load libs
library(ssh)
library(stringr)
library(glue)
library(readr)

# read password
password = read_csv("data/password.txt")$password

# read in data names
data_files <- list.files("data/tent/", pattern = "F01_2018",
                         full.names = TRUE)[1:3]
# get bird ids
data_ids <- str_extract(data_files, "(Z\\w+)")

#### transfer files and process using ctmm
for(i in 1:length(data_files)){
  # connect to peregrine
  s <- ssh_connect("p284074@peregrine.hpc.rug.nl", passwd = password)
  # make directory if non-existent
  ssh_exec_wait(s, command = "mkdir -p data/tent")
  
  # list files already present
  files_on_prg <- ssh_exec_internal(s, command = "ls data/tent")
  files_on_prg <- rawToChar(files_on_prg$stdout) %>% 
    str_split("\n") %>% 
    unlist()
  
  # check name
  data_name <- data_files[i] %>% 
    str_split("/") %>% 
    unlist() %>% .[3]
  
  if(!data_name %in% files_on_prg){
    # upload data file for processing
    scp_upload(s, data_files[i], to = "data/tent/")
  }
  
  # make job file
  {
    shebang <- readLines("code/template_job.sh")
    
    # rename job
    shebang[2] <- glue('#SBATCH --job-name=ctmm_{data_ids[i]}')
    
    text <- glue('Rscript code/code_doCtmmTent.r {data_files[i]}')
    jobfile <- glue('code/job_ctmm_{data_ids[i]}.sh')
    
    writeLines(c(shebang, text), con = jobfile)
    scp_upload(s, jobfile, to = "code/")
  }
  
  ssh_exec_wait(s, command = glue('dos2unix {jobfile}'))
  # process using ctmm
  ssh_exec_wait(s, command = glue('sbatch {jobfile}'))
  
  # disconnect
  ssh_disconnect(s)
}

# ends here
