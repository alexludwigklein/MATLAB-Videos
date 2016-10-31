function [ data, opt, init ] = process_LabelCCFromFile(data, opt, init, state, varargin)
%process_LabelCCFromFile Post processing function for PROCESS method of Video objects
%
% Purpose: A wrapper function such that the result of the post processing as performed for the PoF
% experiments and PRApplied paper can be shown. The video MAT file should hold a CC structure where
% each frame of the movie is described by the output of bwconncomp (or similar).

if strcmp(state,'pre')
    %
    % configure how this function should be used
    opt.runmode = 'images';
    opt.outmode = 'cdata';
    %
    % load CC structure from file
    if any(strcmp('CC',data.cdata.list2MAT))
        init.CC = data.cdata.CC;
        tmpSize = vertcat(init.CC.ImageSize);
        tmpSize = tmpSize-repmat(tmpSize(1,:),size(tmpSize,1),1);
        if ~(numel(init.CC) == data.nFrames)
            warning(sprintf('%s:Input',mfilename),...
                'Video ''%s'' with %d frames holds CC structure for %d frames',...
                data.filename,data.nFrames,numel(init.CC));    
        end
        if any(tmpSize) > eps
            error(sprintf('%s:Input',mfilename),...
                'Video ''%s'' holds CC structure with changing image size',...
                data.filename,data.nFrames,numel(init.CC));
        end
        if init.CC(1).ImageSize(1,1) ~= data.nY || init.CC(1).ImageSize(1,2) ~= data.nX
            error(sprintf('%s:Input',mfilename),...
                'Video ''%s'' holds CC structure with image size different than frame size',...
                data.filename,data.nFrames,numel(init.CC));
        end
    else
        error(sprintf('%s:Input',mfilename),'Video ''%s'' does not hold CC structure',data.filename);
    end
    return;
end

if strcmp(state,'run')
    if opt.curFrames <= numel(init.CC)
        data = Video.imgColorize(data,init.CC(opt.curFrames).PixelIdxList,false,@parula);
    else
        data = repmat(data(:,:,1),[1 1 3]);
    end
    return;
end

if strcmp(state,'post')
    return;
end
end