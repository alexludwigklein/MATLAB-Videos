classdef Videoplaylist < handle
    %Videoplaylist Creates a playlist for the Videoplayer class
    %
    %----------------------------------------------------------------------------------
    %   Copyright 2016 Alexander Ludwig Klein, alexludwigklein@gmail.com
    %
    %   Physics of Fluids, University of Twente
    %----------------------------------------------------------------------------------
        
    %% Properties
    properties (GetAccess = public, SetAccess = public, Dependent = true)
        % vid Video objects that can be shown (n x Video)
        vid
        % name Name of video objects in playlist (n x cellstr)
        name
        % player Videoplayer object to show videos (Videoplayer)
        player
        % enable Logical whether the video is selected (n x logical)
        enable
        % splitup Splitup ratio when docking the playlist to the player (scalar double)
        splitup
        % isLive True/false whether object should update automatically for new videos (logical)
        isLive
    end
    
    properties (GetAccess = public, SetAccess = protected, Dependent = true)
        % isGUI True/false whether playlist main is currently open (logical)
        isGUI
        % isMaster True/false whether the GUI is not embedded in an unknown GUI
        isMaster
    end
    
    properties (GetAccess = protected, SetAccess = protected, Transient = true)
        % main Main figure or panel (figure)
        main      = [];
        % ui User interface objects, e.g. buttons (struct)
        ui        = struct;
        % p_vid Storage for vid
        p_vid     = [];
        % p_name Storage for name
        p_name    = {};
        % p_player Storage for player
        p_player  = [];
        % p_enable Storage for enable
        p_enable  = false(0);
        % state State of GUI during reset (struct)
        state     = struct;
        % p_parent Storage for parent
        p_parent  = [];
        % p_isLive Storage for isLive
        p_isLive  = false
    end
    
    properties (GetAccess = protected, SetAccess = protected, Dependent = true)
        % parent The figure where the playlist is shown in
        parent
    end
    
    %% Constructor/Destructor, SET/GET
    methods
        function obj   = Videoplaylist(vid,name,player,parent)
            %Videoplaylist Class constructor taking the video object(s) as first argument
            
            if nargin == 1 && isnumeric(vid)
                %
                % accepts single numeric input to create an array of objects
                obj      = Videoplaylist;
                obj(vid) = Videoplaylist;
            elseif nargin > 0
                if isa(vid,'Video')
                    obj.p_vid  = vid(:);
                    obj.p_name = reshape({vid(:).name},[],1);
                    nDig       = 1+ceil(log10(numel(obj.p_name)));
                    for k = 1:numel(obj.p_name)
                        obj.p_name{k} = sprintf('%0.*d: %s',nDig,k,obj.p_name{k});
                    end
                    obj.p_enable    = false(size(obj.p_vid));
                    obj.p_enable(1) = true;
                else
                    error(sprintf('%s:Input',mfilename),'First input should be an array of Video objects');
                end
                if nargin > 1
                    if iscellstr(name) && numel(name) == numel(vid)
                        obj.p_name = reshape(name,[],1);
                    elseif isempty(name)
                        obj.p_name = reshape({vid(:).name},[],1);
                        nDig       = 1+ceil(log10(numel(obj.p_name)));
                        for k = 1:numel(obj.p_name)
                            obj.p_name{k} = sprintf('%0.*d: %s',nDig,k,obj.p_name{k});
                        end
                    else
                        error(sprintf('%s:Input',mfilename),'Second input should a cellstr same size as first input with the names of the videos');
                    end
                end
                if nargin > 2
                    if isa(player,'Videoplayer')
                        obj.p_player = player;
                    elseif isempty(player)
                        % nothing
                    else
                        error(sprintf('%s:Input',mfilename),'Third input should a videoplayer object');
                    end
                end
                if nargin > 3
                    if isgraphics(parent,'figure') || isgraphics(parent,'uipanel') || isgraphics(parent,'uitab') && isvalid(parent)
                        obj.p_parent = parent;
                    else
                        error(sprintf('%s:Input',mfilename),'Fourth input should a valid figure, uipanel or uitab that serves has parent for the uipanel of the playlist');
                    end
                end
                createMain(obj);
            end
        end
        
        function delete(obj)
            %delete Class destructor to close GUI
            
            if ~isempty(obj.main), delete(obj.main); end
            cleanMyVideo(obj,false)
            obj.p_vid    = [];
            obj.p_player = [];
        end
        
        function value = get.isLive(obj)
            value = obj.p_isLive;
        end
        
        function         set.isLive(obj,value)
            if (islogical(value) || isnumeric(value)) && isscalar(value)
                value = logical(value);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for the property');
            end
            obj.p_isLive = value;
            if obj.isGUI, obj.ui.CLive.Value = value; end
        end
        
        function value = get.splitup(obj)
            if ~obj.isMaster
                value = 1;
            elseif obj.isGUI
                if isgraphics(obj.main,'figure')
                    value = 1;
                else
                    value = obj.player.mainPanel.Position(3);
                end
            elseif isfield(obj.state,'splitup') && obj.state.splitup < 1
                value = obj.state.splitup;
            else
                value = 0.8;
            end
        end
        
        function         set.splitup(obj,value)
            if isnumeric(value) && isscalar(value) && value > 0 && value < 1
                if ~obj.isMaster
                    obj.state.splitup = value;
                elseif obj.isGUI
                    if isgraphics(obj.main,'figure')
                        obj.state.splitup = value;
                    else
                        obj.player.mainPanel.Position(3) = value;
                        obj.main.Position = [value 0 1-value 1];
                        obj.state.splitup = value;
                    end 
                else
                    obj.state.splitup = value;
                end
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for the property');
            end
        end
        
        function value = get.vid(obj)
            value = obj.p_vid;
        end
        
        function         set.vid(obj,value)
            if isa(value,'Video')
                bakEnable  = obj.enable;
                obj.p_vid  = value(:);
                obj.p_name = reshape({value.name},[],1);
                nDig       = 1+ceil(log10(numel(obj.p_name)));
                for k = 1:numel(obj.p_name)
                    obj.p_name{k} = sprintf('%0.*d: %s',nDig,k,obj.p_name{k});
                end
                obj.p_enable    = false(size(obj.p_vid));
                obj.p_enable(1) = true;
                if numel(bakEnable) == numel(obj.p_enable)
                    obj.p_enable = bakEnable;
                end
                updateMain(obj);
                if obj.isGUI && obj.isLive
                    callbackMain(obj,'PBShow');
                end
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for the property');
            end
        end
        
        function value = get.name(obj)
            value = obj.p_name;
        end
        
        function         set.name(obj,value)
            if (iscellstr(value) && numel(value) == numel(obj.vid)) || (ischar(value) && numel(obj.vid) == 1)
                if ischar(value), value = {value}; end
                obj.p_name = reshape(value,[],1);
                if obj.isGUI
                    obj.ui.LBEnable.String = obj.p_name;
                    obj.ui.LBEnable.Value  = find(obj.enable);
                end
            elseif isempty(value)
                obj.p_name = reshape({obj.vid.name},[],1);
                nDig       = 1+ceil(log10(numel(obj.p_name)));
                for k = 1:numel(obj.p_name)
                    obj.p_name{k} = sprintf('%0.*d: %s',nDig,k,obj.p_name{k});
                end
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for the property');
            end
        end
        
        function value = get.player(obj)
            value = obj.p_player;
        end
        
        function         set.player(obj,value)
            if isa(value,'Videoplayer')
                obj.p_player = value;
            elseif isempty(value)
                if ~isempty(obj.player), delete(obj.player); end
                obj.p_player = [];
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for the property');
            end
        end
        
        function value = get.enable(obj)
            value = obj.p_enable;
        end
        
        function         set.enable(obj,value)
            if isempty(value)
                obj.p_enable = false(size(obj.vid));
                updateMain(obj);
            elseif islogical(value) && numel(value) == numel(obj.vid)
                obj.p_enable = value(:);
                updateMain(obj);
            elseif isnumeric(value) && max(value(:)) <= numel(obj.vid) && min(value(:)) > 0
                obj.p_enable               = false(size(obj.vid));
                obj.p_enable(round(value)) = true;
                updateMain(obj);
            else
                error(sprintf('%s:Input',mfilename),'Input not valid for the property');
            end
        end
        
        function value = get.isGUI(obj)
            value = ~isempty(obj.main) && isgraphics(obj.main);
        end
        
        function value = get.isMaster(obj)
            value = ~(~isempty(obj.p_parent) && isvalid(obj.p_parent));
        end
        
        function value = get.parent(obj)
            if ~obj.isGUI
                value = [];
            else
                value = Videoplayer.getParentFigure(obj.main);
            end
        end
    end
    
    %% Methods for public tasks
    methods (Access = public, Hidden = false, Sealed = true)
        function show(obj)
            %show Shows playlist
            
            if numel(obj) > 1
                for i = 1:numel(obj), show(obj(i)); end
                return;
            end
            if obj.isGUI
                getFocus(obj);
            else
                createMain(obj);
            end
        end
    end
    
    %% Methods for private tasks
    methods (Access = protected, Hidden = false, Sealed = true)
        function         createMain(obj,windowStyle)
            %createMain (Re-)creates the figure for the playlist
            
            if nargin < 2
                if isfield(obj.state,'WindowStyle')
                    windowStyle = obj.state.WindowStyle;
                elseif obj.isMaster
                    windowStyle = 'internal';
                else
                    windowStyle = 'slave';
                end
            end
            if strcmp(windowStyle,'slave') && obj.isMaster, windowStyle = 'internal'; end
            % create figure
            if ~isempty(obj.main) && (isgraphics(obj.main,'figure') || isgraphics(obj.main,'uipanel'))
                return;
            else
                if ~isempty(obj.main) && (isgraphics(obj.main,'figure') || isgraphics(obj.main,'uipanel')), delete(obj.main); end
                if strcmp(windowStyle,'slave')
                    mypos = [0 0 1 1];
                    if isfield(obj.state,'Position') && isfield(obj.state,'windowStyle') && ...
                            strcmp(obj.state.windowStyle,'slave')
                        mypos = obj.state.Position;
                    end
                    obj.main  = uipanel('parent',obj.p_parent,'Position',mypos,...
                        'Units','Normalized','BorderType','none',...
                        'DeleteFcn',      @(src,dat) deleteMain(obj),...
                        'SizeChangedFcn', @(src,dat) sizeChangedMain(obj,src,dat));
                elseif strcmp(windowStyle,'internal')
                    callbackMain(obj,'PBShow');
                    splitUp = obj.splitup;
                    if splitUp > 0.999; splitUp = 0.8; end
                    obj.player.mainPanel.Position(3) = splitUp;
                    obj.main  = uipanel('parent',obj.player.main,'Position',[splitUp 0 1-splitUp 1],...
                        'Units','Normalized','BorderType','none',...
                        'DeleteFcn',      @(src,dat) deleteMain(obj),...
                        'SizeChangedFcn', @(src,dat) sizeChangedMain(obj,src,dat));
                else
                    % create new figure
                    obj.main  = figure('numbertitle', 'off', 'Visible','off',...
                        'name', 'Video Player - Playlist', ...
                        'menubar','none', ...
                        'toolbar','none', ...
                        'resize', 'on', ...
                        'HandleVisibility','callback',...
                        'WindowStyle',          windowStyle,...
                        'DeleteFcn',            @(src,dat) deleteMain(obj),...
                        'SizeChangedFcn',       @(src,dat) sizeChangedMain(obj,src,dat));
                    if isfield(obj.state,'Position') && isfield(obj.state,'windowStyle') && ...
                            strcmp(obj.state.windowStyle,'normal') && strcmp(windowStyle,'normal')
                        obj.main.Position = obj.state.Position;
                    end
                end
            end
            %
            % add uicontrols
            obj.ui          = struct;
            % panel for controls
            obj.ui.PControl = uipanel('parent',obj.main,'Position',[0 0 1 0.1],...
                'Tag','PControl','Units','Normalized','UserData',[0 0]);
            % show button
            obj.ui.PBShow = uicontrol(obj.ui.PControl,'Units','pixel','style','pushbutton','string','Show',...
                'tag','PBShow','callback', @(src,dat) callbackMain(obj,src,dat),'UserData',[2 1],...
                'ToolTipString','Show selected video(s) in player (return key)');
            % toggle dock button
            obj.ui.PBDock = uicontrol(obj.ui.PControl,'Units','pixel','style','pushbutton','string','Toggle dock',...
                'tag','PBDock','callback', @(src,dat) callbackMain(obj,src,dat),'UserData',[2 2],...
                'ToolTipString','Dock and undock playlist figure');
            obj.ui.CLive = uicontrol(obj.ui.PControl,'Units','pixel','Style','checkbox',...
                    'String','Live','Tag','CLive','Value',obj.isLive,...
                    'Callback', @(src,dat) callbackMain(obj,src,dat),'UserData',[2 3],...
                    'ToolTipString',['In live mode the playlist shows new videos immediately in a ',...
                    'player, as well as any change of the selection']);
            % montage selection
            obj.ui.PPMontage = uicontrol(obj.ui.PControl,'Units','pixel','style','popupmenu','string',...
                {
                ' 1x horizontal' ,' 1x vertical' ...
                ' 2x horizontal' ,' 2x vertical' ...
                ' 3x horizontal' ,' 3x vertical' ...
                ' 4x horizontal' ,' 4x vertical' ...
                ' 5x horizontal' ,' 5x vertical' ...
                ' 6x horizontal' ,' 6x vertical' ...
                ' 7x horizontal' ,' 7x vertical' ...
                ' 8x horizontal' ,' 8x vertical' ...
                ' 9x horizontal' ,' 9x vertical' ...
                '10x horizontal' ,'10x vertical' ...
                },...
                'tag','PPMontage','UserData',[1 1],'Value',1,'callback', @(src,dat) callbackMain(obj,src,dat),...
                'ToolTipString','Select how to montage videos in videoplayer');
            % panel for selection
            obj.ui.PSelect = uipanel('parent',obj.main,'Position',[0 0.1 1 0.9],...
                'Tag','PSelect','Units','Normalized','UserData',[0 0],'BorderType','none');
            % selection listbox
            obj.ui.LBEnable = uicontrol(obj.ui.PSelect,'Units','normalized','style','listbox','string',obj.name,...
                'tag','LBEnable','callback', @(src,dat) callbackMain(obj,src,dat),'Units', 'normalized',...
                'KeyPressFcn', @(src,dat) callbackKeyPress(obj,src,dat),...
                'Min',1,'Max',10,'Value',find(obj.enable),'Position',[0 0 1 1], 'ToolTipString','Select video(s)');
            % allow obj.ui.LBEnablefor automatic resize and store original position
            fn = fieldnames(obj.ui);
            for i = 1:numel(fn)
                obj.ui.(fn{i}).Units = 'normalized';
            end
            % add a context menu to listbox to allow for larger font
            cm  = uicontextmenu('Parent',obj.parent);
            uimenu(cm, 'Label', 'Show', 'Callback',...
                @(src,dat) callbackMain(obj,'PBShow',dat));
            uimenu(cm, 'Label', 'Move selection to ... (next click)','Separator','on','Callback',...
                @(src,dat) callbackLBMenu(obj,'MoveSelection',src,dat));
            cm1 = uimenu(cm, 'Label', 'Set font size to','Separator','on');
            for i = 10:2:40
                uimenu(cm1, 'Label', num2str(i), 'Callback',...
                    @(src,dat) callbackLBMenu(obj,'FontSize',src,i));
            end
            if strcmp(windowStyle,'internal')
                cm1 = uimenu(cm, 'Label', 'Set split up to','Separator','on');
                for i = 50:5:95
                    uimenu(cm1, 'Label', sprintf('%d%%',i), 'Callback',...
                        @(src,dat) callbackLBMenu(obj,'SplitUp',src,i/100));
                end
            end
            obj.ui.LBEnable.UIContextMenu = cm;
            obj.ui.LBEnable.UserData.moveSelection = 0;
            % restore state
            if isfield(obj.state,'PPMontage')
                obj.ui.PPMontage.String = obj.state.PPMontage.String;
                obj.ui.PPMontage.Value  = obj.state.PPMontage.Value;
            end
            if isfield(obj.state,'LBEnable')
                obj.ui.LBEnable.FontSize = obj.state.LBEnable.FontSize;
            end
            % make visible and call resize once
            obj.main.Visible = 'on';
            sizeChangedMain(obj,obj.main);
            getFocus(obj);
        end
        
        function         callbackKeyPress(obj,hObject,hData) %#ok<INUSL>
            %callbackKeyPress Handles keys pressed in list box for video selection
            
            if ~isempty(obj.player) && ~isempty(obj.player.main) && obj.parent == obj.player.main
                % only handle up/down arrow and return key when the playlist is in the player
                % figure, the videoplayer should take care of the rest
                switch hData.Key
                    case 'return'
                        myReturn;
                    case {'uparrow' 'downarrow'}
                        myUpDownArrow;
                end
            else
                switch hData.Key
                    case 'i'
                        if numel(hData.Modifier) < 1
                            obj.player.isInfo = ~obj.player.isInfo;
                        elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                            % nothing
                        end
                    case 'p'
                        if numel(hData.Modifier) < 1
                            obj.player.isProcess = ~obj.player.isProcess;
                        elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                            play(obj.player);
                        end
                    case 'l'
                        if numel(hData.Modifier) < 1
                            obj.player.isLoop = ~obj.player.isLoop;
                        elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                            % nothing
                        end
                    case 'r'
                        if numel(hData.Modifier) < 1
                            obj.player.isReverse = ~obj.player.isReverse;
                        elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                            % nothing
                        end
                    case 's'
                        if numel(hData.Modifier) < 1
                            obj.player.isSkip = ~obj.player.isSkip;
                        elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                            % nothing
                        end
                    case 't'
                        if numel(hData.Modifier) < 1
                            obj.player.isTrack = ~obj.player.isTrack;
                        elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                            % nothing
                        end
                    case 'space'
                        if numel(hData.Modifier) < 1
                            if obj.player.isPlay, stop(obj.player); else, play(obj.player); end
                        elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                            if obj.player.isPlay, stop(obj.player); obj.player.frame = 1; else, obj.player.frame = 1; play(obj.player); end
                        end
                    case 'return'
                        myReturn;
                    case {'uparrow' 'downarrow'}
                        myUpDownArrow;
                    case 'rightarrow'
                        if numel(hData.Modifier) < 1
                            obj.player.frame = min(obj.player.frame+1,obj.player.nFrameMax);
                        elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                            obj.player.frame = min(obj.player.frame+10,obj.player.nFrameMax);
                        end
                    case 'leftarrow'
                        if numel(hData.Modifier) < 1
                            obj.player.frame = max(obj.player.frame-1,obj.player.nFrameMin);
                        elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                            obj.player.frame = max(obj.player.frame-10,obj.player.nFrameMin);
                        end
                end
            end
            
            function myReturn
                if numel(hData.Modifier) < 1
                    callbackMain(obj,'PBShow');
                elseif numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'})
                    % nothing
                end
            end
            
            function myUpDownArrow
                if strcmp(hData.Key,'uparrow'), step = -1;
                else,                           step = 1;
                end
                if numel(hData.Modifier) == 1 && ismember(hData.Modifier{1},{'alt','control','shift','command'}) && ...
                        ~isempty(obj.ui.LBEnable.Value)
                    % move selection by its own blocksize
                    step = step * (max(obj.ui.LBEnable.Value)-min(obj.ui.LBEnable.Value) + 1);
                    doUpdate = true;
                else
                    doUpdate = false;
                end
                % mark selection to be moved selection when its callback is executed next
                if ~isempty(obj.ui.LBEnable.Value)
                    idxNew = obj.ui.LBEnable.Value + step;
                    idxNew(idxNew<1 | idxNew > numel(obj.p_enable)) = [];
                    obj.p_enable         = false(size(obj.vid));
                    obj.p_enable(idxNew) = true;
                    obj.ui.LBEnable.UserData.moveSelection = 2;
                    % callback is not executed, do it manually
                    if doUpdate, callbackMain(obj,'LBEnable');end
                end
            end
        end

        function         updateMain(obj)
            %updateMain Updates main figure when properties change
            
            if ~obj.isGUI, return; end
            obj.ui.LBEnable.String = obj.p_name;
            obj.ui.LBEnable.Value  = find(obj.enable);
            obj.ui.CLive.Value     = obj.p_isLive;
        end
        
        function         getFocus(obj)
           %getFocus Makes sure the listbox is activated
           
           % if isgraphics(obj.main,'figure'),figure(obj.main); end
           if obj.isGUI, uicontrol(obj.ui.LBEnable); end
        end
        
        function         sizeChangedMain(obj,fig,data) %#ok<INUSD>
            %sizeChangedMain Adjusts GUI in case of a size change
            
            if isempty(obj.main), return; end
            %
            % settings
            pbW  = 75;
            pbH  = 25;
            spW  = 10;
            spH  = 10;
            %
            % get size of panel/figure in pixel
            bak       = fig.Units;
            fig.Units = 'pixel';
            pos       = fig.Position;
            fig.Units = bak;
            if any(pos(3:4) < 50), return; end
            %
            % resize GUI
            maxW = obj.ui.CLive.UserData(2);
            maxH = obj.ui.CLive.UserData(1);
            % reduce button size and spacing if window gets to small
            if maxW*pbW+(maxW+1)*spW > pos(3)
                ratio = spW/pbW;
                pbW   = max(1,pos(3)/((maxW*(1+ratio)+ ratio)));
                spW   = max(1,ratio * pbW);
            else
                pbW = (pos(3)-(maxW+1)*spW)/maxW;
            end
            if maxH*pbH+(maxH+1)*spH > pos(4)-100 % reserve 100 pix for the listbox
                ratio = spH/pbH;
                pbH   = max(1,(pos(4)-100)/((maxH*(1+ratio)+ ratio)));
                spH   = max(1,ratio * pbH);
            end
            useH = (maxH*pbH+(maxH+1)*spH)/pos(4); % relative size of control panel, 80 pixel normally
            fn   = fieldnames(obj.ui);            % control panel and uicontrols
            % distribute panels but keep control panel constant in height
            obj.ui.PControl.Position = [0 0 1 useH];
            obj.ui.PSelect.Position  = [0 useH 1 1-useH];
            % set uicontrols in control panel, make sliders to fill panel
            for i = 1:numel(fn)
                obj.ui.(fn{i}).Units = 'pixels';
                mypos = obj.ui.(fn{i}).UserData;
                switch fn{i}
                    case {'PControl' 'PSelect' 'LBEnable'}
                    case {'PPMontage'}
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
                case {'PBShow' 'PPMontage'}
                    % determine montage options for videoplayer
                    if obj.isGUI
                        idx   = obj.ui.PPMontage.Value;
                        str   = obj.ui.PPMontage.String;
                    elseif isfield(obj.state,'PPMontage')
                        idx   = obj.state.PPMontage.Value;
                        str   = obj.state.PPMontage.String;
                    else
                        idx = 1;
                        str = {'horizontal'};
                    end
                    nShow = sum(obj.enable);
                    if nShow < 1, return; end
                    if strcmp(str{idx},'horizontal')
                        montage = reshape(1:nShow,1,[]);
                    elseif strcmp(str{idx},'vertical')
                        montage = reshape(1:nShow,[],1);
                    else
                        n = str2double(str{idx}(1:2));
                        if ~(nShow > n && mod(nShow,n) == 0), n = 1; end
                        montage = reshape(1:nShow,[],n);
                        if ~isempty(strfind(str{idx},'horizontal'))
                            montage = montage';
                        end
                    end
                    %
                    % get options of current player, add new montage option and adjust options that
                    % depend on the number of videos and show videos
                    if isempty(obj.player) || ~isvalid(obj.player)
                        cleanMyVideo(obj);
                        tmp = play(obj.vid(obj.enable),'montage',montage);
                        if ~isempty(tmp), obj.player = tmp; end
                    else
                        myopt             = obj.player.opt;
                        myopt.montage     = montage;
                        myopt.idxChannels = [];
                        myopt.idxFrames   = [];
                        fn                = fieldnames(myopt);
                        for k = 1:numel(fn)
                            if iscell(myopt.(fn{k})) && numel(myopt.(fn{k})) ~= nShow
                                if numel(myopt.(fn{k})) < nShow
                                    myopt.(fn{k}) = myopt.(fn{k}){1};
                                else
                                    myopt.(fn{k}) = myopt.(fn{k})(1:nShow);
                                end
                            end
                        end
                        cleanMyVideo(obj);
                        obj.player.show(obj.vid(obj.enable),myopt);
                        % get focus back to own GUI
                        % getFocus(obj);
                    end
                case 'PBDock'
                    % make sure the player is available
                    if isempty(obj.player) || ~isvalid(obj.player)
                        callbackMain(obj,'PBShow');
                    end
                    if isempty(obj.player) || ~isvalid(obj.player)
                        error(sprintf('%s:Input',mfilename),'Could not get the player object, please delete all player objects and try again');
                    end
                    % if a master is availabel (i.e. playlist is the slave):
                    % slave -> internal -> docked -> normal -> slave
                    % otherwise:
                    % internal -> docked -> normal -> internal
                    if isgraphics(obj.main,'figure') && strcmp(obj.main.WindowStyle,'normal') % normal mode
                        % create internal playlist
                        deleteMain(obj);
                        if obj.isMaster
                            createMain(obj,'internal');
                        else
                            createMain(obj,'slave');
                        end
                    elseif isgraphics(obj.main,'figure') && strcmp(obj.main.WindowStyle,'docked') % docked mode
                        % undock matlab figure
                        obj.main.WindowStyle = 'normal';
                    elseif obj.main.Parent == obj.player.main %internal mode
                        % create docked figure
                        deleteMain(obj);
                        createMain(obj,'docked');
                    elseif ~obj.isMaster % slave mode
                        % create internal playlist
                        deleteMain(obj);
                        createMain(obj,'internal');
                    end
                case 'LBEnable'
                    if hObject.UserData.moveSelection == 2
                        hObject.UserData.moveSelection = 0;
                        hObject.Value = find(obj.p_enable);
                        if obj.isLive, callbackMain(obj,'PBShow'); end
                    elseif hObject.UserData.moveSelection == 1
                        hObject.UserData.moveSelection = 0;
                        if isempty(hObject.Value)
                            hObject.Value = find(obj.p_enable);
                        else
                            idxNew = hObject.Value(1);
                            idxOld = find(obj.p_enable);
                            idxNew = idxOld - min(idxOld)+idxNew;
                            idxNew(idxNew<1 | idxNew > numel(obj.p_enable)) = [];
                            obj.p_enable         = false(size(obj.vid));
                            obj.p_enable(idxNew) = true;
                            hObject.Value        = find(obj.p_enable);
                        end
                        if obj.isLive, callbackMain(obj,'PBShow'); end
                    else
                        obj.p_enable = false(size(obj.vid));
                        if ~isempty(hObject.Value)
                            obj.p_enable(hObject.Value) = true;
                        end
                        fig = gcbf;
                        if strcmp(fig.SelectionType,'open') || obj.isLive
                            callbackMain(obj,'PBShow'); 
                        end
                    end
                    getFocus(obj);
                case 'CLive'
                    obj.p_isLive = logical(obj.ui.CLive.Value);
            end
        end
        
        function         deleteMain(obj)
            %deleteMain Deletes main figure
            
            if isgraphics(obj.main,'uipanel')
                if obj.isMaster
                    obj.state.WindowStyle = 'internal';
                    if ~isempty(obj.player) && isvalid(obj.player) && obj.player.isGUI
                        obj.state.splitup = obj.player.mainPanel.Position(3);
                        obj.player.mainPanel.Position = [0 0 1 1];
                    end
                else
                    obj.state.WindowStyle = 'slave';
                end
            else
                obj.state.WindowStyle = obj.main.WindowStyle;
            end
            obj.state.Position          = obj.main.Position;
            obj.state.PPMontage.String  = obj.ui.PPMontage.String;
            obj.state.PPMontage.Value   = obj.ui.PPMontage.Value;
            obj.state.LBEnable.FontSize = obj.ui.LBEnable.FontSize;
            delete(obj.main);
            obj.main = [];
        end
        
        function         callbackLBMenu(obj,type,src,dat) %#ok<INUSL>
            %callbackMainMenu Handles callbacks from context menu
            
            switch type
                case 'FontSize'
                    obj.ui.LBEnable.FontSize = dat;
                case 'MoveSelection'
                    obj.ui.LBEnable.UserData.moveSelection = 1;
                case 'SplitUp'
                    obj.splitup = dat;
            end
        end
        
        function         cleanMyVideo(obj,relinkPlayer)
           %cleanMyVideo Removes player string from videos if it is the player of this object and
           % videos are not any more shown in the player
           
           if nargin < 2 || isempty(relinkPlayer), relinkPlayer = true; end
           if isempty(obj.player) || ~isvalid(obj.player), return; end
           for k = 1:numel(obj.vid)
               if ~isempty(obj.vid(k).player) && obj.vid(k).player == obj.player
                   obj.vid(k).player = [];
               end
           end
           if relinkPlayer
               for k = 1:numel(obj.player.vid)
                   obj.player.vid(k).player = obj.player;
               end
           end
        end
    end
end
