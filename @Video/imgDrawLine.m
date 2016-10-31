function [ind, xy] = imgDrawLine(img,XY)
% imgDrawLine Returns linear and 2D indices of a line drawn in img between two points
% given by XY

x1 = XY(1,1);    y1 = XY(1,2);
x2 = XY(2,1);    y2 = XY(2,2);
xn = abs(x2-x1); yn = abs(y2-y1);
% interpolate against axis with greater distance between points
if (xn > yn)
    xc = x1 : sign(x2-x1) : x2;
    yc = round( interp1([x1 x2], [y1 y2], xc, 'linear') );
else
    yc = y1 : sign(y2-y1) : y2;
    xc = round( interp1([y1 y2], [x1 x2], yc, 'linear') );
end
% 2D indices of line are saved in xy, linear indices are calculated
xy  = [xc(:) yc(:)];
ind = sub2ind( size(img), xc, yc );
end