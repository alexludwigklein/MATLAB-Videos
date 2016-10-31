function [ data, opt, init ] = process_Dummy(data, opt, init, state, varargin)
%process_Dummy Post processing function for PROCESS method of Video objects
%
% Purpose:
% A dummy function for testing, etc.

if strcmp(state,'pre')
    %
    % configure how this function should be used
    opt.runmode = 'images';
    opt.outmode = 'cdata';
    %
    % set init to empty
    init = [];
    return;
end

if strcmp(state,'run')
    % data(1:100,1:100,:) = 0;
    
    data = repmat(data,[1 1 3]);
    data(:,:,3) = 0.5 * data(:,:,3);
    
    return;
end

if strcmp(state,'post')
    return;
end
end
