%% Create some example data
img = im2uint16(reshape(1:1e5,200,500)/1e5);
imwrite(img,'test1.tif');
for i = 1:10
    imwrite(img(:,end:-1:1),'test1.tif', 'WriteMode', 'append');
    imwrite(img,            'test1.tif', 'WriteMode', 'append');
end
img = im2uint8(rand(400,800));
imwrite(img,'test2.tif');
for i = 1:10
    imwrite(img(:,end:-1:1),'test2.tif', 'WriteMode', 'append');
    imwrite(img,            'test2.tif', 'WriteMode', 'append');
end

%% Example 1
% Load TIF file into memory with memory mapping and play it
vid    = Video({'test1.tif','test2.tif'});
player = vid.play;

%% Example 2
% Load mj2 file
vid           = Video({'demo_traffic-rgb.mj2','demo_traffic-gray.mj2'});
vid(1).pixres = 0.1;
vid(2).pixres = vid(1).pixres;
player        = vid.play;