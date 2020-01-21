#### code to do ctmm on file in cli args
#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
source("code/func_Ctmm_tent.r")
do_ctmm_tent(args)

message(paste("ctmm tent done on ", args))

# ends here
