function varargout = guiGetMask(varargin)
%guiGetMask Creates modal GUI to setup a binary mask in an given img
% First input should be the image (filename or actual image), if an empty array is given or no input
% is given at all a dialog asks for an image file.

%
% check input
if numel(varargin) <= 1
    if numel(varargin) < 1
        [img, user_canceled] = imgetfile;
        if user_canceled, varargout = {[]}; return; end
    else
        img = varargin{1};
    end
    if ischar(img) && exist(img,'file') && numel(dir(img)) == 1
        img = imread(img);
    elseif ~Video.isImage(img)
        error(sprintf('%s:Input',mfilename),'Input for image is not valid');
    end
else
    error(sprintf('%s:Input',mfilename),'Input is unexpected');
end
%
% Settings
% Spacing and length of GUI elements in pixels [spacing of uicontrols, height of
% uicontrols, length of uicontrols (big, medium, small), spacing to fix text
% uicontrols], Default: [5 20 135 65 30 -4]
dp = [5 20 255 125 60 -4];
%
% Prepare to close figure opened by last run, but copy size
figTag = mfilename;
oldFig = findall(groot,'tag',figTag);
if ~isempty(oldFig)
    % use existing figure and remove its children to clean
    fig    = oldFig(1);
    figPos = fig.Position;
    delete(fig.Children);
    fig.UserData = [];
    if numel(oldFig) > 1
        close(oldFig(2:end));
    end
else
    aspectRatio = 2*size(img,2)/size(img,1);
    tmp         = groot;
    
    
    
    figPos      = [70 50 aspectRatio*(tmp.ScreenSize(4)-250) (tmp.ScreenSize(4)-250)];
    % create new figure
    fig  = figure('name', 'Create a binary mask', ...
        'numbertitle', 'off', 'Visible', 'off', 'WindowStyle', 'modal',...
        'menubar', 'none', 'toolbar', 'figure', 'resize', 'on', ...
        'tag', figTag, 'position', figPos);
    fig.CloseRequestFcn = @(src,event) guiGetMaskClose(src,event,fig);
    fig.ResizeFcn       = @(src,event) guiGetMaskResize(src,event,fig);
end
%
% add GUI elements
dxP = dp(1);
dyB = dp(2);
dxM = dp(4);
fig.UserData.dp = dp;
fig.UserData.hPolygon = uicontrol(fig,'Style','pushbutton',...
    'String','Polygon ROI','Tag','Polygon',...
    'TooltipString','Select ROI with polygon tool',...
    'Position',[0*dxM+1*dxP dxP dxM dyB],...
    'Callback', @(src,event) guiGetMaskCallback(src,event,fig));
fig.UserData.hRectangle = uicontrol(fig,'Style','pushbutton',...
    'String','Rectangle ROI','Tag','Rectangle',...
    'TooltipString','Select ROI with rectangle tool',...
    'Position',[1*dxM+2*dxP dxP dxM dyB],...
    'Callback', @(src,event) guiGetMaskCallback(src,event,fig));
fig.UserData.hEllipse = uicontrol(fig,'Style','pushbutton',...
    'String','Ellipse ROI','Tag','Ellipse',...
    'TooltipString','Select ROI with ellipse tool',...
    'Position',[2*dxM+3*dxP dxP dxM dyB],...
    'Callback', @(src,event) guiGetMaskCallback(src,event,fig));
fig.UserData.hFreehand = uicontrol(fig,'Style','pushbutton',...
    'String','Freehand ROI','Tag','Freehand',...
    'TooltipString','Select ROI with freehand tool',...
    'Position',[3*dxM+4*dxP dxP dxM dyB],...
    'Callback', @(src,event) guiGetMaskCallback(src,event,fig));
fig.UserData.hDeleteROI = uicontrol(fig,'Style','pushbutton',...
    'String','Clear ROI(s)','Tag','DeleteROI',...
    'TooltipString','Delete ROI object(s) without changing the mask',...
    'Position',[4*dxM+5*dxP dxP dxM dyB],...
    'Callback', @(src,event) guiGetMaskCallback(src,event,fig));
fig.UserData.hGetMask = uicontrol(fig,'Style','pushbutton',...
    'String','Create Mask','Tag','GetMask',...
    'TooltipString','Get binary mask from ROI(s) and show result',...
    'Position',[5*dxM+6*dxP dxP dxM dyB],...
    'Callback', @(src,event)  guiGetMaskCallback(src,event,fig));
fig.UserData.hGetInverseMask = uicontrol(fig,'Style','pushbutton',...
    'String','Create Inv. Mask','Tag','GetInverseMask',...
    'TooltipString','Get inverse binary mask from ROI(s) and show result',...
    'Position',[6*dxM+7*dxP dxP dxM dyB],...
    'Callback', @(src,event) guiGetMaskCallback(src,event,fig));
fig.UserData.hFinish = uicontrol(fig,'Style','pushbutton',...
    'String','Finish','Tag','Finish',...
    'TooltipString','Close figure and return current mask',...
    'Position',[7*dxM+8*dxP dxP dxM dyB],...
    'Callback', @(src,event) guiGetMaskCallback(src,event,fig));
% create img to show and store original image and mask for later use
fig.UserData.img         = img;
fig.UserData.sizImg      = size(img);
[img, fig.UserData.mask] = guiGetMaskImgMask(img,[]);
% create movie panel to show image without rescale option
fig.UserData.Videopanel = Videopanel(fig,'data',img,...
    'position',[dxP 2*dxP+1*dyB figPos(3)-2*dxP figPos(4)-(3*dxP+1*dyB)],'showSelect',false,...
    'showRescale',false, 'name','Setup ROI(s) and create a binary mask susequently',...
    'rescale',1,'dp',dp([1 2 5]),'label',{'Current ROI(s)' 'Current mask'});
% prepare some settings and wait for figure
fig.UserData.myROI    = {};
fig.UserData.roiIsNew = false;
fig.Visible = 'on';
fig.UserData.isDone = false;
while ~fig.UserData.isDone
    uiwait(fig);
end
% return current mask and clean up
varargout = {fig.UserData.mask};
if ishandle(fig)
    delete(fig);
end
delete(findall(0,'Type','figure','Tag',figTag));
end

function [out, mask] = guiGetMaskImgMask(img,mask)
%guiGetMaskImgMask Combine image and a mask to 4D image to be shown in a GUI

sizImg = size(img);
if nargin < 2 || isempty(mask)
    mask = false(sizImg([1 2]));
end
sizMask = size(mask);
if ~isequal(sizImg([1 2]),sizMask([1 2]))
    mask = false(sizImg([1 2]));
end
out   = repmat(img,[1,1,1,2]);
[b,w] = Video.imgGetBlackWhiteValue(img);
if mean(img(:)) > double(b)+0.5*(double(w)-double(b))
    img(repmat(mask,[1,1,size(img,3)])) = b;
else
    img(repmat(mask,[1,1,size(img,3)])) = w;
end
out(:,:,:,2) = img;
end

function guiGetMaskClose(src,event,fig) %#ok<INUSL>
%guiGetMaskClose Closes figure

fig.UserData.isDone = true;
uiresume(fig);
end

function guiGetMaskResize(src,event,fig) %#ok<INUSL>
%guiGetMaskClose Resize figure

% resize panel of movie panel
dxP    = fig.UserData.dp(1);
dyB    = fig.UserData.dp(2);
dxB    = fig.UserData.dp(3);
posNew = get(gcbo,'Position');
if posNew(3) < 2*dxB || posNew(4) < 5*dyB
    return
end
posMP  = [dxP 2*dxP+1*dyB posNew(3)-2*dxP posNew(4)-6*dxP-dyB];
set(fig.UserData.Videopanel,'position',posMP);
% resize uicontrols
hChange = [fig.UserData.hFinish fig.UserData.hPolygon fig.UserData.hGetMask ...
    fig.UserData.hGetInverseMask fig.UserData.hRectangle fig.UserData.hEllipse ...
    fig.UserData.hFreehand fig.UserData.hDeleteROI];
dxB     = (posMP(3)-(numel(hChange)-1)*dxP)/numel(hChange);
[~,idx] = sort(cellfun(@(x) x(1),get(hChange,'Position')));
hChange = hChange(idx);
for i = 1:numel(hChange)
    pos    = [dxP*i+dxB*(i-1) dxP dxB dyB];
    set(hChange(i),'Position',pos);
end
end

function guiGetMaskCallback(src,event,fig) %#ok<INUSL>
%guiGetMaskCallback Callbacks of figure

h      = gcbo;
tag    = get(h,'Tag');
newROI = true;
switch tag
    case 'Ellipse'
        func = @imellipse;
    case 'Polygon'
        func = @impoly;
    case 'Rectangle'
        func = @imrect;
    case 'Freehand'
        func = @imfreehand;
    case 'DeleteROI'
        fig.UserData.myROI(cellfun(@(x) ~isa(x,'imroi'),fig.UserData.myROI)) = [];
        if ~isempty(fig.UserData.myROI)
            for i = 1:numel(fig.UserData.myROI)
                delete(fig.UserData.myROI{i});
            end
            fig.UserData.myROI = {};
        end
        return
    case {'GetMask' 'GetInverseMask'}
        newROI = false;
    case 'Finish'
        if fig.UserData.roiIsNew
            % ask user if he really wants to proceed
            choice = questdlg('Current binary mask is *NOT* up to date due to change at ROI(s). Do really want to close the GUI?',...
                'Closing GUI', 'Yes','No','Yes');
            % handle response
            switch choice
                case 'Yes'
                otherwise
                    return;
            end
        end
        fig.UserData.isDone = true;
        uiresume(fig);
        return
    otherwise
        return;
end
if newROI
    % add ROI handle to cell array
    hROI   = func(fig.UserData.Videopanel.axes);
    addNewPositionCallback(hROI,@(x) guiROIPositionCallback(fig,x));
    fig.UserData.myROI(end+1) = {hROI};
    fig.UserData.roiIsNew     = true;
else
    % get binary mask and combine all masks
    mask = false(fig.UserData.sizImg([1 2]));
    fig.UserData.myROI(cellfun(@(x) ~isa(x,'imroi'),fig.UserData.myROI)) = [];
    if ~isempty(fig.UserData.myROI)
        for i = 1:numel(fig.UserData.myROI)
            curMask = fig.UserData.myROI{i}.createMask;
            curMask = curMask(1:fig.UserData.sizImg(1),1:fig.UserData.sizImg(2),1);
            if ~isempty(curMask)
                mask = mask | curMask;
            end
        end
    end
    if strcmp(tag,'GetInverseMask')
        mask = ~mask;
    end
    fig.UserData.mask     = mask;
    fig.UserData.roiIsNew = false;
    % show current mask by updating movie panel
    set(fig.UserData.Videopanel,'data', guiGetMaskImgMask(fig.UserData.img,fig.UserData.mask));
end
end

function guiROIPositionCallback(fig,pos) %#ok<INUSD>
%guiROIPositionCallback Writes state of ROI to object

fig.UserData.roiIsNew = true;
end
