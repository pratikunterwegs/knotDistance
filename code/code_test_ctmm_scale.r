#### code to do ctmm on file in cli args
#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=FALSE)
source("code/func_test_ctmm_scale.r")
test_ctmm_scale(datafile=args[1], scale=args[2])

message(paste("ctmm done on ", args[1], " at scale ", args[2]))

# ends here
