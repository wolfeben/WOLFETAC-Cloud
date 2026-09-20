controladdin "SAL Planner Workspace"
{
    MinimumHeight = 640;
    RequestedHeight = 1080;
    MinimumWidth = 320;
    RequestedWidth = 1920;
    HorizontalStretch = true;
    HorizontalShrink = true;
    VerticalStretch = true;
    VerticalShrink = true;

    Scripts = 'ControlAddIn/Planner/planner.js';
    StartupScript = 'ControlAddIn/Planner/startup.js';
    RecreateScript = 'ControlAddIn/Planner/startup.js';
    StyleSheets = 'ControlAddIn/Planner/planner.css';
    Images = 'ControlAddIn/Shared/images/avocado-mark.png', 'ControlAddIn/Shared/images/avocado-wordmark.png';

    procedure SetState(StateJson: Text; StatusMessage: Text; IsError: Boolean);

    event ControlReady();
    event RefreshRequested();
    event PlanSelected(PlanNo: Text; VersionNo: Integer);
    event DemandCandidateSelected(SourceType: Text; DocumentNo: Text);
    event OpenDemandSourceRequested(SourceType: Text; DocumentNo: Text);
    event ReleaseAndCreateDemandRequested(SourceType: Text; DocumentNo: Text);
    event NewSalesOrderRequested();
    event NewTransferOrderRequested();
    event OpenNativeRequested();
    event OpenPlansRequested();
    event AddDemandRequested();
    event RefreshDemandRequested();
    event ValidateRequested();
    event ReleaseRequested();
    event CreateVersionRequested();
    event CancelDraftRequested();
    event AddPalletRequested(PalletType: Text; PalletCount: Integer; TargetQuantity: Decimal; Description: Text);
    event AutoFillPalletsRequested(AllowMixed: Boolean);
    event OpenPalletRulesRequested();
    event DeletePalletRequested(PalletNo: Integer);
    event EditPalletRequested(PalletNo: Integer; PalletType: Text; TargetQuantity: Decimal; Description: Text);
    event AddComponentRequested(PalletNo: Integer; SourceLineNo: Integer; Quantity: Decimal);
    event AddFillComponentRequested(PalletNo: Integer; SourceLineNo: Integer; FillMemberLineNo: Integer; Quantity: Decimal);
    event AddFlexibleFillComponentRequested(PalletNo: Integer; SourceLineNo: Integer; Quantity: Decimal);
    event DeleteComponentRequested(PalletNo: Integer; LineNo: Integer);
    event EditExactComponentRequested(PalletNo: Integer; LineNo: Integer; Quantity: Decimal);
    event AdjustFillTargetRequested(SourceLineNo: Integer; NewFillTarget: Decimal; Reason: Text);
    event ConvertRemainingToFillRequested(SourceLineNo: Integer; FillGroupCode: Text; Quantity: Decimal; AllowMixed: Boolean; MembersJson: Text; Reason: Text);
    event OpenFillGroupsRequested();
    event SavePriorityRequested(Priority: Integer);
    event SaveMarketerRequested(Marketer: Text);
    event SaveRoutingRequested(SourceLineNo: Integer; ExecutionRoute: Text; FacilityWorkType: Text);
    event SaveShipFromAllRequested(LocationCode: Text);
    event OpenSourceRequested(SourceLineNo: Integer);
}
