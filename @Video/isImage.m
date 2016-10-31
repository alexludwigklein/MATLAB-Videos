function out = isImage(img)
% isImage Tests if img is an image

if (isnumeric(img) || islogical(img)) && ndims(img) <= 3 && ndims(img) >=2
    out = true;
else
    out = false;
end
end