#### function to do ctmm

# load libs
library(ctmm)
library(tibble)
library(dplyr)
library(purrr)
library(tidyr)
# devtools::install_github("pratikunterwegs/watlasUtils", ref = "devbranch")
library(lubridate)
library(glue)
library(stringr)
library(scales)
library(readr)

do_ctmm_tent <- function(datafile){
  
  # load some data
  {
    ring <- str_extract(datafile, "(Z\\w+)")
    data <- read_tsv(datafile)
    
    # make single start time
    start_time <- as.POSIXct("2018-08-18 12:00:00")
    
    # repair data -- assign id and time
    data <- data %>% 
      transmute(individual.local.identifier = ring, 
                location.long = rescale(X1, to = c(0, 1)), 
                location.lat = rescale(Y1, to = c(0, 1)), 
                timestamp = seq(1, (nrow(data)+1)/2, 0.5)) %>% 
      filter(is.numeric(location.long), is.numeric(location.lat), 
             !is.nan(location.long), !is.nan(location.lat)) %>% 
      mutate(timestamp = as.numeric(start_time) + timestamp,
             timestamp = as.POSIXct(timestamp, origin = "1970-01-01"))
    
  }
  
  # make telemetry after converting to data.frame
  {
    tel <- as.telemetry(as.data.frame(data),
                        timeformat = "%Y-%m-%d %H:%M:%S")
  }
  
  # ctmm
  {
    outliers <- outlie(tel)
    q90 <- quantile(outliers[[1]], probs = c(0.99))
    
    tel <- tel[-(which(outliers[[1]] >= q90)),]
    
    # make variogram
    vg <- variogram(tel)
    
    mod <- ctmm.fit(tel)
  }
  
  message("model fit!")
  
  summary(mod)
  
  # check output
  {
    png(filename = as.character(glue('vg_ctmm_{ring}.png')))
    plot(vg, CTMM=mod)
    dev.off()
  }
  
  # print model
  {
    if(dir.exists("mod_output") == F)
    {
      dir.create("mod_output")
    }
    writeLines(R.utils::captureOutput(summary(mod)), 
               con = as.character(glue('mod_output/ctmm_tent_{ring}.txt')))
  }
  
}

# ends here
