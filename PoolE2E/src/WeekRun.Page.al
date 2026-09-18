page 59353 "WLF Pool Week Test Run"
{
    Caption = 'Pooling September test dataset';
    PageType = Card;
    UsageCategory = Tasks;
    ApplicationArea = All;
    Editable = false;
    layout
    {
        area(Content)
        {
            group(About)
            {
                ShowCaption = false;
                field(Info; 'Pool_Sandbox / LIVE APMS only. 21–25 September 2026: 50 deliveries, 500 bins, 50 orders. Source records use existing growers and items. Each stage stops on its first error; completed receipts are never replayed.')
                { ApplicationArea = All; ShowCaption = false; MultiLine = true; }
            }
            group(Results)
            {
                field(Contents; Contents) { ApplicationArea = All; Caption = 'Run evidence'; MultiLine = true; }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(PalletDetailSerials)
            {
                Caption = 'Use pallet-detail serials for remaining output'; ApplicationArea = All; Image = Change;
                trigger OnAction() begin M.UsePalletDetailSerials(); Contents := M.Snapshot(); end;
            }
            action(PreparePilot)
            {
                Caption = 'Prepare release and consume next order'; ApplicationArea = All; Image = Production;
                trigger OnAction() begin M.RunProduction(1); Contents := M.Snapshot(); end;
            }
            action(PrepareAll)
            {
                Caption = 'Prepare release and consume remaining orders'; ApplicationArea = All; Image = Production;
                trigger OnAction() begin M.RunProduction(50); Contents := M.Snapshot(); end;
            }
            action(OutputPilot)
            {
                Caption = 'Post next pallet contribution'; ApplicationArea = All; Image = OutputJournal;
                trigger OnAction() begin M.RunOutputs(1); Contents := M.Snapshot(); end;
            }
            action(OutputChunk)
            {
                Caption = 'Post next 50 pallet contributions'; ApplicationArea = All; Image = OutputJournal;
                trigger OnAction() begin M.RunOutputs(50); Contents := M.Snapshot(); end;
            }
            action(CompleteSourceDimensions)
            {
                Caption = 'Complete missing pool source dimensions'; ApplicationArea = All; Image = Dimensions;
                trigger OnAction() begin M.CompleteSourceDimensions(); Contents := M.Snapshot(); end;
            }
            action(FinishPilot)
            {
                Caption = 'Finish next order through pooling'; ApplicationArea = All; Image = Post;
                trigger OnAction() begin M.RunFinish(1); Contents := M.Snapshot(); end;
            }
            action(FinishAll)
            {
                Caption = 'Finish remaining orders through pooling'; ApplicationArea = All; Image = Post;
                trigger OnAction() begin M.RunFinish(50); Contents := M.Snapshot(); end;
            }
            action(RefreshEvidence)
            {
                Caption = 'Refresh evidence'; ApplicationArea = All; Image = Refresh;
                trigger OnAction() begin Contents := M.Snapshot(); end;
            }
            action(ExportEvidence)
            {
                Caption = 'Download evidence'; ApplicationArea = All; Image = Export;
                trigger OnAction() begin M.DownloadEvidence(); end;
            }
            action(FirstReceipt)
            {
                Caption = 'Receive next delivery'; ApplicationArea = All; Image = Receipt;
                trigger OnAction() begin M.RunReceipts(1); Contents := M.Snapshot(); end;
            }
            action(RemainingReceipts)
            {
                Caption = 'Receive remaining deliveries'; ApplicationArea = All; Image = Receipt;
                trigger OnAction() begin M.RunReceipts(50); Contents := M.Snapshot(); end;
            }
            action(PreparePlans)
            {
                Caption = 'Prepare five batch plans'; ApplicationArea = All; Image = Planning;
                trigger OnAction() begin M.RunPlans(); Contents := M.Snapshot(); end;
            }
            action(NextPlan)
            {
                Caption = 'Open next batch plan'; ApplicationArea = All; Image = Document;
                trigger OnAction() begin M.OpenNextPlan(); end;
            }
        }
    }
    var M: Codeunit "WLF Pool Week Management"; Contents: Text;
    trigger OnOpenPage() begin Contents := M.Snapshot(); end;
}
