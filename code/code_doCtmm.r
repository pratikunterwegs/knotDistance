#### code to do ctmm on file in cli args
#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
source("code/code_doCtmm.r")
do_ctmm(args)

# ends here
