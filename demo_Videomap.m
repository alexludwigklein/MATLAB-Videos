%% Create some example data
img = im2uint16(reshape(1:1e5,200,500)/1e5);
imwrite(img,'test.tif');
for i = 1:10
    imwrite(img(:,end:-1:1),'test.tif', 'WriteMode', 'append');
    imwrite(img,            'test.tif', 'WriteMode', 'append');
end

%% Example 1
% Load TIF file into memory
obj = Videomap('test.tif');
% * If a file test.mat is available it will be preferred.
% * Memory mapping is disabled by default, switch it on with
obj.memmap = true;
% Show first image
imshow(obj(:,:,1,1));
% add data to file
obj.write2MAT('message','Hello World!');
% store also image data to file to read next time (othersie the cdata would be missing next time)
obj.store;

%% Example 2
% convert TIF file to matfile, overwrite existing MAT file and enable memmap next time it is loaded
Videomap.convert2DAT('test.tif','forceNew',true,'memmap',true)
% load data, test.mat should be found and loaded
obj = Videomap('test.tif');
% Show first image
imshow(obj(:,:,1,1));
% store also image data to file to read next time
obj.store;

%% Example 3
% create MAT file and apply a resize by a factor of 2
Videomap.convert2DAT('test.tif','memmap',false,'transform',{@(x) imresize(x,2)})
obj = Videomap('test.dat');
% apply another transformation for the MAT file and read only frame 1 3 and 5
Videomap.convert2DAT('test.dat','memmap',false,'transform',{@(x) imresize(x,0.5)},'idxFrames',[1 3 5])
obj = Videomap('test.mat');

%% Example 4
% use crop and resize directly
obj = Videomap('test.dat');
obj.resize(2);
