setwd("Z:/kaggle/taxi")
train_data=read.csv("train.csv")
head(train_data)


############ Extract date elements using lubridate ##############
library(lubridate)
train_data$pickup_datetime<-as.character(train_data$pickup_datetime)
train_data$dropoff_datetime<-as.character(train_data$dropoff_datetime)

train_data$pickup_month<-month(train_data$pickup_datetime)
train_data$pickup_day<-day(train_data$pickup_datetime)
train_data$pickup_hour<-hour(train_data$pickup_datetime)
train_data$pickup_weekday<-wday(train_data$pickup_datetime, label=TRUE)

train_data$dropoff_month<-month(train_data$dropoff_datetime)
train_data$dropoff_day<-day(train_data$dropoff_datetime)
train_data$dropoff_hour<-hour(train_data$dropoff_datetime)
train_data$dropoff_weekday<-wday(train_data$dropoff_datetime, label=TRUE)

###############  Save modified files ##############
write.csv(train_data, file="train_data2.csv")
train_data<-read.csv("train_data2.csv")
head(train_data)


######################## Visualize data through ggplot ggmap #####################
library(ggplot2)
library(viridis)
library(ggmap)
#gather all GPS coordinate for both pickup and dropoff with duration greater or equal to 1200 seconds

library(dplyr)
subset_data <- train_data %>% filter(trip_duration>1200)
dim(subset_data)
### x is longitude, y is latitude ###############
m <- get_map("New York City",zoom=14,maptype='toner-lite',source="stamen")
pickup<-ggmap(m) + geom_point(aes(x=pickup_longitude,y=pickup_latitude,size=trip_duration),colour="turquoise4", alpha=0.2,data=subset_data)+ggtitle("Pick up")
dropoff<-ggmap(m) + geom_point(aes(x=dropoff_longitude,y=dropoff_latitude,size=trip_duration),colour="indianred3", alpha=0.2,data=subset_data)+ggtitle("Drop off")
#################### Use gridExtra to arrange the two plots ################
library(gridExtra)
library(grid)
grid.arrange(pickup, dropoff, ncol = 2)


####################### Plot contour with overlay ###########################

p <- get_map("New York City",zoom=14,maptype='toner-lite',source="stamen")

data_pickup<-subset_data %>% select (starts_with("pickup_l"))
data_dropoff<-subset_data %>% select (starts_with("dropoff_l"))
colnames(data_pickup)<-c('lon', 'lat')
colnames(data_dropoff)<-c('lon', 'lat')
combo_data<-rbind(data.frame(data_pickup, group="pickup"), data.frame(data_dropoff, group="dropoff"))


ggmap(p)+ stat_density_2d(data=combo_data, geom ='polygon', bins=10, aes(x=lon, y=lat, fill=group, alpha=..level..))+
  scale_fill_manual(values=c('pickup'='orchid4', 'dropoff'='darkorange1'))+
  scale_alpha(guide = FALSE)



##################### Look at trip numbers by hours and day of week #####################

pickup_sum_data<-subset_data %>% 
  group_by(pickup_hour, pickup_weekday) %>%
  summarise(total = n())
  
head(pickup_sum_data)
#put weekday string values into level so they appear in order 
pickup_sum_data$pickup_weekday<-factor(pickup_sum_data$pickup_weekday, levels=c('Mon', 'Tues', 'Wed','Thurs','Fri','Sat','Sun'))
pickup_sum_plot<-ggplot(pickup_sum_data, aes(x = pickup_weekday , y = pickup_hour)) +
  geom_tile(aes(fill=total), colour = "white") +
  scale_fill_gradient(name = "# of pickups", low = "wheat2", high = "violetred4") +
  scale_y_continuous(breaks = unique(pickup_sum_data$pickup_hour)) +
  labs( x = "Day of week", y = "Hour") +
  theme(axis.ticks = element_blank())

######################## Hourly rides #################################
group_data<-subset_data %>% 
  group_by(pickup_hour) %>%
  summarise(total = n())


hourly_plot<-ggplot(group_data, aes(x=pickup_hour, y=total))+geom_area(fill="salmon4", alpha=0.5)+
  labs(y='Total number of rides')

grid.arrange(hourly_plot, pickup_sum_plot, ncol = 2)


##########  Calendar Heatmap   ##############
df<-subset_data %>% select(pickup_day, pickup_hour, pickup_month)%>%
  group_by(pickup_day, pickup_hour, pickup_month) %>%
  summarise(total=n()) 


library(plyr) # Use plyr to map month column values to letters

df$pickup_month2 <- mapvalues(df$pickup_month,
                     from = c(1,2,3,4,5,6),
                     to = c("Jan", "Feb", "March", "April", "May", 'June'))

p <-ggplot(df,aes(x=pickup_day,y=pickup_hour, fill=total))+
  geom_tile(color="white", size=0.1) + coord_equal()+
  scale_fill_viridis(name="Number of rides", option="D")
#put facet plot in order
p <-p + facet_grid(.~factor(pickup_month2, levels=c("Jan", "Feb", "March", "April", "May", 'June')))
p <-p + scale_y_continuous(trans = "reverse", breaks = unique(df$pickup_hour))
p <-p + labs( x="Pickup Day", y="Pickup Hour")
p
