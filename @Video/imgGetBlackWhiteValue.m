function [black, white] = imgGetBlackWhiteValue(img)
% imgGetBlackWhiteValue Returns black and white value for the given image

narginchk(1,1);
if islogical(img)
    black = false;
    white = true;
elseif isinteger(img)
    black = intmin(class(img));
    white = intmax(class(img));
elseif isfloat(img)
    black = cast(0,'like',img);
    white = cast(1,'like',img);
else
    error(sprintf('alexludwigklein:%s',mfilename),...
        'Unsupported image class. Please check!');
end
end