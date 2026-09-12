controladdin "SAL Freight Monitor Workspace"
{
    MinimumHeight = 720;
    RequestedHeight = 900;
    MinimumWidth = 320;
    RequestedWidth = 1920;
    HorizontalStretch = true;
    HorizontalShrink = true;
    VerticalStretch = true;
    VerticalShrink = true;

    Scripts = 'ControlAddIn/Freight/freight-monitor.js';
    StartupScript = 'ControlAddIn/Freight/startup.js';
    RecreateScript = 'ControlAddIn/Freight/startup.js';
    StyleSheets = 'ControlAddIn/Freight/freight-monitor.css';
    Images = 'ControlAddIn/Shared/images/avocado-mark.png', 'ControlAddIn/Shared/images/avocado-wordmark.png';

    procedure SetState(StateJson: Text; StatusMessage: Text; IsError: Boolean);

    event ControlReady();
    event RefreshRequested();
    event OpenSourceRequested(SourceType: Text; DocumentNo: Text);
}
