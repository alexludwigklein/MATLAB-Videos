function varargout = guiGetPixresSquare(varargin)
%guiGetPixresSquare Determines pixel resolution from square pattern made of lines or dots
% First input should be the image (filename or actual image), if an empty array is given or no input
% is given at all a dialog asks for an image file. Any additional input is passed to
% detectGridPoints.

%
% check input
options = {};
img     = [];
% get image input
if numel(varargin) > 0
    if (islogical(varargin{1}) || isnumeric(varargin{1})) || (ischar(varargin{1}) && exist(varargin{1},'file') && ...
            numel(dir(varargin{1})) == 1)
        img         = varargin{1};
        varargin(1) = [];
    elseif isempty(varargin{1})
        img         = [];
        varargin(1) = [];
    end
end
% get options input
if numel(varargin) > 0
    options = varargin;
end
% get actual image
if isempty(img)
    [img, user_canceled] = imgetfile;
    if user_canceled, varargout = {NaN}; return; end
    img = imread(img);
elseif ischar(img) && exist(img,'file') && numel(dir(img)) == 1
    img = imread(img);
elseif ~Video.isImage(img)
    error(sprintf('%s:Input',mfilename),'Input for image is not valid');
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
    fig  = figure('name', 'Select grid in image, input grid distance and run detection', ...
        'numbertitle', 'off', 'Visible', 'off', 'WindowStyle', 'normal',...
        'menubar', 'none', 'toolbar', 'figure', 'resize', 'on', ...
        'tag', figTag, 'position', figPos);
    fig.CloseRequestFcn = @(src,event) guiGetPixresSquareClose(src,event,fig);
    fig.ResizeFcn       = @(src,event) guiGetPixresSquareResize(src,event,fig);
end

%
% add GUI elements
fig.UserData.useH     = 40;
fig.UserData.pixres   = NaN;
fig.UserData.freq     = NaN;
fig.UserData.res      = NaN;
fig.UserData.rot      = 0;
useH                  = min(0.1,fig.UserData.useH/figPos(4));
fig.UserData.hControl = uipanel('parent',fig,'Position',[0 0 1 useH],...
    'Tag','Control','Units','Normalized');
fig.UserData.hImgPanel = uipanel('parent',fig,'Position',[0 useH 0.5 1-useH],...
    'Tag','ImgPanel','Units','Normalized');
fig.UserData.hAxes = axes('OuterPosition',[0 0 1 1],'Parent',fig.UserData.hImgPanel);
fig.UserData.hImg  = imshow(img,'InitialMagnification','fit','Parent',fig.UserData.hAxes);
title(fig.UserData.hAxes,'Image and rectangle for selection');
axis(fig.UserData.hAxes,'image');
fig.UserData.hImgPanelFFT = uipanel('parent',fig,'Position',[0.5 useH 0.5 1-useH],...
    'Tag','ImgPanel','Units','Normalized');
fig.UserData.hAxesFFT  = axes('OuterPosition',[0 0 1 1],'Parent',fig.UserData.hImgPanelFFT,...
    'NextPlot','Add');
fig.UserData.hImgFFT   = imshow(img,'InitialMagnification','fit','Parent',fig.UserData.hAxesFFT);
fig.UserData.hTitleFFT = title(fig.UserData.hAxesFFT,['Select grid with rectangle in left image, ',...
    'input grid distance and press run to see results'],'Interpreter','none');
axis(fig.UserData.hAxesFFT,'image');
fig.UserData.hFinish = uicontrol(fig.UserData.hControl,'Style','pushbutton',...
    'String','Finish','Tag','Finish','Units','Normalized',...
    'TooltipString','Close figure and return pixel resolution',...
    'Position',[0 0 1/4 1],...
    'Callback', @(src,event) guiGetPixresSquareCallback(src,event,fig));
fig.UserData.hFinish = uicontrol(fig.UserData.hControl,'Style','pushbutton',...
    'String','Run','Tag','Run','Units','Normalized',...
    'TooltipString','Run post processing',...
    'Position',[1/4 0 1/4 1],...
    'Callback', @(src,event) guiGetPixresSquareCallback(src,event,fig));
fig.UserData.hFreq = uicontrol(fig.UserData.hControl,'Style','edit',...
    'String',num2str(fig.UserData.freq),'Tag','Freq','Units','Normalized',...
    'TooltipString','Single grid distance in world units',...
    'Position',[2/4 0 1/4 1],...
    'Callback', @(src,event) guiGetPixresSquareCallback(src,event,fig));
fig.UserData.hPixres = uicontrol(fig.UserData.hControl,'Style','edit',...
    'String',num2str(fig.UserData.pixres),'Tag','Pixres','Units','Normalized',...
    'TooltipString','Current pixel resolution (input known pixel resolution)',...
    'Position',[3/4 0 1/4 1],...
    'Callback', @(src,event) guiGetPixresSquareCallback(src,event,fig));
%
% add data to UserData
fig.UserData.options = options;
fig.UserData.img     = img;
fig.UserData.imgSiz  = size(img);
fig.UserData.isDone  = false;
fig.UserData.imroi   = imrect(fig.UserData.hAxes,[1 1 size(img,2) size(img,1)]);
fig.UserData.line    = plot([NaN NaN],[NaN NaN],'--o','color','green','MarkerFaceColor','red','MarkerEdgeColor','red');
fig.UserData.line2   = plot([NaN NaN],[NaN NaN],'x','color','blue');
% Do not allow initial and live update since the function takes too long to run
% fig.UserData.imroi.addNewPositionCallback(@(pos) updateGrid(fig));
% updateGrid(fig);
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

function guiGetPixresSquareClose(src,event,fig) %#ok<INUSL>
%guiGetPixresSquareClose Closes figure

fig.UserData.isDone = true;
uiresume(fig);
end

function guiGetPixresSquareResize(src,event,fig) %#ok<INUSL>
%guiGetPixresSquareClose Resize figure

useH = min(0.1,fig.UserData.useH/fig.Position(4));
fig.UserData.hControl.Position  = [0 0 1 useH];
fig.UserData.hImgPanel.Position = [0 useH 0.5 1-useH];
fig.UserData.hImgPanelFFT.Position = [0.5 useH 0.5 1-useH];
end

function guiGetPixresSquareCallback(src,event,fig) %#ok<INUSL>
%guiGetPixresSquareCallback Callbacks of figure

h      = gcbo;
tag    = get(h,'Tag');
switch tag
    case 'Run'
        updateGrid(fig);
    case 'Freq'
        [value, stat] = str2num(h.String); %#ok<ST2NM>
        if stat && isscalar(value) && isnumeric(value) && ~isnan(value)
            if isnan(fig.UserData.pixres)
                fig.UserData.freq = value;
                updateGrid(fig);
            else
                fig.UserData.pixres = value/(fig.UserData.freq/fig.UserData.pixres);
                fig.UserData.freq   = value;
            end
        end
        fig.UserData.hPixres.String   = num2str(fig.UserData.pixres);
        fig.UserData.hFreq.String     = num2str(fig.UserData.freq);
        fig.UserData.hTitleFFT.String = makeTitle(fig.UserData.pixres,fig.UserData.rot,fig.UserData.res);
    case 'Pixres'
        [value, stat] = str2num(h.String); %#ok<ST2NM>
        if stat && isscalar(value) && isnumeric(value) && ~isnan(value)
            if isnan(fig.UserData.freq)
                fig.UserData.pixres = value;
                fig.UserData.freq   = 1;
                updateGrid(fig);
            end
            fig.UserData.freq   = fig.UserData.freq/fig.UserData.pixres*value;
            fig.UserData.pixres = value;
        end
        fig.UserData.hPixres.String   = num2str(fig.UserData.pixres);
        fig.UserData.hFreq.String     = num2str(fig.UserData.freq);
        fig.UserData.hTitleFFT.String = makeTitle(fig.UserData.pixres,fig.UserData.rot,fig.UserData.res);
    case 'Finish'
        fig.UserData.isDone = true;
        uiresume(fig);
        return
    otherwise
        return;
end
end

function updateGrid(fig)
%updateGrid Updates with new FFT

fig.UserData.hTitleFFT.String = sprintf('Working ....');
set(fig.UserData.line,'XData',NaN(2,1),'YData',NaN(2,1));
set(fig.UserData.line2,'XData',NaN(2,1),'YData',NaN(2,1));
drawnow;
% get points
bb  = fig.UserData.imroi.getPosition;
img = imcrop(fig.UserData.img,bb);
try
    [points, boardSize, ~, ~, rot] = Video.detectGridPoints(img,'rect',false,fig.UserData.options{:});
catch
    points = [];
end

if ~isempty(points)
    dist = NaN(size(points,1),1);
    %
    % determine mean pixel resolution
    pos  = points;
    nPos = size(pos,1);
    for i = 1:nPos
        mydist    = sqrt(sum((pos - repmat(pos(i,:),nPos,1)).^2,2));
        mydist(i) = Inf; dist(i) = min(mydist);
    end
    len    = mean(dist);
    pixres = fig.UserData.freq/len;
    if abs(diff(boardSize)) < eps && nPos == prod(boardSize)
        %
        % order points
        transRot = affine2d([cos(rot) -sin(rot) 0; sin(rot) cos(rot) 0; 0 0 1]);
        pos      = transformPointsInverse(transRot,points);
        posLT    = [min(pos(:,1)) min(pos(:,2))];
        mydist   = sqrt(sum((pos - repmat(posLT,nPos,1)).^2,2));
        [~, idx] = min(mydist);
        idxTodo  = setdiff(1:nPos,idx);
        counter  = 2;
        while ~isempty(idxTodo)
            nTodo    = numel(idxTodo);
            mydist   = sqrt(sum((pos(idxTodo,:) - repmat(pos(idx(counter-1),:),nTodo,1)).^2,2));
            [mydist, myidx] = sort(mydist);
            if numel(mydist) > 1 && all(mydist(1:2) < 1.2*len)
                mydistx = pos(idxTodo(myidx(1:2)),1) - pos(idx(counter-1),1);
                [~, i]  = min(mydistx);
            else
                i = 1;
            end
            idx = [idx, idxTodo(myidx(i))]; %#ok<AGROW>
            idxTodo(myidx(i)) = [];
            counter = counter + 1;
        end
        for i = 2:2:boardSize(1)
            idx(boardSize(1)*(i-1)+(1:boardSize(1))) = idx(boardSize(1)*(i-1)+(boardSize(1):-1:1));
        end
        points  = points(idx,:);
        %
        % fit grid to get good estimate for pixres and rot
        pos0    = mean(points,1);
        params0 = [len, rot, pos0(1), pos0(2)];
        paramsl = [len/2 -pi/4 pos0(1)-len pos0(2)-len];
        paramsu = [len*2  pi/4 pos0(1)+len pos0(2)+len];
        options = optimoptions('lsqnonlin');
        options.Display = 'off';
        params  = lsqnonlin(@fitGrid,params0,paramsl,paramsu,options);
        rot     = params(2);
        len     = params(1);
        pos0    = [params(3) params(4)];
        pixres  = fig.UserData.freq/len;
        points2 = myGrid(boardSize(1),len,rot,pos0);
        res     = max(fitGrid(params));
    else
        points2 = NaN(2,2);
        res     = NaN;
    end
else
    points  = NaN(2,2);
    points2 = NaN(2,2);
    pixres  = NaN;
    rot     = NaN;
    res     = NaN;
    fig.UserData.hTitleFFT.String = sprintf('Failed to determine grid');
end
% update pixres and image
fig.UserData.pixres           = pixres;
fig.UserData.rot              = rot;
fig.UserData.res              = res;
fig.UserData.hPixres.String   = num2str(pixres);
fig.UserData.hImgFFT.CData    = img;
fig.UserData.hTitleFFT.String = makeTitle(pixres,rot,res);
set(fig.UserData.line,'XData',points(:,1),'YData',points(:,2));
set(fig.UserData.line2,'XData',points2(:,1),'YData',points2(:,2));
fig.UserData.hAxesFFT.XLimMode = 'auto';
fig.UserData.hAxesFFT.YLimMode = 'auto';

    function res = fitGrid(x)
        %fitGrid Used to fit grid by length of squares (x(1)) and rotation of grid (x(2))
        res = myGrid(boardSize(1),x(1),x(2),[x(3) x(4)]);
        res = sqrt(sum((res-points).^2,2));
    end

    function pos = myGrid(siz,len,rot,pos0)
        %myGrid Returns location of grid points for a square grid of size siz x siz with a length
        % len of each grid square and rotated by rot in radians. The center of the grid is moved to
        % pos0
        
        xg    = (0:(siz-1))*len;
        [x,y] = meshgrid(xg,xg);
        pos   = [x(:) y(:)];
        pos   = transformPointsForward(affine2d([cos(rot) -sin(rot) 0; sin(rot) cos(rot) 0; 0 0 1]),pos);
        pos   = pos + repmat(pos0-mean(pos,1),size(pos,1),1);
    end
end

function str = makeTitle(pixres,rot,res)
%makeTitle Returns a title with the results

if isnan(pixres)
    str = 'Grid not found or grid distance is missing';
else
    str = {sprintf('Detected grid leading to pixres = %0.2e wu/pix, rot = %0.2e deg',...
        pixres,rot*180/pi); 'Red & green: detected grid, blue: test grid'; ...
        sprintf('Maximum error in test grid %0.2e pix ',res)};
end
end