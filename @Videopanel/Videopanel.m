classdef Videopanel < hgsetget
    %Videopanel Class to show a horizontal montage of a video matrix (4D matrix)
    %
    % Implementation Notes: 
    %
    %----------------------------------------------------------------------------------
    %   Copyright 2016 Alexander Ludwig Klein, alexludwigklein@gmail.com
    %
    %   Physics of Fluids, University of Twente
    %----------------------------------------------------------------------------------
    
    %% Properties
    properties (GetAccess = public, SetAccess = public)
        % dp Spacing and length of GUI elements in pixels
        %    [spacing of uicontrols, height of uicontrols, length of uicontrols]
        dp = [5 20 125];
        % parent Handle of parent figure or uipanel
        parent = [];
        % position Position of uipanel holding all other uicontrols, etc.
        position = [70 50 800 400];
        % textPosition Text relative position in images when overlaying text on images
        textPosition = [0.05 0.05];
        % textColor Text color when overlaying text on images
        textColor = 'black';
        % textBackgroundColor Text background color when overlaying text on images
        textBackgroundColor = 'white';
        % label Label for each image
        label = {};
        % image Callback that returns new images or images itself
        data = [];
        % index Callback that is executed after a frame is selected
        index = [];
        % rescale Factor used to rescale images before displaying in movie panel
        rescale = 1;
        % name Name of movie panel
        name = '';
        % idxFrame Indices of selected Frames
        idxFrame = [];
        % showZoom True/false whether to show zoom uicontrols
        showZoom = true;
        % showRescale True/false whether to show rescale uicontrol
        showRescale = true;
        % showLabel True/false whether to show label uicontrol
        showLabel = true;
        % showPlay True/false whether to show play uicontrol
        showPlay = true;
        % showSelect True/false whether to show select uicontrol(s)
        showSelect = true;
    end
    
    properties (Dependent = true, GetAccess = public, SetAccess = public)
        % visible Visibility of main uipanel
        visible = 'on'
    end
    
    properties (GetAccess = public, SetAccess = private)
        % panel Handle to uipanel
        panel
        % axes Handle to axes
        axes = [];
        % api Handle to api of imscrollpanel
        api = [];
        % image Handle to image
        image = [];
        % sizeData Size of data
        sizeData = [0 0 0 0];
    end
    
    properties (GetAccess = private, SetAccess = private)
        % handles Handles for some uicontrols and temporary data
        handles
    end
    
    %% Methods
    methods
        function obj = Videopanel(parent,varargin)
            if nargin > 0
                obj.parent = parent;
            end
            if numel(varargin) > 0
                set(obj,varargin{:});
            end
            if nargin > 0
                obj.create;
            end
        end
        
        function delete(obj)
            if ~isempty(obj.panel) && ishandle(obj.panel)
                delete(obj.panel);
            end
        end
        
        function set.idxFrame(obj,value)
            if isnumeric(value)
                obj.idxFrame = value;
                if ~isempty(obj.panel) && ishandle(obj.panel) %#ok<MCSUP>
                    obj.updateLabel('idxFrame');
                end
            else
                error(sprintf('alexludwigklein:%s',mfilename),...
                    'Invalid value for idxFrame. Please check!');
            end
        end
        
        function set.showRescale(obj,value)
            if islogical(value) && isscalar(value)
                obj.showRescale = value;
                if ~isempty(obj.panel) && ishandle(obj.panel) %#ok<MCSUP>
                    obj.updateUIControls;
                    obj.forceResize;
                end
            else
                error(sprintf('alexludwigklein:%s',mfilename),...
                    'Invalid value for showRescale. Please check!');
            end
        end
        
        function set.showZoom(obj,value)
            if islogical(value) && isscalar(value)
                obj.showZoom = value;
                if ~isempty(obj.panel) && ishandle(obj.panel) %#ok<MCSUP>
                    obj.updateUIControls;
                    obj.forceResize;
                end
            else
                error(sprintf('alexludwigklein:%s',mfilename),...
                    'Invalid value for showZoom. Please check!');
            end
        end
        
        function set.showPlay(obj,value)
            if islogical(value) && isscalar(value)
                obj.showPlay = value;
                if ~isempty(obj.panel) && ishandle(obj.panel) %#ok<MCSUP>
                    obj.updateUIControls;
                    obj.forceResize;
                end
            else
                error(sprintf('alexludwigklein:%s',mfilename),...
                    'Invalid value for showPlay. Please check!');
            end
        end
        
        function set.showLabel(obj,value)
            if islogical(value) && isscalar(value)
                obj.showLabel = value;
                if ~isempty(obj.panel) && ishandle(obj.panel) %#ok<MCSUP>
                    obj.updateUIControls;
                    obj.forceResize;
                end
            else
                error(sprintf('alexludwigklein:%s',mfilename),...
                    'Invalid value for showLabel. Please check!');
            end
        end
        
        function set.showSelect(obj,value)
            if islogical(value) && isscalar(value)
                obj.showSelect = value;
                if ~isempty(obj.panel) && ishandle(obj.panel) %#ok<MCSUP>
                    obj.updateUIControls;
                end
            else
                error(sprintf('alexludwigklein:%s',mfilename),...
                    'Invalid value for showSelect. Please check!');
            end
        end
        
        function set.visible(obj,value)
            if ~isempty(obj.panel) && ishandle(obj.panel)
                set(obj.panel,'Visible',value);
            end
        end
        
        function value = get.visible(obj)
            if ~isempty(obj.panel) && ishandle(obj.panel)
                value = get(obj.panel,'Visible');
            else
                value = 'off';
            end
        end
        
        function set.data(obj,value)
            if isnumeric(value) || islogical(value) || (isa(value,'function_handle') && abs(nargin(value)) == 0)
                obj.data = value;
                obj.updateImage;
            else
                error(sprintf('alexludwigklein:%s',mfilename),...
                    'Invalid value for data. Please check!');
            end
        end
        
        function set.index(obj,value)
            if isa(value,'function_handle') && abs(nargin(value)) == 1
                obj.index = value;
            else
                error(sprintf('alexludwigklein:%s',mfilename),...
                    'Invalid value for index. Please check!');
            end
        end
        
        function set.name(obj,value)
            if ischar(value)
                obj.name = value;
                if ~isempty(obj.panel) && ishandle(obj.panel) %#ok<MCSUP>
                    set(obj.panel,'Title',obj.name); %#ok<MCSUP>
                end
            else
                error(sprintf('alexludwigklein:%s',mfilename),...
                    'Invalid value for name. Please check!');
            end
        end
        
        function set.label(obj,value)
            if ischar(value)
                value = Videopanel.ensureCell(value);
            end
            if iscellstr(value) || (isa(value,'function_handle') && abs(nargin(value)) == 0)
                obj.label = value;
                obj.updateLabel('label');
            else
                error(sprintf('alexludwigklein:%s',mfilename),...
                    'Invalid value for label. Please check!');
            end
        end
        
        function set.parent(obj,value)
            if isa(value,'matlab.ui.Figure') || (isnumeric(value) && isscalar(value) && ishandle(value) && ...
                    (strcmpi(get(value,'Type'),'figure') || strcmpi(get(value,'Type'),'uipanel')))
                if ~isempty(obj.panel) && ishandle(obj.panel) %#ok<MCSUP>
                    error(sprintf('alexludwigklein:%s',mfilename),...
                        'Resetting parent for an existing movie panel is *NOT* allowed. Please check!');
                else
                    obj.parent = value;
                end
            else
                error(sprintf('alexludwigklein:%s',mfilename),...
                    'Invalid value for parent. Please check!');
            end
        end
        
        function set.textPosition(obj,value)
            if isnumeric(value) && isvector(value) && numel(value) == 2 && all(value >= 0) &&...
                    all(value <= 1)
                obj.textPosition = value;
                obj.updateLabel;
            else
                error(sprintf('alexludwigklein:%s',mfilename),...
                    'Invalid value for textPosition. Please check!');
            end
        end
        
        function set.textColor(obj,value)
            if (isnumeric(value) && isvector(value) && numel(value) == 3 && all(value >= 0) &&...
                    all(value <= 1)) || ischar(value)
                obj.textColor = value;
                obj.updateLabel;
            else
                error(sprintf('alexludwigklein:%s',mfilename),...
                    'Invalid value for textColor. Please check!');
            end
        end
        
        function set.textBackgroundColor(obj,value)
            if (isnumeric(value) && isvector(value) && numel(value) == 3 && all(value >= 0) &&...
                    all(value <= 1)) || ischar(value)
                obj.textBackgroundColor = value;
                obj.updateLabel;
            else
                error(sprintf('alexludwigklein:%s',mfilename),...
                    'Invalid value for textBackgroundColor. Please check!');
            end
        end
        
        function set.position(obj,value)
            if isnumeric(value) && isvector(value) && numel(value) == 4 && all(value > 0)
                obj.position = value;
                if ~isempty(obj.panel) && ishandle(obj.panel) %#ok<MCSUP>
                    pos = get(obj.panel,'Position'); %#ok<MCSUP>
                    if ~isequal(obj.position,pos)
                        set(obj.panel,'Position',obj.position); %#ok<MCSUP>
                    end
                end
            else
                error(sprintf('alexludwigklein:%s',mfilename),...
                    'Invalid value for position. Please check!');
            end
        end
        
        function set.dp(obj,value)
            if isnumeric(value) && isvector(value) && numel(value) == 3 && all(value > 0)
                obj.dp = value;
                if ~isempty(obj.panel) && ishandle(obj.panel) %#ok<MCSUP>
                    % force resize
                    tmp = get(obj.panel,'Position'); %#ok<MCSUP>
                    set(obj.panel,'Position',tmp-1); %#ok<MCSUP>
                    obj.position = tmp; %#ok<MCSUP>
                end
            else
                error(sprintf('alexludwigklein:%s',mfilename),...
                    'Invalid value for dp. Please check!');
            end
        end
        
        function set.rescale(obj,value)
            if isnumeric(value) && isscalar(value) && value > 0 && value < 10
                obj.rescale = value;
                if ~isempty(obj.panel) && ishandle(obj.panel) %#ok<MCSUP>
                    obj.updateImage;
                    obj.updateLabel;
                    set(obj.handles.rescale,'String',sprintf('%7.4f%%',obj.rescale*100)); %#ok<MCSUP>
                end
            else
                error(sprintf('alexludwigklein:%s',mfilename),...
                    'Invalid value for rescale. Please check!');
            end
        end
        
        function obj = create(obj)
            % create Creates panel with imscrollpanel, etc.
            
            % some settings
            dxP = obj.dp(1);
            dxB = obj.dp(3);
            % prepare image and create uicontrols, etc.
            [img, obj.sizeData]  = obj.rescaleImgDisplay(obj.data(),obj.rescale);
            obj.panel = uipanel('Parent',obj.parent,'Units','Pixel','Position',obj.position,...
                'Title',obj.name,'ResizeFcn',@obj.resize);
            obj.axes  = axes('Parent',obj.panel,'Position',[0 0 1 1],'XTick',[],'YTick',[],'ZTick',[]); %#ok<CPROP>
            obj.image = imshow(img,'InitialMagnification',100,'Parent',obj.axes);
            obj.handles.hSP = imscrollpanel(obj.panel,obj.image);
            set(obj.handles.hSP,'Units','Pixel');
            curPos    = get(obj.handles.hSP,'Position');
            curPos(3) = curPos(3)-2*dxP-dxB;
            set(obj.handles.hSP,'Position',curPos);
            obj.api   = iptgetapi(obj.handles.hSP);
            if obj.sizeData(1) > 1
                mag = (obj.position(4)-6*dxP)/obj.sizeData(1);
            else
                mag = 1;
            end
            obj.api.setMagnification(mag);
            % uicontrols
            obj.handles.play = uicontrol(obj.panel,'Style','pushbutton','String','P',...
                'Tag','PlayGUI','TooltipString','Open movie at full scale with implay',...
                'Userdata',[1 1 1 1],'Callback',@obj.callback);
            obj.handles.label = uicontrol(obj.panel,'Style','pushbutton','String','L',...
                'Tag','ToggleLabel','TooltipString','Turn on/off frame label',...
                'Userdata',[1 2 1 1],'Callback',@obj.callback);
            obj.handles.zoomReset = uicontrol(obj.panel,'Style','pushbutton','String','R',...
                'Tag','ZoomReset','TooltipString','Reset zoom to fit height of frame(s)',...
                'Userdata',[1 3 1 1],'Callback',@obj.callback);
            obj.handles.zoomIn = uicontrol(obj.panel,'Style','pushbutton','String','+',...
                'Tag','ZoomIn','TooltipString','Zoom in',...
                'Userdata',[1 4 1 1],'Callback',@obj.callback);
            obj.handles.zoomOut = uicontrol(obj.panel,'Style','pushbutton','String','-',...
                'Tag','ZoomOut','TooltipString','Zoom out',...
                'Userdata',[1 5 1 1],'Callback',@obj.callback);
            obj.handles.zoomBox = immagbox(obj.panel,obj.image);
            set(obj.handles.zoomBox,'Units','Pixels','Userdata',[1 6 1 1],...
                'TooltipString','Enter magnification of image','Tag','ZoomBox');
            tmp = uicontrol(obj.panel,'Style','pushbutton');
            set(obj.handles.zoomBox,'BackgroundColor',get(tmp,'BackgroundColor'));
            delete(tmp);
            obj.handles.rescale = uicontrol(obj.panel,'Style','edit','Tag','EditRescale',...
                'String',sprintf('%7.4f%%',obj.rescale*100), 'TooltipString','Scaling of image',...
                'Userdata',[1 7 1 1],'Callback',@obj.callback);
            % obj.handles.selectSingle = uicontrol(obj.panel,'Style','pushbutton','String','S-S',...
            %     'Tag','SelectSingle','TooltipString','Select single frame',... 'Userdata',[2 2 1
            %     1],'Callback',@obj.callback);
            obj.handles.selectMultiple = uicontrol(obj.panel,'Style','pushbutton','String','S',...
                'Tag','SelectMultiple','TooltipString','Select frame(s) by clicking, end with double click or Enter key',...
                'Userdata',[2 4 1 1],'Callback',@obj.callback);
            % obj.handles.unselectSingle =
            % uicontrol(obj.panel,'Style','pushbutton','String','U-S',...
            %     'Tag','UnselectSingle','TooltipString','Unselect single frame',... 'Userdata',[2 1
            %     1 1],'Callback',@obj.callback);
            obj.handles.unselectMultiple = uicontrol(obj.panel,'Style','pushbutton','String','U',...
                'Tag','UnselectMultiple','TooltipString','Unselect frame(s) by clicking, end with double click or Enter key',...
                'Userdata',[2 3 1 1],'Callback',@obj.callback);
            obj.handles.unselectAll = uicontrol(obj.panel,'Style','pushbutton','String','None',...
                'Tag','UnselectAll','TooltipString','Unselect all frames',...
                'Userdata',[2 5 1 1],'Callback',@obj.callback);
            obj.handles.selectAll = uicontrol(obj.panel,'Style','pushbutton','String','All',...
                'Tag','SelectAll','TooltipString','Select all frames',...
                'Userdata',[2 6 1 1],'Callback',@obj.callback);
            % initialize for later use
            obj.handles.idNewMagnificationCallback = [];
            obj.handles.idNewLocationCallback      = [];
            obj.handles.idLinkedPanels             = [];
            obj.handles.label                      = [];
            obj.handles.idxFrame                   = [];
            obj.handles.impointrun                 = false;
            % update panel
            obj.updateUIControls;
            obj.updateLabel;
            % force resize
            obj.forceResize;
        end
        
        function obj = unlink(obj)
            % unlink Unlinks movie panels for synchron zoom and movement
            
            % remove old callbacks
            for i = 1:numel(obj)
                if isempty(obj(i).panel) || ~ishandle(obj(i).panel)
                    error(sprintf('alexludwigklein:%s',mfilename),...
                        'Create movie panels before linking. Please check!');
                end
                if ~isempty(obj(i).handles.idNewMagnificationCallback)
                    obj(i).api.removeNewMagnificationCallback(obj(i).handles.idNewMagnificationCallback);
                end
                if ~isempty(obj(i).handles.idNewLocationCallback)
                    obj(i).api.removeNewLocationCallback(obj(i).handles.idNewLocationCallback);
                end
                obj(i).handles.idNewMagnificationCallback = [];
                obj(i).handles.idNewLocationCallback      = [];
                obj(i).handles.idLinkedPanels             = [];
            end
        end
        
        function obj = link(obj)
            % link (Un)links movie panels for synchron zoom and movement
            
            if numel(obj) < 2
                return
            end
            % unlink and relink
            obj.unlink;
            
            for i = 1:numel(obj)
                obj(i).handles.idNewMagnificationCallback = ...
                    obj(i).api.addNewMagnificationCallback(@(x) obj(i).sync(x));
                obj(i).handles.idNewLocationCallback      = ...
                    obj(i).api.addNewLocationCallback(@(x) obj(i).sync(x));
                obj(i).handles.idLinkedPanels = obj(setdiff(1:numel(obj),i));
            end
            % perform link for first object
            obj(1).sync(1);
            obj(1).sync([1 1]);
        end
        
        function obj = update(obj)
            % update Updates movie panels
            
            obj.updateImage;
            obj.updateLabel;
        end
        
        function obj = updateImage(obj)
            % update Updates panel
            
            if numel(obj) > 1
                for i = 1:numel(obj)
                    obj(i).updateImage;
                end
                return
            end
            if isempty(obj.panel) || ~ishandle(obj.panel)
                return
            end
            % update image
            [img, obj.sizeData]  = obj.rescaleImgDisplay(obj.data(),obj.rescale);
            obj.api.replaceImage(img,'PreserveView',true);
        end
        
        function obj = updateLabel(obj,taskList)
            % updateLabel Overlays text on scrollpanel
            
            if nargin < 2
                taskList = {'all'};
            end
            if numel(obj) > 1
                for i = 1:numel(obj)
                    obj(i).updateLabel(taskList);
                end
                return
            end
            if isempty(obj.panel) || ~ishandle(obj.panel)
                return
            end
            if any(ismember({'all','label'},taskList))
                % remove old text and create new ones afterwards
                h = obj.handles.label(ishandle(obj.handles.label));
                if ~isempty(h)
                    strFlag = get(h(1),'Visible');
                else
                    strFlag = 'on';
                end
                delete(h);
                obj.handles.label    = NaN(1,obj.sizeData(4));
                strLabel             = Videopanel.ensureCell(obj.label());
                if numel(strLabel) < obj.sizeData(4)
                    strLabel(end+1:obj.sizeData(4)) = {''};
                end
                posLabel    = [((0:obj.sizeData(4)-1)' + obj.textPosition(2)).* obj.sizeData(2) ...
                    ones(obj.sizeData(4),1).*obj.sizeData(1).*obj.textPosition(1)];
                for k = 1:obj.sizeData(4)
                    obj.handles.label(k) = text('Parent',obj.axes,'String',strLabel{k},'Units','Data',...
                        'Position', posLabel(k,:),'Color',obj.textColor,'Visible',strFlag,'BackgroundColor',...
                        obj.textBackgroundColor,'HorizontalAlignment','left','VerticalAlignment','top');
                end
            end
            if any(ismember({'all','idxFrame'},taskList))
                % remove old text if necessary
                posSelected = [((0:obj.sizeData(4)-1)' + 0.5).* obj.sizeData(2) ...
                    ones(obj.sizeData(4),1).*obj.sizeData(1).*0.5];
                if any(~ishandle(obj.handles.idxFrame)) || ...
                        numel(obj.handles.idxFrame) ~= obj.sizeData(4) || ...
                        (numel(obj.handles.idxFrame) > 1 &&...
                        ~isequal(get(obj.handles.idxFrame(2),'Position'),[posSelected(2,:) 0]))
                    delete(obj.handles.idxFrame(ishandle(obj.handles.idxFrame)));
                    obj.handles.idxFrame = NaN(1,obj.sizeData(4));
                    for k = 1:obj.sizeData(4)
                        if ismember(k,obj.idxFrame);
                            strFlag = 'on';
                        else
                            strFlag = 'off';
                        end
                        obj.handles.idxFrame(k) = text('Parent',obj.axes,'String','Selected','Units','Data',...
                            'Position', posSelected(k,:),'Color','red','BackgroundColor','black',...
                            'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','middle',...
                            'Rotation',45,'Visible',strFlag);
                    end
                else
                    set(obj.handles.idxFrame(obj.idxFrame),'Visible','on');
                    idx = setdiff(1:numel(obj.handles.idxFrame),obj.idxFrame);
                    set(obj.handles.idxFrame(idx),'Visible','off');
                end
            end
        end
    end
    
    methods (Access = private)
        function sync(obj,newVal)
            % sync Synchronizes given movie panels to its linked movies panels
            
            if numel(obj) > 1
                for i = 1:numel(obj)
                    obj(i).sync;
                end
                return
            end
            if isempty(obj.panel) || ~ishandle(obj.panel) || numel(obj.handles.idLinkedPanels) < 1
                return
            end
            % update position and magnification of linked movie panel to be equal to given object
            visRect    = obj.api.getVisibleImageRect();
            imgSize    = obj.sizeData;
            visRectRel = visRect ./ [imgSize(2)*imgSize(4) imgSize(1) imgSize(2)*imgSize(4) imgSize(1)];
            for i = 1:numel(obj.handles.idLinkedPanels)
                imgSizeCur = obj.handles.idLinkedPanels(i).sizeData;
                visRectTar = visRectRel .* [imgSizeCur(2)*imgSizeCur(4) imgSizeCur(1) imgSizeCur(2)*imgSizeCur(4) imgSizeCur(1)];
                pos        = get(obj.handles.hSP,'Position');
                magTar     = pos(3)/visRectTar(3);
                if numel(newVal) < 2
                    obj.handles.idLinkedPanels(i).api.setMagnification(magTar);
                else
                    obj.handles.idLinkedPanels(i).api.setVisibleLocation(visRectTar(1:2));
                end
            end
        end
        
        function obj = forceResize(obj)
            % forceResize Forces resize of GUI to reorder uicontrols, etc.
            
            if isempty(obj.panel) || ~ishandle(obj.panel)
                return
            end
            tmp = get(obj.panel,'Position');
            set(obj.panel,'Position',tmp-1);
            obj.position = tmp;
        end
        
        function obj = updateUIControls(obj)
            % updateUIControls Disables/Enables uicontrols
            
            if isempty(obj.panel) || ~ishandle(obj.panel)
                return
            end
            if obj.showPlay
                set(obj.handles.play,'Visible','on','Enable','on');
            else
                set(obj.handles.play,'Visible','off','Enable','off');
            end
            if obj.showLabel
                set(obj.handles.label,'Visible','on','Enable','on');
            else
                set(obj.handles.label,'Visible','off','Enable','off');
            end
            if obj.showZoom
                set([obj.handles.zoomReset obj.handles.zoomIn obj.handles.zoomOut obj.handles.zoomBox],...
                    'Visible','on','Enable','on');
            else
                set([obj.handles.zoomReset obj.handles.zoomIn obj.handles.zoomOut obj.handles.zoomBox],...
                    'Visible','off','Enable','off');
            end
            if obj.showRescale
                set(obj.handles.rescale,'Visible','on','Enable','on');
            else
                set(obj.handles.rescale,'Visible','off','Enable','off');
            end
            if obj.showSelect
                % set([obj.handles.selectSingle obj.handles.selectMultiple
                % obj.handles.unselectSingle ...
                %     obj.handles.unselectMultiple obj.handles.unselectAll
                %     obj.handles.selectAll],'Visible','on','Enable','on');
                set([obj.handles.selectMultiple obj.handles.unselectMultiple obj.handles.unselectAll...
                    obj.handles.selectAll],'Visible','on','Enable','on');
            else
                % set([obj.handles.selectSingle obj.handles.selectMultiple
                % obj.handles.unselectSingle ...
                %     obj.handles.unselectMultiple obj.handles.unselectAll
                %     obj.handles.selectAll],'Visible','off','Enable','off');
                set([obj.handles.selectMultiple obj.handles.unselectMultiple obj.handles.unselectAll...
                    obj.handles.selectAll],'Visible','off','Enable','off');
            end
        end
        
        function resize(obj,src,event) %#ok<INUSD>
            % resize Resizes uipanel
            
            if isempty(obj.panel) || ~ishandle(obj.panel) || isempty(obj.handles)
                return
            end
            dxP          = obj.dp(1);
            dyB          = obj.dp(2);
            dxB          = obj.dp(3);
            posP         = get(obj.panel,'Position');
            obj.position = posP;
            if posP(3) < dxB*2 || posP(4) < dyB*7
                return
            end
            % set scrollpanel
            if obj.showSelect
                posSP    = [dxP dxP posP(3)-dxP*4-2*dxB posP(4)-dxP*5];
                nColumns = 2;
            else
                posSP    = [dxP dxP posP(3)-dxP*3-dxB posP(4)-dxP*5];
                nColumns = 1;
            end
            set(obj.handles.hSP,'Position',posSP);
            % set buttons, etc.
            hAll    = [findall(obj.panel,'Type','uicontrol','Style','pushbutton','Enable','on');
                findall(obj.panel,'Type','uicontrol','Style','edit','Enable','on')];
            pos     = Videopanel.ensureCell(get(hAll,'Userdata'));
            [~,idx] = sort(cellfun(@(x) x(2),pos));
            pos     = pos(idx);
            hAll    = hAll(idx);
            row     = cellfun(@(x) x(1),pos);
            for i = 1:nColumns
                idxRow = find(row == i);
                nRow   = numel(idxRow);
                dyB    = (posSP(4)-(nRow-1)*dxP)/nRow;
                for k = 1:nRow
                    curPos = [posSP(1)+posSP(3)+dxP*i+dxB*(i-1) posSP(2)+(dxP+dyB)*(k-1) dxB dyB];
                    set(hAll(idxRow(k)),'Position', curPos);
                end
            end
        end
        
        function callback(obj,src,event) %#ok<INUSD>
            % callback Callbacks for uicontrols
            
            if obj.handles.impointrun
                errordlg('Please, finish selecting frames before doing something else.','Error','modal');
                return
            end
            h   = gcbo;
            tag = get(h,'Tag');
            switch tag
                case 'PlayGUI'
                    implay(obj.data());
                case 'ZoomIn'
                    obj.api.setMagnification(obj.api.getMagnification()*1.2);
                case 'ZoomOut'
                    obj.api.setMagnification(obj.api.getMagnification()/1.2);
                case 'ZoomReset'
                    if obj.sizeData(1) > 1
                        mag = (obj.position(4)-7.5*obj.dp(1))/obj.sizeData(1);
                    else
                        mag = 1;
                    end
                    obj.api.setMagnification(mag);
                case 'ToggleLabel'
                    strFlag = get(obj.handles.label(1), 'Visible');
                    if strcmpi(strFlag, 'on')
                        strFlag = 'off';
                    else
                        strFlag = 'on';
                    end
                    set(obj.handles.label, 'Visible', strFlag);
                case 'EditRescale'
                    val = str2double(get(h,'String'));
                    if ~isnan(val) && isnumeric(val)
                        if val >= 1 && val <= 200
                            obj.rescale = val/100;
                        else
                            set(h,'String',sprintf('%7.4f%%',obj.rescale*100));
                        end
                    else
                        set(h,'String',sprintf('%7.4f%%',obj.rescale*100));
                    end
                case 'SelectSingle'
                    if ~isempty(obj.index)
                        hPoint = impoint(obj.axes);
                        pos    = getPosition(hPoint);
                        delete(hPoint);
                        idx = ceil(pos(1)/obj.sizeData(2));
                        obj.idxFrame = union(obj.idxFrame,idx);
                        obj.index(obj.idxFrame);
                        obj.updateLabel('idxFrame');
                    end
                case 'SelectMultiple'
                    if ~isempty(obj.index) && numel(obj.idxFrame) < obj.sizeData(4)
                        obj.handles.impointrun = true;
                        [x, y]  = getpts(obj.axes);
                        idxFlag = y > 0 & y < obj.sizeData(2);
                        x       = x(idxFlag);
                        idx = ceil(x./obj.sizeData(2));
                        obj.idxFrame = union(obj.idxFrame,idx);
                        obj.index(obj.idxFrame);
                        obj.updateLabel('idxFrame');
                        obj.handles.impointrun = false;
                    end
                case 'UnselectSingle'
                    if ~isempty(obj.index)
                        hPoint = impoint(obj.axes);
                        pos    = getPosition(hPoint);
                        delete(hPoint);
                        idx = ceil(pos(1)/obj.sizeData(2));
                        obj.idxFrame = setdiff(obj.idxFrame,idx);
                        obj.index(obj.idxFrame);
                        obj.updateLabel('idxFrame');
                    end
                case 'UnselectMultiple'
                    if ~isempty(obj.index) && ~isempty(obj.idxFrame)
                        obj.handles.impointrun = true;
                        [x, y]  = getpts(obj.axes);
                        idxFlag = y > 0 & y < obj.sizeData(2);
                        x       = x(idxFlag);
                        idx = ceil(x./obj.sizeData(2));
                        obj.idxFrame = setdiff(obj.idxFrame,idx);
                        obj.index(obj.idxFrame);
                        obj.updateLabel('idxFrame');
                        obj.handles.impointrun = false;
                    end
                case 'SelectAll'
                    obj.idxFrame = 1:obj.sizeData(4);
                    obj.index(obj.idxFrame);
                    obj.updateLabel('idxFrame');
                case 'UnselectAll'
                    obj.idxFrame = [];
                    obj.index(obj.idxFrame);
                    obj.updateLabel('idxFrame');
                otherwise
                    error(sprintf('alexludwigklein:%s',mfilename),...
                        'Unknown tag for GUI button. Please check!');
            end
        end
    end
    
    methods (Static = true, Access = public)
        function out = ensureCell(out)
            % ensureCell Put input in a cell if it is not a cell
            
            if ~iscell(out)
                out = {out};
            end
        end
        
        function [out, siz] = rescaleImgDisplay(img,rescaleFactor)
            % rescaleImgDisplay Prepares image to be shown in imscrollpanel
            %   Performs rescaling and reshaping to get a horizontal montage of the given image(s),
            %   siz is the size of a single rescaled image, the fourth entry is the number of frames
            
            if isempty(img)
                out = [];
                siz = [0 0 0 0];
                return
            end
            siz = size(img);
            if numel(siz) < 3, siz(3) = 1; end
            if numel(siz) < 4, siz(4) = 1; end
            if abs(rescaleFactor-1) > eps
                if siz(4) > 1
                    % Note: to avoid the for loop imresize is called with an 4D input, which is not
                    % documented in help, but seems to work (tested with examles), old code: tmp =
                    % imresize(img(:,:,:,1),rescaleFactor); siz(1) = size(tmp,1); siz(2) =
                    % size(tmp,2); out = repmat(tmp,[1,siz(4),1]); for i = 2:siz(4)
                    %     out(:,((i-1)*siz(2)+1):(i*siz(2)),:) = ...
                    %         imresize(img(:,:,:,i),rescaleFactor);
                    % end new code:
                    tmp    = imresize(img,rescaleFactor);
                    siz(1) = size(tmp,1);
                    siz(2) = size(tmp,2);
                    idx    = 1:siz(3):siz(3)*siz(4);
                    if siz(3) > 1,idx = [idx idx+1 idx+2];end
                    out    = reshape(tmp(:,:,idx),siz(1),[],siz(3));
                else
                    out    = imresize(img,rescaleFactor);
                    siz(1) = size(out,1);
                    siz(2) = size(out,2);
                end
            else
                if size(img,4) > 1
                    out = reshape(permute(img,[1 2 4 3]), siz(1), [], siz(3));
                else
                    out = img;
                end
            end
        end
    end
end

