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
  
  # load some data
  {
    reldate <- fread("data/release_data_2018.csv")
    reldate[,Release_Date:=fastPOSIXct(Release_Date)]
    
    # read data and filter after release + 24 hrs
    data <- fread(datafile, integer64 = "numeric")
    
    id_data <- unique(data$TAG)
    id_data <- str_sub(id, -3, -1)
    
    id_rel <- reldate[id == id_data, Release_Date]
    id_rel <- as.numeric(id_rel)
    
    data <- data[TIME/1e3 > as.numeric(id_rel + (24*60*60)),]
    
    # remove attractors
    attractors <- fread("data/attractor_points.txt")
    
    data <- wat_rm_attractor(df = data, 
                             atp_xmin = attractors$xmin,
                             atp_xmax = attractors$xmax,
                             atp_ymin = attractors$ymin,
                             atp_ymax = attractors$ymax)
    
    # clean data and aggregate
    data <- wat_clean_data(data)
    data <- wat_agg_data(df = data, interval = 60)
  }
  
  # prepare for telemetry
  {
    test <- data
    # convert to lat-long
    coords <- test %>% 
      st_as_sf(coords = c("x", "y")) %>% 
      `st_crs<-`(32631) %>% 
      st_transform(4326) %>% 
      st_coordinates()
    
    names(coords) <- c("location.long","location.lat")
    
    test[,HDOP:=sqrt(VARX+VARY)]
    test <- test[,.(id, ts, HDOP)]
    test[,ts:=fastPOSIXct(ts)]
    setnames(test, c("individual.local.identifier", "timestamp", "HDOP"))
    test[,`:=`(location.long = coords[,1], location.lat = coords[,2])]
  }
  
  # make telemetry
  {
    tel <- as.telemetry(test)
  }
  
  # ctmm
  {
    outliers <- outlie(tel)
    q90 <- quantile(outliers[[1]], probs = c(0.9))
    
    tel <- tel[-(which(outliers[[1]] >= q90)),]
    
    # make variogram
    vg <- variogram(tel)
    
    mod <- ctmm.fit(tel)
  }
  
  # check output
  {
    png(glue('vg_ctmm_{id}.png'))
    plot(vg, CTMM=mod)
    dev.off()
  }
  
  # print model
  {
    if(dir.exists("mod_output") == F)
    {
      dir.create("mod_output")
    }
    writeLines(summary(mod), con=glue('ctmm_out_{id}.txt'))
  }
  
}
# ends here

