classdef Video < matlab.mixin.Copyable
    %Video Class to handle video data from high speed or stroboscopic experiments
    %   The class is supposed to help handling video data as recorded, for example, by a high speed
    %   camera. The chip of the camera is referred to as CCD, although it makes no difference - at
    %   least in this class - whether the video data is recorded with a CCD, CMOS or similar camera
    %   that records gridded data with a constant pixel resolution in x and y direction. The actual
    %   data handling for each single video is performed with the Videomap class that supports
    %   memory mapping for large files.
    %
    %   Global xyz coordinate system: x is the vertical component aligned with gravity, y the
    %   horizontal component and z is along the laser beam, the positon of the CCD needs to be given
    %   in this coordinate system, the following sketches should clarify the different views
    %   depending on the given norm:
    %
    %   norm = [0 0 1]: image is supposed to show:
    %   y <---|
    %         |
    %         v
    %         x
    %
    %   norm = [0 0 -1]: image is supposed to show:
    %         |---> y
    %         |
    %         v
    %         x
    %
    %   norm = [0 1 0]: image is supposed to show:
    %         |---> z
    %         |
    %         v
    %         x
    %
    %   norm = [0 -1 0]: image is supposed to show:
    %   z <---|
    %         |
    %         v
    %         x
    %
    %   norm = [1 0 0]: image is supposed to show:
    %   z <---|
    %         |
    %         v
    %         y
    %
    %   norm = [-1 0 0]: image is supposed to show:
    %         |---> z
    %         |
    %         v
    %         y
    %
    %   Video/image coordinate system: The image coordinate system is the typical xy sytem for
    %   images with x being the horizontal and y the vertical direction. The origiin is the top left
    %   corner of the image. The depth of the image (i.e. for RGB color) is the z axis.
    %
    % Implementation Notes:
    %   * The data is handeld by the Videomap class, which supports memory mapping with MATLAB's
    %     builtin memmapfile, but also loading all video data to memory.
    %   * The actual image data is not stored when the video object is saved to disk with MATLAB's
    %     save method (the actual data is handeld by the Videomap class), please use the store and
    %     recall methods to store the data to disk.
    %   * Private p_<something> properties are uses for two purposes: First, to store computational
    %     expensive properties that can be accessed by the user via a <something> property (used for
    %     xGrid for example). Second, to have two different set methods: one for the public
    %     <something> property that performs error checking and the private set method without any
    %     test (so no implementation at all) for in class access (used for memmap for example).
    %   * All properties are transient since they should get restored from the MAT file that is
    %     updated/created during the save process
    %
    %----------------------------------------------------------------------------------
    %   Copyright 2016 Alexander Ludwig Klein, alexludwigklein@gmail.com
    %
    %   Physics of Fluids, University of Twente
    %----------------------------------------------------------------------------------
    
    %% Properties
    properties (GetAccess = public, SetAccess = public, Dependent = true)
        % device Name of device used to record video (string)
        device
        % comment Comment on device, measurement, etc. (cellstr)
        comment
        % name Name of video, returns filename if it is left empty (string)
        name
        % map A map to map indexed cdata to a colormap or some other quantity (nM x 3 double)
        map
        % norm CCD normal in global xyz coordinate system (3 x double)
        norm
        % date Date of measurement (datetime)
        date
        % userdata User data linked to object (should be a scalar structure for many applications, but can be arbitrary)
        userdata
        % cdata Image data as 4D array (nX x nY x 1 or 3 x nFrames) but can also be used to access any variable in MAT file of video (see Videomap) (Videomap)
        cdata
        % temp Temporary data linked to object, i.e. during post processing, gets easily overwritten (anything)
        temp
        % pos Position in m of CCD center ([xCCD yCCD zCCD]) in global xyz coordinate system (3 x double)
        pos
        % pixres Pixel resolution in m/pixel of cdata in x and y direction of image (2 x double)
        pixres
        % pixresX Pixel resolution in m/pixel of cdata in x direction of image (2 x double)
        pixresX
        % pixresY Pixel resolution in m/pixel of cdata in y direction of image (2 x double)
        pixresY
        % pixresR Equivalent pixel resolution (quadratic pixel with same area) in m/pixel of cdata in x and y direction of image (double)
        pixresR
        % pixresM Mean pixel resolution in m/pixel of cdata in x and y direction of image (double)
        pixresM
        % filename Filename of video file (string)
        filename
        % xCCD X position in m of CCD center in global xyz coordinate system (double)
        xCCD
        % yCCD Y position in m of CCD center in global xyz coordinate system (double)
        yCCD
        % zCCD Z position in m of CCD center in global xyz coordinate system (double)
        zCCD
        % z Coordinate along z axis in m, same as zCCD (double)
        z
        % memmap The mode of memory mapping (double)
        %
        % 0 or false: no memory mapping at all, instead reading the complete SRC file into memory
        %  1 or true: full memory mapping with read and write access, requires to create a DAT file
        %          2: memory mapping with read-only access by a VideoReader, no DAT file is required
        %          3: memory mapping with read-only access by a TIFFStack, no DAT file is required
        memmap
        % time Time(s) in s of each frame in cdata relative to date ((1,2,..) x nFrames double)
        time
        % exposure Exposure(s) of each frame in s ((1,2,..) x nFrames double)
        exposure
        % lock Locks object to prevent any change to its data (logical)
        lock
        % ud Short for userdata (see userdata)
        ud
        % track Structure to hold tracking information ROIs (<number of ROIS> x structure)
        track
        % player Place to store the video player that shows video object (string)
        player
        % transform See Videomap for information, video object just takes care of storage and makes it easier to access
        transform
        % bufferData True/false whether to keep grids or memory expensive results in memory (logical)
        %
        % Note: when set to true, large grids such as xGrid are kept in memory after they are used
        % for the first time. This is an advantage in terms of speed, but requires more memory.
        bufferData
        % minimizeStore True/false whether to store data to MAT file only if data has changed (logical)
        %
        % The change of data is checked by computing a MD5 hash value with a third party tool. The
        % MAT file on disk is only touched in case the hash value has changed.
        minimizeStore
    end
    
    properties (GetAccess = protected, SetAccess = protected, Dependent = true)
        % p_transform Same as transform, for convenience
        p_transform
    end
    
    properties (GetAccess = public, SetAccess = protected, Dependent = true)
        % props2Disk Properties that are stored on disk for each movie (cellstr)
        props2Disk
        % nX Number of pixel along x axis in image coordinate system (double)
        nX
        % nY Number of pixel along y axis in image coordinate system (double)
        nY
        % nZ Number of pixel along z axis in image coordinate system (double)
        nZ
        % nFrames Number of frames (double)
        nFrames
        % x Coordinates of pixels along image x axis in m (nX double)
        x
        % y Coordinates of pixels along image y axis in m (nX double)
        y
        % xStr String of global axis along image x axis (char)
        xStr
        % yStr String of global axis along image y axis (char)
        yStr
        % xIdx Index of image x axis in global coordinate system (double)
        xIdx
        % yIdx Index of image y axis in global coordinate system (double)
        yIdx
        % xDir Orientation of global axis along image x axis (1: with image axis, -1: vice versa) (double)
        xDir
        % yDir Orientation of global axis along image y axis (1: with image axis, -1: vice versa) (double)
        yDir
        % xGrid Grid of CCD for image x in m (nX x nY double)
        xGrid
        % yGrid Grid of CCD for image y in m (nX x nY double)
        yGrid
        % zGrid Grid of CCD for image z in m (nX x nY double)
        zGrid
        % cdataClass Class of cdata, i.e. 'uint8', 'uint16', 'single' or 'double' (string)
        cdataClass
        % memory Estimate for the memory usage in MiB for image data in object (double)
        memory
        % memoryDisk Estimate for the memory usage in MiB for image data of object on disk (double)
        memoryDisk
        % isChanged True/false whether video data is changed since object was created or saved the last time (logical)
        isChanged
        % isLinked True/false whether the video data is linked to a file, i.e. a file is kept open (logical)
        isLinked
        % info Cellstr with information on video (cellstr)
        info
        % ref2d Reference 2-D image to world coordinates (cannot handle reversed orientation of axes, leads to issues) (imref2d)
        ref2d
        % backupData The stored backup data (structure)
        backupData
    end
    
    properties (GetAccess = protected, SetAccess = protected, Transient = true)
        % p_props2Disk Storage for props2Disk of this class, the superclass
        p_props2Disk_sup = {'device','comment','map','pixres','pos','norm','date','userdata','time',...
            'exposure','name','track','transform','bufferData','minimizeStore'};
        % p_props2Disk Storage for props2Disk
        p_props2Disk = [];
        % p_x Storage for x
        p_x          = [];
        % p_y Storage for y
        p_y          = [];
        % p_xGrid Storage for xGrid
        p_xGrid      = [];
        % p_yGrid Storage for yGrid
        p_yGrid      = [];
        % p_xStr Storage for xStr
        p_xStr       = [];
        % p_yStr Storage for yStr
        p_yStr       = [];
        % p_xIdx Storage for xIdx
        p_xIdx       = [];
        % p_yIdx Storage for yIdx
        p_yIdx       = [];
        % p_xDir Storage for xDir
        p_xDir       = [];
        % p_yDir Storage for yDir
        p_yDir       = [];
        % p_time Storage for time (needed to access other property in set method)
        p_time       = NaN;
        % p_exposure Storage for exposure (needed to access other property in set method)
        p_exposure   = NaN;
        % p_pixres Storage for pixres (needed to access other property in set method)
        p_pixres     = [1 1];
        % p_pos Storage for position (needed to access other property in set method)
        p_pos        = zeros(1,3);
        % device Storage for device (needed to access other property in set method)
        p_device     = '<undefined>';
        % comment Storage for comment (needed to access other property in set method)
        p_comment    = {'<undefined>'};
        % name Storage for name (needed to access other property in set method)
        p_name       = '<undefined>';
        % map Storage for map (needed to access other property in set method)
        p_map        = [];
        % norm Storage for norm (needed to access other property in set method)
        p_norm       = [0 -1 0];
        % date Storage for date (needed to access other property in set method)
        p_date       = datetime('now');
        % userdata Storage for userdata (needed to access other property in set method)
        p_userdata   = [];
        % cdata Storage for cdata (needed to access other property in set method)
        p_cdata      = Videomap;
        % temp Storage for temp (needed to access other property in set method)
        p_temp       = [];
        % ref2d Storage for ref2d
        p_ref2d      = [];
        % p_player Storage for player
        p_player     = [];
        % p_backupData Storage for backup data
        p_backupData = [];
        % p_bufferData Storage for bufferData
        p_bufferData = true;
        % p_minimizeStore A hash value of the data that is stored to disk or -1 in case the feature is disabled (char)
        %
        % The MAT file on disk is only touched in case the hash value has changed, to avoid saving
        % to disk to often.
        p_minimizeStore = '';
        % p_hashfunc A function handle to create a hash value from a structure (char or function handle)
        p_hashfunc = '';
        % p_nFrames Storage for Videomap property for faster access in Video class
        p_nFrames       = [];
        % p_nX Storage for Videomap property for faster access in Video class
        p_nX            = [];
        % p_nY Storage for Videomap property for faster access in Video class
        p_nY            = [];
        % p_nZ Storage for Videomap property for faster access in Video class
        p_nZ            = [];
        % p_memoryDisk Storage for Videomap property for faster access in Video class
        p_memoryDisk    = [];
    end
    
    properties (GetAccess = {?Video,?Videoplayer}, SetAccess = {?Video,?Videoplayer}, Transient = true)
        % p_track Storage for track (for faster access)
        p_track    = struct('imroi',{},'position',{},'color',{},'name',{});
    end
    
    %% Events
    events
        % showPlayer Shows video player
        showPlayer
        % deletePlayer Delete video player
        deletePlayer
        % exitPlayer Exit video player
        exitPlayer
        % disableTrack Disable display of any track
        disableTrack
        % enableTrack Enable display of any track
        enableTrack
        % resetPlayer Reset video player
        resetPlayer
        % updatePlayer Updates video player
        updatePlayer
    end
    
    %% Constructor, SET/GET
    methods
        function obj   = Video(filename, varargin)
            % Video Class constructor accepting one (string as first input) or more filename(s)
            % (cellstr as first input) as well as options that are passed to an inputparser. Instead
            % of the filename(s) an existing object can be given as input, which gets copied in that
            % case. A numeric input for the filename leads to the allocation of an array of Video
            % objects with the given number of elements.
            
            % check input
            if nargin < 1
                filename = [];
            elseif ~(ischar(filename) || iscellstr(filename) || strcmp(class(filename),class(obj)) ||...
                    (isnumeric(filename) && isscalar(filename) && min(filename) >= 0) || ...
                    isempty(filename))
                error(sprintf('%s:Input',mfilename),'Unknown input for filename');
            end
            % use input parser to process options
            opt               = inputParser;
            opt.StructExpand  = true;
            opt.KeepUnmatched = false;
            % true/false whether to enable/disable memory mapping (overwrites setting in an existing
            % DAT file), supply an empty value to get default settings (changing the default to true
            % here should enable memory mapping by default)
            opt.addParameter('memmap', [], ...
                @(x) isempty(x) || ((islogical(x) || isnumeric(x)) && isscalar(x)));
            % true/false whether to ignore any existing DAT file and prefer to start from the source
            % file again
            opt.addParameter('ignoreDAT', false, ...
                @(x) islogical(x) && isscalar(x));
            % chunkSize Size in MiB that can be loaded in one go into memory
            opt.addParameter('chunkSize', 1024, ...
                @(x) isnumeric(x) && isscalar(x) && min(x)>0);
            % transform Transform property for videomap
            opt.addParameter('transform', [], ...
                @(x) isempty(x) || isa(x,'function_handle') || isa(x,'affine2d') || ...
                isa(x,'cameraParameters') || (iscell(x) && isa(x{1},'function_handle')));
            % true/false whether to buffer data, see class property bufferData
            opt.addParameter('bufferData', true, ...
                @(x) islogical(x) && isscalar(x));
            % true/false whether to minimize disk access, see class property minimizeStore
            opt.addParameter('minimizeStore', true, ...
                @(x) islogical(x) && isscalar(x));
            opt.parse(varargin{:});
            opt = opt.Results;
            if islogical(opt.memmap), opt.memmap = double(opt.memmap); end
            if ~isempty(opt.memmap) && ~(opt.memmap >= 0 && opt.memmap <= 3)
                error(sprintf('%s:Input',mfilename),...
                    'Unknown memory mapping mode ''%d'', please check!',opt.memmap);
            end
            % find a hash function
            if ~isempty(which('GetMD5'))
                hashFunc = @(x) GetMD5(x,'Array');
            elseif ~isempty(which('DataHash'))
                hashFunc = @(x) DataHash(x);
            else
                warning(sprintf('%s:Input',mfilename),['No hash function could be found and the ',...
                    'minimizeStore feature will have no effect for object of class ''%s'''],class(obj));
                hashFunc = '';
            end
            % process input
            if isempty(filename)
                % just return object with default values but make sure a new Videomap is created,
                % otherwise MATALB may use a previous default!
                obj.p_hashfunc = hashFunc;
                obj.p_cdata    = Videomap([],'master',obj);
            elseif ischar(filename) || iscellstr(filename)
                % create cellstr of filenames
                if ischar(filename), filename = {filename}; end
                if numel(filename) < 1
                    % just return object with default values
                    obj.p_hashfunc = hashFunc;
                else
                    %
                    % create new Videomap object and allocate object of given size
                    nObj = numel(filename);
                    func = str2func(class(obj));
                    if nObj > 1
                        obj(nObj) = func();
                        % nDig    = 1+ceil(log10(nObj));
                        % fprintf('Reading %d %ss:\n',nObj,class(obj));
                    end
                    for i = 1:nObj
                        % if nObj > 1, fprintf('  %*d of %d: ''%s''\n',nDig,i,nObj,filename{i}); end
                        % add some data such as comment and date, it might get overwritten by
                        % recall, but it ensures a default value
                        obj(i).p_hashfunc = hashFunc; %#ok<AGROW>
                        obj(i).comment    = sprintf('%s read from input filename ''%s''',class(obj(i)),filename{i}); %#ok<AGROW>
                        tmp               = dir(filename{i});
                        if numel(tmp) == 1 && ~tmp.isdir
                            obj(i).date = datetime(tmp.date);%#ok<AGROW>
                        end
                        % read actual video data, this call also creates a unique Videomap object
                        % for all Video objects, which is very important to get unique Videos
                        obj(i).p_cdata = Videomap(filename{i},'memmap',opt.memmap,...
                            'ignoreDAT',opt.ignoreDAT,'chunkSize',opt.chunkSize,...
                            'transform',opt.transform,'master',obj(i));%#ok<AGROW>
                    end
                    %
                    % reshape and reload data from MAT file
                    obj = reshape(obj,size(filename));
                    p_recall(obj,true,false,true,'memmap',opt.memmap,...
                        'ignoreDAT',opt.ignoreDAT,'chunkSize',opt.chunkSize);
                end
            elseif strcmp(class(filename),class(obj))
                % copy input object
                obj = copy(filename);
            elseif isnumeric(filename)
                % allocate object of given size, but make sure each element in the array is a new
                % handle object (created by copying). The copy function makes sure a unique Videomap
                % object is created.
                if filename == 0
                    func = str2func([class(obj) '.empty']);
                    obj  = func();
                    obj.p_hashfunc = hashFunc;
                else
                    func           = str2func(class(obj));
                    tmp            = func();
                    tmp.p_hashfunc = hashFunc;
                    obj(filename)  = tmp;
                    for i = 1:(numel(obj)-1)
                        obj(i) = tmp.copy;
                        obj(i).p_hashfunc = hashFunc;
                    end
                end
            else
                error(sprintf('%s:Input',mfilename),'Unknown input for class ''%s''',class(obj));
            end
            % change bufferdata and minimizeStore in case they differs from default values (true)
            if ~opt.bufferData
                for i = 1:numel(obj)
                    obj(i).bufferData = opt.bufferData; %#ok<AGROW>
                end
            end
            if ~opt.minimizeStore
                for i = 1:numel(obj)
                    obj(i).minimizeStore = opt.minimizeStore; %#ok<AGROW>
                end
            end
        end
        
        function         set.props2Disk(obj,value)
            if iscellstr(value)
                obj.p_props2Disk = reshape(value,[],1);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for props2Disk');
            end
        end
        
        function value = get.props2Disk(obj)
            if isempty(obj.p_props2Disk)
                obj.p_props2Disk = unique(get_props2Disk(obj));
            end
            value = obj.p_props2Disk;
        end
        
        function         set.transform(obj,value)
            obj.p_cdata.transform = value;
        end
        
        function value = get.transform(obj)
            value = obj.p_cdata.transform;
        end
        
        function         set.p_transform(obj,value)
            obj.p_cdata.transform = value;
        end
        
        function value = get.p_transform(obj)
            value = obj.p_cdata.transform;
        end
        
        function         set.player(obj,value)
            if isempty(value)
                obj.p_player = [];
            elseif isa(value,'Videoplayer') && ismember(obj,value.vid)
                obj.p_player = value;
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for player');
            end
        end
        
        function value = get.player(obj)
            value = obj.p_player;
        end
        
        function         set.userdata(obj,value)
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if isempty(value)
                obj.p_userdata = [];
            elseif isstruct(value)
                obj.p_userdata = value;
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for userdata');
            end
        end
        
        function value = get.userdata(obj)
            value = obj.p_userdata;
        end
        
        function         set.ud(obj,value)
            obj.userdata = value;
        end
        
        function value = get.ud(obj)
            value = obj.p_userdata;
        end
        
        function         set.temp(obj,value)
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            obj.p_temp = value;
        end
        
        function value = get.temp(obj)
            value = obj.p_temp;
        end
        
        function         set.lock(obj,value)
            if islogical(value) && isscalar(value)
                obj.p_cdata.lock = value;
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for lock');
            end
        end
        
        function value = get.lock(obj)
            value = obj.p_cdata.lock;
        end
        
        function         set.bufferData(obj,value)
            if islogical(value) && isscalar(value)
                obj.p_bufferData = value;
                if ~value
                    obj.p_xGrid = [];
                    obj.p_yGrid = [];
                    obj.p_x     = [];
                    obj.p_y     = [];
                end
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for bufferData');
            end
        end
        
        function value = get.bufferData(obj)
            value = obj.p_bufferData;
        end
        
        function         set.minimizeStore(obj,value)
            if islogical(value) && isscalar(value)
                if value && ~obj.minimizeStore
                    obj.p_minimizeStore = '';
                elseif ~value && obj.minimizeStore
                    obj.p_minimizeStore = -1;
                end
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for minimizeStore');
            end
        end
        
        function value = get.minimizeStore(obj)
            value = ischar(obj.p_minimizeStore);
        end
        
        function         set.name(obj,value)
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if ischar(value) && ~strcmp(value,obj.p_name)
                obj.p_name = value;
                notify(obj,'resetPlayer');
            elseif ~ischar(value)
                error(sprintf('%s:Input',mfilename),'Input not valid for name');
            end
        end
        
        function value = get.name(obj)
            if isempty(obj.p_name)
                value = obj.filename;
            else
                value = obj.p_name;
            end
        end
        
        function         set.filename(obj,value)
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if ischar(value) && ~strcmp(value,obj.filename)
                % filename is new, don't do anything in case object is not memory mapped, in
                % case of memory mapping: recall video from new location (see also Videomap)
                if obj.memmap > 0
                    obj.p_cdata.filename = value;
                    p_recall(obj,false,true,true);
                else
                    obj.p_cdata.filename = value;
                end
                notify(obj,'resetPlayer');
            elseif ~ischar(value)
                error(sprintf('%s:Input',mfilename),'Input not valid for filename');
            end
        end
        
        function value = get.filename(obj)
            value = obj.p_cdata.filename;
        end
        
        function         set.map(obj,value)
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if isnumeric(value) && ~isequal(value,obj.p_map)
                obj.p_map = value;
                notify(obj,'resetPlayer');
            elseif ~isnumeric(value)
                error(sprintf('%s:Input',mfilename),'Input not valid for map');
            end
        end
        
        function value = get.map(obj)
            value = obj.p_map;
        end
        
        function         set.norm(obj,value)
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if isnumeric(value) && numel(value) == 3
                value = reshape(value,1,[]);
                if isequal(value,obj.p_norm), return; end
                if sum(value == 0) ~= 2
                    error(sprintf('%s:Input',mfilename),'Currently only CCD normals along on axis (e.g [1 0 0]) are supported');
                else
                    showTrack = hideTracks(obj);
                    normOld   = obj.p_norm;
                    normNew   = value;
                    for i = 1:numel(obj.p_track)
                        posROI = obj.p_track(i).position;
                        switch obj.p_track(i).imroi
                            case {'imellipse','imrect'}
                                obj.p_norm = normOld; obj.p_x = []; obj.p_y = [];
                                [x,y]      = transformCoordinates(obj,posROI(:,1)+posROI(:,3)/2,posROI(:,2)+posROI(:,4)/2,'real2pix'); %#ok<*PROPLC>
                                obj.p_norm = normNew; obj.p_x = []; obj.p_y = [];
                                [x,y]      = transformCoordinates(obj,x,y,'pix2real');
                                posROI(:,1:2) = [x-posROI(:,3)/2,y-posROI(:,4)/2];
                            case {'imline', 'imdistline', 'impoly', 'impoint'}
                                obj.p_norm = normOld; obj.p_x = []; obj.p_y = [];
                                [x,y]      = transformCoordinates(obj,posROI(:,1:end/2),posROI(:,end/2+1:end),'real2pix');
                                obj.p_norm = normNew; obj.p_x = []; obj.p_y = [];
                                [x,y]      = transformCoordinates(obj,x,y,'pix2real');
                                posROI(:,1:end/2)     = x;
                                posROI(:,end/2+1:end) = y;
                            otherwise
                                error(sprintf('%s:Input',mfilename),'Unknown ROI ''%s''',obj.p_track(i).imroi);
                        end
                        obj.p_track(i).position = posROI;
                    end
                    % store new value for norm
                    obj.p_norm = normNew;
                    resetUpdate(obj);
                    if showTrack, notify(obj,'enableTrack'); end
                end
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for norm');
            end
        end
        
        function value = get.norm(obj)
            value = obj.p_norm;
        end
        
        function         set.device(obj,value)
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if ischar(value) && ~isequal(value,obj.p_device)
                obj.p_device = value;
            elseif ~ischar(value)
                error(sprintf('%s:Input',mfilename),'Input not valid for device name');
            end
        end
        
        function value = get.device(obj)
            value = obj.p_device;
        end
        
        function         set.comment(obj,value)
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if ischar(value)
                value = {value};
            elseif ~iscellstr(value)
                error(sprintf('%s:Input',mfilename),'Input not valid for comment');
            end
            value = reshape(value,[],1);
            if ~isequal(value,obj.p_comment), obj.p_comment = value; end
        end
        
        function value = get.comment(obj)
            value = obj.p_comment;
        end
        
        function         set.date(obj,value)
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if isdatetime(value) && isscalar(value)
                if isequal(value,obj.p_date), return; end
                obj.p_date = value;
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for date');
            end
            resetUpdate(obj);
        end
        
        function value = get.date(obj)
            value = obj.p_date;
        end
        
        function         set.time(obj,value)
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if isa(value,'double') && isscalar(value)
                value = reshape((0:(obj.nFrames-1)) * value,1,[]);
            elseif isa(value,'double') && ismatrix(value) && max(size(value)) == obj.nFrames
                value = reshape(value,[],obj.nFrames);
            elseif isa(value,'double') && ismatrix(value) && max(size(value)) ~= obj.nFrames
                warning(sprintf('%s:Input',mfilename),'Input for time exhibits %d elements for a video with %d frames',numel(value),obj.nFrames);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for time');
            end
            if ~isequal(value,obj.p_time), obj.p_time = value; notify(obj,'resetPlayer'); end
        end
        
        function value = get.time(obj)
            value = obj.p_time;
        end
        
        function         set.cdata(obj,value)
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if isa(value,'Videomap')
                if isequal(value,obj.p_cdata), return; end
                obj.p_cdata.master = [];
                obj.p_cdata        = value;
                obj.p_cdata.master = obj;
                notify(obj,'updatePlayer');
            else
                error(sprintf('%s:Input',mfilename),...]
                    ['Input not valid for image data, since it must be a Videomap object, ',...
                    'use .cdata.cdata instead to set image data of current Videomap object directly']);
            end
        end
        
        function value = get.cdata(obj)
            value = obj.p_cdata;
        end
        
        function         set.exposure(obj,value)
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if isa(value,'double') && ismatrix(value) && max(size(value)) == obj.nFrames
                value = reshape(value,[],obj.nFrames);
            elseif isa(value,'double') && numel(value) == 1
                value = repmat(value,1,obj.nFrames);
            elseif isa(value,'double') && numel(value) ~= obj.nFrames
                warning(sprintf('%s:Input',mfilename),'Input for exposure exhibits %d elements for a video with %d frames',numel(value),obj.nFrames);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for exposure');
            end
            if ~isequal(value,obj.p_exposure), obj.p_exposure = value; end
        end
        
        function value = get.exposure(obj)
            value = obj.p_exposure;
        end
        
        function         set.pixres(obj,value)
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if isa(value,'double') && numel(value) <= 2 && numel(value) > 0 && all(value >= 0)
                if isscalar(value), value = repmat(value,1,2); end
                if isequal(value,obj.p_pixres), return; end
                % scale ROI to stay at the same position in video
                showTrack = hideTracks(obj);
                pixOld    = obj.p_pixres;
                pixNew    = value;
                for i = 1:numel(obj.p_track)
                    posROI = obj.p_track(i).position;
                    switch obj.p_track(i).imroi
                        case {'imellipse','imrect'}
                            obj.p_pixres = pixOld; obj.p_x = []; obj.p_y = [];
                            [x,y]        = transformCoordinates(obj,posROI(:,1)+posROI(:,3)/2,posROI(:,2)+posROI(:,4)/2,'real2pix');
                            obj.p_pixres = pixNew; obj.p_x = []; obj.p_y = [];
                            [x,y]        = transformCoordinates(obj,x,y,'pix2real');
                            posROI(:,1:2) = [x-posROI(:,3)/2*pixNew(1)/pixOld(1),y-posROI(:,4)/2*pixNew(2)/pixOld(2)];
                            posROI(:,3:4) = [posROI(:,3) * pixNew(1)/pixOld(1) posROI(:,4) * pixNew(2)/pixOld(2)];
                        case {'imline', 'imdistline', 'impoly', 'impoint'}
                            obj.p_pixres = pixOld; obj.p_x = []; obj.p_y = [];
                            [x,y]        = transformCoordinates(obj,posROI(:,1:end/2),posROI(:,end/2+1:end),'real2pix');
                            obj.p_pixres = pixNew; obj.p_x = []; obj.p_y = [];
                            [x,y]        = transformCoordinates(obj,x,y,'pix2real');
                            posROI(:,1:end/2)     = x;
                            posROI(:,end/2+1:end) = y;
                        otherwise
                            error(sprintf('%s:Input',mfilename),'Unknown ROI ''%s''',obj.p_track(i).imroi);
                    end
                    obj.p_track(i).position = posROI;
                end
                % store new value for pixel resolution
                obj.p_pixres = pixNew;
                % show player again
                resetUpdate(obj);
                if showTrack, notify(obj,'enableTrack'); end
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for pixel resolution');
            end
        end
        
        function value = get.pixres(obj)
            value = obj.p_pixres;
        end
        
        function         set.pixresX(obj,value)
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if isa(value,'double') && isscalar(value) && value > 0
                obj.pixres = [value obj.pixres(2)];
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for x pixres of video');
            end
        end
        
        function value = get.pixresX(obj)
            value = obj.pixres(1);
        end
        
        function         set.pixresY(obj,value)
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if isa(value,'double') && isscalar(value) && value > 0
                obj.pixres = [obj.pixres(1) value];
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for x pixres of video');
            end
        end
        
        function value = get.pixresY(obj)
            value = obj.pixres(2);
        end
        
        function         set.pixresR(obj,value)
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if isa(value,'double') && isscalar(value) && value > 0
                if any(isnan(obj.pixres)) || isempty(obj.pixres)
                    obj.pixres = [value value];
                else
                    obj.pixres = value ./ sqrt([obj.pixres(2)/obj.pixres(1) obj.pixres(1)/obj.pixres(2)]);
                end
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for x pixres of video');
            end
        end
        
        function value = get.pixresR(obj)
            value = sqrt(prod(obj.pixres));
        end
        
        function         set.pixresM(obj,value)
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if isa(value,'double') && isscalar(value) && value > 0
                if any(isnan(obj.pixres)) || isempty(obj.pixres)
                    obj.pixres = [value value];
                else
                    obj.pixres = 2*value ./ (1+[obj.pixres(2)/obj.pixres(1) obj.pixres(1)/obj.pixres(2)]);
                end
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for x pixres of video');
            end
        end
        
        function value = get.pixresM(obj)
            value = mean(obj.pixres);
        end
        
        function         set.track(obj,value)
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if isempty(value), value = struct('imroi',{},'position',{},'color',{},'name',{}); end
            if isstruct(value) && all(isfield(value,{'imroi' 'position'}))
                % disable current tracks in video
                showTrack = hideTracks(obj);
                % check new tracks
                addColor = ~isfield(value,'color');
                addName  = ~isfield(value,'name');
                for i = 1:numel(value)
                    if ~ischar(value(i).imroi) && ~isvalid(value(i).imroi)
                        value(i).imroi = class(value(i).imroi);
                    end
                    if addColor
                        value(i).color      = NaN(obj.nFrames,3);
                        value(i).color(1,:) = [1 0 0];
                    end
                    if addName,  value(i).name  = sprintf('%d',i); end
                    if ~(size(value(i).position,1) == obj.nFrames && size(value(i).color,1) == obj.nFrames)
                        warning(sprintf('%s:Input',mfilename),['Input not valid for track of video, ',...
                            'size in first dimension of position and color must match number of frames, ',...
                            'changing size of position and/or color to match number of frames']);
                        if size(value(i).position,1) < obj.nFrames, value(i).position(end+1:obj.nFrames,:) = NaN;
                        else,                                       value(i).position = value(i).position(1:obj.nFrames,:);
                        end
                        if size(value(i).color,1) < obj.nFrames, value(i).color(end+1:obj.nFrames,:) = NaN;
                        else,                                    value(i).color = value(i).color(1:obj.nFrames,:);
                        end
                    end
                end
                obj.p_track = value;
                % notify video player
                resetUpdate(obj);
                if showTrack, notify(obj,'resetPlayer'); notify(obj,'enableTrack'); end
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for track of video, must be a structure with imroi, position and color');
            end
        end
        
        function value = get.track(obj)
            value = obj.p_track;
        end
        
        function         set.pos(obj,value)
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if isa(value,'double') && numel(value) == 3
                posNew = reshape(value,1,[]);
                posOld = obj.p_pos;
                if isequal(posNew,posOld), return; end
                % scale ROI to stay at the same position in video
                showTrack = hideTracks(obj);
                for i = 1:numel(obj.p_track)
                    posROI = obj.p_track(i).position;
                    switch obj.p_track(i).imroi
                        case {'imellipse','imrect'}
                            obj.p_pos = posOld; obj.p_x = []; obj.p_y = [];
                            [x,y]     = transformCoordinates(obj,posROI(:,1)+posROI(:,3)/2,posROI(:,2)+posROI(:,4)/2,'real2pix');
                            obj.p_pos = posNew; obj.p_x = []; obj.p_y = [];
                            [x,y]     = transformCoordinates(obj,x,y,'pix2real');
                            posROI(:,1:2) = [x-posROI(:,3)/2,y-posROI(:,4)/2];
                        case {'imline', 'imdistline', 'impoly', 'impoint'}
                            obj.p_pos = posOld; obj.p_x = []; obj.p_y = [];
                            [x,y]     = transformCoordinates(obj,posROI(:,1:end/2),posROI(:,end/2+1:end),'real2pix');
                            obj.p_pos = posNew; obj.p_x = []; obj.p_y = [];
                            [x,y]     = transformCoordinates(obj,x,y,'pix2real');
                            posROI(:,1:end/2)     = x;
                            posROI(:,end/2+1:end) = y;
                        otherwise
                            error(sprintf('%s:Input',mfilename),'Unknown ROI ''%s''',obj.p_track(i).imroi);
                    end
                    obj.p_track(i).position = posROI;
                end
                % store new value for position
                obj.p_pos = posNew;
                % show player again
                resetUpdate(obj);
                if showTrack, notify(obj,'enableTrack'); end
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for position of video');
            end
        end
        
        function value = get.pos(obj)
            value = obj.p_pos;
        end
        
        function         set.xCCD(obj,value)
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if isa(value,'double') && isscalar(value)
                obj.pos = [value obj.pos(2) obj.pos(3)];
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for x position of video');
            end
        end
        
        function value = get.xCCD(obj)
            value = obj.pos(1);
        end
        
        function         set.yCCD(obj,value)
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if isa(value,'double') && isscalar(value)
                obj.pos = [obj.pos(1) value obj.pos(3)];
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for y position of video');
            end
        end
        
        function value = get.yCCD(obj)
            value = obj.pos(2);
        end
        
        function         set.zCCD(obj,value)
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if isa(value,'double') && isscalar(value)
                obj.pos = [obj.pos(1) obj.pos(2) value];
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for z position of video');
            end
        end
        
        function value = get.zCCD(obj)
            value = obj.pos(3);
        end
        
        function         set.memmap(obj,value)
            if obj.lock, error(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);end
            if (islogical(value) || isnumeric(value)) && isscalar(value)
                if islogical(value), value = double(value); end
                obj.p_cdata.memmap = value;
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for memmap');
            end
        end
        
        function value = get.memmap(obj)
            value = obj.p_cdata.memmap;
        end
        
        function value = get.nX(obj)
            if isempty(obj.p_nX)
                obj.p_nX = obj.p_cdata.nX;
            end
            value = obj.p_nX;
        end
        
        function value = get.nY(obj)
            if isempty(obj.p_nY)
                obj.p_nY = obj.p_cdata.nY;
            end
            value = obj.p_nY;
        end
        
        function value = get.nZ(obj)
            if isempty(obj.p_nZ)
                obj.p_nZ = obj.p_cdata.nZ;
            end
            value = obj.p_nZ;
        end
        
        function value = get.nFrames(obj)
            if isempty(obj.p_nFrames)
                obj.p_nFrames = obj.p_cdata.nFrames;
            end
            value = obj.p_nFrames;
        end
        
        function value = get.x(obj)
            if isempty(obj.p_x) || numel(obj.p_x) ~= obj.nX || ...
                    isempty(obj.p_y) || numel(obj.p_y) ~= obj.nY || ...
                    isempty(obj.p_xStr) || isempty(obj.p_yStr) || ...
                    isempty(obj.p_xIdx) || isempty(obj.p_yIdx) || ...
                    isempty(obj.p_xDir) || isempty(obj.p_yDir)
                % reset image x and y coordinates
                idx = find(abs(obj.p_norm) > eps);
                sgn = sign(obj.p_norm(idx));
                switch idx
                    case 3
                        % view in z orientation
                        obj.p_x    = ((0:(obj.nX-1))-(obj.nX-1)/2) * obj.p_pixres(1) + obj.yCCD;
                        obj.p_y    = ((0:(obj.nY-1))-(obj.nY-1)/2) * obj.p_pixres(2) + obj.xCCD;
                        obj.p_xStr = 'y';
                        obj.p_yStr = 'x';
                        obj.p_xIdx = 2;
                        obj.p_yIdx = 1;
                        obj.p_xDir = 1;
                        obj.p_yDir = 1;
                        if sgn > 0, obj.p_x = obj.p_x(end:-1:1); obj.p_xDir = -1; end
                    case 2
                        % view in y orientation
                        obj.p_x = ((0:(obj.nX-1))-(obj.nX-1)/2) * obj.p_pixres(1) + obj.zCCD;
                        obj.p_y = ((0:(obj.nY-1))-(obj.nY-1)/2) * obj.p_pixres(2) + obj.xCCD;
                        obj.p_xStr = 'z';
                        obj.p_yStr = 'x';
                        obj.p_xIdx = 3;
                        obj.p_yIdx = 1;
                        obj.p_xDir = 1;
                        obj.p_yDir = 1;
                        if sgn < 0, obj.p_x = obj.p_x(end:-1:1); obj.p_xDir = -1; end
                    case 1
                        % view in z orientation
                        obj.p_x = ((0:(obj.nX-1))-(obj.nX-1)/2) * obj.p_pixres(1) + obj.zCCD;
                        obj.p_y = ((0:(obj.nY-1))-(obj.nY-1)/2) * obj.p_pixres(2) + obj.yCCD;
                        obj.p_xStr = 'z';
                        obj.p_yStr = 'y';
                        obj.p_xIdx = 3;
                        obj.p_yIdx = 2;
                        obj.p_xDir = 1;
                        obj.p_yDir = 1;
                        if sgn > 0, obj.p_x = obj.p_x(end:-1:1); obj.p_xDir = -1; end
                end
                % reset grids as well
                if obj.bufferData
                    [obj.p_xGrid, obj.p_yGrid] = meshgrid(obj.p_x,obj.p_y);
                end
            end
            value = obj.p_x;
        end
        
        function value = get.y(obj)
            if isempty(obj.p_x) || numel(obj.p_x) ~= obj.nX || ...
                    isempty(obj.p_y) || numel(obj.p_y) ~= obj.nY
                % query obj.x that sets obj.x, obj.y and more
                obj.x;
            end
            value = obj.p_y;
        end
        
        function value = get.z(obj)
            value = obj.zCCD;
        end
        
        function         set.z(obj,value)
            obj.zCCD = value;
        end
        
        function value = get.xGrid(obj)
            if isempty(obj.p_xGrid) || size(obj.p_xGrid,1) ~= obj.nY || size(obj.p_xGrid,2) ~= obj.nX
                [value, tmp] = meshgrid(obj.x,obj.y);
                if obj.p_bufferData
                    obj.p_xGrid = value;
                    obj.p_yGrid = tmp;
                end
            else
                value = obj.p_xGrid;
            end
        end
        
        function value = get.yGrid(obj)
            if isempty(obj.p_yGrid) || size(obj.p_yGrid,1) ~= obj.nY || size(obj.p_yGrid,2) ~= obj.nX
                [tmp, value] = meshgrid(obj.x,obj.y);
                if obj.p_bufferData
                    obj.p_xGrid = tmp;
                    obj.p_yGrid = value;
                end
            else
                value = obj.p_yGrid;
            end
        end
        
        function value = get.zGrid(obj)
            value = repmat(obj.zCCD,obj.nX,obj.nY);
        end
        
        function value = get.xStr(obj)
            if isempty(obj.p_xStr)
                % query obj.x that sets obj.x, obj.y and more
                obj.x;
            end
            value = obj.p_xStr;
        end
        
        function value = get.yStr(obj)
            if isempty(obj.p_yStr)
                % query obj.x that sets obj.x, obj.y and more
                obj.x;
            end
            value = obj.p_yStr;
        end
        
        function value = get.xIdx(obj)
            if isempty(obj.p_xIdx)
                % query obj.x that sets obj.x, obj.y and more
                obj.x;
            end
            value = obj.p_xIdx;
        end
        
        function value = get.yIdx(obj)
            if isempty(obj.p_yIdx)
                % query obj.x that sets obj.x, obj.y and more
                obj.x;
            end
            value = obj.p_yIdx;
        end
        
        function value = get.xDir(obj)
            if isempty(obj.p_xDir)
                % query obj.x that sets obj.x, obj.y and more
                obj.x;
            end
            value = obj.p_xDir;
        end
        
        function value = get.yDir(obj)
            if isempty(obj.p_yDir)
                % query obj.x that sets obj.x, obj.y and more
                obj.x;
            end
            value = obj.p_yDir;
        end
        
        function value = get.memory(obj)
            % use a function such that subclasses can re-define it
            value = get_memory(obj);
        end
        
        function value = get.memoryDisk(obj)
            if isempty(obj.p_memoryDisk)
                obj.p_memoryDisk = obj.p_cdata.memoryDisk;
            end
            value = obj.p_memoryDisk;
        end
        
        function value = get.cdataClass(obj)
            value = obj.p_cdata.class;
        end
        
        function value = get.info(obj)
            
            % use a function such that subclasses can re-define it
            value = get_info(obj);
        end
        
        function value = get.isChanged(obj)
            value = obj.p_cdata.isChanged;
        end
        
        function value = get.isLinked(obj)
            value = obj.p_cdata.isLinked;
        end
        
        function value = get.ref2d(obj)
            if isempty(obj.p_ref2d)
                % obj.p_ref2d = imref2d([obj.nY obj.nX], sort(obj.x([1 end])),sort(obj.y([1 end])));
                obj.p_ref2d = imref2d([obj.nY obj.nX], obj.xDir * obj.x([1 end]),obj.yDir*obj.y([1 end]));
            end
            value = obj.p_ref2d;
        end
        
        function value = get.backupData(obj)
            value = obj.p_backupData;
        end
    end
    
    %% Methods for various class related tasks
    methods (Access = public, Hidden = false)
        function value     = isnan(obj)
            %isnan Tests if object only contains NaN without memory mapping
            
            value = false(size(obj));
            for n = 1:numel(obj)
                value(n) = isnan(obj(n).cdata);
            end
        end
        
        function value     = isdefault(obj)
            %isdefault Tests if object is the default object, i.e. contains no data worth storing,
            % please note: this might not be a 100% fail-safe test depending on a subclass
            
            value = false(size(obj));
            for i = 1:numel(obj)
                value(i) = (isnan(obj(i)) && isscalar(obj(i).time) && isnan(obj(i).time) && ...
                    isscalar(obj(i).exposure) && isnan(obj(i).exposure) && ...
                    isequal(obj(i).pixres,[1 1]) && isempty(obj(i).userdata) && ...
                    isequal(obj(i).pos,zeros(1,3)) && isequal(obj(i).norm,[0 -1 0]) && ...
                    strcmp(obj(i).name,'<undefined>') && strcmp(obj(i).device,'<undefined>') &&...
                    numel(obj(i).comment) == 1 && strcmp(obj(i).comment{1},'<undefined>'));
            end
        end
        
        function             closePlayer(obj)
            %closePlayer Closes any open player linked to video(s)
            
            for k = 1:numel(obj)
                if ~isempty(obj(k).p_player)
                    delete(obj(k).p_player)
                    obj(k).p_player = [];
                end
            end
        end
        
        function             clean(obj)
            %clean Cleans the property temp for temporary data by setting it to an empty value
            
            for i = 1:numel(obj)
                obj(i).p_temp = [];
            end
        end
        
        function             backup(obj)
            %backup Backups settings of video (all but actual video data) to memory for later recover
            
            for i = 1:numel(obj)
                if obj(i).lock
                    waring(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj(i).filename);
                else
                    % check object
                    check(obj(i),false);
                    % backup data to a backup property
                    obj(i).p_backupData = backupStruct(obj(i));
                end
            end
        end
        
        function             backup2Disk(obj)
            % backup2Disk Backups all but the cdata to a backup file on disk
            
            p_backup2Disk(obj, 0)
        end
        
        function             backup2DiskClean(obj)
            % backup2DiskClean Backups all but the cdata to a backup file on disk an remove all but the last backup file
            
            p_backup2Disk(obj, 1)
        end
        
        function             backup2DiskGUI(obj)
            %backup2DiskGUI Stores a backup to a file picked in a GUI for each object
            
            p_backup2Disk(obj, 2)
        end
        
        function             cleanBackups(obj,keepLast)
            % cleanBackups Removes any backup file or any but the last backup
            
            % process objects
            if nargin < 2 || isempty(keepLast), keepLast = true; end
            for i = 1:numel(obj)
                if isempty(obj(i).filename)
                    % this should be the default value for the filename, i.e. the template object
                    % that does not hold any data to be stored, issue a warning in case it is not
                    if ~isdefault(obj(i))
                        warning(sprintf('%s:Input',mfilename),['No filename is set for object of ',...
                            'class ''%s'', please check!'],class(obj));
                    end
                else
                    % find backup file(s)
                    dataFile = @(x) sprintf('%s.BAK%0.2d.mat',obj(i).filename,x);
                    counter  = 0;
                    while exist(dataFile(counter),'file') == 2
                        counter = counter + 1;
                    end
                    if counter > 0
                        if keepLast
                            if counter > 1
                                movefile(dataFile(counter-1),dataFile(0));
                            end
                            idxDelete = 1:(counter-2);
                        else
                            idxDelete = 0:(counter-1);
                        end
                    else
                        idxDelete = [];
                    end
                    for j = idxDelete, delete(dataFile(j)); end
                    fntest = dir(sprintf('%s.BAK*.mat',obj(i).filename));
                    fntest([fntest.isdir]) = [];
                    if (numel(fntest) ~= double(keepLast))
                        str = sprintf('''%s'', ',fntest.name); str = str(1:end-2);
                        warning(sprintf('%s:Input',mfilename),['%3d backup file(s) removed, but some ',...
                            'unexpected file(s) (%s) are still available, possible due to discontinuous ',...
                            'numbering of the file(s), please clean up manually!\n'],numel(idxDelete),str);
                    end
                end
            end
        end
        
        function             restore(obj,varargin)
            %restore Restores settings from backup in memory, puts current setting in backup
            
            if numel(varargin) < 1
                props = obj(1).props2Disk;
            elseif numel(varargin) > 0 && iscellstr(varargin) && all(ismember(varargin,obj(1).props2Disk))
                props = varargin;
            elseif numel(varargin) == 1 && iscellstr(varargin{1}) && all(ismember(varargin{1},obj(1).props2Disk))
                props = varargin{1};
            elseif numel(varargin) > 0
                error(sprintf('%s:Input',mfilename),'Input for properties to restore is unexpected');
            end
            for i = 1:numel(obj)
                if obj(i).lock
                    waring(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj(i).filename);
                else
                    % check object
                    check(obj(i),false);
                    % take out backup and restore
                    restoreStruct(obj(i),obj(i).p_backupData,props);
                end
            end
        end
        
        function             restore2Disk(obj,varargin)
            %restore2Disk Restores given properties from last backup on disk
            
            p_restore2Disk(obj,0,varargin{:});
        end
        
        function             restore2DiskGUI(obj,varargin)
            %restore2DiskGUI Restores given properties from backup file picked in GUI
            
            p_restore2Disk(obj,1,varargin{:});
        end
        
        function             link(obj)
            %link Links video to file, i.e. makes sure the file is open
            
            for i = 1:numel(obj)
                link(obj(i).cdata);
            end
        end
        
        function             unlink(obj)
            %unlink Unlinks video from file, i.e. makes sure the file is closed
            
            for i = 1:numel(obj)
                if obj(i).isLinked
                    % query a properties to make sure the data is set while the video is linked
                    obj(i).nFrames;
                    unlink(obj(i).cdata);
                end
            end
        end
        
        function             disp(obj)
            % disp Displays object on command line
            
            newLineChar = char(10);
            spacing     = '     ';
            if isempty(obj)
                tmp = sprintf('%sEmpty object of class ''%s''',spacing,class(obj));
            elseif numel(obj) > 1
                tmp = [spacing, sprintf('Array of %ss, Size %s, Memory: %.2f MiB\n',...
                    class(obj),mat2str(size(obj)),sum([obj.memory]))];
            else
                % Option 1: short information
                % str1 = sprintf('%s object [nY nX nZ nFrames] = [%d %d %d %d] ',...
                %     class(obj),obj.nY,obj.nX,obj.nZ,obj.nFrames);
                % if isempty(obj.transform)
                %     str2 = sprintf('(%s, no transform) ',obj.cdataClass);
                % else
                %     str2 = sprintf('(%s, with transform) ',obj.cdataClass);
                % end
                % if obj.memmap > 0
                %     str3 = sprintf('using %.2f MiB (memory mapping (%d) enabled for %.2f MiB on disk)',...
                %         obj.memory, obj.memmap, obj.memoryDisk);
                % else
                %     str3 = sprintf('using %.2f MiB (memory mapping (%d) disabled)',obj.memory, obj.memmap);
                % end
                % tmp = [str1, str2, str3];
                % Option 2: show info
                tmp = sprintf('%s\n',obj.info{:});
                tmp = [spacing tmp];
            end
            tmp = strrep(tmp, newLineChar, [newLineChar, spacing]);
            disp(tmp);
            if ~isequal(get(0,'FormatSpacing'),'compact')
                disp(' ');
            end
        end
        
        function             recall(obj,varargin)
            % recall Recalls video objects from disk into memory or creates memory map, input is forwarded to Videomap (cdata)
            
            p_recall(obj,false,true,false,varargin{:});
        end
        
        function             store(obj,cleanStore)
            % store Stores video objects in memory to DAT files, input is forwarded to Videomap (cdata)
            
            % process objects
            if nargin < 2, cleanStore = false; end
            for i = 1:numel(obj)
                if obj(i).lock
                    waring(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj(i).filename);
                elseif isempty(obj(i).filename)
                    % this should be the default value for the filename, i.e. the template object
                    % that does not hold any data to be stored, issue a warning in case it is not
                    if ~isdefault(obj(i))
                        warning(sprintf('%s:Input',mfilename),['No filename is set for object of ',...
                            'class ''%s'', please check!'],class(obj));
                    end
                else
                    % check object
                    check(obj(i),false);
                    % store additional data to MAT file if the hash value changed
                    tmp = backupStruct(obj(i));
                    if obj(i).minimizeStore && ~isempty(obj(i).p_hashfunc)
                        bsh = obj(i).p_hashfunc(tmp);
                        if ~strcmp(obj(i).p_minimizeStore, bsh)
                            write2File(obj(i).p_cdata,cleanStore,'Video',tmp);
                            obj(i).p_minimizeStore = bsh;
                        end
                    else
                        write2File(obj(i).p_cdata,cleanStore,'Video',tmp);
                    end
                    % store video data
                    store(obj(i).p_cdata);
                end
            end
        end
        
        function             resize(obj,scale,depth)
            %resize Resize cdata and pixres by scaling factor or vector [nY nX], see imresize
            
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
            % resize objects one by one
            for i = 1:numel(obj)
                if obj(i).lock
                    warning(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj(i).filename);
                else
                    if numel(scale) == 2
                        obj(i).p_pixres(1) = obj(i).p_pixres(1) * obj(i).nX/scale(2);
                        obj(i).p_pixres(2) = obj(i).p_pixres(2) * obj(i).nY/scale(1);
                    else
                        obj(i).p_pixres = obj(i).p_pixres / scale;
                    end
                    % resize and check
                    resize(obj(i).p_cdata,scale,depth);
                    check(obj(i),true);
                end
            end
        end
        
        function             crop(obj,rect)
            %crop Crop data by rect
            % Rect can be a four-element position vector [xmin ymin width height] which crops all
            % slices of all frames. To crop also in z and frame direction use eight-element vector
            % [xmin ymin zmin framemin width height depth frames], see also imcrop
            % check input
            
            % check input
            if ~(nargin > 1 && isnumeric(rect) && isvector(rect) && (numel(rect) == 4 || numel(rect) == 8))
                error(sprintf('%s:Input',mfilename),'Input for rect is unexpected');
            end
            % crop objects one by one
            bak = rect;
            for i = 1:numel(obj)
                if obj(i).lock
                    warning(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj(i).filename);
                else
                    rect = bak;
                    if numel(rect) == 4, rect = [rect(1) rect(1) 1 1 rect(3) rect(4) obj(i).nZ obj(i).nFrames]; end
                    maxRect = [rect(1:4) rect(1:4)+rect(5:8)-1];
                    if any(rect<1) || any(maxRect-[obj(i).nX obj(i).nY obj(i).nZ obj(i).nFrames obj(i).nX obj(i).nY obj(i).nZ obj(i).nFrames] > 0)
                        error(sprintf('%s:Input',mfilename),'Rect exceeds size of object for file ''%s''',obj(i).filename);
                    end
                    % crop and check
                    crop(obj(i).p_cdata,rect);
                    check(obj(i),true);
                end
            end
        end
        
        function             exportAs(obj,varargin)
            %exportAs Export video objects in memory in common video file formats
            % This is a wrapper function for the exportAs function in Videomap, but allows also for
            % writing a MAT file with additional video information for a proper reload as object.
            %
            % Example:
            %   % Export the first 50 frames in a horizontal montage
            %   obj.exportAs('idxFrame',1:50,'transform',@im2uint8 @(x) cat(2,x(1:end/2,:,:),x(end/2+1:end,:,:)))
            
            %
            % use input parser to process options
            opt               = inputParser;
            opt.StructExpand  = true;
            opt.KeepUnmatched = true;
            % true/false whether to export a MAT file with additonal Video information
            opt.addParameter('writeMAT', false, ...
                @(x) islogical(x) && isscalar(x));
            opt.parse(varargin{:});
            optPass           = opt.Unmatched;
            opt               = opt.Results;
            %
            % export one-by-one
            for i = 1:numel(obj)
                % export cdata with Videomap, pass options
                [fn, idx, optPass] = exportAs(obj(i).p_cdata,optPass);
                % store MAT file as well
                if opt.writeMAT
                    [fp,fn]  = fileparts(fn);
                    fnExport = fullfile(fp,[fn '.mat']);
                    if ~optPass.overwrite && exist(fnExport,'file') == 2 && numel(dir(fnExport)) == 1
                        warning(sprintf('%s:Export',mfilename),['File ''%s'' already exists and ',...
                            'overwriting is disabled, no data exported'],fnExport);
                    else
                        tmp.Video = backupStruct(obj(i),idx); %#ok<STRNU>
                        save(fnExport,'-struct','tmp');
                    end
                end
            end
        end
        
        function             check(obj,doReset)
            %check Checks object's integrity, e.g. the Videomap in its cdata
            
            if nargin < 2, doReset = false; end
            % check if the basename (filename without extension) is unique
            fn     = cellfun(@(x) fullpath(x), {obj.filename}, 'UniformOutput', false);
            fnBase = fn;
            for i = 1:numel(fn)
                [path,name ] = fileparts(fnBase{i});
                fnBase{i}    = fullfile(path,name);
            end
            fnBaseUnique = unique(fnBase);
            if numel(fnBaseUnique) ~= numel(fnBase)
                idx     = cellfun(@(x) sum(strcmp(fnBase,x)) > 1, fnBaseUnique);
                fnMulti = fnBaseUnique(idx);
                strList = sprintf('%s\n',fnMulti{:});
                warning(sprintf('%s:Input',mfilename),['%s array links to the same file multiple times ... ',...
                    'Is this on purpose? List of basenames:\n%s\b'], class(obj), strList);
            end
            for i = 1:numel(obj)
                % reset object before check
                if ~obj(i).lock && doReset, resetUpdate(obj(i),false); end
                % check Videomap object
                check(obj(i).p_cdata,doReset);
                % check tracks
                for j = 1:numel(obj(i).track)
                    if size(obj(i).track(j).position,1) ~= obj(i).nFrames || ...
                            size(obj(i).track(j).color,1) ~= obj(i).nFrames
                        warning(sprintf('%s:Input',mfilename),['%s object (filename: ''%s'') contains ',...
                            'a track (track %d called ''%s'') where the number of position or color ',...
                            'information does not match the number of frames, please check!'],...
                            class(obj(i)), obj(i).filename,j,obj(i).track(j).name);
                    end
                end
            end
        end
        
        function             readCIH(obj,varargin)
            %readCIH Reads information from CIH file as written by Photron's PFV software
            % It populates selected properties or all possible ones if input is empty
            
            %
            % check input
            allProps = {'time','device','exposure'};
            if numel(varargin) < 1
                props = allProps;
            elseif iscellstr(varargin)
                props = varargin;
            elseif numel(varargin) == 1 && iscellstr(varargin{1})
                props = varargin{1};
            else
                error(sprintf('%s:Input',mfilename),'Unexpected input for properties to read from CIH file')
            end
            if ~all(ismember(props,allProps))
                error(sprintf('%s:Input',mfilename),'Unknown property to read from CIH file')
            end
            % read file for each object one-by-one
            if numel(obj) > 1
                for i = 1:numel(obj)
                    if obj(i).lock
                        warning(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj(i).filename);
                    else
                        readCIH(obj(i),props{:});
                    end
                end
                return;
            end
            % read for single object
            myfile = [obj.filename,'.cih'];
            if exist(myfile,'file') && numel(dir(myfile)) == 1
                data = obj.parameterFileRead(myfile);
                if isstruct(data) && all(isfield(data,...
                        {'CameraType','RecordRate_fps_','ShutterSpeed_s_','StartFrame','TotalFrame','CorrectTriggerFrame'}))
                    for i = 1:numel(props)
                        switch props{i}
                            case 'time'
                                if abs(obj.nFrames - data.TotalFrame) > eps
                                    warning(sprintf('%s:Input',mfilename),...
                                        ['CIH file ''%s'' contains information for %d frames but %s holds %d frames, ',...
                                        'please check new timing information taken from the first %d frames'],...
                                        myfile,data.TotalFrame,obj.filename,obj.nFrames,obj.nFrames);
                                end
                                obj.time = ((1:obj.nFrames) - 2 + data.StartFrame - data.CorrectTriggerFrame) / data.RecordRate_fps_;
                            case 'exposure'
                                obj.exposure = data.ShutterSpeed_s_;
                            case 'device'
                                obj.device = data.CameraType;
                        end
                    end
                else
                    warning(sprintf('%s:Input',mfilename),...
                        'CIH file ''%s'' is missing information, please check it!',myfile);
                end
            end
        end
        
        function             process(obj,func,varargin)
            %process Processes video data with given function(s)
            % The first input (func) holds the function(s) to use for post processing and any
            % additional input (varargin) is parsed with the inputParser for further options on how
            % to apply the post processing, see comments in code for explanantions and an example
            % file such as process_SubtractBackground.
            %
            % What should a post processing function do and look like?
            %   A function handle with only one input argument should accept a single image,
            %   otherwise: Each function is at least called three times for initialization, run and
            %   clean up. The function should accept four arguments during the initialization:
            %     1st input: Video object
            %     2nd input: Copy of the settings of the process method
            %     3rd input: Empty storage that can be used to store data between calls
            %     4th input: State of post processing: 'pre'
            %   The function can set its runmode and outmode during the initialization. The runmode
            %   determines what is passed to the function during the actual post processing (object,
            %   single images (default runmode) or chunks of images): 'object', 'images', 'chunks'.
            %   The outmode determines what the function should return in case the runmode is
            %   'images' or 'chunks': 'cdata' for image data or 'cell' for a cell with arbitrary
            %   data. If the post processing function(s) return image data that can be stored in the
            %   object, use the 'cdata' mode, otherwise 'cell', which will collect the output in a
            %   cell and put it in the userdata creating a structure with the field 'process' (only
            %   applies to runmode of 'images' and 'chunks'). The post processing functions should
            %   return a cell with as many elements as processed images, e.g. one cell for 'images'
            %   runmode. The second and third output argument are of the same type as the second and
            %   third input arguments (independent of runmode).
            %
            %   Input and output arguments during post processing, runmode == 'object':
            %     1st input: Video object
            %     2nd input: Copy of the settings of the process function
            %     3rd input: Storage that can be used to store data between calls
            %     4th input: State of post processing: 'run'
            %   The function should return the Video object as first output.
            %
            %   Input and output arguments during post processing, runmode == 'images':
            %     1st input: Single image
            %     2nd input: Copy of the settings of the process function
            %     3rd input: Storage that can be used to store data between calls
            %     4th input: State of post processing: 'run'
            %   The function should return a single image or a single cell (depending on outmode).
            %
            %   Input and output arguments during post processing, runmode == 'chunks':
            %     1st input: Chunk of images
            %     2nd input: Copy of the settings of the process function
            %     3rd input: Storage that can be used to store data between calls
            %     4th input: State of post processing: 'run'
            %   The function should return a chunk of images or a cell with as many elements as
            %   images in the current chunk (depending on outmode).
            %
            %   The clean up run is similar to the initialization: the Video object is passed as
            %   first argument. The output should be at least one argument, namely the Video object.
            
            %
            % check func input
            if nargin < 2
                return;
            elseif ~(isa(func,'function_handle') || ...
                    (iscell(func) && all(cellfun(@(x) isa(x,'function_handle'),func))))
                error(sprintf('%s:Input',mfilename),...
                    'Post processing function(s) should be a single function_handle or a cell array with function handles')
            end
            if isa(func,'function_handle'), func = {func}; end
            for i = 1:numel(func)
                nInput = nargin(func{i});
                if ~(abs(nInput) >= 4 || abs(nInput) == 1 )
                    error(sprintf('%s:Input',mfilename),['Post processing function(s) should ',...
                        'accept either one, four or varargin inputs, such that nargin returns 1, ',...
                        '4 or -1 but not %d'],nInput);
                end
            end
            %
            % use input parser to process options
            opt               = inputParser;
            opt.StructExpand  = true;
            opt.KeepUnmatched = false;
            % Verbose level during post processing
            %
            %        verbose <= 0: nothing,
            %   	  verbose > 0: print progress on command line
            % In case the runmode is set to 'images' verbose sets the percentage steps to print
            % progress, e.g. verbose=10 lead to output about every 10% of processed images
            opt.addParameter('verbose', 10, ...
                @(x) isnumeric(x) && isscalar(x));
            % True/false whether to enable debugging mode
            %
            % In debugging a copy of the video object with the selected number of frames and
            % disabled memory mapping is created in the temp property (and left there for further
            %  manual debugging) to allow for a rapid testing of post processing functions without
            % changing the original data
            opt.addParameter('debug', false, ...
                @(x) islogical(x) && isscalar(x));
            % Run mode of post processing function(s)
            opt.addParameter('runmode', [], ...
                @(x) isempty(x) || (ischar(x) && ismember(x,{'object','images','chunks'})));
            % Output mode of post processing
            opt.addParameter('outmode', [], ...
                @(x) isempty(x) || (ischar(x) && ismember(x,{'cdata','cell'})));
            % true/false whether to ignore the actual output of the post processing function. This
            % can be used to protect the cdata from any change (for outmode == 'cdata'), actual
            % output can be stored in another way, e.g. in the userdata by the post processing
            % function itself
            opt.addParameter('ignoreOutput', false, ...
                @(x) islogical(x) && isscalar(x))
            % Select only certain frames to post process
            opt.addParameter('idxFrames', [], ...
                @(x) isempty(x) || (isnumeric(x) && min(x)>0));
            % Size in MiB that can be loaded in one go into memory, empty value leads to value of
            % object's Videomap to be used in this function, twice as much is given to the temporary
            % debugging object
            opt.addParameter('chunkSize', [], ...
                @(x) isempty(x) || (isnumeric(x) && isscalar(x) && min(x)>0));
            % true/false whether to play video (original and post processed) after debugging
            opt.addParameter('playDebug', true, ...
                @(x) islogical(x) && isscalar(x))
            opt.parse(varargin{:});
            opt      = opt.Results;
            %
            % process video array one by one
            if numel(obj) > 1 && opt.debug
                error(sprintf('%s:Export',mfilename),...
                    'Debugging of post processing only supports a single %s object', class(obj));
            elseif numel(obj) > 1
                for i = 1:numel(obj)
                    process(obj(i),func,opt);
                end
                return;
            end
            if ~opt.debug && obj.lock
                warning(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj.filename);
                return
            end
            %
            % prepare input
            % get number of frames
            if ~isempty(opt.idxFrames)
                opt.idxFrames = reshape(opt.idxFrames,1,[]);
                opt.idxFrames(opt.idxFrames > obj.nFrames) = [];
            else
                opt.idxFrames = 1:obj.nFrames;
            end
            if isempty(opt.idxFrames)
                warning(sprintf('%s:Export',mfilename),...
                    'Current data and settings lead to empty selection of frames for file ''%s'', no data processed',obj.filename);
                return;
            end
            % get chunkSize
            if isempty(opt.chunkSize)
                opt.chunkSize = obj.p_cdata.chunkSize;
            end
            %
            % prepare debugging object and point variable myobj to object that should be processed
            % (debugging object or input object itself)
            if opt.debug
                % check size of object
                mySize = numel(opt.idxFrames)/obj.nFrames * obj.memoryDisk;
                if mySize > 2*opt.chunkSize
                    warning(sprintf('%s:Export',mfilename),...
                        'Reading %.2f MiB of file ''%s'' into memory for debugging object, which is larger than twice the given chunkSize of %.2f MiB',...
                        mySize,obj.filename,2*opt.chunkSize);
                end
                % create a copy of the object with memory mapping disabled and the selected frames
                func       = str2func(class(obj));
                obj.p_temp = func([],'memmap',0,'chunkSize',2*opt.chunkSize);
                obj.p_temp.filename      = obj.filename;
                obj.p_temp.p_name        = obj.p_name;
                obj.p_temp.p_cdata.cdata = obj.p_cdata(:,:,:,opt.idxFrames);
                obj.p_temp.p_pixres      = obj.p_pixres;
                obj.p_temp.p_pos         = obj.p_pos;
                obj.p_temp.p_device      = obj.p_device;
                obj.p_temp.p_comment     = obj.p_comment;
                obj.p_temp.p_map         = obj.p_map;
                obj.p_temp.p_norm        = obj.p_norm;
                obj.p_temp.p_date        = obj.p_date;
                obj.p_temp.p_userdata    = obj.p_userdata;
                if max(opt.idxFrames) <= size(obj.time,2)
                    obj.p_temp.time = obj.time(opt.idxFrames);
                end
                if max(opt.idxFrames) <= size(obj.exposure,2)
                    obj.p_temp.exposure = obj.exposure(opt.idxFrames);
                end
                check(obj.p_temp,true);
                % link myobj to debugging object
                myobj         = obj.p_temp;
                bak           = opt;
                opt.idxFrames = 1:myobj.nFrames;
            else
                % link myobj to object itself
                myobj = obj;
            end
            %
            % start postprocessing of object
            if opt.debug && opt.verbose > 0
                fprintf('Post processing %d frames of file ''%s'' in debugging mode (obj.temp holds result of debugging run)\n',...
                    numel(opt.idxFrames), obj.filename);
            elseif ~opt.debug && opt.verbose > 0
                fprintf('Post processing %d frames of file ''%s''\n',...
                    numel(opt.idxFrames), obj.filename);
            end
            %
            % run function
            tStart = tic;
            processFunc(myobj,func,opt);
            tEnd   = toc(tStart);
            if opt.debug && opt.verbose > 0
                fprintf('  Post processing of %d frames finshed in debugging mode after %.2f s (obj.temp holds result of debugging run)\n',...
                    numel(opt.idxFrames),tEnd);
            elseif ~opt.debug && opt.verbose > 0
                fprintf('  Post processing of %d frames finshed after %.2f s\n', numel(opt.idxFrames),tEnd);
            end
            if opt.debug
                obj.p_temp.filename = [obj.filename '_debug'];
                obj.p_temp.name     = [obj.name '_debug'];
            end
            if opt.debug && opt.playDebug
                play([obj obj.p_temp],'idxFrames',{bak.idxFrames,1:myobj.nFrames},'linkAxes',true);
            end
        end
        
        function varargout = transformCoordinates(obj,varargin)
            %transformCoordinates Transforms image to physical coordinates and vice versa
            % First one, two or three input should be the coordinates to be transformed, last input
            % is the direction of transformation: 'pix2real' or 'real2pix'
            %
            % How are input coordiantes interpreted depending on the number of numeric inputs?
            % * One coordinate input with second dimenson equal to 1: Input is assumed to be linear
            %   indices into image, transform option must be 'pix2real'
            % * One coordinate input with one dimension of length 2 or two coordinate inputs: Input
            %   is assumed to be coordinates along the image axis, either pixel or real coordinates,
            %   transfom option determines which way the coordinates are transformed
            % * Three coordinate inputs: Input is assumed to be coordinates along the global
            %   coordinate system, either pixel or real coordinates, transfom option determines which
            %   way the coordinates are transformed (not yet implemented)
            
            %
            % get coordinates and options from input
            if numel(varargin) < 1
                error(sprintf('%s:Input',mfilename),...
                    'Function needs at least one numeric input');
            end
            coorIN = {};
            i      = 1;
            while i <= numel(varargin) && isnumeric(varargin{i})
                coorIN{i} = varargin{i}; %#ok<AGROW>
                i         = i + 1;
            end
            varargin(1:i-1) = [];
            if ~(numel(coorIN) > 0 && numel(coorIN) <= 3)
                error(sprintf('%s:Input',mfilename),...
                    'Unknown number (%d) of coordinates',numel(coorIN));
            elseif ~(numel(varargin)==1 && ischar(varargin{1}) && ismember(varargin{1},{'pix2real','real2pix'}))
                error(sprintf('%s:Input',mfilename),...
                    'Unknown input for direction of transformation');
            else
                transform = varargin{1};
            end
            %
            % find out what coordinates are given
            singleOutput = -1;
            if numel(coorIN) == 1 && ismatrix(coorIN{1}) && (size(coorIN{1},2) == 1 ||...
                    (size(coorIN{1},1) == 1 && numel(coorIN{1}) > 2))
                % make case with two input out of single coordinate
                if ~strcmp(transform,'pix2real')
                    error(sprintf('%s:Input',mfilename),...
                        'Coordinate is assumed to be a linear indices, but transform method (%s) does not match',transform);
                end
                [coorIN{2}, coorIN{1}] = ind2sub([obj.nY obj.nX],coorIN{1});
            elseif numel(coorIN) == 1 && ismatrix(coorIN{1}) && any(size(coorIN{1}) == 2)
                if size(coorIN{1},2) == 2
                    coorIN{2}    = coorIN{1}(:,2);
                    coorIN{1}    = coorIN{1}(:,1);
                    singleOutput = 2;
                else
                    coorIN{2}    = coorIN{1}(2,:);
                    coorIN{1}    = coorIN{1}(1,:);
                    singleOutput = 1;
                end
            elseif numel(coorIN) == 1
                error(sprintf('%s:Input',mfilename), 'Unexpected input, please check!');
            end
            if numel(coorIN) == 2
                switch transform
                    case 'pix2real'
                        % Option 1: interpolate with interp1
                        coorIN{1} = reshape(interp1(1:obj.nX,obj.x,coorIN{1}(:),'linear','extrap'),size(coorIN{1}));
                        coorIN{2} = reshape(interp1(1:obj.nY,obj.y,coorIN{2}(:),'linear','extrap'),size(coorIN{2}));
                        % Option 2: interpolate do it yourself, but this needs a case switch for
                        % different orientations based on obj.norm, not done yet
                        % coorIN{1}    = (coorIN{1}-(obj.nX+1)/2) * obj.pixres + obj.([ obj.xStr 'CCD']);
                        % coorIN{2}    = (coorIN{2}-(obj.nY+1)/2) * obj.pixres + obj.([ obj.yStr 'CCD']);
                    case 'real2pix'
                        % Option 1: interpolate with interp1
                        coorIN{1} = reshape(interp1(obj.x,1:obj.nX,coorIN{1}(:),'linear','extrap'),size(coorIN{1}));
                        coorIN{2} = reshape(interp1(obj.y,1:obj.nY,coorIN{2}(:),'linear','extrap'),size(coorIN{2}));
                    otherwise
                        error(sprintf('%s:Input',mfilename),...
                            'Unknown transform method (%s)',transform);
                end
            else
                error(sprintf('%s:Input',mfilename), 'This option is not yet implemented, sorry!');
            end
            %
            % prepare output
            if singleOutput < 0
                varargout = coorIN;
            else
                tmp = [reshape(coorIN{1},[],1) reshape(coorIN{2},[],1)];
                if singleOutput == 1
                    varargout = {tmp'};
                else
                    varargout = {tmp};
                end
            end
        end
        
        function vid       = overlay(obj,varargin)
            %overlay Creates an overlay of given videos, where the first serves as reference
            
            %
            % parse and check input
            opt               = inputParser;
            opt.StructExpand  = true;
            opt.KeepUnmatched = false;
            % selection of frames to include in overlay video
            opt.addParameter('idxFrames', [], ...
                @(x) isempty(x) || isnumeric(x) || iscell(x));
            % true\false whether to align image(s) according to their origion
            opt.addParameter('align', true, ...
                @(x) islogical(x) && isscalar(x));
            opt.parse(varargin{:});
            opt = opt.Results;
            nFrames = [obj.nFrames];
            nObj    = numel(obj);
            %
            % prepare frames to take from each video
            if isempty(opt.idxFrames)
                idxFrames = repmat({1:min(nFrames)},size(obj));
            else
                idxFrames = opt.idxFrames;
                if isnumeric(idxFrames) && min(round(idxFrames)) > 0 && max(round(idxFrames)) <= max(nFrames)
                    idxFrames = repmat({round(idxFrames)},size(obj));
                elseif iscell(idxFrames) && numel(idxFrames) == nObj && ...
                        all(cellfun(@(x) isnumeric(x) && min(round(x)) > 0 && ...
                        numel(x) == numel(idxFrames{1}) && max(round(x)) <= max(nFrames),idxFrames))
                    idxFrames = cellfun(@(x) round(x),idxFrames,'un',false);
                else
                    error(sprintf('%s:Input',mfilename),['Input for idxFrames is unexpected, ',...
                        'please check!']);
                end
            end
            % create a copy without memory mapping
            vid             = obj(1).copyShallow;
            vid.cdata.cdata = obj(1).cdata(:,:,:,idxFrames{1});
            % compute mean of all videos
            if nObj > 1
                fprintf('Creating overlay of %d objects\n',nObj);
                fprintf('  adding %d of %d: %s\n',1,nObj,obj(1).name);
                % prepare transformation, which is just the identity matrix, since imwarp is called
                % with a spatial reference object and aligns the videos according to their world
                % coordinate system
                func = str2func(['im2' vid.cdataClass]);
                if opt.align
                    refOut = obj(1).ref2d;
                    tform  = affine2d([1 0 0; 0 1 0; 0 0 1]);
                end
                % compute mean
                tmp = im2double(vid.cdata(:,:,:,:))/nObj;
                for i = 2:nObj
                    fprintf('  adding %d of %d: %s\n',i,nObj,obj(i).name);
                    img = im2double(obj(i).cdata(:,:,:,idxFrames{i}));
                    if opt.align
                        img = imwarp(img,obj(i).ref2d,tform,'OutputView',refOut);
                    end
                    tmp = tmp + img/nObj;
                end
                tmp = func(tmp);
                vid.cdata.cdata = tmp;
            end
            vid.name    = sprintf('Overlay of %d object(s)',nObj);
            vid.device  = sprintf('Overlay of %d object(s)',nObj);
            vid.comment = sprintf('Result of overlaying %d object(s)',nObj);
        end
        
        function varargout = play(obj,varargin)
            %play Plays video(s) in video player class and returns video player object
            % Any further input is passed to the video player object
            
            nargoutchk(0,1);
            idxOK = cellfun('isempty',{obj.p_player});
            if ~all(idxOK)
                tags = cellfun(@(x) x.tagMain, {obj(~idxOK).p_player}, 'un', false);
                if numel(unique(tags)) == 1
                    player = obj(find(~idxOK,1)).player;
                    player.show(obj,varargin{:});
                    if nargout > 0,varargout = {player}; end
                else
                    warning(sprintf('%s:Input',mfilename),['Showing videos in existing video players, ',...
                        'ignoring given options or videos that are not already on display and returning open players']);
                    if nargout > 0,varargout = {[obj(~idxOK).p_player]}; end
                    notify(obj,'showPlayer');
                end
            else
                out = Videoplayer(obj,varargin{:});
                if nargout > 0, varargout = {out}; end
            end
        end
        
        function varargout = playlist(obj,varargin)
            %play Plays first video in video player class and opens playlist class in addition
            
            nargoutchk(0,2);
            idxOK = cellfun('isempty',{obj.p_player});
            if ~all(idxOK)
                error(sprintf('%s:Input',mfilename),['%s(s) are already on display, please close ',...
                    'playlist(s) and start from scratch'],class(obj));
            end
            playlist = Videoplaylist(obj,varargin{:});
            player   = playlist.player;
            if nargout > 0, varargout = {playlist, player}; end
        end
        
        function out       = trackProfile(obj,varargin)
            %trackProfile Interpolates the intensity profile along a track
            
            %
            % use input parser to process options
            opt               = inputParser;
            opt.StructExpand  = true;
            opt.KeepUnmatched = false;
            % number of points to use for interpolation, empty to find estimate based on pixel
            % resolution and pixel along the circumference of the ROI
            opt.addParameter('nPoints', [], ...
                @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
            % index of frame to use
            opt.addParameter('idxFrames', 1, ...
                @(x) isnumeric(x) && isscalar(x));
            % index of track to use
            opt.addParameter('idxTrack', 1:numel(obj.track), ...
                @(x) isnumeric(x) && min(x) > 0 && max(x) <= numel(obj.track));
            % normalize cdata to [0 1]
            opt.addParameter('normalize', true, ...
                @(x) islogical(x) && isscalar(x));
            % use given image instead of video to compute profile, e.g. to use a post process image
            % and check the profiles
            opt.addParameter('img', [], ...
                @(x) isempty(x) || isnumeric(x));
            opt.parse(varargin{:});
            opt = opt.Results;
            
            %
            % initialize output
            out = struct('s',{},'x',{},'y',{},'cdata',{});
            %
            % get image
            if isempty(opt.img), img = obj.cdata(:,:,:,opt.idxFrames); imgClass = obj.cdataClass;
            else,                img = opt.img;                        imgClass = class(img);
            end
            nZ  = size(img,3);
            if opt.normalize, img = im2double(img); end
            %
            % get points of cdata along ROI perimeter
            for i = 1:numel(opt.idxTrack)
                if ischar(obj.p_track(opt.idxTrack(i)).imroi), strROI = obj.p_track(opt.idxTrack(i)).imroi;
                else,                                          strROI = class(obj.p_track(opt.idxTrack(i)).imroi);
                end
                switch strROI
                    case 'imellipse'
                        a       = max(obj.p_track(opt.idxTrack(i)).position(opt.idxFrames,3:4))/2;
                        b       = min(obj.p_track(opt.idxTrack(i)).position(opt.idxFrames,3:4))/2;
                        [~,len] = ellipke(sqrt((a^2-b^2)/a^2)); len = 4 * a * len;
                        if isempty(opt.nPoints), nPoints = ceil(len/mean(obj.pixres));
                        else,                    nPoints = ceil(opt.nPoints);
                        end
                        t        = linspace(0,2*pi,nPoints);
                        xE       = @(t,c,d,phi) c(1) + d(1)/2 * cos(phi) * cos(t) - d(2)/2 * sin(phi) * sin(t);
                        yE       = @(t,c,d,phi) c(2) + d(1)/2 * sin(phi) * cos(t) + d(2)/2 * cos(phi) * sin(t);
                        out(i).x = xE(t,obj.p_track(opt.idxTrack(i)).position(opt.idxFrames,1:2)+0.5*obj.p_track(opt.idxTrack(i)).position(opt.idxFrames,3:4),obj.p_track(opt.idxTrack(i)).position(opt.idxFrames,3:4),0);
                        out(i).y = yE(t,obj.p_track(opt.idxTrack(i)).position(opt.idxFrames,1:2)+0.5*obj.p_track(opt.idxTrack(i)).position(opt.idxFrames,3:4),obj.p_track(opt.idxTrack(i)).position(opt.idxFrames,3:4),0);
                        val      = NaN([size(out(i).x) nZ]);
                        for idxZ = 1:nZ
                            val(:,:,idxZ) = interp2(obj.xGrid,obj.yGrid,img(:,:,idxZ),out(i).x,out(i).y,'linear',NaN);
                        end
                        if ~opt.normalize
                            func = str2func(['im2' imgClass]);
                            val  = func(val);
                        end
                        out(i).s     = [0 a*cumsum(sqrt(sin(t(1:end-1)).^2+((b/a)*cos(t(1:end-1))).^2).*diff(t))];
                        out(i).cdata = val;
                    case {'imrect', 'imline', 'imdistline', 'impoly', 'impoint'}
                        if strcmp(strROI,'imrect')
                            tmp   = obj.p_track(opt.idxTrack(i)).position(opt.idxFrames,:);
                            mypos = repmat(tmp(1:2),5,1) + [0 0; tmp(3) 0; tmp(3) tmp(4); 0 tmp(4); 0 0];
                        elseif strcmp(strROI,'impoly')
                            mypos = reshape(obj.p_track(opt.idxTrack(i)).position(opt.idxFrames,:),[],2);
                            mypos = cat(1,mypos,mypos(1,:));
                        else
                            mypos = reshape(obj.p_track(opt.idxTrack(i)).position(opt.idxFrames,:),[],2);
                        end
                        if isempty(opt.nPoints), nPoints = {};
                        else,                    nPoints = {ceil(opt.nPoints)};
                        end
                        % improfile seems not to respect xdata and ydata correctly, therefore, the
                        % image is flipped, but it could be done maybe faster with interp2 directly
                        if obj.x(1) > obj.x(end), img = img(:,end:-1:1,:); end
                        if obj.y(1) > obj.y(end), img = img(end:-1:1,:,:); end
                        if opt.normalize
                            [cx,cy,val] = improfile(obj.x([1 end]),obj.y([1 end]),...
                                img,mypos(:,1),mypos(:,2),nPoints{:});
                        else
                            [cx,cy,val] = improfile(obj.x([1 end]),obj.y([1 end]),...
                                img,mypos(:,1),mypos(:,2),nPoints{:});
                            val = cast(val,obj.cdataClass);
                        end
                        out(i).x     = cx;
                        out(i).y     = cy;
                        out(i).s     = cumsum([0; sqrt((cx(1:end-1)-cx(2:end)).^2 + (cy(1:end-1)-cy(2:end)).^2)]);
                        out(i).cdata = val;
                    otherwise
                        error(sprintf('%s:Input',mfilename),'Unknown ROI ''%s''',strROI);
                end
            end
        end
        
        function             setOrigin(obj,track,idx)
            %setOrigin Use a given frame in a given track structure to set CCD position
            % such that the origin is at the center of the track
            
            %
            % check input
            narginchk(2,3);
            if nargin < 3, idx = 1; end
            if numel(obj) > 1
                for i = 1:numel(obj)
                    if obj(i).lock
                        warning(sprintf('%s:Input',mfilename),['File ''%s'' is locked to ',...
                            'prevent any data change'],obj(i).filename);
                    else
                        setOrigin(obj(i),track,idx);
                    end
                end
                return;
            end
            if ischar(track)
                idxTrack = find(strcmp(track,{obj.track.name}));
                if numel(idxTrack) ~= 1
                    error(sprintf('%s:Input',mfilename),'Track ''%s'' not found in object',track);
                end
                track = obj.track(idxTrack);
            end
            if ~(isstruct(track) && all(isfield(track,{'imroi','position'})) && numel(track) ==1)
                error(sprintf('%s:Input',mfilename),'Unknown input for track');
            elseif ~(isnumeric(idx) && isscalar(idx) && idx > 0 && idx <= size(track.position,1))
                error(sprintf('%s:Input',mfilename),'Unknown input for index or index exceeds limits');
            end
            %
            % get center of ROI
            if ischar(track.imroi), strROI = track.imroi;
            else,                   strROI = class(track.imroi);
            end
            switch strROI
                case {'imellipse','imrect'}
                    mypos = track.position(idx,1:2) + track.position(idx,3:4)/2;
                case {'imline', 'imdistline', 'impoly', 'impoint'}
                    mypos = mean(reshape(track.position(idx,:),[],2),1);
                otherwise
                    error(sprintf('%s:Input',mfilename),'Unknown ROI ''%s''',strROI);
            end
            %
            % determine center of ROI in global coordinate system and set new CCD position such that
            % the origin is at the center of the ROI
            tmp      = [0 0 0];
            tmp([obj.xIdx obj.yIdx]) = mypos;
            obj.pos  = obj.pos-tmp;
        end
        
        function             reset(obj)
            % reset Resets properties that should be recomputed on data change
            
            obj.resetUpdate;
        end
        
        function out       = copyShallow(obj)
            %copyShallow Copies all properties but not the Videomap, which is replaced by a Videomap
            % object holding only the first frame of the original video in memory. Therefore, it is
            % not really a shallow copy since the new object is unique (including the Videomap)
            
            
            % copyElement Override copyElement method from matlab.mixin.Copyable class
            
            % Make a shallow copy of all properties
            func = str2func(class(obj));
            out  = reshape(func(numel(obj)),size(obj));
            for i = 1:numel(obj)
                out(i)               = copyElement(obj(i));
                % make new videomap
                out(i).p_cdata       = Videomap([],'master',out(i));
                out(i).p_cdata.cdata = obj(i).cdata(:,:,:,1);
                % reset new object
                resetUpdate(out(i));
            end
        end
        
        function             resetUpdate(obj,doNotify)
            % resetUpdate Resets properties that should be recomputed on data change
            %
            % This will force a recalculation of the corresponding properties next time they are
            % used and also reduces the memory consumption of the object
            
            if nargin < 2, doNotify = true; end
            for i = 1:numel(obj)
                obj(i).p_xGrid      = [];
                obj(i).p_yGrid      = [];
                obj(i).p_x          = [];
                obj(i).p_y          = [];
                obj(i).p_xStr       = [];
                obj(i).p_yStr       = [];
                obj(i).p_xIdx       = [];
                obj(i).p_yIdx       = [];
                obj(i).p_xDir       = [];
                obj(i).p_yDir       = [];
                obj(i).p_ref2d      = [];
                obj(i).p_props2Disk = [];
                obj(i).p_nFrames    = [];
                obj(i).p_nX         = [];
                obj(i).p_nY         = [];
                obj(i).p_nZ         = [];
                obj(i).p_memoryDisk = [];
                if doNotify, notify(obj,'resetPlayer'); end
            end
        end
    end
    
    methods (Access = protected, Hidden = false)
        function out       = backupStruct(obj,idxFrames)
            % backupStruct Return structure with all data for given frames but the cdata of the
            % video(s) to store
            
            if nargin < 2 || isempty(idxFrames), idxFrames = []; end
            out = struct;
            for i = 1:numel(obj)
                % backup data to a backup structure
                for j = 1:numel(obj(i).props2Disk)
                    switch obj(i).props2Disk{j}
                        case 'track'
                            % save ROIs as string and not as imroi object
                            track = obj(i).(obj(i).props2Disk{j}); %#ok<*PROP>
                            for idxTrack = 1:numel(track)
                                if ~ischar(track(idxTrack).imroi)
                                    track(idxTrack).imroi = class(track(idxTrack).imroi);
                                end
                            end
                            out(i).(obj(i).props2Disk{j}) = track;
                        otherwise
                            out(i).(obj(i).props2Disk{j}) = obj(i).(obj(i).props2Disk{j});
                    end
                end
                % adjust properties that depend on number of frames
                if ~isempty(idxFrames)
                    for j = 1:numel(out(i).track)
                        if size(out(i).track(j).position,1) == obj(i).nFrames
                            out(i).track(j).position = out(i).track(j).position(idxFrames,:);
                        end
                        if size(out(i).track(j).color,1) == obj(i).nFrames
                            out(i).track(j).color    = out(i).track(j).color(idxFrames,:);
                        end
                    end
                    if size(out(i).time,2) == obj(i).nFrames
                        out(i).time = out(i).time(:,idxFrames);
                    elseif numel(out(i).time) == obj(i).nFrames
                        out(i).time = out(i).time(idxFrames);
                    end
                    if size(out(i).exposure,2) == obj(i).nFrames
                        out(i).exposure = out(i).exposure(:,idxFrames);
                    elseif numel(out(i).exposure) == obj(i).nFrames
                        out(i).exposure = out(i).exposure(idxFrames);
                    end
                end
            end
        end
        
        function             restoreStruct(obj,out,props)
            %restoreStruct Restores structure with backup data
            
            if nargin < 2 || isempty(out)
                return;
            elseif numel(obj) ~= numel(out)
                error(sprintf('%s:Input',mfilename),'Mismatch in number of elements for given input');
            end
            if nargin < 3 || isempty(props)
                props = obj(1).props2Disk;
            else
                props = intersect(props,obj(1).props2Disk);
            end
            
            fn = intersect(fieldnames(out),props);
            for i = 1:numel(obj)
                if obj(i).lock
                    waring(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj(i).filename);
                else
                    tmp = out(i);
                    if ~isempty(tmp)
                        % make sure the tracks are not on display
                        if ismember('track',fn), showTrack = hideTracks(obj(i)); end
                        % restore backup, but set the p_ property intead of the public one
                        for j = 1:numel(fn)
                            if strcmp(fn{j},'pixres') && numel(tmp.(fn{j})) == 1
                                obj(i).(['p_' fn{j}]) = repmat(tmp.(fn{j}),1,2);
                            elseif strcmp(fn{j},'minimizeStore')
                                if tmp.(fn{j})
                                    obj(i).(['p_' fn{j}]) = '';
                                else
                                    obj(i).(['p_' fn{j}]) = -1;
                                end
                            else
                                obj(i).(['p_' fn{j}]) = tmp.(fn{j});
                            end
                        end
                        % reset object
                        resetUpdate(obj(i));
                        % re-show tracks
                        if ismember('track',fn) && showTrack, notify(obj(i),'enableTrack'); end
                    end
                end
            end
        end
        
        function             p_backup2Disk(obj,mode)
            % p_backup2Disk Backup all but the cdata to a backup file on disk
            %
            %  mode values:
            %    0: store to backup file
            %    1: store to backup file and remove all but the last backup file
            %    2: ask for backup file location with a GUI
            
            % process objects
            for i = 1:numel(obj)
                if isempty(obj(i).filename)
                    % this should be the default value for the filename, i.e. the template object
                    % that does not hold any data to be stored, issue a warning in case it is not
                    if ~isdefault(obj(i))
                        warning(sprintf('%s:Input',mfilename),['No filename is set for object of ',...
                            'class ''%s'', please check!'],class(obj));
                    end
                else
                    % find unused backup file
                    dataFile = @(x) sprintf('%s.BAK%0.2d.mat',obj(i).filename,x);
                    counter  = 0;
                    while exist(dataFile(counter),'file') == 2
                        counter = counter + 1;
                    end
                    if mode == 2
                        [fn, fp] = uiputfile('*.mat',sprintf('Pick a backup file for ''%s''',obj(i).name),...
                            dataFile(counter));
                        if isequal(fn,0) || isequal(fp,0)
                            % stop backing up for all videos
                            return;
                        else
                            dataFile = fullfile(fp,fn);
                        end
                    end
                    tmp.Video = backupStruct(obj(i)); %#ok<STRNU>
                    if mode == 0
                        % store additional data to MAT file
                        fntest                 = dir(sprintf('%s.BAK*.mat',obj(i).filename));
                        fntest([fntest.isdir]) = [];
                        save(dataFile(counter),'-struct','tmp');
                        if numel(fntest) ~= counter
                            warning(sprintf('%s:Input',mfilename),['Mismatch in number of backup files, ',...
                                'possible due to discontinuous numbering, last backup was written to ',...
                                '''%s'', please check and clean up manually!\n'],dataFile(counter));
                        end
                    elseif mode == 1
                        % store additional data to first backup file and remove remaining
                        save(dataFile(0),'-struct','tmp');
                        for j = (counter-1):-1:1
                            delete(dataFile(j));
                        end
                        fntest                 = dir(sprintf('%s.BAK*.mat',obj(i).filename));
                        fntest([fntest.isdir]) = [];
                        if numel(fntest) ~= 1
                            warning(sprintf('%s:Input',mfilename),['Mismatch in number of backup files, ',...
                                'possible due to discontinuous numbering, last backup was written to ',...
                                '''%s'', please check and clean up manually!\n'],dataFile(counter));
                        end
                    else
                        save(dataFile,'-struct','tmp');
                    end
                end
            end
        end
        
        function             p_restore2Disk(obj,mode,varargin)
            %p_restore2Disk Restores settings from last backup on disk
            %
            %  mode values:
            %    0: restore from last backup file
            %    1: restore from file picked in a GUI
            
            if numel(varargin) < 1
                props = obj(1).props2Disk;
            elseif numel(varargin) > 0 && iscellstr(varargin) && all(ismember(varargin,obj(1).props2Disk))
                props = varargin;
            elseif numel(varargin) == 1 && iscellstr(varargin{1}) && all(ismember(varargin{1},obj(1).props2Disk))
                props = varargin;
            elseif numel(varargin) > 0
                error(sprintf('%s:Input',mfilename),'Input for properties to restore is unexpected');
            end
            for i = 1:numel(obj)
                if obj(i).lock
                    waring(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj(i).filename);
                elseif isempty(obj(i).filename)
                    % this should be the default value for the filename, i.e. the template object
                    % that does not hold any data to be stored, issue a warning in case it is not
                    if ~isdefault(obj(i))
                        warning(sprintf('%s:Input',mfilename),['No filename is set for object of ',...
                            'class ''%s'', please check!'],class(obj));
                    end
                else
                    % find last backup file
                    dataFile = @(x) sprintf('%s.BAK%0.2d.mat',obj(i).filename,x);
                    counter  = 0;
                    while exist(dataFile(counter),'file') == 2
                        counter = counter + 1;
                    end
                    counter = counter - 1;
                    if mode == 1
                        [fn, fp] = uigetfile('*.mat',sprintf('Pick a backup file for ''%s''',obj(i).name),...
                            dataFile(counter));
                        if isequal(fn,0) || isequal(fp,0)
                            return;
                        else
                            dataFile = fullfile(fp,fn);
                        end
                        counter = 0;
                    end
                    if counter >= 0
                        % take out backup from disk
                        if mode == 0
                            tmp = load(dataFile(counter));
                        else
                            tmp = load(dataFile);
                        end
                        if isfield(tmp,'Video') && isstruct(tmp.Video) && ...
                                any(ismember(props,fieldnames(tmp.Video)))
                            % check object
                            check(obj(i),false);
                            % restore data
                            restoreStruct(obj(i),tmp.Video);
                        else
                            warning(sprintf('%s:Input',mfilename),['Backup file ''%s'' seems to be ',...
                                'invalid for object of class ''%s'', please check!'],dataFile(counter),class(obj));
                        end
                    end
                end
            end
        end
        
        function out       = hideTracks(obj)
            %hideTracks Hides tracks and issues warning if not possible, returns whether tracks were
            % on disblay before the call of the function for each video
            
            out = false(size(obj));
            for i = 1:numel(obj)
                for j = 1:numel(obj(i).p_track)
                    if ~ischar(obj(i).p_track(j).imroi)
                        notify(obj(i),'disableTrack'); out(i) = true;
                        if ~ischar(obj(i).p_track(j).imroi)
                            error(sprintf('%s:Input',mfilename),['Tracking ROIs are ',...
                                'currently on display, please disable display of all ROIs ',...
                                'before changing this property of video ''%s'''],obj(i).filename);
                        end
                    end
                end
            end
        end
        
        function value     = checkPropertyEqual(obj,props,err)
            %checkPropertyEqual Checks if all given properties are equal in array of beam profiles
            % and throws a warning (err = 1), error (err = 1) or nothing (err is not 1 or 2)
            
            %
            % check for absolute difference
            value = true(size(props));
            for i = 1:numel(props)
                switch props{i}
                    case 'norm'
                        tmp      = abs(cat(1,obj(:).norm) - repmat(obj(1).norm,numel(obj),1));
                        value(i) = ~(any(tmp(:) > eps));
                    otherwise
                        tmp      = [obj(:).(props{i})];
                        tmp      = sum(abs(tmp - mean(tmp)));
                        value(i) = ~(tmp > eps);
                end
            end
            %
            % output warning or error
            if any(~value)
                str = sprintf('%s, ',props{~value});
                str = str(1:end-2);
                switch err
                    case 1
                        warning(sprintf('%s:Input',mfilename),['Some properties (%s) differ among the given ',...
                            'objects and the result of the requested operation may be incorrect, please check!'], str);
                    case 2
                        warning(sprintf('%s:Input',mfilename),['Some properties (%s) differ among the given ',...
                            'objects and the requested operation cannot be performed, please check!'], str);
                end
            end
        end
        
        function value     = get_props2Disk(obj)
            %get_props2Disk Return the properties that should be stored to disk, this can be used by
            % a subclass to add properties that should be saved to disk
            
            value = unique(obj.p_props2Disk_sup);
        end
        
        function value     = get_info(obj)
            % get_info Returns info for a scalar object
            
            if numel(obj) > 1
                error(sprintf('%s:Input',mfilename),...
                    'Function only supports scalar inputs');
            end
            nIntro   = 16;
            nValue   = 10;
            value    = {'';''};
            value{2} = sprintf('| %40s from %s                                     |',class(obj),datestr(obj.p_date));
            value{1} = repmat('-',1,numel(value{2}));
            value{3} = value{1};
            nTotal   = numel(value{1});
            props    = {'filename' 'comment' 'device' 'name' 'sep' ...
                'data' 'map' 'transform' 'memmap' 'status' 'sep' ...
                'pos' 'norm' 'xStr' 'yStr' 'sep' ...
                'track' 'time' 'exposure' 'sep' ...
                'pixresX' 'pixresY' 'pixresR' 'pixresM' ...
                };
            for i = 1:numel(props)
                switch props{i}
                    case 'sep'
                        value{end+1} = ''; %#ok<AGROW>
                    case 'data'
                        value{end+1} = sprintf('%*s: [%d %d %d %d] as %s, %.0f MiB in memory, %.0f MiB on disk',nIntro,'data',...
                            obj.nY,obj.nX,obj.nZ,obj.nFrames,obj.cdataClass,obj.memory,obj.memoryDisk); %#ok<AGROW>
                    case 'status'
                        if obj.lock
                            str = 'object is locked';
                        else
                            str = 'object is unlocked';
                        end
                        if obj.isChanged
                            str = [str ' and image data is changed']; %#ok<AGROW>
                        else
                            str = [str ' and image data is unchanged']; %#ok<AGROW>
                        end
                        value{end+1} = sprintf('%*s: %s',nIntro,'status',str); %#ok<AGROW>
                    case 'memmap'
                        switch obj.memmap
                            case 0
                                str = 'all data loaded into memory, read & write access';
                            case 1
                                str = 'memory mapping binary DAT file, read & write access';
                            case 2
                                str = 'memory mapping with VideoReader, read-only';
                            case 3
                                str = 'memory mapping with TIFFStack, read-only';
                            otherwise
                                str = 'unknown memory mapping mode';
                        end
                        value{end+1} = sprintf('%*s: %s',nIntro,props{i},str); %#ok<AGROW>
                    case 'transform'
                        if isempty(obj.(props{i}))
                            str = 'no image transformation defined';
                        else
                            str = ['''' func2str(obj.(props{i})) ''''];
                        end
                        value{end+1} = sprintf('%*s: %s',nIntro,props{i},str); %#ok<AGROW>
                    case 'map'
                        if isempty(obj.(props{i}))
                            str = 'no custom color map defined';
                        else
                            str = ['[' num2str(size((obj.(props{i})))) '] in size'];
                        end
                        value{end+1} = sprintf('%*s: %s',nIntro,props{i},str); %#ok<AGROW>
                    case {'pixresX' 'pixresY' 'pixresR' 'pixresM'}
                        value{end+1} = sprintf('%*s: %*.2e m/pix',nIntro,props{i},nValue,obj.(props{i})); %#ok<AGROW>
                    case {'xStr' 'yStr'}
                        if obj.([props{i}(1) 'Dir']) > 0
                            str = 'in normal orientation';
                        else
                            str = 'in reverse orientation';
                        end
                        value{end+1} = sprintf('%*s: %s %s',nIntro,['CCD   ' props{i}(1) ' axes'],obj.(props{i}),str); %#ok<AGROW>
                    case 'pos'
                        str          = ['[' num2str(obj.(props{i})) '] m'];
                        value{end+1} = sprintf('%*s: %s',nIntro,'CCD position',str); %#ok<AGROW>
                    case 'norm'
                        str          = ['[' num2str(obj.(props{i})) ']'];
                        value{end+1} = sprintf('%*s: %s',nIntro,'CCD   normal',str); %#ok<AGROW>
                    case 'track'
                        value{end+1} = sprintf('%*s: %d track(s) available',nIntro,props{i},numel(obj.(props{i}))); %#ok<AGROW>
                    case {'time' 'exposure'}
                        if all(isnan(obj.(props{i})))
                            str = 'NaN(s)';
                        elseif obj.nFrames == size(obj.(props{i}),2)
                            str = sprintf('%d value(s) per frame available',size(obj.(props{i}),1));
                        else
                            str = ['[' num2str(size((obj.(props{i})))) '] in size'];
                        end
                        value{end+1} = sprintf('%*s: %s',nIntro,props{i},str); %#ok<AGROW>
                    case 'comment'
                        if isempty(obj.p_comment)
                            value{end+1} = sprintf('%*s: ',nIntro,props{i}); %#ok<AGROW>
                        else
                            str = {};
                            for j = 1:numel(obj.p_comment)
                                str = cat(1,str(:),mywrap(obj.p_comment{j},nTotal - nIntro - 2));
                            end
                            str{1} = sprintf('%*s: %s',nIntro,props{i},str{1});
                            for j = 2:numel(str)
                                str{j} = sprintf('%*s  %s',nIntro,'',str{j}); %#ok<AGROW>
                            end
                            value = cat(1,value(:), str(:));
                        end
                    otherwise
                        if isnumeric(obj.(props{i})) && isscalar(obj.(props{i}))
                            value{end+1} = sprintf('%*s: %*.2e',nIntro,props{i},nValue,obj.(props{i})); %#ok<AGROW>
                        elseif ischar(obj.(props{i}))
                            value{end+1} = sprintf('%*s: %s',nIntro,props{i},obj.(props{i})); %#ok<AGROW>
                        elseif iscellstr(obj.(props{i}))
                            value{end+1} = sprintf('%*s: %s',nIntro,props{i},obj.(props{i}){1}); %#ok<AGROW>
                            for j = 2:numel(obj.(props{i}))
                                value{end+1} = sprintf('%*s  %s',nIntro,' ',obj.(props{i}){j}); %#ok<AGROW>
                            end
                        end
                end
            end
            value{end+1} = value{1};
            
            function str = mywrap(str,len)
                % mywrap Wraps a char array at word breaks exceeding a maximum line length
                
                str = strtrim(str);
                exp = sprintf('(\\S\\S{%d,}|.{1,%d})(?:\\s+|$)', len, len);
                tok = regexp(str, exp, 'tokens').';
                str = cellfun(@(f) f{1}, tok, 'UniformOutput', false);
                str = deblank(str(:));
            end
        end
        
        function value     = get_memory(obj)
            % get_memory Returns memory for a scalar object
            
            if numel(obj) > 1
                error(sprintf('%s:Input',mfilename),...
                    'Function only supports scalar inputs');
            end
            % memory in cdata and in p_xGrid and p_yGrid, p_x and p_y, no explicit computation for
            % all properties
            value = obj.p_cdata.memory + ...
                (numel(obj.p_xGrid)+numel(obj.p_yGrid)+numel(obj.p_x)+numel(obj.p_y)) * 8 / 1024^2 + ... % grids and axes
                (1 + numel(obj.p_backupData)) * 8 / 1024^2 * ( ...
                numel(obj.p_time) + numel(obj.p_exposure) + ...  % time and exposure
                numel(obj.track) * obj.nFrames * 10 + ...        % estimate tracks
                numel(obj.p_map) + 100 );                        % map and estimate all other properties
        end
        
        function             p_recall(obj,ignoreLock,checkTrack,onlyMAT,varargin)
            % p_recall Recalls video objects from disk into memory or creates memory map, varargin is forwarded to Videomap (cdata)
            
            mc          = metaclass(obj(1));
            props       = [mc.Properties{:}];
            propsName   = {props.Name};
            mypropsp    = cellfun(@(x) ['p_' x],obj(1).props2Disk,'un',false);
            [~,idxProp] = ismember(mypropsp,propsName);
            for i = 1:numel(obj)
                if obj(i).lock && ~ignoreLock
                    warning(sprintf('%s:Input',mfilename),'File ''%s'' is locked to prevent any data change',obj(i).filename);
                elseif isdefault(obj(i))
                    % this should be the default object that does not need recalling
                else
                    % make sure the tracks are not on display
                    if checkTrack, showTrack = hideTracks(obj(i)); end
                    % make a backup of the backup data to restore it after the recall
                    bakDat = obj.p_backupData;
                    if ~onlyMAT
                        % recall object
                        obj(i).p_cdata.recall(varargin{:});
                    end
                    % set default values for all properties, since this function might be called
                    % when the object has already certain values assigned and then it should remove
                    % all properties and reset to default or the ones on disk. set a default time
                    % and exposure time that matches the number of frames.
                    for j = 1:numel(mypropsp)
                        if props(idxProp(j)).HasDefault
                            obj(i).(mypropsp{j}) = props(idxProp(j)).DefaultValue;
                        else
                            switch mypropsp{j}
                                case 'p_transform'
                                    obj(i).(mypropsp{j}) = [];
                                otherwise
                                    error(sprintf('%s:Input',mfilename),...
                                        'Unknown property ''%s'' without default value',mypropsp{j});
                            end
                        end
                    end
                    obj(i).p_time     = NaN;
                    obj(i).p_exposure = NaN;
                    % load additional data from MAT file
                    dat   = read2File(obj(i).p_cdata);
                    fnDat = fieldnames(dat);
                    % convert files to new version and load again
                    if ~ismember('Video',fnDat) && any(ismember(obj(i).props2Disk,fnDat))
                        Video.convertMATFile(obj(i).p_cdata.filenameMAT);
                        resetUpdate(obj(i).p_cdata,false);
                        dat   = read2File(obj(i).p_cdata);
                        fnDat = fieldnames(dat);
                    end
                    % restore backup and make sure a resetUpdate call takes place
                    if ismember('Video',fnDat) && isstruct(dat.Video)
                        restoreStruct(obj(i),dat.Video);
                    else
                        resetUpdate(obj(i));
                    end
                    % restore backup data
                    obj(i).p_backupData = bakDat;
                    % check object
                    check(obj(i),false);
                    % store a hash value of the current data
                    if obj(i).minimizeStore && ~isempty(obj(i).p_hashfunc)
                        obj(i).p_minimizeStore = obj(i).p_hashfunc(backupStruct(obj(i)));
                    end
                    % reshow the video player
                    notify(obj(i),'resetPlayer');
                    if checkTrack && showTrack, notify(obj,'enableTrack'); end
                end
            end
        end
        
        function             processFunc(obj,func,opt)
            %processFunc Process object and let the function(s) decide how to do it
            
            nDig    = 1+ceil(log10(numel(opt.idxFrames)));
            optOrig = opt;
            for i = 1:numel(func)
                nInput = nargin(func{i});
                if nInput == 1
                    try
                        framesChunk = 1;
                        framesDone  = 0;
                        while framesDone < numel(optOrig.idxFrames)
                            curFrames = (framesDone + 1):min(numel(optOrig.idxFrames),framesDone+framesChunk);
                            if optOrig.verbose > 0
                                fprintf('  %*d of %*d frames: %*d to %*d\n',...
                                    nDig,numel(curFrames),nDig,numel(optOrig.idxFrames),nDig,min(curFrames),nDig,max(curFrames));
                            end
                            opt.curFrames    = optOrig.idxFrames(curFrames);
                            tmp = func{i}(obj.p_cdata(:,:,:,optOrig.idxFrames(curFrames)));
                            if ~opt.ignoreOutput
                                obj.p_cdata(:,:,:,optOrig.idxFrames(curFrames)) = tmp;
                            end
                            framesDone = curFrames(end);
                        end
                    catch err
                        warning(sprintf('%s:Error',mfilename),['Error during post processing:\n%s\n'...
                            'Nevertheless, trying to continue to recover data at least partially,'...
                            ' but the following output might be wrong'],err.getReport);
                    end
                else
                    % initialization
                    [obj, opt, init] = func{i}(obj,optOrig,[],'pre');
                    % process data
                    if isempty(opt.runmode), opt.runmode = 'images'; end
                    if isempty(opt.outmode), opt.outmode = 'cdata'; end
                    try
                        switch opt.runmode
                            case {'images','chunks'}
                                if strcmp(opt.runmode,'images')
                                    framesChunk = 1;
                                else
                                    framesChunk = ceil(opt.chunkSize/obj.memoryDisk * obj.nFrames);
                                end
                                framesDone  = 0;
                                switch opt.outmode
                                    case 'cdata'
                                        while framesDone < numel(optOrig.idxFrames)
                                            curFrames = (framesDone + 1):min(numel(optOrig.idxFrames),framesDone+framesChunk);
                                            if optOrig.verbose > 0
                                                fprintf('  %*d of %*d frames: %*d to %*d\n',...
                                                    nDig,numel(curFrames),nDig,numel(optOrig.idxFrames),nDig,min(curFrames),nDig,max(curFrames));
                                            end
                                            opt.curFrames    = optOrig.idxFrames(curFrames);
                                            [tmp, opt, init] = func{i}(obj.p_cdata(:,:,:,optOrig.idxFrames(curFrames)),opt,init,'run');
                                            if ~opt.ignoreOutput
                                                obj.p_cdata(:,:,:,optOrig.idxFrames(curFrames)) = tmp;
                                            end
                                            framesDone = curFrames(end);
                                        end
                                    case 'cell'
                                        if ~opt.ignoreOutput
                                            obj.userdata.process = cell(1,obj.nFrames);
                                        end
                                        while framesDone < numel(optOrig.idxFrames)
                                            curFrames = (framesDone + 1):min(numel(optOrig.idxFrames),framesDone+framesChunk);
                                            if optOrig.verbose > 0
                                                fprintf('  %*d of %*d frames: %*d to %*d\n',...
                                                    nDig,numel(curFrames),nDig,numel(optOrig.idxFrames),nDig,min(curFrames),nDig,max(curFrames));
                                            end
                                            opt.curFrames    = optOrig.idxFrames(curFrames);
                                            [tmp, opt, init] = func{i}(obj.p_cdata(:,:,:,optOrig.idxFrames(curFrames)),opt,init,'run');
                                            if ~opt.ignoreOutput
                                                obj.userdata.process(optOrig.idxFrames(curFrames)) = tmp;
                                            end
                                            framesDone = curFrames(end);
                                        end
                                end
                            case 'object'
                                [obj, opt, init] = func{i}(obj,opt,init,'run');
                            otherwise
                                error(sprintf('%s:Process',mfilename),...
                                    'Unknown runmode for post processing function %d',i);
                        end
                    catch err
                        warning(sprintf('%s:Error',mfilename),['Error during post processing:\n%s\n'...
                            'Nevertheless, trying to continue to recover data at least partially,'...
                            ' but the following output might be wrong'],err.getReport);
                    end
                    % clean up
                    obj = func{i}(obj,opt,init,'post');
                end
            end
        end
    end
    
    methods (Access = protected)
        function cpObj     = copyElement(obj)
            % copyElement Override copyElement method from matlab.mixin.Copyable class
            
            % Make a shallow copy of all properties
            cpObj = copyElement@matlab.mixin.Copyable(obj);
            % Make a deep copy of Videomap
            cpObj.p_cdata        = copy(obj.p_cdata);
            cpObj.p_cdata.master = cpObj;
            % reset new object
            resetUpdate(cpObj);
        end
    end
    
    methods
        function S         = saveobj(obj)
            % saveobj Supposed to be called by MATLAB's save function, ensures the object is stored
            % to disk by its own store function, the MATLAB file just needs little information such
            % as the filename to the stored data
            
            % process objects in case user called this function, but note: MATLAB's save function
            % should also call the saveobj method of the Videomap object (cdata property), therefore
            % a local implementation of the store function is used to avoid storing the cdata twice.
            % THIS IS CHANGED: cdata property is now transient and save function should not be
            % called. Therefore, the objects store function is called here that will also call the
            % store function of the Videomap object. Note: saveobj is called twice for a single
            % object if saveing to pre-HDF5 (to determine the size).
            store(obj);
            
            % return a structure with the necessary information to restore the object from disk
            S = struct('filename',{},'memmap',{},'chunkSize',{});
            for k = 1:numel(obj)
                S(k).class     = class(obj(k));
                S(k).filename  = obj(k).filename;
                S(k).memmap    = obj(k).memmap;
                S(k).chunkSize = obj(k).p_cdata.chunkSize;
            end
            S = reshape(S,size(obj));
        end
        
        function             delete(obj)
            %delete Class destructor to close GUI
            
            notify(obj,'deletePlayer');
            obj.p_cdata.master = [];
        end
    end
    
    %% Static class related methods
    methods (Static = true, Access = public, Hidden = false)
        function obj       = loadobj(S)
            %loadobj Loads object and recalls data
            
            if isstruct(S)
                % make object of superclass if not specified otherwise in structure
                if isfield(S,'class'), func = str2func(S(1).class);
                else,                  func = str2func('Video');
                end
                % create object(s)
                if (numel(unique([S.memmap])) == 1 || all([S.memmap]>1)) && numel(unique([S.chunkSize])) == 1
                    obj = func({S.filename},'memmap',S(1).memmap,'chunkSize',S(1).chunkSize);
                else
                    % the allocation is performed here in a way that creates objects with the same
                    % cdata (a Videomap object). However, it should get when the default video
                    % object is replaced by its
                    % obj = reshape(func(numel(S)),size(S));
                    obj = func();
                    obj(numel(S)) = func();
                    for k = 1:numel(S)
                        obj(k)= func(S(k).filename,'memmap',S(k).memmap,'chunkSize',S(k).chunkSize);
                    end
                end
                obj = reshape(obj,size(S));
            else
                obj = S;
                p_recall(obj,true,false,true);
                % make sure to link Videomap and Video
                for i = 1:numel(obj), obj(i).p_cdata.master = obj(i); end
            end
        end
        
        function             convertMATFile(filename)
            %convertMATFile Converts MAT file of video class to new version
            % Old version: data is stored as single variables in the mat file
            % New version: data is stored as single structure
            
            % run each file separately
            if iscellstr(filename)
                for i = 1:numel(filename)
                    Video.convertMATFile(filename{i});
                end
                return;
            end
            % convert file:
            % * load complete file
            % * put all known class properties that are normally stored to disk into a structure
            %   called Video
            % * store file again with the new structure
            if ~(ischar(filename) && exist(filename,'file') == 2 && numel(dir(filename)) == 1)
                error(sprintf('%s:Input',mfilename),'File ''%s'' not found',filename);
            end
            [~, ~ , ext] = fileparts(filename);
            if ~strcmp(ext,'.mat')
                error(sprintf('%s:Input',mfilename),'File''%s '' is not a MAT found',filename);
            end
            props  = {'device','comment','map','pixres','pos','norm','date','userdata','time','exposure','name','track'};
            oldDat = load(filename);
            fn     = fieldnames(oldDat);
            if ismember('Video',fn)
                warning(sprintf('%s:Input',mfilename),'File ''%s'' seems to be converted already, no conversion performed',filename);
                return
            end
            newDat.Video = struct;
            for i = 1:numel(fn)
                if ismember(fn{i}, props)
                    newDat.Video.(fn{i}) = oldDat.(fn{i});
                else
                    newDat.(fn{i}) = oldDat.(fn{i});
                end
            end
            save(filename,'-struct','newDat');
        end
        
        function out       = parameterFileRead(in)
            %parameterFileRead Reads parameters and comments from simple parameter file as often
            % written by some lab equipment, first input is the filename, this file was basically
            % copied from the NGS01 class to make the Video class inpependent of the NGS01 class.
            %
            % Input is the filename to an info file:
            % * Comments in the file start with an % or # symbol
            % * Parameters are encoded in "<propertyname> : <propertyvalue>" style
            % * Function tries to interpret the values as numerical datatype
            %
            % Output is a structure with the parameters and all comment lines
            
            %
            % check input
            if exist(in,'file') ~= 2
                error(sprintf('%s:Input',mfilename),'File ''%s'' does not exist',in);
            end
            %
            % process file
            out.Comment = {};
            fid = fopen(in);
            str = fgetl(fid);
            while ischar(str)
                str = strtrim(str);
                if isempty(str)
                    % do nothing
                elseif strcmp(str(1),'%') || strcmp(str(1),'#')
                    out.Comment{end+1} = str;
                else
                    [token, remain] = strtok(str,':');
                    token  = strtrim(token);
                    if ~isempty(token)
                        remain = strtrim(remain(2:end));
                    end
                    switch token
                        otherwise
                            % try to read numeric value, otherwise store as
                            % string in structure
                            [tmp, status] = str2num(remain); %#ok<ST2NM>
                            if status
                                out.(matlab.lang.makeValidName(token)) = tmp;
                            else
                                out.(matlab.lang.makeValidName(token)) = remain;
                            end
                    end
                end
                str = fgetl(fid);
            end
            fclose(fid);
            out = orderfields(out);
        end
        
        function varargout = convert2DAT(varargin)
            % convert2DAT A wrapper function for the same function in the Videomap class
            
            [varargout{1:nargout}] = Videomap.convert2DAT(varargin{:});
        end
        
        function varargout = convert2VID(varargin)
            % convert2VID A wrapper function for the same function in the Videomap class
            
            [varargout{1:nargout}] = Videomap.convert2VID(varargin{:});
        end
    end
    
    %% Collection of static methods for video post processing
    methods (Static = true, Access = public, Hidden = false)
        %
        % Determine pixel resolution or similar from calibration images
        out                                                        = pixresFromAnyTarget(img)
        [pixres, rot, out, amp, pos, pixresLow]                    = pixresFromLineTarget(img,density)
        [imagePoints, boardSize, imageIdx, userCanceled, boardRot] = detectGridPoints(img,varargin)
        loc                                                        = pixelLocalMaxima(metric, loc, halfPatchSize)
        loc                                                        = pixelLocalSubMaxima(metric, loc, halfPatchSize)
        %
        % Transform image coordinates among different systems
        pos = pixAbs2pixRel(pos,cropRect)
        pos = pixRel2pixAbs(pos,cropRect)
        ind = indRel2indAbs(ind,cropRect,absSize)
        %
        % Test the image class
        out = isImage(img)
        out = isBWImage(img)
        out = isDoubleImage(img)
        out = isGrayINT16Image(img)
        out = isGrayUINT8Image(img)
        out = isGrayUINT16Image(img)
        %
        % Work on connected components
        imgOut = imgConnectComponents(img,minDist,maxDist)
        [CC,L] = imgLabelAlmostConnected(img,tol)
        %
        % GUIs for interactive input, e.g. creation of a mask in an image or pixel resolution
        varargout = guiGetMask(varargin);
        varargout = guiGetPixres(varargin);
        varargout = guiGetPixresLines(varargin);
        varargout = guiGetPixresSquare(varargin);
        %
        % Miscellaneous
        [ind, xy] = imgDrawLine(img,XY)
        [b, w]    = imgGetBlackWhiteValue(img)
        img       = imgColorize(img,pixellist,setColor,funcColor)
        out       = imgGetObjectSize(img, varargin)
        imgSetPixelMagnification(img,mag)
        %
        % Functions that work as transform function
        cdata = transform_SubtractBackground(cdata,bg,mode)
        %
        % Functions that work with process method of Video objects
        [ data, opt, init ] = process_SubtractBackground        ( data, opt, init, state, varargin )
        [ data, opt, init ] = process_Dummy                     ( data, opt, init, state, varargin )
        [ data, opt, init ] = process_WhereDidItGo              ( data, opt, init, state, varargin )
        [ data, opt, init ] = process_WasItHit                  ( data, opt, init, state, varargin )
        [ data, opt, init ] = process_DropFragMist_UID105       ( data, opt, init, state, varargin )
        [ data, opt, init ] = process_LabelCCFromFile           ( data, opt, init, state, varargin )
    end
end