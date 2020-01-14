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

do_ctmm <- function(datafile){

# load some data
{
  # read data and attractors
  data <- fread(datafile, integer64 = "numeric")

  id <- unique(data$id)
  
  attractors <- fread("data/attractor_points.txt")
  
  data <- wat_rmAttractor(df = data, 
                          atp_xmin = attractors$xmin,
                          atp_xmax = attractors$xmax,
                          atp_ymin = attractors$ymin,
                          atp_ymax = attractors$ymax)
  
  data <- wat_clean_data(data)
  data <- wat_agg_data(df = data, interval = 180)
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

  tel <- tel[-(which(outliers[[1]] >= q90),]
  
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
	writeLines(summary(mod), con=glue('ctmm_out_{id}.txt'))
}

# ends here

