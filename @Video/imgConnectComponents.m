function imgOut = imgConnectComponents(img,minDist,maxDist)
% imgConnectPixels Connects components in BW image with its nearest-neighbor
%
% * The distance needs to be within given limits
% * Connection is done with straight lines

if ~Video.isBWImage(img) || ...
        ~isnumeric(minDist) || ~isnumeric(maxDist) || ...
        ~isscalar(minDist) || ~isscalar(maxDist) || ...
        minDist < 0 || maxDist < 0
    error(sprintf('%s:Input',mfilename),'Wrong input. Please check!');
end
imgOut  = img;
doAgain = true;
i       = 1;
CC      = bwconncomp(imgOut);
while doAgain
    numObjects                 = CC.NumObjects;
    imgWOC                     = imgOut;
    imgWOC(CC.PixelIdxList{i}) = false;
    imgWC                      = false(size(imgOut));
    imgWC(CC.PixelIdxList{i})  = true;
    [imgDist, indDist] = bwdist(imgWOC,'euclidean');
    mask               = (imgDist>=minDist & imgDist<=maxDist & imgWC);
    if any(mask(:))
        imgDist(~mask)  = maxDist+1;
        [~,idxStart]    = min(imgDist(:));
        idxEnd          = indDist(idxStart);
        [x,y]           = ind2sub(size(imgOut),[idxStart idxEnd]);
        ind             = Video.imgDrawLine(imgOut,double([x(:) y(:)]));
        imgOut(ind)     = true;
    end
    CC = bwconncomp(imgOut);
    if CC.NumObjects == numObjects
        % number of objects did not change, i.e. no new connection and, therefore,
        % advance to next object, ToDo: May we miss one object, since numbering changes?
        i = i + 1;
    end
    if i == CC.NumObjects
        % the last object has already been tested with all previous objects, therefor,
        % stop here
        doAgain = false;
    end
end
end