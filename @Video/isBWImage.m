function out = isBWImage(img)
% isBWImage Tests if img is a logical BW image

if (isa(img,'logical') || (isa(img,'gpuArray') && strcmp(classUnderlying(img),'logical'))) && ismatrix(img)
    out = true;
else
    out = false;
end
end