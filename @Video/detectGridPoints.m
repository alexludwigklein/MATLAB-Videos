function [imagePoints, boardSize, imageIdx, userCanceled, boardRot] = detectGridPoints(I,varargin)
% detectGridPoints Detects a square grid pattern in images made up of lines or single dots
%   Similar to detectCheckerboardPoints but for a grid instead a checkerboard. Note: output
%   arguments match (almost) detectCheckerboardPoints, except for some additions, functions does not
%   support stereo cameras as does detectCheckerboardPoints

%
% check input, use input parser to process options
opt               = inputParser;
opt.StructExpand  = true;
opt.KeepUnmatched = false;
% rectangle to crop images
opt.addParameter('rect', true, ...
    @(x) isempty(x) || (islogical(x) && isscalar(x)) || (isnumeric(x) && numel(x) ==4 && all(x>0)));
% structuring element for background subtraction
opt.addParameter('strel', strel('disk',20), ...
    @(x) isempty(x) || isa(x,'strel'));
% threshold for BW
opt.addParameter('thres', 0.75, ...
    @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
% true/false whether to plot result
opt.addParameter('plot', false, ...
    @(x) islogical(x) && isscalar(x));
% type of grid to detect, e.g a grid made of squares/lines or single dots
opt.addParameter('type', 'squares', ...
    @(x) ischar(x) && ismember(x,{'squares' 'dots'}));
% rotation of the grid in degrees, leave empty for automatic detection
opt.addParameter('rot', [], ...
    @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
opt.parse(varargin{:});
opt = opt.Results;
%
% single camera
[imagePoints, boardSize, imageIdx, userCanceled, boardRot] = detectMono(I, opt);
end

function [points, boardSize, rot] = detectGridInOneImage(img, opt)
%detectGridInOneImage Detects grid in a single image

% call the workhorse function
switch opt.type
    case 'squares'
        detectSquares;
    case 'dots'
        detectDots;
end
% check results
if isempty(rect),
    points = loc;
else
    points = loc + repmat(rect(1:2)-[1 1],size(loc,1),1);
end
boardSize = round(sqrt(size(loc,1)));
if size(loc,1) ~= boardSize^2
    warning(sprintf('%s:Input',mfilename),'Grid does not seem to be a square grid');
end
%
% prepare output
boardSize = [boardSize boardSize]; % detectCheckerboardPoints would return boardSize = 1+ [boardSize boardSize];
rot       = rot/180*pi;
%
% plot result
if opt.plot
    f = figure('Name',sprintf('Result of grid detection, %d x%d',boardSize(1),boardSize(2)));
    imshow(bak,'InitialMagnification','fit');
    hold('on'); plot(points(:,1),points(:,2),'or');
    uiwait(f);
end

    function detectDots
        bak = img;
        % create gray image of single precision
        if size(img, 3) > 1
            img = rgb2gray(img);
        end
        img = im2single(img);
        %
        % ask for rectangle
        rect = opt.rect;
        if islogical(rect) && rect
            f = figure('Name','Select complete grid of dots');
            h = imshow(img,'InitialMagnification','fit');
            [~,rect] = imcrop(h);
            delete(f);
        elseif islogical(rect) && ~rect
            rect = [];
        end
        %
        % crop and normalize image
        if ~isempty(rect)
            rect = round(rect);
            img  = imcrop(img,rect);
        end
        if ~isempty(opt.strel)
            bg  = imopen(imcomplement(img),opt.strel);
            img = imdivide(img,imcomplement(bg));
        end
        img = imadjust(img);
        %
        % find each single square of the grid as BW image
        if islogical(bak)
            % in case the user gave a logical input: assume it only holds the correct dots, do not
            % perform any filtering
            if ~isempty(rect)
                BW = imcrop(bak,rect);
            else
                BW = bak;
            end
            CC         = bwconncomp(BW,4);
            statSquare = regionprops(CC,'Area','PixelIdxList','Centroid','BoundingBox');
        else
            % create a logical image and filter what should be dots by mean area, etc.
            if isempty(opt.thres)
                BW = ~im2bw(img,graythresh(img));
            else
                BW = ~im2bw(img,opt.thres);
            end
            BW         = imclearborder(BW,4);
            BW         = bwareaopen(BW,round(numel(BW)/1e4));
            BW         = bwmorph(BW,'spur',Inf);
            CC         = bwconncomp(BW,4);
            statSquare = regionprops(CC,'Area','PixelIdxList','Centroid','BoundingBox');
            bbox       = cat(1,statSquare.BoundingBox);
            siz        = prod(bbox(:,3:4),2);
            statSquare = statSquare(siz < 0.01 * numel(BW));
            bbox       = cat(1,statSquare.BoundingBox);
            aratio     = bbox(:,3)./bbox(:,4);
            area       = cat(1,statSquare.Area);
            statSquare = statSquare(area > 0.5*mean(area) & aratio<1.5 & aratio > 0.6);
            nSquare    = numel(statSquare);
            if nSquare > round(sqrt(nSquare))^2
                % remove squares most off from mean area
                area       = cat(1,statSquare.Area);
                [~, idx]   = sort(abs(area-mean(area)));
                statSquare = statSquare(idx(1:round(sqrt(nSquare))^2));
            end
        end
        area  = cat(1,statSquare.Area);        % area of grid dots
        posCM = cat(1,statSquare.Centroid);    % centroid position of dots
        len   = sqrt(mean(area));              % edge length of singel square
        BW    = false(size(BW));               % image with all squares
        for i = 1:numel(statSquare)
            BW(statSquare(i).PixelIdxList) = true;
        end
        %
        % determine rotation of grid
        if isempty(opt.rot)
            BW2          = bwperim(bwmorph(bwmorph(BW,'dilate',len),'erode',len));
            statSquare2  = regionprops(BW2,'Area','Extrema');
            area2        = cat(1,statSquare2.Area);
            [~, idx]     = sort(area2);
            statSquare2  = statSquare2(idx(end));
            if numel(statSquare2) > 1
                points    = [];
                boardSize = [];
                rot       = [];
                return;
            end
            posEdge      = statSquare2.Extrema(:,:);
            rot          = NaN(size(posEdge,1),1);
            for i = 1:size(posEdge,1)
                dist     = sqrt(sum((posEdge - repmat(posEdge(i,:),size(posEdge,1),1)).^2,2));
                [~,idx]  = max(dist);
                tmp      = ((posEdge(i,:)-posEdge(idx,:)));
                rot(i)   = atand(tmp(2)/tmp(1));
            end
            rot = 45-mean(rot(rot>mean(rot)));
        else
            rot = opt.rot;
        end
        loc = posCM;
    end

    function detectSquares
        bak = img;
        % create gray image of single precision
        if size(img, 3) > 1
            img = rgb2gray(img);
        end
        img = im2single(img);
        %
        % ask for rectangle
        rect = opt.rect;
        if islogical(rect) && rect
            f = figure('Name','Select complete square grid');
            h = imshow(img,'InitialMagnification','fit');
            [~,rect] = imcrop(h);
            delete(f);
        elseif islogical(rect) && ~rect
            rect = [];
        end
        %
        %  crop and normalize image
        if ~isempty(rect)
            rect = round(rect);
            img  = imcrop(img,rect);
        end
        if ~isempty(opt.strel)
            bg  = imopen(imcomplement(img),opt.strel);
            img = imdivide(img,imcomplement(bg));
        end
        img = imadjust(img);
        %
        % find each single square of the grid as BW image
        if isempty(opt.thres)
            BW = im2bw(img,graythresh(img));
        else
            BW = im2bw(img,opt.thres);
        end
        BW         = imclearborder(BW,4);
        BW         = bwareaopen(BW,round(numel(BW)/1e4));
        BW         = bwmorph(BW,'spur',Inf);
        CC         = bwconncomp(BW,4);
        statSquare = regionprops(CC,'Area','PixelIdxList','Centroid','BoundingBox');
        bbox       = cat(1,statSquare.BoundingBox);
        siz        = prod(bbox(:,3:4),2);
        statSquare = statSquare(siz < 0.01 * numel(BW));
        bbox       = cat(1,statSquare.BoundingBox);
        aratio     = bbox(:,3)./bbox(:,4);
        area       = cat(1,statSquare.Area);
        statSquare = statSquare(area > 0.5*mean(area) & aratio<1.5 & aratio > 0.6);
        nSquare    = numel(statSquare);
        if nSquare > round(sqrt(nSquare))^2
            % remove squares most off from mean area
            area       = cat(1,statSquare.Area);
            [~, idx]   = sort(abs(area-mean(area)));
            statSquare = statSquare(idx(1:round(sqrt(nSquare))^2));
        end
        area       = cat(1,statSquare.Area);        % area of grid squares
        posCM      = cat(1,statSquare.Centroid);    % centroid position of grid squares
        len        = sqrt(mean(area));              % edge length of singel square
        BW         = false(size(BW));               % image with all squares
        for i = 1:numel(statSquare)
            BW(statSquare(i).PixelIdxList) = true;
        end
        %
        % determine rotation of grid
        if isempty(opt.rot)
            BW2          = bwperim(bwmorph(bwmorph(BW,'dilate',len/2),'erode',len/2));
            statSquare2  = regionprops(BW2,'Area','Extrema');
            area2        = cat(1,statSquare2.Area);
            [~, idx]     = sort(area2);
            statSquare2  = statSquare2(idx(end));
            if numel(statSquare2) > 1
                points    = [];
                boardSize = [];
                rot       = [];
                return;
            end
            posEdge      = statSquare2.Extrema(:,:);
            rot          = NaN(size(posEdge,1),1);
            for i = 1:size(posEdge,1)
                dist     = sqrt(sum((posEdge - repmat(posEdge(i,:),size(posEdge,1),1)).^2,2));
                [~,idx]  = max(dist);
                tmp      = ((posEdge(i,:)-posEdge(idx,:)));
                rot(i)   = atand(tmp(2)/tmp(1));
            end
            rot = 45-mean(rot(rot>mean(rot)));
        else
            rot = opt.rot;
        end
        %
        % move centroid position to lower right edge
        posCross = posCM+repmat((len/sqrt(2)) * [sind(45+rot) cosd(45+rot)],size(posCM,1),1);% approximated position of lower left corner
        
        %
        % create template for a crossing point of the grid
        len1  = round(2*len/4) * 2 + 1;
        len2  = 1; %#ok<NASGU>
        len3  = round(len/4);
        % Option 1: a simple cross as filter
        % cross = zeros([len1,len1],'single');
        % cross((len1+1)/2+(-len2:len2),:) = repmat([0.5; 1; 0.5],1,size(cross,2));
        % cross(:,(len1+1)/2+(-len2:len2)) = repmat([0.5 1 0.5],size(cross,1),1);
        % cross((len1+1)/2+(-len2:len2),(len1+1)/2+(-len2:len2)) = 1;
        % cross = imrotate(cross,rot);
        % cross = cross(round((size(cross,1)+1)/2) + (-len3:len3),round((size(cross,2)+1)/2) + (-len3:len3));
        % % determine maxima in cross and its deviation from the expected centroid
        % crossCM = [(1+size(cross,2))/2 (1+size(cross,1))/2];
        % crossCM = crossCM - Video.pixelLocalSubMaxima(cross,crossCM,4);
        % Option 2:
        x         = (1:len1) - (1+len1)/2;
        [xg, yg]  = meshgrid(x,x);
        rg        = hypot(xg,yg);
        pg        = atan2(yg,xg) + (45+rot)/180*pi;
        pg        = sin(pg*2).^4;
        pg(rg<=2) = 1;
        rg        = rg./max(rg(:));
        rg        = 1-rg;
        cross     = rg.^2.*pg.^2-0.0;
        crossCM   = [0 0];
        %
        % compute cross correlation with template and find location of local maxima
        img    = imcomplement(img);
        % Option 1:
        % img2   = normxcorr2(cross,img);
        % img2   = img2(round((size(img2,1)+1)/2) + (-round((size(img,1)-1)/2):round((size(img,1)-1)/2)),...
        %     round((size(img2,2)+1)/2) + (-round((size(img,2)-1)/2):round((size(img,2)-1)/2)));
        % Option 2:
        img2 = imfilter(img,cross);
        loc  = Video.pixelLocalMaxima(img2, round(posCross),round(len3/2));
        % show(img);hold;plot(posCross(:,1),posCross(:,2),'or');plot(loc(:,1),loc(:,2),'xr')
        %
        % determine sub pixel accurancy
        loc = Video.pixelLocalSubMaxima(img2, loc, 4);
        loc = loc - repmat(crossCM,size(loc,1),1);
    end
end

function checkFileNames(fileNames)
validateattributes(fileNames, {'cell'}, {'nonempty', 'vector'}, mfilename, ...
    'imageFileNames');
for i = 1:numel(fileNames)
    checkFileName(fileNames{i});
end
end

function checkFileName(fileName)
validateattributes(fileName, {'char'}, {'nonempty'}, mfilename, ...
    'elements of imageFileNames');
try
    imfinfo(fileName);
catch err
    throwAsCaller(err);
end
end

function checkImageStack(images)
validClasses = {'double', 'single', 'uint8', 'int16', 'uint16'};
validateattributes(images, validClasses,...
    {'nonempty', 'real', 'nonsparse'},...
    mfilename, 'images');
end

function [points, boardSize, imageIdx, userCanceled, boardRot] = detectGridFiles(fileNames, opt)
%detectGridFiles Detects checkerboards in a set of images specified by file names

numImages    = numel(fileNames);
boardPoints  = cell(1, numImages);
boardSizes   = zeros(numImages, 2);
boardRot     = zeros(numImages, 1);
userCanceled = false;
for i = 1:numImages
    im = imread(fileNames{i});
    [boardPoints{i}, boardSizes(i,:), boardRot(i)] = detectGridInOneImage(im, opt);
end
[points, boardSize, imageIdx, boardRot] = chooseValidBoards(boardPoints, boardSizes, boardRot);
end

function [points, boardSize, imageIdx, userCanceled, boardRot] = detectGridStack(images, opt)
%detectGridStack Detects checkerboards in a stack of images

numImages    = size(images, 4);
boardPoints  = cell(1, numImages);
boardSizes   = zeros(numImages, 2);
boardRot     = zeros(numImages, 1);
userCanceled = false;
for i = 1:numImages
    im = images(:, :, :, i);
    [boardPoints{i}, boardSizes(i,:), boardRot(i)] = detectGridInOneImage(im, opt);
end
[points, boardSize, imageIdx, boardRot] = chooseValidBoards(boardPoints, boardSizes, boardRot);
end

function [points, boardSize, imageIdx, boardRot]               = chooseValidBoards(boardPoints, boardSizes, boardRot)
%chooseValidBoards Determines which board size is the most common in the set

uniqueBoardIds = 2.^boardSizes(:, 1) .* 3.^boardSizes(:, 2);
% Eliminate images where no board was detected.
% The unique board id in this case is 2^0 + 3^0 = 1.
% Replace all 1's by a sequence of 1:n * 1e10, which will be different from
% all other numbers which are only multiples of 2 and 3.
zeroIdx = (uniqueBoardIds == 1);
uniqueBoardIds(zeroIdx) = (1:sum(zeroIdx)) * 5;

% Find the most common value among unique board ids.
[~, ~, modes] = mode(uniqueBoardIds);
modeBoardId = max(modes{1});

% Get the corresponding points
imageIdx = (uniqueBoardIds == modeBoardId);
boardSize = boardSizes(imageIdx, :);
boardSize = boardSize(1, :);
boardRot  = boardRot(imageIdx);
boardRot  = mean(boardRot);
points    = boardPoints(imageIdx);
points    = cat(3, points{:});
end

function [points, boardSize, imageIdx, userCanceled, boardRot] = detectMono(I, opt)
%detectMono Detects the checkerboards in a single set of images

userCanceled = false;
if iscell(I)
    % detect in a set of images specified by file names
    fileNames = I;
    checkFileNames(fileNames);
    [points, boardSize, imageIdx, boardRot] = detectGridFiles(fileNames, opt);
elseif ischar(I)
    % detect in a single image specified by a file name
    fileName = I;
    checkFileName(I);
    I = imread(fileName);
    [points, boardSize, boardRot] = detectGridInOneImage(I, opt);
    imageIdx = ~isempty(points);
elseif ndims(I) > 3
    % detect in a stack of images
    checkImageStack(I);
    [points, boardSize, imageIdx, boardRot] = detectGridStack(I, opt);
else
    % detect in a single image
    vision.internal.inputValidation.validateImage(I, 'I');
    [points, boardSize, boardRot] = detectGridInOneImage(I, opt);
    imageIdx = ~isempty(points);
end
end
