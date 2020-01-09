#### code to try ctmm on different data subsets from knots patches

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

# load some data
{
  data <- fread("data/whole_season_tx_435.csv")

  data <- funcCleanData(data)
  
  # setnames(data, old="ts", new="timestamp")
}

# prepare for telemetry
{
  test = data
  # convert to lat-long
  coords <- test %>% 
    st_as_sf(coords = c("x", "y")) %>% 
    `st_crs<-`(32631) %>% 
    st_transform(4326) %>% 
    st_coordinates()
  
  names(coords) <- c("location.long","location.lat")
  
  test <- test[,.(id, ts)]
  test[,ts:=fastPOSIXct(ts)]
  setnames(test, c("individual.local.identifier", "timestamp"))
  test[,`:=`(location.long = coords[,1], location.lat = coords[,2])]
}

# run ctmm proc
{
  data.tel <- as.telemetry(test)
  
  # make variogram
  vg <- variogram(data.tel)
  variogram.fit(vg)
  
  guess <- ctmm.guess(data.tel,variogram = vg, interactive = FALSE )
  guess$error=TRUE
  
  mod = ctmm.fit(data.tel, CTMM=guess)
}

# plot to check
plot(vg, CTMM = mod)
  