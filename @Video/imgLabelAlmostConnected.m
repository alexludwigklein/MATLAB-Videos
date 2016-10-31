function [CC,L] = imgLabelAlmostConnected(img,tol)
% imgLabelAlmostConnected  Connects components that are almost connected and returns label matrix
% and (almost) connected component, where connectivity is set to 0, since components might not be
% connected at all. Tolerance can be a numeric scalar, in which case the Euclidean distance is used
% to determine if components are almost connected. Otherwise it is expected to be a structuring
% element returnedby the strel function

if ~Video.isBWImage(img)
    error(sprintf('%s:Input',mfilename),'Wrong input. Please check!');
end
if isnumeric(tol) && isscalar(tol) &&  tol < eps
    CC = bwconncomp(img);
    L  = labelmatrix(CC);
    return
elseif isnumeric(tol) && isscalar(tol) &&  tol > eps
    img2 = bwdist(img) <= tol;
elseif isa(tol,'strel')
    img2 = imdilate(img,tol);
else
    error(sprintf('%s:Input',mfilename),'Wrong input. Please check!');
end
CC      = bwconncomp(img2);
L       = labelmatrix(CC);
L(~img) = 0;

nObj = max(L(:));
CC   = orderfields(struct('NumObjects',nObj,'PixelIdxList',{cell(1,nObj)},...
    'Connectivity',0,'ImageSize',size(img2)));
for i = 1:nObj
    CC.PixelIdxList{i} = find(L==i);
end
end