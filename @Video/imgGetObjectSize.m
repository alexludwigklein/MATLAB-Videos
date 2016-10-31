function out = imgGetObjectSize(varargin)
%imgGetObjectSize Computes size of objects in BW image, plots and returns results as structure
% First numeric image should be the BW image, the second (optional) input can be a grayscale image
% that is used for the 2nd order moments instead the BW (the BW marks the area for computation in
% grayscale), any following input is given to the input parser (see code)
%
% Computes size by several methods, so far
% * Diameter based on number of pixel in each object
% * Diameter, etc. of an ellipse based on 2nd order moments
%
% Note: In code x and y are swapped as compared to output

%
% get images
if numel(varargin) < 1
    error(sprintf('%s:Input',mfilename),...
        'Function needs at least one numeric input');
end
img = {};
i   = 1;
while i <= numel(varargin) && (Video.isImage(varargin{i})) 
    img{i} = varargin{i}; %#ok<AGROW>
    i      = i + 1;
end
varargin(1:i-1) = [];
if ~(numel(img) > 0 && numel(img) <=2)
    error(sprintf('%s:Input',mfilename),...
        'Unknown number (%d) of images',numel(img));
end
if numel(img) > 1, imgGray = double(img{2});
else,              imgGray = [];
end
img = img{1};
if ~Video.isBWImage(img)
    error(sprintf('%s:Input',mfilename),'First image must be a black and white (logical) image');
end
if ~isempty(imgGray) && ~(Video.isImage(imgGray) && isequal(size(img),size(imgGray)))
    error(sprintf('%s:Input',mfilename),'Second image must be an image the same size as the first one');
end
%
% get input
opt               = inputParser;
opt.StructExpand  = true;
opt.KeepUnmatched = false;
% plot results
opt.addParameter('plot', false, ...
    @(x) islogical(x) && isscalar(x));
% only largest object, returns result for largest object based on dR_pixelCount
opt.addParameter('onlyLargest', false, ...
    @(x) islogical(x) && isscalar(x));
opt.parse(varargin{:});
opt = opt.Results;
%
% compute
L    = bwlabel(img);
stat = regionprops(L,'Centroid','Area','SubarrayIdx');
out  = struct;
[xGrid, yGrid] = ndgrid(1:size(img,1),1:size(img,2));
for i = 1:numel(stat)
    %
    % radius based on pixel count
    m1X_pixelCount = stat(i).Centroid(2);
    m1Y_pixelCount = stat(i).Centroid(1);
    dR_pixelCount  = sqrt(stat(i).Area/pi)*2;
    %
    % area, radius, etc. based on 2nd order moments as described in ISO11146 for beam profiles
    idxX     = stat(i).SubarrayIdx{1};
    idxY     = stat(i).SubarrayIdx{2};
    xg       = xGrid(idxX,idxY);
    yg       = yGrid(idxX,idxY);
    if isempty(imgGray)
        F = img(idxX,idxY);
    else
        F = imgGray(idxX,idxY);
    end
    % 1st order moments (eq. 1 & eq. 2 in ISO)
    E   = sum(F(:));
    m1X = sum(F(:).*xg(:))./E;
    m1Y = sum(F(:).*yg(:))./E;
    % 2nd order moments (eq. 3 & eq. 4 in ISO)
    m2X  = sum(F(:).*(xg(:)- m1X).^2)./E;
    m2Y  = sum(F(:).*(yg(:)- m1Y).^2)./E;
    m2XY = sum(F(:).*(xg(:)- m1X).*(yg(:)- m1Y))./E;
    % beam diameter (eq. 15 to 23 in ISO)
    if abs(m2X-m2Y)/(abs(m2X)+abs(m2Y)) > 1e-2
        phi   = 0.5 * atan(2*m2XY/(m2X-m2Y));
        gamma = sign(m2X-m2Y);
        tmp1  = m2X+m2Y;
        tmp2  = gamma.*((m2X-m2Y).^2+4*m2XY.^2).^0.5;
    else
        phi  = sign(m2XY)*pi/4;
        tmp1 = m2X+m2Y;
        tmp2 = 2*abs(m2XY);
    end
    dX  = 8^0.5 .*(tmp1+tmp2).^0.5;
    dY  = 8^0.5 .*(tmp1-tmp2).^0.5;
    dR  = 8^0.5 .*(tmp1).^0.5;
    % ellipticity and eccentricity
    ell = min(dX,dY)./max(dX,dY);
    ecc = sqrt(max(dX,dY).^2-min(dX,dY).^2)./max(dX,dY);
    % add results to output but flip x and y to do it in common coordinate system for images
    out(i).m1Y_pixelCount = m1X_pixelCount;
    out(i).m1X_pixelCount = m1Y_pixelCount;
    out(i).dR_pixelCount  = dR_pixelCount;
    out(i).m1Y            = m1X;
    out(i).m1X            = m1Y;
    out(i).m2Y            = m2X;
    out(i).m2X            = m2Y;
    out(i).m2XY           = m2XY;
    out(i).dY             = dX;
    out(i).dX             = dY;
    out(i).dR             = dR;
    out(i).phi            = phi;
    out(i).ell            = ell;
    out(i).ecc            = ecc;
end
%
% filter output
if opt.onlyLargest
    [~, idx] = max([out.dR_pixelCount]);
    out      = out(idx);
    L(L~=idx)= 0;
    L(L==idx)= 1;
end
%
% plot result with swapped x and y as compared to the code
if opt.plot
    %
    % prepare figure and show image
    nObj         = numel(out);
    mycObj       = parula(nObj);
    mycLine      = rgb2hsv(mycObj);
    mycLine(:,3) = mycLine(:,3)/2;
    mycLine      = hsv2rgb(mycLine);
    fig  = figure;
    if isempty(imgGray)
        ax   = subplot(1,1,1,'NextPlot','Add','Parent',fig);
    else
        ax    = subplot(1,2,1,'NextPlot','Add','Parent',fig);
        ax(2) = subplot(1,2,2,'NextPlot','Add','Parent',fig);
    end
    imgL = label2rgb(L,mycObj,[1 1 1]*1);
    image(imgL,'Parent',ax(1),'CDataMapping','direct');
    ax(1).YDir = 'reverse';
    % ax.XDir = 'normal';
    axis(ax(1),'equal');
    xlabel(ax(1),'x');
    ylabel(ax(1),'y');
    ax(1).Layer = 'top';
    if ~isempty(imgGray)
        imagesc(imgGray,'Parent',ax(2),'CDataMapping','direct');
        ax(2).YDir = 'reverse';
        % ax.XDir = 'normal';
        axis(ax(2),'equal');
        xlabel(ax(2),'x');
        ylabel(ax(2),'y');
        ax(2).Layer = 'top';
    end
    %
    % show circle and ellipse for each object
    xE = @(t,cX,cY,dX,dY,phi,scale) cX + scale*dX/2 * cos(phi) * cos(t) - scale*dY/2 * sin(phi) * sin(t);
    yE = @(t,cX,cY,dX,dY,phi,scale) cY + scale*dX/2 * sin(phi) * cos(t) + scale*dY/2 * cos(phi) * sin(t);
    t  = linspace(0,2*pi,100);
    for i = 1:nObj
        plot(ax(1), xE(t,out(i).m1X,out(i).m1Y,out(i).dX,out(i).dY,out(i).phi,1), yE(t,out(i).m1X,out(i).m1Y,out(i).dX,out(i).dY,out(i).phi,1),...
            'Color',mycLine(i,:),'Linestyle','-','LineWidth',2,...
            'DisplayName',sprintf('Ellipse, dR = %.2e',out(i).dR));
        plot(ax(1), xE(t,out(i).m1X_pixelCount,out(i).m1Y_pixelCount,out(i).dR_pixelCount,out(i).dR_pixelCount,0,1), ...
            yE(t,out(i).m1X_pixelCount,out(i).m1Y_pixelCount,out(i).dR_pixelCount,out(i).dR_pixelCount,0,1),...
            'Color',mycLine(i,:),'Linestyle','--','LineWidth',2,...
            'DisplayName',sprintf('Circle, dR = %.2e',out(i).dR_pixelCount));
        if ~isempty(imgGray)
            plot(ax(2), xE(t,out(i).m1X,out(i).m1Y,out(i).dX,out(i).dY,out(i).phi,1), yE(t,out(i).m1X,out(i).m1Y,out(i).dX,out(i).dY,out(i).phi,1),...
                'Color',mycLine(i,:),'Linestyle','-','LineWidth',2,...
                'DisplayName',sprintf('Ellipse, dR = %.2e',out(i).dR));
            plot(ax(2), xE(t,out(i).m1X_pixelCount,out(i).m1Y_pixelCount,out(i).dR_pixelCount,out(i).dR_pixelCount,0,1), ...
                yE(t,out(i).m1X_pixelCount,out(i).m1Y_pixelCount,out(i).dR_pixelCount,out(i).dR_pixelCount,0,1),...
                'Color',mycLine(i,:),'Linestyle','--','LineWidth',2,...
                'DisplayName',sprintf('Circle, dR = %.2e',out(i).dR_pixelCount));
        end
    end
    title(ax(1),sprintf('Size measurement for %d object',nObj));
    legend(ax(1),'show');
end
end