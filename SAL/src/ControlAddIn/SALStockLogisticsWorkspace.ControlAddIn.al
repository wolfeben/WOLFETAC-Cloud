controladdin "SAL Stock Logistics Workspace"
{
    MinimumHeight = 720;
    RequestedHeight = 900;
    MinimumWidth = 1024;
    RequestedWidth = 1920;
    HorizontalStretch = true;
    HorizontalShrink = true;
    VerticalStretch = true;
    VerticalShrink = true;

    Scripts = 'ControlAddIn/Monitor/packing-logistics-monitor.js';
    StartupScript = 'ControlAddIn/Monitor/startup.js';
    RecreateScript = 'ControlAddIn/Monitor/startup.js';
    StyleSheets = 'ControlAddIn/Monitor/packing-logistics-monitor.css';

    procedure SetState(StateJson: Text; StatusMessage: Text; IsError: Boolean);

    event ControlReady();
    event RefreshRequested();
    event OpenSourceRequested(SourceType: Text; DocumentNo: Text);
    event OpenPlanRequested(PlanNo: Text; VersionNo: Integer);
}
