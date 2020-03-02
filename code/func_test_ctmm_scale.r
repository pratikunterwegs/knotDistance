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

# define globals
tide_duration <- 4
tide_quality <- 0.5
tide_hr_start <- 3
tide_hr_end <- 10

test_ctmm_scale <- function(datafile, scale){
  
  # load raw data
  {
    tryCatch({
      reldate <- fread("data/release_data_2018.csv")
      reldate[,Release_Date:=fastPOSIXct(Release_Date)]
      
      # read data and filter after release + 24 hrs
      data <- fread(datafile, integer64 = "numeric")
      
      id_data <- as.character(unique(data$TAG))
      id_data <- str_sub(id_data, -3, -1)
      
      id_rel <- reldate[id == id_data, Release_Date]
      id_rel <- as.numeric(id_rel)
    },
    error = function(e) {
      message(glue("could not find id {id_data} in release data"))
    }
    )
    
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
    data <- wat_clean_data(somedata = data, moving_window = 3, 
                            sd_threshold = 100, filter_speed = TRUE, 
                            speed_cutoff = 150)
    
    # add tide data
    data <- wat_add_tide(df = data,
                         tide_data = "data/tidesSummer2018.csv")
    
    # filter for low tide
    data <- setDT(data)
    data <- data[between(tidaltime, tide_hr_start*60, tide_hr_end*60),]
    if(nrow(data) > 1){
      message("data has rows and will be processed")
    } else stop("data has too few rows")
  }
  
  # implement quality filters
  {
    data_summary <- data[,.(duration = (max(time) - min(time))/60,
                            prop_fixes = length(x) / ((max(time) - min(time))/3)),
                         by = .(tide_number)]
    data_summary <- data_summary[duration >= tide_duration & prop_fixes >= tide_quality,]
    
    data <- data[tide_number %in% data_summary$tide_number,]
    if(nrow(data) > 1){
      message("processed for quality")
    } else stop("quality processing removed all data")
  }

  # remove data outside the limits of the towers mcp
  {
    # read in tower location data
    towers <- fread("data/towers_2018.csv")
    towers <- st_as_sf(towers, coords = c("X", "Y")) %>% 
      `st_crs<-`(32631)
    towers <- st_union(towers)
    tch <- st_convex_hull(towers)
    
    # remove data outside the bounding box
    bbox <- st_bbox(tch)
    setDT(data)
    data <- data[between(x, bbox[1], bbox[3]) & between(y, bbox[2], bbox[4]),]
  }
  
  # prepare for telemetry
  {
    data_for_ctmm <- setDT(data)[,.(id, tide_number, x, y, time, VARX, VARY)]
    
    # aggregate within a tide to `scale` seconds
    data_for_ctmm <- split(x = data_for_ctmm, f = data_for_ctmm$tide_number) %>%
      map(wat_agg_data, interval = scale) %>%
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
  
  # print model
  {
    if(dir.exists("mod_output") == F)
    {
      dir.create("mod_output")
    }
    
    {
      # get speed estimates with id, tide, and scale
      speed_est <- map(mod, function(model) as.data.table(speed(model, units=FALSE)))
      speed_est <- data.table::rbindlist(speed_est)
      speed_est[,`:=`(id = id_data,
                      scale = scale,
                      tide_number = as.numeric(substring(names(mod), 
                                                         regexpr("_", names(mod)) + 1, 
                                                         nchar(names(mod)))))]
      
      # add tide quality checks
      speed_est <- merge(speed_est, data_summary, by = "tide_number")
      # write data
      fwrite(speed_est, file = "output/speed_estimates_2018.csv", append = TRUE)
      # save the models
      save(mod, file = as.character(glue('output/mods/ctmm_{id_data}_{scale}.rdata')))
    }
    
    {
      # filter data for ctmm based on speed estimate data
      setDT(data)[,.(id, tide_number, x, y, time, VARX, VARY)]
      data <- data[tide_number %in% speed_est$tide_number,]
      data <- split(x = data, f = data$tide_number) %>% 
        map(wat_agg_data, interval = scale) %>% 
        bind_rows() %>% 
        ungroup()
      # get speeds
      inst_speeds <- map2_df(tel, mod, function(obj_tel, ctmm_mod){
        speeds_ <- speeds(object=obj_tel, CTMM=ctmm_mod)
      })
      # join speed to data
      data <- left_join(setDF(data), inst_speeds, by = c("time" = "t"))
      # write data
      fwrite(data, file = as.character(glue('output/mods/speeds_{id_data}_{scale}.csv')))
      #save(inst_speeds, file = as.character(glue('output/mods/speeds_{id_data}_{scale}.rdata')))
    }    
  }
  
  # check model fit
  {
    png(filename = as.character(glue('output/figs/vg_ctmm_{id_data}_{scale}_seconds.png')),
        height = 1600, width = 1600, type = "cairo")
    {
      par(mfrow=c(10, ceiling(length(mod)/ 10)), mar = c(1,1,1,1))
      for(i in 1:length(mod))
      {
        modtype = summary(mod[[i]])$name
        plot(variogram(tel[[i]]), CTMM=mod[[i]], 
             main = as.character(glue('{id_data} : scale = {scale} : {modtype}')))
      }
    }
    dev.off()
  }
  
  # get speed output
  
  
  
}
# ends here

