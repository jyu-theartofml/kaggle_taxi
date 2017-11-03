#set the working directory, use fread to import large .csv it's much faster

library(data.table)
## the train_data2.csv files is preprocessed with time elements extracted and haversine distance calculated
datasets<-fread("train_data2.csv")
head(datasets)

################## OPTIONAL: Code for computing haversine distance (use radians) ##########################
# Calculates the geodesic distance between two points specified by radian latitude/longitude using the
h_dist <- function(pickup_longitude, pickup_latitude, dropoff_longitude, dropoff_latitude) {
  R <- 6371 # Earth mean radius [km]
  deg2rad <- function(deg) return(deg*pi/180)
  pickup_longitude<-deg2rad(pickup_longitude)
  pickup_latitude<-deg2rad(pickup_latitude)
  dropoff_longitude<-deg2rad(dropoff_longitude)
  dropoff_latitude<-deg2rad(dropoff_latitude)

  delta.long <- (dropoff_longitude - pickup_longitude)
  delta.lat <- (dropoff_latitude - pickup_latitude)
  a <- sin(delta.lat/2)^2 + cos(pickup_latitude) * cos(dropoff_latitude) * sin(delta.long/2)^2
  c <- 2 * asin(min(1,sqrt(a)))
  d = R * c
  return(d) # Distance in km
}

datasets$distance_h<-mapply(h_dist, datasets$pickup_longitude, datasets$pickup_latitude,datasets$dropoff_longitude,datasets$dropoff_latitude)

############################  Use Caret to do grid search on Random Forest ##################
library(randomForest)
library(caret)
library(parallel)
library(doParallel)
library(dplyr)

######## check class, and convert integer columns to numeric ######
sapply(datasets, class)
datasets<- datasets%>% mutate_if(is.integer, as.numeric)

datasets<-na.omit(datasets)
datasets$log_duration<-log(datasets$trip_duration+1)
datasets$trip_duration<-NULL
datasets$vendor_id<-NULL
datasets$dropoff_weekday<-NULL


######### split data #########
trainIndex <- createDataPartition(datasets$log_duration, p = .7,
                                  list = FALSE,
                                  times = 1)
data_train<-datasets[trainIndex,]
data_val<-datasets[-trainIndex,]

rfgrid<- expand.grid(mtry=c(6,13))

set.seed(20)
cv_control <- trainControl(
  method = "cv",
  number = 3)

cluster <- makeCluster(detectCores()-3)# convention to leave 1 node for OS
cluster
registerDoParallel(cluster)

#train function will invoke dummy variables for formula input!
#but randomForest library doesn't do that with formula input
rfFit <- train(log_duration ~ ., data = data_train[1:200000,],
                 method = "rf", ntree=100,
                 trControl = cv_control,
                 tuneGrid=rfgrid,
                 verbose = FALSE, importance=TRUE)


stopCluster(cluster)
registerDoSEQ()

rfFit$results
