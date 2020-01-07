#### code to try ctmm on different data subsets from knots patches

# load libs
library(data.table)
library(ctmm)
library(fasttime)
library(tibble)
library(dplyr)

# load some data
data <- fread("data/435_024_revisit.csv")
data <- data[,.(id, ts, x, y)]
data[,ts:=fastPOSIXct(ts)]

# convert to lat-long
library(sf)
coords <- setDF(data) %>% 
  st_as_sf(coords = c("x", "y")) %>% 
  `st_crs<-`(32631) %>% 
  st_transform(4326) %>% 
  st_coordinates()

names(coords) <- c("x","y")

data <- setDT(data)
data[,`:=`(x=coords[,1], y=coords[,2])]

setnames(data, c("individual.local.identifier", 
                 "timestamp", "location.long", "location.lat"))

# run ctmm proc
data.tel <- as.telemetry(setDF(data))
mod <- ctmm.fit(data.tel, CTMM = ctmm(tau = c(1)))

# plot to check
plot(vg, CTMM = mod)
