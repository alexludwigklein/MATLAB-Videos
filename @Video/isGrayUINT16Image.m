function out = isGrayUINT16Image(img)
% isGrayUINT16Image Tests if img is an uint16 grayscale image

if (isa(img,'uint16') || (isa(img,'gpuArray') && strcmp(classUnderlying(img),'uint16'))) && ismatrix(img)
    out = true;
else
    out = false;
end
end