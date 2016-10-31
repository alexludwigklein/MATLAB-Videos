function  imgSetPixelMagnification(img,mag)
%imgSetPixelMagnification Sets the pixel magnification of a given image in an axes
%
% The term pixel magnification refers here to the ratio of screen pixels to image pixels, e.g. a
% magnification of one means on screen pixel shows one image pixel.

%
% check input
narginchk(1,2);
nargoutchk(0,1);
if nargin < 2, mag = 1; end
if ~(isnumeric(mag) && isscalar(mag) && mag > 0)
    error(sprintf('%s:Input',mfilename),'Magnification (2nd input) is expected to be a scalar larger than zero');
end
if ~all(isgraphics(img,'image'))
    error(sprintf('%s:Input',mfilename),'Image (1st input) is expected to be one or multiple image object(s)');
end
%
% set axes limits and keep the center of the view
for n = 1:numel(img)
    par       = img(n).Parent;
    bak       = par.Units;
    par.Units = 'pixels';
    pos       = par.Position;
    par.Units = bak;
    siz       = size(img(n).CData);
    par.XLim  = sort(mean(par.XLim) + [-0.5 0.5] * pos(3) * diff(img(n).XData)/(siz(2)-1)/mag);
    par.YLim  = sort(mean(par.YLim) + [-0.5 0.5] * pos(4) * diff(img(n).YData)/(siz(1)-1)/mag);
end
