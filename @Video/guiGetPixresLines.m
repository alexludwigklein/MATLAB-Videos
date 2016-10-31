function varargout = guiGetPixresLines(varargin)
%guiGetPixresLines Determines pixel resolution from the spatial frequency in a test target
% First input should be the image (filename or actual image), if an empty array is given or no input
% is given at all a dialog asks for an image file.

%
% check input
if numel(varargin) <= 1
    if numel(varargin) < 1
        [img, user_canceled] = imgetfile;
        if user_canceled, varargout = {NaN}; return; end
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
if size(img,3) > 1, img = rgb2gray(img); end
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
    bak         = tmp.Units;
    tmp.Units   = 'pixels';
    screensize  = tmp.ScreenSize;
    tmp.Units   = bak;
    figPos      = [70 50 aspectRatio*(screensize(4)-250) (screensize(4)-250)];
    % create new figure
    fig  = figure('name', 'Input spatial frequency and select ROI in image to compute pixel resolution', ...
        'numbertitle', 'off', 'Visible', 'off', 'WindowStyle', 'normal',...
        'menubar', 'none', 'toolbar', 'figure', 'resize', 'on', ...
        'tag', figTag, 'position', figPos);
    fig.CloseRequestFcn = @(src,event) guiGetPixresLinesClose(src,event,fig);
    fig.ResizeFcn       = @(src,event) guiGetPixresLinesResize(src,event,fig);
end

%
% add GUI elements
fig.UserData.useH     = 40;
fig.UserData.pixres   = NaN;
fig.UserData.freq     = NaN;
fig.UserData.rot      = NaN;
useH                  = min(0.1,fig.UserData.useH/figPos(4));
fig.UserData.hControl = uipanel('parent',fig,'Position',[0 0 1 useH],...
    'Tag','Control','Units','Normalized');
fig.UserData.hImgPanel = uipanel('parent',fig,'Position',[0 useH 0.5 1-useH],...
    'Tag','ImgPanel','Units','Normalized');
fig.UserData.hAxes = axes('OuterPosition',[0 0 1 1],'Parent',fig.UserData.hImgPanel);
fig.UserData.hImg  = imshow(img,'InitialMagnification','fit','Parent',fig.UserData.hAxes);
title(fig.UserData.hAxes,'Image and ROI for selection');
axis(fig.UserData.hAxes,'image');
fig.UserData.hImgPanelFFT = uipanel('parent',fig,'Position',[0.5 useH 0.5 1-useH],...
    'Tag','ImgPanel','Units','Normalized');
fig.UserData.hAxesFFT  = axes('OuterPosition',[0 0 1 1],'Parent',fig.UserData.hImgPanelFFT,...
    'NextPlot','Add');
fig.UserData.hImgFFT   = imagesc(img,'Parent',fig.UserData.hAxesFFT);
fig.UserData.hTitleFFT = title(fig.UserData.hAxesFFT,' ','Interpreter','none');
axis(fig.UserData.hAxesFFT,'off');
axis(fig.UserData.hAxesFFT,'image');
colormap(fig.UserData.hAxesFFT,'parula');
fig.UserData.hFinish = uicontrol(fig.UserData.hControl,'Style','pushbutton',...
    'String','Finish','Tag','Finish','Units','Normalized',...
    'TooltipString','Close figure and return pixel resolution',...
    'Position',[0 0 1/3 1],...
    'Callback', @(src,event) guiGetPixresLinesCallback(src,event,fig));
fig.UserData.hFreq = uicontrol(fig.UserData.hControl,'Style','edit',...
    'String',num2str(fig.UserData.freq),'Tag','Freq','Units','Normalized',...
    'TooltipString','Line frequency in world units (e.g. as specified on Ronchi ruling)',...
    'Position',[1/3 0 1/3 1],...
    'Callback', @(src,event) guiGetPixresLinesCallback(src,event,fig));
fig.UserData.hPixres = uicontrol(fig.UserData.hControl,'Style','edit',...
    'String',num2str(fig.UserData.pixres),'Tag','Pixres','Units','Normalized',...
    'TooltipString','Current pixel resolution (input known pixel resolution)',...
    'Position',[2/3 0 1/3 1],...
    'Callback', @(src,event) guiGetPixresLinesCallback(src,event,fig));
%
% add data to UserData
fig.UserData.img    = img;
fig.UserData.imgSiz = size(img);
fig.UserData.isDone = false;
fig.UserData.imroi  = imrect(fig.UserData.hAxes,[1 1 size(img,2) size(img,1)]);
fig.UserData.imroi.addNewPositionCallback(@(pos) updateFFT(fig));
fig.UserData.line   = imdistline(fig.UserData.hAxesFFT,[1 2],[1 2]); %plot([NaN NaN],[NaN NaN],'x-','color','red');
strFormat           = fig.UserData.line.getLabelTextFormatter;
fig.UserData.line.setLabelTextFormatter([strFormat ' pix']);
fig.UserData.line.addNewPositionCallback(@(pos) updateLine(fig));
updateFFT(fig);
fig.Visible         = 'on';
while ~fig.UserData.isDone
    uiwait(fig);
end
% return current pixel resolution and clean up
varargout = {fig.UserData.pixres};
if ishandle(fig)
    delete(fig);
end
delete(findall(0,'Type','figure','Tag',figTag));
end

function guiGetPixresLinesClose(src,event,fig) %#ok<INUSL>
%guiGetPixresLinesClose Closes figure

fig.UserData.isDone = true;
uiresume(fig);
end

function guiGetPixresLinesResize(src,event,fig) %#ok<INUSL>
%guiGetPixresLinesClose Resize figure

useH = min(0.1,fig.UserData.useH/fig.Position(4));
fig.UserData.hControl.Position  = [0 0 1 useH];
fig.UserData.hImgPanel.Position = [0 useH 0.5 1-useH];
fig.UserData.hImgPanelFFT.Position = [0.5 useH 0.5 1-useH];
end

function guiGetPixresLinesCallback(src,event,fig) %#ok<INUSL>
%guiGetPixresLinesCallback Callbacks of figure

h      = gcbo;
tag    = get(h,'Tag');
switch tag
    case 'Freq'
        [value, stat] = str2num(h.String); %#ok<ST2NM>
        if stat && isscalar(value) && isnumeric(value) && ~isnan(value)
            if isnan(fig.UserData.pixres)
                fig.UserData.freq = value;
                updateFFT(fig);
            else
                fig.UserData.pixres = fig.UserData.pixres*fig.UserData.freq/value;
                fig.UserData.freq   = value;
            end
        end
        fig.UserData.hPixres.String   = num2str(fig.UserData.pixres);
        fig.UserData.hFreq.String     = num2str(fig.UserData.freq);
        fig.UserData.hTitleFFT.String = makeTitle(fig.UserData.pixres,fig.UserData.rot);
    case 'Pixres'
        [value, stat] = str2num(h.String); %#ok<ST2NM>
        if stat && isscalar(value) && isnumeric(value) && ~isnan(value)
            if isnan(fig.UserData.freq)
                fig.UserData.pixres = value;
                fig.UserData.freq   = 1;
                updateFFT(fig);
            end
            fig.UserData.freq   = fig.UserData.freq/fig.UserData.pixres*value;
            fig.UserData.pixres = value;
        end
        fig.UserData.hPixres.String   = num2str(fig.UserData.pixres);
        fig.UserData.hFreq.String     = num2str(fig.UserData.freq);
        fig.UserData.hTitleFFT.String = makeTitle(fig.UserData.pixres,fig.UserData.rot);
    case 'Finish'
        fig.UserData.isDone = true;
        uiresume(fig);
        return
    otherwise
        return;
end
end

function updateLine(fig)
%updateLine Updates if user moves the line

pos     = fig.UserData.line.getPosition;
siz     = fig.UserData.imroi.getPosition;
siz     = round(siz([4 3]));
pixres  = hypot(((pos(1,2)-pos(2,2))./siz(1)/2),((pos(1,1)-pos(2,1))./siz(2)/2))/fig.UserData.freq;
rot     = atan2(((pos(1,1)-pos(2,1))./siz(2)),((pos(1,2)-pos(2,2))./siz(1)));
fig.UserData.pixres           = pixres;
fig.UserData.rot              = rot;
fig.UserData.hPixres.String   = num2str(fig.UserData.pixres);
fig.UserData.hFreq.String     = num2str(fig.UserData.freq);
fig.UserData.hTitleFFT.String = makeTitle(fig.UserData.pixres,fig.UserData.rot);
drawnow;
end


function updateFFT(fig)
%updateFFT Updates with new FFT

% run fft with part of image
bb                         = fig.UserData.imroi.getPosition;
img                        = imcrop(fig.UserData.img,bb);
[pixres, rot, out, ~, pos] = Video.pixresFromLineTarget(img,fig.UserData.freq);
% update pixres and image
fig.UserData.pixres        = pixres;
fig.UserData.rot           = rot;
fig.UserData.hImgFFT.CData = out(round(size(out,1)*2/8):round(size(out,1)*6/8),round(size(out,2)*2/8):round(size(out,2)*6/8));
pos(:,1) = pos(:,1) - round(size(out,2)*2/8) + 1;
pos(:,2) = pos(:,2) - round(size(out,1)*2/8) + 1;
fig.UserData.line.setPosition(pos); % calls makeTitle and sets pixres in GUI
end

function str = makeTitle(pixres,rot)
%makeTitle Returns a title with the results

if isnan(pixres)
    str = 'Unknown spatial frequency, please input';
else
    str = sprintf('FFT2 of rectangle (partially) leading to pixres = %0.2e  wu/pix, rot = %0.2e deg',...
        pixres,rot*180/pi);
end
end