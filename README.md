# HGT-To-Normal

Sample CUDA code to create a normal map from a high resolution HGT file. The normal map can be used to help create relief maps (bottom image).
The code expects a high resolution HGT file ( 1 arc-second ). These files are 3601 by 3601 and contain the height in meters stored as a 16 bit value.
The output file is a 3600 by 3600 Bitmap. For more about HGT files see my other [project](https://github.com/nodecomplete/NZDEM-HGT-30).

The images below show a normal map and relief map (top and bottom images respectively) of the S40E175.hgt file (Tongariro National Park, New Zealand).

![alt text](https://github.com/nodecomplete/HGTToNormal/blob/master/NormalMapCUDA.jpg)
![alt text](https://github.com/nodecomplete/HGT-To-Normal/blob/master/ReliefMap.jpg)
