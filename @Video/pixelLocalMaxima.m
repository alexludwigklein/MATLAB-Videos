function loc = pixelLocalMaxima(metric, loc, halfPatchSize)
%pixelLocalMaxima Find location(s) of local maxima in a patch around given position(s)

for id = 1: size(loc,1)
    loc(id,:) = pixelLocationImpl(metric, loc(id,:));
end

    function pixelLoc = pixelLocationImpl(metric, loc)
        % check if the patch is outside the image
        if any(loc(:) < halfPatchSize + 1) || loc(1) > size(metric, 2) - halfPatchSize - 1 ...
                || loc(2) > size(metric, 1) - halfPatchSize -1
            pixelLoc = single(loc);
            return;
        end
        % get the patch
        patch = metric(loc(2)-halfPatchSize:loc(2)+halfPatchSize, ...
            loc(1)-halfPatchSize:loc(1)+halfPatchSize);
        % find maxima
        [~,idx]  = max(patch(:));
        [I, J]   = ind2sub(size(patch),idx);
        pixelLoc = single(loc) + [J-halfPatchSize-1 I-halfPatchSize-1];
    end
end