#############
# Data steps
# 6.6.19
# BHO
#############

#Set working directory to the location of this file
#setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

#Functions
source("Functions.R")

#Packages
packages <- c("reshape2", "plyr", "data.table", "car", "lme4", "stargazer",
              "knitr", "ggplot2", "cowplot")
package.check(packages)

############################################
# Summarize covariates for AR, MI, WI, and MN
############################################

#Read in sites
sites <- read.csv("Data/AllLakes_SiteInfo_2016.csv")
colnames(sites)[1] <- "FM_Name"
sites[,c("Photo1", "Photo2", "Photo3")] <- NULL
sites$Region <- ifelse(sites$Latitude > 38, "NorthCentral", "SouthCentral")
sites$Region <- as.factor(sites$Region)

#Calculate count of all fish caught in each lake  
fish <- read.csv("Data/AllLakes_Fish_2016.csv") #Read in fish data
total.fish <- aggregate(Count ~ SiteVisit_Record_ID_Fish, data=fish, sum) #Sum fish by lake
colnames(total.fish)[2] <- "TotalFish"
total.fish$FM_Name <- sapply(strsplit(as.character(total.fish$SiteVisit_Record_ID_Fish),"_"),'[',1) #Create name column to join by later
total.fish <- join(total.fish, sites, by = "FM_Name")
total.fish$Fish.perhaul <- total.fish$TotalFish/3 #Get mean number of fish per seine haul
total.fish$Fish.Densitym2 <- ifelse(total.fish$Region == "NorthCentral" |
                                    total.fish$State != "AR" |
                                    total.fish$FM_Name == "MerrisachLake" |
                                    total.fish$FM_Name == "MonticelloLake" |
                                    total.fish$FM_Name == "RickEvansWMA" |
                                    total.fish$FM_Name == "WhiteOakLane", 
                                    total.fish$Fish.perhaul/(3*1.5), #Divide by surface area of seine to get fish per m2 of seine
                                    total.fish$Fish.perhaul/(4.5*1.5)) #Different seine sizes used in NW AR vs rest of the study

rm(fish) #Clean up unnecessary dataframes

#Calculate density of zooplankton prey per L sampled.
zoop <- read.csv("Data/AllLakes_Zooplankton_2016.csv")

zoop$Count <- as.numeric(as.character(zoop$Count))

prey <- subset(zoop, Prey == "Y") #Subset out the zooplankton that have been flagged as prey items
prey1 <- aggregate(Count ~ Lake, sum, data=prey) #Sum of zooplankton prey items by lake
colnames(prey1) <- c("FM_Name", "Prey.Count")
prey1$FM_Name <- as.character(prey1$FM_Name)  #Create name column to join by later
prey1$FM_Name <- ifelse(prey1$FM_Name == "LockandDamPond", "LockAndDamPond", prey1$FM_Name) #Fix naming inconsistencies in the data file
prey1$Prey.CPU <- prey1$Prey.Count/6 #Mean number of prey items per sample
prey1$Prey.DensityL <- prey1$Prey.CPU/6.95 #Mean prey per sample divided by volume of sample (6.95 L in 2016)

diversity <- setDT(prey)[, .(count = uniqueN(Taxa)), by = Lake] #This step requires the data.table package
colnames(diversity)[1] <- "FM_Name"
diversity$FM_Name <- as.character(diversity$FM_Name)
diversity$FM_Name <- ifelse(diversity$FM_Name == "LockandDamPond", "LockAndDamPond", diversity$FM_Name) #Fix naming inconsistencies in the data file
diversity$FM_Name <- as.factor(diversity$FM_Name)
prey <- join(prey1, diversity, by = "FM_Name", type = "left")
colnames(prey)[5] <- "Prey.Diversity"

rm(prey1, zoop, diversity) #Clean up unnecessary dataframes

#Calculate density and percent coverage of macrophytes    
macro <- read.csv("Data/AllLakes_Macrophyte_2016.csv") #Read in macrophyte data

macro <- aggregate(cbind(Shoot.Count, Per.Coverage) ~ SiteVisit_Record_ID_MacrophyteRaw, sum, data=macro) #Sum of shoot count and percent coverages by lake
macro$FM_Name <- sapply(strsplit(as.character(macro$SiteVisit_Record_ID_MacrophyteRaw),"_"),'[',1) #Create name column to join by later
macro$FM_Name <-ifelse(macro$FM_Name == "LockandDamPond", "LockAndDamPond", macro$FM_Name) #Fix naming inconsistencies in the data file
macro$Shoot.Countm2 <- (macro$Shoot.Count/10)*4 #Mean number of shoots per m2
macro$Mean.Per.Cover <- ifelse(macro$Per.Coverage / 10 > 100, 100, macro$Per.Coverage / 10) #Mean percent cover of macrophytes  

macro[,2:3] <- NULL  

#Summarize larval odonate data

#Read in the file that has larval measurements from 20 Arkansas focal lakes
meas <- read.csv("Data/AllLakes_Measurements_2016.csv", stringsAsFactors = FALSE)
meas[8:13] <- NULL                          #Delete empty columns

meas.counts <- ddply(meas, .(meas$FM_Name, meas$SamplingRound), nrow) #Count of Enallagma per site per visit (2 in 2016)
colnames(meas.counts) <- c("FM_Name","Sampling.Round","Meas.Count") 

#Read in file that contains counts of non-enallagma odonate larvae and unidentified Enallagma (too small to ID)
other.abun <- read.csv("Data/AllLakes_NonEnallagmaAbun_2016.csv")
other.abun <- subset(other.abun, !is.na(Count))
other.abun$Sampling.Round <- as.factor(other.abun$Sampling.Round)
other.abun <- reshape2::dcast(other.abun, FM_Name+Sampling.Round ~ Group,
                              value.var = "Count", sum)

#Replace NAs with 0's
other.abun$Dragonflies <- ifelse(is.na(other.abun$Dragonflies), 0, other.abun$Dragonflies)
other.abun$Ischnura <- ifelse(is.na(other.abun$Ischnura), 0, other.abun$Ischnura)
other.abun$Enallagma.Unk <- ifelse(is.na(other.abun$Enallagma), 0, other.abun$Enallagma)
other.abun$Lestes <- ifelse(is.na(other.abun$Lestes),0,other.abun$Lestes)
other.abun$Argia <- ifelse(is.na(other.abun$Argia),0,other.abun$Argia)


#Join 2 count dataframes  
abun <- join(other.abun,meas.counts, by=c("FM_Name", "Sampling.Round"))

#Combine Enallamga identified to species with those just to genus  
abun$Enallagma <- abun$Enallagma.Unk + abun$Meas.Count
abun[,c(8,9)] <- NULL

#Add in a sampling round
abun.round <- meas[,c('Date','FM_Name','SamplingRound')]
abun.round <- ddply(abun.round,.(abun.round$FM_Name, abun.round$Date, abun.round$SamplingRound),nrow)
abun.round[4] <- NULL
colnames(abun.round) <- c("FM_Name", "Date","Sampling.Round")


abun <- join(abun, abun.round, by=c("FM_Name","Sampling.Round"), type="left")

#Add counts of all odonates by lake and sampling round to get count of odonate competitors
abun$Competitor <- abun$Enallagma+abun$Ischnura+abun$Argia+abun$Dragonflies+abun$Lestes
abun$Competitorm2 <- abun$Competitor/10

#Calculate relative abundances by group
abun$Rel.Argia <- abun$Argia / abun$Competitor
abun$Rel.Dragonflies <- abun$Dragonflies / abun$Competitor
abun$Rel.Enallagma <- abun$Enallagma / abun$Competitor
abun$Rel.Ischnura <- abun$Ischnura / abun$Competitor
abun$Rel.Lestes <- abun$Lestes / abun$Competitor

#Format Date so R recognizes it
abun.per <- subset(abun, nchar(abun$Date) < 9)
abun.per$Date <- as.Date(abun.per$Date, format = "%m.%d.%y")

abun.slash <- subset(abun, nchar(abun$Date) > 8)
abun.slash$Date <- as.Date(abun.slash$Date, format = "%m/%d/%Y")

abun <- rbind(abun.per, abun.slash)

rm(abun.round, meas, meas.counts, other.abun, abun.per, abun.slash)  

#Add in mean water measures
water <- read.csv("Data/AllLakes_WaterQuality_2016.csv")

#Get mean of 3 samples
#water$WaterTemp <- (water$WaterTemp_Rep1 + water$WaterTemp_Rep2 + water$WaterTemp_Rep3) / 3
#water$DO <- (water$DO_Rep1 + water$DO_Rep2 + water$DO_Rep3) / 3
#water$DO.percent <- (water$DO.percent_Rep1 + water$DO.percent_Rep2 + water$DO.percent_Rep3) / 3
#water$DO.ppm <- (water$DO.ppm_Rep1 + water$DO.ppm_Rep2 + water$DO.ppm_Rep3) / 3
water$Conductivity <- (water$Conductivity_Rep1 + water$Conductivity_Rep2 + water$Conductivity_Rep3) / 3
#water$SPC <- (water$SPC_Rep1 + water$SPC_Rep2 + water$SPC_Rep3) / 3
water$Salinity <- (water$Salinity_Rep1 + water$Salinity_Rep2 + water$Salinity_Rep3) / 3
#water$TDS <- (water$TDS_Rep1 + water$TDS_Rep2 + water$TDS_Rep3) / 3
water$pH <- (water$pH_Rep1 + water$pH_Rep2 + water$pH_Rep3) / 3

water$FM_Name <- as.factor(sapply(strsplit(as.character(water$SiteVisit_Record_ID_WaterQuality),"_"),'[',1)) #Create name column to join by later

water[,c(1:37)] <- NULL

#Chl-a
chla <- read.csv("Data/AllLakes_ChlA_2016.csv")
chla$chla.ug.L <- (chla$ChlA.ug.L.Rep1 + chla$ChlA.ug.L.Rep2) / 2
chla[,c(2:7)] <- NULL
colnames(chla)[1] <- "FM_Name"

#Merge dataframes to make single dataframe
df1 <- join(total.fish, macro, by = "FM_Name", type = "left")
df2 <- join(df1, water, by = "FM_Name", type = "left")
df3 <- join(df2, chla, by = "FM_Name", type = "left")
df4 <- join(df3, prey, by = "FM_Name", type = "left")
df5 <- join(abun, df4, by = "FM_Name", type = "left")

##################################################################
#Add in measurements of individual larvae for AR, MI, WI, and MN
##################################################################

meas <- read.csv('Data/AllLakes_Measurements_2016.csv')
meas[,c(2,8:13)] <- NULL                          #Delete empty columns

meas$Species <- revalue(meas$Species, c("ENDI" = "ENEX"))
colnames(meas)[6] <- 'Sampling.Round'
meas$Sampling.Round <- as.factor(meas$Sampling.Round)

df <- join(meas, df5, by = c('FM_Name', 'Sampling.Round'))

df <- df[,c('FM_Name', 'Species', 'HW', 'OWPL', 'Sampling.Round',
            'Date', 'Region', 'Fish.Densitym2', 'Shoot.Countm2', 'Prey.CPU',
            'Prey.Diversity', 'Competitorm2', 'Conductivity', 'Salinity', 'pH',
            'chla.ug.L')]

covar <- df5[, c("FM_Name", "pH", "Conductivity", "Salinity")]
colnames(covar)[1] <- "FM_Name" 

rm(list= ls()[!(ls() %in% c('df','covar'))])

################
# VT and NH
################

nh <- read.csv('Data/VTNH_measurements.csv')
nh$HW <- as.numeric(as.character(nh$HW))
nh$OWPL <- as.numeric(as.character(nh$OWPL))
nh$TL <- as.numeric(as.character(nh$TL))

nh[,c(2,4,6,10,11,12)] <- NULL

nh$sample.date <- as.Date(nh$sample.date, format="%m/%d/%Y")
colnames(nh)[c(2,3)] <- c("Date", "Sampling.Round")
nh$Sampling.Round <- as.factor(nh$Sampling.Round)

nh.env <- read.csv('Data/VTNH_environmental.csv')
nh.env <- nh.env[-c(41:43),]

prey <- nh.env[,c(1,36:65)]

prey <- melt(prey, id.vars=c("Lake"))
colnames(prey)[2] <- 'Taxa'
prey <- subset(prey, value > 0)

diversity <- setDT(prey)[, .(count = uniqueN(Taxa)), by = Lake]

nh.env <- nh.env[,c(1,5:7,15, 16, 17, 21, 22, 23, 28, 66)] #uS = cond, salinity = ppt, H20 PC1, No TDS
 
nh.env$Competitor <- nh.env$Total.Enallagma + nh.env$Total.ischnura + 
                       nh.env$Total.Lestes + (10*nh.env$dragonfly.abundance)
nh.env$Competitorm2 <- nh.env$Competitor/10

colnames(nh.env)[6] <- "Conductivity"
colnames(nh.env)[7] <- "Salinity"
colnames(nh.env)[8] <- "chla.ug.L"
colnames(nh.env)[9] <- "Shoot.Countm2"
colnames(nh.env)[10] <- "Fish.Densitym2"
nh.env$Fish.Densitym2 <- nh.env$Fish.Densitym2/(4.5*1.5)
colnames(nh.env)[12] <- "Prey.CPU"

nh.env <-join(nh.env, diversity)
colnames(nh.env)[15] <-'Prey.Diversity'

nh <- join(nh, nh.env)

nh <- subset(nh, species!='Ischnura' & species!='Lestes' & species!='Nehalennia' 
             & species!='Dragonflies' & species!='Argia')
colnames(nh)[7] <- "Species"
nh$Region <- as.factor(rep("NE", nrow(nh)))

nh <- nh[,c('Lake', 'Species', 'HW', 'OWPL', 'Sampling.Round',
            'Date', 'Region', 'Fish.Densitym2', 'Shoot.Countm2', 'Prey.CPU',
            'Prey.Diversity', 'Competitorm2', 'Conductivity', 'Salinity', 'pH',
            'chla.ug.L')]

colnames(nh)[1] <- 'FM_Name'
colnames(nh.env)[1] <- 'FM_Name'

df <- rbind(df, nh)

h2o <- rbind(covar, nh.env[,c(1,5:7)])
h2o <- h2o[!duplicated(h2o$FM_Name), ]  #Remove duplicates

rm(list= ls()[!(ls() %in% c('df', 'h2o'))])

########################################
# Collapse water quality to single axis
########################################

h2o.no.name <- h2o[,-1]

h2o.pca <- prcomp(h2o.no.name,
                  center = TRUE,
                  scale. = TRUE) 

# plot(h2o.pca, type="l")
# summary(h2o.pca)
# print(h2o.pca)

loadings <- h2o$rotation
h2o.pca <- predict(h2o.pca, newdata = h2o.no.name) 
h2o.pca <- as.data.frame(h2o.pca)
h2o.pca <- subset(h2o.pca, select=c(1))

h2o <- cbind(h2o[,1], h2o.pca)
colnames(h2o) <- c('FM_Name', 'H2O.PC1')

df <- plyr::join(df, h2o, by = 'FM_Name')

############################
# Add in Lat and Long
############################

#Imputed mean NE lat for Pinnacle
coords <- read.csv("Data/Site_Coords.csv")
df <- join(df, coords[1:3], by = "FM_Name")

nh <- subset(df, Region == "NE")

df$Lat <- ifelse(is.na(df$Lat), 
                  mean(nh$Lat, na.rm = TRUE),
                  df$Lat)

df$Long <- ifelse(is.na(df$Long), 
                  mean(nh$Long, na.rm = TRUE),
                  df$Long)


rm(list= ls()[!(ls() %in% c('df'))])

#############################
# Split into regions
#############################

df$lOWPL<-log(df$OWPL)
df$lHW <- log(df$HW)

# Split into regions and dropped species if we did not capture at least 10
# individuals at more than 2 sites

df.S<-subset(df, Region=='SouthCentral')
df.S<-subset(df.S, Species!="ENGE" & Species != 'ENCI')
df.S<-subset(df.S, !is.na(OWPL) & !is.na(HW))

df.N<-subset(df, Region=='NorthCentral')
df.N<-subset(df.N, Species != "ENTR" & Species != 'ENVERN')
df.N<-subset(df.N, !is.na(OWPL) & !is.na(HW))

df.E<-subset(df, Region == "NE")  
df.E<-subset(df.E, Species != "ENAS" & Species != "ENMI"  & 
               Species != "ENTR" & Species != "ENEX" & 
               Species != "ENVERN"  & Species != "ENPI")
df.E<-subset(df.E, !is.na(OWPL) & !is.na(HW))

#Drop unused factor levels
df.S[] <- lapply(df.S, function(x) if(is.factor(x)) factor(x) else x)
df.N[] <- lapply(df.N, function(x) if(is.factor(x)) factor(x) else x)
df.E[] <- lapply(df.E, function(x) if(is.factor(x)) factor(x) else x)

#Extract residuals
rS<-lm(log(HW) ~ log(OWPL), data=df.S)
rN<-lm(log(HW) ~ log(OWPL), data=df.N)
rE<-lm(log(HW) ~ log(OWPL), data=df.E)

df.NAll <-rbind(df.N, df.E)
rNAll<-lm(log(HW) ~ log(OWPL), data=df.NAll)

df.N$resid.HW<-residuals(rN)
df.S$resid.HW<-residuals(rS)
df.E$resid.HW<-residuals(rE)
df.NAll$resid.HW<-residuals(rNAll)

df.Ss<-as.data.frame(scale(df.S[,c(8:19)]))
df.S2<-cbind(df.S[,c(1:7,20:22)], df.Ss)

df.Ns<-as.data.frame(scale(df.N[,c(8:19)]))
df.N2<-cbind(df.N[,c(1:7, 20:22)], df.Ns)

df.Es<-as.data.frame(scale(df.E[,c(8:19)]))
df.E2<-cbind(df.E[,c(1:7, 20:22)], df.Es)

df.NAlls<-as.data.frame(scale(df.NAll[,c(8:19)]))
df.NAll2<-cbind(df.NAll[,c(1:7, 20:22)], df.NAlls)
