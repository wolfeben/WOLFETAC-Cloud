controladdin "WLF Pool Review Workspace UI"
{
    MinimumHeight = 600;
    RequestedHeight = 950;
    MinimumWidth = 320;
    RequestedWidth = 1600;
    HorizontalStretch = true;
    HorizontalShrink = true;
    VerticalStretch = true;
    VerticalShrink = true;
    Scripts = 'ui/pooling.js';
    StartupScript = 'ui/startup.js';
    RecreateScript = 'ui/startup.js';
    StyleSheets = 'ui/pooling.css';
    Images = 'ui/images/avocado-mark.png', 'ui/images/avocado-wordmark.png';

    procedure SetState(StateJson: Text);
    event Ready();
    event ActionRequested(ActionName: Text; Payload: Text);
}

