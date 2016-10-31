function [pixres, rot, out, amp, pos] = pixresFromLineTarget(img,density)
% pixresFromLineTarget Determine pixel resolution from line pattern image and given line density
%    Input is the image or the filename to an image. If the density is omitted or set to one or
%    empty the method returns the spatial frequency, i.e. cycle per pixels
%
%    Algorithm:
%    * Use fft2 to find strongest spatial freqency neglecting the DC part
%    * Output is its spatial frequency devided by density and its orientation in rad,
%     third output is the fftshifted fft2 result and fourth output is the fftshifted fft2 result
%     with the DC part and outer part removed (actually used to determine the spatial frequency and
%     orientation)
%
%    Example: Make an image 'img' of a line test target with 40 lines per cm and call
%    pixresFromLineTarget(img,40e2) to determine the pixel resolution in m per pixel

if nargin < 2 || isempty(density)
    density = 1;
end
if ischar(img)
    if exist(img,'file') == 2
        img = imread(img);
    else
        error(sprintf('%s:Input',mfilename),'Input ''%s'' is not a valid filename',img);
    end
end
if size(img,3) > 1, img = rgb2gray(img); end
% 
% windowing
img = im2double(img);
wc  = window(@hamming,size(img,1));
wr  = window(@hamming,size(img,2));
[maskr,maskc] = meshgrid(wr,wc);
w   = maskr.*maskc;
img = im2double(img) .* w;
%
% compute fftshift fft2 and remove DC part and outer region
siz                = size(img);
amp                = abs(fftshift(fft2(img)));
dSize              = [10 10];
[tmp,ID]           = max(amp,[],1);
[~,JD]             = max(tmp);
ID                 = ID(JD);
if abs(siz(1)/2-ID) < dSize(1) && abs(siz(2)/2-JD) < dSize(2)
    dSize(1) = find(amp(ID:end,JD) < 0.1*amp(ID,JD),1,'first') + 1;
    dSize(2) = find(amp(ID,JD:end) < 0.1*amp(ID,JD),1,'first') + 1;
else
    pixres = NaN; rot = NaN;
    warning(sprintf('%s:Compute',mfilename),'Could not find DC part. Please check fftshifted fft2 result');
    return
end
idxDCI             = round((siz(1)/2-dSize(1)):(siz(1)/2+dSize(1)));
idxDCJ             = round((siz(2)/2-dSize(2)):(siz(2)/2+dSize(2)));
amp(idxDCI,idxDCJ) = min(amp(:));
amp([1:dSize(1) (siz(1)-dSize(1)):siz(1)],:) = min(amp(:));
amp(:,[1:dSize(2) (siz(2)-dSize(2)):siz(2)]) = min(amp(:));
%
% select 2 strongest maximum that should be symmetric around the center
[tmp,I1] = max(amp,[],1);
[~,J1]   = max(tmp);
I1       = I1(J1);
dSize(1) = find(amp(I1:end,J1) < 0.1*amp(I1,J1),1,'first') + 1;
dSize(2) = find(amp(I1,J1:end) < 0.1*amp(I1,J1),1,'first') + 1;
out      = amp;
amp(min(siz(1)*ones(1,2*dSize(1)+1),max(ones(1,2*dSize(1)+1),I1+(-dSize(1):dSize(1)))),...
    min(siz(2)*ones(1,2*dSize(2)+1),max(ones(1,2*dSize(2)+1),J1+(-dSize(2):dSize(2))))) = min(amp(:));
[tmp,I2] = max(amp,[],1);
[~,J2]   = max(tmp);
I2       = I2(J2);
%
% compute spatial frequency and rotation
pos     = [J1 I1; J2 I2];
pos     = Video.pixelLocalSubMaxima(amp,pos,2);
pixres  = hypot(((pos(1,2)-pos(2,2))./siz(1)/2), ((pos(1,1)-pos(2,1))./siz(2)/2))/density;
rot     = atan2(((pos(1,1)-pos(2,1))./siz(2)),   ((pos(1,2)-pos(2,2))./siz(1)));
% pixres  = hypot(((I1-I2)./siz(1)/2),((J1-J2)./siz(2)/2))/density;
% rot     = atan2(((J2-J1)./siz(2)),((I2-I1)./siz(1)));
end