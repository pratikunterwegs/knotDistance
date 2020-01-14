#### code to get id and release date

library(readr)
library(dplyr)

data <- read_csv("data/SelinDB.csv")

# filter out NAs in release date and time
data <- data %>% 
  filter(!is.na(Toa_Tag), !is.na(Release_Date), !is.na(Release_Time)) %>% 
  mutate(Release_Date = as.POSIXct(paste(Release_Date, Release_Time, sep = " "), 
                                   format = "%d.%m.%y %H:%M", tz = "CET")) %>% 
  select(id = Toa_Tag, Release_Date) %>% 
  arrange(id) %>%
  distinct()

# write release data
write_csv(data, "data/release_data_2018.csv")

# ends here
