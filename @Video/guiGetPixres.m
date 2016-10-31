function varargout = guiGetPixres(varargin)
%guiGetPixres Determines pixel resolution from polygon that is drawn in a given image
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
    aspectRatio = size(img,2)/size(img,1);
    tmp         = groot;
    bak         = tmp.Units;
    tmp.Units   = 'pixels';
    screensize  = tmp.ScreenSize;
    tmp.Units   = bak;
    figPos      = [70 50 aspectRatio*(screensize(4)-250) (screensize(4)-250)];
    % create new figure
    fig  = figure('name', 'Create polygon along known distances to determine a pixel resolution', ...
        'numbertitle', 'off', 'Visible', 'off', 'WindowStyle', 'normal',...
        'menubar', 'none', 'toolbar', 'figure', 'resize', 'on', ...
        'tag', figTag, 'position', figPos);
    fig.CloseRequestFcn = @(src,event) guiGetPixresClose(src,event,fig);
    fig.ResizeFcn       = @(src,event) guiGetPixresResize(src,event,fig);
end
%
% add GUI elements
fig.UserData.useH     = 40;
fig.UserData.pixres   = 1;
useH                  = min(0.1,fig.UserData.useH/figPos(4));
fig.UserData.hControl = uipanel('parent',fig,'Position',[0 0 1 useH],...
    'Tag','Control','Units','Normalized');
fig.UserData.hImgPanel = uipanel('parent',fig,'Position',[0 useH 1 1-useH],...
    'Tag','ImgPanel','Units','Normalized');
fig.UserData.hAxes = axes('OuterPosition',[0 0 1 1],'Parent',fig.UserData.hImgPanel);
fig.UserData.hImg  = imshow(img,'InitialMagnification','fit','Parent',fig.UserData.hAxes,...
    'XData',[0 size(img,2)-1],'YData',[0 size(img,1)-1]);
axis(fig.UserData.hAxes,'image');
axis(fig.UserData.hAxes,'on');
fig.UserData.hPolygon = uicontrol(fig.UserData.hControl,'Style','pushbutton',...
    'String','Polygon','Tag','Polygon','Units','Normalized',...
    'TooltipString','(Re-)create polygon along known distances in figure',...
    'Position',[0 0 1/3 1],...
    'Callback', @(src,event) guiGetPixresCallback(src,event,fig));
fig.UserData.hFinish = uicontrol(fig.UserData.hControl,'Style','pushbutton',...
    'String','Finish','Tag','Finish','Units','Normalized',...
    'TooltipString','Close figure and return pixel resolution',...
    'Position',[1/3 0 1/3 1],...
    'Callback', @(src,event) guiGetPixresCallback(src,event,fig));
fig.UserData.hPixres = uicontrol(fig.UserData.hControl,'Style','edit',...
    'String',num2str(fig.UserData.pixres),'Tag','Pixres','Units','Normalized',...
    'TooltipString','Current pixel resolution (input known pixel resolution)',...
    'Position',[2/3 0 1/3 1],...
    'Callback', @(src,event) guiGetPixresCallback(src,event,fig));
%
% add data to UserData
fig.UserData.imgSiz = size(img);
fig.UserData.isDone = false;
fig.UserData.imroi  = [];
fig.UserData.label  = [];
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

function guiGetPixresClose(src,event,fig) %#ok<INUSL>
%guiGetPixresClose Closes figure

fig.UserData.isDone = true;
uiresume(fig);
end

function guiGetPixresResize(src,event,fig) %#ok<INUSL>
%guiGetPixresClose Resize figure

useH = min(0.1,fig.UserData.useH/fig.Position(4));
fig.UserData.hControl.Position  = [0 0 1 useH];
fig.UserData.hImgPanel.Position = [0 useH 1 1-useH];
end

function guiGetPixresCallback(src,event,fig) %#ok<INUSL>
%guiGetPixresCallback Callbacks of figure

h      = gcbo;
tag    = get(h,'Tag');
switch tag
    case 'Polygon'
        % remove existing polygon and labels
        if ~isempty(fig.UserData.imroi)
            delete(fig.UserData.imroi);
        end
        if ~isempty(fig.UserData.label)
            delete(fig.UserData.label);
        end
        % add new polygon
        fig.UserData.imroi = impoly(fig.UserData.hAxes,'Closed',true);
        mypos              = fig.UserData.imroi.getPosition;
        % add labels
        fig.UserData.label = gobjects(size(mypos,1),1);
        mypos              = cat(1,mypos,mypos(1,:));
        for p = 1:numel(fig.UserData.label)
            fig.UserData.label(p) = text('Position',mean(mypos(p:p+1,:)),...
                'Parent',fig.UserData.hAxes,'String',num2str(sum(diff(mypos(p:p+1,:),1,1).^2)^0.5),...
                'FontSize',12,'Interpreter','none','PickableParts','visible',...
                'HorizontalAlignment','center','VerticalAlignment','middle',...
                'BackgroundColor','white');
            cm = uicontextmenu('Parent',fig);
            uimenu(cm, 'Label', 'Set length ...', 'Callback',...
                @(src,dat) updateLabel(fig,fig.UserData.label(p)));
            fig.UserData.label(p).UIContextMenu = cm;
        end
        % add callbacks
        fig.UserData.imroi.addNewPositionCallback(@(pos) updateROIPosition(fig,pos));
    case 'Pixres'
        [value, stat] = str2num(h.String); %#ok<ST2NM>
        if stat && isscalar(value) && isnumeric(value) && ~isnan(value)
            updatePixres(fig,value);
        else
            updatePixres(fig,fig.UserData.pixres);
        end
    case 'Finish'
        fig.UserData.isDone = true;
        uiresume(fig);
        return
    otherwise
        return;
end
end

function updateLabel(fig,h)
%updateLabel Updates distance of label by user input

oldLen = str2double(h.String);
answer = inputdlg({'Length of edge in world units'},'Input',1,{h.String});
if isempty(answer), return; end
[newLen, stat] = str2num(answer{1}); %#ok<ST2NM>
if stat && isscalar(newLen) && isnumeric(newLen) && ~isnan(newLen)
    updatePixres(fig,newLen/(oldLen/fig.UserData.pixres));
end
end

function updatePixres(fig,newPixres)
%updatePixres Updates figure for new pixel resolution

oldPixres               = fig.UserData.pixres;
fig.UserData.pixres     = newPixres;
fig.UserData.hImg.XData = [0 (fig.UserData.imgSiz(2)-1)*newPixres];
fig.UserData.hImg.YData = [0 (fig.UserData.imgSiz(1)-1)*newPixres];
mypos                   = fig.UserData.imroi.getPosition;
fig.UserData.imroi.setPosition(mypos*newPixres/oldPixres);
fig.UserData.hPixres.String = num2str(newPixres);
end

function updateROIPosition(fig,mypos)
%updateROIPosition Updates labels when ROI position changes

% add labels
mypos = cat(1,mypos,mypos(1,:));
if size(mypos,1) ~= numel(fig.UserData.label)+1
    delete(fig.UserData.label);
    fig.UserData.label = gobjects(size(mypos,1)-1,1);
    for p = 1:numel(fig.UserData.label)
        fig.UserData.label(p) = text('Position',mean(mypos(p:p+1,:)),...
            'Parent',fig.UserData.hAxes,'String',num2str(sum(diff(mypos(p:p+1,:),1,1).^2)^0.5),...
            'FontSize',12,'Interpreter','none','PickableParts','visible',...
            'HorizontalAlignment','center','VerticalAlignment','middle',...
            'BackgroundColor','white');
        cm = uicontextmenu('Parent',fig);
        uimenu(cm, 'Label', 'Set length ...', 'Callback',...
            @(src,dat) updateLabel(fig,fig.UserData.label(p)));
        fig.UserData.label(p).UIContextMenu = cm;
    end
else
    for p = 1:numel(fig.UserData.label)
        fig.UserData.label(p).Position = mean(mypos(p:p+1,:));
        fig.UserData.label(p).String   = num2str(sum(diff(mypos(p:p+1,:),1,1).^2)^0.5);
    end
end
end