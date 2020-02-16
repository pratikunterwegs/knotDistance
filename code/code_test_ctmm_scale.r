#### code to do ctmm on file in cli args
#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
source("code/func_test_ctmm_scale.r")

message(glue::glue('args 1 = {args[1]} args 2 = {args[2]}'))

test_ctmm_scale(datafile=args[1], scale=as.numeric(args[2]))

message(paste("ctmm done on ", args[1], " at scale ", args[2]))

# ends here
