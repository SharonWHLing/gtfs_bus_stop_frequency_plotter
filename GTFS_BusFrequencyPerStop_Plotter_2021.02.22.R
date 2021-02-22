#install packages
install.packages("beepr")
install.packages("tidytransit")
install.packages("hms")
install.packages("tidyverse")
install.packages("ggpubr")
install.packages("gridExtra")
install.packages("openxlsx")

#load packages
library("beepr")
library("tidytransit")
library("hms")
library("tidyverse")
library("ggpubr")
library("gridExtra")
library("openxlsx")

rm(list = ls()) #do this to clear the global environment if necessary
gc() #frees up memory
dev.off() #removes plots from Plot window

#set working directory etc
getwd() # first see R's default location
setwd("C:/Users/XXXXX/Desktop") #change directory address
getwd() # check that working directory is changed

######
######
######

##################### SET UP BASE TABLES #################################################################

#reference: http://tidytransit.r-transit.org/articles/timetable.html

path_local_gtfs <- "R_GTFS_timetabling-MARTA-2020.03.26-sample.zip" #source file name

gtfs <- read_gtfs(path_local_gtfs) %>%
  set_hms_times() %>% 
  set_date_service_table() #extract service table 

gtfs_date_service <- gtfs$.$date_service_table #from here we see that 5 = Weekday, 3 = Saturday, 4 = Sunday
gtfs_routes <- gtfs$routes #route information (including route IDs and route short names)
gtfs_stops <- gtfs$stops #stop information (including stop IDs and names)
gtfs_stop_times <- gtfs$stop_times #stop time information

# create new table: join stop_times with stops, based on stop_id, to get stop name information
gtfs_edited_stop_times <- left_join(gtfs$stop_times, gtfs$stops, by="stop_id") 
  
# revise new table: join stop_times with trips, based on trip_id, to get route_id and shape_id information
gtfs_edited_stop_times <- left_join(gtfs_edited_stop_times, gtfs$trips, by= "trip_id")

# create table of route IDs only (want to get unique route ids)
# note: don't take this from gtfs_edited_stop_times because #11843 (Atlanta Streetcar)'s entries are missing 
gtfs_route_id_only <- gtfs_routes[,c("route_id")] %>% unique()

# create table of unique shape IDs only (want to get unique shape ids)
gtfs_shape_id_only <- gtfs_edited_stop_times[,c("route_id", "shape_id", "direction_id")] %>% unique()

# create table of all routes inclusive of all shape IDs 
gtfs_routes_and_shape_id <- left_join(gtfs_shape_id_only, gtfs_routes, by="route_id")

# make a blank version of the latter, prep it to use for populating later   
MARTA_summary_table <- gtfs_routes_and_shape_id[0,]

list <- c("(-5,0)", "(0,5)", "(5,10)", "(10,15)", "(15,20)", "(20,25)", "(25,30)", "(30,35)", "(35,40)",
             "(40,45)", "(45,50)", "(50,55)", "(55,60)", "(60,65)", "(65,70)", "(70,75)", "(75,80)",
             "(80,85)", "(85,90)", "(90,95)", "(95,100)", "(100,105)", "(105,110)", "(110,115)", "(115,120)")   

MARTA_summary_table[list] <- NA
MARTA_summary_table <- MARTA_summary_table %>%mutate_if(is.logical, as.character)

# print tables to Excel as needed
write.xlsx(gtfs_routes_and_shape_id, "gtfs_routes_and_shape_id.xlsx", )

######
######
######

###################### 1) CALCULATE HEADWAYS FOR EACH ROUTE (BY STOP, BASED ON DIRECTION & SEQUENCE) & PLOT TO TIME GRAPHS BY STOP #########

# loop for each route, sort table contents, calculate headways according to per direction and per stop, then re-sort by stop sequence

for (r in gtfs_route_id_only$route_id){
  
  r_short <- gtfs$routes$route_short_name[gtfs_route_id_only$route_id == r] %>% unique() #extract route short name
  
  r_file_name <- paste("Timetable_MARTA_Route_", r_short, "_Code_", r, ".xlsx", sep="")
  print(paste("Processing", r_file_name, "...")) #prints route (short name) that is being worked on
  
  r_table <- gtfs_edited_stop_times  %>% 
    filter(route_id == r) %>% # filter by route ID 
    filter(service_id == 5) %>% # filter by service_id = weekday only
    
    # this lets you check headways between 1 bus and the next, at the same bus stop
    group_by(direction_id, stop_id) %>% # group by selected characteristics, in order of importance: same direction, then in order of stops 
    arrange(departure_time, .by_group = TRUE) %>% # re-arrange by departure time
    mutate(headways_1 = departure_time_hms - lag(departure_time_hms, default = first(departure_time_hms))) %>% # calculate headways in seconds
    mutate(headways_2 = as_hms(headways_1)) %>% # convert seconds to hh:mm:ss format for easy reading
    mutate(headways_3 = as.numeric(headways_1/60)) %>% # convert seconds to minutes for easy reading (also easier to see in plot)
    ungroup(stop_id) %>%
    arrange(stop_sequence, .by_group = TRUE) # re-arrange by stop sequence 
  
  path_output <- paste(getwd(), "/", "MARTA_Route_", r_short, "_Code_", r, "/", sep="")
  dir.create(path_output)
    
  r_file_name <- paste(path_output, r_file_name, sep="")
  r_sheet_name <- paste(r_short,"_all",sep="")
  write.xlsx(r_table, r_file_name, sheetName = r_sheet_name)
 
  # find rush hour period in Atlanta: https://www.tomtom.com/en_gb/traffic-index/atlanta-traffic/
  r_table_AM <- r_table %>% filter(departure_time < ("10:00:00"))
  
  # create table of unique shape IDs for a particular route only (for both directions)
  r_table_AM_dir_shapeID_only <- r_table_AM[,c("shape_id", "direction_id")] %>% ungroup("direction_id") %>% unique() #use for alternative v2 

  # create table of unique stop sequence IDs for a particular route only, based on direction of route 
  r_table_AM_dir0_sequence_only <- r_table_AM[,c("stop_sequence", "stop_id", "direction_id")] %>% ungroup("direction_id") %>%
    filter(direction_id %in% c("0")) %>% select(-direction_id) %>% unique() #based on direction 0, use for alternative v2 
  
  r_table_AM_dir1_sequence_only <- r_table_AM[,c("stop_sequence", "stop_id", "direction_id")] %>% ungroup("direction_id") %>%
    filter(direction_id %in% c("1")) %>% select(-direction_id) %>% unique() #based on direction 1, use for alternative v2    

  print("Processed!") 
  beep(sound = 1, expr = NULL) 
  Sys.sleep(2)  
  
  ##### V2: USE IF ORDERING BY ROUTE ID - DIRECTION ID - SHAPE ID - STOP SEQUENCE - STOP ID
  
  for (shape in r_table_AM_dir_shapeID_only$shape_id){
  
    r_table_AM_shape_stops <- r_table_AM %>% filter(shape_id %in% c(shape))
    r_table_AM_shape_stops_sequence_only <- r_table_AM_shape_stops[,c("stop_sequence")] %>% unique()
    
    for (seq in r_table_AM_shape_stops_sequence_only$stop_sequence){
    
      s <- r_table_AM_shape_stops$stop_id[r_table_AM_shape_stops$stop_sequence == seq] %>% unique() # extract stop ID based on direction 0 & sequence ID
      d <- r_table_AM_shape_stops$direction_id[r_table_AM_shape_stops$stop_sequence == seq] %>% unique()  # extract stop ID based on direction 0 & sequence ID

      # loop for each stop, print out graph & table of headways for the direction's sequence 

      seq_file_name <- (paste("Route_", r_short, "_Code_", r, "_AM_Direction_", d, "_Shape_", shape, "_Sequence_", seq, "_Stop_", s, ".jpg",sep=""))
      print(paste("Processing", seq_file_name, sep=" ")) #prints sequence ID that is being worked on  
    
      # make plots & tables for each sequence ID
      plot_AM_sequence <- r_table_AM_shape_stops %>%
        filter(stop_sequence == seq) %>%
        ggplot(aes(x = departure_time_hms, y = headways_3, colour = stop_id)) + geom_line() + geom_point() + theme(aspect.ratio=0.55) +
        guides(color = guide_legend(ncol = 2)) +
        geom_hline(yintercept=20, linetype="dashed", color = "green", size=0.75) +
        theme(axis.title.x=element_blank(), axis.title=element_text(size = 9)) + ylab("minutes") +
        scale_y_continuous(breaks=seq(0,120,10)) + 
        labs(caption=seq_file_name) + theme(plot.caption = element_text(hjust=0.5, size = 9, face = "bold"))

      table_AM_sequence <- r_table_AM_shape_stops %>% #create a table, place it under the requisite graph
        ungroup("direction_id") %>% #do this to remove the direction ID from appearing in the table
        filter(stop_sequence == seq) %>%
        select("departure_time_hms", "headways_3", "direction_id", "shape_id", "stop_sequence", "stop_id")
      
      table_AM_dummy <- data.frame(departure_time_hms=(character()), headways_3=character(), direction_id = character(), shape_id = character(), stop_sequence = character(), stop_id = character(), stringsAsFactors=FALSE) %>% 
        add_row(departure_time_hms = "N/A", headways_3 = "N/A", direction_id = "N/A", shape_id = "N/A", stop_sequence = "N/A", stop_id = "N/A") #create a dummy table 
      
      # create plot tables based on content of tables as per above code (if blank, no table generated)
      if (!dim(table_AM_sequence)[1] == 0) 
      {plot_table0 <- ggtexttable(table_AM_sequence, theme = ttheme(base_style = "default", base_size = 7))} #use if table has content
      else {plot_table0 <- ggtexttable(table_AM_dummy, theme = ttheme(base_style = "default", base_size = 7))} #use if table is blank, else error
    
      ggarrange(plot_AM_sequence + rremove("legend"), plot_table0, ncol = 1, nrow = 2)
      
      seq_file_name <- paste(path_output, seq_file_name, sep="")
      
      ggsave(seq_file_name)
      
      print("Processed!")  
      beep(sound = 2, expr = NULL) 
      Sys.sleep(2)
      
    }
  }

print(paste("Route", r_short, "files all processed!")) 
beep(sound = 3, expr = NULL) 
Sys.sleep(3)
} 

Sys.sleep(3)
print("All done!")  
beep(sound = 8, expr = NULL)

######
######
######

###################### 2) CALCULATE HEADWAYS FOR EACH ROUTE (BY STOP, BASED ON DIRECTION & SEQUENCE) & PLOT FREQUENCY DISTRIBUTION PER SHAPE ID

for (r in gtfs_route_id_only$route_id){
  
  r_short <- gtfs$routes$route_short_name[gtfs_route_id_only$route_id == r] %>% unique() #extract route short name
  
  r_file_name <- paste("Timetable_MARTA_Route_", r_short, "_Code_", r, ".xlsx", sep="")
  print(paste("Processing", r_file_name, "...")) #prints route (short name) that is being worked on
  
  r_table <- gtfs_edited_stop_times  %>% 
    filter(route_id == r) %>% # filter by route ID 
    filter(service_id == 5) %>% # filter by service_id = weekday only
    
    # this lets you check headways between 1 bus and the next, at the same bus stop
    group_by(direction_id, stop_id) %>% # group by selected characteristics, in order of importance: same direction, then in order of stops 
    arrange(departure_time, .by_group = TRUE) %>% # re-arrange by departure time
    mutate(headways_1 = departure_time_hms - lag(departure_time_hms, default = first(departure_time_hms))) %>% # calculate headways in seconds
    mutate(headways_2 = as_hms(headways_1)) %>% # convert seconds to hh:mm:ss format for easy reading
    mutate(headways_3 = as.numeric(headways_1/60)) %>% # convert seconds to minutes for easy reading (also easier to see in plot)
    ungroup(stop_id) %>%
    arrange(stop_sequence, .by_group = TRUE) # re-arrange by stop sequence 
  
  path_output <- paste(getwd(), "/", "MARTA_Route_", r_short, "_Code_", r, "/", sep="")
  dir.create(path_output)

  # find rush hour period in Atlanta: https://www.tomtom.com/en_gb/traffic-index/atlanta-traffic/
  # create tables for rush hour departure times & other times of the day 
  r_table_AM <- r_table %>% filter(departure_time < ("10:00:00"))

  # create table of unique shape IDs for a particular route only (for both directions)
  r_table_AM_dir_shapeID_only <- r_table_AM[,c("shape_id", "direction_id")] %>% ungroup("direction_id") %>% unique() #use for alternative v2 
  
  print("Processed!") 
  beep(sound = 1, expr = NULL) 
  Sys.sleep(2) 

  ##### PRINT HISTOGRAMS & FREQUENCY TABLE ENTRIES FOR SHAPE IDS
  
  for (shape in r_table_AM_dir_shapeID_only$shape_id){
    
    shape_headway_freq_file_name <- paste("Route_", r_short, "_Code_", r, "_Shape_", shape, "_Headway_Histogram", ".jpg",sep="")
    print(paste("Processing", shape_headway_freq_file_name, "...")) #prints route (short name) that is being worked on
    
    # make plot of frequency distribution for headways based on shape ID 
    plot_shape_headwayfreq <- r_table_AM[,c("shape_id", "headways_3")] %>% filter(shape_id %in% c(shape)) %>% 
    ggplot(aes(x = headways_3)) + geom_histogram(breaks=seq(-5, 120, by=5), col="red", fill="black", alpha = .2) +
      geom_vline(aes(xintercept=20), color = "green", size = 1.5) + labs(x="headways", y="count", size = 9) + 
      scale_x_continuous(breaks=seq(0,120,5)) + 
      labs(caption=shape_headway_freq_file_name) + theme(plot.caption = element_text(hjust=0.5, size = 9, face = "bold"))
    
      ggarrange(plot_shape_headwayfreq + rremove("legend"))
      
      shape_headway_freq_file_name <- paste(path_output, shape_headway_freq_file_name, sep="")
      
      ggsave(shape_headway_freq_file_name)
    
    print("Processed!")   
    
    # make table of frequency distribution for headways based on shape ID 
    
    r_table_AM_shape_headwayfreq <- r_table_AM[,c("shape_id", "headways_3")] %>% 
      filter(shape_id %in% c(shape)) %>% select(-shape_id) 
    
    breaks = seq(-5, 120, by=5)
    
    r_table_AM_shape_headwayfreq <- cut(r_table_AM_shape_headwayfreq$headways_3, breaks) %>% 
      table() %>% cbind() %>% t()
    rownames(r_table_AM_shape_headwayfreq)[1] <- 'Frequency' 
    colnames(r_table_AM_shape_headwayfreq) <- gsub("]", ")", colnames(r_table_AM_shape_headwayfreq))

    # merge info from r_table_AM_shape_headwayfreq and gtfs_routes_and_shape_id, creating new row of info
    r_table_AM_shape_headwayfreq <- cbind(shape_id = shape, r_table_AM_shape_headwayfreq)
    test_join <- merge(x = gtfs_routes_and_shape_id, y = r_table_AM_shape_headwayfreq, by.x="shape_id", by.y="shape_id")

    # fetch table, append new columns based on histogram categories
    MARTA_summary_table <- MARTA_summary_table %>% add_row(test_join)
  
    print(paste("Added new row", shape, "to MARTA_summary_table_headways_AM.xlsx!", sep = " "))
    beep(sound = 5, expr = NULL) 
    Sys.sleep(2)
  } 
  
}

setwd("C:/Users/XXXXX/Desktop/")
write.xlsx(MARTA_summary_table, "MARTA_summary_table_headways_AM.xlsx", )

Sys.sleep(3)
print("All done!")  
beep(sound = 8, expr = NULL)
