classdef Videoplayer < handle
    %Videoplayer Class to display Video objects in a GUI
    %
    %----------------------------------------------------------------------------------
    %   Copyright 2016 Alexander Ludwig Klein, alexludwigklein@gmail.com
    %
    %   Physics of Fluids, University of Twente
    %----------------------------------------------------------------------------------
    
    %% Properties
    properties (GetAccess = public, SetAccess = public, Dependent = true)
        % frame Current frame number shown in GUI (double)
        frame = 1;
        % isTrack True/false whether track feature is enabled (logical)
        isTrack
        % isInfo True/false whether info feature is enabled (logical)
        isInfo
        % isProcess True/false whether process feature is enabled (logical)
        isProcess
        % isLoop True/false whether loop feature is enabled (logical)
        isLoop
        % isReverse True/false whether reverse feature is enabled (logical)
        isReverse
        % isSkip True/false whether reverse skip is enabled (logical)
        isSkip
        % isGUI True/false whether video player main is currently open (logical)
        isGUI
    end
    
    properties (GetAccess = public, SetAccess = protected, Transient = true)
        % vid Video objects to display (n x m Video)
        vid
        % frameVideo Frame of each video that is on display (index for cdata property for each video) (n x m double)
        frameVideo
        % opt Options for player (struct)
        opt
        % main Main figure (figure)
        main
        % mainPanel Uipanel to hold all other uicontrols (uipanel)
        mainPanel
        % sub_profile Figure to show profiles (figure)
        sub_profile
        % sub_compare Figure(s) to compare images (figure)
        sub_compare
        % sub_hist Figure(s) to show histogram (figure)
        sub_hist
        % sub_export Figure with axis for better export (figure)
        sub_export
        % panel Panel to hold axes for image display (n x m uipanel)
        panel
        % ax Axes to hold image (n x m axes)
        ax
        % img Image to show current frame (n x m image)
        img
        % axMenu Context menu for each video (n x m uimenu)
        axMenu
        % textX Text for x axis (n x m text)
        textX
        % textY Text for y axis (n x m text)
        textY
        % textT Text for title (n x m text)
        textT
        % iRange Information panel on range of pixel values (n x m uipanel)
        iRange
        % iPixel Information panel on pixel values of cursor (n x m uipanel)
        iPixel
        % idxFrames Cell with frame indices to show from each video (n x m cell)
        idxFrames
        % idxChannels Cell with channel indices to show from each video (n x m cell)
        idxChannels
        % nFrameMax Maximum number of frames to show (double)
        nFrameMax
        % nFrameMin Minimum number of frames to show (double)
        nFrameMin
        % ustr Unit string for length (n x m cellstr)
        ustr
        % usca Scaling factor for length (n x m double)
        usca
        % tstr Unit string for time (n x m cellstr)
        tstr
        % tsca Scaling factor for time (n x m double)
        tsca
        % process Place to store process function and data (cell of function handles)
        process
        % tagMain Tag for main figure (string)
        tagMain = 'Videoplayer_Main';
    end
    
    properties (GetAccess = public, SetAccess = protected, Dependent = true)
        % isPlay True/false whether video player is currently playing (logical)
        isPlay
        % isProfile True/false whether profile figure is currently open (logical)
        isProfile
        % isCompare True/false whether any compare figure is currently open (logical)
        isCompare
        % isHist True/false whether any histogram figure is currently open (logical)
        isHist
        % isExport True/false whether an export figure is currently open (logical)
        isExport
    end
    
    properties (GetAccess = protected, SetAccess = protected, Dependent = true)
        % state State of GUI during reset, etc. (struct)
        state
    end
    
    properties (GetAccess = protected, SetAccess = protected, Transient = true)
        % ui User interface objects, e.g. buttons (struct)
        ui = struct;
        % helper Some helper variables for the GUI (struct)
        helper = struct;
        % listener Listeners (struct)
        listener = struct;
        % p_state Storage for state
        p_state = struct;
        % p_frame Storage for frame
        p_frame = 1;
        % p_frameVideo Storage for frame
        p_frameVideo = [];
        % resolution Resolutions that can be choosen from when resizing (cellstr)
        resolution = {
            '1920x1080' '1920 x 1080, 16:9'
            '960x540'   '960 x 540, 16:9'
            '640x360'   '640 x 360, 16:9'
            '1024x768'  '1024 x 768, 4:3'
            '768x576'   '768 x 576, 4:3'
            '512x384'   '512 x 384, 4:3'};
    end
    
    %% Constructor/Destructor, SET/GET
    methods
        function obj   = Videoplayer(vid,varargin)
            %Videoplayer Class constructor taking the video object(s) as first argument
            % Any additional argument is passed to the input parser to obtain the options for the
            % instance of the video player, see code for further details
            
            %
            % accepts video(s) as input or numeric input to create an array of video player, make
            % sure each objects gets a - hopefully - unique tag for its figures
            if nargin < 1
                tmp         = randi(1e10);
                obj.tagMain = sprintf('%s_%0.10d',obj.tagMain, tmp);
                return;
            elseif isnumeric(vid)
                obj      = Videoplayer;
                obj(vid) = Videoplayer;
                for i = 1:numel(obj)
                    tmp            = randi(1e10);
                    obj(i).tagMain = sprintf('%s_%0.10d',obj(i).tagMain, tmp);
                end
                return;
            end
            tmp         = randi(1e10);
            obj.tagMain = sprintf('%s_%0.10d',obj.tagMain, tmp);
            %
            % add video and options to object
            initObject(obj,vid,varargin{:});
        end
        
        function delete(obj)
            %delete Class destructor to close GUI
            
            stop(obj);
            for i = 1:numel(obj.vid)
                obj.vid(i).player = [];
            end
            if obj.isGUI, delete(obj.main); end
            fn = fieldnames(obj.listener);
            for i = 1:numel(fn)
                delete(obj.listener.(fn{i}));
            end
        end
        
        function value = get.frameVideo(obj)
            if ~obj.isGUI
                obj.p_frameVideo = [];
            elseif isempty(obj.p_frameVideo)
                obj.p_frameVideo = NaN(size(obj.vid));
                for v = 1:numel(obj.vid)
                    if numel(obj.idxFrames{v}) >= obj.p_frame
                        obj.p_frameVideo(v) = obj.idxFrames{v}(obj.p_frame);
                    else
                        obj.p_frameVideo(v) = obj.idxFrames{v}(end);
                    end
                end
            end
            value = obj.p_frameVideo;
        end
        
        function value = get.isPlay(obj)
            value = obj.isGUI && isfield(obj.ui,'PBPlay') && ...
                isgraphics(obj.ui.PBPlay) && strcmp(obj.ui.PBPlay.String,'Pause');
        end
        
        function value = get.isProfile(obj)
            value = ~isempty(obj.sub_profile) && any(isgraphics(obj.sub_profile,'figure'));
        end
        
        function value = get.isCompare(obj)
            value = ~isempty(obj.sub_compare) && any(isgraphics(obj.sub_compare,'figure'));
        end
        
        function value = get.isHist(obj)
            value = ~isempty(obj.sub_hist) && any(isgraphics(obj.sub_hist,'figure'));
        end
        
        function value = get.isExport(obj)
            value = ~isempty(obj.sub_export) && any(isgraphics(obj.sub_export,'figure'));
        end
        
        function value = get.isGUI(obj)
            value = ~isempty(obj.main) && isgraphics(obj.main,'figure');
            % NOTE: the test should not include an isvalid(obj.main), since when the main figure is
            % being deleted it should also run certain code (e.g. code in deleteMain, which also
            % checks if the GUI is still open)
        end
        
        function         set.isGUI(obj,value)
            if (islogical(value) || isnumeric(value)) && isscalar(value)
                value = logical(value);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for the property');
            end
            if value, show(obj); else, exit(obj); end
        end
        
        function value = get.isTrack(obj)
            value = obj.isGUI && logical(obj.ui.CTrack.Value);
        end
        
        function         set.isTrack(obj,value)
            if (islogical(value) || isnumeric(value)) && isscalar(value)
                value = logical(value);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for the property');
            end
            if obj.isGUI
                obj.ui.CTrack.Value = value;
                if value
                    if any([obj.vid.lock])
                        obj.ui.CTrack.Value = false;
                        warning(sprintf('%s:Input',mfilename),'At least one video is locked, enabling track feature is not allowed');
                        return;
                    end
                    % clean tracks, enable contextmenus and update ROIs in axes
                    for i = 1:numel(obj.axMenu)
                        obj.vid(i).p_track = Videoplayer.trackClean(obj.vid(i).p_track);
                        idxM               = strcmp({obj.axMenu(i).Children.Label},'Track');
                        obj.axMenu(i).Children(idxM).Enable = 'on';
                    end
                    trackUpdate(obj);
                    trackROIUpdate(obj);
                else
                    % remove ROIs and disable context menu
                    trackHide(obj);
                    for i = 1:numel(obj.axMenu)
                        idxM = strcmp({obj.axMenu(i).Children.Label},'Track');
                        obj.axMenu(i).Children(idxM).Enable = 'off';
                    end
                    % remove profile figure
                    deleteProfile(obj);
                end
            else
                obj.p_state.isTrack = value;
            end
        end
        
        function value = get.isInfo(obj)
            value = obj.isGUI && logical(obj.ui.CInfo.Value);
        end
        
        function         set.isInfo(obj,value)
            if (islogical(value) || isnumeric(value)) && isscalar(value)
                value = logical(value);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for the property');
            end
            if obj.isGUI
                obj.ui.CInfo.Value = value;
                if value
                    % enable contextmenus and show info panels
                    for i = 1:numel(obj.axMenu)
                        idxM = strcmp({obj.axMenu(i).Children.Label},'Info');
                        obj.axMenu(i).Children(idxM).Enable = 'on';
                        if isgraphics(obj.iRange(i))
                            delete(obj.iRange(i));
                        end
                        obj.iRange(i) = imdisplayrange(obj.panel(i),obj.img(i));
                        if isgraphics(obj.iPixel(i))
                            delete(obj.iPixel(i));
                        end
                        obj.iPixel(i) = impixelinfo(obj.panel(i),obj.img(i));
                        set(obj.img(i),'UIContextMenu',obj.axMenu(i));
                    end
                else
                    % disable contextmenus and remove info panels
                    for i = 1:numel(obj.axMenu)
                        idxM = strcmp({obj.axMenu(i).Children.Label},'Info');
                        obj.axMenu(i).Children(idxM).Enable = 'off';
                        if isgraphics(obj.iRange(i))
                            delete(obj.iRange(i));
                        end
                        if isgraphics(obj.iPixel(i))
                            delete(obj.iPixel(i));
                        end
                    end
                    % delete profile figure
                    deleteProfile(obj);
                    deleteCompare(obj,true);
                    deleteHist(obj,true);
                end
            else
                obj.p_state.isInfo = value;
            end
        end
        
        function value = get.isProcess(obj)
            value = obj.isGUI && logical(obj.ui.CProcess.Value);
        end
        
        function         set.isProcess(obj,value)
            if (islogical(value) || isnumeric(value)) && isscalar(value)
                value = logical(value);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for the property');
            end
            if obj.isGUI
                switchValue(value);
            else
                obj.p_state.isProcess = value;
            end
            
            function switchValue(value)
                obj.ui.CProcess.Value = value;
                if value
                    if any([obj.vid.lock])
                        warning(sprintf('%s:Input',mfilename),'At least one video is locked, enabling process feature is not allowed');
                        switchValue(false);
                        return;
                    end
                    % do not allow feature if no function is available
                    if isempty(obj.opt.process)
                        switchValue(false);
                        return;
                    end
                    % enable contextmenus
                    for i = 1:numel(obj.axMenu)
                        idxM = strcmp({obj.axMenu(i).Children.Label},'Process');
                        obj.axMenu(i).Children(idxM).Enable = 'on';
                    end
                    % run init function and process one image to get an idea of the output and be able
                    % to reset channel settings, etc.
                    try
                        processInit(obj);
                        processRun(obj);
                    catch err
                        switchValue(false);
                        error(sprintf('%s:Error',mfilename),['Error during post processing of video, '...
                            'disabled process feature, please check error report:\n%s\n'],err.getReport);
                    end
                    for i = 1:numel(obj.vid)
                        if ~isempty(obj.process.func{i})
                            % check output of processing
                            if ~((isnumeric(obj.process.data{i}) || islogical(obj.process.data{i})) && size(obj.process.data{i},1)==obj.vid(i).nY && ...
                                    size(obj.process.data{i},2)==obj.vid(i).nX && ndims(obj.process.data{i}) <= 3)
                                switchValue(false);
                                error(sprintf('%s:Input',mfilename),'Video player only support process function which return images with the same X and Y size as the input');
                            end
                            % set idxChannels
                            nZ = size(obj.process.data{i},3);
                            if nZ == 3, obj.idxChannels{i} = 1:3;
                            else,       obj.idxChannels{i} = 1;
                            end
                            % set image size and class
                            obj.helper.imgSiz{i}(3) = nZ;
                            obj.helper.imgClass{i}  = class(obj.process.data{i});
                            % reset title
                            if isgraphics(obj.textT(i)) && numel(obj.textT(i).String) > 0
                                obj.textT(i).String{1} = ['PROCESS ' obj.textT(i).String{1}];
                            end
                            if isgraphics(obj.textT(i)) && numel(obj.textT(i).String) > 1
                                obj.textT(i).String{2} = sprintf('%d x %d x %d x %d (%s, transform = %d), CH %s, %.2f MiB (memmap = %d)', ...
                                    obj.helper.imgSiz{i}(2),obj.helper.imgSiz{i}(1),obj.helper.imgSiz{i}(3),obj.vid(i).nFrames,...
                                    obj.helper.imgClass{i},~isempty(obj.vid(i).transform),num2str(obj.idxChannels{i}),obj.vid(i).memoryDisk,obj.vid(i).memmap);
                            end
                            % set context menu
                            idxM = strcmp({obj.axMenu(i).Children.Label},'Channel');
                            delete(obj.axMenu(i).Children(idxM));
                            createChannelMenu(obj,i,obj.axMenu(i),obj.helper.imgSiz{i}(3),obj.idxChannels{i});
                        end
                    end
                    update(obj);
                else
                    % remove data
                    obj.process = [];
                    % disable context menu
                    for i = 1:numel(obj.axMenu)
                        idxM = strcmp({obj.axMenu(i).Children.Label},'Process');
                        obj.axMenu(i).Children(idxM).Enable = 'off';
                    end
                    % restore settings
                    resetIdxChannels(obj);
                    for i = 1:numel(obj.vid)
                        % reset image size and class
                        obj.helper.imgSiz{i}(3) = obj.vid(i).nZ;
                        obj.helper.imgClass{i}  = obj.vid(i).cdataClass;
                        % reset title
                        if isgraphics(obj.textT(i)) && numel(obj.textT(i).String) > 0
                            obj.textT(i).String{1} = sprintf('Video %d: %s',i,obj.vid(i).name);
                        end
                        if isgraphics(obj.textT(i)) && numel(obj.textT(i).String) > 1
                            obj.textT(i).String{2} = sprintf('%d x %d x %d x %d (%s, transform = %d), CH %s, %.2f MiB (memmap = %d)', ...
                                obj.helper.imgSiz{i}(2),obj.helper.imgSiz{i}(1),obj.helper.imgSiz{i}(3),obj.vid(i).nFrames,...
                                obj.helper.imgClass{i},~isempty(obj.vid(i).transform),num2str(obj.idxChannels{i}),obj.vid(i).memoryDisk,obj.vid(i).memmap);
                        end
                        % reset context menu
                        idxM = strcmp({obj.axMenu(i).Children.Label},'Channel');
                        delete(obj.axMenu(i).Children(idxM));
                        createChannelMenu(obj,i,obj.axMenu(i),obj.helper.imgSiz{i}(3),obj.idxChannels{i});
                    end
                    update(obj);
                end
            end
        end
        
        function value = get.isLoop(obj)
            value = obj.isGUI && logical(obj.ui.CLoop.Value);
        end
        
        function         set.isLoop(obj,value)
            if (islogical(value) || isnumeric(value)) && isscalar(value)
                value = logical(value);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for the property');
            end
            if obj.isGUI
                obj.ui.CLoop.Value = value;
            else
                obj.p_state.isLoop = value;
            end
        end
        
        function value = get.isReverse(obj)
            value = obj.isGUI && logical(obj.ui.CReverse.Value);
        end
        
        function         set.isReverse(obj,value)
            if (islogical(value) || isnumeric(value)) && isscalar(value)
                value = logical(value);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for the property');
            end
            if obj.isGUI
                obj.ui.CReverse.Value = value;
            else
                obj.p_state.isReverse = value;
            end
        end
        
        function value = get.isSkip(obj)
            value = obj.isGUI && logical(obj.ui.CSkip.Value);
        end
        
        function         set.isSkip(obj,value)
            if (islogical(value) || isnumeric(value)) && isscalar(value)
                value = logical(value);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for the property');
            end
            if obj.isGUI
                obj.ui.CSkip.Value = value;
            else
                obj.p_state.isSkip = value;
            end
        end
        
        function value = get.frame(obj)
            if ~obj.isGUI
                value = [];
            else
                value = obj.p_frame;
            end
        end
        
        function         set.frame(obj,value)
            if isnumeric(value) && isscalar(value) && round(value) >= obj.nFrameMin && round(value) <= obj.nFrameMax
                value = round(value);
                if obj.isGUI
                    obj.ui.EFrame.String = sprintf('%d',value);
                    obj.ui.SFrame.Value  = value;
                    if ~obj.isPlay
                        % store current ROI before update
                        if obj.isTrack, trackRead(obj); end
                        obj.p_frame      = value;
                        obj.p_frameVideo = [];
                        updateMain(obj);
                    else
                        obj.p_frame      = value;
                        obj.p_frameVideo = [];
                    end
                else
                    obj.p_frame      = value;
                    obj.p_frameVideo = [];
                end
            end
        end
        
        function value = get.state(obj)
            
            % store frame number
            value.frame     = obj.p_frame;
            % store general state of features that were enabled
            value.isGUI     = obj.isGUI;
            value.isPlay    = obj.isPlay;
            value.isTrack   = obj.isTrack;
            value.isInfo    = obj.isInfo;
            value.isProfile = obj.isProfile;
            value.isCompare = obj.isCompare;
            value.isHist    = obj.isHist;
            value.isExport  = obj.isExport;
            value.isProcess = obj.isProcess;
            value.isLoop    = obj.isLoop;
            value.isReverse = obj.isReverse;
            value.isSkip    = obj.isSkip;
            % store main figure position, styles and zoom of axes
            value.main.Position    = [];
            value.main.WindowStyle = 'normal';
            value.fov              = [];
            if obj.isGUI
                value.main.Position    = obj.main.Position;
                value.main.WindowStyle = obj.main.WindowStyle;
                value.fov              = Videoplayer.imageFOVGet(obj.ax);
            end
            % store remaing gui settings
            value.delay     = 0;
            if obj.isGUI
                value.delay = obj.ui.SDelay.Value;
            end
            % store state
            obj.p_state = value;
        end
        
        function         set.state(obj,value)
            if ~isempty(value), obj.p_state = value; end
            if isempty(fieldnames(obj.p_state)), return; end
            %
            % restore GUI
            if obj.p_state.isGUI
                show(obj);
                % update figures if they are still existing
                if obj.isExport,  createExport(obj,false); end
                if obj.isProfile, createProfile(obj,false); end
                if obj.isCompare, createCompare(obj,false); end
                if obj.isHist,    createHist(obj,false); end
                % features and states (many things are set in the create functions)
                obj.isTrack         = obj.p_state.isTrack;
                obj.isInfo          = obj.p_state.isInfo;
                obj.isProcess       = obj.p_state.isProcess;
                obj.isLoop          = obj.p_state.isLoop;
                obj.isReverse       = obj.p_state.isReverse;
                obj.isSkip          = obj.p_state.isSkip;
                obj.ui.SDelay.Value = obj.p_state.delay;
                % restore field of view, but update once before
                if ~isempty(obj.p_state.fov) && numel(obj.p_state.fov) == numel(obj.ax)
                    Videoplayer.imageFOVSet(obj.ax,obj.p_state.fov);
                end
                % text properties
                Videoplayer.changeFont(obj.main,obj.opt);
                % make sure the resize function is called once
                sizeChangedMain(obj,obj.mainPanel);
                % put video player to the front and start playing videos
                figure(obj.main);
                if obj.p_state.isPlay, play(obj); end
            end
            %
            % set frame number
            obj.frame = obj.p_state.frame;
        end
    end
    
    %% Methods for public tasks
    methods (Access = public, Hidden = false)
        function             play(obj)
            %play Plays video(s) in video player
            
            if numel(obj) > 1
                for i = 1:numel(obj)
                    show(obj(i));
                    play(obj(i));
                end
                return;
            end
            try
                hObject = obj.ui.PBPlay;
                % check the status of play button
                isStart = ~obj.isPlay;
                % store current ROI before update
                if isStart && obj.isTrack, trackRead(obj); end
                if isStart && obj.p_frame >= obj.nFrameMax && ~obj.isReverse
                    obj.frame = obj.nFrameMin;
                elseif isStart && obj.p_frame <= obj.nFrameMin && obj.isReverse
                    obj.frame = obj.nFrameMax;
                end
                if isStart, hObject.String = 'Pause'; hObject.TooltipString = 'Pause video(s) (MOD+p)';
                else,       hObject.String = 'Play';  hObject.TooltipString = 'Play video(s) (MOD+p)';
                end
                % keep playing
                maxStep   = obj.opt.skipFrames;
                frameStep = 1;
                t1        = tic;
                % show current frame
                updateMain(obj);
                % keep processing until button is pressed
                while strcmp(hObject.String, 'Pause') && ...
                        ((obj.p_frame <= obj.nFrameMax && ~obj.isReverse) || ...
                        (obj.p_frame  >= obj.nFrameMin &&  obj.isReverse))
                    % wait for next frame or adjust step size
                    t2    = toc(t1);
                    tWait = obj.ui.SDelay.Value*frameStep-t2;
                    if tWait < 0
                        frameStep = min(maxStep,frameStep + 1);
                    else
                        frameStep = max(1,frameStep - 1);
                        pause(tWait);
                    end
                    if ~obj.isSkip, frameStep = 1; end
                    % determine next frame to show
                    if ~obj.isReverse, nextFrame = obj.p_frame + frameStep;
                    else,              nextFrame = obj.p_frame - frameStep;
                    end
                    if nextFrame > obj.nFrameMax && obj.isLoop
                        obj.frame = 1;
                    elseif nextFrame > obj.nFrameMax
                        obj.frame = obj.nFrameMax;
                        updateMain(obj);
                        drawnow;
                        break;
                    elseif nextFrame < obj.nFrameMin && obj.isLoop
                        obj.frame = obj.nFrameMax;
                    elseif nextFrame < obj.nFrameMin
                        obj.frame = obj.nFrameMin;
                        updateMain(obj);
                        drawnow;
                        break;
                    else
                        obj.frame = nextFrame;
                    end
                    % update graphics
                    t1 = tic;
                    updateMain(obj);
                    drawnow;
                end
                hObject.String = 'Play'; hObject.TooltipString = 'Play video(s) (MOD+p)';
            catch ME
                % Re-throw error message if it is not related to invalid handle
                if ~strcmp(ME.identifier, 'MATLAB:class:InvalidHandle')
                    rethrow(ME);
                end
            end
        end
        
        function             stop(obj)
            %stop Stops playing in GUI of video player
            
            if numel(obj) > 1
                for i = 1:numel(obj), stop(obj(i)); end
                return;
            end
            if obj.isPlay
                obj.ui.PBPlay.String        = 'Play';
                obj.ui.PBPlay.TooltipString = 'Play video(s) (MOD+p)';
            end
        end
        
        function             exit(obj)
            %exit Exits GUI of video player
            
            if numel(obj) > 1
                for i = 1:numel(obj), exit(obj(i)); end
                return;
            end
            if obj.isGUI, delete(obj.main); end
        end
        
        function             hide(obj)
            %hide Hides GUI of video player
            
            if numel(obj) > 1
                for i = 1:numel(obj), hide(obj(i)); end
                return;
            end
            if obj.isGUI
                stop(obj);
                obj.main.Visible = 'off';
            end
        end
        
        function             reset(obj,varargin)
            %reset Resets GUI of video player
            
            p_reset(obj,true);
        end
        
        function             show(obj,varargin)
            %show Shows GUI of video player, additional arguments can be used to replace videos or
            % obtions, i.e. keep an existing figure but replace videos that are shown. The current
            % options will be reused in case no new ones are given.
            
            if numel(obj) > 1
                for i = 1:numel(obj), show(obj(i),varargin{:}); end
                return;
            end
            if numel(varargin) < 1
                % show player with current options
                if obj.isGUI
                    obj.main.Visible = 'on';
                    figure(obj.main);
                else
                    createMain(obj);
                end
            else
                % * store current state
                % * replace videos, but keep options if no new options are given, but reset some if
                %   the number of videos change
                % * if no videos are given, reset player with current videos but new options
                % * replace with new options and new videos
                if numel(varargin) < 2 && isa(varargin{1},'Video')
                    myopt = obj.opt;
                    nVid  = numel(varargin{1});
                    if nVid ~= numel(obj.vid)
                        myopt.montage     = [];
                        myopt.idxChannels = [];
                        myopt.idxFrames   = [];
                        if nVid <= numel(obj.vid)
                            if iscell(myopt.process),    myopt.process    = myopt.process(1:nVid); end
                            if iscell(myopt.unitLength), myopt.unitLength = myopt.unitLength(1:nVid); end
                            if iscell(myopt.unitTime),   myopt.unitTime   = myopt.unitTime(1:nVid); end
                        else
                            if iscell(myopt.process),    myopt.process    = myopt.process{1}; end
                            if iscell(myopt.unitLength), myopt.unitLength = myopt.unitLength{1}; end
                            if iscell(myopt.unitTime),   myopt.unitTime   = myopt.unitTime{1}; end
                        end
                    end
                    initObject(obj,varargin{1},myopt);
                elseif ~isa(varargin{1},'Video')
                    initObject(obj,obj.vid,varargin{:});
                elseif isa(varargin{1},'Video')
                    initObject(obj,varargin{1},varargin{2:end});
                else
                    error(sprintf('%s:Input',mfilename),'Input for show method is unexpected');
                end
            end
        end
        
        function             update(obj)
            %update Updates GUI of video player, e.g. to show change in cdata or tracks of videos
            
            if numel(obj) > 1
                for i = 1:numel(obj), update(obj(i)); end
                return;
            end
            if obj.isGUI && ~obj.isPlay
                updateMain(obj);
            end
        end
        
        function varargout = exportFigure(obj)
            %exportFigure Creates export figure and returns figure object
            
            nargoutchk(0,1);
            if numel(obj) > 1
                for i = 1:numel(obj), exportFigure(obj(i)); end
                return;
            end
            if ~obj.isExport
                if ~obj.isGUI, obj.show; end
                createExport(obj,true);
            end
            %
            % output
            if nargout > 0
                varargout = {obj.sub_export};
                varargout = varargout(1:nargout);
            end
        end
        
        function varargout = export(obj,varargin)
            %export Plays and exports current GUI of video player as a single movie
            
            nargoutchk(0,1);
            if numel(obj) > 1
                for i = 1:numel(obj), export(obj(i),varargin{:}); end
                return;
            end
            %
            % prepare video player
            if ~obj.isGUI, return; end
            if obj.isPlay, stop(obj); end
            %
            % use input parser to process options
            set               = inputParser;
            set.StructExpand  = true;
            set.KeepUnmatched = false;
            % absolute basename for filename to use, empty leads to a default
            set.addParameter('filename', [], ...
                @(x) isempty(x) || (ischar(x) && numel(x) > 0));
            % profile to use
            set.addParameter('profile', 'MPEG-4', ...
                @(x) ischar(x) && ismember(x,{'MPEG-4','Archival','Motion JPEG AVI','Motion JPEG 2000','TIF','PNG','PNGFFMPEG'}));
            % absolute basename for filename to use, empty leads to a default
            set.addParameter('ffmpegCommand', '/usr/local/bin/ffmpeg', ...
                @(x) ischar(x) && numel(x) > 0);
            % framerate if supported by profile
            set.addParameter('framerate', 10, ...
                @(x) isnumeric(x) && isscalar(x) && x>0);
            % overwrite files
            set.addParameter('overwrite', true, ...
                @(x) islogical(x) && isscalar(x));
            % select only certain frames from the data to play, empty value leads to all frames of
            % video player to be shown
            set.addParameter('idxFrames', [], ...
                @(x) isempty(x) || (isnumeric(x) && min(x) >= obj.nFrameMin && max(x) <= obj.nFrameMax))
            % additional options for export_fig, such as quality
            set.addParameter('options', {'-m1','-nocrop'}, ...
                @(x) iscell(x));
            % make a dry run without exporting, just show video in player
            set.addParameter('dryRun', false, ...
                @(x) islogical(x) && isscalar(x));
            set.parse(varargin{:});
            set = set.Results;
            %
            % prepare new filename
            if isempty(set.filename)
                if numel(obj.vid) == 1 && ~isempty(obj.vid.name)
                    strBase = sprintf('%s_Export_%s',matlab.lang.makeValidName(obj.vid.name),datestr(now,'yyyy-mm-dd'));
                else
                    strBase = sprintf('Videoplayer_Export_%s',datestr(now,'yyyy-mm-dd'));
                end
                counter = 0;
                while exist(sprintf('%s_%0.2d',strBase,counter),'file') == 2 || ...
                        exist(sprintf('%s_%0.2d.tif',strBase,counter),'file') == 2 || ...
                        exist(sprintf('%s_%0.2d.mp4',strBase,counter),'file') == 2 || ...
                        exist(sprintf('%s_%0.2d.png',strBase,counter),'file') == 2 || ...
                        exist(sprintf('%s_%0.2d_%0.6d.png',strBase,counter,0),'file') == 2
                    counter = counter + 1;
                end
                filename = sprintf('%s_%0.2d',strBase,counter);
            else
                filename = set.filename;
            end
            switch set.profile
                case {'MPEG-4' 'Archival' 'Motion JPEG AVI' 'Motion JPEG 2000'}
                    mov           = VideoWriter(filename,set.profile);
                    mov.FrameRate = set.framerate;
                    fnExport      = mov.Filename;
                case 'TIF'
                    fnExport = fullfile([filename '.tif']);
                case {'PNG' 'PNGFFMPEG'}
                    fnExport = fullfile([filename '_000000.png']);
            end
            if ~set.overwrite && exist(fnExport,'file') == 2 && numel(dir(fnExport)) == 1
                warning(sprintf('%s:Export',mfilename),...
                    'File ''%s'' already exists and overwriting is disabled, no data exported',fnExport);
                return;
            end
            %
            % get number of frames
            myFrames = set.idxFrames;
            if ~isempty(myFrames), myFrames = reshape(myFrames,1,[]);
            else,                  myFrames = obj.nFrameMin:obj.nFrameMax;
            end
            if isempty(myFrames)
                warning(sprintf('%s:Export',mfilename),...
                    'Current data and settings lead to file ''%s'' containing no frames, no data exported',fnExport);
                return;
            end
            %
            % export data
            isMyExport = obj.isExport;
            nDig       = 1+ceil(log10(numel(myFrames)));
            [pathTemp, strTemp] = fileparts(tempname);
            fnTemp     = fullfile(pathTemp,sprintf('Videoplayer_%s.png',strTemp));
            nPanel     = numel(obj.panel);
            [ni,~]     = size(obj.panel);
            imgExp     = cell(size(obj.panel));
            % initialize
            fprintf('Writing %d frames to file ''%s''\n',numel(myFrames),fnExport);
            switch set.profile
                case {'MPEG-4' 'Archival' 'Motion JPEG AVI' 'Motion JPEG 2000'}
                    if ~set.dryRun, mov.open; end
                case {'TIF'}
                    % write to TIF with LZW compression (should make sure imageJ can read it), use
                    % 64 bit addressing, use FEX submission saveastiff
                    options.color   = false;
                    options.comp    = 'lzw';
                    options.message = false;
                    options.ask     = false;
                    options.append  = true;
                    options.big     = true;
                    if ~set.dryRun && exist(fnExport,'file') == 2 && numel(dir(fnExport)) == 1
                        delete(fnExport);
                    end
                case {'PNG' 'PNGFFMPEG'}
                    if isMyExport, options = {'-transparent'};
                    else,          options = {};
                    end
            end
            % run
            try
                counter = 0;
                for idx = myFrames
                    fprintf('  %*d of %*d frames: %*d to %*d\n',...
                        nDig,1,nDig,numel(myFrames),nDig,idx,nDig,idx);
                    obj.frame = idx;
                    if set.dryRun
                        drawnow;
                    else
                        if isMyExport
                            switch set.profile
                                case {'MPEG-4' 'Archival' 'Motion JPEG AVI' 'Motion JPEG 2000'}
                                    export_fig(fnTemp,'-png',set.options{:},obj.sub_export);
                                    imgAll = imread(fnTemp);
                                    writeVideo(mov,imgAll);
                                case {'TIF'}
                                    export_fig(fnTemp,'-png',set.options{:},obj.sub_export);
                                    imgAll = imread(fnTemp);
                                    if size(imgAll,3) > 1
                                        options.color = true;
                                    end
                                    saveastiff(imgAll,fnExport,options);
                                case {'PNG' 'PNGFFMPEG'}
                                    fnPNG = fullfile([filename sprintf('_%0.6d.png',counter)]);
                                    export_fig(fnPNG,'-png',set.options{:},options{:},obj.sub_export);
                            end
                        else
                            for i = 1:nPanel
                                export_fig(fnTemp,'-png',set.options{:},obj.panel(i));
                                imgExp{i} = imread(fnTemp);
                            end
                            imgAll  = [];
                            nDepth  = cellfun(@(x) size(x,3),imgExp);
                            % extend in depth in case color and gray scale are combined
                            if numel(unique(nDepth)) > 1
                                if max(nDepth) == 3 && all(nDepth == 3 | nDepth == 1)
                                    iDepth = nDepth == 1;
                                    imgExp(iDepth) = cellfun(@(x) repmat(x,[1 1 3]),imgExp(iDepth),'un',false);
                                else
                                    error(sprintf('%s:Input',mfilename),'Unexpexted combination of color and non-color images? Please check!');
                                end
                            end
                            for i = 1:ni
                                imgAll = cat(1,imgAll,cat(2,imgExp{i,:}));
                            end
                            switch set.profile
                                case {'MPEG-4' 'Archival' 'Motion JPEG AVI' 'Motion JPEG 2000'}
                                    writeVideo(mov,imgAll);
                                case {'TIF'}
                                    if size(imgAll,3) > 1
                                        options.color = true;
                                    end
                                    saveastiff(imgAll,fnExport,options);
                                case {'PNG' 'PNGFFMPEG'}
                                    fnPNG = fullfile([filename sprintf('_%0.6d.png',counter)]);
                                    export_fig(fnPNG,'-png',set.options{:},options{:},obj.panel(i));
                            end
                        end
                    end
                    counter = counter + 1;
                end
            catch err
                if exist(fnTemp,'file') == 2, delete(fnTemp); end
                error(sprintf('%s:Error',mfilename),['Error during video export:\n%s\n'...
                    'Nevertheless, tried to clean up temporary file ''%s'''],err.getReport,fnTemp);
            end
            % clean
            switch set.profile
                case {'MPEG-4' 'Archival' 'Motion JPEG AVI' 'Motion JPEG 2000'}
                    if ~set.dryRun, mov.close; end
                case {'TIF'}
                case {'PNG' 'PNGFFMPEG'}
                    % running somthing like:
                    % ffmpeg -r 10 -i img_%6d.png -qscale 1 -vcodec qtrle img.mov
                    % ffmpeg -r 10 -i img_%6d.png -qscale 1 -vcodec prores_ks img.mov
                    strCMD = [set.ffmpegCommand ' -r ' num2str(set.framerate) ' -i ' filename '_%6d.png ' '-qscale 1 -vcodec prores_ks' ' ' filename '.mov'];
                    if strcmp(set.profile,'PNG')
                        fprintf('Note: to convert single PNGs to a transparent movie with FFMPEG, try to run:\n%s\n',strCMD);
                    else
                        fnExport = [filename '.mov'];
                        fprintf('Trying to run:\n%s\n',strCMD);
                        if ~set.dryRun
                            system(strCMD, '-echo');
                        end
                        fn     = dir(fullfile([filename '_*.png']));
                        nChar  = numel(fullfile([filename '_000000.png']));
                        for i = 1:numel(fn)
                            if numel(fn(i).name) == nChar && str2double(fn(i).name(end-9:end-4)) == i-1
                                delete(fn(i).name);
                            end
                        end
                    end
            end
            if exist(fnTemp,'file') == 2, delete(fnTemp); end
            if set.dryRun
                fprintf('  Finished exporting to file ''%s'' (DRY RUN)\n',fnExport);
            else
                fprintf('  Finished exporting to file ''%s''\n',fnExport);
            end
            %
            % output
            if nargout > 0
                varargout = {set};
                varargout = varargout(1:nargout);
            end
        end
        
        function mypos     = transformCoordinates(obj,idxAx,mypos,roi,trans)
            %transformCoordinates Transforms coordinates of ROI in given axes, basically a wrapper
            % of trackROIPosition.

            % check input
            assert(isscalar(idxAx) && idxAx > 0 && idxAx <= numel(obj.vid), ...
                'Index of axes is not valid');
            assert(isnumeric(mypos), ...
                'Position is not valid');
            assert(ischar(roi) || isa(roi,'imroi'), ...
                'ROI is not valid');
            assert(ischar(trans) && ismember(trans,{'real2ax','ax2real'}), ...
                'Transformation is unknown');
            if ischar(roi), strROI = roi;
            else,           strROI = class(roi);
            end
            assert(ismember(strROI,{'imline', 'impoly', 'impoint', 'imdistline' 'imellipse','imrect'}), ...
                sprintf('ROI ''%s'' is unknown',strROI));
            % call workhorse function
            mypos = trackROIPosition(obj,idxAx,mypos,strROI,trans);
        end
    end
    
    %% Methods for private tasks
    methods (Access = protected, Hidden = false)
        function         initObject(obj,vid,varargin)
            %initObject Initializes single object with given videos and options and creates figure
            
            %
            % check input arguments
            validateattributes(vid,{'Video'},{'2d','nonempty'});
            %
            % check number of videos
            if numel(vid) > 1
                bak     = obj.vid;
                obj.vid = ones(size(vid));
                obj.opt = parseInput(obj,varargin{:});
                obj.vid = bak;
                if numel(vid) > obj.opt.maxFigure
                    button = questdlg(sprintf('This will play %d videos. Continue?',numel(vid)), ...
                        sprintf('%s:play',mfilename), 'Yes, show all videos','Yes, but show only the first video',...
                        'Yes, but show only the first video');
                    if ~strcmp(button,'Yes, show all videos')
                        vid = vid(1);
                    end
                end
            end
            for i = 1:numel(vid)
                if ~isempty(vid(i).player) && ~(vid(i).player == obj)
                    error(sprintf('%s:Input',mfilename),['Video ''%s'' seems to be already shown ',...
                        'in a video player'],vid(i).name);
                end
            end
            if numel(varargin) == 1 && isempty(varargin{1}), varargin = {}; end
            %
            % clean object in case it is already showing something, leave figure intact
            clean(obj);
            for i = 1:numel(obj.vid); obj.vid(i).player = []; end
            %
            % parse input options
            obj.vid = vid;
            obj.opt = parseInput(obj,varargin{:});
            %
            % add video objects to video player
            montage = obj.opt.montage;
            if isempty(montage)
                montage = reshape(1:numel(vid),size(vid));
            end
            obj.vid = reshape(vid(montage),size(montage));
            % backup video if no backup exists
            for i = 1:numel(obj.vid)
                if isempty(obj.vid(i).backupData)
                    backup(obj.vid(i));
                end
            end
            % create listeners
            fn = fieldnames(obj.listener);
            for i = 1:numel(fn)
                delete(obj.listener.(fn{i}));
            end
            for i = 1:numel(obj.vid)
                obj.vid(i).player       = obj;
                obj.listener.showPlayer = event.listener(obj.vid,'showPlayer',...
                    @(src,event) show(obj));
                obj.listener.deletePlayer = event.listener(obj.vid,'deletePlayer',...
                    @(src,event) delete(obj));
                obj.listener.exitPlayer = event.listener(obj.vid,'exitPlayer',...
                    @(src,event) exit(obj));
                obj.listener.resetPlayer = event.listener(obj.vid,'resetPlayer',...
                    @(src,event) p_reset(obj,true));
                obj.listener.disableTrack = event.listener(obj.vid,'disableTrack',...
                    @(src,event) respondToEvents(obj,'disableTrack'));
                obj.listener.enableTrack = event.listener(obj.vid,'enableTrack',...
                    @(src,event) respondToEvents(obj,'enableTrack'));
                obj.listener.updatePlayer = event.listener(obj.vid,'updatePlayer',...
                    @(src,event) update(obj));
            end
            %
            % create figure
            createMain(obj);
        end
        
        function value = parseInput(obj,varargin)
            %parseInput Parses input and returns structure with options
            
            tmp               = inputParser;
            tmp.StructExpand  = true;
            tmp.KeepUnmatched = false;
            % show warning and ask for confirmation if there are too many videos to show
            tmp.addParameter('maxFigure', 10, ...
                @(x) isnumeric(x) && isscalar(x));
            % position of layer with grid lines relative to image data in each axis
            tmp.addParameter('layer', 'top', ...
                @(x) ischar(x) && ismember(x,{'top','bottom'}));
            % unit to use for axis or normalization value as numeric input or cell to specify
            % scaling for each video separately, empty for automatic selection
            tmp.addParameter('unitLength', [], ...
                @(x) isempty(x) || (ischar(x) && ismember(x,{'m', 'mm', 'ym', 'pix'})) || ...
                isnumeric(x) || iscell(x));
            % unit to use for time or normalization value as numeric input or cell to specify
            % scaling for each video separately, empty for automatic selection
            tmp.addParameter('unitTime', [], ...
                @(x) isempty(x) || (ischar(x) && ismember(x,{'s','ms','ys','ns'})) ||...
                isnumeric(x) || iscell(x));
            % true/false whether to link axes that share the same label along a single axis
            tmp.addParameter('linkAxes', false, ...
                @(x) islogical(x) && isscalar(x))
            % show only ever xth row and column of the cdata of each video
            tmp.addParameter('stepImage', 1, ...
                @(x) isnumeric(x) && isscalar(x) && x > 0)
            % maximum number of frames to skip if option is enabled in GUI
            tmp.addParameter('skipFrames', 4, ...
                @(x) isnumeric(x) && isscalar(x) && x > 0)
            % montage videos in given arrangement, e.g [1 4; 2 3] to play first video in top left,
            % second video bottom left. etc.
            tmp.addParameter('montage', [], ...
                @(x) isempty(x) || (isnumeric(x) && max(x(:))<=numel(obj.vid) && min(x(:)) > 0));
            % select only certain frames from the data to play, empty value leads to all frames
            tmp.addParameter('idxFrames', [], ...
                @(x) isempty(x) || (isnumeric(x) && min(x)>0) || iscell(x));
            % select only certain color channels
            tmp.addParameter('idxChannels', [], ...
                @(x) isempty(x) || (isnumeric(x) && min(x)>0) || iscell(x));
            % add a post processing function that is applied to each frame before display, see
            % process method in Video class that uses the same kind of function, but here only one
            % function can be given or a cell, since a cell is interpreted as different process
            % function for each video
            tmp.addParameter('process', [], ...
                @(x) isempty(x) || (isa(x,'function_handle') && (abs(nargin(x)) == 1 || abs(nargin(x))>=4)) || ...
                (iscell(x) && numel(x) == numel(obj.vid) && ...
                all(cellfun(@(y) isempty(y) || (isa(y,'function_handle') && (abs(nargin(y))==1 || abs(nargin(y))>=4)),x))));
            % How to get the ROI's position for a frame that has not been tracked so far?
            %   linear: interpolate from already known positions (no extrapolation, but nearest)
            %  nearest: use nearest location
            %  initial: use the initial position
            %
            % Note: the color is never interpolated, but the initial or nearest value is used (also
            % in linear tracking mode)
            tmp.addParameter('trackMode', 'nearest', ...
                @(x) ischar(x) && ismember(x,{'linear','nearest','initial'}));
            % compare mode (see imfuse)
            tmp.addParameter('compareMode', 'falsecolor', ...
                @(x) ischar(x) && ismember(x,{'falsecolor','blend','diff'}));
            % function handle called when the export figure is updated to allow for special update
            tmp.addParameter('exportFunc', [], ...
                @(x) isempty(x) || isa(x,'function_handle') || ...
                (iscell(x) && all(cellfun(@(y) isa(y,'function_handle'),x))));
            % cut values in alpha blending in export figure, empty value to disable
            tmp.addParameter('alphaCut', [], ...
                @(x) isempty(x) || (isnumeric(x) && numel(x) == 2 && min(x) >= 0 && max(x) <= 1));
            % font size for axes and text
            tmp.addParameter('fontSize', [], ...
                @(x) isempty(x) || (isnumeric(x) && isscalar(x) && min(x) > 0));
            % font name for axes and text
            tmp.addParameter('fontName', [], ...
                @(x) isempty(x) || ischar(x));
            % font weight for axes and text
            tmp.addParameter('fontWeight', [], ...
                @(x) isempty(x) || ischar(x));
            % font angle for axes and text
            tmp.addParameter('fontAngle', [], ...
                @(x) isempty(x) || ischar(x));
            % direction of scroll wheel action
            tmp.addParameter('scrollDirection', 1, ...
                @(x) isnumeric(x) && isscalar(x) && ismember(x,[-1 1]));
            tmp.parse(varargin{:});
            value = tmp.Results;
        end
        
        function         p_reset(obj,reUse,varargin)
            %p_reset Resets GUI with or without reusing part of the GUI
            
            if numel(obj) > 1
                for i = 1:numel(obj), p_reset(obj(i)); end
                return;
            end
            if obj.isGUI
                if numel(varargin) < 1
                    obj.state;
                    clean(obj);
                    createMain(obj,reUse);
                else
                    % reset with new videos and/or options
                    show(obj,varargin{:});
                end
            end
        end
        
        function         clean(obj)
            %clean Cleans object to allow change to video data
            
            if obj.isGUI
                % store state for recover
                obj.state;
                % clean figures
                stop(obj);
                Videoplayer.disableInteractiveModes(obj.main);
                trackHide(obj);
                cleanProfile(obj);
                cleanHist(obj);
                cleanExport(obj);
                cleanCompare(obj);
            end
        end
        
        function         respondToEvents(obj,event)
            %respondToEvents Responds to some events send out by video object(s)
            
            switch event
                case 'enableTrack'
                    for i = 1:numel(obj)
                        obj.isTrack = true;
                    end
                case 'disableTrack'
                    for i = 1:numel(obj)
                        obj.isTrack = false;
                    end
            end
        end
        
        function         resetIdxChannels(obj)
            %resetIdxChannels Finds settings for the number of channels
            
            if isempty(obj.opt.idxChannels)
                obj.idxChannels = cell(size(obj.vid));
            elseif isnumeric(obj.opt.idxChannels)
                obj.idxChannels = repmat({obj.opt.idxChannels},size(obj.vid));
            elseif ~(iscell(obj.opt.idxChannels) && numel(obj.opt.idxChannels) == numel(obj.vid))
                error(sprintf('%s:Input',mfilename),'Input for idxChannels is unexpected');
            end
            for i = 1:numel(obj.idxChannels)
                if isempty(obj.idxChannels{i})
                    if obj.vid(i).nZ == 3, obj.idxChannels{i} = 1:3;
                    else,                  obj.idxChannels{i} = 1;
                    end
                elseif isnumeric(obj.idxChannels{i}) && min(obj.idxChannels{i})>0 && ...
                        max(obj.idxChannels{i}<=obj.vid(i).nZ) && ...
                        (isscalar(obj.idxChannels{i}) || numel(obj.idxChannels{i})==3)
                    obj.idxChannels{i} = round(reshape(obj.idxChannels{i},1,[]));
                else
                    error(sprintf('%s:Input',mfilename),'Input for idxChannels is unexpected')
                end
            end
        end
        
        function         processInit(obj,idx)
            %processInit Initializes processing
            
            if isempty(obj.opt.process), return; end
            if nargin < 2, idx = 1:numel(obj.vid); end
            % initialize options for post processing function, see process method in Video class
            optFunc.verbose      = 0;
            optFunc.debug        = true;
            optFunc.runmode      = 'images';
            optFunc.outmode      = 'cdata';
            optFunc.ignoreOutput = true;
            optFunc.chunkSize    = 512;
            optFunc.globalParFor = false;
            optFunc.playDebug    = true;
            optFunc.idxFrames    = 1;
            optFunc.curFrames    = 1;
            optFunc              = repmat(optFunc,size(obj.vid));
            for i = 1:numel(optFunc), optFunc(i).idxFrames = obj.idxFrames{i}; end
            % init process property
            if isa(obj.opt.process,'function_handle')
                obj.process      = struct;
                obj.process.func = repmat({obj.opt.process},size(obj.vid));
            elseif iscell(obj.opt.process) && numel(obj.opt.process) == numel(obj.vid)
                obj.process      = struct;
                obj.process.func = reshape(obj.opt.process,size(obj.vid));
            else
                error(sprintf('%s:Input',mfilename),'Input for process is unexpected');
            end
            obj.process.opt    = optFunc;
            obj.process.init   = repmat({[]},size(obj.vid));
            obj.process.data   = repmat({[]},size(obj.vid));
            obj.process.nInput = NaN(size(obj.vid));
            % run init part of functions
            for v = reshape(idx,1,[])
                if ~isempty(obj.process.func{v})
                    obj.process.nInput(v) = nargin(obj.process.func{v});
                    if abs(obj.process.nInput(v)) >= 4 || obj.process.nInput(v) == -1
                        [obj.vid(v), obj.process.opt(v), obj.process.init{v}] = obj.process.func{v}(obj.vid(v),...
                            obj.process.opt(v), obj.process.init{v}, 'pre');
                    elseif obj.process.nInput(v) == 1
                        obj.process.func{v}(obj.vid(v).cdata(:,:,:,1));
                    else
                        error(sprintf('%s:Input',mfilename),['Post processing function(s) should ',...
                            'accept either one, four or varargin inputs, such that nargin returns 1, ',...
                            '4 or -1 but not %d'],obj.process.nInput(v));
                    end
                end
            end
            % check if runmode and outmode are still fine
            if ~(all(strcmp('images',{obj.process.opt.runmode})) && ...
                    all(strcmp('cdata',{obj.process.opt.outmode})))
                obj.process   = [];
                obj.isProcess = false;
                error(sprintf('%s:Input',mfilename),['Video player only support process function ',...
                    'with runmode == ''images'' and outmode == ''cdata'', disabled process feature']);
            end
        end
        
        function         processRun(obj,idx)
            %processRun  Runs processing for current frame and given video
            
            if isempty(obj.process), return; end
            if nargin < 2, idx = 1:numel(obj.vid); end
            % process current frame and store result
            for v = reshape(idx,1,[])
                obj.process.opt(v).curFrames = obj.frameVideo(v);
                if ~isempty(obj.process.func{v})
                    if abs(obj.process.nInput(v)) >= 4 || obj.process.nInput(v) == -1
                        [obj.process.data{v}, obj.process.opt(v), obj.process.init{v}] = obj.process.func{v}(...
                            obj.vid(v).cdata(:,:,:,obj.frameVideo(v)),obj.process.opt(v),obj.process.init{v},'run');
                    else
                        obj.process.data{v} = obj.process.func{v}(obj.vid(v).cdata(:,:,:,obj.frameVideo(v)));
                    end
                end
            end
        end
        
        function         processPost(obj,idx)
            %processPost  Runs post processing
            
            if isempty(obj.process), return; end
            if nargin < 2, idx = 1:numel(obj.vid); end
            % clean up
            for v = reshape(idx,1,[])
                if ~isempty(obj.process.func{v})
                    if abs(obj.process.nInput(v)) >= 4 || obj.process.nInput(v) == -1
                        obj.vid(v) = obj.process.func{v}(obj.vid(v),...
                            obj.process.opt(v), obj.process.init{v}, 'post');
                    end
                end
            end
        end
        
        function         createMain(obj,reUse)
            %createMain (Re-)creates the figure for the video player
            
            if nargin < 2, reUse = true; end
            % make sure playback is stopped
            stop(obj);
            %
            % check number of videos
            if numel(obj.vid) > 1
                if numel(obj.vid) > obj.opt.maxFigure
                    button = questdlg(sprintf('This will play %d videos. Continue?',numel(obj.vid)), ...
                        sprintf('%s:play',mfilename), 'Yes, show all videos','Yes, but show only the first video',...
                        'Yes, but show only the first');
                    if ~strcmp(button,'Yes, show all videos')
                        obj.vid = obj.vid(1);
                    end
                end
            elseif numel(obj.vid) < 1
                error(sprintf('%s:Input',mfilename),'At least one video is required to be played')
            end
            ni = size(obj.vid,1);
            nj = size(obj.vid,2);
            %
            % prepare number of frames
            if isempty(obj.opt.idxFrames)
                obj.idxFrames = cell(size(obj.vid));
            elseif isnumeric(obj.opt.idxFrames)
                obj.idxFrames = repmat({obj.opt.idxFrames},size(obj.vid));
            elseif iscell(obj.opt.idxFrames) && numel(obj.opt.idxFrames) == numel(obj.vid)
                obj.idxFrames = obj.opt.idxFrames;
            else
                error(sprintf('%s:Input',mfilename),'Input for idxFrames is unexpected');
            end
            for i = 1:numel(obj.idxFrames)
                if isempty(obj.idxFrames{i})
                    obj.idxFrames{i} = 1:obj.vid(i).nFrames;
                elseif isnumeric(obj.idxFrames{i}) && min(obj.idxFrames{i})>0
                    obj.idxFrames{i} = reshape(obj.idxFrames{i},1,[]);
                    obj.idxFrames{i}(obj.idxFrames{i} > obj.vid(i).nFrames) = [];
                else
                    error(sprintf('%s:Input',mfilename),'Input for idxFrames is unexpected')
                end
            end
            obj.nFrameMin      = 1;
            obj.nFrameMax      = max(cellfun(@numel,obj.idxFrames(:)));
            obj.p_frameVideo   = [];
            obj.opt.skipFrames = ceil(obj.opt.skipFrames);
            %
            % prepare channel index
            resetIdxChannels(obj);
            %
            % prepare unit scaling
            % length
            unitLength = obj.opt.unitLength;
            if isempty(unitLength)
                unitLength = cell(size(obj.vid));
                for i = 1:numel(obj.vid)
                    logSize = log10(sqrt(diff(obj.vid(i).x([1 end]))^2+diff(obj.vid(i).x([1 end]))^2));
                    if     logSize < -4, unitLength{i} = 'ym';
                    elseif logSize < -1, unitLength{i} = 'mm';
                    else,                unitLength{i} = 'm';
                    end
                end
            end
            if ischar(unitLength) || (isnumeric(unitLength) && isscalar(unitLength))
                unitLength = repmat({unitLength},ni,nj);
            elseif isnumeric(unitLength) && isequal(size(unitLength),[ni nj])
                unitLength = num2cell(unitLength);
            elseif ~(iscell(unitLength) && isequal(size(unitLength),[ni nj]))
                error(sprintf('%s:Input',mfilename),'Input for unitLength is unexpected')
            end
            obj.ustr = cell(ni,nj);
            obj.usca = NaN(ni,nj);
            for i = 1:numel(unitLength)
                if ischar(unitLength{i})
                    switch unitLength{i}
                        case 'm'
                            obj.ustr{i}  =   'm'; obj.usca(i) = 1;
                        case 'mm'
                            obj.ustr{i}  =  'mm'; obj.usca(i) = 1e3;
                        case 'ym'
                            obj.ustr{i}  =  'ym'; obj.usca(i) = 1e6;
                        case 'pix'
                            obj.ustr{i}  = 'pix'; obj.usca(i) = NaN;
                    end
                else
                    obj.ustr{i}  = ''; obj.usca(i) = 1/unitLength{i};
                end
            end
            % time
            unitTime = obj.opt.unitTime;
            if isempty(unitTime)
                unitTime = cell(size(obj.vid));
                for i = 1:numel(obj.vid)
                    logSize = log10(abs(diff(obj.vid(i).time([1 end]))));
                    if     logSize < -7, unitTime{i} = 'ns';
                    elseif logSize < -4, unitTime{i} = 'ys';
                    elseif logSize < -1, unitTime{i} = 'ms';
                    else,                unitTime{i} = 's';
                    end
                end
            end
            if ischar(unitTime) || (isnumeric(unitTime) && isscalar(unitTime))
                unitTime = repmat({unitTime},ni,nj);
            elseif isnumeric(unitTime) && isequal(size(unitTime),[ni nj])
                unitTime = num2cell(unitTime);
            elseif ~(iscell(unitTime) && isequal(size(unitTime),[ni nj]))
                error(sprintf('%s:Input',mfilename),'Input for unitTime is unexpected')
            end
            obj.tstr = cell(ni,nj);
            obj.tsca = NaN(ni,nj);
            for i = 1:numel(unitTime)
                if ischar(unitTime{i})
                    switch unitTime{i}
                        case 's'
                            obj.tstr{i}  =  's'; obj.tsca(i) = 1;
                        case 'ms'
                            obj.tstr{i}  = 'ms'; obj.tsca(i) = 1e3;
                        case 'ys'
                            obj.tstr{i}  = 'ys'; obj.tsca(i) = 1e6;
                        case 'ns'
                            obj.tstr{i}  = 'ns'; obj.tsca(i) = 1e9;
                    end
                else
                    obj.tstr{i}  = ''; obj.tsca(i) =1/unitTime{i};
                end
            end
            %
            % prepare process function(s) is done in init script
            obj.process = [];
            %
            % create figure
            oldFig = findall(groot,'tag',obj.tagMain);
            if ~isempty(oldFig)
                % use existing figure and remove its children to clean
                obj.main = oldFig(1);
                montage  = obj.opt.montage;
                reUseP   = true;
                if isempty(montage), montage = reshape(1:numel(obj.vid),size(obj.vid)); end
                if ~(reUse && numel(obj.vid) == numel(obj.ax) && isequal(size(montage),size(obj.panel)))
                    reUse = false;
                end
                if numel(oldFig) > 1, delete(oldFig(2:end)); end
                if ~reUse, delete(obj.panel); end
            else
                if ~isempty(fieldnames(obj.p_state)) && ~isempty(obj.p_state.main.Position)
                    posMain = obj.p_state.main.Position;
                    styMain = obj.p_state.main.WindowStyle;
                else
                    styMain     = 'normal';
                    aspectRatio = size(obj.vid,2)/size(obj.vid,1);
                    tmp         = groot;
                    bak         = tmp.Units;
                    tmp.Units   = 'pixels';
                    screensize  = tmp.ScreenSize;
                    tmp.Units   = bak;
                    pos1        = [25 50 (screensize(3)-50)              (screensize(3)-50)/aspectRatio];
                    pos2        = [25 50 (screensize(4)-100)*aspectRatio (screensize(4)-100)];
                    if all((pos1-screensize)>0), posMain = pos1; else, posMain = pos2; end
                end
                % create new figure
                obj.main  = figure('numbertitle', 'off', 'Visible','off',...
                    'name', 'Video Player - Main', ...
                    'menubar','none', ...
                    'toolbar','figure', ...
                    'resize', 'on', ...
                    'HandleVisibility','callback',...
                    'tag',obj.tagMain, ...
                    'DeleteFcn', @(src,dat) deleteMain(obj,src,dat),...
                    'WindowScrollWheelFcn', @(src,dat) callbackScroll(obj,src,dat),...
                    'WindowButtonDownFcn',  @(src,dat) callbackButtonDown(obj,src,dat),...
                    'WindowKeyPressFcn', @(src,dat) callbackKeyPress(obj,src,dat),...
                    'position',posMain);
                obj.mainPanel = uipanel('parent',obj.main,'Position',[0 0 1 1], 'Tag','PMain',...
                    'Units','Normalized','BorderType','none',...
                    'SizeChangedFcn', @(src,dat) sizeChangedMain(obj,src,dat));
                obj.main.WindowStyle = styMain;
                reUse                = false;
                reUseP               = false;
            end
            %
            % collect information on videos
            obj.helper = struct('imgSiz',{cell(ni,nj)},'imgClass',{cell(ni,nj)},'funcT',{cell(ni,nj)});
            for k = 1:numel(obj.vid)
                obj.helper.imgSiz{k}     = [obj.vid(k).nY obj.vid(k).nX obj.vid(k).nZ];
                obj.helper.imgClass{k}   = obj.vid(k).cdataClass;
            end
            %
            % create main and control panels
            if ~reUseP
                obj.ui          = struct;
                obj.ui.PControl = uipanel('parent',obj.mainPanel,'Position',[0 0 1 0.1],...
                    'Tag','PControl','Units','Normalized');
                % play button with text Start/Pause/Continue
                obj.ui.PBPlay = uicontrol(obj.ui.PControl,'Units','pixel','style','pushbutton','string','Play',...
                    'tag','PBPlay','callback', @(src,dat) play(obj),'UserData',[1 1],...
                    'ToolTipString','Play video(s) (MOD+p)');
                % exit button
                obj.ui.PBExit = uicontrol(obj.ui.PControl,'Units','pixel','style','pushbutton','string','Exit',...
                    'tag','PBExit','callback', @(src,dat) delete(obj.main),'UserData',[1 2],...
                    'ToolTipString','Exit video player (MOD+e)');
                % hide button with
                obj.ui.PBDel = uicontrol(obj.ui.PControl,'Units','pixel','style','pushbutton','string','Del',...
                    'tag','PBDel','callback', @(src,dat) delete(obj),'UserData',[1 3],...
                    'ToolTipString','Delete video player object (MOD+d)');
                % reset button
                obj.ui.PBReset = uicontrol(obj.ui.PControl,'Units','pixel','style','pushbutton','string','Reset',...
                    'tag','PBReset','callback', @(src,dat) p_reset(obj,false),'UserData',[1 4],...
                    'ToolTipString','Reset video player (MOD+r)');
                % reset view button
                obj.ui.PBResetView = uicontrol(obj.ui.PControl,'Units','pixel','style','pushbutton','string','View',...
                    'tag','PBResetView','callback', @(src,dat) callbackMain(obj,src,dat),'UserData',[1 5],...
                    'ToolTipString','Reset view of video player, e.g. zoom out and unlink axes (MOD+v)');
                % backup button
                obj.ui.PBBackup = uicontrol(obj.ui.PControl,'Units','pixel','style','pushbutton','string','Backup',...
                    'tag','PBBackup','callback', @(src,dat) callbackMain(obj,src,dat),'UserData',[2 1],...
                    'ToolTipString','Backup video object(s) to memory (MOD+b)');
                % undo button
                obj.ui.PBUndo = uicontrol(obj.ui.PControl,'Units','pixel','style','pushbutton','string','Undo',...
                    'tag','PBUndo','callback', @(src,dat) callbackMain(obj,src,dat),'UserData',[2 2],...
                    'ToolTipString','Undo video object(s) to last backup (MOD+u)');
                % store button
                obj.ui.PBStore = uicontrol(obj.ui.PControl,'Units','pixel','style','pushbutton','string','Save',...
                    'tag','PBStore','callback', @(src,dat) callbackMain(obj,src,dat),'UserData',[2 3],...
                    'ToolTipString','Save video object(s) to disk (MOD+s)');
                % load button
                obj.ui.PBRecall = uicontrol(obj.ui.PControl,'Units','pixel','style','pushbutton','string','Load',...
                    'tag','PBRecall','callback', @(src,dat) callbackMain(obj,src,dat),'UserData',[2 4],...
                    'ToolTipString','Load video object(s) from disk (MOD+l)');
                % reverse checkbox
                obj.ui.CReverse = uicontrol(obj.ui.PControl,'Units','pixel','style','checkbox','string','Rev.',...
                    'tag','CReverse','Value',false,'UserData',[2 5], 'ToolTipString','Play in reverse (r)');
                % loop checkbox
                obj.ui.CLoop = uicontrol(obj.ui.PControl,'Units','pixel','style','checkbox','string','Loop',...
                    'tag','CLoop','Value',false,'UserData',[2 6], 'ToolTipString','Loop playback (l)');
                % skip checkbox
                obj.ui.CSkip = uicontrol(obj.ui.PControl,'Units','pixel','style','checkbox','string','Skip',...
                    'tag','CSkip','Value',false,'UserData',[2 7], 'ToolTipString','Allow to skip frames for faster playback (s)');
                % track checkbox
                obj.ui.CTrack = uicontrol(obj.ui.PControl,'Units','pixel','style','checkbox','string','Track',...
                    'tag','CTrack','Value',false,'callback', @(src,dat) callbackMain(obj,src,dat),'UserData',[2 8],...
                    'ToolTipString','Enable tracking feature (data is stored in video object(s)) (t)');
                % info checkbox
                obj.ui.CInfo = uicontrol(obj.ui.PControl,'Units','pixel','style','checkbox','string','Info',...
                    'tag','CInfo','Value',false,'callback', @(src,dat) callbackMain(obj,src,dat),'UserData',[2 9],...
                    'ToolTipString','Enable adjust and info feature (i)');
                % process checkbox
                if isempty(obj.opt.process), mystate = 'off'; else, mystate = 'on'; end
                obj.ui.CProcess = uicontrol(obj.ui.PControl,'Units','pixel','style','checkbox','string','Proc.',...
                    'tag','CProcess','Value',false,'callback', @(src,dat) callbackMain(obj,src,dat),'UserData',[2 10],...
                    'ToolTipString','Enable process feature (p)','Enable',mystate);
                % delay slider
                obj.ui.SDelay = uicontrol(obj.ui.PControl,'Units','pixel','style','slider','string','Delay of playback in s',...
                    'tag','SDelay', 'Min',0,'Max',.5,'SliderStep',[0.05 0.100 ],'Value',0,'UserData',[2 11],...
                    'ToolTipString','Add delay to playback after each frame (0 to 500 ms)');
                % frame edit
                obj.ui.EFrame = uicontrol(obj.ui.PControl,'Units','pixel','style','edit','string','1',...
                    'tag','EFrame','callback', @(src,dat) callbackMain(obj,src,dat),'UserData',[1 6],...
                    'ToolTipString','Current frame number (f)');
                % frame slider
                if obj.nFrameMin == obj.nFrameMax
                    sstep = [0.1 1];
                else
                    sstep = [max(1.5e-6,1.01/(obj.nFrameMax-obj.nFrameMin+1)) min(1,10/(obj.nFrameMax-obj.nFrameMin+1))];
                end
                obj.ui.SFrame = uicontrol(obj.ui.PControl,'Units','pixel','style','slider','string','Current frame',...
                    'tag','SFrame','Min',obj.nFrameMin,'Max',obj.nFrameMax,...
                    'SliderStep',sstep,'Value',obj.nFrameMin,'callback',...
                    @(src,dat) callbackMain(obj,src,dat),'UserData',[1 7],...
                    'ToolTipString','Current frame number (arrow keys)');
                % allow for automatic resize and store original position
                fn = fieldnames(obj.ui);
                for i = 1:numel(fn)
                    obj.ui.(fn{i}).Units = 'normalized';
                end
            end
            if isempty(obj.opt.process), obj.ui.CProcess.Enable = 'off';
            else,                        obj.ui.CProcess.Enable = 'on';
            end
            obj.ui.SFrame.Min        = obj.nFrameMin;
            obj.ui.SFrame.Max        = obj.nFrameMax;
            if obj.nFrameMin == obj.nFrameMax
                sstep = [0.1 1];
            else
                sstep = [max(1.5e-6,1.01/(obj.nFrameMax-obj.nFrameMin+1)) min(1,10/(obj.nFrameMax-obj.nFrameMin+1))];
            end
            obj.ui.SFrame.SliderStep = sstep;
            obj.ui.SFrame.Value      = obj.nFrameMin;
            %
            % create panels, axes and image objects
            if ~reUse
                obj.ax     = gobjects(ni,nj);
                obj.axMenu = gobjects(ni,nj);
                obj.panel  = gobjects(ni,nj);
                obj.img    = gobjects(ni,nj);
                obj.textX  = gobjects(ni,nj);
                obj.textY  = gobjects(ni,nj);
                obj.textT  = gobjects(ni,nj);
                obj.iRange = gobjects(ni,nj);
                obj.iPixel = gobjects(ni,nj);
                % axis are created on uipanel container objects. This allows more control over the
                % layout of the GUI.
                k = 1;
                for j = 1:nj
                    for i = 1:ni
                        if ~reUse
                            obj.axMenu(k) = createMainMenu(obj,k);
                            obj.panel(k)  = uipanel('parent',obj.mainPanel,'Position',[(j-1)/nj 1-i/ni 1/nj 1/ni],...
                                'Units','Normalized','uicontextmenu',obj.axMenu(k),'Title',sprintf('Video %d',k));
                            obj.ax(k)     = axes('OuterPosition',[0 0 1 1],'Parent',obj.panel(k),'Layer',obj.opt.layer,...
                                'uicontextmenu',obj.axMenu(k));
                            obj.img(k)    = image(...
                                'XData',[1 2],...
                                'YData',[1 2],...
                                'CData',zeros(2,2,numel(obj.idxChannels{k}),obj.vid(k).cdataClass),...
                                'CDataMapping','scaled',...
                                'BusyAction', 'cancel', ...
                                'Parent', obj.ax(k), ...
                                'UIContextMenu',obj.axMenu(k),...
                                'Interruptible', 'off');
                            obj.textX(k)  = xlabel(obj.ax(k),'');
                            obj.textY(k)  = ylabel(obj.ax(k),'');
                            obj.textT(k)  = title(obj.ax(k),'','Interpreter','none');
                            axis(obj.ax(k),'image');
                        end
                        obj.ax(k).UserData.idxAx = k;
                        k                        = k + 1;
                    end
                end
            end
            %
            % initialize figure with actual data
            if obj.p_frame < obj.nFrameMin || obj.p_frame > obj.nFrameMax
                obj.p_frame = obj.nFrameMin;
            end
            for i = 1:numel(obj.ax)
                if isnan(obj.usca(i))
                    limXData = [1 obj.vid(i).nX];
                    limYData = [1 obj.vid(i).nY];
                else
                    limXData = obj.vid(i).x([1 end])*obj.usca(i);
                    limYData = obj.vid(i).y([1 end])*obj.usca(i);
                end
                set(obj.img(i), 'XData',limXData, 'YData',limYData, ...
                    'CData',obj.vid(i).cdata(1:obj.opt.stepImage:obj.helper.imgSiz{i}(1),...
                    1:obj.opt.stepImage:obj.helper.imgSiz{i}(2),...
                    obj.idxChannels{i},obj.frameVideo(i)));
                if ~reUse
                    if ~isempty(obj.vid(i).map)
                        colormap(obj.ax(i),obj.vid(i).map);
                    else
                        switch obj.vid(i).cdataClass
                            case 'uint8'
                                colormap(obj.ax(i),repmat(reshape(linspace(0,1,256),[],1),1,3));
                            otherwise
                                colormap(obj.ax(i),repmat(reshape(linspace(0,1,65536),[],1),1,3));
                        end
                    end
                end
                if isempty(obj.ustr{i})
                    set(obj.textX(i), 'String', obj.vid(i).xStr);
                    set(obj.textY(i), 'String', obj.vid(i).yStr);
                else
                    set(obj.textX(i), 'String', sprintf('%s (%s)',obj.vid(i).xStr,obj.ustr{i}));
                    set(obj.textY(i), 'String', sprintf('%s (%s)',obj.vid(i).yStr,obj.ustr{i}));
                end
                if size(obj.vid(i).time,2) == obj.vid(i).nFrames
                    obj.helper.funcT{i} = @(f,t) sprintf('frame %4d, t = %s %s',f,num2str(reshape(t(:,f),1,[])*obj.tsca(i),'%.2e '),obj.tstr{i});
                else
                    obj.helper.funcT{i} = @(f,t) sprintf('frame %4d',f);
                end
                set(obj.textT(i), 'String', ...
                    {sprintf('Video %d: %s',i,obj.vid(i).name);...
                    sprintf('%d x %d x %d x %d (%s, transform = %d), CH %s, %.2f MiB (memmap = %d)', ...
                    obj.helper.imgSiz{i}(2),obj.helper.imgSiz{i}(1),obj.helper.imgSiz{i}(3),obj.vid(i).nFrames,...
                    obj.helper.imgClass{i},~isempty(obj.vid(i).transform),num2str(obj.idxChannels{i}),obj.vid(i).memoryDisk,obj.vid(i).memmap);...
                    obj.helper.funcT{i}(obj.frameVideo(i),obj.vid(i).time)},...
                    'Interpreter','none');
                if strcmp(obj.ustr{i}, 'pix')
                    set(obj.ax(i),'XDir','normal');
                    set(obj.ax(i),'YDir','reverse');
                else
                    if obj.vid(i).xDir > 0, set(obj.ax(i),'XDir','normal');
                    else,                   set(obj.ax(i),'XDir','reverse');
                    end
                    if obj.vid(i).yDir > 0, set(obj.ax(i),'YDir','reverse');
                    else,                   set(obj.ax(i),'YDir','normal');
                    end
                end
            end
            % link axes
            if obj.opt.linkAxes, Videoplayer.linkAllAxes(obj.main,obj.ax); end
            %
            % restore state and show
            obj.state        = [];
            obj.frame        = obj.p_frame;
            obj.main.Visible = 'on';
            drawnow;
            sizeChangedMain(obj,obj.mainPanel);
        end
        
        function         updateMain(obj,doProcess,idx)
            %updateMain Shows frame(s) in video player
            
            if nargin < 2 || isempty(doProcess), doProcess = obj.isProcess && ~isempty(obj.process); end
            if nargin < 3 || isempty(idx), idx = 1:numel(obj.vid); else, idx = reshape(idx,[],1); end
            % update each axis
            for i = idx
                if isgraphics(obj.img(i))
                    if doProcess && ~isempty(obj.process.func{i})
                        processRun(obj,i);
                        set(obj.img(i),'cdata',obj.process.data{i}(1:obj.opt.stepImage:obj.helper.imgSiz{i}(1),...
                            1:obj.opt.stepImage:obj.helper.imgSiz{i}(2),...
                            obj.idxChannels{i}));
                    else
                        set(obj.img(i),'cdata',obj.vid(i).cdata(1:obj.opt.stepImage:obj.helper.imgSiz{i}(1),...
                            1:obj.opt.stepImage:obj.helper.imgSiz{i}(2),...
                            obj.idxChannels{i},obj.frameVideo(i)));
                    end
                end
                if isgraphics(obj.textT(i)) && numel(obj.textT(i).String) > 2
                    obj.textT(i).String{3} = obj.helper.funcT{i}(obj.frameVideo(i),obj.vid(i).time);
                end
            end
            % update ROIs
            if obj.isTrack,  trackUpdate(obj,idx); end
            if obj.isInfo,   updateCompare(obj); end
            if obj.isExport, updateExport(obj);end
        end
        
        function         deleteMain(obj,hObject,hData) %#ok<INUSD>
            %deleteMain Deletes main, profile, compare, hist and export figure
            
            if obj.isGUI
                % store state of player
                obj.state;
                % make sure any secondary figure is deleted and delete the figure window
                if obj.isProfile, deleteProfile(obj); end
                if obj.isCompare, deleteCompare(obj,true); end
                if obj.isHist,    deleteHist(obj,true); end
                if obj.isExport,  deleteExport(obj,true); end
                % disable Info and track (disables tracks)
                obj.isInfo  = false;
                obj.isTrack = false;
                delete(gcbo);
                % clean up
                obj.main        = [];
                obj.mainPanel   = [];
                obj.sub_profile = [];
                obj.sub_compare = [];
                obj.sub_hist    = [];
                obj.sub_export  = [];
                obj.ui          = struct;
                obj.helper      = struct;
                obj.panel       = [];
                obj.ax          = [];
                obj.img         = [];
                obj.axMenu      = [];
                obj.textX       = [];
                obj.textY       = [];
                obj.textT       = [];
                obj.iRange      = [];
                obj.iPixel      = [];
                obj.idxFrames   = [];
                obj.idxChannels = [];
                obj.nFrameMax   = [];
                obj.nFrameMin   = [];
                obj.ustr        = [];
                obj.usca        = [];
                obj.tstr        = [];
                obj.tsca        = [];
                obj.process     = [];
                obj.p_frameVideo= [];
            end
        end
        
        function         sizeChangedMain(obj,fig,data) %#ok<INUSD>
            %sizeChangedMain Adjusts GUI in case of a size change
            
            %
            % settings for size in pixels
            pbW  = 50;
            pbH  = 25;
            spW  = 10;
            spH  = 10;
            %
            % get size of panel/figure in pixel
            bak       = fig.Units;
            fig.Units = 'pixel';
            pos       = fig.Position;
            fig.Units = bak;
            %
            % resize GUI
            maxW = max(obj.ui.SDelay.UserData(2),obj.ui.SFrame.UserData(2));
            maxH = max(obj.ui.SDelay.UserData(1),obj.ui.SFrame.UserData(1));
            % reduce button size and spacing if window gets to small
            if maxW*pbW+(maxW+1)*spW > pos(3)
                ratio = spW/pbW;
                pbW   = max(1,pos(3)/((maxW*(1+ratio)+ ratio)));
                spW   = max(1,ratio * pbW);
            end
            if maxH*pbH+(maxH+1)*spH > pos(4)-100 % reserve 100 pix for the video
                ratio = spH/pbH;
                pbH   = max(1,(pos(4)-100)/((maxH*(1+ratio)+ ratio)));
                spH   = max(1,ratio * pbH);
            end
            useH = (pos(4)-(maxH*pbH+(maxH+1)*spH))/pos(4); % relative size of control panel, 80 pixel normally
            fn   = fieldnames(obj.ui);            % control panel and uicontrols
            % distribute panels but keep control panel constant in height
            [ni, nj] = size(obj.ax);
            obj.ui.PControl.Position = [0 0 1 1-useH];
            for j = 1:nj
                for i = 1:ni
                    obj.panel(i,j).Position =[(j-1)/nj 1-i*useH/ni 1/nj useH/ni];
                end
            end
            % set uicontrols in control panel, make sliders to fill panel
            for i = 1:numel(fn)
                obj.ui.(fn{i}).Units = 'pixels';
                mypos = obj.ui.(fn{i}).UserData;
                switch fn{i}
                    case 'PControl'
                    case {'SDelay' 'SFrame'}
                        tmp    = [mypos(2)*spW+(mypos(2)-1)*pbW mypos(1)*spH+(mypos(1)-1)*pbH pbW pbH];
                        tmp(3) = pos(3)-spW-tmp(1);
                        tmp(2) = tmp(2)-5;
                        obj.ui.(fn{i}).Position = tmp;
                    otherwise
                        obj.ui.(fn{i}).Position = [mypos(2)*spW+(mypos(2)-1)*pbW mypos(1)*spH+(mypos(1)-1)*pbH pbW pbH];
                end
                obj.ui.(fn{i}).Units = 'normalized';
            end
        end
        
        function         callbackMain(obj,hObject,hData) %#ok<INUSD>
            %callbackMain Runs callbacks for some uicontrols in main figure or run code snippet by
            % name, i.e there is no need to create a uicontrol for each code part
            
            if ischar(hObject)
                strTag = hObject;
                if isfield(obj.ui,strTag), hObject = obj.ui.(strTag);
                else,                      hObject = [];
                end
            else
                strTag = hObject.Tag;
            end
            switch strTag
                case 'CInfo'
                    obj.isInfo = hObject.Value;
                case 'CTrack'
                    obj.isTrack = hObject.Value;
                case 'CProcess'
                    obj.isProcess = hObject.Value;
                case 'PBResetView'
                    callbackMainMenu(obj,[],'resetZoom');
                    callbackMainMenu(obj,[],'unlink');
                    callbackMainMenu(obj,[],'autodr');
                    callbackMainMenu(obj,[],'grid',[],'on');
                    for i = 1:numel(obj.vid)
                        if ~isempty(obj.vid(i).map)
                            colormap(obj.ax(i),obj.vid(i).map);
                        else
                            switch obj.vid(i).cdataClass
                                case 'uint8'
                                    colormap(obj.ax(i),repmat(reshape(linspace(0,1,256),[],1),1,3));
                                otherwise
                                    colormap(obj.ax(i),repmat(reshape(linspace(0,1,65536),[],1),1,3));
                            end
                        end
                    end
                case 'PBBackup'
                    backup(obj.vid);
                case 'PBUndo'
                    button = questdlg(...
                        'This will revert all videos to the last backup. Continue?', ...
                        'Video player - Backup', 'Yes','No','No');
                    if ~strcmp(button,'Yes'); return; end
                    % disable listeners to prevent multiple execution of reset function
                    clean(obj);
                    fn = fieldnames(obj.listener);
                    for i = 1:numel(fn)
                        obj.listener.(fn{i}).Enabled = false;
                    end
                    restore(obj.vid);
                    p_reset(obj,true);
                    fn = fieldnames(obj.listener);
                    for i = 1:numel(fn)
                        obj.listener.(fn{i}).Enabled = true;
                    end
                case 'PBStore'
                    button = questdlg(...
                        'This will store all videos to disk. Continue?', ...
                        'Video player - Store', 'Yes','No','No');
                    if ~strcmp(button,'Yes'); return; end
                    store(obj.vid);
                case 'PBRecall'
                    button = questdlg(...
                        'This will load all videos from disk. Continue?', ...
                        'Video player - Store', 'Yes','No','No');
                    if ~strcmp(button,'Yes'); return; end
                    % disable listeners to prevent multiple execution of reset function
                    clean(obj);
                    fn = fieldnames(obj.listener);
                    for i = 1:numel(fn)
                        obj.listener.(fn{i}).Enabled = false;
                    end
                    recall(obj.vid);
                    p_reset(obj,true);
                    fn = fieldnames(obj.listener);
                    for i = 1:numel(fn)
                        obj.listener.(fn{i}).Enabled = true;
                    end
                case 'SFrame'
                    if hObject.Value < hObject.Min
                        hObject.Value = hObject.Min;
                    elseif hObject.Value > hObject.Max
                        hObject.Value = hObject.Max;
                    end
                    obj.frame = hObject.Value;
                case 'EFrame'
                    value = str2double(hObject.String);
                    if ~isnan(value) && isnumeric(value) && isscalar(value)
                        value = round(value);
                        if value >= obj.nFrameMin && value <= obj.nFrameMax
                            obj.frame = value;
                        else
                            obj.ui.EFrame.String = sprintf('%d',obj.p_frame);
                        end
                    else
                        obj.ui.EFrame.String = sprintf('%d',obj.p_frame);
                    end
            end
        end
        
        function         callbackMainMenu(obj,idxAx,type,src,dat)
            %callbackMainMenu Handles callbacks from context menu
            
            if isempty(idxAx), idxAx = 1:numel(obj.vid);end
            switch type
                case {'imellipse', 'imrect', 'imline', 'imdistline', 'impoly', 'impoint'}
                    trackAdd(obj,idxAx,type);
                case 'imcontrast'
                    if strcmp(dat,'all')
                        tmpLink = linkprop(obj.ax,'CLim');
                    end
                    hFig = imcontrast(obj.img(idxAx));
                    if strcmp(dat,'all')
                        hFig.UserData.link = tmpLink;
                    end
                case 'improfile'
                    improfile
                    fig = gcf;
                    if ~isempty(fig) && isgraphics(fig,'figure')
                        set(fig, 'Name', 'Video Player - Profile','numbertitle', 'off');
                    end
                case 'imtool'
                    imtool(obj.img(idxAx).CData);
                case 'imsave'
                    imsave(obj.img(idxAx));
                case 'export_fig'
                    [filename, ext, user_canceled] = imputfile;
                    if ~user_canceled
                        export_fig(filename,['-' ext],obj.panel(idxAx));
                    end
                case 'imhist'
                    createHist(obj,true,idxAx);
                case 'resetZoom'
                    set(obj.ax(idxAx),'XLimMode','auto','YLimMode','auto');
                case 'resetMag'
                    Video.imgSetPixelMagnification(obj.img(idxAx));
                case 'colormap'
                    % add listener that runs if imcolormaptool changes the colormap of the main
                    % figure, which is than applied to the current axes
                    try
                        colormap(obj.main,colormap(obj.ax(idxAx(1))));
                        h = imcolormaptool(obj.main);
                        for i = 1:numel(idxAx)
                            lh(i) = addlistener(obj.main , 'Colormap' , 'PostSet' , ...
                                @(h,e) colormap(obj.ax(idxAx(i)),obj.main.Colormap)); %#ok<AGROW>
                        end
                        uiwait(h);
                        delete(lh);
                    catch err
                        if exist('lh','var') == 1, delete(lh);end
                        rethrow(err);
                    end
                case 'autodr'
                    for i = reshape(idxAx,1,[])
                        obj.ax(i).CLimMode = 'auto';
                    end
                case 'maxdr'
                    for i = reshape(idxAx,1,[])
                        [mmin, mmax]   = Video.imgGetBlackWhiteValue(obj.img(i).CData);
                        obj.ax(i).CLim = sort([mmin mmax]);
                    end
                case 'grid'
                    for i = reshape(idxAx,1,[])
                        obj.ax(i).XGrid = dat;
                        obj.ax(i).YGrid = dat;
                    end
                case 'getMask'
                    mask = Video.guiGetMask(obj.img(idxAx).CData);
                    export2wsdlg({'Export mask to variable named:'},{'mask'},{mask},...
                        'Export binary mask to base workspace');
                case 'getPixres'
                    pixres = Video.guiGetPixres(obj.img(idxAx).CData);
                    if ~isnan(pixres)
                        export2wsdlg({'Export pixel resolution to variable named:'},{'pixres'},{pixres},...
                            'Export pixel resolution to base workspace');
                    end
                case 'getPixresLines'
                    pixres = Video.guiGetPixresLines(obj.img(idxAx).CData);
                    if ~isnan(pixres)
                        export2wsdlg({'Export pixel resolution to variable named:'},{'pixres'},{pixres},...
                            'Export pixel resolution to base workspace');
                    end
                case 'getPixresGrid'
                    pixres = Video.guiGetPixresSquare(obj.img(idxAx).CData,'type','squares');
                    if ~isnan(pixres)
                        export2wsdlg({'Export pixel resolution to variable named:'},{'pixres'},{pixres},...
                            'Export pixel resolution to base workspace');
                    end
                case 'getPixresDot'
                    pixres = Video.guiGetPixresSquare(obj.img(idxAx).CData,'type','dots');
                    if ~isnan(pixres)
                        export2wsdlg({'Export pixel resolution to variable named:'},{'pixres'},{pixres},...
                            'Export pixel resolution to base workspace');
                    end
                case 'exportObj'
                    export2wsdlg({'Export video player to variable named:'},{'player'},{obj},...
                        'Export video player object to base workspace');
                case 'profile'
                    if any([obj.vid(idxAx).lock])
                        hObject.Value = false;
                        warning(sprintf('%s:Input',mfilename),...
                            ['At least one video is locked, but profiles require track feature ',...
                            'which is not allowed for locked videos']);
                        return;
                    end
                    createProfile(obj,true,idxAx);
                case 'compare'
                    createCompare(obj,true,idxAx,dat);
                case 'export'
                    createExport(obj,true,idxAx);
                case 'exportBackup'
                    backup2DiskGUI(obj.vid(idxAx));
                case 'importBackup'
                    restore2DiskGUI(obj.vid(idxAx));
                case 'reset roi'
                    trackReset(obj,reshape(idxAx,1,[]));
                case 'Clear'
                    trackHide(obj,idxAx);
                    for i = reshape(idxAx,1,[])
                        obj.vid(i).p_track = struct('imroi',{},'position',{},'color',{},'name',{});
                    end
                case {'initial','nearest','linear'}
                    obj.opt.trackMode = lower(src.Label);
                    for i = 1:numel(obj.axMenu)
                        idx1 = strcmp({obj.axMenu(i).Children.Label},'Track');
                        idx2 = strcmp({obj.axMenu(i).Children(idx1).Children.Label},'Mode');
                        for j = 1:numel(obj.axMenu(i).Children(idx1).Children(idx2).Children)
                            if strcmpi(obj.axMenu(i).Children(idx1).Children(idx2).Children(j).Label,...
                                    obj.opt.trackMode)
                                obj.axMenu(i).Children(idx1).Children(idx2).Children(j).Checked = 'on';
                            else
                                obj.axMenu(i).Children(idx1).Children(idx2).Children(j).Checked = 'off';
                            end
                        end
                    end
                case 'changeChannel'
                    % set new value
                    obj.idxChannels{idxAx} = str2num(dat); %#ok<ST2NM>
                    % change menu
                    idx1 = strcmp({obj.axMenu(idxAx).Children.Label},'Channel');
                    for j = 1:numel(obj.axMenu(idxAx).Children(idx1).Children)
                        if strcmpi(obj.axMenu(idxAx).Children(idx1).Children(j).Label,dat)
                            obj.axMenu(idxAx).Children(idx1).Children(j).Checked = 'on';
                        else
                            obj.axMenu(idxAx).Children(idx1).Children(j).Checked = 'off';
                        end
                    end
                    % change title
                    if isgraphics(obj.textT(idxAx)) && numel(obj.textT(idxAx).String) > 1
                        obj.textT(idxAx).String{2} = sprintf('%d x %d x %d x %d (%s, transform = %d), CH %s, %.2f MiB (memmap = %d)', ...
                            obj.helper.imgSiz{idxAx}(2),obj.helper.imgSiz{idxAx}(1),obj.helper.imgSiz{idxAx}(3),obj.vid(idxAx).nFrames,...
                            obj.helper.imgClass{idxAx},~isempty(obj.vid(idxAx).transform),num2str(obj.idxChannels{idxAx}),obj.vid(idxAx).memoryDisk,obj.vid(idxAx).memmap);
                    end
                    % recreate
                    if obj.isProfile, cleanProfile(obj); createProfile(obj,false); end
                    if obj.isCompare, cleanCompare(obj); createCompare(obj,false,idxAx); end
                    if obj.isHist,    cleanHist(obj);    createHist(obj,false,idxAx); end
                    % update view
                    if ~obj.isPlay, update(obj); end
                case 'linkForce'
                    linkaxes(obj.ax,'xy');
                case 'link'
                    Videoplayer.linkAllAxes(obj.main,obj.ax);
                    obj.opt.linkAxes = true;
                case 'unlink'
                    Videoplayer.unlinkAllAxes(obj.main);
                    obj.opt.linkAxes = false;
                case obj.resolution(:,1)
                    [width, height] = strtok(type,'x'); height = height(2:end);
                    width = str2double(width); height = str2double(height);
                    obj.ui.PControl.Units = 'pixels';
                    pos    = obj.main.Position;
                    pos(3) = width; pos(4) = height+obj.ui.PControl.Position(4);
                    obj.ui.PControl.Units = 'normalized';
                    obj.main.Position = pos;
                case {'FontSizeAll' 'FontSizeSingle'}
                    % set font size
                    tmp = struct('FontSize',dat);
                    if strcmp(type,'FontSizeAll'), Videoplayer.changeFont(obj.main,tmp);
                    else,                          Videoplayer.changeFont(obj.panel(idxAx),tmp);
                    end
                    obj.opt.fontSize = dat;
                case {'FontToolAll' 'FontToolSingle'}
                    if strcmp(type,'FontToolAll')
                        h1 = findall(obj.main,'type','axes');
                        h2 = findall(obj.main,'type','text');
                    else
                        h1 = findall(obj.panel(idxAx),'type','axes');
                        h2 = findall(obj.panel(idxAx),'type','text');
                    end
                    if ~isempty(h1)
                        s = uisetfont(h1(1));
                    elseif ~isempty(h2)
                        s = uisetfont(h2(1));
                    else
                        return;
                    end
                    if isstruct(s)
                        fn = fieldnames(s);
                        for i = 1:numel(fn)
                            set(h1,fn{i},s.(fn{i}));
                            set(h2,fn{i},s.(fn{i}));
                        end
                        obj.opt.fontName   = s.FontName;
                        obj.opt.fontSize   = s.FontSize;
                        obj.opt.fontWeight = s.FontWeight;
                        obj.opt.fontAngle  = s.FontAngle;
                    end
                case {'unitLength-ym' 'unitLength-mm' 'unitLength-m' 'unitLength-pix' 'unitLength-user'}
                    if strcmp(type,'unitLength-user')
                        prompt     = {'Enter a value to scale the length'};
                        name       = 'Normalization of length';
                        if dat, defaultans = {num2str(1/mean(obj.usca(:)))};
                        else,   defaultans = {num2str(1/obj.usca(idxAx))};
                        end
                        doAgain    = true;
                        while doAgain
                            answer = inputdlg(prompt,name,[1 40],defaultans);
                            if isempty(answer), return;end
                            str    = str2double(answer{1});
                            if ~isnan(str), doAgain = false; end
                        end
                    else
                        [~,str] = strtok(type,'-');str = str(2:end);
                    end
                    redoTrack = false;
                    if obj.isTrack, redoTrack = true; trackHide(obj); end
                    if dat
                        % set all videos to the same setting
                        obj.opt.unitLength = str;
                    else
                        % set only one video
                        obj.opt.unitLength = obj.ustr;
                        for i = 1:numel(obj.opt.unitLength)
                            if isempty(obj.opt.unitLength{i})
                                obj.opt.unitLength{i} = 1/obj.usca(i);
                            end
                        end
                        obj.opt.unitLength{idxAx} = str;
                    end
                    p_reset(obj,true);
                    obj.isTrack = redoTrack;
                case {'unitTime-ns' 'unitTime-ys' 'unitTime-ms' 'unitTime-s' 'unitTime-user'}
                    if strcmp(type,'unitTime-user')
                        prompt     = {'Enter a value to scale the time'};
                        name       = 'Normalization of time';
                        if dat, defaultans = {num2str(1/mean(obj.tsca(:)))};
                        else,   defaultans = {num2str(1/obj.tsca(idxAx))};
                        end
                        doAgain    = true;
                        while doAgain
                            answer = inputdlg(prompt,name,[1 40],defaultans);
                            if isempty(answer), return;end
                            str    = str2double(answer{1});
                            if ~isnan(str), doAgain = false; end
                        end
                    else
                        [~,str] = strtok(type,'-');str = str(2:end);
                    end
                    if dat
                        % set all videos to the same setting
                        obj.opt.unitTime = str;
                    else
                        % set only one video
                        obj.opt.unitTime = obj.tstr;
                        for i = 1:numel(obj.opt.unitTime)
                            if isempty(obj.opt.unitTime{i})
                                obj.opt.unitTime{i} = 1/obj.tsca(i);
                            end
                        end
                        obj.opt.unitTime{idxAx} = str;
                    end
                    p_reset(obj,true);
            end
        end
        
        function         callbackExportMenu(obj,type,src,dat) %#ok<INUSL>
            %callbackExportMenu Handles callbacks from export context menu
            
            switch type
                case 'linkForce'
                    myax = findall(obj.sub_export,'type','axes');
                    linkaxes(myax,'xy');
                case 'link'
                    Videoplayer.linkAllAxes(obj.sub_export);
                case 'unlink'
                    Videoplayer.unlinkAllAxes(obj.sub_export);
                case obj.resolution(:,1)
                    [width, height] = strtok(type,'x'); height = height(2:end);
                    width = str2double(width); height = str2double(height);
                    pos    = obj.sub_export.Position;
                    pos(3) = width; pos(4) = height;
                    obj.sub_export.Position = pos;
                case 'main'
                    obj.sub_export.Position = obj.main.Position + [0 80 0 -80];
                case 'FontSize'
                    % set font size
                    tmp = struct('FontSize',dat);
                    Videoplayer.changeFont(obj.sub_export,tmp);
                case 'LineWidth'
                    h = findall(obj.sub_export,'type','line');
                    set(h,'Linewidth',dat);
                case 'LineColor'
                    myc = get(groot,'DefaultAxesColorOrder');
                    h   = findall(obj.sub_export,'type','line');
                    if numel(h) > size(myc,1)
                        myc = parula(numel(h));
                    end
                    for i = 1:numel(h)
                        set(h(i),'Color',myc(i,:));
                    end
                case 'FontTool'
                    h1 = findall(obj.sub_export,'type','axes');
                    h2 = findall(obj.sub_export,'type','text');
                    if ~isempty(h1),     s = uisetfont(h1(1));
                    elseif ~isempty(h2), s = uisetfont(h2(1));
                    else,                return;
                    end
                    if isstruct(s)
                        fn = fieldnames(s);
                        for i = 1:numel(fn)
                            set(h1,fn{i},s.(fn{i}));
                            set(h2,fn{i},s.(fn{i}));
                        end
                    end
                case 'resetZoom'
                    h1 = findall(obj.sub_export,'type','axes');
                    set(h1,'XLimMode','auto','YLimMode','auto');
                case 'resetMag'
                    h = findmyaxes(obj.sub_export);
                    for i = 1:numel(h)
                        hImg = findall(h(i),'type','image');
                        if numel(hImg) > 0
                            Video.imgSetPixelMagnification(hImg(1));
                        end
                    end
                case 'colormap'
                    h = imcolormaptool(obj.sub_export);
                    uiwait(h);
                case 'cleanFigure'
                    [h, idx] = findmyaxes(obj.sub_export);
                    if isempty(h), return; end
                    if strcmp(dat,'on')
                        for i = 1:numel(h)
                            h(i).Title.String  = '';
                            h(i).XLabel.String = '';
                            h(i).YLabel.String = '';
                            h(i).XTickLabel    = [];
                            h(i).YTickLabel    = [];
                        end
                    else
                        for i = 1:numel(h)
                            h(i).Title.String   = obj.ax(idx(i)).Title.String;
                            h(i).XLabel.String  = obj.ax(idx(i)).XLabel.String;
                            h(i).YLabel.String  = obj.ax(idx(i)).YLabel.String;
                            h(i).XTickLabelMode = 'auto';
                            h(i).YTickLabelMode = 'auto';
                        end
                    end
                case 'grid'
                    h = findmyaxes(obj.sub_export);
                    if isempty(h), return; end
                    for i = 1:numel(h)
                        h(i).XGrid = dat;
                        h(i).YGrid = dat;
                    end
                case 'autodr'
                    h = findmyaxes(obj.sub_export);
                    for i = 1:numel(h)
                        h(i).CLimMode = 'auto';
                    end
                case 'maxdr'
                    h = findmyaxes(obj.sub_export);
                    for i = 1:numel(h)
                        hImg = findall(h(i),'type','image');
                        if numel(hImg) > 0
                            [mmin, mmax] = Video.imgGetBlackWhiteValue(hImg(1).CData);
                            h(i).CLim    = sort([mmin mmax]);
                        end
                    end
                case 'changeContrast'
                    h1 = findmyaxes(obj.sub_export);
                    if isempty(h1), return; end
                    if numel(h1) > 1
                        % add listener that runs if imcontrast changes the clim of the first axes,
                        % which is than applied to all remaining axes
                        try
                            h = imcontrast(h1(1));
                            for i = 2:numel(h1)
                                lh(i-1) = addlistener(h1(1), 'CLim' , 'PostSet' , ...
                                    @(h,e) set(h1(i),'CLim',h1(1).CLim)); %#ok<AGROW>
                            end
                            uiwait(h);
                            delete(lh);
                        catch err
                            if exist('lh','var') == 1, delete(lh);end
                            rethrow(err);
                        end
                    else
                        h = imcontrast(h1(1));
                        uiwait(h);
                    end
                case 'FirstFrame'
                    stop(obj);
                    obj.frame = obj.nFrameMin;
                case 'MidFrame'
                    stop(obj);
                    obj.frame = round((obj.nFrameMax+obj.nFrameMin)/2);
                case 'LastFrame'
                    stop(obj);
                    obj.frame = obj.nFrameMax;
                case 'RemoveTracks'
                    createExportTracks(obj,false);
                case 'AddTracks'
                    createExportTracks(obj,true);
                case {'AlphaOFF' 'AlphaON'}
                    obj.opt.alphaCut = dat;
                    updateExport(obj);
            end
            
            function [myax, idxAx] = findmyaxes(fig)
                myax  = findall(fig,'type','axes');
                idxAx = [];
                idxOK = false(size(myax));
                for l = 1:numel(myax)
                    if isstruct(myax(l).UserData) && isfield(myax(l).UserData,'idxAx')
                        idxAx    = [idxAx,myax(l).UserData.idxAx]; %#ok<AGROW>
                        idxOK(l) = true;
                    end
                end
                myax = myax(idxOK);
            end
        end
        
        function         callbackScroll(obj,src,dat)
            %callbackScroll Uses scroll wheel input to play videos
            
            % only accept scroll when it is over the main panel (in case the figure is the main
            % figure)
            if ~isempty(src.Tag) && strcmp(src.Tag,obj.tagMain)
                posMO = src.CurrentPoint./src.Position(3:4);
                posPM = obj.mainPanel.Position;
                if posMO(1) < posPM(1) || posMO(1) > sum(posPM([1 3])) || ...
                        posMO(2) < posPM(2) || posMO(2) > sum(posPM([2 4]))
                    return;
                end
            end
            step = sign(obj.opt.scrollDirection) * round(dat.VerticalScrollCount/dat.VerticalScrollAmount);
            next = obj.p_frame + step;
            if obj.isLoop
                if next > obj.nFrameMax
                    next = obj.nFrameMin + mod(next-obj.nFrameMax,obj.nFrameMax - obj.nFrameMin + 1) - 1;
                elseif next < obj.nFrameMin
                    next = obj.nFrameMax - mod(obj.nFrameMin-next,obj.nFrameMax - obj.nFrameMin + 1) + 1;
                end
            else
                if next > obj.nFrameMax
                    next = obj.nFrameMax;
                elseif next < obj.nFrameMin
                    next = obj.nFrameMin;
                end
            end
            obj.frame = min(obj.nFrameMax,max(obj.nFrameMin,next));
        end
        
        function         callbackButtonDown(obj,hObject,hData) %#ok<INUSD>
            %callbackButtonDown Play and stop video on click
            
            % only accept click when it is over the main panel
            posMO = hObject.CurrentPoint./hObject.Position(3:4);
            posPM = obj.mainPanel.Position;
            if posMO(1) < posPM(1) || posMO(1) > sum(posPM([1 3])) || ...
                    posMO(2) < posPM(2) || posMO(2) > sum(posPM([2 4]))
                return;
            end
            switch hObject.SelectionType
                case 'normal'
                    if obj.isPlay
                        stop(obj);
                    elseif ~obj.isTrack
                        play(obj);
                    end
                case 'open'
                    stop(obj);
                    callbackMain(obj,'PBResetView');
            end
        end
        
        function         callbackKeyPress(obj,hObject,hData) %#ok<INUSL>
            %callbackKeyPress Handles keys pressed in video player
            
            switch hData.Key
                case 'b'
                    if numel(hData.Modifier) < 1
                        %nothing
                    elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                        callbackMain(obj,'PBBackup');
                    end
                case 'd'
                    if numel(hData.Modifier) < 1
                        % nothing
                    elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                        delete(obj);
                    end
                case 'e'
                    if numel(hData.Modifier) < 1
                        % nothing
                    elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                        delete(obj.main)
                    end
                case 'f'
                    if numel(hData.Modifier) < 1
                        uicontrol(obj.ui.EFrame);
                    elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                        % nothing
                    end
                case 'i'
                    if numel(hData.Modifier) < 1
                        obj.isInfo = ~obj.isInfo;
                    elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                        % nothing
                    end
                case 'p'
                    if numel(hData.Modifier) < 1
                        obj.isProcess = ~obj.isProcess;
                    elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                        play(obj);
                    end
                case 'l'
                    if numel(hData.Modifier) < 1
                        obj.isLoop = ~obj.isLoop;
                    elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                        % nothing
                    end
                case 'r'
                    if numel(hData.Modifier) < 1
                        obj.isReverse = ~obj.isReverse;
                    elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                        p_reset(obj,false);
                    end
                case 's'
                    if numel(hData.Modifier) < 1
                        obj.isSkip = ~obj.isSkip;
                    elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                        callbackMain(obj,'PBStore');
                    end
                case 't'
                    if numel(hData.Modifier) < 1
                        obj.isTrack = ~obj.isTrack;
                    elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                        % nothing
                    end
                case 'u'
                    if numel(hData.Modifier) < 1
                        % nothing
                    elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                        callbackMain(obj,'PBUndo');
                    end
                case 'v'
                    if numel(hData.Modifier) < 1
                        % nothing
                    elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                        callbackMain(obj,'PBResetView');
                    end
                case 'space'
                    if numel(hData.Modifier) < 1
                        if obj.isPlay, stop(obj); else, play(obj); end
                    elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                        if obj.isPlay, stop(obj); obj.frame = 1; else, obj.frame = 1; play(obj); end
                    end
                    %
                % up and down arrow are disabled to allow navigation in the listbox of the
                % videoplaylist
                %
                % case 'downarrow'
                %     if numel(hData.Modifier) < 1
                %         obj.frame = obj.ui.SFrame.Max;
                %     elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                %         % nothing
                %     end
                % case 'uparrow'
                %    if numel(hData.Modifier) < 1
                %         obj.frame = obj.ui.SFrame.Min;
                %     elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                %         % nothing
                %     end
                case 'rightarrow'
                    if numel(hData.Modifier) < 1
                        obj.frame = min(obj.p_frame+1,obj.nFrameMax);
                    elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                        obj.frame = min(obj.p_frame+10,obj.nFrameMax);
                    end
                case 'leftarrow'
                    if numel(hData.Modifier) < 1
                        obj.frame = max(obj.p_frame-1,obj.nFrameMin);
                    elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                        obj.frame = max(obj.p_frame-10,obj.nFrameMin);
                    end
            end
        end
        
        function out   = createMainMenu(obj,idxAx)
            %createMainMenu Creates a context menu for the axes of the video player
            
            out = uicontextmenu('Parent',obj.main);
            %
            % Style menu
            tmp = uimenu(out, 'Label', 'Style');
            % Resize sub menu
            tmp2 = uimenu(tmp, 'Label', 'Set figure size to', 'Enable', 'on');
            for i = 1:size(obj.resolution,1)
                uimenu(tmp2, 'Label', obj.resolution{i,2}, 'Callback',...
                    @(src,dat) callbackMainMenu(obj,idxAx,obj.resolution{i,1},src,dat));
            end
            % Font size sub menu
            tmp2 = uimenu(tmp, 'Label', 'Set font size of all videos to','Separator','on', 'Enable', 'on');
            for i = 10:2:40
                uimenu(tmp2, 'Label', num2str(i), 'Callback',...
                    @(src,dat) callbackMainMenu(obj,idxAx,'FontSizeAll',src,i));
            end
            tmp2 = uimenu(tmp, 'Label', sprintf('Set font size of video %d to',idxAx), 'Enable', 'on');
            for i = 10:2:40
                uimenu(tmp2, 'Label', num2str(i), 'Callback',...
                    @(src,dat) callbackMainMenu(obj,idxAx,'FontSizeSingle',src,i));
            end
            uimenu(tmp, 'Label', 'Set font properties of all videos','Separator','off', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'FontToolAll',src,dat));
            uimenu(tmp, 'Label', sprintf('Set font properties of video %d',idxAx), 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'FontToolSingle',src,dat));
            % colormap & display range
            uimenu(tmp, 'Label', 'Change colormap of all videos','Separator','on', 'Callback',...
                @(src,dat) callbackMainMenu(obj,[],'colormap',src,dat));
            uimenu(tmp, 'Label', sprintf('Change colormap of video %d',idxAx), 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'colormap',src,dat));
            uimenu(tmp, 'Label', 'Change contrast of all videos', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'imcontrast',src,'all'));
            uimenu(tmp, 'Label', sprintf('Change contrast of video %d',idxAx), 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'imcontrast',src,'single'));
            tmp2 = uimenu(tmp, 'Label', 'Set display range for all videos to ','Separator','off');
            uimenu(tmp2, 'Label', 'automatic', 'Callback',...
                @(src,dat) callbackMainMenu(obj,[],'autodr',src,dat));
            uimenu(tmp2, 'Label', 'maximum', 'Callback',...
                @(src,dat) callbackMainMenu(obj,[],'maxdr',src,dat));
            tmp2 = uimenu(tmp, 'Label', sprintf('Set display range for video %d',idxAx),'Separator','off');
            uimenu(tmp2, 'Label', 'automatic', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'autodr',src,dat));
            uimenu(tmp2, 'Label', 'maximum', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'maxdr',src,dat));
            % grid
            tmp2 = uimenu(tmp, 'Label', 'Set grid for all videos to','Separator','on');
            uimenu(tmp2, 'Label', 'on', 'Callback',...
                @(src,dat) callbackMainMenu(obj,[],'grid',src,'on'));
            uimenu(tmp2, 'Label', 'off', 'Callback',...
                @(src,dat) callbackMainMenu(obj,[],'grid',src,'off'));
            tmp2 = uimenu(tmp, 'Label', sprintf('Set grid for video %d to',idxAx));
            uimenu(tmp2, 'Label', 'on', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'grid',src,'on'));
            uimenu(tmp2, 'Label', 'off', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'grid',src,'off'));
            % zoom & link axes
            uimenu(tmp, 'Label', 'Reset zoom of all videos','Separator','on', 'Callback',...
                @(src,dat) callbackMainMenu(obj,[],'resetZoom',src,dat));
            uimenu(tmp, 'Label', sprintf('Reset zoom of video %d',idxAx), 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'resetZoom',src,dat));
            uimenu(tmp, 'Label', 'Set magnification of all videos to one','Separator','off', 'Callback',...
                @(src,dat) callbackMainMenu(obj,[],'resetMag',src,dat));
            uimenu(tmp, 'Label', sprintf('Set magnification of video %d to one',idxAx), 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'resetMag',src,dat));
            tmp2 = uimenu(tmp, 'Label', 'Link axes limits of','Separator','off');
            uimenu(tmp2, 'Label', 'matching axes','Separator','off', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'link',src,dat));
            uimenu(tmp2, 'Label', 'all axes','Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'linkForce',src,dat));
            uimenu(tmp2, 'Label', 'none at all', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'unlink',src,dat));
            % unit length sub menu
            tmp2 = uimenu(tmp, 'Label', 'Change unit length of all videos to','Separator','on');
            uimenu(tmp2, 'Label', 'ym', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'unitLength-ym',src,true));
            uimenu(tmp2, 'Label', 'mm', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'unitLength-mm',src,true));
            uimenu(tmp2, 'Label', 'm', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'unitLength-m',src,true));
            uimenu(tmp2, 'Label', 'pix', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'unitLength-pix',src,true));
            uimenu(tmp2, 'Label', 'input ...', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'unitLength-user',src,true));
            tmp2 = uimenu(tmp, 'Label', sprintf('Change unit length of video %d to',idxAx));
            uimenu(tmp2, 'Label', 'ym', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'unitLength-ym',src,false));
            uimenu(tmp2, 'Label', 'mm', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'unitLength-mm',src,false));
            uimenu(tmp2, 'Label', 'm', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'unitLength-m',src,false));
            uimenu(tmp2, 'Label', 'pix', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'unitLength-pix',src,false));
            uimenu(tmp2, 'Label', 'input ...', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'unitLength-user',src,false));
            % unit time sub menu
            tmp2 = uimenu(tmp, 'Label', 'Change unit time of all videos to','Separator','off');
            uimenu(tmp2, 'Label', 'ns', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'unitTime-ns',src,true));
            uimenu(tmp2, 'Label', 'ys', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'unitTime-ys',src,true));
            uimenu(tmp2, 'Label', 'ms', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'unitTime-ms',src,true));
            uimenu(tmp2, 'Label', 's', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'unitTime-s',src,true));
            uimenu(tmp2, 'Label', 'input ...', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'unitTime-user',src,true));
            tmp2 = uimenu(tmp, 'Label', sprintf('Change unit time of video %d to',idxAx));
            uimenu(tmp2, 'Label', 'ns', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'unitTime-ns',src,false));
            uimenu(tmp2, 'Label', 'ys', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'unitTime-ys',src,false));
            uimenu(tmp2, 'Label', 'ms', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'unitTime-ms',src,false));
            uimenu(tmp2, 'Label', 's', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'unitTime-s',src,false));
            uimenu(tmp2, 'Label', 'input ...', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'unitTime-user',src,false));
            %
            % Export sub menu
            tmp = uimenu(out,   'Label', 'Export');
            uimenu(tmp, 'Label', 'Export all videos with dedicated figure', 'Callback',...
                @(src,dat) callbackMainMenu(obj,[],'export',src,dat));
            uimenu(tmp, 'Label', sprintf('Export video %d with dedicated figure',idxAx), 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'export',src,dat));
            uimenu(tmp, 'Label', sprintf('Export a binary mask from video %d',idxAx),'Separator','on', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'getMask',src,dat));
            uimenu(tmp, 'Label', sprintf('Export a pixel resolution from video %d (any)',idxAx), 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'getPixres',src,dat));
            uimenu(tmp, 'Label', sprintf('Export a pixel resolution from video %d (lines)',idxAx), 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'getPixresLines',src,dat));
            uimenu(tmp, 'Label', sprintf('Export a pixel resolution from video %d (squares)',idxAx), 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'getPixresGrid',src,dat));
            uimenu(tmp, 'Label', sprintf('Export a pixel resolution from video %d (dots)',idxAx), 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'getPixresDot',src,dat));
            uimenu(tmp, 'Label', 'Export video player object','Separator','on', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'exportObj',src,dat));
            uimenu(tmp, 'Label', sprintf('Export a backup for video %d',idxAx),'Separator','on', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'exportBackup',src,dat));
            uimenu(tmp, 'Label', 'Export a backup for all videos','Separator','off', 'Callback',...
                @(src,dat) callbackMainMenu(obj,[],'exportBackup',src,dat));
            uimenu(tmp, 'Label', sprintf('Load a backup for video %d',idxAx),'Separator','off', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'importBackup',src,dat));
            uimenu(tmp, 'Label', 'Load a backup for all videos','Separator','off', 'Callback',...
                @(src,dat) callbackMainMenu(obj,[],'importBackup',src,dat));
            uimenu(tmp, 'Label', sprintf('Open image of video %d in improfile',idxAx),'Separator','on', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'improfile',src,dat));
            uimenu(tmp, 'Label', sprintf('Open image of video %d in imsave',idxAx), 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'imsave',src,dat));
            uimenu(tmp, 'Label', sprintf('Open image of video %d in imtool',idxAx), 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'imtool',src,dat));
            uimenu(tmp, 'Label', sprintf('Open panel of video %d in export_fig',idxAx), 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'export_fig',src,dat));
            %
            % Info sub menu
            tmp = uimenu(out,   'Label', 'Info', 'Enable', 'off');
            uimenu(tmp, 'Label', 'Show all intensity profiles along tracks', 'Callback',...
                @(src,dat) callbackMainMenu(obj,[],'profile',src,dat));
            uimenu(tmp, 'Label', sprintf('Show intensity profiles of video %d',idxAx),'Separator','on', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'profile',src,dat));
            uimenu(tmp, 'Label', sprintf('Show histogram of video %d',idxAx), 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'imhist',src,dat));
            tmpComp = uimenu(tmp, 'Label', sprintf('Compare video %d to',idxAx));
            % Compare sub sub menu
            for i = 1:numel(obj.vid)
                uimenu(tmpComp, 'Label', sprintf('Video %d',i), 'Callback',...
                    @(src,dat) callbackMainMenu(obj,idxAx,'compare',src,i));
            end
            %
            % Tracking sub menu
            track = uimenu(out,   'Label', 'Track', 'Enable', 'off');
            uimenu(track, 'Label', 'Ellipse', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'imellipse',src,dat));
            uimenu(track, 'Label', 'Rectangle', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'imrect',src,dat));
            uimenu(track, 'Label', 'Polygon', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'impoly',src,dat));
            uimenu(track, 'Label', 'Line','Separator','on', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'imline',src,dat));
            uimenu(track, 'Label', 'Distline', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'imdistline',src,dat));
            uimenu(track, 'Label', 'Point', 'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'impoint',src,dat));
            % Tracking mode sub sub menu
            trackMode = uimenu(track, 'Label', 'Mode','Separator','on');
            str = {'Initial','Nearest','Linear'};
            idx = strcmpi(str,obj.opt.trackMode);
            tmp = gobjects(size(str));
            for i = 1:numel(str)
                tmp(i) = uimenu(trackMode, 'Label', str{i},'Callback',...
                    @(src,dat) callbackMainMenu(obj,idxAx,lower(str{i}),src,dat));
            end
            tmp(idx).Checked='on';
            % clear tracking
            uimenu(track, 'Label', sprintf('Reset ROIs of video %d',idxAx),'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'reset roi',src,dat));
            uimenu(track, 'Label', 'Reset ROIs of all videos','Callback',...
                @(src,dat) callbackMainMenu(obj,[],'reset roi',src,dat));
            uimenu(track, 'Label', sprintf('Clear ROIs of video %d',idxAx),'Callback',...
                @(src,dat) callbackMainMenu(obj,idxAx,'Clear',src,dat));
            uimenu(track, 'Label', 'Clear ROIs of all videos','Callback',...
                @(src,dat) callbackMainMenu(obj,[],'Clear',src,dat));
            %
            % Process sub menu
            tmp  = uimenu(out, 'Label', 'Process', 'Enable', 'off');
            tmp2 = uimenu(tmp, 'Label', 'Run for all video(s)');
            uimenu(tmp2, 'Label', 'Init', 'Callback',...
                @(src,dat) processInit(obj));
            uimenu(tmp2, 'Label', 'Run', 'Callback',...
                @(src,dat) update(obj));
            uimenu(tmp2, 'Label', 'Post', 'Callback',...
                @(src,dat) processPost(obj));
            tmp2 = uimenu(tmp, 'Label', sprintf('Run for video %d',idxAx));
            uimenu(tmp2, 'Label', 'Init', 'Callback',...
                @(src,dat) processInit(obj,idxAx));
            uimenu(tmp2, 'Label', 'Run', 'Callback',...
                @(src,dat) updateMain(obj,[],idxAx));
            uimenu(tmp2, 'Label', 'Post', 'Callback',...
                @(src,dat) processPost(obj,idxAx));
            %
            % Channel sub menu
            createChannelMenu(obj,idxAx,out,obj.vid(idxAx).nZ,obj.idxChannels{idxAx});
        end
        
        function out   = createChannelMenu(obj,idxAx,parent,nZ,val)
            %createChannelMenu Creates menu for channel selection in parent for given number of
            % available channels and current value
            
            out = uimenu(parent, 'Label', 'Channel', 'Enable', 'on');
            str = cellfun(@(x) sprintf('%d',x),num2cell(1:nZ),'un',false);
            if nZ == 3, str{end+1} = num2str(1:3); end
            idx = find(strcmp(str,num2str(val)));
            if numel(idx) ~= 1
                str{end+1} = num2str(val);
                idx        = numel(str);
            end
            tmp = gobjects(size(str));
            for i = 1:numel(str)
                tmp(i) = uimenu(out, 'Label', str{i}, 'Callback',...
                    @(src,dat) callbackMainMenu(obj,idxAx,'changeChannel',src,str{i}));
            end
            tmp(idx).Checked='on';
        end
        
        function out   = createExportMenu(obj)
            %createExportMenu Creates a context menu for the export figure
            
            out = uicontextmenu('Parent',obj.sub_export);
            %
            % Resize sub menu
            tmp       = uimenu(out,   'Label', 'Set figure size to', 'Enable', 'on');
            for i = 1:size(obj.resolution,1)
                uimenu(tmp, 'Label', obj.resolution{i,2}, 'Callback',...
                    @(src,dat) callbackExportMenu(obj,obj.resolution{i,1},src,dat));
            end
            uimenu(tmp, 'Label', 'Video player format','Separator','on','Callback',...
                @(src,dat) callbackExportMenu(obj,'main',src,dat));
            %
            % Line width and color
            tmp = uimenu(out, 'Label', 'Set line width to','Separator','on', 'Enable', 'on');
            for i = 0.5:0.5:8
                uimenu(tmp, 'Label', sprintf('%0.2f',i), 'Callback',...
                    @(src,dat) callbackExportMenu(obj,'LineWidth',src,i));
            end
            uimenu(out, 'Label', 'Vary line color', 'Callback',...
                @(src,dat) callbackExportMenu(obj,'LineColor',src,dat));
            %
            % Font size
            tmp = uimenu(out, 'Label', 'Set font size to','Separator','on', 'Enable', 'on');
            for i = 10:2:40
                uimenu(tmp, 'Label', num2str(i), 'Callback',...
                    @(src,dat) callbackExportMenu(obj,'FontSize',src,i));
            end
            uimenu(out, 'Label', 'Set font properties', 'Callback',...
                @(src,dat) callbackExportMenu(obj,'FontTool',src,dat));
            % colormap & contrast
            uimenu(out, 'Label', 'Change colormap','Separator','on', 'Callback',...
                @(src,dat) callbackExportMenu(obj,'colormap',src,dat));
            uimenu(out, 'Label', 'Change contrast','Separator','off', 'Callback',...
                @(src,dat) callbackExportMenu(obj,'changeContrast',src,dat));
            % display range
            tmp2 = uimenu(out, 'Label', 'Set display range to ','Separator','off');
            uimenu(tmp2, 'Label', 'automatic', 'Callback',...
                @(src,dat) callbackExportMenu(obj,'autodr',src,dat));
            uimenu(tmp2, 'Label', 'maximum', 'Callback',...
                @(src,dat) callbackExportMenu(obj,'maxdr',src,dat));
            % grid
            tmp2 = uimenu(out, 'Label', 'Set grid to','Separator','on');
            uimenu(tmp2, 'Label', 'on', 'Callback',...
                @(src,dat) callbackExportMenu(obj,'grid',src,'on'));
            uimenu(tmp2, 'Label', 'off', 'Callback',...
                @(src,dat) callbackExportMenu(obj,'grid',src,'off'));
            % labels
            tmp2 = uimenu(out, 'Label', 'Set labels to','Separator','off');
            uimenu(tmp2, 'Label', 'on', 'Callback',...
                @(src,dat) callbackExportMenu(obj,'cleanFigure',src,'off'));
            uimenu(tmp2, 'Label', 'off', 'Callback',...
                @(src,dat) callbackExportMenu(obj,'cleanFigure',src,'on'));
            % zoom & link axes
            uimenu(out, 'Label', 'Reset zoom','Separator','on', 'Callback',...
                @(src,dat) callbackExportMenu(obj,'resetZoom',src,dat));
            uimenu(out, 'Label', 'Set magnification to one','Separator','off', 'Callback',...
                @(src,dat) callbackExportMenu(obj,'resetMag',src,dat));
            tmp2 = uimenu(out, 'Label', 'Link axes limits of','Separator','off');
            uimenu(tmp2, 'Label', 'matching axes','Separator','off', 'Callback',...
                @(src,dat) callbackExportMenu(obj,'link',src,dat));
            uimenu(tmp2, 'Label', 'all axes','Callback',...
                @(src,dat) callbackExportMenu(obj,'linkForce',src,dat));
            uimenu(tmp2, 'Label', 'none at all', 'Callback',...
                @(src,dat) callbackExportMenu(obj,'unlink',src,dat));
            % remove tracks
            tmp2 = uimenu(out, 'Label', 'Set tracks to','Separator','on');
            uimenu(tmp2, 'Label', 'on','Separator','off', 'Callback',...
                @(src,dat) callbackExportMenu(obj,'AddTracks',src,dat));
            uimenu(tmp2, 'Label', 'off', 'Callback',...
                @(src,dat) callbackExportMenu(obj,'RemoveTracks',src,dat));
            % alpha
            tmp = uimenu(out, 'Label', 'Set alpha blending to','Separator','on');
            uimenu(tmp, 'Label', 'off','Separator','off', 'Callback',...
                @(src,dat) callbackExportMenu(obj,'AlphaOFF',src,[]));
            for i = 1:4
                cut = (i-1) * 0.05;
                uimenu(tmp, 'Label', sprintf('on, cut %.2g%%',cut*100), 'Callback',...
                    @(src,dat) callbackExportMenu(obj,'AlphaON',src,[cut 1-cut]));
            end
            % playback
            uimenu(out, 'Label', 'Start playing','Separator','on', 'Callback',...
                @(src,dat) play(obj));
            uimenu(out, 'Label', 'Stop playing', 'Callback',...
                @(src,dat) stop(obj));
            uimenu(out, 'Label', 'Jump to first frame', 'Callback',...
                @(src,dat) callbackExportMenu(obj,'FirstFrame',src,dat));
            uimenu(out, 'Label', 'Jump to mid frame', 'Callback',...
                @(src,dat) callbackExportMenu(obj,'MidFrame',src,dat));
            uimenu(out, 'Label', 'Jump to last frame', 'Callback',...
                @(src,dat) callbackExportMenu(obj,'LastFrame',src,dat));
        end
        
        function         trackAdd(obj,idxAx,type)
            %trackAdd Adds a new track of given type to video object and axes of video player
            
            %
            % create new ROI
            track          = Videoplayer.trackClean(obj.vid(idxAx).p_track);
            i              = numel(track)+1;
            allName        = {track.name};
            counter        = 1; while ismember(sprintf('%d',counter),allName), counter = counter + 1; end
            track(i).name  = sprintf('%d',counter);
            track(i).imroi = trackROICreate(obj,idxAx,type,[],track(i).name);
            mycol          = track(i).imroi.getColor;
            mypos          = trackROIPosition(obj,idxAx,track(i).imroi.getPosition,track(i).imroi,'ax2real');
            %
            % initialize position array in track
            if strcmp(obj.opt.trackMode,'initial')
                track(i).position = repmat(reshape(mypos,1,[]),obj.vid(idxAx).nFrames,1);
                track(i).color    = repmat(reshape(mycol,1,[]),obj.vid(idxAx).nFrames,1);
            else
                track(i).position = NaN(obj.vid(idxAx).nFrames,numel(mypos));
                track(i).color    = NaN(obj.vid(idxAx).nFrames,numel(mycol));
                track(i).position(obj.frameVideo(idxAx),:) = mypos(:);
                track(i).color(obj.frameVideo(idxAx),:)    = mycol(:);
            end
            % store new track in video object and update axes
            obj.vid(idxAx).p_track = track;
            trackUpdate(obj,idxAx);
        end
        
        function         trackUpdate(obj,idxAx)
            %trackUpdate Updates given axes to show corresponding tracks of video object
            
            if nargin < 2, idxAx = 1:numel(obj.ax);
            else,          idxAx = reshape(idxAx,1,[]);
            end
            for k = idxAx
                track = obj.vid(k).p_track;
                idxFr = obj.frameVideo(k);
                for i = 1:numel(track)
                    %
                    % find position of ROI
                    if ischar(track(i).imroi), strROI = track(i).imroi;
                    else,                      strROI = class(track(i).imroi);
                    end
                    mypos = track(i).position(idxFr,:);
                    mycol = track(i).color(idxFr,:);
                    % find frame with known position if current is not known, same for color
                    if any(isnan(mypos(:)))
                        idxOK = find(all(~isnan(track(i).position),2));
                        if isempty(idxOK)
                            error(sprintf('%s:Input',mfilename),'Could not find any valid position for ROI');
                        elseif numel(idxOK) == 1 || idxFr < min(idxOK) || idxFr > max(idxOK) || ...
                                any(strcmp(obj.opt.trackMode,{'nearest','initial'}))
                            % use closest known position
                            [~, idx] = min(abs(idxOK-idxFr));
                            mypos    = track(i).position(idxOK(idx),:);
                        elseif numel(idxOK) > 1
                            % linear interpolation
                            mypos    = interp1(idxOK,track(i).position(idxOK,:),idxFr,'linear','extrap');
                        end
                        % store it permanently
                        track(i).position(idxFr,:) = mypos;
                    end
                    if any(isnan(mycol(:)))
                        idxOK = find(all(~isnan(track(i).color),2));
                        if isempty(idxOK)
                            error(sprintf('%s:Input',mfilename),'Could not find any valid position for ROI');
                        else
                            % use closest known color
                            [~, idx] = min(abs(idxOK-idxFr));
                            mycol    = track(i).color(idxOK(idx),:);
                        end
                        % store it permanently
                        track(i).color(idxFr,:) = mycol;
                    end
                    %
                    % transform position to axes coordinate system
                    mypos = trackROIPosition(obj,k,mypos,strROI,'real2ax');
                    %
                    % restore ROI, reset position, triggers update of ROI via position callback
                    track(i).imroi = trackROICreate(obj,k,track(i).imroi,mypos,track(i).name);
                    if sum(abs(track(i).imroi.getColor - mycol)) > eps
                        track(i).imroi.setColor(mycol);
                    end
                    track(i).imroi.setPosition(mypos);
                end
                % store track in the object
                obj.vid(k).p_track = track;
            end
        end
        
        function         trackRead(obj,idxAx,name)
            %trackRead Reads position of ROIs from axes and stores in track of video object
            
            if nargin < 2 || isempty(idxAx), idxAx = 1:numel(obj.ax);
            else,                            idxAx = reshape(idxAx,1,[]);
            end
            for k = idxAx
                track = Videoplayer.trackClean(obj.vid(k).p_track);
                idxFr = obj.frameVideo(k);
                if nargin < 3, idxROI = 1:numel(track);
                else,          idxROI = reshape(find(strcmp(name,{track.name})),1,[]);
                end
                for i = idxROI
                    if ~ischar(track(i).imroi)
                        track(i).position(idxFr,:) = ...
                            trackROIPosition(obj,k,track(i).imroi.getPosition,track(i).imroi,'ax2real');
                        track(i).color(idxFr,:) = track(i).imroi.getColor;
                    end
                end
                obj.vid(k).p_track = track;
            end
        end
        
        function         trackHide(obj,idxAx)
            %trackHide Reads and deletes ROIs from axes, but stores before in tracks of video object
            
            if nargin < 2 || isempty(idxAx), idxAx = 1:numel(obj.ax);
            else,                            idxAx = reshape(idxAx,1,[]);
            end
            trackRead(obj,idxAx);
            for k = idxAx
                track = Videoplayer.trackClean(obj.vid(k).p_track);
                for i = 1:numel(track)
                    if ~ischar(track(i).imroi)
                        delete(track(i).imroi);
                        track(i).imroi = class(track(i).imroi);
                    end
                end
                obj.vid(k).p_track = track;
            end
        end
        
        function         trackReset(obj,idxAx)
            %trackReset Resets position and color to NaN except for the current frame
            
            if nargin < 2 || isempty(idxAx), idxAx = 1:numel(obj.vid);
            else,                            idxAx = reshape(idxAx,1,[]);
            end
            for v = idxAx
                myframe = obj.frameVideo(v);
                for t = 1:numel(obj.vid(v).p_track)
                    tmpPos = obj.vid(v).p_track(t).position(myframe,:);
                    tmpCol = obj.vid(v).p_track(t).color(myframe,:);
                    obj.vid(v).p_track(t).position = NaN(size(obj.vid(v).p_track(t).position));
                    obj.vid(v).p_track(t).color    = NaN(size(obj.vid(v).p_track(t).color));
                    obj.vid(v).p_track(t).position(myframe,:) = tmpPos;
                    obj.vid(v).p_track(t).color(myframe,:)    = tmpCol;
                end
            end
        end
        
        function mypos = trackROIPosition(obj,idxAx,mypos,roi,trans)
            %trackROIPosition Transforms position of a ROI from axes to physical units or vice versa
            
            if ischar(roi), strROI = roi;
            else,           strROI = class(roi);
            end
            switch trans
                case 'ax2real'
                    if isnan(obj.usca(idxAx))
                        switch strROI
                            case {'imellipse','imrect'}
                                tmp                 = mypos(1:2) + mypos(3:4);
                                [mypos(1),mypos(2)] = transformCoordinates(obj.vid(idxAx),mypos(1),mypos(2),'pix2real');
                                mypos(3:4)          = mypos(3:4) .* obj.vid(idxAx).pixres;
                                [tmp(1),tmp(2)]     = transformCoordinates(obj.vid(idxAx),tmp(1),tmp(2),'pix2real');
                                if tmp(1)-mypos(1) < 0, mypos(1) = tmp(1); end
                                if tmp(2)-mypos(2) < 0, mypos(2) = tmp(2); end
                            otherwise
                                [mypos(:,1),mypos(:,2)] = transformCoordinates(obj.vid(idxAx),mypos(:,1),mypos(:,2),'pix2real');
                        end
                    else
                        mypos = mypos/obj.usca(idxAx);
                    end
                    mypos = reshape(mypos,1,[]);
                case 'real2ax'
                    if ismember(strROI,{'imline', 'impoly', 'impoint', 'imdistline'})
                        mypos = reshape(mypos,[],2);
                    end
                    if isnan(obj.usca(idxAx))
                        switch strROI
                            case {'imellipse','imrect'}
                                tmp                 = mypos(1:2) + mypos(3:4);
                                [mypos(1),mypos(2)] = transformCoordinates(obj.vid(idxAx),mypos(1),mypos(2),'real2pix');
                                mypos(3:4)          = mypos(3:4) ./ obj.vid(idxAx).pixres;
                                [tmp(1),tmp(2)]     = transformCoordinates(obj.vid(idxAx),tmp(1),tmp(2),'real2pix');
                                if tmp(1)-mypos(1) < 0, mypos(1) = tmp(1); end
                                if tmp(2)-mypos(2) < 0, mypos(2) = tmp(2); end
                            otherwise
                                [mypos(:,1),mypos(:,2)] = transformCoordinates(obj.vid(idxAx),mypos(:,1),mypos(:,2),'real2pix');
                        end
                    else
                        mypos = mypos*obj.usca(idxAx);
                    end
            end
        end
        
        function roi   = trackROICreate(obj,idxAx,roi,mypos,name)
            %trackROICreate Creates single ROI in given axes at given position with given name
            % In case the position is empty it will ask for user input to draw ROI in axes
            
            if ischar(roi)
                % create ROI
                strROI = roi;
                func   = str2func(roi);
                if isempty(mypos)
                    switch strROI
                        case 'imdistline'
                            tmp    = imline(obj.ax(idxAx));
                            tmpPos = tmp.getPosition;
                            roi    = func(obj.ax(idxAx),tmpPos(:,1),tmpPos(:,2));
                            delete(tmp);
                        case 'impoly'
                            roi = func(obj.ax(idxAx),'Closed',true);
                            Videoplayer.disableDeleteVortexImpoly(roi);
                        otherwise
                            roi = func(obj.ax(idxAx));
                    end
                    mypos = roi.getPosition;
                else
                    switch strROI
                        case {'imellipse', 'imrect', 'imline', 'impoint'}
                            roi = func(obj.ax(idxAx),mypos);
                        case 'impoly'
                            roi = func(obj.ax(idxAx),mypos,'Closed',true);
                            Videoplayer.disableDeleteVortexImpoly(roi);
                        case 'imdistline'
                            roi = func(obj.ax(idxAx),mypos(:,1),mypos(:,2));
                        otherwise
                            error(sprintf('%s:Input',mfilename),'Unknown ROI ''%s''',strROI);
                    end
                end
                % make it interactive
                roi.addNewPositionCallback(@(pos) trackROIUpdate(obj,idxAx,name));
                roi.addNewPositionCallback(@(pos) trackRead(obj,idxAx,name));
                roi.addNewPositionCallback(@(pos) updateProfile(obj,idxAx,name));
                tmp = get(roi,'DeleteFcn');
                set(roi,'DeleteFcn',{@(a,b,c,d) trackROIDelete(obj,idxAx,roi) tmp});
                % add labels to ROI
                tmpSet = {'Interpreter','none','PickableParts','none',...
                    'HorizontalAlignment','center','VerticalAlignment','middle'};
                switch strROI
                    case {'imellipse'}
                        ud.label = text('Position',mypos(1:2)+0.5*mypos(3:4),...
                            'Parent',obj.ax(idxAx),'String',name,'FontSize',14,tmpSet{:});
                        ud.label(2) = text('Position',mypos(1:2)+0.5*[0 mypos(4)],...
                            'Parent',obj.ax(idxAx),'String','c','FontSize',12,tmpSet{:});
                        ud.label(3) = text('Position',mypos(1:2)+0.5*[mypos(3) 0],...
                            'Parent',obj.ax(idxAx),'String','d','FontSize',12,tmpSet{:});
                        ud.label(4) = text('Position',mypos(1:2)+[mypos(3) mypos(4)/2],...
                            'Parent',obj.ax(idxAx),'String','a','FontSize',12,tmpSet{:});
                        ud.label(5) = text('Position',mypos(1:2)+[mypos(3)/2 mypos(4)],...
                            'Parent',obj.ax(idxAx),'String','b','FontSize',12,tmpSet{:});
                    case {'imrect'}
                        ud.label = text('Position',mypos(1:2)+0.5*mypos(3:4),...
                            'Parent',obj.ax(idxAx),'String',name,'FontSize',14,tmpSet{:});
                        ud.label(2) = text('Position',mypos(1:2),...
                            'Parent',obj.ax(idxAx),'String','a','FontSize',12,tmpSet{:});
                        ud.label(3) = text('Position',mypos(1:2)+[mypos(3) 0],...
                            'Parent',obj.ax(idxAx),'String','b','FontSize',12,tmpSet{:});
                        ud.label(4) = text('Position',mypos(1:2)+[mypos(3) mypos(4)],...
                            'Parent',obj.ax(idxAx),'String','c','FontSize',12,tmpSet{:});
                        ud.label(5) = text('Position',mypos(1:2)+[0 mypos(4)],...
                            'Parent',obj.ax(idxAx),'String','d','FontSize',12,tmpSet{:});
                    case {'imdistline'}
                        ud.label = text('Position',mypos(1,:)+0.15*diff(mypos,1,1),...
                            'Parent',obj.ax(idxAx),'String',name,'FontSize',14,tmpSet{:});
                        if size(mypos,1) > 1
                            idxChar = [97:122 65:90];
                            for p = 1:size(mypos,1)
                                ud.label(p+1) = text('Position',mypos(p,:),...
                                    'Parent',obj.ax(idxAx),'String',char(idxChar(p)),'FontSize',12,tmpSet{:});
                            end
                        end
                    otherwise
                        ud.label = text('Position',mean(mypos,1),...
                            'Parent',obj.ax(idxAx),'String',name,'FontSize',14,tmpSet{:});
                        if size(mypos,1) > 1
                            idxChar = [97:122 65:90];
                            for p = 1:size(mypos,1)
                                ud.label(p+1) = text('Position',mypos(p,:),...
                                    'Parent',obj.ax(idxAx),'String',char(idxChar(p)),'FontSize',12,tmpSet{:});
                            end
                        end
                end
                set(roi,'UserData',ud);
                trackROIUpdate(obj,idxAx,name);
            end
        end
        
        function         trackROIUpdate(obj,idxAx,name)
            %trackROIUpdate Updates labels of ROIs
            
            % update labels of ROI
            if nargin < 2, idxAx = 1:numel(obj.ax);
            else,          idxAx = reshape(idxAx,1,[]);
            end
            for k = idxAx
                track = obj.vid(k).p_track;
                if nargin < 3, idxROI = 1:numel(track);
                else,          idxROI = reshape(find(strcmp(name,{track.name})),1,[]);
                end
                for i = idxROI
                    if ~ischar(track(i).imroi)
                        ud    = get(track(i).imroi,'UserData');
                        if isfield(ud,'label')
                            mypos = track(i).imroi.getPosition;
                            mycol = track(i).imroi.getColor;
                            switch class(track(i).imroi)
                                case {'imellipse'}
                                    set(ud.label(1),'Position',mypos(1:2)+0.5*mypos(3:4),...
                                        'BackgroundColor',mycol,'Color',1-mycol);
                                    set(ud.label(2),'Position',mypos(1:2)+0.5*[0 mypos(4)],...
                                        'BackgroundColor',mycol,'Color',1-mycol);
                                    set(ud.label(3),'Position',mypos(1:2)+0.5*[mypos(3) 0],...
                                        'BackgroundColor',mycol,'Color',1-mycol);
                                    set(ud.label(4),'Position',mypos(1:2)+[mypos(3) mypos(4)/2],...
                                        'BackgroundColor',mycol,'Color',1-mycol);
                                    set(ud.label(5),'Position',mypos(1:2)+[mypos(3)/2 mypos(4)],...
                                        'BackgroundColor',mycol,'Color',1-mycol);
                                case {'imrect'}
                                    set(ud.label(1),'Position',mypos(1:2)+0.5*mypos(3:4),...
                                        'BackgroundColor',mycol,'Color',1-mycol);
                                    set(ud.label(2),'Position',mypos(1:2),...
                                        'BackgroundColor',mycol,'Color',1-mycol);
                                    set(ud.label(3),'Position',mypos(1:2)+[mypos(3) 0],...
                                        'BackgroundColor',mycol,'Color',1-mycol);
                                    set(ud.label(4),'Position',mypos(1:2)+[mypos(3) mypos(4)],...
                                        'BackgroundColor',mycol,'Color',1-mycol);
                                    set(ud.label(5),'Position',mypos(1:2)+[0 mypos(4)],...
                                        'BackgroundColor',mycol,'Color',1-mycol);
                                case {'imdistline'}
                                    set(ud.label(1),'Position',mypos(1,:)+0.15*diff(mypos,1,1),...
                                        'BackgroundColor',mycol,'Color',1-mycol);
                                    if size(mypos,1) > 1
                                        for p = 1:size(mypos,1)
                                            set(ud.label(p+1),'Position',mypos(p,:),...
                                                'BackgroundColor',mycol,'Color',1-mycol);
                                        end
                                    end
                                otherwise
                                    set(ud.label(1),'Position',mean(mypos,1),...
                                        'BackgroundColor',mycol,'Color',1-mycol);
                                    if size(mypos,1) > 1
                                        for p = 1:size(mypos,1)
                                            set(ud.label(p+1),'Position',mypos(p,:),...
                                                'BackgroundColor',mycol,'Color',1-mycol);
                                        end
                                    end
                            end
                        end
                    end
                end
            end
        end
        
        function         trackROIDelete(obj,idxAx,imroi)
            %trackROIDelete Removes ROI from axes and corresponding track from video object
            
            % delete labels of given ROI
            if ~ischar(imroi)
                try
                    ud = get(imroi,'UserData');
                    fn = fieldnames(ud);
                    for i = 1:numel(fn)
                        delete(ud.(fn{i}));
                    end
                catch err
                    % Re-throw error message if it is not related to invalid handle
                    if ~strcmp(err.identifier, 'MATLAB:class:InvalidHandle')
                        rethrow(err);
                    end
                end
            end
            % remove ROI from video object
            idxBad = false(size(obj.vid(idxAx).p_track));
            for i = 1:numel(obj.vid(idxAx).p_track)
                if ~ischar(obj.vid(idxAx).p_track(i).imroi) && (~isvalid(obj.vid(idxAx).p_track(i).imroi) || ...
                        strcmp(get(obj.vid(idxAx).p_track(i).imroi,'BeingDeleted'),'on'))
                    idxBad(i) = true;
                end
            end
            obj.vid(idxAx).p_track(idxBad) = [];
        end
        
        function         createProfile(obj,forceNew,idxAx)
            %createProfile Creates profile figure
            
            %
            % enable ROI tracking
            obj.isTrack = true;
            %
            % create figure or reuse existing one
            if forceNew && obj.isProfile, delete(obj.sub_profile); end
            if ~obj.isProfile
                myPos   = get(groot,'DefaultFigurePosition');
                myStyle = obj.main.WindowStyle;
                obj.sub_profile  = figure('numbertitle', 'off', 'Visible','on',...
                    'name', 'Video Player - Profiles', ...
                    'Tag', sprintf('%s_Profile',obj.tagMain),...
                    'Position',myPos,...
                    'menubar','none', ...
                    'toolbar','figure', ...
                    'resize', 'on', ...
                    'WindowScrollWheelFcn', @(src,dat) callbackScroll(obj,src,dat),...
                    'HandleVisibility','callback');
                if nargin < 3, idxAx = 1:numel(obj.ax); end
                obj.sub_profile.WindowStyle    = myStyle;
                obj.sub_profile.UserData.idxAx = idxAx;
                obj.sub_profile.UserData.type  = [2 3];
            end
            %
            % build figure from scratch
            idxAx = obj.sub_profile.UserData.idxAx;
            type  = obj.sub_profile.UserData.type;
            if isfield(obj.sub_profile.UserData,'ax')
                delete(obj.sub_profile.UserData.ax);
            end
            delete(obj.sub_profile.Children);
            idxAx(idxAx > numel(obj.vid)) = [];
            if isempty(idxAx), return; end
            axTmp = subplot(2,1,1,'Parent',obj.sub_profile,'NextPlot','Add',...
                'ColorOrder',get(groot,'DefaultAxesColorOrder'),...
                'LineStyleOrder',get(groot,'DefaultAxesLineStyleOrder'),...
                'DeleteFcn',@(src,dat) deleteProfileAxes(obj,src,dat));
            axTmp(2) = subplot(2,1,2,'Parent',obj.sub_profile,'NextPlot','Add',...
                'ColorOrder',get(groot,'DefaultAxesColorOrder'),...
                'LineStyleOrder',get(groot,'DefaultAxesLineStyleOrder'),...
                'DeleteFcn',@(src,dat) deleteProfileAxes(obj,src,dat));
            axTmp(1).UserData.type = 2;
            axTmp(2).UserData.type = 3;
            ylim(axTmp(1),[0 1]);
            zlim(axTmp(2),[0 1]);
            view(axTmp(2),3);
            if numel(obj.ustr) == numel(unique(obj.ustr))
                if isempty(obj.ustr{1})
                    xlabel(axTmp(1),'arc length');
                    xlabel(axTmp(2),'image x axis');
                    ylabel(axTmp(2),'image y axis');
                else
                    xlabel(axTmp(1),sprintf('arc length (%s)',obj.ustr{1}));
                    xlabel(axTmp(2),sprintf('image x axis (%s)',obj.ustr{1}));
                    ylabel(axTmp(2),sprintf('image y axis (%s)',obj.ustr{1}));
                end
            else
                xlabel(axTmp(1),'arc length (video units)');
                xlabel(axTmp(2),'image x axis (video units)');
                ylabel(axTmp(2),'image y axis (video units)');
            end
            ylabel(axTmp(1),'normalized intensity');
            zlabel(axTmp(2),'normalized intensity');
            obj.sub_profile.UserData.ax = axTmp;
            obj.sub_profile.DeleteFcn   = @(src,dat) deleteProfile(obj,src,dat);
            %
            % init and update view
            anyNew = false;
            for k = reshape(idxAx,1,[])
                track = obj.vid(k).p_track;
                if numel(track) > 0
                    idxFr = obj.frameVideo(k);
                    if obj.isProcess && ~isempty(obj.process) && ~isempty(obj.process.func{k})
                        out = trackProfile(obj.vid(k),'idxTrack',1:numel(track),'idxFrame',idxFr,...
                            'img',obj.process.data{k});
                    else
                        out = trackProfile(obj.vid(k),'idxTrack',1:numel(track),'idxFrame',idxFr);
                    end
                    for i = 1:numel(track)
                        if ~ischar(track(i).imroi)
                            ud  = get(track(i).imroi,'UserData');
                            if isnan(obj.usca(k))
                                out(i).s = out(i).s/mean(obj.vid(k).pixres);
                                out(i).x = out(i).x/obj.vid(k).pixres(1);
                                out(i).y = out(i).y/obj.vid(k).pixres(2);
                            else
                                out(i).s = out(i).s*obj.usca(k);
                                out(i).x = out(i).x*obj.usca(k);
                                out(i).y = out(i).y*obj.usca(k);
                            end
                            if isa(track(i).imroi,'impoint'), linspec = 'o';
                            else,                             linspec = '-';
                            end
                            if isfield(ud,'profile'), delete(ud.profile); end
                            ud.profile   = gobjects(numel(obj.idxChannels{k}),1);
                            ud.profile3D = gobjects(numel(obj.idxChannels{k}),1);
                            for p = 1:numel(ud.profile)
                                ud.profile(p) = plot(out(i).s,out(i).cdata(:,:,obj.idxChannels{k}(p)),linspec,...
                                    'Parent',obj.sub_profile.UserData.ax(1),...
                                    'DisplayName',sprintf('Video %d, CH%d, ROI: %s',k,obj.idxChannels{k}(p),track(i).name),...
                                    'DeleteFCN',@(src,dat) deleteProfileLine(obj,k,track(i).name,src,dat));
                                ud.profile3D(p) = plot3(out(i).x,out(i).y,out(i).cdata(:,:,obj.idxChannels{k}(p)),linspec,...
                                    'Parent',obj.sub_profile.UserData.ax(2),...
                                    'DisplayName',ud.profile(p).DisplayName,...
                                    'DeleteFCN',@(src,dat) deleteProfileLine(obj,k,track(i).name,src,dat),...
                                    'Color',ud.profile(p).Color);
                                anyNew = true;
                            end
                            set(track(i).imroi,'UserData',ud);
                        end
                    end
                end
            end
            if anyNew
                legend(obj.sub_profile.UserData.ax(1),'off','Location','northeastoutside');
                legend(obj.sub_profile.UserData.ax(1),'show','Location','northeastoutside');
                legend(obj.sub_profile.UserData.ax(2),'off','Location','northeastoutside');
                legend(obj.sub_profile.UserData.ax(2),'show','Location','northeastoutside');
            end
            trackUpdate(obj);
            Videoplayer.changeFont(obj.sub_profile,obj.opt);
            % remove unwanted types
            if ~ismember(2,type), delete(axTmp(1)); end
            if ~ismember(3,type), delete(axTmp(2)); end
            if isscalar(type)
                if ismember(2,type)
                    axTmp(1).OuterPosition = [0.0 0.0 1 1];
                    legend(axTmp(1),'off','Location','northoutside');
                    legend(axTmp(1),'show','Location','northoutside');
                else
                    axTmp(2).OuterPosition = [0.0 0.0 1 1];
                    legend(axTmp(2),'off','Location','northoutside');
                    legend(axTmp(2),'show','Location','northoutside');
                end
            end
        end
        
        function         cleanProfile(obj)
            %cleanProfile Cleans profile figure
            
            if obj.isProfile && ~isempty(obj.sub_profile.Children)
                Videoplayer.disableInteractiveModes(obj.sub_profile);
                h1   = findall(obj.sub_profile,'type','axes');
                type = [];
                for i = 1:numel(h1)
                    if isstruct(h1(i).UserData) && isfield(h1(i).UserData,'type')
                        type = [type,h1(i).UserData.type]; %#ok<AGROW>
                    end
                end
                obj.sub_profile.UserData.type = unique(type);
                delete(obj.sub_profile.Children);
            end
        end
        
        function         deleteProfile(obj,hObject,hData) %#ok<INUSD>
            %deleteProfile Deletes profile figure
            
            if obj.isProfile, delete(obj.sub_profile); end
            obj.sub_profile = [];
            % remove profiles from ROI
            for k = 1:numel(obj.vid)
                for i = 1:numel(obj.vid(k).p_track)
                    if ~ischar(obj.vid(k).p_track(i).imroi)
                        ud = get(obj.vid(k).p_track(i).imroi,'UserData');
                        if isfield(ud,'profile'), ud = rmfield(ud,'profile'); end
                        if isfield(ud,'profile3D'), ud = rmfield(ud,'profile3D'); end
                        set(obj.vid(k).p_track(i).imroi,'UserData',ud);
                    end
                end
            end
        end
        
        function         updateProfile(obj,idxAx,name)
            %updateProfile Updates profiles
            
            if ~obj.isProfile, return; end
            if nargin < 2, idxAx = 1:numel(obj.ax);
            else,          idxAx = reshape(idxAx,1,[]);
            end
            if ~any(isgraphics(obj.sub_profile.UserData.ax)), return; end
            %
            % updates profiles
            for k = idxAx
                track = obj.vid(k).p_track;
                if nargin < 3, idxROI = 1:numel(track);
                else,          idxROI = reshape(find(strcmp(name,{track.name})),1,[]);
                end
                if numel(idxROI) > 0
                    idxFr = obj.frameVideo(k);
                    if obj.isProcess && ~isempty(obj.process) && ~isempty(obj.process.func{k})
                        out = trackProfile(obj.vid(k),'idxTrack',idxROI,'idxFrame',idxFr,...
                            'img',obj.process.data{k});
                    else
                        out = trackProfile(obj.vid(k),'idxTrack',idxROI,'idxFrame',idxFr);
                    end
                    for i = 1:numel(idxROI)
                        if ~ischar(track(idxROI(i)).imroi)
                            ud  = get(track(idxROI(i)).imroi,'UserData');
                            if isnan(obj.usca(k))
                                out(i).s = out(i).s/mean(obj.vid(k).pixres);
                                out(i).x = out(i).x/obj.vid(k).pixres(1);
                                out(i).y = out(i).y/obj.vid(k).pixres(2);
                            else
                                out(i).s = out(i).s*obj.usca(k);
                                out(i).x = out(i).x*obj.usca(k);
                                out(i).y = out(i).y*obj.usca(k);
                            end
                            if isgraphics(obj.sub_profile.UserData.ax(1)) && ...
                                    isfield(ud,'profile') && numel(ud.profile) == numel(obj.idxChannels{k}) && ...
                                    all(isgraphics(ud.profile))
                                for p = 1:numel(ud.profile)
                                    set(ud.profile(p),'XData',out(i).s,'YData',out(i).cdata(:,:,obj.idxChannels{k}(p)));
                                end
                            end
                            if isgraphics(obj.sub_profile.UserData.ax(2)) && ...
                                    isfield(ud,'profile3D') && numel(ud.profile3D) == numel(obj.idxChannels{k}) && ...
                                    all(isgraphics(ud.profile3D))
                                for p = 1:numel(ud.profile3D)
                                    set(ud.profile3D(p),'XData',out(i).x,'YData',out(i).y,'ZData',out(i).cdata(:,:,obj.idxChannels{k}(p)));
                                end
                            end
                        end
                    end
                end
            end
        end
        
        function         deleteProfileAxes(obj,src,dat) %#ok<INUSD,INUSL>
            %deleteProfileAxes Delete axis in profile figure without affecting the other
            
            h = findall(src,'type','line');
            set(h,'DeleteFcn','');
            delete(h);
            delete(src);
        end
        
        function         deleteProfileLine(obj,idxAx,name,src,dat) %#ok<INUSD>
            %deleteProfileLine Deletes profiles line and updates legend
            
            % delete line in axes and profile in ROI
            delete(src);
            track  = obj.vid(idxAx).p_track;
            idxROI = reshape(find(strcmp(name,{track.name})),1,[]);
            for i = idxROI
                if ~ischar(track(i).imroi)
                    ud = get(track(i).imroi,'UserData');
                    if isfield(ud,'profile')
                        delete(ud.profile)
                        ud = rmfield(ud,'profile');
                    end
                    if isfield(ud,'profile3D')
                        delete(ud.profile3D)
                        ud = rmfield(ud,'profile3D');
                    end
                    set(track(i).imroi,'UserData',ud);
                end
            end
            % update legend
            if obj.isProfile
                if isgraphics(obj.sub_profile.UserData.ax(1)) && ...
                        strcmp(obj.sub_profile.UserData.ax(1).BeingDeleted,'off') && ...
                        numel(obj.sub_profile.UserData.ax(1).Children) > 0 && ...
                        any(isgraphics(obj.sub_profile.UserData.ax(1).Children))
                    legend(obj.sub_profile.UserData.ax(1),'off','Location','northeastoutside');
                    legend(obj.sub_profile.UserData.ax(1),'show','Location','northeastoutside');
                end
                if isgraphics(obj.sub_profile.UserData.ax(2)) && ...
                        strcmp(obj.sub_profile.UserData.ax(2).BeingDeleted,'off') && ...
                        numel(obj.sub_profile.UserData.ax(2).Children) > 0 && ...
                        any(isgraphics(obj.sub_profile.UserData.ax(2).Children))
                    legend(obj.sub_profile.UserData.ax(2),'off','Location','northeastoutside');
                    legend(obj.sub_profile.UserData.ax(2),'show','Location','northeastoutside');
                end
            end
        end
        
        function         createCompare(obj,addNew,idx1,idx2)
            %createCompare Creates a new compare figure
            
            obj.sub_compare = Videoplayer.cleanFigures(obj.sub_compare);
            if addNew
                % create single new figure
                if isempty(obj.sub_compare)
                    idx             = 1;
                    obj.sub_compare = gobjects;
                else
                    idx = numel(obj.sub_compare) + 1;
                end
                myPos   = get(groot,'DefaultFigurePosition');
                myStyle = obj.main.WindowStyle;
                obj.sub_compare(idx) = figure('numbertitle', 'off', 'Visible','on',...
                    'name', sprintf('Video Player - Video %d vs Video %d',idx1,idx2), ...
                    'Tag', sprintf('%s_Compare',obj.tagMain),...
                    'Position',myPos,...
                    'menubar','none', ...
                    'toolbar','figure', ...
                    'resize', 'on', ...
                    'DeleteFcn', @(src,dat) deleteCompare(obj,false,src,dat),...
                    'WindowScrollWheelFcn', @(src,dat) callbackScroll(obj,src,dat),...
                    'HandleVisibility','callback');
                obj.sub_compare(idx).WindowStyle   = myStyle;
                obj.sub_compare(idx).UserData.idx1 = idx1;
                obj.sub_compare(idx).UserData.idx2 = idx2;
            end
            % delete figures that show videos not available any
            idxBad = false(size(obj.sub_compare));
            for i = 1:numel(obj.sub_compare)
                if isgraphics(obj.sub_compare(i),'figure')
                    idx1 = obj.sub_compare(i).UserData.idx1;
                    idx2 = obj.sub_compare(i).UserData.idx2;
                    if ~(idx1 <= numel(obj.img) && idx2 <= numel(obj.img))
                        idxBad(i) = true;
                    end
                end
            end
            delete(obj.sub_compare(idxBad));
            obj.sub_compare = Videoplayer.cleanFigures(obj.sub_compare);
            % recreate figures if they are clean
            for i = 1:numel(obj.sub_compare)
                if isgraphics(obj.sub_compare(i),'figure') && isempty(obj.sub_compare(i).Children)
                    idx1 = obj.sub_compare(i).UserData.idx1;
                    idx2 = obj.sub_compare(i).UserData.idx2;
                    delete(obj.sub_compare(i).Children);
                    if idx1 <= numel(obj.img) && idx2 <= numel(obj.img)
                        axTmp = subplot(1,1,1,'Parent',obj.sub_compare(i));
                        try
                            [cdata,R] = imfuse(obj.img(idx1).CData,obj.vid(idx1).ref2d,obj.img(idx2).CData,obj.vid(idx2).ref2d,obj.opt.compareMode);
                        catch err
                            obj.sub_compare(i).delete;
                            error(sprintf('%s:Error',mfilename),'Error during call of imfuse (maybe scaling of images not correct?):\n%s\n',...
                                err.getReport);
                        end
                        imgTmp = imshow(cdata,R,'Parent',axTmp,'InitialMagnification','fit');
                        title(axTmp,{sprintf('%s vs %s',obj.vid(idx1).name,obj.vid(idx2).name);sprintf('imfuse with method ''%s''',obj.opt.compareMode)});
                        obj.sub_compare(i).UserData.ax  = axTmp;
                        obj.sub_compare(i).UserData.img = imgTmp;
                        Videoplayer.changeFont(obj.sub_compare(i),obj.opt);
                    end
                end
            end
            obj.sub_compare = Videoplayer.cleanFigures(obj.sub_compare);
            updateCompare(obj);
        end
        
        function         cleanCompare(obj)
            %cleanCompare Cleans compare figure(s)
            
            if obj.isCompare
                for i = 1:numel(obj.sub_compare)
                    if isgraphics(obj.sub_compare(i),'figure') && ~isempty(obj.sub_compare(i).Children)
                        Videoplayer.disableInteractiveModes(obj.sub_compare(i));
                        delete(obj.sub_compare(i).Children);
                    end
                end
            end
            obj.sub_compare = Videoplayer.cleanFigures(obj.sub_compare);
        end
        
        function         deleteCompare(obj,all,hObject,hData) %#ok<INUSD>
            %deleteCompare Deletes compare figure(s)
            
            if obj.isCompare && all
                delete(obj.sub_compare);
            elseif obj.isCompare
                delete(hObject);
            end
            obj.sub_compare = Videoplayer.cleanFigures(obj.sub_compare);
        end
        
        function         updateCompare(obj)
            %updateCompare Updates compare figures
            
            if ~obj.isCompare, return; end
            obj.sub_compare = Videoplayer.cleanFigures(obj.sub_compare);
            for i = 1:numel(obj.sub_compare)
                idx1 = obj.sub_compare(i).UserData.idx1;
                idx2 = obj.sub_compare(i).UserData.idx2;
                set(obj.sub_compare(i).UserData.img,'CData', imfuse(...
                    obj.img(idx1).CData,obj.vid(idx1).ref2d,obj.img(idx2).CData,obj.vid(idx2).ref2d,obj.opt.compareMode));
            end
        end
        
        function         createExport(obj,forceNew,idxAx)
            %createExport Create an export figure
            
            if forceNew && obj.isExport, delete(obj.sub_export); end
            if ~obj.isExport
                % create single new figure
                figPos  = [obj.main.Position(1:2)+[0 80] 960 540]; % obj.main.Position + [0 80 0 -80];
                myStyle = obj.main.WindowStyle;
                obj.sub_export = figure('numbertitle', 'off', 'Visible','on',...
                    'Position',figPos,...
                    'name', 'Video Player - Export', ...
                    'Tag', sprintf('%s_Export',obj.tagMain),...
                    'menubar','none', ...
                    'toolbar','figure', ...
                    'resize', 'on', ...
                    'Color','white',...
                    'DeleteFcn', @(src,dat) deleteExport(obj,src,dat),...
                    'WindowScrollWheelFcn', @(src,dat) callbackScroll(obj,src,dat),...
                    'HandleVisibility','on');
                if nargin < 3, idxAx = 1:numel(obj.ax); end
                obj.sub_export.WindowStyle        = myStyle;
                obj.sub_export.UserData.idxAx     = idxAx;
                obj.sub_export.UserData.fontstyle = Videoplayer.changeFont([],obj.opt);
                obj.sub_export.UserData.fontstyle.fontsize = 18;
                obj.sub_export.UserData.isTracks  = obj.isTrack;
                obj.sub_export.UserData.linkAxes  = obj.opt.linkAxes;
            end
            idxAx = obj.sub_export.UserData.idxAx;
            idxAx(idxAx > numel(obj.vid)) = [];
            if isempty(idxAx), return; end
            % check if axes are available to be reused
            myax   = findall(obj.sub_export,'type','axes');
            idxTMP = NaN(size(myax));
            for i = 1:numel(myax)
                if isstruct(myax(i).UserData) && isfield(myax(i).UserData,'idxAx')
                    myimg = findobj(myax(i),'Type','image');
                    if numel(myimg) == 1
                        idxTMP(i) = myax(i).UserData.idxAx;
                    end
                end
            end
            if all(ismember(idxAx,idxTMP))
                % use existing axes, but delete axes that show a video that is not available any
                % more in videoplayer object, update x and ydata of image
                idxBad = ~isnan(idxTMP) & ~ismember(idxTMP,idxAx);
                delete(myax(idxBad));
                myax(idxBad | isnan(idxTMP)) = [];
                for i = 1:numel(myax)
                    myidx = myax(i).UserData.idxAx;
                    myimg = findobj(myax(i),'Type','image');
                    myimg.XData = obj.img(myidx).XData;
                    myimg.YData = obj.img(myidx).YData;
                end
                updateExport(obj);
            else
                % delete children and build figure from scratch
                delete(obj.sub_export.Children);
                tmpMenu                      = createExportMenu(obj);
                obj.sub_export.UIContextMenu = tmpMenu;
                obj.sub_export.Colormap      = colormap(obj.ax(idxAx(1)));
                % create axes
                myax  = gobjects(size(obj.vid));
                myimg = gobjects(size(obj.vid));
                ni    = size(obj.vid,1);
                nj    = size(obj.vid,2);
                k     = 1;
                for j = 1:nj
                    for i = 1:ni
                        if ismember(k,idxAx)
                            myax(k) = axes('OuterPosition',[(j-1)/nj 1-i/ni 1/nj 1/ni],...
                                'Parent',obj.sub_export,'Layer',obj.opt.layer, 'Tag',num2str(k),...
                                'YDir',obj.ax(k).YDir,'XDir',obj.ax(k).XDir,...
                                'LineWidth',2,'NextPlot','Add','Color','none',...
                                'UIContextMenu',tmpMenu);
                            myax(k).UserData.idxAx = k;
                            myimg(k) = image(...
                                'XData',obj.img(k).XData,...
                                'YData',obj.img(k).YData,...
                                'CData',obj.img(k).CData,...
                                'CDataMapping','scaled',...
                                'UIContextMenu',tmpMenu,...
                                'BusyAction', 'cancel', ...
                                'Parent', myax(k), ...
                                'Interruptible', 'off');
                            xlabel(myax(k),obj.textX(k).String);
                            ylabel(myax(k),obj.textY(k).String);
                            if numel(obj.textT(k).String) > 2
                                title(myax(k),obj.textT(k).String([1 3]),'Interpreter','none');
                            else
                                title(myax(k),obj.vid(k).name,'Interpreter','none');
                            end
                            axis(myax(k),'image');
                            fov = Videoplayer.imageFOVGet(obj.ax(k));
                            Videoplayer.imageFOVSet(myax(k),fov);
                        end
                        k = k + 1;
                    end
                end
                myax = myax(isgraphics(myax,'axes'));
                % resize figure if idxAx is scalar
                if isscalar(myax),myax.OuterPosition = [0.0 0.0 1 1]; end
                % link axes, create tracks, update and restore font
                if obj.sub_export.UserData.linkAxes, Videoplayer.linkAllAxes(obj.sub_export,myax); end
                if obj.sub_export.UserData.isTracks, createExportTracks(obj,true); end
                updateExport(obj);
                Videoplayer.changeFont(obj.sub_export,obj.sub_export.UserData.fontstyle);
            end
        end
        
        function         createExportTracks(obj,addTracks)
            %createExportTracks Adds tracks to export figure
            
            % delete all tracks first
            myline = findobj(obj.sub_export,'Type','line','Tag','track');
            delete(myline);
            % add tracks
            if addTracks
                xE   = @(t,c,d,phi) c(1) + d(1)/2 * cos(phi) * cos(t) - d(2)/2 * sin(phi) * sin(t);
                yE   = @(t,c,d,phi) c(2) + d(1)/2 * sin(phi) * cos(t) + d(2)/2 * cos(phi) * sin(t);
                myax = findobj(obj.sub_export,'Type','axes');
                for k = 1:numel(myax)
                    if isfield(myax(k).UserData,'idxAx')
                        idxAx = myax(k).UserData.idxAx;
                        for i = 1:numel(obj.vid(idxAx).p_track)
                            if ischar(obj.vid(idxAx).p_track(i).imroi), strROI = obj.vid(idxAx).p_track(i).imroi;
                            else,                                       strROI = class(obj.vid(idxAx).p_track(i).imroi);
                            end
                            idxFr = obj.frameVideo(idxAx);
                            mypos = obj.vid(idxAx).p_track(i).position(idxFr,:);
                            mypos = trackROIPosition(obj,idxAx,mypos,strROI,'real2ax');
                            mycol = obj.vid(idxAx).p_track(i).color(idxFr,:);
                            name  = obj.vid(idxAx).p_track(i).name;
                            if any(isnan(mycol(:))) || any(isnan(mypos(:)))
                                plot(myax(k),NaN(2,1),NaN(2,1),'-','Color','k','Linewidth',2,...
                                    'DisplayName',name,'Tag','track');
                            else
                                switch strROI
                                    case {'imellipse'}
                                        t = linspace(0,2*pi);
                                        x = xE(t,mypos(1:2)+0.5*mypos(3:4),mypos(3:4),0);
                                        y = yE(t,mypos(1:2)+0.5*mypos(3:4),mypos(3:4),0);
                                        plot(myax(k),x,y,'-','Color',mycol,'Linewidth',2,...
                                            'DisplayName',name,'Tag','track');
                                    case {'imrect' 'imline', 'imdistline', 'impoly', 'impoint'}
                                        if strcmp(strROI,'imrect')
                                            mypos = repmat(mypos(1:2),5,1) + [ 0 0; mypos(3) 0; mypos(3) mypos(4); 0 mypos(4); 0 0];
                                        elseif strcmp(strROI,'impoly')
                                            mypos = [mypos; mypos(1,:)]; %#ok<AGROW>
                                        end
                                        if strcmp(strROI,'impoint')
                                            plot(myax(k),mypos(:,1),mypos(:,2),'o','Color',mycol,'Linewidth',2,...
                                                'DisplayName',name,'Tag','track');
                                        else
                                            plot(myax(k),mypos(:,1),mypos(:,2),'-','Color',mycol,'Linewidth',2,...
                                                'DisplayName',name,'Tag','track');
                                        end
                                    otherwise
                                        error(sprintf('%s:Input',mfilename),'Unknown ROI ''%s''',strROI);
                                end
                            end
                        end
                    end
                end
            end
        end
        
        function         cleanExport(obj)
            %cleanExport Cleans export figure
            
            if obj.isExport && ~isempty(obj.sub_export.Children)
                Videoplayer.disableInteractiveModes(obj.sub_export);
                obj.sub_export.UserData.linkAxes = isfield(obj.sub_export.UserData,'link');
                h1 = findall(obj.sub_export,'type','axes');
                h2 = findall(obj.sub_export,'type','text');
                if ~isempty(h1),     h = h1(1);
                elseif ~isempty(h2), h = h2(1);
                else,                h = [];
                end
                if ~isempty(h)
                    obj.sub_export.UserData.fontstyle = ...
                        struct('fontname', h.FontName, 'fontsize', h.FontSize, 'fontweight', h.FontWeight, 'fontangle', h.FontAngle);
                end
                idxAx = [];
                for i = 1:numel(h1)
                    if isstruct(h1(i).UserData) && isfield(h1(i).UserData,'idxAx')
                        idxAx = [idxAx,h1(i).UserData.idxAx]; %#ok<AGROW>
                    end
                end
                if ~isempty(idxAx)
                    obj.sub_export.UserData.idxAx = idxAx;
                end
            end
        end
        
        function         deleteExport(obj,hObject,hData) %#ok<INUSD>
            %deleteExport Deletes export figure
            
            delete(obj.sub_export);
            obj.sub_export = [];
        end
        
        function         updateExport(obj)
            %updateExport Update export figure
            
            if ~obj.isExport, return; end
            xE   = @(t,c,d,phi) c(1) + d(1)/2 * cos(phi) * cos(t) - d(2)/2 * sin(phi) * sin(t);
            yE   = @(t,c,d,phi) c(2) + d(1)/2 * sin(phi) * cos(t) + d(2)/2 * cos(phi) * sin(t);
            myax = findobj(obj.sub_export,'Type','axes');
            for i = 1:numel(myax)
                if isfield(myax(i).UserData,'idxAx')
                    myimg = findobj(myax(i),'Type','image');
                    if ~isempty(myimg)
                        % get index of video
                        idxAx = myax(i).UserData.idxAx;
                        % set cdata
                        myimg.CData = obj.img(idxAx).CData;
                        % set alpha data from gray value
                        if ~isempty(obj.opt.alphaCut)
                            alpha = myimg.CData;
                            if ndims(alpha) == 3
                                alpha = rgb2gray(alpha);
                            end
                            myimg.AlphaData = imcomplement(imadjust(alpha,obj.opt.alphaCut,[0 1],1));
                        else
                            myimg.AlphaData = 1;
                        end
                        % update title
                        if isvalid(obj.textT(idxAx)) && numel(obj.textT(idxAx).String) > 2 && ...
                                iscell(myax(i).Title.String) && numel(myax(i).Title.String) > 1
                            myax(i).Title.String = obj.textT(idxAx).String([1 3]);
                        end
                        % update tracks
                        myline = findobj(myax(i),'Type','line','Tag','track');
                        if numel(myline) > 0
                            [idxOK, idx] = ismember({myline.DisplayName},{obj.vid(idxAx).p_track.name});
                            delete(myline(~idxOK));
                            idx          = idx(idxOK);
                            myline       = myline(idxOK);
                            for j = 1:numel(myline)
                                if ischar(obj.vid(idxAx).p_track(idx(j)).imroi), strROI = obj.vid(idxAx).p_track(idx(j)).imroi;
                                else,                                            strROI = class(obj.vid(idxAx).p_track(idx(j)).imroi);
                                end
                                mypos = obj.vid(idxAx).p_track(idx(j)).position(obj.frameVideo(idxAx),:);
                                mypos = trackROIPosition(obj,idxAx,mypos,strROI,'real2ax');
                                mycol = obj.vid(idxAx).p_track(idx(j)).color(obj.frameVideo(idxAx),:);
                                switch strROI
                                    case {'imellipse'}
                                        t = linspace(0,2*pi);
                                        x = xE(t,mypos(1:2)+0.5*mypos(3:4),mypos(3:4),0);
                                        y = yE(t,mypos(1:2)+0.5*mypos(3:4),mypos(3:4),0);
                                        set(myline(j),'XData',x,'YData',y)
                                    case {'imrect' 'imline', 'imdistline', 'impoly', 'impoint'}
                                        if strcmp(strROI,'imrect')
                                            mypos = repmat(mypos(1:2),5,1) + [ 0 0; mypos(3) 0; mypos(3) mypos(4); 0 mypos(4); 0 0];
                                        elseif strcmp(strROI,'impoly')
                                            mypos = [mypos; mypos(1,:)]; %#ok<AGROW>
                                        end
                                        set(myline(j),'XData',mypos(:,1),'YData',mypos(:,2));
                                    otherwise
                                        error(sprintf('%s:Input',mfilename),'Unknown ROI ''%s''',strROI);
                                end
                                if all(~isnan(mycol(:))), myline(j).Color = mycol; end
                            end
                        end
                    end
                end
            end
            try
                if ~isempty(obj.opt.exportFunc)
                    if iscell(obj.opt.exportFunc)
                        for i = 1:numel(obj.opt.exportFunc)
                            obj.opt.exportFunc{i}(obj);
                        end
                    else
                        obj.opt.exportFunc(obj);
                    end
                end
            catch err
                warning(sprintf('%s:Error',mfilename),['Error during call of user export function:\n%s\n'...
                    'Nevertheless, tried to continue'],err.getReport);
            end
        end
        
        function         createHist(obj,addNew,idxAx)
            %createHist (Re-)creates hist figure
            
            obj.sub_hist = Videoplayer.cleanFigures(obj.sub_hist);
            if addNew
                % create single new figure
                obj.sub_hist = Videoplayer.cleanFigures(obj.sub_hist);
                if isempty(obj.sub_hist)
                    idx          = 1;
                    obj.sub_hist = gobjects;
                else
                    idx = numel(obj.sub_hist) + 1;
                end
                myPos   = get(groot,'DefaultFigurePosition');
                myStyle = obj.main.WindowStyle;
                obj.sub_hist(idx) = figure('numbertitle', 'off', 'Visible','on',...
                    'name', sprintf('Video Player - Histogram of video %d',idxAx), ...
                    'Tag', sprintf('%s_Hist',obj.tagMain),...
                    'Position',myPos,...
                    'menubar','none', ...
                    'toolbar','figure', ...
                    'resize', 'on', ...
                    'DeleteFcn', @(src,dat) deleteHist(obj,false,src,dat),...
                    'WindowScrollWheelFcn', @(src,dat) callbackScroll(obj,src,dat),...
                    'HandleVisibility','callback');
                obj.sub_hist(idx).WindowStyle    = myStyle;
                obj.sub_hist(idx).UserData.idxAx = idxAx;
            end
            % recreate figures if they are clean
            for i = 1:numel(obj.sub_hist)
                if isgraphics(obj.sub_hist(i),'figure') && isempty(obj.sub_hist(i).Children)
                    idxAx = obj.sub_hist(i).UserData.idxAx;
                    if isfield(obj.sub_hist(i).UserData,'listen')
                        delete(obj.sub_hist(i).UserData.listen);
                    end
                    delete(obj.sub_hist(i).Children);
                    if idxAx <= numel(obj.img)
                        axTmp      = subplot(1,1,1,'Parent',obj.sub_hist(i));
                        tmp        = im2double(obj.img(idxAx).CData);
                        if size(tmp,3) > 1, tmp = rgb2gray(tmp); end
                        [counts,x] = imhist(tmp);
                        h          = stem(x,counts/(size(tmp,1)*size(tmp,2)),'Parent',axTmp);
                        t          = title(axTmp,obj.textT(idxAx).String,'Interpreter','none');
                        xlabel(axTmp,'normalized intensity')
                        ylabel(axTmp,'probability');
                        obj.sub_hist(i).UserData.title  = t;
                        obj.sub_hist(i).UserData.stem   = h;
                        obj.sub_hist(i).UserData.listen = addlistener(obj.img(idxAx) , 'CData' , 'PostSet' , ...
                            @(h,e) updateHist(obj,obj.sub_hist(i)));
                        Videoplayer.changeFont(obj.sub_hist(i),obj.opt);
                    end
                end
            end
            obj.sub_hist = Videoplayer.cleanFigures(obj.sub_hist);
            updateHist(obj);
        end
        
        function         updateHist(obj,fig)
            %updateHist Updates figure created for imhist
            
            if nargin < 2
                for i = 1:numel(obj.sub_hist)
                    updateHist(obj,obj.sub_hist(i));
                end
                return;
            end
            if isgraphics(fig)
                idxAx      = fig.UserData.idxAx;
                tmp        = im2double(obj.img(idxAx).CData);
                if size(tmp,3) > 1, tmp = rgb2gray(tmp); end
                [counts,x] = imhist(tmp);
                set(fig.UserData.stem,'XData',x,'YData',counts/(size(tmp,1)*size(tmp,2)));
                set(fig.UserData.title,'String', obj.textT(idxAx).String);
            end
        end
        
        function         cleanHist(obj)
            %cleanHist Cleans hist figure(s)
            
            if obj.isHist
                for i = 1:numel(obj.sub_hist)
                    if isgraphics(obj.sub_hist(i),'figure') && ~isempty(obj.sub_hist(i).Children)
                        Videoplayer.disableInteractiveModes(obj.sub_hist(i));
                        delete(obj.sub_hist(i).UserData.listen);
                        delete(obj.sub_hist(i).Children);
                    end
                end
            end
            obj.sub_hist = Videoplayer.cleanFigures(obj.sub_hist);
        end
        
        function         deleteHist(obj,deleteAll,hObject,hData) %#ok<INUSD>
            %deleteHist Deletes figure created for imhist
            
            if obj.isHist
                if deleteAll
                    for i = 1:numel(obj.sub_hist)
                        if isstruct(obj.sub_hist(i)) && isfield(obj.sub_hist(i),'listen')
                            delete(obj.sub_hist(i).UserData.listen);
                        end
                    end
                    delete(obj.sub_hist);
                else
                    if isstruct(hObject.UserData) && isfield(hObject.UserData,'listen')
                        delete(hObject.UserData.listen);
                    end
                    delete(hObject);
                end
            end
            obj.sub_hist = Videoplayer.cleanFigures(obj.sub_hist);
        end
    end
    
    %% Save method
    methods
        function S = saveobj(obj)
            %saveobj Saves video objects and options as structure
            
            % return a structure with the necessary information to restore the object from disk
            S = struct;
            for k = 1:numel(obj)
                S(k).opt   = obj(k).opt;
                S(k).frame = obj(k).frame;
                S(k).vid   = obj(k).vid;
                S(k).state = obj(k).state;
            end
            S = reshape(S,size(obj));
        end
    end
    
    %% Static methods
    methods (Static = true, Access = public, Hidden = false)
        function value = imageFOVGet(ax)
            %imageFOVGet Gets image field of view, expects single image in an axes
            
            %
            % check input
            if ~all(isgraphics(ax,'axes'))
                error(sprintf('%s:Input',mfilename),'Expected one or more axes as first input');
            end
            %
            % run for each axes separately
            if numel(ax) > 1
                value = struct('XLim',{},'YLim',{});
                for i = 1:numel(ax)
                    value(i) = Videoplayer.imageFOVGet(ax(i));
                end
                return;
            end
            %
            % find image
            img = findall(ax,'type','image');
            if isempty(img)
                error(sprintf('%s:Input',mfilename),'Expected to find an image in each axis');
            end
            img = img(1);
            value.XLim = interp1(img.XData,[0 1],ax.XLim,'linear','extrap');
            value.YLim = interp1(img.YData,[0 1],ax.YLim,'linear','extrap');
        end
        
        function value = imageFOVSet(ax,fov)
            %imageFOVSet Sets image field of view, expects single image in an axes
            
            %
            % check input
            if ~all(isgraphics(ax,'axes'))
                error(sprintf('%s:Input',mfilename),'Expected one or more axes as first input');
            elseif ~(isstruct(fov) && numel(fov)==numel(fov))
                error(sprintf('%s:Input',mfilename),'Expected structure array as second input');
            end
            %
            % run for each axes separately
            if numel(ax) > 1
                value = struct;
                for i = 1:numel(ax)
                    Videoplayer.imageFOVSet(ax(i),fov(i));
                end
                return;
            end
            %
            % find image
            img = findall(ax,'type','image');
            if isempty(img)
                error(sprintf('%s:Input',mfilename),'Expected to find an image in each axis');
            end
            img = img(1);
            ax.XLim = sort(interp1([0 1],img.XData,fov.XLim,'linear','extrap'));
            ax.YLim = sort(interp1([0 1],img.YData,fov.YLim,'linear','extrap'));
        end
        
        function         linkAllAxes(fig,myax)
            %linkAllAxes Links limits of axes with the same label
            
            %
            % check input
            if ~all(isgraphics(fig,'figure'))
                error(sprintf('%s:Input',mfilename),'Expected one or more figures as first input');
            elseif numel(fig) > 1 && nargin < 2
                % process each figure separately
                for i = 1:numel(fig)
                    Videoplayer.linkAllAxes(fig(i));
                end
                return;
            end
            if nargin < 2 || isempty(myax)
                myax = findall(fig,'type','axes');
            elseif ~all(isgraphics(myax,'axes'))
                error(sprintf('%s:Input',mfilename),'Expected multiple axes as second input');
            end
            if numel(myax) < 2, return; end
            %
            % link axes with the same labels
            strName = {'X' 'Y' 'Z'};
            counter = 1;
            for i = 1:numel(strName)
                strAll = arrayfun(@(x) x.([strName{i} 'Label']).String, myax, 'un', false);
                str    = unique(strAll);
                for k = 1:numel(str)
                    idx = strcmp(strAll,str{k});
                    if sum(idx) > 1
                        mylink(counter) = linkprop(myax(idx),[strName{i} 'Lim']); %#ok<AGROW>
                        counter         = counter + 1;
                    end
                end
            end
            % store links in figure
            if counter > 1, fig.UserData.link = mylink; end
        end
        
        function         unlinkAllAxes(fig)
            %unlinkAllAxes Unlink axes
            %
            % check input
            if ~all(isgraphics(fig,'figure'))
                error(sprintf('%s:Input',mfilename),'Expected one or more figures as first input');
            end
            % unlink matched links from linkAllAxes
            for i = 1:numel(fig)
                if isstruct(fig(i).UserData) && isfield(fig(i).UserData,'link')
                    fig(i).UserData = rmfield(fig(i).UserData,'link');
                end
            end
            % unlink any other link from linkaxes
            ax = findall(fig,'type','axes');
            if ~isempty(ax)
                linkaxes(ax,'off');
            end
        end
        
        function value = changeFont(parent,fontstyle)
            %changeFont Changes font of all axes and texts in a given parent graphics object
            
            if ~isempty(parent)
                h1  = findall(parent,'type','axes');
                h2  = findall(parent,'type','text');
            else
                h1 = []; h2 = [];
            end
            value = struct('fontname', [], 'fontsize', [], 'fontweight', [], 'fontangle', []);
            fn    = fieldnames(fontstyle);
            for i = 1:numel(fn)
                switch lower(fn{i})
                    case {'fontname', 'fontsize', 'fontweight', 'fontangle'}
                        if ~isempty(fontstyle.(fn{i}))
                            value.(lower(fn{i})) = fontstyle.(fn{i});
                            if ~isempty(h1)
                                set(h1,lower(fn{i}),fontstyle.(fn{i}));
                            end
                            if ~isempty(h2)
                                set(h2,lower(fn{i}),fontstyle.(fn{i}));
                            end
                        end
                end
            end
        end
        
        function fig   = cleanFigures(fig)
            %cleanFigures Removes figures from array that are not valid any more
            
            fig(~isgraphics(fig,'figure')) = [];
            if ~isempty(fig)
                fig(strcmp('on',{fig.BeingDeleted})) = [];
            end
            if isempty(fig), fig = []; end
        end
        
        function         disableInteractiveModes(fig)
            %disableInteractiveModes Disables interactive modes of figure, e.g. zoom, pan, etc.
            
            for i = 1:numel(fig)
                if isgraphics(fig(i),'figure')
                    zoom(fig(i),'off');
                    rotate3d(fig(i),'off');
                    pan(fig(i),'off');
                    plotedit(fig(i),'off');
                    brush(fig(i),'off');
                    h = findall(fig(i),'type','hggroup');
                    for k = 1:numel(h)
                        if isa(h(k),'matlab.graphics.shape.internal.PointDataTip')
                            delete(h(k));
                        end
                    end
                    dcm           = datacursormode(fig(i));
                    dcm.UpdateFcn = [];
                    dcm.Enable    = 'off';
                    datacursormode(fig(i),'off');
                end
            end
        end
        
        function fig   = getParentFigure(fig)
            %getParentFigure Returns the parent figure of a graphics object
            
            while ~isempty(fig) && ~isgraphics(fig,'figure')
                fig = fig.Parent;
            end
        end
        
        function         disableDeleteVortexImpoly(roi)
            %disableDeleteVortexImpoly Tries to remove delete vortex menu entry from impoly
            
            if ~isa(roi,'impoly'), return; end
            try %#ok<TRYNC>
                tmpC = get(roi,'Children');
                tmpH = findall(tmpC,'Tag','impoly vertex');
                tmpH = tmpH(1).UIContextMenu.Children;
                for i = 1:numel(tmpH)
                    if strcmp(tmpH(i).Label,'Delete Vertex')
                        delete(tmpH(1)); break;
                    end
                end
            end
        end
        
        function obj   = loadobj(S)
            %loadobj Loads object
            
            if isstruct(S)
                obj = Videoplayer(numel(S));
                for k = 1:numel(S)
                    obj(k)         = Videoplayer(S(k).vid,S(k).opt);
                    obj(k).p_state = S(k).state;
                    createMain(obj(k));
                    obj(k).frame   = S(k).frame;
                end
                reshape(obj,size(S));
            else
                obj = S;
            end
        end
    end
    
    methods (Static = true, Access = protected, Hidden = false)
        function track = trackClean(track)
            %trackClean Cleans or initializes structure to handle ROIs
            
            if isempty(track)
                track = struct('imroi',{},'position',{},'color',{},'name',{});
            elseif ~isstruct(track) || (isstruct(track) && ~all(isfield(track,{'imroi' 'position'})))
                error(sprintf('%s:Track',mfilename),'Structure for tracking feature is unexpected, please check');
            else
                idxBad  = false(size(track));
                for i = 1:numel(track)
                    if isempty(track(i).imroi) || (~ischar(track(i).imroi) && ~isvalid(track(i).imroi))
                        idxBad(i) = true;
                    end
                end
                track(idxBad) = [];
                addColor = ~isfield(track,'color');
                addName  = ~isfield(track,'name');
                for i = 1:numel(track)
                    if addColor
                        track(i).color      = NaN(size(track(i).position));
                        track(i).color(1,:) = [1 0 0];
                    end
                    if addName, track(i).name = sprintf('%d',i); end
                end
            end
        end
    end
end
