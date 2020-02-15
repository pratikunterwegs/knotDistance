#### code to do ctmm on file in cli args
#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=FALSE)
source("code/func_test_ctmm_scale.r")
test_ctmm_scale(args)

message(paste("ctmm done on ", args))

# ends here
