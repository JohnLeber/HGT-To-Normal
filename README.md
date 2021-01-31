# HGT-To-Normal

Sample CUDA code to create a normal map from a high resolution HGT file. The normal map can be used to help create relief maps (bottom image).
The code expects a high resolution HGT file ( 1 arc-second ). These files are 3601 by 3601 and contain the height in meters stored as a 16 bit value.
The output file is a 3600 by 3600 bitmap file containing the normals in tangent space. For more information about HGT files see my other [project](https://github.com/nodecomplete/NZDEM-HGT-30).

The code should be reasonably easy to adapt to height maps and depth maps of different sizes.

The images below show a normal map and relief map (top and bottom images respectively) of the [S44E170.hgt](https://github.com/nodecomplete/NZDEM-HGT-30/blob/master/HGT/S44E170.zip) file (West Coast/Southern Alps of New Zealand).

![alt text](https://github.com/nodecomplete/HGTToNormal/blob/master/NormalMapCUDA2.jpg)
![alt text](https://github.com/nodecomplete/HGT-To-Normal/blob/master/ReliefMap2.jpg)

More samples, in this case Tongariro National Park [S40E175.hgt](https://github.com/nodecomplete/NZDEM-HGT-30/blob/master/HGT/S40E175.zip)

![alt text](https://github.com/nodecomplete/HGTToNormal/blob/master/NormalMapCUDA.jpg)
![alt text](https://github.com/nodecomplete/HGT-To-Normal/blob/master/ReliefMap.jpg)


