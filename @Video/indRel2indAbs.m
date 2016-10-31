function ind = indRel2indAbs(ind,cropRect,absSize)
% pixRel2pixAbs Transforms linear index to coordinate system of image with size absSize before
% cropping with cropRect. If any component of cropRect is negative or any input is empty, no
% transformation takes place

if  isempty(ind) || isempty(cropRect) || any(cropRect < 0)
    return
end
if size(ind,2) ~= 1
    error(sprintf('%s:Transform',mfilename),'Wrong input size');
end
% transform to subscripts first, make use of pixRel2pixAbs and then back to linear
% indices, Note: cropRect is supposed to give [xmin ymin width height] which should
% correspond to second and first dimension when indexing a matrix
[y, x] = ind2sub(cropRect([4 3]),ind);
pos    = pixRel2pixAbs([x(:) y(:)],cropRect);
ind    = sub2ind(absSize([1 2]),pos(:,2),pos(:,1));
end