function out = isDoubleImage(img)
% isGrayINT16Image Tests if img is an int16 grayscale image

if (isa(img,'double') || (isa(img,'gpuArray') && strcmp(classUnderlying(img),'double'))) && ismatrix(img)
    out = true;
else
    out = false;
end
end