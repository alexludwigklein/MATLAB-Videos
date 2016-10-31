function cdata = transform_SubtractBackground(cdata,bg,mode)
%transform_SubtractBackground Subtracts background image bg from input image cdata with given mode
% The function does not perform error checking for speed considerations

switch mode
    case 1
        cdata = imcomplement(imabsdiff(cdata,bg));
    case 2
        if ~isa(bg,'double'), bg = im2double(bg); end
        if ~isa(cdata,'double'), cdata = im2double(cdata); end
        cdata = imdivide(cdata,bg);
    otherwise
        error(sprintf('%s:Input',mfilename),'Unknown mode:%d',mode);
end
end