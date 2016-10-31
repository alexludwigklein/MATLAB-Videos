function [ data, opt, init ] = process_SubtractBackground(data, opt, init, state, varargin)
%process_SubtractBackground Post processing function for PROCESS method of Video objects
%
% Purpose:
% The function subtracts a background image from the video

if strcmp(state,'pre')
    %
    % configure how this function should be used
    opt.runmode = 'images';
    opt.outmode = 'cdata';
    %
    % parse options with input parser
    myopt               = inputParser;
    myopt.StructExpand  = true;
    myopt.KeepUnmatched = false;
    % background image as filename or actual image, leave empty if function should try to find one
    myopt.addParameter('background', [], ...
        @(x) isempty(x) || ((ischar(x) && exist(x,'file') && numel(dir(x)) == 1) || ...
        (isa(x,class(data.cdata(:,:,:,1))) && isequal(size(x),size(data.cdata(:,:,:,1))))));
    % normalize image by background instead of subtraction
    myopt.addParameter('normalize', true, ...
        @(x) islogical(x) && isscalar(x))
    % matches background mean value before subtraction, needs a area to compute the mean of the
    % background, given as rectangle (relative e.g. [ 0 0 0.1 0.1] for bottom left 10%)
    myopt.addParameter('matchBGMean', [], ...
        @(x) isempty(x) || isnumeric(x))
    myopt.parse(varargin{:});
    init.opt = myopt.Results;
    %
    % find or get the background image and check
    if isempty(init.opt.background)
        if isstruct(data.userdata) && isfield(data.userdata,'process_SubtractBackground') && ...
            isfield(data.userdata.process_WhereDidItGo,'background')
            % background image from userdata of this function
            init.bg = data.userdata.process_SubtractBackground.background;
        elseif isstruct(data.userdata) && isfield(data.userdata,'background')
            % background image from userdata
            init.bg = data.userdata.background;
        elseif exist([data.filename, '_background.tif'],'file') && numel(dir([data.filename, '_background.tif'])) == 1
            % background from file
            init.bg = imread([data.filename, '_background.tif']);
        else
            % take the first image
            init.bg = data.cdata(:,:,:,1);
        end
    elseif ischar(init.opt.background)
        init.bg = imread(init.opt.background);
    else
        init.bg = init.opt.background;
    end
    if ~(isa(init.bg,class(data.cdata(:,:,:,1))) && isequal(size(init.bg),size(data.cdata(:,:,:,1))))
        error(sprintf('%s:Input',mfilename),'Background image is not valid for ''%s''',data.filename);
    end
    % image for normalization
    if init.opt.normalize
        init.bg   = im2double(init.bg);
        init.func = str2func(sprintf('im2%s',data.cdataClass));
    end
    % create mask to compute mean
    if ~isempty(init.opt.matchBGMean)
        tmp = init.opt.matchBGMean;
        if numel(tmp) == 4 && all(tmp<=1) && all((tmp(1:2)+tmp(3:4))<=1)
            mask = false(data.nY,data.nX,data.nZ);
            idxX = max(1,round(tmp(1)*data.nX)):min(data.nX,round((tmp(1)+tmp(3))*data.nX));
            idxY = data.nY - (max(1,round(tmp(2)*data.nY)):min(data.nY,round((tmp(2)+tmp(4))*data.nY))) + 1;
            mask(idxY,idxX,:)     = true;
            init.matchBGMean.mask = mask;
            init.matchBGMean.mean = mean(reshape(init.bg(mask),[],1));
        else 
            error(sprintf('%s:Input',mfilename),'Cannot handle mask to adapt background image');
        end
    end
    return;
end

if strcmp(state,'run')
    if ~isempty(init.opt.matchBGMean)
        % prepare background to match mean before subtraction        
        if ~init.opt.normalize
            for i = 1:size(data,4)
                img           = data(:,:,:,i);
                bg            = mean(reshape(img(init.matchBGMean.mask),[],1))/init.matchBGMean.mean;
                bg            = init.bg * bg;
                data(:,:,:,i) = imcomplement(imabsdiff(img,bg));
            end
        else
            for i = 1:size(data,4)
                img           = im2double(data(:,:,:,i));
                bg            = init.bg * mean(reshape(img(init.matchBGMean.mask),[],1))/init.matchBGMean.mean;
                data(:,:,:,i) = init.func(imdivide(img,bg));
            end
        end
    else
        % subtract background
        if ~init.opt.normalize
            for i = 1:size(data,4)
                data(:,:,:,i) = imcomplement(imabsdiff(data(:,:,:,i),init.bg));
            end
        else
            for i = 1:size(data,4)
                data(:,:,:,i) = init.func(imdivide(im2double(data(:,:,:,i)),init.bg));
            end
        end
    end
    return;
end

if strcmp(state,'post')
    return;
end
end
