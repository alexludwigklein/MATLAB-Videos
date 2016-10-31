function [ data, opt, init ] = process_WhereDidItGo(data,opt,init,state,varargin) 
%process_WhereDidItGo Post processing function for PROCESS method of Video objects
%
% Recommend/required settings for PROCESS method:
% runmode: image
% outmode: cell
%
% Purpose:
% The function analyses videos where a drop is shoot with a laser and might go into a catcher bucket
% or maybe not - that should be found out by the function. It's a rather specific function :)


if strcmp(state,'pre')
    
    %
    % parse options with input parser
    myopt               = inputParser;
    myopt.StructExpand  = true;
    myopt.KeepUnmatched = false;
    % 
    myopt.addParameter('normalize', true, ...
        @(x) islogical(x) && isscalar(x))
    myopt.parse(varargin{:});
    init.opt = myopt.Results;
    %
    % get a background image
    [ data, opt, init ] = Video.process_SubtractBackground(data,opt,init,state);
    % 
    % change output mode to cell, since no actual data is changed
    opt.runmode = 'images';
    opt.outmode = 'cell';
    % 
    % ask where the drop should be in case it did not go into the bucket
    if isstruct(data.userdata) && isfield(data.userdata,'process_WhereDidItGo') && ...
            isfield(data.userdata.process_WhereDidItGo, 'mask1')
        init.mask1 = data.userdata.process_WhereDidItGo.mask1;
    elseif exist([data.filename '_mask1.tif'],'file') && numel(dir([data.filename '_mask1.tif']))==1
        init.mask1 = imread([data.filename '_mask1.tif']);
    else
        fprintf('Please, select single ROI where the drop is supposed to be in case it does not make it to the catcher\n');
        init.mask1 = Video.guiGetMask(data.cdata(:,:,:,1));
    end
    %
    % ask where the drop should be to determine the mean size in case it did not go into the bucket
    if isstruct(data.userdata) && isfield(data.userdata,'process_WhereDidItGo') && ...
            isfield(data.userdata.process_WhereDidItGo, 'mask2')
        init.mask2 = data.userdata.process_WhereDidItGo.mask2;
    elseif exist([data.filename '_mask2.tif'],'file') && numel(dir([data.filename '_mask2.tif']))==1
        init.mask2 = imread([data.filename '_mask2.tif']);
    else
        fprintf('Please, select single ROI where the drop is supposed to be in case it does not make it to the catcher and the size can be determined\n');
        init.mask2 = Video.guiGetMask(data.cdata(:,:,:,1));
    end
    stat = regionprops(init.mask2,'BoundingBox');
    bb   = round(stat.BoundingBox);
    init.xIDX = bb(1):(bb(1)+bb(3)-1);
    init.yIDX = bb(2):(bb(2)+bb(4)-1);
    %
    init.threshold = intmax(data.cdataClass)/2;
    % prepare result output for the the dropStatus and drop radius of the drop:
    init.dropStatus = NaN(1,numel(opt.idxFrames));
    init.dropRadius = NaN(1,numel(opt.idxFrames));
    init.dropPos    = NaN(2,numel(opt.idxFrames));
    return;
end

if strcmp(state,'run')
    %  data: Depends on runmode: Video object, image or chunk of images
    %   opt: Options of the PROCESS method
    % state: State of call, 'run'
    %  init: Storage passed from call to call

    % subtract background
    [ tmp, opt, init ] = Video.process_SubtractBackground(data,opt,init,state);
    % 
    % if more than 10% in the mask are below the threshold, the drop should have been there and
    % nothing should have gone into the catcher
    %   NaN: No idea where it is
    %    >0: Fraction of the drop that goes into the catcher
    myfrac = double(~(sum(tmp(init.mask1) < init.threshold)/sum(init.mask1(:)) > 0.1));
    init.dropStatus(opt.curFrames) = myfrac;
    if myfrac < 1
        % determine drop size
       img   = tmp(init.yIDX,init.xIDX);
       level = graythresh(img);
       img   = ~im2bw(img,level);
       stat  = regionprops(img,'Area','Centroid','Image');
       init.dropRadius(opt.curFrames) = sqrt(stat.Area/pi);
       init.dropPos(1,opt.curFrames)  = init.xIDX(1) + stat.Centroid(1) - 1;
       init.dropPos(2,opt.curFrames)  = init.yIDX(1) + stat.Centroid(2) - 1;
    end
    data = cell(1,size(data,4));
    return;
end
if strcmp(state,'post')
    %  data: Video object
    %   opt: Options of the PROCESS method
    % state: State of call, 'pre'
    %  init: Storage passed from call to call
    
    % move result
    init.dropRadius = init.dropRadius * mean(data.pixres);
    init.dropPos    = init.dropPos    * mean(data.pixres);
    data.userdata.process_WhereDidItGo = init;
    return;
end
end
