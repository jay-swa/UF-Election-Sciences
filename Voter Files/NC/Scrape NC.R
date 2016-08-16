#Scrape the North Carolina Statewide Voter File to a local directory
#
#########
# SETUP #
#########
#
# Load required packages

library(sqldf)
library(maptools)
library(RColorBrewer)
library(ggmap)
library(ggplot2)
library(rgeos)
library(png)
library(gridGraphics)

# Working Directory

working.dir <- "D:/Research/Turnout/Voter Files/Analyze/NC/"

# Root archive dir (will automatically create archive subdirectories each week)

archive.dir <- "D:/Research/Turnout/Voter Files/NC/"

# Load FIPS10 to NCSBOE county code conversion table

countycodesfile <- paste(working.dir,"NC_FIPS_NCSBOE.csv",sep="")
countycodes <- read.csv(countycodesfile, header = TRUE, colClasses = c("character", "character"))
countycodes$County <- as.numeric(countycodes$County)

# Initialize current.week.stats, where stats for the current week are stored

current.week.stats <- subset(countycodes,select = "County")

# Load and fortify county shapefile

county.map <- readShapePoly("D:/Research/Turnout/Voter Files/Analyze/NC/tl_2010_37_county10.shp")
county.map <- fortify(county.map, region = "COUNTYFP10")

# Load logo image
logo <- readPNG("D:/Research/Turnout/Voter Files/Analyze/USelections_logo_web.png")
g <- rasterGrob(logo, interpolate=TRUE)

###############
# SCRAPE FILE #
###############
#
# Vote history url (to be used later):
# url <- "https://s3.amazonaws.com/dl.ncsbe.gov/data/ncvhis_Statewide.zip"
#
# Statewide voter file url

url <- "https://s3.amazonaws.com/dl.ncsbe.gov/data/ncvoter_Statewide.zip"
destfile <- "D:/Research/Turnout/Voter Files/Analyze/NC/ncvoter_Statewide.zip"

download.file(url, destfile, mode = "wb")

# unzip file

# set destination directory for zip file

current.week.file <- paste(working.dir,"ncvoter_Statewide.txt", sep="")

file.remove(current.week.file)

zipdest = "D:/Research/Turnout/Voter Files/Analyze/NC"

unzip(destfile, exdir=zipdest, overwrite = TRUE)

# get current week file creation date (used for output)

current.date <- file.info(current.week.file)$ctime
current.date <- paste(substr(current.date,1,4),substr(current.date,6,7),substr(current.date,9,10),sep="")
current.date
# Archive current week zip file using creation date of file to create directory
# (Need to check if file exists, if not, do these steps)

current.date.dir <- paste(substr(current.date,1,4),substr(current.date,6,7),substr(current.date,9,10),sep="")
dir.create(paste(archive.dir,current.date.dir,sep=""))

# move zip file to archive

file.copy(paste(working.dir,"ncvoter_Statewide.zip",sep=""),paste(archive.dir, "ncvoter_Statewide.zip",sep=""))

####################
# READ DATA INTO R #
####################
#
# Assumes the voter file for the last week has been processed. On first time 
# run need to set up last week file in  
#

# Data fields for NC to read in (need to change for other states)

readcolumns = c(NA, "NULL", NA, NA, NA, NA, "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", NA, NA, NA, NA, "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", "NULL", NA, NA, NA, NA, NA)

# Load current week file

currentweek <- read.csv(current.week.file, header = TRUE, sep = "\t", quote = "\"", dec = ".", fill = TRUE, colClasses = readcolumns)

# Load last week file 

lastweekfile <- "D:/Research/Turnout/Voter Files/Analyze/NC/ncvoter_Statewide_last.txt"
lastweek <- read.csv(lastweekfile, header = TRUE, sep = "\t", quote = "\"", dec = ".", fill = TRUE, colClasses = readcolumns)

# lastweekfile <- "D:/Research/Turnout/Voter Files/Analyze/NC/lastweek.csv"
# lastweek <- read.csv(lastweekfile, header = TRUE, sep = ",", quote = "\"", dec = ".", fill = TRUE)

###########
# ANALYZE #
###########
#
# Example: number of records by county in currentweek
#
# Simple SQL to statement using sqldf package to compute number of records by county
# notes:
# 
# SQL is not an intuitive language, but it is very versitle and widely used 
#
# SELECT tells you which variables you want to select FROM in a table, in this case, the currentweek voter file.
# You can use functions in SELECT. Here we select the county_id and, effectively, a count of the number of records
# in each county_id, County(county_id). More variables and functions of variables can be added to the statement.
# (hint: you can use any variable for a count, but be careful if the variable has null values. For this reason I usually use
# the variable I wish to GROUP BY when I county records)
# To count the records by county, use GROUP BY couny_id. 
	
query <- sqldf("SELECT county_id, Count(county_id) AS filldata FROM currentweek GROUP BY county_id")

# Load shapefile

county.map <- readShapePoly("D:/Research/Turnout/Voter Files/Analyze/NC/tl_2010_37_county10.shp")

# R can't really manipulate shapefiles, so need to "fortify" shapefile to make it usable to R
# note that the county identified variable COUNTYFP10 is identified as the unique region identfier.
# The values for COUNTYFP10 will be placed into a new variable called id. This new table contains a record
# for each unique geographical point (or node) in the shapefile

county.map <- fortify(county.map, region = "COUNTYFP10")

# fortify strips out what it sees as extraneous data, which is any non-spatial data you might like to plot
# so, we need to merge the spatial data with any data we might like to plot

# first, we've got to add a county identifier to the voter file that is consistent with the county identifer
# in the shapefile. I've created a file called countycodes which creates this correspondence.
# For data management purposes, and some other buggy behavior of R, it is recommended to merge the the 
# voterstat table with the countycodes first

temp <- merge(x = countycodes, y = query, by.x = "County", by.y= "county_id", all=TRUE)

# Now merge the data we would like to plot with the shapefile data

county.map <- merge(x = county.map, y = temp, by.x = "id", by.y = "COUNTYFP10", all.x = TRUE, sort=FALSE)

# And we can now plot the data

ggplot() +
geom_polygon(data=county.map, aes(x=long,y=lat, group=group, fill=filldata), color="black") +
coord_map() +
scale_fill_distiller(name="Total Records", palette = "YlGn")+
  theme_nothing(legend = TRUE)+
  labs(title="North Carolina Total Records by County")

# save the plot to disk

save.image.file <- paste(working.dir,"NC_records_",current.date,".jpg", sep="")
ggsave(save.image.file, device = "jpeg")

# Clean up by dropping the filldata and County from county.map (the two variables merged from temp)
# We don't want to append too many variables to county.map since it has many records
# We can now reuse county.map without having to reload it and fortify it

county.map$filldata <- NULL
county.map$County <- NULL

# The code can now be reused to generate more maps. We don't need to reload or fortify the shapefile
# Do need to:
# - Change the SQL statement 
# - Change map map lables

######################
# Reg Voters - Total #
######################
#
# Number of Active ("A"), Inactive ("I") or Temporary Overseas ("S") voters
#

query <- sqldf("SELECT county_id, Count(county_id) AS filldata FROM currentweek WHERE(((status_cd)=\"A\" Or (status_cd)=\"I\" Or (status_cd)=\"S\")) GROUP BY county_id")
temp <- merge(x = countycodes, y = query, by.x = "County", by.y= "county_id", all=TRUE)

# append query statistics to current.week.stats

temp <- subset(temp,select = c("County","filldata"))
colnames(temp)[2] = "reg.voter.total"
current.week.stats <- merge(x = current.week.stats, y = temp, by = "County", all=TRUE)

# append query statistics to shapefile

county.map <- merge(x = county.map, y = temp, by.x = "id", by.y = "COUNTYFP10", all.x = TRUE, sort=FALSE)

# Plot

titletxt <- paste("North Carolina Registered Voters as of ",substr(current.date,5,6),"/",substr(current.date,7,8),sep="")

ggplot() +
geom_polygon(data=county.map, aes(x=long,y=lat, group=group, fill=filldata), color="black") +
coord_map() +
scale_fill_distiller(name="Reg Voters", palette = "YlGn")+
  theme_nothing(legend = TRUE)+
  labs(title=titletxt)
save.image.file <- paste(working.dir,"NC_regvoters_",current.date,".jpg", sep="")
ggsave(save.image.file, device = "jpeg")

# Clean up

county.map$filldata <- NULL
county.map$County <- NULL

##########
# UOCAVA #
##########
#
# (reason_cd = miltary ("SM") or overseas citizen ("SO") voters)
#

query <- sqldf("SELECT county_id, Count(county_id) AS filldata FROM currentweek WHERE(((reason_cd)=\"SM\" Or (reason_cd)=\"SO\")) GROUP BY county_id")
temp <- merge(x = countycodes, y = query, by.x = "County", by.y= "county_id", all=TRUE)

temp <- subset(temp,select = c("County","filldata"))
colnames(temp)[2] = "UOCAVA"
current.week.stats <- merge(x = current.week.stats, y = temp, by = "County", all=TRUE)

county.map <- merge(x = county.map, y = temp, by.x = "id", by.y = "COUNTYFP10", all.x = TRUE, sort=FALSE)

titletxt <- paste("North Carolina Military and Overseas Citizen voters as of ",substr(current.date,5,6),"/",substr(current.date,7,8),sep="")

ggplot() +
geom_polygon(data=county.map, aes(x=long,y=lat, group=group, fill=filldata), color="black") +
coord_map() +
scale_fill_distiller(name="UOCAVA Voters", palette = "YlGn")+
  theme_nothing(legend = TRUE)+
  labs(title=titletxt)
save.image.file <- paste(working.dir,"NC_UOCAVA_",current.date,".jpg", sep="")
ggsave(save.image.file, device = "jpeg")
county.map$filldata <- NULL
county.map$County <- NULL

#########################
# Cancelled Records     #
#########################
#
# Those records that are in last week but not in current week

# pare down the voter file data frames to merge on the first two columns
# (county_id and voter_reg_num) and include the 3rd column, status_cd

keepvars <- c("county_id","voter_reg_num","status_cd","party_cd","race_code","ethnic_code","birth_age")

current.temp <- currentweek[keepvars]
last.temp <- lastweek[keepvars]

# Need to ensure names are different in two tables (will fix this later in Clean up!)

colnames(last.temp)[1] = "county_id_last"
colnames(last.temp)[2] = "voter_reg_num_last"
colnames(last.temp)[3] = "status_cd_last"
colnames(last.temp)[4] = "party_cd_last"
colnames(last.temp)[4] = "race_code_last"
colnames(last.temp)[4] = "ethnic_code_last"
colnames(last.temp)[4] = "birth_age_last"



# sqldf does not do INNER and OUTER joins, so use merge to do these joins
# since y = lastid, all.y ensures that all records in last week will be included in merge
# those records with a Null value for status_cd (i.e., status_cd from current week) are those
# lastweek records that do not appear in current week (i.e., purged)

combinedtemp <- merge(x = last.temp, y = current.temp, by.y = c("voter_reg_num"), by.x =c("voter_reg_num_last"), all.x = TRUE)

# get counts of purged records (those in last.temp but not in current.temp) by county

query <-sqldf("SELECT county_id_last, COUNT(voter_reg_num_last) AS filldata FROM combinedtemp WHERE status_cd is null GROUP BY county_id_last")
temp <- merge(x = countycodes, y = query, by.x = "County", by.y= "county_id_last", all.x=TRUE)

temp.stats <- subset(temp,select = c("County","filldata"))
colnames(temp.stats)[2] = "purged.records"
current.week.stats <- merge(x = current.week.stats, y = temp.stats, by = "County", all=TRUE)

county.map <- merge(x = county.map, y = temp, by.x = "id", by.y = "COUNTYFP10", all.x = TRUE, sort=FALSE)

titletxt <- paste("North Carolina Canceled Registrations in Week Ending ",substr(current.date,5,6),"/",substr(current.date,7,8),sep="")

ggplot() +
geom_polygon(data=county.map, aes(x=long,y=lat, group=group, fill=filldata), color="black") +
coord_map() +
scale_fill_distiller(name="Canceled Reg", palette = "YlGn", na.value = 'white')+
  theme_nothing(legend = TRUE)+
  labs(title=titletxt)
save.image.file <- paste(working.dir,"NC_canceled_",current.date,".jpg", sep="")
ggsave(save.image.file, device = "jpeg")

# plot canceled records as percent of active, inactive, and UOCAVA voters

temp <- merge(x = temp, y = current.week.stats, by = "County", all = TRUE)
temp$pcanceled <- temp$filldata/temp$regvoters

titletxt <- paste("North Carolina Cancelation Rate of Registered Voters in Week Ending ",substr(current.date,5,6),"/",substr(current.date,7,8),sep="")

ggplot() +
geom_polygon(data=county.map, aes(x=long,y=lat, group=group, fill=pcanceled), color="black") +
coord_map() +
scale_fill_distiller(name="Purged Voter Rate", palette = "YlGn", na.value = 'white')+
  theme_nothing(legend = TRUE)+
  labs(title=titletxt)
save.image.file <- paste(working.dir,"NC_purged_rate_",current.date,".jpg", sep="")
ggsave(save.image.file, device = "jpeg")

county.map$filldata <- NULL
county.map$County <- NULL
combinedtemp <- NULL

#########################
# Purged Voters         #
#########################
#
# Records that have been changed from Active, Inactive, or Temporary status in last week
# to Denied or Removed in current week

combinedtemp <- merge(x = last.temp, y = current.temp, by.x = c("voter_reg_num_last","county_id_last"), by.y = c("voter_reg_num","county_id"), all.x = TRUE)

query1 <-sqldf("SELECT county_id_last, voter_reg_num_last FROM combinedtemp WHERE (((status_cd_last='A') AND ((status_cd='D') OR (status_cd='R'))) OR ((status_cd_last='I') AND ((status_cd='D') OR (status_cd='R'))) OR ((status_cd_last='S') AND ((status_cd='D') OR (status_cd='R'))))")
query2 <-sqldf("SELECT county_id_last, COUNT(voter_reg_num_last) AS filldata FROM query1 GROUP BY county_id_last")

temp <- merge(x = countycodes, y = query2, by.x = "County", by.y= "county_id_last", all.x=TRUE)

temp.stats <- subset(temp,select = c("County","filldata"))
colnames(temp.stats)[2] = "purged.records"
current.week.stats <- merge(x = current.week.stats, y = temp.stats, by = "County", all=TRUE)

county.map <- merge(x = county.map, y = temp, by.x = "id", by.y = "COUNTYFP10", all.x = TRUE, sort=FALSE)

titletxt <- paste("North Carolina Purged Registrations in Week Ending ",substr(current.date,5,6),"/",substr(current.date,7,8),sep="")

ggplot() +
geom_polygon(data=county.map, aes(x=long,y=lat, group=group, fill=filldata), color="black") +
coord_map() +
scale_fill_distiller(name="Purge Reg", palette = "YlGn", na.value = 'white')+
  theme_nothing(legend = TRUE)+
  labs(title=titletxt)
save.image.file <- paste(working.dir,"NC_purged_",current.date,".jpg", sep="")
ggsave(save.image.file, device = "jpeg")



# New voters 

combinedtemp <- merge(x = current.temp, y = last.temp, by.x =c("voter_reg_num", "county_id"), by.y = c("voter_reg_num_last", "county_id_last"), all.x = TRUE)

# get counts of new records (those in current.temp but not in last.temp) by county

query<-sqldf("SELECT county_id, COUNT(voter_reg_num) AS filldata FROM combinedtemp WHERE status_cd_last is null GROUP BY county_id") 
temp <- merge(x = countycodes, y = query, by.x = "County", by.y= "county_id", all=TRUE)
county.map <- merge(x = county.map, y = temp, by.x = "id", by.y = "COUNTYFP10", all.x = TRUE, sort=FALSE)
#county.map$filldata[is.na(county.map$filldata)]<-0

titletxt <- paste("North Carolina New Registered Voters in Week Ending ",substr(current.date,5,6),"/",substr(current.date,7,8),sep="")

logo <- readPNG("D:/Research/Turnout/Voter Files/Analyze/USelections_logo_web.png")
g <- rasterGrob(logo, interpolate=TRUE)

base <- ggplot() +
geom_polygon(data=county.map, aes(x=long,y=lat, group=group, fill=filldata), color="black") +
coord_map() +
scale_fill_distiller(name="New Reg Voters", palette = "Blues", trans="reverse", na.value = 'white') +
  theme_nothing(legend = TRUE) +
  labs(title=titletxt)
base + annotation_custom(grob = g, xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf)

save.image.file <- paste(working.dir,"NC_newreg_",current.date,".jpg", sep="")
ggsave(save.image.file, device = "jpeg")
county.map$filldata <- NULL
county.map$County <- NULL
combinedtemp <- NULL

############
# CLEAN UP #
############
#
# save reduced current week file to scratch directory to use next week, call it lastweek
#

write.table(currentweek, lastweekfile, sep = ",", quote = TRUE, dec = ".", col.names = TRUE, row.names = FALSE)

# delete zip and text file from scratch directory

file.remove(paste(working.dir,"ncvoter_Statewide.zip",sep=""))
file.remove(paste(working.dir,"ncvoter_Statewide.txt",sep="")) 
