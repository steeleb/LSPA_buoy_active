#*****************************************************************
#*      Cary Institute of Ecosystem Studies (Millbrook, NY)      *
#*                                                               *
#* TITLE:   buoy_manual_do_collation.r                           *
#* AUTHOR:  Bethel Steele                                        *
#* PROJECT: Lake Sunapee Buoy Data Cleaning                      *
#*****************************************************************

#this file collates manual DO measurements for calibration of Sunapee Buoy DO data

source('library_func_lists.R')

#point to directories
op_log = 'C:/Users/steeleb/Dropbox/Lake Sunapee/monitoring/buoy data/data/all sensors/operation notes/'
dump_dir = 'C:/Users/steeleb/Dropbox/Lake Sunapee/monitoring/buoy data/data/all sensors/L1/manual_do/'

# manual measurements from the operations log ####

## read in DO from operations log buoy v1 ----
log_v1 <- read_xlsx(file.path(op_log, 'LS Buoy Operation Log - BGS primary.xlsx'),
                    sheet = 'DO Readings',
                    skip = 2) %>% 
  select(Sensor:`Oxygen Sat (%)`)
#format and harmonize
log_v1 <- log_v1%>% # only select necessary columns
  filter(Sensor == 'Handheld') %>%  # select manual measurement
  mutate(date = as.Date(date),
         time = format(Time, '%H:%M'),
         datetime.local = as.POSIXct(paste(date, time, sep = ' '), tz = 'America/New_York')) %>% 
  mutate(datetime.et = with_tz(datetime.local, tz = 'Etc/GMT+5')) %>% 
  rename(depth_m = `Depth(m)`,
         oxygenDissolved_mgl = `DO (mg/l)`,
         waterTemperature_degC = `Temp (°C)`,
         oxygenDissolvedPercentOfSaturation_pct = `Oxygen Sat (%)`) %>% 
  mutate(location = 'loon') %>% 
  select(date, datetime.local, datetime.et, location, depth_m, waterTemperature_degC, oxygenDissolved_mgl, oxygenDissolvedPercentOfSaturation_pct)
log_v1

## read in DO from operations log buoy v2 ----
log_v2_2021 <- read_xlsx(file.path(op_log, 'SUNP_MaintenanceLog_2021.xlsx'),
                    sheet = 'ManualDO')
#format and harmonize
log_v2_2021 <- log_v2_2021 %>% 
  rename(date = Date,
         depth_m = Depth,
         oxygenDissolved_mgl = DO_mgL,
         oxygenDissolvedPercentOfSaturation_pct = DO_Sat,
         waterTemperature_degC = Temp_C,
         location = Site) %>% 
  mutate(date = as.Date(date),
         location = case_when(location == 'buoy' ~ 'loon',
                              location == '210.0' ~ '210',
                              TRUE ~ location))
log_v2_2021

log_v2_2022 <- read_xlsx(file.path(op_log, 'SUNP_MaintenanceLog_2022.xlsx'),
                         sheet = 'ManualDO')
#format and harmonize
log_v2_2022 <- log_v2_2022 %>% 
  select(date = Date,
         depth_m = Depth,
         oxygenDissolved_mgl = DO_mgL,
         oxygenDissolvedPercentOfSaturation_pct = DO_Sat,
         waterTemperature_degC = Temp_C,
         location = Site) %>% 
  mutate(date = as.Date(date),
         location = case_when(location == 'buoy' ~ 'loon',
                              location == '210.0' ~ '210',
                              TRUE ~ location))
log_v2_2022

## merge into one log ----
log <- full_join(log_v1, log_v2_2021) %>% 
  full_join(., log_v2_2022) %>% 
  arrange(date, datetime.et)
log

#plot to check
ggplot(log, aes(x = date, y = oxygenDissolved_mgl)) +
  geom_point()

ggplot(log, aes(x = date, y = oxygenDissolvedPercentOfSaturation_pct)) +
  geom_point()

ggplot(log, aes(x = date, y = waterTemperature_degC)) +
  geom_point()

#add flag to low 2021 value as possibly in sediment
log <- log %>% 
  mutate(flag_domgl = case_when(oxygenDissolved_mgl < 6 ~ 'possibly in sediment',
                                TRUE ~ ''),
         flag_dopct = case_when(oxygenDissolvedPercentOfSaturation_pct < 60 ~ 'possibly in sediment',
                                TRUE ~ ''))

#add data source column
log <- log %>% 
  mutate(data_source = 'operations log')

# manual do from historical record ####
dir.create('tmp')
download.file("https://raw.githubusercontent.com/Lake-Sunapee-Protective-Association/LMP/v2023.1/primary%20files/LSPALMP_1986-2022_v2023-01-22.csv",file.path('tmp', 'LMP_2023.csv'), method = 'curl')
LMP <- read.csv(file.path('tmp', 'LMP_2023.csv'))
unlink('tmp', recursive = T)

head(LMP)
unique(LMP$parameter)
# format and harmonize
do210 <- LMP %>% 
  mutate(date = as.Date(date)) %>% 
  filter((parameter == 'waterTemperature_degC'|parameter == 'oxygenDissolved_mgl' |parameter == 'oxygenDissolvedPercentOfSaturation_pct') & station == 210 & date >= as.Date('2007-01-01')) %>% 
  filter(depth_m < 11) %>% 
  arrange(date, depth_m)%>% 
  rename(location = station)

#look for flags
unique(do210$flag)
unique(do210$gen_flag)
#drop gen flag; no flags
do210$gen_flag = NULL

#plot to double check
ggplot(do210, aes(x = date, y = value, color = depth_m, shape = flag)) +
  geom_point() +
  facet_grid(parameter ~ ., scales = 'free_y') +
  theme(legend.position = 'bottom')

unique(do210$flag)

#filter for only those without flags
do210 <- do210 %>% 
  filter(flag == '')
unique(do210$flag)

head(do210)
do210 <- do210 %>% 
  select(date, depth_m, parameter, value, location)

#plot to double check
ggplot(do210, aes(x = date, y = value, color = depth_m)) +
  geom_point() +
  facet_grid(parameter ~ ., scales = 'free_y') +
  theme(legend.position = 'bottom')

#pivot to match manual measurements
lmp_domgl <- do210 %>% 
  filter(parameter == 'oxygenDissolved_mgl') %>% 
  rename(oxygenDissolved_mgl = value)%>% 
  select(-parameter)
lmp_dosat <- do210 %>% 
  filter(parameter == 'oxygenDissolvedPercentOfSaturation_pct') %>% 
  rename(oxygenDissolvedPercentOfSaturation_pct = value)%>% 
  select(-parameter)
lmp_temp <- do210 %>% 
  filter(parameter == 'waterTemperature_degC') %>% 
  rename(waterTemperature_degC = value) %>% 
  select(-parameter)

lmp_manual <- full_join(lmp_domgl, lmp_dosat) %>% 
  full_join(., lmp_temp) %>% 
  mutate(data_source = 'LMP',
         location = as.character(location))

head(lmp_manual)


# join both data sources and plot ####
manual_do = full_join(log, lmp_manual)
unique(manual_do$flag_domgl)
unique(manual_do$flag_dopct)
manual_do <- manual_do %>% 
  mutate_at(vars(flag_domgl, flag_dopct),
            ~case_when(is.na(.) ~ '',
                       TRUE ~ .))

manual_do <- manual_do %>% 
  filter(flag_domgl == '')

ggplot(manual_do, aes(x = date, y = oxygenDissolvedPercentOfSaturation_pct, color = depth_m, shape = flag_dopct)) +
  geom_point() +
  facet_grid(location ~ .) +
  theme(legend.position = 'bottom')
ggplot(manual_do, aes(x = date, y = oxygenDissolved_mgl, color = depth_m, shape = flag_domgl)) +
  geom_point() +
  facet_grid(location ~ .) +
  theme(legend.position = 'bottom')
ggplot(manual_do, aes(x = date, y = waterTemperature_degC, color = depth_m)) +
  geom_point() +
  facet_grid(location ~ .) +
  theme(legend.position = 'bottom')


# export file ####


startyear = format(min(manual_do$date), '%Y')
endyear = format(max(manual_do$date), '%Y')

manual_do %>% 
  arrange(date, depth_m) %>% 
  select(-datetime.local, -flag_domgl, -flag_dopct) %>% 
  rename(datetime = datetime.et)%>% 
  write.csv(., file.path(dump_dir, paste0('manual_do_', startyear, '-', endyear, '_v', Sys.Date(), '.csv')), row.names = F)
