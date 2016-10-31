function img = imgColorize(img,pixellist,setColor,funcColor)
% imgColorize Colorizes grayscale image with color at given positions and returns RGB
%
%         img: grayscale image (in case of size(img,3) == 3 img(:,:,3) is interpreted as intensity)
%   pixellist: cell array with n pixellists/masks, a single pixellist as numeric input or a mask
%    setcolor: if true the objects in pixellist are set to a specific color otherwise they are
%              highlighted by changing the saturation in hsv color space
%   funcColor: function handle to create a matrix with RGB colors, size n x 3, where n is the input
%              to the function. Only used if setColor is true. (optional)

if isempty(img) || isempty(pixellist)
    return
end
if nargin < 4, setColor = false; end
if ~iscell(pixellist), pixellist = {pixellist}; end
for i = 1:numel(pixellist); pixellist{i} = pixellist{i}(:); end
[tmpHeight, tmpWidth, tmpDepth] = size(img);
strClass                        = class(img);
mycast                          = str2func(['im2',strClass]);
% replace and create new image, reshape so that each column is one color channel
if tmpDepth < 3
    img = reshape(img,[],1);
    img = repmat(img,1,3);
else
    img = reshape(img,[],3);
end
if setColor
    if nargin < 5
        mycolor = mycast(parula(numel(pixellist)));
    else
        mycolor = mycast(funcColor(numel(pixellist)));
    end
    % set rgb channels to given color
    for i = 1:3
        for k=1:numel(pixellist)
            if ~isempty(pixellist{k})
                img(pixellist{k},i) = mycolor(k,i);
            end
        end
    end
    img = reshape(img,tmpHeight,tmpWidth,3);
else
    % colorize output by changing the saturation, use a part of the colorcircle
    % in HSV color space
    mycolor      = ones(numel(pixellist),3);
    mycolor(:,1) = linspace(240/360,0,numel(pixellist));
    for k = 1:numel(pixellist)
        if ~isempty(pixellist{k}) && (~islogical(pixellist{k}) || ...
                (islogical(pixellist{k}) && any(pixellist{k}(:))))
            if islogical(pixellist{k})
                nP = sum(pixellist{k});
            else
                nP = numel(pixellist{k});
            end
            curObj      = repmat(mycolor(k,:),[nP,1]);
            curObj(:,2) = im2double(img(pixellist{k},3));
            curObj      = mycast(hsv2rgb(curObj));
            for i = 1:3
                img(pixellist{k},i) = curObj(:,i);
            end
        end
    end
    img = reshape(img,tmpHeight,tmpWidth,3);
end
end