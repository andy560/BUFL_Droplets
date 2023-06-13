# BUFL_Droplets
Repository includes scripts used to analyze droplet data in MATLAB. See code comments for explanation.

# FL_dropletdata.m:
Takes frame by frame data from lateral view videos of droplets:
- 3 measures of vertical impact velocity using position of droplet 2 frames apart
- highest droplet roundness
- radius at maximum roundness

# FL_dropletdata_auto.m:
Similar purpose to FL_dropletdata.m, but automated for individual files. 
- 3 measures of vertical impact velocity using position of droplet 2 frames apart
- highest droplet roundness
- radius at maximum roundness

# maxdiameter.m:
reads maximum diameter of a droplet after impact
- maximum diameter
- impact frame
- maximum diameter frame

# diametergraph_batch.m:
Similar to maxdiameter.m, but can process multiple files in one run. 
Then saves diameter data as a function of time, starting after impact.
Saves .mat file for each file processed, with diameter graph data, and 
creates excel file listing all files processed. 
