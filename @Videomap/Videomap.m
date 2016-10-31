classdef Videomap < matlab.mixin.Copyable
    %Videomap Stores the image data for the Video class in memory or maps a video file to memory
    %   The class takes care of mapping a single video file with user-defined subsref and subsasgn,
    %   such that the actual video data in the Video class can be accessed more naturally. It can
    %   also be used to store video data in memory, such that for both cases (all data read into
    %   memory or memory mapping a video file) the same syntax can be used: obj(:,:,:,:) is used to
    %   index into the image data (called cdata) of the video and obj.<prop> can be used to access
    %   public properties or a method.
    %
    %   For read, write and memory mapping support the video data (i.e. the data from a stacked tiff
    %   file or a MJ2, MP4 or AVI file supported by MATLAB's VideoReader class, called the source
    %   file SRC from hereon) is copied to a corresponding DAT file (raw binary data with a custom
    %   header), which means the data of the source file SRC is copied into a DAT file with the same
    %   basename but extension '.dat'. Additional information can be written to a MATLAB file MAT
    %   with extension '.mat' (see write2File and read2File). The DAT and MAT files are overwritten
    %   without warning, but the SRC file is always untouched. In case only read access is required,
    %   the SRC file can be directly memory mapped without the need to write a DAT file first.
    %
    %   Note: The indexing uses MATLAB's way to index arrays: Therefore, the first index is the y
    %   axis of the image and the second index is the x axis (e.g. obj(2,4,3,10) is x=4 y=2 z=3
    %   frame=10). This is different in the image methods, such as the crop method, where MATLAB's
    %   definition for images is used, confusing but in accordiance with MATLAB: Indexing follows
    %   general indexing for arrays and image functions may swap the first two dimensions.
    %
    %   Indexing with obj.<prop> can also be used to load additional data from the MAT file, that
    %   has been stored with the method write2File before. This allows to easily store small data
    %   related to the video in the MAT file.
    %
    %   Multiple TIF files: Some tools such as PCO CamWare store large data sets in multiple TIF
    %   files of 2GiB in size (avoiding BigTIFF) and name them <something>@0001.tif, etc.. The class
    %   supports to read those files as one data set by default when writing to a DAT file. It
    %   checks for TIF files ending with the format '@%0.d'.tif
    %
    %   The class allows for a custom transformation applied to any image returned by the object,
    %   have a look at the transform porperty.
    %
    % Implementation Notes:
    %  * Memory mapping is based on MATLAB's memmapfile for the DAT file, in case of TIF files the
    %    file exchange submission TIFFStack is used, for all video files (MJ2, MP4 and AVI) the
    %    VideoReader is used. In principle there are tools available on file exchange, such as
    %    HDF5PROP, to allow for memory mapping of HDF5 files.
    %  * Array of objects are not allowed to enable a custom subsref
    %  * Use 'obj(:,:,:,:)' to get all video data, since just 'obj' would return the handle object,
    %    but not just its data
    %  * Video data is stored as 4D array to support color video or any video with more than one
    %    slice per frame
    %  * DAT file format: the header stores the dimensions (nY, nX, nZ, nFrames), bits per pixel
    %    (nBits) and the memmap mode (memmap) as uint64 in that particular order leading to 48 bytes
    %    for the header. The actual data starts after 1024 bytes to allow for future extensions.
    %       1 to    8: nY
    %       9 to   16: nX
    %      17 to   24: nZ
    %      25 to   32: nFrames
    %      33 to   40: nBits
    %      41 to   48: memmap
    %      49 to 1024: padded with zeros
    %    1024 to  end: Image data
    %
    % Examples: see demo_Videomap.m
    %
    %----------------------------------------------------------------------------------
    %   Copyright 2016 Alexander Ludwig Klein, alexludwigklein@gmail.com
    %
    %   Physics of Fluids, University of Twente
    %----------------------------------------------------------------------------------
    
    %% Properties
    properties (GetAccess = public, SetAccess = public, Dependent = true)
        % filename Absolute basename of video data, i.e. without extension (string)
        filename
        % memmap The mode of memory mapping (double)
        %
        % 0 or false: no memory mapping at all, instead reading the complete SRC file into memory
        %  1 or true: full memory mapping with read and write access, requires to create a DAT file
        %          2: memory mapping with read-only access by a VideoReader, no DAT file is required
        %          3: memory mapping with read-only access by a TIFFStack, no DAT file is required
        %
        % Note: in case memmap is set to 2 but a tif file is only available, it will be changed to 3
        memmap
        % list2File Returns list of variables in MAT file (cellstr)
        list2File
        % cdata Image data (uint8, unit16, single or double (virtual or empty in case of memmory mapping))
        cdata
        % transform Function handle, geometric transformation object, etc. that is applied to the cdata (several dataypes allowed)
        %
        % The transformation is always applied to the data to recreate the situation as if it would
        % have been applied to the data stored on disk, currently supported are:
        % * empty value to disable any transform
        % * affine2d object
        % * cameraParameters object
        % * function handle that accepts a single image
        %
        % Note: This is not stored with videomap on disk (see video class that handles this)
        transform
    end
    
    properties (GetAccess = public, SetAccess = public, Transient = true)
        % lock Locks object to prevent any change to its data (logical)
        lock = false;
        % chunkSize Size in MiB that can be loaded in one go into memory (double)
        chunkSize = 1024;
    end
    
    properties (GetAccess = public, SetAccess = protected, Transient = true)
        % filenameSRC Absolute path to source file SRC (string)
        filenameSRC = '';
        % filenameDAT Absolute path to binary data file DAT (string)
        filenameDAT = '';
        % filenameMAT Absolute path to additional MATLAB file MAT (string)
        filenameMAT = '';
        % isChanged True/false whether video data is changed since object was created or saved the last time (logical)
        isChanged = false;
    end
    
    properties (GetAccess = public, SetAccess = protected, Dependent = true)
        % nX Number of pixel along x axis in image coordinate system (double)
        nX
        % nY Number of pixel along y axis in image coordinate system (double)
        nY
        % nZ Number of pixel along z axis in image coordinate system (double)
        nZ
        % nXDisk Number of pixel along x axis in image coordinate system on disk (double)
        nXDisk
        % nYDisk Number of pixel along y axis in image coordinate system on disk (double)
        nYDisk
        % nZDisk Number of pixel along z axis in image coordinate system on disk (double)
        nZDisk
        % nFrames Number of frames (double)
        nFrames
        % nBits Number of bits per pixel, i.e. 8 for uint8, 16 for uint16, 32 for single or 64 for double (double)
        nBits
        % class Class of image cdata, i.e. 'uint8', 'uint16', 'single' or 'double' (string)
        class
        % nBitsDisk Number of bits per pixel on disk, i.e. 8 for uint8, 16 for uint16, 32 for single or 64 for double (double)
        nBitsDisk
        % classDisk Class of image cdata on disk, i.e. 'uint8', 'uint16', 'single' or 'double' (string)
        classDisk
        % memory Estimate for the memory usage in MiB of the image data in memory (double)
        memory
        % memory Estimate for the memory usage in MiB of the image data on disk (double)
        memoryDisk
        % isLinked True/false whether video data is linked to a file, i.e. a file is kept open (logical)
        isLinked
    end
    
    properties (GetAccess = protected, SetAccess = protected, Transient = true)
        % p_nX Storage for nX
        p_nX = [];
        % p_nY Storage for nY
        p_nY = [];
        % p_nZ Storage for nZ
        p_nZ = [];
        % p_nXDisk Storage for nXDisk
        p_nXDisk = [];
        % p_nYDisk Storage for nYDisk
        p_nYDisk = [];
        % p_nZDisk Storage for nZDisk
        p_nZDisk = [];
        % p_nFrames Storage for nFrames
        p_nFrames = [];
        % p_nBits Storage for nBits
        p_nBits = [];
        % p_nBitsDisk Storage for nBitsDisk
        p_nBitsDisk = [];
        % p_memory Storage for memory
        p_memory = [];
        % p_memoryDisk Storage for memory
        p_memoryDisk = [];
        % p_class Storage for class
        p_class = [];
        % p_classDisk Storage for classDisk
        p_classDisk = [];
        % p_list2File Storage for list2File
        p_list2File = -1
        % p_cdata Storage for mmFile.Data.cdata field of memmapfile or actual image cdata (struct, uint8, uint16, single or double)
        p_cdata = NaN(2,2,1,1,'single');
        % p_transform Storage for transform
        p_transform = [];
        % p_memmap Storage for memmap
        p_memmap = [];
        % p_filename Storage for filename
        p_filename = '';
        % master A master object that is reset in case the Videomap object is reset
        %
        % The object notifies a master object by the event resetVideo, unless this property is set,
        % which will lead to the direct call of resetUpdate(obj.master)
        %
        master = [];
        % mmFile Storage for memmapfile or similar object in case of memory mapping (memmapfile, etc.)
        mmFile = [];
    end
    
    %% Events
    events
        % resetVideo Reset video object
        resetVideo
    end
    
    %% Constructor, SET/GET
    methods
        function obj   = Videomap(filename,varargin)
            %Videomap Class constructor accepting filename and optional input in <propertyname> <value> style
            % Filename to video file or an existing object that should be duplicated (ignores other
            % settings given to constructor), supply an empty value to get an object with default
            % properties (ignores other settings given to constructor)
            
            %
            % check input
            if nargin < 1
                filename = [];
            elseif ~(isempty(filename) || ischar(filename) || strcmp(class(filename),class(obj)))
                error(sprintf('%s:Input',mfilename),'Unknown input for filename');
            end
            % use input parser to process options
            opt               = inputParser;
            opt.StructExpand  = true;
            opt.KeepUnmatched = false;
            % memory mapping mode (overwrites setting in an existing DAT file), supply an empty
            % value to get default settings (changing the default to true here should enable memory
            % mapping by default)
            opt.addParameter('memmap', [], ...
                @(x) isempty(x) || ((islogical(x) || isnumeric(x)) && isscalar(x)));
            % true/false whether to ignore any existing DAT file and prefer to start from the source
            % file again
            opt.addParameter('ignoreDAT', false, ...
                @(x) islogical(x) && isscalar(x));
            % chunkSize Size in MiB that can be loaded in one go into memory
            opt.addParameter('chunkSize', 1024, ...
                @(x) isnumeric(x) && isscalar(x) && min(x)>0);
            % transform Transform property of object
            opt.addParameter('transform', [], ...
                @(x) isempty(x) || isa(x,'function_handle') || isa(x,'affine2d') || ...
                isa(x,'cameraParameters') || (iscell(x) && isa(x{1},'function_handle')));
            % true/false whether to ignore any existing DAT file and prefer to start from the source
            % file again
            opt.addParameter('master', [], ...
                @(x) isempty(x) || isa(x,'Video'));
            opt.parse(varargin{:});
            opt          = opt.Results;
            opt.filename = filename;
            if islogical(opt.memmap), opt.memmap = double(opt.memmap); end
            if ~isempty(opt.memmap) && ~(opt.memmap >= 0 && opt.memmap <= 3)
                error(sprintf('%s:Input',mfilename),...
                    'Unknown memory mapping mode ''%d'', please check!',opt.memmap);
            end
            % get structure/object and fieldnames/properties that can be copied to object
            if isempty(opt.filename)
                % return object with default values
            elseif ischar(opt.filename)
                % set filename for new object and recall from disk
                obj.filename  = opt.filename;
                obj.chunkSize = opt.chunkSize;
                obj.transform = opt.transform;
                recall(obj,'ignoreDAT',opt.ignoreDAT,'memmap',opt.memmap);
            elseif strcmp(class(opt.filename),class(obj))
                % copy input object
                obj = copy(opt.filename);
            else
                error(sprintf('%s:Input',mfilename),'Unknown input for class ''%s''',class(obj));
            end
            % set master object
            if ~isempty(opt.master), obj.master = opt.master; end
        end
        
        function         delete(obj)
            %delete Video class destructor
            
            % make sure we clear the copy by value of the memmapfile by first clearing the link to
            % the Data field and afterwards the memmapfile itself, see:
            % http://nl.mathworks.com/help/matlab/import_export/deleting-a-memory-map.html
            obj.p_cdata = [];
            obj.mmFile  = [];
        end
                
        function value = get.isLinked(obj)
            value = ~isempty(obj.mmFile) && ~iscell(obj.mmFile);
        end
        
        function value = isnan(obj)
            %isnan Test if object only contains NaN without memory mapping
            
            value = obj.memmap == 0 && all(isnan(obj.p_cdata(:)));
        end
        
        function value = get.transform(obj)
            value = obj.p_transform;
        end
        
        function         set.transform(obj,value)
            if isempty(value) || isa(value,'function_handle') || isa(value,'affine2d') || ...
                    isa(value,'cameraParameters') || (iscell(value) && isa(value{1},'function_handle'))
                if isequal(value,obj.p_transform), return; end
                obj.p_transform = value;
                resetUpdate(obj);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for transform');
            end
        end
        
        function value = get.filename(obj)
            value = obj.p_filename;
        end
        
        function         set.filename(obj,value)
            if ischar(value)
                if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
                % a basename without extension might be the input, where the basename contains a dot
                % '.', which leads to a wrong file extension. Therefore, check for any file with the
                % given basename ending with avi, mj2, mp4 or tif
                [fp,fn,fe] = fileparts(value);
                if strcmp(fe,'.mat')
                    % a mat file was given, the extension is removed to find the corresponding data
                    % file, i.e. a DAT, TIF, MJ2 or avi file
                    value = fullfile(fp,fn);
                    fe    = '';
                end
                if any(value=='.') && ~ismember(fe,{'.dat','.tif','.mj2','.avi','.mp4'})
                    if numel(dir([value '.dat'])) == 1
                        value      = [value '.dat'];
                        [fp,fn,fe] = fileparts(value);
                    elseif numel(dir([value '.tif'])) == 1
                        value      = [value '.tif'];
                        [fp,fn,fe] = fileparts(value);
                    elseif numel(dir([value '.mj2'])) == 1
                        value      = [value '.mj2'];
                        [fp,fn,fe] = fileparts(value);
                    elseif numel(dir([value '.avi'])) == 1
                        value      = [value '.avi'];
                        [fp,fn,fe] = fileparts(value);
                    elseif numel(dir([value '.mp4'])) == 1
                        value      = [value '.mp4'];
                        [fp,fn,fe] = fileparts(value);
                    else
                        fn = [fn fe];
                        fe = '';
                    end
                end
                % process input
                tmpBase    = fullpath(fullfile(fp,fn));
                tmpFull    = fullpath(fullfile(fp,[fn,     fe]));
                tmpDAT     = fullpath(fullfile(fp,[fn, '.dat']));
                tmpMAT     = fullpath(fullfile(fp,[fn, '.mat']));
                if ~strcmp(tmpBase,obj.p_filename)
                    % filename is new, but don't do anything in case object is not memory mapped
                    % (filename will be used next time the object is stored to disk or recalled), in
                    % case of memory mapping: unclear what to do: write cdata to new file or load
                    % existing file? Therefore, issue warning but don't change filename. User needs
                    % to make a new object after storing current data to file. This has been changed
                    % in order to allow to link to the same file at a different location. Therefore,
                    % in case of memory mapping a recall from the new position is performed
                    switch fe
                        case {'.avi','.mj2','.mp4','.tif'}
                            % file must already exist since this class does not create a TIF, MJ2,
                            % MP4 or AVI file, in case it does not exist look for a DAT file (maybe
                            % the tif was deleted to save disk space), in which case a warning is
                            % issued. Also check any other supported file extension if a file with
                            % the same basename is found.
                            if exist(tmpFull,'file') == 2 && numel(dir(tmpFull)) == 1
                                tmpSRC = tmpFull;
                            else
                                strFE   = {'.dat' '.tif' '.mj2' '.mp4' '.avi'};
                                tmpFile = cell(size(strFE));
                                for i = 1:numel(strFE)
                                    tmpFile{i} = dir(fullpath(fullfile(fp,[fn, strFE{i}])));
                                    if numel(tmpFile{i}) ~= 1, tmpFile{i} = []; end
                                end
                                idxOK  = ~cellfun('isempty',tmpFile);
                                idxAbs = find(idxOK, 1);
                                if sum(idxOK) > 1
                                    warning(sprintf('%s:Input',mfilename),...
                                        ['For file ''%s'' no exact match for the source is found but %d possible sources, which is ambiguous, ',...
                                        'but the ''%s'' file is preferred in this case for object of class ''%s'''],...
                                        tmpFull,sum(idxOK),strFE{idxAbs},class(obj)); %#ok<*CPROPLC>
                                    tmpSRC = tmpFile{idxAbs}.name;
                                elseif sum(idxOK) < 1
                                    error(sprintf('%s:Input',mfilename),...
                                        ['Source file ''%s'' (or any AVI, MJ2, MP4, TIF or DAT file with the same basename) is not found. ',...
                                        'Please provide a DAT file in case current object data should be stored on disk. ',...
                                        'Provide an existing TIF, MJ2, MP4 or AVI file in case data should be read from a source file.'],tmpFull);
                                else
                                    warning(sprintf('%s:Input',mfilename), ['Source file ''%s'' is not found, ',...
                                        'but a file with extension ''%s'' and the same basename'], tmpFull, strFE{idxAbs});
                                    tmpSRC = tmpFile{idxAbs}.name;
                                end
                                % create fullpath for source file
                                tmpSRC = fullpath(fullfile(fp,tmpSRC));
                            end
                        case {'.dat', ''}
                            % try to find a TIF, MJ2, MP4 or AVI with the same basename, which will
                            % act as source file. If no SRC file is available the DAT file will be
                            % the source. It does not need to exist, since it can be created next
                            % time the data is stored.
                            strFE   = {'.tif' '.mj2' '.mp4' '.avi'};
                            tmpFile = cell(size(strFE));
                            for i = 1:numel(strFE)
                                tmpFile{i} = dir(fullpath(fullfile(fp,[fn, strFE{i}])));
                                if numel(tmpFile{i}) ~= 1, tmpFile{i} = []; end
                            end
                            idxOK  = ~cellfun('isempty',tmpFile);
                            idxAbs = find(idxOK, 1);
                            if sum(idxOK) > 1
                                warning(sprintf('%s:Input',mfilename),...
                                    ['For file ''%s'' %d possible sources are found, which is ambiguous, ',...
                                    'but the ''%s'' file is preferred in this case for object of class ''%s'''],...
                                    tmpFull,sum(idxOK),strFE{idxAbs},class(obj)); %#ok<*CPROPLC>
                                tmpSRC = tmpFile{idxAbs}.name;
                            elseif sum(idxOK) < 1
                                tmpSRC = tmpDAT;
                            else
                                tmpSRC = tmpFile{idxAbs}.name;
                            end
                            % create fullpath for source file
                            tmpSRC = fullpath(fullfile(fp,tmpSRC));
                        otherwise
                            error(sprintf('%s:Input',mfilename),['File extension of input ''%s'' not ',...
                                'supported by class ''%s'''],tmpFull,class(obj));
                    end
                    if obj.memmap > 0
                        % Option 1: issue warning
                        % error(sprintf('%s:Input',mfilename),...
                        %     ['File ''%s'' is memory mapped and changing the filename is not supported for memory mapped objects of class ''%s''. ',...
                        %     'Please, create a new object that links to the new file.'],obj.filename,class(obj));
                        % Option 2: recall from an existing file
                        if     obj.memmap == 1,          checkFile = tmpDat;
                        elseif any(obj.memmap == [2 3]), checkFile = tmpSRC;
                        else
                            error(sprintf('%s:Input',mfilename),...
                                'Unknown memory mapping mode ''%d'', please check!',obj.memmap);
                        end
                        if exist(checkFile,'file') && numel(dir(checkFile)) == 1
                            obj.p_filename  = tmpBase;
                            obj.filenameDAT = tmpDAT;
                            obj.filenameMAT = tmpMAT;
                            obj.filenameSRC = tmpSRC;
                            recall(obj);
                        else
                            error(sprintf('%s:Input',mfilename),...
                                ['File ''%s'' for memory mapping is not found or is not unique. Please, make ',...
                                'sure the file exists in order to link a memory mapped video to a new file.'], checkFile);
                        end
                    else
                        obj.p_filename  = tmpBase;
                        obj.filenameDAT = tmpDAT;
                        obj.filenameMAT = tmpMAT;
                        obj.filenameSRC = tmpSRC;
                    end
                end
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for filename');
            end
        end
        
        function value = get.memmap(obj)
            if isempty(obj.p_memmap)
                if isempty(obj.mmFile) && ~isempty(obj.p_cdata)
                    obj.p_memmap = 0;
                elseif iscell(obj.mmFile)
                    % file was unlinked and memmap state is stored in cell
                    obj.p_memmap = obj.mmFile{1};
                elseif isa(obj.mmFile,'memmapfile')
                    obj.p_memmap = 1;
                elseif isa(obj.mmFile,'VideoReader')
                    obj.p_memmap = 2;
                elseif isa(obj.mmFile,'TIFFStack')
                    obj.p_memmap = 3;
                else
                    error(sprintf('%s:Input',mfilename),...
                        'Unknown memory mapping mode, please check!');
                end
            end
            value = obj.p_memmap;
        end
        
        function         set.memmap(obj,value)
            if (islogical(value) || isnumeric(value)) && isscalar(value)
                if islogical(value), value = double(value); end
                if value ~= obj.memmap
                    if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
                    % switch memory mapping by storing and recalling data for a forced memmap
                    store(obj);
                    recall(obj,'ignoreDAT',false,'memmap',value);
                end
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for memmap');
            end
        end
        
        function value = get.cdata(obj)
            if obj.memmap > 0 && obj.memoryDisk > obj.chunkSize
                warning(sprintf('%s:Input',mfilename),...
                    'Reading all image data of %.2f MiB from file ''%s'' into memory',...
                    obj.memoryDisk,obj.filename);
            end
            link(obj);
            switch obj.memmap
                case 0
                    value = Videomap.applyTransform(obj.p_cdata(:,:,:,:),obj.p_transform);
                case 1
                    value = Videomap.applyTransform(obj.p_cdata(:,:,:,:),obj.p_transform);
                case 2
                    obj.mmFile.CurrentTime = 0;
                    value                  = readFrame(obj.mmFile);
                    value                  = repmat(value,[1 1 1 obj.p_nFrames]);
                    for n = 2:obj.p_nFrames
                        obj.mmFile.CurrentTime = (n-1)/obj.mmFile.Framerate;
                        value(:,:,:,n)         = readFrame(obj.mmFile);
                    end
                    value = Videomap.applyTransform(value,obj.transform);
                case 3
                    value = Videomap.applyTransform(permute(obj.mmFile(:,:,:,:),[1 2 4 3]),obj.transform);
                otherwise
                    error(sprintf('%s:Input',mfilename),...
                        'Unknown memory mapping mode ''%d'', please check!',obj.memmap);
            end
        end
        
        function         set.cdata(obj,value)
            if obj.memmap == 0
                if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
                if ~(~isempty(value) && isnumeric(value) && (isa(value,'uint8') || isa(value,'uint16') || ...
                        isa(value,'single') || isa(value,'double')) && (ndims(value) >= 2 && ndims(value) <= 4))
                    error(sprintf('%s:Input',mfilename),'Input not valid for cdata');
                elseif ~isa(value,obj.classDisk)
                    % accept new class without warning
                    % warning(sprintf('%s:Input',mfilename), ...
                    %     ['Input for cdata is of class ''%s'', but ''%s'' is expected ... ',...
                    %     'the class of the videomap will be changed to the new class ''%s'''],...
                    %     class(value),obj.classDisk,class(value));
                    obj.p_cdata   = value;
                    obj.isChanged = true;
                    resetUpdate(obj);
                elseif ~isequal(value,obj.p_cdata)
                    obj.p_cdata   = value;
                    obj.isChanged = true;
                    resetUpdate(obj);
                end
            else
                error(sprintf('%s:Input',mfilename),'Setting the complete image data is only possible if memory mapping is disabled');
            end
        end
        
        function         set.chunkSize(obj,value)
            if isnumeric(value) && isscalar(value) && min(value) > 0
                if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end %#ok<MCSUP>
                obj.chunkSize = value;
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for chunkSize');
            end
        end
        
        function         set.lock(obj,value)
            if islogical(value) && isscalar(value)
                obj.lock = value;
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for lock');
            end
        end
        
        function value = get.list2File(obj)
            if isempty(obj.p_list2File) && isnumeric(obj.p_list2File)
                [~, ~, obj.p_list2File] = obj.isMyMAT(obj.filenameMAT);
            end
            value = obj.p_list2File;
        end
        
        function value = get.nX(obj)
            if isempty(obj.p_nX)
                % query obj.nBits that sets multiple properties
                obj.nBits;
            end
            value = obj.p_nX;
        end
        
        function value = get.nY(obj)
            if isempty(obj.p_nY)
                % query obj.nBits that sets multiple properties
                obj.nBits;
            end
            value = obj.p_nY;
        end
        
        function value = get.nZ(obj)
            if isempty(obj.p_nZ)
                % query obj.nBits that sets multiple properties
                obj.nBits;
            end
            value = obj.p_nZ;
        end
        
        function value = get.nXDisk(obj)
            if isempty(obj.p_nXDisk)
                % query obj.nBits that sets multiple properties
                obj.nBits;
            end
            value = obj.p_nXDisk;
        end
        
        function value = get.nYDisk(obj)
            if isempty(obj.p_nYDisk)
                % query obj.nBits that sets multiple properties
                obj.nBits;
            end
            value = obj.p_nYDisk;
        end
        
        function value = get.nZDisk(obj)
            if isempty(obj.p_nZDisk)
                % query obj.nBits that sets multiple properties
                obj.nBits;
            end
            value = obj.p_nZDisk;
        end
        
        function value = get.classDisk(obj)
            if isempty(obj.p_classDisk)
                % query obj.nBits that sets multiple properties
                obj.nBits;
            end
            value = obj.p_classDisk;
        end
        
        function value = get.nFrames(obj)
            if isempty(obj.p_nFrames)
                % query obj.nBits that sets multiple properties
                obj.nBits;
            end
            value = obj.p_nFrames;
        end
        
        function value = get.nBits(obj)
            if isempty(obj.p_nBits) || isempty(obj.p_nFrames) || isempty(obj.p_nX) || ...
                    isempty(obj.p_nY) || isempty(obj.p_nZ) || isempty(obj.p_class) || ...
                    isempty(obj.p_nBitsDisk) || isempty(obj.p_classDisk) || ...
                    isempty(obj.p_nYDisk) || isempty(obj.p_nZDisk) || isempty(obj.p_nXDisk)
                link(obj);
                % get an example image as stored on disk and how it is mapped in MATLAB
                switch obj.memmap
                    case 0
                        obj.p_nFrames = size(obj.p_cdata,4);
                        imgDisk       = obj.p_cdata(:,:,:,1);
                    case 1
                        obj.p_nFrames = size(obj.mmFile.Data.cdata,4);
                        imgDisk       = obj.p_cdata(:,:,:,1);
                    case 2
                        obj.mmFile.CurrentTime = 0;
                        obj.p_nFrames = floor(obj.mmFile.Duration*obj.mmFile.FrameRate);
                        imgDisk       = readFrame(obj.mmFile);
                    case 3
                        obj.p_nFrames = size(obj.mmFile,3);
                        imgDisk       = squeeze(obj.mmFile(:,:,1,:));
                    otherwise
                        error(sprintf('%s:Input',mfilename),...
                            'Unknown memory mapping mode ''%d'', please check!',obj.memmap);
                end
                imgMem = Videomap.applyTransform(imgDisk,obj.transform);
                % get properties of images
                if     isa(imgMem,'uint8'),  obj.p_nBits = 8;
                elseif isa(imgMem,'uint16'), obj.p_nBits = 16;
                elseif isa(imgMem,'single'), obj.p_nBits = 32;
                elseif isa(imgMem,'double'), obj.p_nBits = 64;
                else,  error(sprintf('%s:Input',mfilename),['Unknown class ''%s'' for cdata in ',...
                        'object of class ''%s'''],class(imgMem),class(obj)); %#ok<*CPROP>
                end
                if     isa(imgDisk,'uint8'),  obj.p_nBitsDisk = 8;
                elseif isa(imgDisk,'uint16'), obj.p_nBitsDisk = 16;
                elseif isa(imgDisk,'single'), obj.p_nBitsDisk = 32;
                elseif isa(imgDisk,'double'), obj.p_nBitsDisk = 64;
                else,  error(sprintf('%s:Input',mfilename),['Unknown class ''%s'' for cdata in ',...
                        'object of class ''%s'''],class(imgDisk),class(obj)); %#ok<*CPROP>
                end
                obj.p_nY        = size(imgMem,1);
                obj.p_nX        = size(imgMem,2);
                obj.p_nZ        = size(imgMem,3);
                obj.p_class     = class(imgMem);
                obj.p_nYDisk    = size(imgDisk,1);
                obj.p_nXDisk    = size(imgDisk,2);
                obj.p_nZDisk    = size(imgDisk,3);
                obj.p_classDisk = class(imgDisk);
            end
            value = obj.p_nBits;
        end
        
        function value = get.nBitsDisk(obj)
            if isempty(obj.p_nBitsDisk)
                % query obj.nBits that sets multiple properties
                obj.nBits;
            end
            value = obj.p_nBitsDisk;
        end
        
        function value = get.memory(obj)
            if isempty(obj.p_memory)
                % estimate number of bytes in object
                if obj.memmap > 0, obj.p_memory = 0;
                else,              obj.p_memory = obj.memoryDisk;
                end
            end
            value = obj.p_memory;
        end
        
        function value = get.memoryDisk(obj)
            if isempty(obj.p_memoryDisk)
                obj.p_memoryDisk = obj.nXDisk * obj.nYDisk * obj.nZDisk * obj.nFrames * obj.nBitsDisk / 8 / 1024^2;
            end
            value = obj.p_memoryDisk;
        end
        
        function value = get.class(obj)
            if isempty(obj.p_class)
                obj.nBits;
            end
            value = obj.p_class;
        end
    end
    
    %% Methods for indexing/assignment and access control
    methods (Access = public, Hidden = false, Sealed = true)
        function siz       = size(obj,dim)
            %size Returns size of cdata
            
            siz = [obj.nY obj.nX obj.nZ obj.nFrames];
            if nargin > 1
                if dim > numel(siz), siz = 1;
                else,                siz = siz(dim);
                end
            end
        end
        
        function out       = numArgumentsFromSubscript(obj,S,ctext) %#ok<INUSD>
            % numArgumentsFromSubscript Returns number of output arguments
            
            out = 1;
        end
        
        function out       = end(obj, k, ~)
            %end Overloads built-in function end function
            
            switch k
                case 1, out = obj.nY;
                case 2, out = obj.nX;
                case 3, out = obj.nZ;
                case 4, out = obj.nFrames;
                otherwise
                    error(sprintf('%s:Indexing',mfilename), ...
                        'Type of indexing is not supported for object of class ''%s''', class(obj));
            end
        end
        
        function varargout = subsref(obj, S)
            %subsref Redefines subscripted reference for object
            
            if numel(obj) > 1
                error(sprintf('%s:Indexing',mfilename), ...
                    'Array of objects are not supported for the class ''%s''', class(obj(1)));
            end
            switch S(1).type
                case '.'
                    % return property or run method, if public
                    if hIsPublicGetProperty(obj, S(1).subs) || hIsPublicMethod(obj, S(1).subs)
                        % fprintf('%s: ',S(1).subs);t1=tic;
                        [varargout{1:nargout}] = builtin('subsref', obj, S);
                        % fprintf('%e s\n',toc(t1));
                    else
                        % try to read data from MAT file that was added with write2File
                        if ismember(S(1).subs,obj.list2File)
                            if numel(S) > 1
                                error(sprintf('%s:Indexing',mfilename), ...
                                    '''%s'' is a variable in the MAT file ''%s'', for which deep indexing is not supported for object of class ''%s''',...
                                    S(1).subs, obj.filenameMAT, class(obj));
                            else
                                tmp                    = obj.read2File(S(1).subs);
                                [varargout{1:nargout}] = tmp.(S(1).subs);
                            end
                        else
                            error(sprintf('%s:Indexing',mfilename), ...
                                '''%s'' is neither a public property of the class ''%s'' nor does it exist in the MAT file ''%s''',...
                                S(1).subs, class(obj), obj.filenameMAT);
                        end
                    end
                case '()'
                    % access cdata
                    if ~isscalar(S) || numel(S.subs) > 4
                        error(sprintf('%s:Indexing',mfilename), ...
                            'Type of indexing is not supported for object of class ''%s''', class(obj));
                    elseif ~isempty(obj.transform) && (...
                            (obj.nFrames > 1 && numel(S.subs) ~= 4) || ...
                            (obj.nFrames == 1 && obj.nZ == 1 && numel(S.subs) < 2) || ...
                            (obj.nFrames == 1 && obj.nZ > 1 && numel(S.subs) < 3))
                        error(sprintf('%s:Input',mfilename),['File ''%s'' is using a transformation, please provide indexing for '...
                            'every dimension (no logical or linear indexing), i.e. 4 indices for a video with multiple frames'],obj.filename);
                    elseif any(obj.memmap == [2 3]) && (...
                            (obj.nFrames > 1 && numel(S.subs) ~= 4) || ...
                            (obj.nFrames == 1 && obj.nZ == 1 && numel(S.subs) < 2) || ...
                            (obj.nFrames == 1 && obj.nZ > 1 && numel(S.subs) < 3))
                        error(sprintf('%s:Input',mfilename),['File ''%s'' is memory mapped an requires indexing for '...
                            'every dimension (no logical or linear indexing), i.e. 4 indices for width, height, depth and frame number'],obj.filename);
                    end
                    link(obj);
                    if isempty(obj.transform)
                        switch obj.memmap
                            case 0
                                [varargout{1:nargout}] = builtin('subsref', obj.p_cdata, S);
                            case 1
                                % redirect subsref to cdata (works for memmapfile object or actual numerical array)
                                % [varargout{1:nargout}] = builtin('subsref', obj.p_cdata, S);
                                % [varargout{1:nargout}] = subsref(obj.p_cdata, S);
                                % [varargout{1:nargout}] = subsref(obj.mmFile.Data.cdata, S);
                                % [varargout{1:nargout}] = obj.p_cdata(S.subs{:});
                                % [varargout{1:nargout}] = builtin('subsref', obj.p_cdata, S);
                                [varargout{1:nargout}] = builtin('subsref', obj.p_cdata, S);
                            case 2
                                % extend to all dimensions
                                if numel(S.subs) < 3, S.subs{3} = 1; end
                                if numel(S.subs) < 4, S.subs{4} = 1; end
                                if ischar(S.subs{4})
                                    switch S.subs{4}
                                        case ':'
                                            idxFrames = 1:obj.nFrames;
                                        otherwise
                                            error(sprintf('%s:Indexing',mfilename), ...
                                                'Type of indexing is not supported for object of class ''%s''', class(obj));
                                    end
                                else
                                    idxFrames = S.subs{4};
                                end
                                if numel(idxFrames)/obj.nFrames * obj.memoryDisk > obj.chunkSize
                                    warning(sprintf('%s:Input',mfilename),...
                                        'Reading image data of approximately %.2f MiB in file ''%s'' into memory',...
                                        numel(idxFrames)/obj.nFrames * obj.memoryDisk,obj.filename);
                                end
                                % get all frames as one block, and apply index again
                                vidTime                = (idxFrames-1)/obj.mmFile.Framerate;
                                obj.mmFile.CurrentTime = vidTime(1);
                                data                   = readFrame(obj.mmFile);
                                data                   = repmat(data,[1 1 1 numel(idxFrames)]);
                                for n = 2:numel(idxFrames)
                                    obj.mmFile.CurrentTime = vidTime(n);
                                    data(:,:,:,n)          = readFrame(obj.mmFile);
                                end
                                S.subs{4}              = 1:size(data,4);
                                [varargout{1:nargout}] = data(S.subs{:});
                            case 3
                                S.subs = S.subs([1 2 4 3]);
                                [varargout{1:nargout}] = permute(builtin('subsref', obj.mmFile, S),[1 2 4 3]);
                            otherwise
                                error(sprintf('%s:Input',mfilename),...
                                    'Unknown memory mapping mode ''%d'', please check!',obj.memmap);
                        end
                    else
                        % extend to all dimensions
                        if numel(S.subs) < 3, S.subs{3} = 1; end
                        if numel(S.subs) < 4, S.subs{4} = 1; end
                        if ischar(S.subs{4})
                            switch S.subs{4}
                                case ':'
                                    idxFrames = 1:obj.nFrames;
                                otherwise
                                    error(sprintf('%s:Indexing',mfilename), ...
                                        'Type of indexing is not supported for object of class ''%s''', class(obj));
                            end
                        else
                            idxFrames = S.subs{4};
                        end
                        if numel(idxFrames)/obj.nFrames * obj.memoryDisk > obj.chunkSize
                            warning(sprintf('%s:Input',mfilename),...
                                'Reading image data of approximately %.2f MiB in file ''%s'' into memory',...
                                numel(idxFrames)/obj.nFrames * obj.memoryDisk,obj.filename);
                        end
                        % get all frames as one block and apply data
                        switch obj.memmap
                            case 0
                                data = Videomap.applyTransform(obj.p_cdata(:,:,:,idxFrames),obj.transform);
                            case 1
                                data = Videomap.applyTransform(obj.p_cdata(:,:,:,idxFrames),obj.transform);
                            case 2
                                vidTime                = (idxFrames-1)/obj.mmFile.Framerate;
                                obj.mmFile.CurrentTime = vidTime(1);
                                data                   = readFrame(obj.mmFile);
                                data                   = repmat(data,[1 1 1 numel(idxFrames)]);
                                for n = 2:numel(idxFrames)
                                    obj.mmFile.CurrentTime = vidTime(n);
                                    data(:,:,:,n)          = readFrame(obj.mmFile);
                                end
                                data = Videomap.applyTransform(data,obj.transform);
                            case 3
                                data = permute(obj.mmFile(:,:,idxFrames,:),[1 2 4 3]);
                                data = Videomap.applyTransform(data,obj.transform);
                            otherwise
                                error(sprintf('%s:Input',mfilename),...
                                    'Unknown memory mapping mode ''%d'', please check!',obj.memmap);
                        end
                        %  apply indexing to transformed data
                        S.subs{4}              = 1:size(data,4);
                        [varargout{1:nargout}] = data(S.subs{:});
                    end
                case '{}'
                    error(sprintf('%s:Indexing',mfilename), ...
                        'Type of indexing ''{}'' is not supported for object of class ''%s''', class(obj));
                otherwise
                    error(sprintf('%s:Indexing',mfilename), ...
                        'Type of indexing is not supported for object of class ''%s''', class(obj));
            end
        end
        
        function obj       = subsasgn(obj, S, B)
            %subsasgn Redefines subscripted assignment for object
            
            if numel(obj) > 1
                error(sprintf('%s:Indexing',mfilename), ...
                    'Array of objects are not supported for the class ''%s''', class(obj(1)));
            end
            switch S(1).type
                case '.'
                    if obj.lock && strcmp(S(1).subs,'lock')
                        obj = builtin('subsasgn', obj, S, B);
                    elseif obj.lock
                        error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);
                    elseif hIsPublicSetProperty(obj, S(1).subs)
                        obj = builtin('subsasgn', obj, S, B);
                    elseif strcmp(S(1).subs,'master') && (isa(B,'Video') || isempty(B))
                        % allow to set the master without further checking
                        obj.master = B;
                    else
                        % allow change if property already exists in the MAT file
                        if ismember(S(1).subs,obj.list2File)
                            if numel(S) > 1
                                error(sprintf('%s:Indexing',mfilename), ...
                                    '''%s'' is a variable in the MAT file ''%s'', for which deep assignment is not supported for object of class ''%s''',...
                                    S(1).subs, obj.filenameMAT, class(obj));
                            else
                                write2File(obj,false,S(1).subs, B);
                            end
                        else
                            error(sprintf('%s:Indexing',mfilename), ...
                                '''%s'' is neither a public property of the class ''%s'' nor does it exist in the MAT file ''%s''',...
                                S(1).subs, class(obj),obj.filenameMAT);
                        end
                    end
                case '()'
                    if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
                    if obj.memmap > 1
                        error(sprintf('%s:Input',mfilename),['File ''%s'' is memory mapped in read-only mode, ',...
                            'write access in combination with memory mapping is only supported for DAT files'],obj.filename);
                    end
                    if ~isempty(obj.transform)
                        error(sprintf('%s:Input',mfilename),['File ''%s'' is using a transformation, please disable before assigning data, '...
                            'since it can be rather confusing (in principle it can be done but is disabled for safety)'],obj.filename);
                    end
                    % check input
                    if ~isa(B,obj.classDisk)
                        warning(sprintf('%s:Indexing',mfilename),['Input for cdata is of class ''%s'', ',...
                            'but ''%s'' is expected ... converting with im2%s'],class(B),obj.classDisk,obj.class);
                        try
                            switch obj.classDisk
                                case 'uint8',  B = im2uint8(B);
                                case 'uint16', B = im2uint16(B);
                                case 'single', B = im2single(B);
                                case 'double', B = im2double(B);
                                otherwise
                                    error(sprintf('%s:Indexing',mfilename),['cdata is of class ''%s'', ',...
                                        'which should not be possible for object of class ''%s'''],obj.classDisk,class(obj));
                            end
                        catch err
                            error(sprintf('%s:Indexing',mfilename),['Input for cdata is of class ''%s'', ',...
                                'but ''%s'' is expected, conversion failed: %s'],class(B),obj.classDisk,err.getReport);
                        end
                    end
                    % set data
                    link(obj);
                    if obj.memmap == 1
                        % redirect subsref to memmapfile object, but delete link to data first,
                        % re-linking is done here to get rid of the get method (slows down)
                        obj.p_cdata = [];
                        S           = [substruct('.','mmFile','.','Data','.','cdata') S];
                        obj         = builtin('subsasgn', obj, S, B);
                        obj.p_cdata = obj.mmFile.Data.cdata;
                        % full reset by resetUpdate should not be required since size of memmapfile
                        % cannot be changed here
                    else
                        tmp = size(obj.p_cdata);
                        % redirect subsref to p_cdata property
                        % option 1:
                        S   = [substruct('.','p_cdata') S];
                        obj = builtin('subsasgn', obj, S, B);
                        % option 2:
                        % obj.p_cdata = builtin('subsasgn', obj.p_cdata, S, B);
                        % option 3:
                        % S = [substruct('.','p_cdata') S];
                        % if numel(S) == 2 && strcmp(S(2).type,'()')
                        %     obj.p_cdata(S(2).subs{:}) = B;
                        % else
                        %     obj = builtin('subsasgn', obj, S, B);
                        % end
                        % reset fully only if size of cdata was changed
                        if numel(tmp) ~= ndims(obj.p_cdata) || any(abs(tmp-size(obj.p_cdata)) > eps)
                            resetUpdate(obj);
                        end
                    end
                    obj.isChanged = true;
                case '{}'
                    error(sprintf('%s:Indexing',mfilename), ['Type of assignment ''{}'' is not ',...
                        'supported for object of class ''%s'''], class(obj));
                otherwise
                    error(sprintf('%s:Indexing',mfilename), ['Type of assignment is not supported ',...
                        'for object of class ''%s'''], class(obj));
            end
        end
    end
    
    methods (Access = protected, Hidden = false, Sealed = true)
        function out = hIsPublicGetProperty(obj, in)
            %hIsPublicGetProperty Determines if input string is the name of a public get property, case-sensitively.
            persistent publicProperties;
            if isempty(publicProperties)
                mc   = metaclass(obj(1));
                prop = [mc.Properties{:}];
                idx  = arrayfun(@(x) ischar(x.GetAccess) && strcmp(x.GetAccess,'public'),prop);
                publicProperties = {prop(idx).Name};
            end
            out = ismember(in, publicProperties);
        end
        
        function out = hIsPublicSetProperty(obj, in)
            %hIsPublicSetProperty Determines if input string is the name of a public set property, case-sensitively.
            persistent publicProperties;
            if isempty(publicProperties)
                mc   = metaclass(obj(1));
                prop = [mc.Properties{:}];
                idx  = arrayfun(@(x) ischar(x.SetAccess) && strcmp(x.SetAccess,'public'),prop);
                publicProperties = {prop(idx).Name};
            end
            out = ismember(in, publicProperties);
        end
        
        function out = hIsPublicMethod(obj, in)
            %hIsPublicMethod Determines if input string is the name of a public method, case-sensitively.
            persistent publicMethod ;
            if isempty(publicMethod)
                mc   = metaclass(obj(1));
                meth = [mc.MethodList];
                idx  = arrayfun(@(x) ischar(x.Access) && strcmp(x.Access,'public'),meth);
                publicMethod = {meth(idx).Name};
            end
            out = ismember(in, publicMethod);
        end
    end
    
    %% Methods for various class related tasks
    methods (Access = public, Hidden = false)
        function             disp(obj)
            %disp Displays object on command line
            
            
            newLineChar = char(10);
            spacing     = '     ';
            if isempty(obj)
                tmp = sprintf('%sEmpty object of class ''%s''',spacing,class(obj));
            else
                str1        = sprintf('%s object [nY nX nZ nFrames] = [%d %d %d %d] ',...
                    class(obj),obj.nY,obj.nX,obj.nZ,obj.nFrames);
                if isempty(obj.transform)
                    str2 = sprintf('(%s, no transform) ',obj.class);
                else
                    str2 = sprintf('(%s, with transform) ',obj.class);
                end
                if obj.memmap > 0
                    str3 = sprintf('using %.2f MiB (memory mapping (%d) enabled for %.2f MiB on disk)',...
                        obj.memory, obj.memmap, obj.memoryDisk);
                else
                    str3 = sprintf('using %.2f MiB (memory mapping (%d) disabled)',obj.memory, obj.memmap);
                end
                tmp = strrep([spacing, str1, str2, str3], newLineChar, [newLineChar, spacing]);
            end
            disp(tmp);
            if ~isequal(get(0,'FormatSpacing'),'compact')
                disp(' ');
            end
        end
        
        function             link(obj)
            %link Makes sure the link to the file in case of memory mapping is active, i.e. the file is open

            if obj.memmap == 0 || obj.isLinked
                % no memory mapping and, therefore, no file to open available, or already linked
                return;
            elseif obj.memmap == 1
                [~,~,data]  = obj.isMyDAT(obj.filenameDAT);
                obj.p_cdata = [];
                obj.mmFile  = memmapfile(obj.mmFile{2},'Writable',true,'Repeat',1,'Offset',1024, ...
                    'Format',{data.class,[data.nY data.nX data.nZ data.nFrames],'cdata'});
                obj.p_cdata = obj.mmFile.Data.cdata;
            elseif obj.memmap == 2
                obj.mmFile = VideoReader(obj.mmFile{2});
            elseif obj.memmap == 3
                obj.mmFile = TIFFStack(obj.mmFile{2});
            else
                error(sprintf('%s:Input',mfilename),...
                    'Unknown memory mapping mode ''%d'', please check!',obj.memmap);
            end
        end
        
        function             unlink(obj)
            %unlink Makes sure the link to the file in case of memory mapping is closed to minimize the open file count
            
            if obj.memmap == 0 || ~obj.isLinked
                % no memory mapping and, therefore, no file to close available or already unlinked
                return;
            elseif obj.memmap == 1
                obj.p_cdata = [];
                obj.mmFile  = {1 obj.mmFile.Filename};
            elseif obj.memmap == 2
                obj.mmFile = {2 fullfile(obj.mmFile.Path,obj.mmFile.Name)};
            elseif obj.memmap == 3
                obj.mmFile = {3 getFilename(obj.mmFile)};
            else
                error(sprintf('%s:Input',mfilename),...
                    'Unknown memory mapping mode ''%d'', please check!',obj.memmap);
            end
        end
        
        function 	         recall(obj,varargin)
            %recall Recalls video object from disk into memory or creates memory map
            % Optional input is processed with input parser
            
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            %
            % use input parser to process options
            opt               = inputParser;
            opt.StructExpand  = true;
            opt.KeepUnmatched = false;
            % the mode of memory mapping (see below), this setting overwrites any setting in an
            % existing DAT file, supply an empty value to get default settings, i.e. memory mapped
            %
            % 0 or false: no memory mapping at all, instead reading the complete SRC file into memory
            %  1 or true: full memory mapping with read and write access, requires to create a DAT file
            %          2: memory mapping with read-only access by a VideoReader, no DAT file is required
            %          3: memory mapping with read-only access by a TIFFStack, no DAT file is required
            opt.addParameter('memmap', [], ...
                @(x) isempty(x) || ((islogical(x) || isnumeric(x)) && isscalar(x)));
            % true/false whether to ignore any existing DAT file and prefer to start from the source
            % file again
            opt.addParameter('ignoreDAT', false, ...
                @(x) islogical(x) && isscalar(x));
            % maximum file size to load from disk into memory in MiB
            opt.addParameter('maxSize', 4 * 1024, ...
                @(x) isnumeric(x) && isscalar(x));
            opt.parse(varargin{:});
            opt = opt.Results;
            if islogical(opt.memmap), opt.memmap = double(opt.memmap); end
            if isempty(opt.ignoreDAT), opt.ignoreDAT = false; end
            if ~isempty(opt.memmap) && ~(opt.memmap >= 0 && opt.memmap <= 3)
                error(sprintf('%s:Input',mfilename),...
                    'Unknown memory mapping mode ''%d'', please check!',opt.memmap);
            end
            %
            % determine what to recall
            [~,~,fe] = fileparts(obj.filenameSRC);
            if isempty(obj.filename)
                warning(sprintf('%s:Input',mfilename),...
                    'Filename is not set for object of class ''%s'', no data recalled from disk',class(obj));
                return;
            elseif opt.ignoreDAT && ~strcmp(fe,'.dat') && exist(obj.filenameSRC,'file') == 2 && numel(dir(obj.filenameSRC)) == 1
                loadSRC = true;
            elseif opt.ignoreDAT && exist(obj.filenameDAT,'file') == 2 && numel(dir(obj.filenameDAT)) == 1
                warning(sprintf('%s:Input',mfilename),'Could not find source file for ''%s'' that is not a DAT file, DAT file is recalled',obj.filename);
                loadSRC = false;
            elseif exist(obj.filenameDAT,'file') == 2 && numel(dir(obj.filenameDAT)) == 1
                loadSRC = false;
            elseif exist(obj.filenameSRC,'file') == 2 && numel(dir(obj.filenameSRC)) == 1
                loadSRC = true;
            else
                warning(sprintf('%s:Input',mfilename),'Could not find data for ''%s'', no data is recalled',obj.filename);
                return;
            end
            % load data from disk
            if loadSRC || (~isempty(opt.memmap) && opt.memmap > 1)
                myfile = obj.filenameSRC;
            else
                myfile = obj.filenameDAT;
            end
            [~,~,fe] = fileparts(myfile);
            testFile = dir(myfile);
            switch fe
                case '.dat'
                    obj = recallDAT(obj);
                case {'.tif', '.mj2', '.mp4', '.avi'}
                    % determine memmap, old default was to use a DAT file in case the video exceeded
                    % a certain size (opt.memmap = double(testFile.bytes/1024^2 > obj.chunkSize);),
                    % but currently the source file is always memeory mapped
                    if isempty(opt.memmap)
                        opt.memmap = 2;
                    end
                    obj.p_memmap = opt.memmap;
                    if obj.p_memmap == 1
                        % convert TIF/MJ2/MP4/AVI to DAT and use recallDAT to map file to memory
                        tmp = obj.convert2DAT(myfile,'memmap',obj.p_memmap,'forceNew',false,'chunkSize',obj.chunkSize);
                        if isempty(tmp)
                            warning(sprintf('%s:Input',mfilename),...
                                'File ''%s'' could not be converted to a DAT file for class ''%s'', no memory map created',...
                                myfile,class(obj));
                            return;
                        end
                        obj = recallDAT(obj);
                    elseif obj.p_memmap == 0
                        if testFile.bytes/1024^2 > opt.maxSize
                            error(sprintf('%s:Input',mfilename),...
                                'File ''%s'' exceeds with %.2f MiB the maximum limit of %.2f MiB for the memory usage, please adjust maxSize accordingly to allow such a file size',...
                                myfile,testFile.bytes/1024^2,opt.maxSize);
                        end
                        switch fe
                            case '.tif'
                                % option 1: 3rd party saveastiff
                                % value = loadtiff(myfile);
                                %
                                % option 2: MATLAB's imread
                                info       = imfinfo(myfile);
                                num_images = numel(info);
                                value      = imread(myfile, 1, 'Info', info);
                                value      = repmat(value,  [1 1 1 num_images]);
                                for k = 2:num_images
                                    value(:,:,:,k) = imread(myfile, k, 'Info', info);
                                end
                            case {'.avi' '.mj2' '.mp4'}
                                vid             = VideoReader(myfile);
                                nVid            = floor(vid.Duration * vid.FrameRate);
                                vid.CurrentTime = 0;
                                value           = readFrame(vid);
                                value           = repmat(value,[1 1 1 nVid]);
                                for n = 2:nVid
                                    vid.CurrentTime = (n-1)/vid.Framerate;
                                    value(:,:,:,n)  = readFrame(vid);
                                end
                        end
                        if (isa(value,'uint8') || isa(value,'uint16') || isa(value,'single') || isa(value,'double')) && ~isempty(value)
                            obj.p_cdata = [];
                            obj.mmFile  = [];
                            if ndims(value) ~= 4
                                obj.p_cdata = permute(value,[1 2 4 3]);
                            else
                                obj.p_cdata = value;
                            end
                        else
                            warning(sprintf('%s:Input',mfilename),['File ''%s'' does not seem to contain uint8, ',...
                                'uint16, single or double data for class ''%s'', no data is recalled'],...
                                myfile,class(obj));
                            return;
                        end
                    elseif any(obj.p_memmap == [2 3])
                        % minor fix to memmap mode, such that it is 3 for tif and 2 otherwise
                        if strcmp(fe,'.tif'), obj.p_memmap = 3;
                        else,                 obj.p_memmap = 2;
                        end
                        obj.p_cdata = [];
                        % todo/test: do not yet open the file, only later when it is really read, at
                        % this moment just store the filename and memmap state
                        if obj.p_memmap == 2, obj.mmFile = {2 myfile};
                        else,                 obj.mmFile = {3 myfile};
                        end
                    else
                        error(sprintf('%s:Input',mfilename),...
                            'Unknown memory mapping mode ''%d'', please check!',obj.p_memmap);
                    end
            end
            resetUpdate(obj);
            
            function obj = recallDAT(obj)
                %recallDAT Syncs single object from DAT file
                
                % load header of DAT file
                [isDat,~,data] = obj.isMyDAT(obj.filenameDAT);
                if ~isDat
                    warning(sprintf('%s:Input',mfilename),...
                        'File ''%s'' does not seem to contain all necessary data for class ''%s'', no data is recalled',...
                        obj.filenameDAT,class(obj));
                    return;
                end
                % determine memmap
                if isempty(opt.memmap), obj.p_memmap = data.memmap;
                else,                   obj.p_memmap = opt.memmap;
                end
                % load data
                if obj.p_memmap == 1
                    % todo/test: do not yet open the file, only later when it is really read, at
                    % this moment just store the filename
                    obj.p_cdata = [];
                    obj.mmFile  = {1 obj.filenameDAT};
                elseif obj.p_memmap == 0
                    if testFile.bytes/1024^2 > opt.maxSize
                        error(sprintf('%s:Input',mfilename),['File ''%s'' exceeds with %.2f MiB the ',...
                            'maximum limit of %.2f MiB for the memory usage, please adjust maxSize ',...
                            'accordingly to allow such a file size'], myfile,testFile.bytes/1024^2,opt.maxSize);
                    end
                    tmpMap = memmapfile(obj.filenameDAT,'Writable',true,'Repeat',1,'Offset',1024, ...
                        'Format',{data.class,[data.nY data.nX data.nZ data.nFrames],'cdata'});
                    obj.p_cdata = [];
                    obj.mmFile  = [];
                    obj.p_cdata = tmpMap.Data.cdata(:,:,:,:);
                    tmpMap      = []; %#ok<NASGU>
                else
                    error(sprintf('%s:Input',mfilename),...
                        'Unknown memory mapping mode ''%d'' for a DAT file, please check!',obj.p_memmap);
                end
            end
        end
        
        function 	         store(obj)
            %store Stores video object in memory to DAT file
            
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if isempty(obj.filename)
                warning(sprintf('%s:Input',mfilename),...
                    'Filename is not set for object of class ''%s'', no data written to disk',class(obj));
                return;
            end
            %
            % check
            check(obj);
            % store data
            [isDat,isExist,data] = obj.isMyDAT(obj.filenameDAT);
            if isExist && ~isDat
                error(sprintf('%s:Input',mfilename),...
                    'Existing file ''%s'' does not seem to be a DAT file of class ''%s''',...
                    obj.filenameDAT,class(obj));
            end
            if obj.memmap == 1
                % store header information, in total 1024 bytes, Note: do not touch file if we are
                % memory mapping and no change to the header is necessary (otherwise we would change
                % the date the file was changed which might trigger rsync or similar programs).
                % Note: memmap does also not change the modified date, such that rsync never syncs!
                % Therefore the class keeps track of any change to its actual data in subsasgn and
                % writes a new header in case cdata was changed. By doing so the modified date is
                % changed and rsync can find the change
                if ~(isDat && obj.nX == data.nX && obj.nY == data.nY && obj.nZ == data.nZ && ...
                        obj.nFrames == data.nFrames && obj.nBits == data.nBits && ...
                        obj.p_memmap == data.memmap) || obj.isChanged
                    if isDat, fid = fopen(obj.filenameDAT,'r+');
                    else,     fid = fopen(obj.filenameDAT,'W');
                    end
                    fseek(fid, 0, 'bof');
                    count = 0;
                    count = count + fwrite(fid,uint64(obj.nYDisk),    'uint64');
                    count = count + fwrite(fid,uint64(obj.nXDisk),    'uint64');
                    count = count + fwrite(fid,uint64(obj.nZDisk),    'uint64');
                    count = count + fwrite(fid,uint64(obj.nFrames),   'uint64');
                    count = count + fwrite(fid,uint64(obj.nBitsDisk), 'uint64');
                    count = count + fwrite(fid,uint64(obj.memmap),    'uint64');
                    count = count + fwrite(fid,zeros(1,122,'uint64'), 'uint64');
                    fclose(fid);
                    if count ~= 128
                        error(sprintf('%s:Write',mfilename),'Could not write to file ''%s''',obj.filenameDAT);
                    end
                    obj.isChanged = false; % reset flag
                end
            else
                % save anything only if data has been changed or does not match
                if (isDat && ~(obj.nX == data.nX && obj.nY == data.nY && obj.nZ == data.nZ && ...
                        obj.nFrames == data.nFrames && obj.nBits == data.nBits && ...
                        obj.p_memmap == data.memmap)) || obj.isChanged
                    % store header information, in total 1024 bytes, start from new file and delete
                    % any previous file
                    if isExist, delete(obj.filenameDAT); end
                    fid = fopen(obj.filenameDAT,'W');
                    fseek(fid, 0, 'bof');
                    count = 0;
                    count = count + fwrite(fid,uint64(obj.nYDisk),    'uint64');
                    count = count + fwrite(fid,uint64(obj.nXDisk),    'uint64');
                    count = count + fwrite(fid,uint64(obj.nZDisk),    'uint64');
                    count = count + fwrite(fid,uint64(obj.nFrames),   'uint64');
                    count = count + fwrite(fid,uint64(obj.nBitsDisk), 'uint64');
                    count = count + fwrite(fid,uint64(obj.memmap),    'uint64');
                    count = count + fwrite(fid,zeros(1,122,'uint64'), 'uint64');
                    if count ~= 128
                        error(sprintf('%s:Write',mfilename),'Could not write to file ''%s''',obj.filenameDAT);
                    end
                    % store cdata
                    switch obj.memmap
                        case 0
                            count = fwrite(fid,obj.p_cdata,obj.classDisk);
                            if count ~= numel(obj.p_cdata)
                                fclose(fid);
                                error(sprintf('%s:Write',mfilename),'Could not write to file ''%s''',obj.filenameDAT);
                            end
                            fclose(fid);
                        otherwise
                            error(sprintf('%s:Input',mfilename),['Unknown memory mapping mode ''%d'' ',...
                                'at this position, since the file should be in read-only mode, please check!'],obj.memmap);
                    end
                    obj.isChanged = false; % reset flag
                end
            end
        end
        
        function 	         write2File(obj,cleanStore,varargin)
            %write2File Stores in the MAT file additional data given as structure or in <variable name>, <value> style
            % The first input can be used to perform a clean write by loading the complete file into
            % memory and saving afterwards (instead of appending which might increase the file size)
            
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if ~(nargin > 1 && islogical(cleanStore))
                error(sprintf('%s:Input',mfilename),...
                    'Second input is expected to be a logical for object of class ''%s''',class(obj));
            elseif isempty(obj.filename)
                warning(sprintf('%s:Input',mfilename),...
                    'Filename is not set for object of class ''%s'', no data written to disk',class(obj));
                return;
            end
            % convert input to struct
            if numel(varargin) < 1
                return;
            elseif numel(varargin) == 1 && isstruct(varargin{1}) && numel(varargin{1}) == 1
                data = varargin{1};
            elseif mod(numel(varargin),2) == 0 && iscellstr(varargin(1:2:end))
                data = struct(varargin{:});
            else
                warning(sprintf('%s:Input',mfilename),...
                    'Unknown input for data to store in file ''%s'', no data is written to disk',obj.filenameMAT);
                return
            end
            if numel(varargin) < 1
                return;
            end
            % check MAT file
            [isMat,isExist] = obj.isMyMAT(obj.filenameMAT);
            if isExist && ~isMat
                warning(sprintf('%s:Input',mfilename),...
                    'Existing file ''%s'' does not seem to be a MAT file of class ''%s'', no data is written to disk',...
                    obj.filenameMAT,class(obj));
                return;
            end
            % store given data in MAT file, unfortunatley that way the file grows over time for an
            % unknown reason. Therefore the file is read into memory, data is added and stored again
            % to keep a clean file (in case cleanStore is true, otherwise append)
            if ~isExist
                save(obj.filenameMAT,'-struct','data');
            else
                if cleanStore
                    tmp = load(obj.filenameMAT);
                    fn  = fieldnames(data);
                    for i = 1:numel(fn)
                        tmp.(fn{i}) = data.(fn{i});
                    end
                    save(obj.filenameMAT,'-struct','tmp');
                else
                    save(obj.filenameMAT,'-struct','data','-append');
                end
            end
            % reset list2File
            obj.p_list2File = [];
        end
        
        function data      = read2File(obj,varargin)
            %read2File Reads from the MAT file variables given as structure or cellstr or returns all data
            
            data = struct;
            % convert input to struct
            if numel(varargin) == 1 && isstruct(varargin{1}) && numel(varargin{1}) == 1
                data = varargin{1};
            elseif iscellstr(varargin)
                for i = 1:numel(varargin)
                    data.(varargin{i}) = [];
                end
            elseif numel(varargin) == 1 && iscellstr(varargin{1})
                for i = 1:numel(varargin{1})
                    data.(varargin{1}{i}) = [];
                end
            else
                warning(sprintf('%s:Input',mfilename),...
                    'Unknown input for data to read from file ''%s'', no data is read from disk',...
                    obj.filenameMAT);
                return
            end
            fn = fieldnames(data);
            % check MAT file
            [isMat,isExist] = obj.isMyMAT(obj.filenameMAT);
            if isExist && ~isMat
                warning(sprintf('%s:Input',mfilename),...
                    'Existing file ''%s'' does not seem to be a MAT file of class ''%s'', no data is read from disk',...
                    obj.filenameMAT,class(obj));
                return;
            elseif ~isExist
                return;
            end
            % read data
            tmp  = load(obj.filenameMAT);
            tmp2 = fieldnames(tmp);
            if numel(fn) < 1
                fn = tmp2;
            else
                idx = ismember(fn,tmp2);
                fn  = fn(idx);
            end
            for i = 1:numel(fn)
                data.(fn{i}) = tmp.(fn{i});
            end
        end
        
        function             crop(obj,rect)
            %crop Crops data by rect
            % Rect can be a four-element position vector [xmin ymin width height] which crops all
            % slices of all frames. To crop also in z and frame direction use eight-element vector
            % [xmin ymin zmin framemin width height depth frames], see also imcrop
            
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            % check input
            if nargin > 1 && isnumeric(rect) && isvector(rect) && (numel(rect) == 4 || numel(rect) == 8)
                if numel(rect) == 4, rect = [rect(1) rect(1) 1 1 rect(3) rect(4) obj.nZ obj.nFrames]; end
            else
                error(sprintf('%s:Input',mfilename),'Input for rect is unexpected');
            end
            maxRect = [rect(1:4) rect(1:4)+rect(5:8)-1];
            if any(rect<1) || any(maxRect-[obj.nXDisk obj.nYDisk obj.nZDisk obj.nFrames obj.nXDisk obj.nYDisk obj.nZDisk obj.nFrames] > 0)
                error(sprintf('%s:Input',mfilename),'Rect exceeds size of object');
            end
            % perform crop
            if obj.memmap == 1
                % data needs to be written to a new file image by image - no other solution found
                store(obj);
                % convert file and recall
                obj.convert2DAT(obj.filenameDAT,'idxFrames',rect(4):(rect(4)+rect(8)-1),...
                    'transform',@(x) x(rect(2):(rect(2)+rect(6)-1),rect(1):(rect(1)+rect(5)-1),rect(3):(rect(3)+rect(7)-1)),...
                    'memmap', obj.p_memmap, 'chunkSize', obj.chunkSize);
                recall(obj);
            elseif obj.memmap == 0
                obj.p_cdata = obj.p_cdata(rect(2):(rect(2)+rect(6)-1),rect(1):(rect(1)+rect(5)-1),rect(3):(rect(3)+rect(7)-1),rect(4):(rect(4)+rect(8)-1));
                resetUpdate(obj);
            else
                error(sprintf('%s:Input',mfilename),['File ''%s'' is memory mapped in read-only mode, ',...
                    'write access in combination with memory mapping is only supported for DAT files'],obj.filename);
            end
            obj.isChanged = true;
        end
        
        function             resize(obj,scale,depth)
            %resize Resizes image data in x, y and z direction
            % Resizing in x and y direction is performed by imresize for a positive scaling factor
            % or vector [nY nX] (first input), the second determines the repetition in z direction
            
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            % check input
            if nargin < 3, depth = 1; end
            if nargin < 2, scale = 1; end
            if ~(isnumeric(scale) && ((isscalar(scale) && scale > 0) || (isrow(scale) && numel(scale) == 2)))
                error(sprintf('%s:Input',mfilename),'Input for scale is unexpected');
            end
            if ~(isnumeric(depth) && isscalar(depth) && depth > 0)
                error(sprintf('%s:Input',mfilename),'Input for depth is unexpected');
            end
            if depth == 1 && scale == 1
                return;
            end
            % perform crop
            if obj.memmap == 1
                % data needs to be written to a new file image by image - no other solution found
                store(obj);
                % convert file and recall
                if scale ~= 1 && depth == 1
                    Videomap.convert2DAT(obj.filenameDAT, 'transform', @(x) imresize(x,scale), ...
                        'memmap', obj.p_memmap, 'chunkSize', obj.chunkSize)
                elseif scale == 1 && depth ~= 1
                    Videomap.convert2DAT(obj.filenameDAT, 'transform', @(x) repmat(x,[1 1 depth]), ...
                        'memmap', obj.p_memmap, 'chunkSize', obj.chunkSize)
                else
                    Videomap.convert2DAT(obj.filenameDAT, 'transform', @(x) imresize(repmat(x,[1 1 depth]),scale), ...
                        'memmap', obj.p_memmap, 'chunkSize', obj.chunkSize)
                end
                recall(obj);
            elseif obj.memmap == 0
                if scale ~= 1
                    in           = obj.p_cdata;
                    tmp          = imresize(in(:,:,:,1),scale);
                    obj.p_cdata  = zeros(size(tmp,1),size(tmp,2),size(tmp,3),obj.nFrames,'like',tmp);
                    for i = 1:obj.nFrames
                        obj.p_cdata(:,:,:,i) = imresize(in(:,:,:,i),scale);
                    end
                else
                    out = obj.p_cdata;
                end
                if depth ~= 1
                    obj.p_cdata = repmat(out,[1 1 depth 1]);
                else
                    obj.p_cdata = out;
                end
                resetUpdate(obj);
            else
                error(sprintf('%s:Input',mfilename),['File ''%s'' is memory mapped in read-only mode, ',...
                    'write access in combination with memory mapping is only supported for DAT files'],obj.filename);
            end
            obj.isChanged = true;
        end
        
        function             check(obj,doReset)
            %check Checks object's integrity, e.g. the memory mapping and class of image data
            
            if nargin < 2, doReset = false; end
            % reset object before check
            if ~obj.lock && doReset
                resetUpdate(obj,false);
            end
            % check MAT file
            [isMat,isExist] = obj.isMyMAT(obj.filenameMAT);
            if isExist && ~isMat
                error(sprintf('%s:Input',mfilename),...
                    'Existing file ''%s'' does not seem to be a MAT file of class ''%s''',...
                    obj.filenameMAT,class(obj));
            end
            % check DAT file
            [isDat,isExist,data] = obj.isMyDAT(obj.filenameDAT);
            if isExist && ~isDat
                error(sprintf('%s:Input',mfilename),...
                    'Existing file ''%s'' does not seem to be a DAT file of class ''%s''',...
                    obj.filenameDAT,class(obj));
            end
            % check data
            if obj.memmap == 0
                if ~((isnumeric(obj.p_cdata) && (ndims(obj.p_cdata) >= 2 && ndims(obj.p_cdata) <= 4) && (isa(obj.p_cdata,'uint8') ||...
                        isa(obj.p_cdata,'uint16') || isa(obj.p_cdata,'single') || isa(obj.p_cdata,'double'))) || isempty(obj.p_cdata))
                    error(sprintf('%s:Input',mfilename),['Data of file ''%s'' in object of class ',...
                        '''%s'' seems to be invalid'],obj.filename,class(obj));
                end
            elseif obj.memmap == 1 && obj.isLinked
                if ~isa(obj.mmFile,'memmapfile')
                    error(sprintf('%s:Input',mfilename),...
                        'Memory map seems to be broken for file ''%s'' in object of class ''%s''',...
                        obj.filename,class(obj));
                elseif isempty(obj.p_cdata)
                    warning(sprintf('%s:Input',mfilename),...
                        'Memory map seems to be not linked correctly for file ''%s'' in object of class ''%s'', trying to fix',...
                        obj.filename,class(obj));
                    obj.p_cdata = obj.mmFile.Data.cdata;
                end
                if ~strcmp(obj.filenameDAT,obj.mmFile.Filename)
                    error(sprintf('%s:Input',mfilename),...
                        'Memory map in object of class ''%s'' exists to file ''%s'', but filename in object seems to link to ''%s''',...
                        class(obj),obj.mmFile.Filename,obj.filenameDAT);
                end
                tmp1    = [obj.nYDisk obj.nXDisk obj.nZDisk obj.nFrames obj.nBitsDisk];
                tmp2    = [data.nY data.nX data.nZ data.nFrames data.nBits];
                mmClass = class(obj.mmFile.Data.cdata);
                tmpSize = size(obj.mmFile.Data.cdata);
                if ndims(tmpSize) < 4, tmpSize(end+1:4) = 1; end
                if strcmp(mmClass,'uint8') %#ok<STISA>
                    tmp3 = [tmpSize 8];
                elseif strcmp(mmClass,'uint16') %#ok<STISA>
                    tmp3 = [tmpSize 16];
                elseif strcmp(mmClass,'single') %#ok<STISA>
                    tmp3 = [tmpSize 32];
                elseif strcmp(mmClass,'double') %#ok<STISA>
                    tmp3 = [tmpSize 64];
                else
                    error(sprintf('%s:Input',mfilename),...
                        'Memory map to file ''%s'' in object of class ''%s'' maps unsupported data class ''%s''',...
                        obj.filenameDAT,class(obj),mmClass);
                end
                if any(abs(tmp1 - tmp2) > eps) || any(abs(tmp1 - tmp3) > eps)
                    error(sprintf('%s:Input',mfilename),['Size of memory map seems to be wrong for ',...
                        'file ''%s'' in object of class ''%s'''],obj.filenameDAT,class(obj));
                end
            elseif obj.memmap == 2 && obj.isLinked
                if ~isa(obj.mmFile,'VideoReader') || ~isempty(obj.p_cdata)
                    error(sprintf('%s:Input',mfilename),['Memory map seems to be broken for file ',...
                        '''%s'' in object of class ''%s'''], obj.filename, class(obj));
                end
            elseif obj.memmap == 3 && obj.isLinked
                if ~isa(obj.mmFile,'TIFFStack') || ~isempty(obj.p_cdata)
                    error(sprintf('%s:Input',mfilename),['Memory map seems to be broken for file ',...
                        '''%s'' in object of class ''%s'''], obj.filename, class(obj));
                end
            end
        end
        
        function varargout = exportAs(obj,varargin)
            %exportAs Exports object to common video file formats
            % The filename of the new file is based on the object's filename extended by '_exportAs'
            % (can be changed in settings), see the options processed by the inputparser for further
            % settings.
            %
            % Example:
            %   % Export the first 50 frames in a horizontal montage
            %   obj.exportAs('idxFrame',1:50,'transform',@im2uint8 @(x) cat(2,x(1:end/2,:,:),x(end/2+1:end,:,:)))
            
            %
            % use input parser to process options
            nargoutchk(0,3);
            opt               = inputParser;
            opt.StructExpand  = true;
            opt.KeepUnmatched = false;
            % absolute basename for filename to use, empty creates new based in object
            opt.addParameter('filename', [], ...
                @(x) isempty(x) || (ischar(x) && numel(x) > 0));
            % suffix to use for video filename
            opt.addParameter('suffix', '_exportAs', ...
                @(x) ischar(x));
            % profile to use
            opt.addParameter('profile', 'MPEG-4', ...
                @(x) ischar(x) && ismember(x,{'MPEG-4','Archival','Motion JPEG AVI',...
                'Motion JPEG 2000','TIF','TIF NOCOMP'}));
            % framerate if supported by profile
            opt.addParameter('framerate', 10, ...
                @(x) isnumeric(x) && isscalar(x) && x>0);
            % overwrite files
            opt.addParameter('overwrite', true, ...
                @(x) islogical(x) && isscalar(x));
            % select only certain frames for the export, empty value leads to all frames
            opt.addParameter('idxFrames', [], ...
                @(x) isempty(x) || (isnumeric(x) && min(x)>0));
            % transformation that should be applied when writing data to video file
            opt.addParameter('transform', [], ...
                @(x) isempty(x) || isa(x,'function_handle') || isa(x,'affine2d') || ...
                isa(x,'cameraParameters') || (iscell(x) && isa(x{1},'function_handle')));
            opt.parse(varargin{:});
            opt          = opt.Results;
            %
            % prepare new filename
            if isempty(opt.filename)
                [path,name] = fileparts(obj.filename);
            else
                [path,name] = fileparts(opt.filename);
            end
            if isempty(name) && isempty(opt.suffix)
                error(sprintf('%s:Export',mfilename),['Filename and suffix are empty leading to ',...
                    'an empty filename to export to, please check']);
            end
            switch opt.profile
                case {'MPEG-4' 'Archival' 'Motion JPEG AVI' 'Motion JPEG 2000'}
                    mov           = VideoWriter(fullfile(path,[name opt.suffix]),opt.profile);
                    mov.FrameRate = opt.framerate;
                    fnExport      = mov.Filename;
                    fnExport      = fullfile(path,fnExport);
                case {'TIF' 'TIF NOCOMP'}
                    fnExport = fullfile(path,[name opt.suffix '.tif']);
            end
            % get number of frames
            idxFrames = opt.idxFrames;
            if ~isempty(idxFrames)
                idxFrames = reshape(idxFrames,1,[]);
                idxFrames(idxFrames > obj.nFrames) = [];
            else
                idxFrames = 1:obj.nFrames;
            end
            if isempty(idxFrames)
                warning(sprintf('%s:Export',mfilename),...
                    'Current data and settings lead to file ''%s'' containing no frames, no data exported',fnExport);
                if nargout > 0
                    varargout = {fnExport idxFrames opt};
                    varargout = varargout(1:nargout);
                end
                return;
            end
            if ~opt.overwrite && exist(fnExport,'file') == 2 && numel(dir(fnExport)) == 1
                warning(sprintf('%s:Export',mfilename),['File ''%s'' already exists and overwriting ',...
                    'is disabled, no data exported'],fnExport);
                if nargout > 0
                    varargout = {fnExport idxFrames opt};
                    varargout = varargout(1:nargout);
                end
                return;
            end
            % get an example image for testing
            link(obj);
            if any(obj.memmap == [0 1])
                tmpTest = Videomap.applyTransform(Videomap.applyTransform(obj.p_cdata(:,:,:,idxFrames(1)),obj.transform),opt.transform);
            elseif obj.memmap == 2
                obj.mmFile.CurrentTime = 0;
                tmpTest = Videomap.applyTransform(Videomap.applyTransform(readFrame(obj.mmFile),obj.transform),opt.transform);
            elseif obj.memmap == 3
                tmpTest = Videomap.applyTransform(Videomap.applyTransform(permute(obj.mmFile(:,:,idxFrames(1),:),[1 2 4 3]),obj.transform),opt.transform);
            else
                error(sprintf('%s:Input',mfilename),...
                    'Unknown memory mapping mode ''%d'', please check!',obj.memmap);
            end
            if ismember(opt.profile,{'MPEG-4' 'Motion JPEG AVI'}) && ...
                    ~(isa(tmpTest,'double') || isa(tmpTest,'single') || isa(tmpTest,'uint8'))
                if isempty(opt.transform)
                    warning(sprintf('%s:Export',mfilename),['Current data of file ''%s'' is of ',...
                        'class ''%s'' and is converted to uint8 in order to write to MPEG-4 or AVI'],...
                        obj.filename,class(tmpTest));
                    opt.transform = @im2uint8;
                else
                    error(sprintf('%s:Export',mfilename),['Current data of file ''%s'' is of ',...
                        'class ''%s'' and needs to be converted to uint8 in order to write to MPEG-4 ',...
                        'or AVI, but a custom transform function is already in use, please check!'],...
                        obj.filename,class(tmpTest));
                end
            end
            % export data
            nDig = 1+ceil(log10(numel(idxFrames)));
            fprintf('Writing %d frames to file ''%s''\n',numel(idxFrames),fnExport);
            switch opt.profile
                case {'MPEG-4' 'Archival' 'Motion JPEG AVI' 'Motion JPEG 2000'}
                    mov.open;
                    if obj.memmap == 1
                        framesDone  = 0;
                        framesChunk = round(obj.chunkSize/obj.memoryDisk * obj.nFrames);
                        while framesDone < numel(idxFrames)
                            curFrames = (framesDone + 1):min(numel(idxFrames),max(framesDone + 1,framesDone+framesChunk));
                            fprintf('  %*d of %*d frames: %*d to %*d\n',...
                                nDig,numel(curFrames),nDig,numel(idxFrames),nDig,min(curFrames),nDig,max(curFrames));
                            writeVideo(mov,Videomap.applyTransform(Videomap.applyTransform(obj.p_cdata(:,:,:,idxFrames(curFrames)),obj.transform),opt.transform));
                            framesDone = curFrames(end);
                        end
                    elseif obj.memmap == 2
                        for n = reshape(idxFrames,1,[])
                            obj.mmFile.CurrentTime = (n-1)/obj.mmFile.Framerate;
                            fprintf('  %*d of %*d frames: %*d to %*d\n',...
                                nDig,1,nDig,numel(idxFrames),nDig,n,nDig,n);
                            writeVideo(mov,Videomap.applyTransform(Videomap.applyTransform(readFrame(obj.mmFile),obj.transform),opt.transform));
                        end
                    elseif obj.memmap == 3
                        framesDone  = 0;
                        framesChunk = round(obj.chunkSize/obj.memoryDisk * obj.nFrames);
                        while framesDone < numel(idxFrames)
                            curFrames = (framesDone + 1):min(numel(idxFrames),max(framesDone + 1,framesDone+framesChunk));
                            fprintf('  %*d of %*d frames: %*d to %*d\n',...
                                nDig,numel(curFrames),nDig,numel(idxFrames),nDig,min(curFrames),nDig,max(curFrames));
                            writeVideo(mov,Videomap.applyTransform(Videomap.applyTransform(permute(obj.mmFile(:,:,idxFrames(curFrames),:),[1 2 4 3]),obj.transform),opt.transform));
                            framesDone = curFrames(end);
                        end
                    elseif obj.memmap == 0
                        fprintf('  %*d of %*d frames: %*d to %*d\n',...
                            nDig,numel(idxFrames),nDig,numel(idxFrames),nDig,1,nDig,numel(idxFrames));
                        writeVideo(mov,Videomap.applyTransform(Videomap.applyTransform(obj.p_cdata(:,:,:,idxFrames),obj.transform),opt.transform))
                    else
                        error(sprintf('%s:Input',mfilename),...
                            'Unknown memory mapping mode ''%d'', please check!',obj.memmap);
                    end
                    mov.close
                case {'TIF' 'TIF NOCOMP'}
                    % write to TIF with LZW compression (should make sure imageJ can read it), use
                    % 64 bit addressing when writing big files, use FEX submission saveastiff
                    options.color   = size(tmpTest,3) > 1;
                    switch opt.profile
                        case 'TIF',        options.comp = 'lzw';
                        case 'TIF NOCOMP', options.comp = 'no';
                    end
                    options.message = true;
                    options.ask     = false;
                    options.append  = false;
                    options.big     = obj.memoryDisk * numel(idxFrames)/obj.nFrames > 3500;
                    if obj.memmap == 1
                        framesDone  = 0;
                        framesChunk = round(obj.chunkSize/obj.memoryDisk * obj.nFrames);
                        while framesDone < numel(idxFrames)
                            curFrames = (framesDone + 1):min(numel(idxFrames),max(framesDone + 1,framesDone+framesChunk));
                            fprintf('  %*d of %*d frames: %*d to %*d\n',...
                                nDig,numel(curFrames),nDig,numel(idxFrames),nDig,min(curFrames),nDig,max(curFrames));
                            fprintf('  ');
                            saveastiff(squeeze(Videomap.applyTransform(Videomap.applyTransform(obj.p_cdata(:,:,:,idxFrames(curFrames)),obj.transform),opt.transform)),fnExport,options);
                            framesDone     = curFrames(end);
                            options.append = true;
                        end
                    elseif obj.memmap == 2
                        for n = reshape(idxFrames,1,[])
                            obj.mmFile.CurrentTime = (n-1)/obj.mmFile.Framerate;
                            fprintf('  %*d of %*d frames: %*d to %*d\n',...
                                nDig,1,nDig,numel(idxFrames),nDig,n,nDig,n);
                            fprintf('  ');
                            saveastiff(squeeze(Videomap.applyTransform(Videomap.applyTransform(readFrame(obj.mmFile),obj.transform),opt.transform)),fnExport,options);
                            options.append = true;
                        end
                    elseif obj.memmap == 3
                        framesDone  = 0;
                        framesChunk = round(obj.chunkSize/obj.memoryDisk * obj.nFrames);
                        while framesDone < numel(idxFrames)
                            curFrames = (framesDone + 1):min(numel(idxFrames),max(framesDone + 1,framesDone+framesChunk));
                            fprintf('  %*d of %*d frames: %*d to %*d\n',...
                                nDig,numel(curFrames),nDig,numel(idxFrames),nDig,min(curFrames),nDig,max(curFrames));
                            fprintf('  ');
                            saveastiff(squeeze(Videomap.applyTransform(Videomap.applyTransform(permute(obj.mmFile(:,:,idxFrames(curFrames),:),[1 2 4 3]),obj.transform),opt.transform)),fnExport,options);
                            framesDone     = curFrames(end);
                            options.append = true;
                        end
                    elseif obj.memmap == 0
                        fprintf('  %*d of %*d frames: %*d to %*d\n',...
                            nDig,numel(idxFrames),nDig,numel(idxFrames),nDig,1,nDig,numel(idxFrames));
                        saveastiff(squeeze(Videomap.applyTransform(Videomap.applyTransform(obj.p_cdata(:,:,:,idxFrames),obj.transform),opt.transform)),fnExport,options);
                    else
                        error(sprintf('%s:Input',mfilename),...
                            'Unknown memory mapping mode ''%d'', please check!',obj.memmap);
                    end
            end
            fprintf('  Finished exporting to file ''%s''\n',fnExport);
            if nargout > 0
                varargout = {fnExport idxFrames opt}; 
                varargout = varargout(1:nargout);
            end
        end
    end
    
    methods (Access = {?Video,?Videomap}, Hidden = false)
        function         resetUpdate(obj,doNotify)
            %resetUpdate Resets properties that should be recomputed on data change
            % This will force a recalculation of the corresponing properties next time they are used
            
            if nargin < 2, doNotify = true; end
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            obj.p_nX         = [];
            obj.p_nXDisk     = [];
            obj.p_nY         = [];
            obj.p_nYDisk     = [];
            obj.p_nZ         = [];
            obj.p_nZDisk     = [];
            obj.p_nFrames    = [];
            obj.p_nBits      = [];
            obj.p_nBitsDisk  = [];
            obj.p_class      = [];
            obj.p_classDisk  = [];
            obj.p_memory     = [];
            obj.p_memoryDisk = [];
            obj.p_list2File  = [];
            if doNotify
                if isempty(obj.master)
                    notify(obj,'resetVideo');
                else
                    resetUpdate(obj.master);
                end 
            end
        end
    end
    
    methods (Access = protected)
        function cpObj = copyElement(obj)
            % copyElement Override copyElement method from matlab.mixin.Copyable class
            
            % Make a shallow copy of all properties
            cpObj = copyElement@matlab.mixin.Copyable(obj);
            % reset new object
            resetUpdate(cpObj);
        end
    end
    
    methods
        function S     = saveobj(obj)
            % saveobj Supposed to be called by MATLAB's save function, ensures the object is stored
            % to disk by its own store function, the MATLAB file just needs little information such
            % as the filename to the stored data
            
            if isempty(obj.filename)
                % this should be the default value for the filename, i.e. the template object
                % that does not hold any data to be recalled
            else
                store(obj);
            end
            % return a structure with the necessary information to restore the object from disk
            S.filename  = obj.filename;
            S.memmap    = obj.memmap;
            S.chunkSize = obj.chunkSize;
            S.transform = obj.transform;
        end
    end
    
    %% Static class related methods
    methods (Static = true, Access = public, Hidden = false)
        function cdata                              = applyTransform(cdata,transform)
            %applyTransform Applies transformation to cdata
            
            if isempty(transform) || nargin < 2, return; end
            switch class(transform)
                case {'function_handle' 'cell'}
                    if isa(transform,'function_handle')
                        func = transform;
                        args = {};
                    else
                        func = transform{1};
                        if numel(transform) > 1, args = transform(2:end);
                        else,                    args = {};
                        end
                    end
                    nFrames = size(cdata,4);
                    if nFrames > 1
                        out = repmat(func(cdata(:,:,:,1),args{:}),[1 1 1 nFrames]);
                        for i = 2:size(cdata,4)
                            out(:,:,:,i) = func(cdata(:,:,:,i),args{:});
                        end
                        cdata = out;
                    else
                        cdata = func(cdata,args{:});
                    end
                case 'affine2d'
                    cdata = imwarp(cdata,transform);
                case 'cameraParameters'
                    nFrames = size(cdata,4);
                    if nFrames > 1
                        out = repmat(undistortImage(cdata(:,:,:,1),transform),[1 1 1 nFrames]);
                        for i = 2:size(cdata,4)
                            out(:,:,:,i) = undistortImage(cdata(:,:,:,i),transform);
                        end
                        cdata = out;
                    else
                        cdata = undistortImage(cdata,transform);
                    end
                otherwise
                    error(sprintf('%s:Input',mfilename),'Unknown input for transformation');
            end
        end
        
        function obj                                = loadobj(S)
            %loadobj Loads object and recalls data
            
            if isstruct(S)
                filename = S.filename;
                S        = rmfield(S,'filename');
                fn       = fieldnames(S);
                tmp      = cell(1,numel(fn)*2);
                tmp(1:2:end) = fn;
                tmp(2:2:end) = struct2cell(S);
                obj = Videomap(filename,tmp{:});
            else
                obj = S;
                if isempty(obj.filename)
                    % this should be the default value for the filename, i.e. the template object
                    % that does not hold any data to be recalled
                    return;
                else
                    recall(obj);
                end
            end
        end
        
        function myfiles                            = findMultipleTIF(filename,nDig)
            %findMultipleTIF Search for TIF files ending with sprintf('@%0.*d',nDig,i), etc.
            % Input filename can be the basename (without extension) or the full filename. This
            % function is extended to also find filenames ending with sprintf('-%0.*d',nDig,i) as
            % saved by Photron software. It will apply the naming schemes that finds the most files.
            % Here are two examples of naming schemes:
            %
            % Example 1a (used for example by PCO software):
            % <something>.tif
            % <something>@0001.tif
            % <something>@0002.tif
            %           .
            %           .
            %
            % Example 1b:
            % <something>@0000.tif
            % <something>@0001.tif
            % <something>@0002.tif
            %           .
            %           .
            %
            % Example 2a (used for example by Photron software):
            % <something>-00.tif
            % <something>-01.tif
            % <something>-02.tif
            %           .
            %           .
            %
            % Example 2b (used for example by Photron software):
            % <something>-00.tif
            % <something>-01.tif
            % <something>-02.tif
            %           .
            %           .
            %
            
            if nargin < 1
                return
            elseif nargin < 2
                nDig = [4 2];
            end
            % get files for both naming schemes and return the one with most files
            myfilesPCO     = findFilesSTR(filename,'@',nDig(1));
            myfilesPhotron = findFilesSTR(filename,'-',nDig(2));
            if numel(myfilesPhotron) > numel(myfilesPCO)
                myfiles = myfilesPhotron;
                if numel(myfilesPCO) > 1
                    warning(sprintf('%s:Input',mfilename),...
                        'Using the Photron naming schemes for %d files, but also the PCO schemes found %d files',numel(myfiles),numel(myfilesPCO));
                end
            else
                myfiles = myfilesPCO;
                if numel(myfilesPhotron) > 1
                    warning(sprintf('%s:Input',mfilename),...
                        'Using the PCO naming schemes for %d files, but also the Photron schemes found %d files',numel(myfiles),numel(myfilesPhotron));
                end
            end
            
            function myfiles = findFilesSTR(filename,str,nDig)
                % initialise output with first input
                myfiles  = {filename};
                % prepare input
                [~,~,fe] = fileparts(filename);
                if isempty(fe)
                    filename = [filename '.tif'];
                end
                [fp,fn] = fileparts(filename);
                % check for names
                isFile = @(fn) numel(fn) > nDig && ~isempty(regexp(fn(end-nDig-4:end-4),['^' str '\d{',num2str(nDig),'}'], 'once'));
                if exist(filename,'file') == 2 && numel(dir(filename)) == 1
                    if ~(numel(fn) > nDig && isFile(filename))
                        % input filename does not end with @0001 but let's treat it as first file
                        tmp = dir(fullfile(fp,[fn str '*.tif']));
                        myfiles{1} = filename;
                        for i = 1:numel(tmp)
                            tmp(i).name = fullfile(fp,tmp(i).name);
                            if numel(tmp(i).name) == numel(filename)+nDig+1 && isFile(tmp(i).name)
                                myfiles{end+1} = tmp(i).name; %#ok<AGROW>
                            end
                        end
                    else
                        tmp = dir(fullfile(fp,[fn(1:end-nDig-1) str '*.tif']));
                        for i = 1:numel(tmp)
                            tmp(i).name = fullfile(fp,tmp(i).name);
                            if numel(tmp(i).name) == numel(filename) && isFile(tmp(i).name)
                                myfiles{end+1} = tmp(i).name; %#ok<AGROW>
                            end
                        end
                    end
                end
                % sort according to last
                nFN     = numel(myfiles);
                if nFN > 1
                    myfiles = unique(myfiles,'sorted');
                    nFN     = numel(myfiles); 
                    idx     = NaN(size(myfiles));
                    for i = 1:nFN
                        [~,fn] = fileparts(myfiles{i});
                        if ~(numel(fn) > nDig && isFile([fn '.tif']))
                            idx(i) = -1;
                        else
                            idx(i) = str2double(fn(end-(nDig-1):end));
                        end
                    end
                    [~,idx] = sort(idx);
                    myfiles = myfiles(idx);
                end
            end
        end
        
        function [isMyMat, isExist, data, filename] = isMyMAT(filename)
            %isMyMAT Checks if given MAT file exists (isExist) and could have been written by this
            %class (isMyMat), it also returns the variable names in the MAT file as cellstr (data),
            %Note: If the input filename does not end with the extension '.mat' it will be added, in
            %order to check if for the basename a MAT file is available (new filename is returned)
            
            isMyMat  = false;
            isExist  = false;
            data     = {};
            if isempty(filename)
                return;
            end
            [fp,fn,fe] = fileparts(filename);
            if isempty(fe)
                filename = [filename '.mat'];
            elseif ~strcmp(fe,'.mat')
                filename = fullfile(fp,[fn '.mat']);
            end
            if exist(filename,'file') == 2 && numel(dir(filename)) == 1
                isExist = true;
                % only try to read if the data is required, otherwise assume it is a valid mat file
                % since this parts takes quite some time when reloading videos
                if nargout > 2
                    try %#ok<TRYNC>
                        % Option 1: use whos
                        tmp     = whos('-file',filename);
                        data    = {tmp.name};
                        % Option 2: load complete file
                        % tmp     = load(filename);
                        % data    = fieldnames(tmp);
                        isMyMat = true;
                    end
                else
                    isMyMat = true;
                end
            end
        end
        
        function [isMyDat, isExist, data, filename] = isMyDAT(filename)
            %isMyDAT Checks if given DAT file exists (isExist) and could have been written by this
            %class (isMyDat), it also returns the header of the DAT file as structure, Note: If the
            %input filename does not end with the extension '.dat' it will be added or changed, in
            %order to check if for the basename a DAT file is available (new filename is returned)
            
            isMyDat  = false;
            isExist  = false;
            data     = struct([]);
            if isempty(filename)
                return;
            end
            [fp,fn,fe] = fileparts(filename);
            if isempty(fe)
                filename = [filename '.dat'];
            elseif ~strcmp(fe,'.dat')
                filename = fullfile(fp,[fn '.dat']);
            end
            if exist(filename,'file') == 2 && numel(dir(filename)) == 1
                isExist = true;
                fi      = dir(filename);
                if fi.bytes > 40
                    try %#ok<TRYNC>
                        fid = fopen(filename);
                        fseek(fid, 0, 'bof');
                        tmp = fread(fid,6,'uint64');
                        fclose(fid);
                        data(1).nX      = double(tmp(2));
                        data(1).nY      = double(tmp(1));
                        data(1).nZ      = double(tmp(3));
                        data(1).nFrames = double(tmp(4));
                        data(1).nBits   = double(tmp(5));
                        data(1).memmap  = double(tmp(6));
                        isMyDat         = true;
                        if data.nBits == 8
                            data(1).class = 'uint8';
                        elseif data.nBits == 16
                            data(1).class = 'uint16';
                        elseif data.nBits == 32
                            data(1).class = 'single';
                        elseif data.nBits == 64
                            data(1).class = 'double';
                        else
                            data    = struct([]);
                            isMyDat = false;
                        end
                    end
                end
            end
        end
        
        function fileOUT                            = convert2DAT(fileIN,varargin)
            %convert2DAT Copies data of a given file or numeric input with multiple frames to a new DAT file
            %
            % The function can apply simple image transformations during the processing, in case
            % multiple files are given as cellstr or DIR output each file is converted to a DAT
            % file, numeric input optional input is processed with input parser (see code)
            
            %
            % check input
            if nargin < 1 || isempty(fileIN)
                fileOUT = {};
                return;
            elseif isstruct(fileIN) && all(ismember({'name'},fieldnames(fileIN)))
                fileIN([fileIN.isdir]) = [];
                fileIN               = {fileIN.name};
            elseif isnumeric(fileIN) && ndims(fileIN) == 4 && (isa(fileIN,'uint8') || ...
                    isa(fileIN,'uint16') || isa(fileIN,'single') || isa(fileIN,'double'))
                % numeric input
            elseif ischar(fileIN)
                % single filename input
            else
                error(sprintf('%s:Input',mfilename),'Unknown input for filename(s)');
            end
            %
            % run for each file separately
            if iscellstr(fileIN)
                fileOUT = cell(size(fileIN));
                for i = 1:numel(fileIN)
                    fileOUT{i} = Videomap.convert2DAT(fileIN{i},varargin{:});
                end
                return;
            end
            %
            % use input parser to process options
            opt               = inputParser;
            opt.StructExpand  = true;
            opt.KeepUnmatched = false;
            % filename without extension (last extension is removed) of the output file in case of
            % numeric input of video data
             opt.addParameter('filename', [], @(x) isempty(x) || ischar(x));
            % true/false whether to enable/disable memory mapping for new file, empty for automatic
            % selection, i.e. load from DAT file or set based on chunkSize
            opt.addParameter('memmap', [], ...
                @(x) isempty(x) || ((islogical(x) || isnumeric(x)) && isscalar(x)));
            % true/false whether to ignore any data in an existing DAT file, Note: the MAT file is
            % untouched in any case
            opt.addParameter('forceNew', false, ...
                @(x) islogical(x) && isscalar(x));
            % transformation that should be applied when writing data to new DAT file
            opt.addParameter('transform', [], ...
                @(x) isempty(x) || isa(x,'function_handle') || isa(x,'affine2d') || ...
                isa(x,'cameraParameters') || (iscell(x) && isa(x{1},'function_handle')));
            % select only certain frames from the file, empty value leads to all frames, must be
            % monotonically increasing
            opt.addParameter('idxFrames', [], ...
                @(x) isempty(x) || (isnumeric(x) && min(x)>0 && all(diff(x)>0)));
            % chunkSize Size in MiB that can be loaded in one go into memory
            opt.addParameter('chunkSize', 1024, ...
                @(x) isnumeric(x) && isscalar(x) && min(x)>=0);
            % check for TIF names with naming scheme for multiple files, negative/empty values
            % disables this feature, i.e. the given value should be the number of digits used for
            % the files that should be treated as one video, two digits need to be given, first for
            % the PCO naming scheme followed by the one for the Photron scheme
            opt.addParameter('multipleTIF', [4 2], ...
                @(x) isempty(x) || (isnumeric(x) && numel(x)==2));
            opt.parse(varargin{:});
            opt       = opt.Results;
            if isnumeric(fileIN) && isempty(opt.filename)
                error(sprintf('%s:Input',mfilename),...
                    'Filename must be specified when numeric video data is given as input, please check!');
            elseif ~isnumeric(fileIN) && ~isempty(opt.filename)
                error(sprintf('%s:Input',mfilename),...
                    'Filename can only be specified for numeric video data as input (for files it is based on the input filename), please check!');
            end
            if islogical(opt.memmap), opt.memmap = double(opt.memmap); end
            if ~isempty(opt.memmap) && ~(opt.memmap >= 0 && opt.memmap <= 3)
                error(sprintf('%s:Input',mfilename),...
                    'Unknown memory mapping mode ''%d'', please check!',opt.memmap);
            end
            memmap    = opt.memmap;
            transform = opt.transform;
            forceNew  = opt.forceNew;
            idxFrames = opt.idxFrames;
            if isempty(opt.multipleTIF)
                opt.multipleTIF = [-1 -1];
            end
            %
            % work on single input file
            if isnumeric(fileIN)
                [path,name] = fileparts(opt.filename);
                fileOUT     = fullfile(path,[name,'.dat']);
                ext         = 'numeric';
            else
                [path,name,ext] = fileparts(fileIN);
                if ~(exist(fileIN,'file') == 2 && numel(dir(fileIN)) == 1)
                    warning(sprintf('%s:Input',mfilename),'Could not find input file ''%s'', nothing to convert',fileIN); %#ok<PFCEL>
                    fileOUT = '';
                    return;
                end
                fileOUT = fullfile(path,[name,'.dat']);
            end
            % to be able to handle multiple files per input file (e.g. for multiple TIFs) the fileIN
            % is converted to
            if ~isnumeric(fileIN)
                if strcmp(ext,'.tif') && all(opt.multipleTIF > 0)
                    fileIN = Videomap.findMultipleTIF(fileIN,opt.multipleTIF);
                else
                    fileIN = {fileIN};
                end
            end
            %
            % check for an existing DAT file
            [isDat,isExist] = Videomap.isMyDAT(fileOUT);
            if isExist && ~isDat
                if isnumeric(fileIN)
                    warning(sprintf('%s:Input',mfilename),['Existing DAT file ''%s'' does not seem to be a DAT file of ',...
                        'class ''Videomap'' and is not overwritten, no conversion performed for numeric input'],...
                        fileOUT);
                else
                    warning(sprintf('%s:Input',mfilename),['Existing DAT file ''%s'' does not seem to be a DAT file of ',...
                        'class ''Videomap'' and is not overwritten, no conversion performed for input file ''%s'''],...
                        fileOUT,fileIN{1});
                end
                fileOUT = '';
                return;
            end
            %
            % read information on video file to create a template of the data to allocate in
            % case of one-by-one conversion
            switch ext
                case '.tif'
                    % check for multiple single files
                    tmpInfo   = imfinfo(fileIN{1});
                    heightIN  = tmpInfo(1).Height;
                    widthIN   = tmpInfo(1).Width;
                    depthIN   = tmpInfo(1).SamplesPerPixel;
                    nFramesIN = numel(tmpInfo);
                    nBitsIN   = tmpInfo(1).BitDepth;
                    framesABS = {1:nFramesIN};
                    framesREL = {1:nFramesIN};
                    if numel(fileIN) > 1
                        for i = 2:numel(fileIN)
                            framesCUR    = numel(imfinfo(fileIN{i}));
                            framesABS{i} = framesABS{i-1}(end)+(1:framesCUR);
                            framesREL{i} = 1:framesCUR;
                            nFramesIN    = nFramesIN + framesCUR;
                        end
                    end
                    if     round(nBitsIN/depthIN) == 8,  imgClassIN = 'uint8';
                    elseif round(nBitsIN/depthIN) == 16, imgClassIN = 'uint16';
                    elseif round(nBitsIN/depthIN) == 32, imgClassIN = 'single';
                    elseif round(nBitsIN/depthIN) == 64, imgClassIN = 'double';
                    else,                                imgClassIN = [];
                    end
                case {'.mj2' '.mp4' '.avi'}
                    if numel(fileIN) > 1
                        error(sprintf('%s:Input',mfilename),...
                            'Multiple input files not supported for MJ2, MP4 or AVI files');
                    end
                    mov       = VideoReader(fileIN{1});
                    heightIN  = mov.Height;
                    widthIN   = mov.Width;
                    nFramesIN = floor(mov.Duration*mov.FrameRate);
                    nBitsIN   = mov.BitsPerPixel;
                    if ismember(mov.VideoFormat,{'Mono16 Signed','Mono8 Signed','RGB24 Signed','RGB48 Signed'})
                        error(sprintf('%s:Input',mfilename),...
                            'Video contains signed values, which are currently not supported');
                    end
                    if ismember(mov.VideoFormat,{'Grayscale','Indexed','Mono16','Mono8','Mono16 Signed','Mono8 Signed'}), depthIN = 1;
                    else,depthIN = 3;
                    end
                    if     round(nBitsIN/depthIN) == 8,  imgClassIN = 'uint8';
                    elseif round(nBitsIN/depthIN) == 16, imgClassIN = 'uint16';
                    elseif round(nBitsIN/depthIN) == 32, imgClassIN = 'single';
                    elseif round(nBitsIN/depthIN) == 64, imgClassIN = 'double';
                    else,                                imgClassIN = [];
                    end
                case '.dat'
                    if numel(fileIN) > 1
                        error(sprintf('%s:Input',mfilename),...
                            'Multiple input files not supported for DAT files');
                    end
                    [isDat,~,data] = Videomap.isMyDAT(fileIN{1});
                    if ~isDat
                        warning(sprintf('%s:Input',mfilename),...
                            'Given DAT file ''%s'' does not seem to be a DAT file of class ''Videomap'', no conversion performed',fileOUT);
                        fileOUT = '';
                        return;
                    end
                    heightIN   = data.nY;
                    widthIN    = data.nX;
                    depthIN    = data.nZ;
                    nFramesIN  = data.nFrames;
                    imgClassIN = data.class;
                    nBitsIN    = data.nBits;
                    if isempty(memmap)
                        memmap = data.memmap;
                    end
                case 'numeric'
                    [heightIN, widthIN, depthIN, nFramesIN] = size(fileIN);
                    imgClassIN                              = class(fileIN);
                    switch imgClassIN
                        case'uint8'
                            nBitsIN = 8;
                        case 'uint16'
                            nBitsIN = 16;
                        case'single'
                            nBitsIN = 32;
                        case'double'
                            nBitsIN = 64;
                    end
            end
            %
            % apply image transformation and get new size
            img                             = zeros(heightIN,widthIN,depthIN,1,imgClassIN);
            img                             = Videomap.applyTransform(img,transform);
            [heightOUT, widthOUT, depthOUT] = size(img);
            imgClassOUT                     = class(img);
            % check again
            if isempty(imgClassOUT) || ~ismember(imgClassOUT,{'uint8', 'uint16', 'single', 'double'})
                if isnumeric(fileIN), fileIN = {'numeric input'}; end
                warning(sprintf('%s:Input',mfilename),['Source file ''%s'' does not seem to contain uint8, ',...
                    'uint16, single or double data for class ''Videomap'', no conversion performed'],fileIN{1});
                fileOUT = '';
                return;
            end
            if strcmp(imgClassOUT,'uint8') %#ok<STISA>
                nBitsOUT = 8;
            elseif strcmp(imgClassOUT,'uint16') %#ok<STISA>
                nBitsOUT = 16;
            elseif strcmp(imgClassOUT,'single') %#ok<STISA>
                nBitsOUT = 32;
            elseif strcmp(imgClassOUT,'double') %#ok<STISA>
                nBitsOUT = 64;
            else
                error(sprintf('%s:Input',mfilename),...
                    'Unknown class for image data ''%s''',imgClassOUT);
            end
            %
            % determine frames to use
            if ~isempty(idxFrames)
                idxFrames = reshape(idxFrames,1,[]);
                idxFrames(idxFrames > nFramesIN) = [];
                if numel(idxFrames) < 2
                    warning(sprintf('%s:Input',mfilename),...
                        'No frames left in source file ''%s'', no conversion performed',fileIN{1});
                    fileOUT = '';
                    return
                end
            else
                idxFrames = 1:nFramesIN;
            end
            nFramesOUT = numel(idxFrames);
            nDig       = 1+ceil(log10(nFramesOUT));
            %
            % determine memmap
            if isempty(memmap)
                totalSizeIN  = widthIN* heightIN* depthIN* nBitsIN* nFramesIN /8/1024^2;
                totalSizeOUT = widthOUT*heightOUT*depthOUT*nBitsOUT*nFramesOUT/8/1024^2;
                memmap       = double(max(totalSizeIN,totalSizeOUT) > opt.chunkSize);
            end
            %
            % delete/create or append file
            if strcmp(ext,'.dat') && isempty(transform) && ~forceNew && isequal(idxFrames,1:nFramesIN) && ...
                    (widthIN == data.nX && heightIN == data.nY && depthIN == data.nZ)
                % conversion form DAT to DAT only necessary if a transformation is performed,
                % explicitly asked for it or the size does not match
                fprintf('DAT file ''%s'' [nY nX nZ nFrames] = [%d %d %d %d] seems to be up to date, no conversion performed\n',fileIN{1},data.nY,data.nX,data.nZ,data.nFrames);
                return;
            elseif strcmp(ext,'.dat')
                % rename existing file to temporary name and create new file
                tmpName = @(x) fullfile(path,sprintf('%s_temp-%d.dat', name, x));
                k       = 1;
                while exist(tmpName(k),'file') == 2 && numel(dir(tmpName(k))) > 0, k = k + 1; end
                stat = movefile(fileIN{1},tmpName(k));
                if ~stat
                    warning(sprintf('%s:Input',mfilename),...
                        'Could not move ''%s'' to temporary file ''%s'' for conversion, no conversion performed',...
                        fileIN{1},tmpName(k));
                    fileOUT = '';
                    return;
                end
                fileOUT   = fileIN{1};
                fileIN{1} = tmpName(k);
                tmpMap    = memmapfile(fileIN{1},'Writable',false,'Repeat',1,'Offset',1024, ...
                    'Format',{data.class,[data.nY data.nX data.nZ data.nFrames],'cdata'});
            elseif ismember(ext,{'.tif' '.mj2' '.mp4' '.avi' 'numeric'})
                if forceNew
                    % delete existing DAT file
                    delete(fileOUT);
                end
            end
            %
            % write header for new file
            if numel(dir(fileOUT)) == 1
                fid = fopen(fileOUT,'r+');
            else
                fid = fopen(fileOUT,'W');
            end
            fseek(fid, 0, 'bof');
            fwrite(fid,uint64(heightOUT),     'uint64');
            fwrite(fid,uint64(widthOUT),      'uint64');
            fwrite(fid,uint64(depthOUT),      'uint64');
            fwrite(fid,uint64(nFramesOUT),    'uint64');
            fwrite(fid,uint64(nBitsOUT),      'uint64');
            fwrite(fid,uint64(memmap),        'uint64');
            fwrite(fid,zeros(1,122,'uint64'), 'uint64');
            %
            % create memory map and transfer image data in chunks
            if isnumeric(fileIN)
                fprintf('Preparing DAT file ''%s'' for conversion of %d frames from numeric input\n',fileOUT,numel(idxFrames));
            else
                fprintf('Preparing DAT file ''%s'' for conversion of %d frames from source file ''%s''\n',fileOUT,numel(idxFrames),fileIN{1});
            end
            if memmap == 1
                framesChunkIN  = opt.chunkSize/(widthIN* heightIN* depthIN* nBitsIN  /8/1024^2);
                framesChunkOUT = opt.chunkSize/(widthOUT*heightOUT*depthOUT*nBitsOUT /8/1024^2);
                framesChunk    = max(1,ceil(min(framesChunkIN,framesChunkOUT)));
                switch ext
                    case '.tif'
                        % disable a warning (restore afterwards) and copy TIF images in chunks
                        ws = warning; warning('off','MATLAB:imagesci:tiffmexutils:libtiffWarning');
                        for i = 1:numel(fileIN)
                            % find for current file which frames must be extracted
                            [idxOK,idx] = ismember(idxFrames,framesABS{i});
                            idx         = idx(idxOK);
                            curABS      = framesABS{i}(idx);
                            curREL      = framesREL{i}(idx);
                            curNUM      = numel(curREL);
                            if curNUM > 0
                                curDone     = 0;
                                mytif       = Tiff(fileIN{i}, 'r');
                                value       = zeros(heightIN,widthIN,depthIN,min(curNUM,framesChunk),imgClassIN);
                                while curDone < curNUM
                                    curIDX = (curDone + 1):min(curNUM,curDone+framesChunk);
                                    fprintf('  %*d of %*d frames in the range %*d to %*d\n',...
                                        nDig,numel(curIDX),nDig,nFramesOUT,nDig,min(curABS(curIDX)),nDig,max(curABS(curIDX)));
                                    for k = 1:numel(curIDX)
                                        mytif.setDirectory(curREL(curIDX(k)));
                                        value(:,:,:,k) = mytif.read();
                                    end
                                    fwrite(fid,Videomap.applyTransform(value(:,:,:,1:numel(curIDX)),transform),imgClassOUT);
                                    curDone = curIDX(end);
                                end
                                close(mytif);
                            end
                        end
                        warning(ws);
                    case {'.mj2' '.mp4' '.avi'}
                        freq       = mov.FrameRate;
                        framesDone = 0;
                        value      = zeros(heightIN,widthIN,depthIN,min(nFramesIN,framesChunk),imgClassIN);
                        while framesDone < nFramesOUT
                            curFrames = (framesDone + 1):min(nFramesOUT,framesDone+framesChunk);
                            fprintf('  %*d of %*d frames in the range %*d to %*d\n',...
                                nDig,numel(curFrames),nDig,nFramesOUT,nDig,min(curFrames),nDig,max(curFrames));
                            for k = 1:numel(curFrames)
                                mov.CurrentTime = (idxFrames(curFrames(k))-1)/freq;
                                value(:,:,:,k)  = readFrame(mov);
                            end
                            fwrite(fid,Videomap.applyTransform(value(:,:,:,1:numel(curFrames)),transform),imgClassOUT);
                            framesDone = curFrames(end);
                        end
                    case '.dat'
                        framesDone = 0;
                        tmpData    = tmpMap.Data;
                        while framesDone < nFramesOUT
                            curFrames = (framesDone + 1):min(nFramesOUT,max(framesDone + 1,framesDone+framesChunk));
                            fprintf('  %*d of %*d frames in the range %*d to %*d\n',...
                                nDig,numel(curFrames),nDig,nFramesOUT,nDig,min(curFrames),nDig,max(curFrames));
                            fwrite(fid,Videomap.applyTransform(tmpData.cdata(:,:,:,idxFrames(curFrames)),transform),imgClassOUT);
                            framesDone = curFrames(end);
                        end
                        tmpData = []; %#ok<NASGU>
                        tmpMap  = []; %#ok<NASGU>
                    case 'numeric'
                        fprintf('  %*d of %*d frames in the range %*d to %*d\n',...
                                nDig,nFramesOUT,nDig,nFramesOUT,nDig,min(nFramesOUT),nDig,max(nFramesOUT));
                        fwrite(fid,Videomap.applyTransform(fileIN(:,:,:,idxFrames),transform),imgClassOUT);
                end
            elseif memmap == 0
                fprintf('  %*d of %*d frames in the range %*d to %*d\n',...
                    nDig,nFramesOUT,nDig,nFramesOUT,nDig,min(idxFrames),nDig,max(idxFrames));
                switch ext
                    case '.tif'
                        if numel(fileIN) > 1
                            error(sprintf('%s:Input',mfilename),...
                                'Multiple input TIF files only supported in combination with memory mapping');
                        end
                        % option 1: 3rd party saveastiff
                        % value = loadtiff(fileIN);
                        % if ndims(value) ~= 4, value = permute(value,[1 2 4 3]); end
                        % value = value(:,:,:,idxFrames);
                        %
                        % option 2: MATLAB's imread
                        info       = imfinfo(fileIN{1});
                        num_images = numel(info);
                        value      = imread(fileIN{1}, 1, 'Info', info);
                        value      = repmat(value,  [1 1 1 num_images]);
                        for k = 2:num_images
                            value(:,:,:,k) = imread(fileIN{1}, k, 'Info', info);
                        end
                    case {'.mj2' '.mp4' '.avi'}
                        vid  = VideoReader(fileIN{1});
                        nVid = floor(vid.Duration * vid.FrameRate);
                        if max(idxFrames) > nVid
                            error(sprintf('%s:Input',mfilename),...
                                'Maximum requested frame number of %d exceeds available number of frames of %d',...
                                max(idxFrames),nVid);
                        end
                        vidTime         = (idxFrames-1)/vid.Framerate;
                        vid.CurrentTime = vidTime(1);
                        value           = readFrame(vid);
                        value           = repmat(value,[1 1 1 numel(idxFrames)]);
                        for n = 2:numel(idxFrames)
                            vid.CurrentTime = vidTime(n);
                            value(:,:,:,n)  = readFrame(vid);
                        end
                    case '.dat'
                        value = tmpMap.Data.cdata(:,:,:,idxFrames);
                    case 'numeric'
                        value = fileIN(:,:,:,idxFrames);
                end
                tmpMap  = []; %#ok<NASGU>
                % apply transformation
                if ~isempty(transform)
                    value = Videomap.applyTransform(value,transform);
                end
                % write data to file
                fwrite(fid,value,imgClassOUT);
            else
                error(sprintf('%s:Input',mfilename),...
                    'Unknown memory mapping mode ''%d'' at this position, please check!',memmap);
            end
            fclose(fid);
            if strcmp(ext,'.dat')
                % delete temporary file
                delete(fileIN{1});
            end
            if isnumeric(fileIN)
                fprintf('  Finished conversion of numeric video input to DAT file ''%s''\n',fileOUT);
            else
                fprintf('  Finished conversion of source file ''%s'' to DAT file ''%s''\n',fileIN{1},fileOUT);
            end
        end
        
        function [fileOUT, fileIN]                  = convert2VID(fileIN,varargin)
            %convert2VID Converts single image files to a multipage TIF, AVI, MJ2 or MP4
            % file that can be read with the Videomap class. It supports a custom read function for
            % otherwise unknown input files and can apply simple image transformations during the
            % processing, optional input is processed with input parser (see code).
            %
            % The input filenames can be given as char that is evaluated by the DIR function to
            % retrieve the actual filnames, e.g. use something like '*.tif' to convert all TIF files
            % in the current folder. The output of a DIR call is also accepted as input, e.g. to
            % convert only a specific set of files. A cellstr is accepted as well, but will be
            % transformed to a DIR output assuming a constant file size (based on the first file).
            % Provide a custom import function to read files that cannot be read by MATLAB's imread
            % function.
            
            %
            % check filename input
            if nargin < 1 || isempty(fileIN)
                fileOUT = {};
                return;
            elseif iscellstr(fileIN)
                tmp = dir(fileIN{1});
                if ~(numel(tmp) == 1 && ~tmp.isdir)
                    error(sprintf('%s:Input',mfilename),'Could not find the first file, please check!');
                end
                fileIN = struct('name',fileIN,'bytes',num2cell(repmat(tmp.bytes,size(fileIN))));
            elseif ~(ischar(fileIN) || (isstruct(fileIN) && ...
                    all(ismember({'name','bytes'},fieldnames(fileIN)))))
                error(sprintf('%s:Input',mfilename),'Unknown input for filename(s)');
            end
            if ischar(fileIN)
                fileIN                 = dir(fileIN);
                fileIN([fileIN.isdir]) = [];
            end
            if numel(fileIN) < 1, return; end
            %
            % use input parser to process options
            opt               = inputParser;
            opt.StructExpand  = true;
            opt.KeepUnmatched = false;
            % absolute basename for filename to use, empty value leads to an artifical name based on
            % the input file names
            opt.addParameter('filename', [], ...
                @(x) isempty(x) || (ischar(x) && numel(x) > 0));
            % profile to use
            opt.addParameter('profile', 'TIF', ...
                @(x) ischar(x) && ismember(x,{'MPEG-4','Archival','Motion JPEG AVI','Motion JPEG 2000','TIF'}));
            % framerate if supported by profile
            opt.addParameter('framerate', 10, ...
                @(x) isnumeric(x) && isscalar(x) && x>0);
            % overwrite files
            opt.addParameter('overwrite', true, ...
                @(x) islogical(x) && isscalar(x));
            % transformation that should be applied when writing data to video file
            opt.addParameter('transform', [], ...
                @(x) isempty(x) || isa(x,'function_handle') || isa(x,'affine2d') || ...
                isa(x,'cameraParameters') || (iscell(x) && isa(x{1},'function_handle')));
            % a custom read function to read given files, should return a single image when a single
            % filename is given as input,
            opt.addParameter('import', [], ...
                @(x) isempty(x) || isa(x,'function_handle'));
            opt.parse(varargin{:});
            opt = opt.Results;
            %
            % prepare new filename
            if isempty(opt.filename)
                [path,name] = fileparts(fileIN(1).name);
                name        = sprintf('%s_convert2VID_%dFiles_%s',...
                    name, numel(fileIN), datestr(datetime('now'),'yyyy-MM-dd-HH-mm-ss'));
            else
                [path,name] = fileparts(opt.filename);
            end
            switch opt.profile
                case {'MPEG-4' 'Archival' 'Motion JPEG AVI' 'Motion JPEG 2000'}
                    mov           = VideoWriter(fullfile(path,name),opt.profile);
                    mov.FrameRate = opt.framerate;
                    fileOUT      = mov.Filename;
                case 'TIF'
                    fileOUT = fullfile(path,[name '.tif']);
            end
            if ~opt.overwrite && exist(fileOUT,'file') == 2 && numel(dir(fileOUT)) == 1
                warning(sprintf('%s:Conversion',mfilename),['File ''%s'' already exists and overwriting ',...
                    'is disabled, no data exported'], fileOUT);
                return;
            end
            imgMem = sum([fileIN.bytes])/1024^2;
            fprintf('Conversion starts for %.2f MiB in %d files (''%s'', ...) to new file ''%s''\n', ...
                imgMem, numel(fileIN), fileIN(1).name, fileOUT);
            %
            % read an example image
            if isempty(opt.import), func = @imread;
            else,                   func = opt.import;
            end
            try
                img = func(fileIN(1).name);
                img = Videomap.applyTransform(img,opt.transform);
            catch err
                error(sprintf('%s:Conversion',mfilename),['Reading the first image ''%s'' as a test ',...
                    'resulted in an error, please check error report:\n%s'], fileIN(1).name, err.getReport);
            end
            %
            % read data and write to new file
            nDig = 1+ceil(log10(numel(fileIN)));
            nImg = numel(fileIN);
            switch opt.profile
                case {'MPEG-4' 'Archival' 'Motion JPEG AVI' 'Motion JPEG 2000'}
                    if ~(isa(img,'double') || isa(img,'single') || isa(img,'uint8'))
                        error(sprintf('%s:Conversion',mfilename),['Current data of file ''%s'' is of ',...
                            'class ''%s'' including any transformation, which is not supported by ',...
                            'the selected profile ''%s'', please modify profile or transformation!'],...
                            fileIN(1).name, class(img), opt.profile);
                    end
                    mov.open;
                    try
                        for n = 1:nImg
                            fprintf('  %*d of %*d frames: %*d to %*d\n',...
                                nDig,1,nDig,nImg,nDig,n,nDig,n);
                            img = func(fileIN(n).name);
                            img = Videomap.applyTransform(img,opt.transform);
                            writeVideo(mov,img);
                        end
                    catch err
                        mov.close;
                        error(sprintf('%s:Conversion',mfilename),['Reading file ''%s'' resulted in an ',...
                            'error, please check error report:\n%s'], fileIN(n).name, err.getReport);
                        
                    end
                    mov.close
                case 'TIF'
                    % write to TIF with LZW compression (should make sure imageJ can read it), use
                    % 64 bit addressing when writing big files with FEX submission saveastiff,
                    % otherwise use MATLAB's imwrite
                    options.color   = size(img,3) > 1;
                    options.comp    = 'lzw';
                    options.message = true;
                    options.ask     = false;
                    options.append  = false;
                    options.big     = imgMem > 3500;
                    try
                        if options.big
                            for n = 1:nImg
                                fprintf('  %*d of %*d frames: %*d to %*d: ',...
                                    nDig,1,nDig,nImg,nDig,n,nDig,n);
                                img = func(fileIN(n).name);
                                img = Videomap.applyTransform(img,opt.transform);
                                saveastiff(squeeze(img),fileOUT,options);
                                options.append = true;
                            end
                        else
                            for n = 1:nImg
                                fprintf('  %*d of %*d frames: %*d to %*d\n',...
                                    nDig,1,nDig,nImg,nDig,n,nDig,n);
                                img = func(fileIN(n).name);
                                img = Videomap.applyTransform(img,opt.transform);
                                if n == 1, imwrite(img,fileOUT);
                                else,      imwrite(img,fileOUT,'WriteMode','append');
                                end
                            end
                        end
                    catch err
                        error(sprintf('%s:Conversion',mfilename),['Reading file ''%s'' resulted in an ',...
                            'error, please check error report:\n%s'], fileIN(n).name, err.getReport);
                    end
            end
            fprintf('  Finished exporting to file ''%s''\n',fileOUT);
        end
    end
end