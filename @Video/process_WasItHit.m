function [ data, opt, init ] = process_WasItHit(data,opt,init,state,varargin) 
%process_WasItHit Post processing function for PROCESS method of Video objects
%
% Recommend/required settings for PROCESS method:
% runmode: image
% outmode: cell
%
% Purpose: The function analyses videos where a drop is shoot with a laser, in order to detect if
% the drop was hit. It actually checks if a mist reduces the brightnes a bit in a certain ROI ...
% rather specific function :)


if strcmp(state,'pre')
    % 
    % only change data if in debug mode to indicate where it went
    opt.runmode               = 'images';
    opt.ignoreOutput          = true;
    if opt.debug
        opt.outmode      = 'cdata';
        opt.ignoreOutput = false;
    else
        opt.outmode      = 'cell';
        opt.ignoreOutput = true;
    end
    % 
    % ask where to detect for mist in case the drop is hit
    if isstruct(data.userdata) && isfield(data.userdata,'process_WasItHit') && ...
            isfield(data.userdata.process_WasItHit, 'mask1')
        init.mask1 = data.userdata.process_WasItHit.mask1;
    elseif exist([data.filename '_mask1.tif'],'file') && numel(dir([data.filename '_mask1.tif']))==1
        init.mask1 = imread([data.filename '_mask1.tif']);
    else
        fprintf('Please, select single ROI where the drop is supposed to be in case it does not make it to the catcher\n');
        init.mask1 = Video.guiGetMask(data.cdata(:,:,:,1));
    end
    % threshold for detection
    init.threshold =double(intmax(data.cdataClass))*0.7;
    % prepare result for output
    init.dropStatus = NaN(1,numel(opt.idxFrames));
    return;
end

if strcmp(state,'run')
    %  data: Depends on runmode: Video object, image or chunk of images
    %   opt: Options of the PROCESS method
    % state: State of call, 'run'
    %  init: Storage passed from call to call

    % 
    % if more than 10% in the mask are below the threshold, the mist should have been there
    %   NaN: No idea where it is
    %    >0: Fraction of the drop that was hit
    value                          = sum(data(init.mask1) < init.threshold)/sum(init.mask1(:));
    myfrac                         = double(value > 0.05);
    init.dropStatus(opt.curFrames) = myfrac;
    if opt.debug
        if myfrac > 0.5
            str = sprintf('-=  LASER HIT   =-\nFraction below threshold: %.2f%%',value*100);
            col = 'green';
        else
            str = sprintf('-= NO LASER HIT =-\nFraction below threshold: %.2f%%',value*100);
            col = 'red';
        end
        data = insertText(data,[300 500],str,'FontSize',60,'BoxColor',col);
    else
        data = [];
    end
    return;
end

if strcmp(state,'post')
    %  data: Video object
    %   opt: Options of the PROCESS method
    % state: State of call, 'pre'
    %  init: Storage passed from call to call
    
    % move result
    data.userdata.process_WasItHit = init;
    return;
end
end
