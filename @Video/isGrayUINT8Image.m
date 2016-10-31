function out = isGrayUINT8Image(img)
% isGrayUINT8Image Tests if img is an uint8 grayscale image

if (isa(img,'uint8') || (isa(img,'gpuArray') && strcmp(classUnderlying(img),'uint8')))  && ismatrix(img)
    out = true;
else
    out = false;
end
end