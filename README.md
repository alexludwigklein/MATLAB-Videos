# MATLAB-Videos
Collection of classes, functions and scripts to analyse movies in MATLAB including memory mapping for huge files

## Installation
Add the parent directory that holds all @-folders to you local MATLAB path. This task can easily be done
	with MATLAB's addpath and genpath functions. The code requires the following toolboxes to be installed 
	(depending on the features used in the GUI):

* Optimization Toolbox
* Signal Processing Toolbox
* Image Processing Toolbox
* Statistics and Machine Learning Toolbox
* Computer Vision System Toolbox
	
Furthermore, the code makes use of some additional third party tools that can be found on the [file exchange](https://nl.mathworks.com/matlabcentral/fileexchange) or on [GitHub](https://github.com):

* [TIFFSTack](https://nl.mathworks.com/matlabcentral/fileexchange/32025-dylanmuir-tiffstack) for reading and mapping TIF files to memory
* [DataHash](https://nl.mathworks.com/matlabcentral/fileexchange/31272-datahash) for creating hash values
* [GetFullPath](https://nl.mathworks.com/matlabcentral/fileexchange/28249-getfullpath) that should be available as `fullpath` on your MATLAB path to determine the full path of a file
* [saveastiff](https://nl.mathworks.com/matlabcentral/fileexchange/35684-save-and-load-a-multiframe-tiff-image) for saving TIF files
* [export_fig](https://nl.mathworks.com/matlabcentral/fileexchange/23629-export-fig) for exporting MATLAB figures in high resolution (used when exporting videos as shown on screen)

## Usage
The class to start with as a user is the `Video` class by opening a video. The actual data handling is performed
by the class `Videomap` and supports MJ2, AVI, MP4, multistack TIF or its own binary format DAT (an uncompressed
binary format to efficiently memory map huge data files). To view one or multiple movies, manually track objects, export the movies in a spatially referenced view (export to movies with transparent background is supported with 
the help of FFMPEG) and much more, use the `Videoplayer` class. Here is a very short example:

```
% open two videos and set a pixel resolution
vid    		  = Video({'demo_traffic-rgb.mj2','demo_traffic-gray.mj2'});
vid(1).pixres = 0.1;
vid(2).pixres = vid(1).pixres;
% and show them in the Videoplayer
player  = vid.play;
```