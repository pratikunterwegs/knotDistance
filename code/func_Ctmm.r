#### function to do ctmm

# load libs
library(data.table)
library(ctmm)
library(fasttime)
library(tibble)
library(dplyr)
library(purrr)
library(tidyr)
# devtools::install_github("pratikunterwegs/watlasUtils", ref = "devbranch")
library(watlasUtils)
library(lubridate)
library(sf)
library(glue)
library(stringr)

do_ctmm <- function(datafile){
  
  # load raw data
  {
    reldate <- fread("data/release_data_2018.csv")
    reldate[,Release_Date:=fastPOSIXct(Release_Date)]
    
    # read data and filter after release + 24 hrs
    data <- fread(datafile, integer64 = "numeric")
    
    id_data <- as.character(unique(data$TAG))
    id_data <- str_sub(id_data, -3, -1)
    
    id_rel <- reldate[id == id_data, Release_Date]
    id_rel <- as.numeric(id_rel)
    
    # filter out the first 24 hours since release
    data <- data[TIME/1e3 > as.numeric(id_rel + (24*60*60)),]
    
    # remove attractors
    attractors <- fread("data/attractor_points.txt")
    data <- wat_rm_attractor(df = data, 
                             atp_xmin = attractors$xmin,
                             atp_xmax = attractors$xmax,
                             atp_ymin = attractors$ymin,
                             atp_ymax = attractors$ymax)
    
    # clean data with median filter
    data <- wat_clean_data(data)
    
    # add tide data
    data <- wat_add_tide(df = data,
                         tide_data = "data/tidesSummer2018.csv")
  }
  
  # prepare for telemetry
  {
    data_for_ctmm <- setDT(data)[,.(id, tide_number, x, y, time, VARX, VARY)]
    
    # aggregate within a patch to 10 seconds
    data_for_ctmm <- split(data_for_ctmm, f = data_for_ctmm$tide_number) %>% 
      map(wat_agg_data, interval = 30) %>% 
      bind_rows()
    
    # make each tidal cycle an indiv
    setDT(data_for_ctmm)
    data_for_ctmm[,individual.local.identifier:= paste(id, tide_number,
                                                       sep = "_")]
    # get horizontal error
    data_for_ctmm[,HDOP := sqrt(VARX+VARY)/10]
    # subset columns
    data_for_ctmm <- data_for_ctmm[,.(individual.local.identifier, time, x, y, HDOP)]
    
    # get new names
    setnames(data_for_ctmm, old = c("x", "y", "time"), 
             new = c("UTM.x","UTM.y", "timestamp"))
    
    # convert time to posixct
    data_for_ctmm[,timestamp:=as.POSIXct(timestamp, origin = "1970-01-01")]
    # add UTM zone
    data_for_ctmm[,zone:="31 +north"]
    
  }
  
  # make telemetry
  {
    tel <- as.telemetry(data_for_ctmm)
  }
  
  # ctmm section
  {
    # get the outliers but do not plot
    outliers <- map(tel, outlie, plot=FALSE)
    # get a list of 99 th percentile outliers
    q90 <- map(outliers, function(this_outlier_set){
      quantile(this_outlier_set[[1]], probs = c(0.99))
    })
    
    # remove outliers from telemetry data
    tel <- pmap(list(tel, outliers, q90), 
                function(this_tel_obj, this_outlier_set, outlier_quantile) 
                {this_tel_obj[-(which(this_outlier_set[[1]] >= outlier_quantile)),]})
    
    # some tides may have no data remaining, filter them out
    # CTMM has issues with data that has only one row
    tel <- keep(tel, function(this_tel){nrow(this_tel) > 10})
    
    # guess ctmm params
    guess_list <- lapply(tel, ctmm.guess, interactive = F)
    
    # run ctmm fit
    mod <- map2(tel, guess_list, function(obj_tel, obj_guess){
      ctmm.fit(obj_tel, CTMM = obj_guess)
    })
  }
  
  message("model fit!")
  
  # check model fit
  {
    png(filename = as.character(glue('output/figs/vg_ctmm_{id_data}.png')),
        height = 800, width = 1600)
    {
      par(mfrow=c(10, ceiling(length(mod)/ 10)), mar = c(1,1,1,1))
      for(i in 1:length(mod))
      {
        modtype = summary(mod[[i]])$name
        plot(variogram(tel[[i]]), CTMM=mod[[i]], 
             main = as.character(glue('{id_data}: {modtype}')))
      }
    }
    dev.off()
  }
  
  # get speed output
  
  # print model
  {
    if(dir.exists("mod_output") == F)
    {
      dir.create("mod_output")
    }
    writeLines(R.utils::captureOutput(map(mod, summary)), 
               con = as.character(glue('mod_output/ctmm_{id_data}.txt')))
    # save the models
    save(mod, file = as.character(glue('output/mods/ctmm_{id_data}.rdata')))
  }
  
}
# ends here

