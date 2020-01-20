#### code to do ctmm on file in cli args
#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
source("code/code_funcCtmm.r")
do_ctmm(args)

message(paste("ctmm done on ", args))

# ends here
