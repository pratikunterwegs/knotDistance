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
    # projection system def
    prj <- "+proj=tmerc +ellps=WGS84 +datum=WGS84 +units=m +no_defs +lon_0=0 +x_0=0 +y_0=0 +k_0=0.000009996"
    tel <- as.telemetry(as.data.frame(data),
                        projection = prj,
                        timeformat = "%Y-%m-%d %H:%M:%S")
  }
  
  # ctmm
  {
    outliers <- outlie(tel)
    vg <- variogram(tel)
    # guess model paramters
    guess <- ctmm.guess(tel, interactive = FALSE)
    
    # fit the range-restricted models
    mods <- ctmm.select(tel, CTMM = guess, verbose = TRUE)
    
  }
  
  message("model fit!")
  
  print(summary(mods))
  
  # check output
  {
    png(filename = as.character(glue('vg_ctmm_{ring}.png')))
    {
      par(mfrow=c(2,3))
      for(i in 1:length(mods)){
        plot(vg, CTMM=mods[[i]], main = summary(mods[[i]])$name)
      }
    }
    plot(vg, CTMM=mods[[1]], main = summary(mods[[1]])$name)
    plot(vg, CTMM=mods[[2]], col = "green", add = T)
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
    # save the models
    save(mods, file = as.character(glue('mod_output/ctmm_tent_{ring}.rdata')))
  }
  
}

# ends here
