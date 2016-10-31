function out = pixresFromAnyTarget(img)
%pixresFromAnyTarget Determine pixel resolution from polygon that is drawn in given image

% check input and get image
if nargin < 1
    [filename, path2File] = uigetfile(...
        {'*.tif','TIF File (*.tif)'}, ...
        'Pick a tiff file for image calibration');
    if isequal(filename,0)
        error(sprintf('%s:Input',mfilename),'Filename to image is required');
    elseif exist(fullfile(path2File,filename),'file') == 2
        img = imread(fullfile(path2File,filename));
    else
        error(sprintf('%s:Input',mfilename),'Filename to image is required');
    end    
elseif ischar(img) && exist(img,'file') == 2
    img = imread(img);
elseif ~(isnumeric(img))
    error(sprintf('%s:Input',mfilename),'Image or filename to image is required as input');
end

bak = img;
% show image for cropping
fig = figure('Name','Select region for calibration in image');
ax  = subplot(1,1,1);
h   = imshow(img,'Parent',ax,'InitialMagnification','fit');
[img, rect] = imcrop(h);
if fig.isvalid, close(fig); end
if isempty(img)
    img = bak;
end
% show image for polygon
fig = figure('Name','Create polygon along known edges');
ax  = subplot(1,1,1);
h   = imshow(img,'Parent',ax,'InitialMagnification','fit'); %#ok<NASGU>
pol = impoly(ax);
% ask for length
opt.Resize      = 'on';
opt.WindowStyle = 'normal';
opt.Interpreter = 'none';
if isempty(pol)
    warning(sprintf('%s:Input',mfilename),'User cancelled calibration');
    out = NaN;
    return
end
pos    = pol.getPosition;
nEdge  = size(pos,1);
prompt = num2cell(1:nEdge);
prompt = cellfun(@(x) sprintf('Length of edge %d in m',x), prompt,'UniformOutput',false);
def    = repmat({'-1'},1,nEdge);
answer = inputdlg(prompt,'Length of polygon''s edges in m',1,def,opt);
if numel(answer) < 1
    warning(sprintf('%s:Input',mfilename),'User cancelled calibration');
    out = NaN;
else
    lenReal = cellfun(@(x) str2double(x),answer);
    if any(isnan(lenReal))
        warning(sprintf('%s:Input',mfilename),'User input seems not to be numeric');
        out = NaN;
        if fig.isvalid, close(fig); end
    elseif all(lenReal < 0)
        warning(sprintf('%s:Input',mfilename),'User input seems not to contain a valid edge length');
        out = NaN;
        if fig.isvalid, close(fig); end
    else
        pos    = pol.getPosition;
        nEdge  = size(pos,1);
        if numel(lenReal) ~= nEdge
            warning(sprintf('%s:Input',mfilename),'User input does not match polygon ... vertices deleted?');
            out = NaN;
            if fig.isvalid, close(fig); end
        else
            lenImg = [ pos; pos(1,:) ];
            lenImg = sqrt(sum((lenImg(2:end,:) - lenImg(1:end-1,:)).^2,2));
            out    = lenReal./lenImg;
            out    = out(lenReal>0);
            if (max(out)-min(out))/mean(out) > 0.01
                warning(sprintf('%s:Input',mfilename),'Error in pixel resolution seems to be large: %.2g%%',100*(max(out)-min(out))/mean(out));
            end
            out = mean(out);
            % show control image
            if fig.isvalid, close(fig); end
            fig = figure('Name','Control image'); %#ok<NASGU>
            ax  = subplot(1,1,1,'NextPlot','Add');
            h   = imshow(bak,'Parent',ax,'InitialMagnification','fit'); %#ok<NASGU>
            pos = [ pos; pos(1,:) ];
            pos = Video.pixRel2pixAbs(pos,rect);
            for i = 1:(size(pos,1)-1)
                plot(ax,[pos(i,1) pos(i+1,1)],[pos(i,2) pos(i+1,2)],'-xr');
                len = sqrt((pos(i,1) - pos(i+1,1))^2 + (pos(i,2) - pos(i+1,2))^2);
                text((pos(i,1)+pos(i+1,1))/2,(pos(i,2)+pos(i+1,2))/2,sprintf('%.2e m',len*out),'Parent',ax,...
                    'HorizontalAlignment','center', 'VerticalAlignment', 'middle','Color','red');
            end
        end
    end
end
end