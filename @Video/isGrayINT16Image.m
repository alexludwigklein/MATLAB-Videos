function out = isGrayINT16Image(img)
% isGrayINT16Image Tests if img is an int16 grayscale image

if (isa(img,'int16') || (isa(img,'gpuArray') && strcmp(classUnderlying(img),'int16'))) && ismatrix(img)
    out = true;
else
    out = false;
end
end