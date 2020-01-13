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

{
  griend <- st_read("data/griend_polygon/griend_polygon.shp")
}

# load some data
{
  # read data and attractors
  data <- fread("data/whole_season_tx_435.csv", integer64 = "numeric")
  
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
  test = data
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
  
  prerel <- test[timestamp > "2018-08-16" & timestamp <= "2018-08-18",]
  # prerel <- st_as_sf(prerel, coords = c("location.long", "location.lat")) %>% 
  #   `st_crs<-`(4326) %>% 
  #   st_transform(32631)
}



# make telemetry
{
  data.tel <- as.telemetry(test[timestamp > "2018-08-18",])
  data.cal <- as.telemetry(prerel)
}

# uere
{
  uere <- uere.fit(data.cal)
  uere(data.tel) <- uere
}

# ctmm
{
  outliers <- outlie(data.tel)
  data.tel <- data.tel[-(which(outliers[[1]] >= 0.07)),]
  
  # make variogram
  vg <- variogram(data.tel)
  variogram.fit(vg)
  
  guess <- GUESS
  guess$error=TRUE
  
  mod = ctmm.fit(data.tel, CTMM=GUESS)
}

# plot to check
plot(vg, CTMM = mod)

# get speeds
data_speed <- speeds(data.tel, mod)
setDT(data_speed)
data_speed[,distance:=est*c(NA, diff(t))]

# plot trajectories with speeds
data2 <- test %>% 
  inner_join(data_speed, by = "timestamp")

# convert to spatial lines and points and export
data2 <- st_as_sf(data2, coords = c("location.long", "location.lat"))
st_write(data2, dsn = "data/points", layer = "ctmm_points", driver='ESRI Shapefile')

lines <- st_coordinates(data2) %>% st_linestring() %>% st_sfc()
data_lines <- data2 %>% 
  select(t, est) %>% 
  mutate(geometry = lines)
st_write(data_lines, dsn = "data/lines", layer = "ctmm_lines", driver='ESRI Shapefile')
