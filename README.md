# gtfs_bus_stop_frequency_plotter

Demo R Script to extract GTFS data and plot peak-hour bus stop frequencies to JPG graphs, histograms, and Excel tables.

This is a demo script to identify "high-frequency" bus routes, i.e. with headways of <= 20 minutes. Beta/personal use so expect some bugs.

----------------------------------------------------------------

REQUIRES: A GTFS zip file; this script was made with MARTA's in mind (https://www.itsmarta.com/app-developer-resources.aspx)

HOW TO USE: Run the script (in multiple parts) in RStudio or equivalent. 

----------------------------------------------------------------

NOTES: 

1) Install the packages and set up your base tables as per the first part of the R script.

2) Choose which section you want to run:
   - Section 1: CALCULATE HEADWAYS FOR EACH ROUTE (BY STOP, BASED ON DIRECTION & SEQUENCE) & PLOT TO TIME GRAPHS BY STOP; or 
   - Section 2: CALCULATE HEADWAYS FOR EACH ROUTE (BY STOP, BASED ON DIRECTION & SEQUENCE) & PLOT FREQUENCY DISTRIBUTION PER SHAPE ID.
   
   * Running Section 1 will produce individual folders for each bus route, which will contain: 
     - an Excel table of the route's headways at each bus stop, based on route direction and sequence of bus stops which the buses travel to; and
     - JPEG graphs for each bus stop, plotting the frequency of bus arrivals for a route for the time range (currently 6:00am-10:00am). 
       
   * Running Section 2 will produce:
     - a histogram for each bus route which shows the frequency of headways for the route, broken into 5 minute intervals; and
     - an Excel summary table showing the frequency distribution of headways for all routes recorded. 
     
   Sample results attached below and uploaded to the repoistory.
     
