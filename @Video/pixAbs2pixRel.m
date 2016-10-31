function pos = pixAbs2pixRel(pos,cropRect)
% pixRel2pixAbs Transforms x and y position to coordinate system of image after cropping with
% cropRect. If any component of cropRect is negative or any input is empty, no transformation takes
% place

if  isempty(pos) || isempty(cropRect) || any(cropRect < 0)
    return
end
if size(pos,2) ~= 2
    error(sprintf('%s:Transform',mfilename),'Wrong input size');
end
pos = pos-repmat(cropRect([1 2])-1,size(pos,1),1);
end