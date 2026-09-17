controladdin "SAL Fill Group Workspace"
{
    MinimumHeight = 520;
    RequestedHeight = 760;
    MinimumWidth = 320;
    RequestedWidth = 1920;
    HorizontalStretch = true;
    HorizontalShrink = true;
    VerticalStretch = true;
    VerticalShrink = true;

    Scripts = 'ControlAddIn/FillGroups/fill-groups.js';
    StartupScript = 'ControlAddIn/FillGroups/startup.js';
    RecreateScript = 'ControlAddIn/FillGroups/startup.js';
    StyleSheets = 'ControlAddIn/FillGroups/fill-groups.css';

    procedure SetState(StateJson: Text; StatusMessage: Text; IsError: Boolean);

    event ControlReady();
    event RefreshRequested();
    event SaveTemplateRequested(GroupCode: Text; Description: Text; MarketerCustomerNo: Text; AllowMixedPallets: Boolean; DefaultPalletQuantity: Decimal; MembersJson: Text);
    event SetTemplateActiveRequested(GroupCode: Text; Active: Boolean);
}
