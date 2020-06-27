{-------------------------------------------------------------------------------

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.

-------------------------------------------------------------------------------}
{===============================================================================

  Progress tracker

  ©František Milt 2018-10-22

  Version 1.3.4

  Dependencies:
    AuxTypes   - github.com/ncs-sniper/Lib.AuxTypes
    AuxClasses - github.com/ncs-sniper/Lib.AuxClasses

===============================================================================}
unit ProgressTracker;

{$IFDEF FPC}
  {$MODE Delphi}
  {$DEFINE FPC_DisableWarns}
  {$MACRO ON}
{$ENDIF}

interface

uses
  SysUtils,
  {$IFNDEF FPC}AuxTypes,{$ENDIF} AuxClasses;

{===============================================================================
    Library-specific exeptions
===============================================================================}

type
  EPTException = class(Exception);

  EPTIndexOutOfBounds  = class(EPTException);
  EPTInvalidStageID    = class(EPTException);
  EPTStageIDAssigned   = class(EPTException);
  EPTUnassignedStageID = class(EPTException);
  //EPTNoSubstage       = class(EPTException);
  EPTInvalidValue     = class(EPTException);

{===============================================================================
--------------------------------------------------------------------------------
                               TProgressStageNode                               
--------------------------------------------------------------------------------
===============================================================================}
type
  TPTStageID = type Integer;

  TPTStageArray = array of TPTStageID;

  // TPTStageData is used to obtain otherwise internal stage data
  TPTStageData = record
    AbsoluteLength:   Double;
    RelativeLength:   Double;
    RelativeStart:    Double;
    RelativeProgress: Double;
  end;

  // stage event/callback procedural types
  TPTStageProgressEvent = procedure(Sender: TObject; Stage: TPTStageID; Progress: Double) of object;
  TPTStageProgressCallback = procedure(Sender: TObject; Stage: TPTStageID; Progress: Double);

const
  PT_STAGEID_INVALID = -1;
  PT_STAGEID_MASTER  = Low(TPTStageID);

{===============================================================================
    TProgressStageNode - class declaration
===============================================================================}
type
  TProgressStageNode = class(TCustomListObject)
  private
    // progress
    fMaximum:                 UInt64;
    fPosition:                UInt64;
    fProgress:                Double;
    fLastReportedProgress:    Double;
    // stage (public)
    fSuperStageNode:          TProgressStageNode;
    fStageID:                 TPTStageID;
    fStageCount:              Integer;
    fStages:                  array of TProgressStageNode;
    // stage (internal)
    fAbsoluteLength:          Double;
    fRelativeLength:          Double;
    fRelativeStart:           Double;
    fRelativeProgress:        Double;
    // settings
    fConsecutiveStages:       Boolean;
    fStrictlyGrowing:         Boolean;
    fMinProgressDelta:        Double;
    fGlobalSettings:          Boolean;
    // updates
    fChanged:                 Boolean;
    fUpdateCounter:           Integer;
    // events
    fOnProgressInternal:      TNotifyEvent;
    fOnProgressEvent:         TFloatEvent;
    fOnProgressCallBack:      TFloatCallback;
    fOnStageProgressEvent:    TPTStageProgressEvent;
    fOnStageProgressCallBack: TPTStageProgressCallback;
    // getters, setters
    procedure SetMaximum(Value: UInt64);
    procedure SetPosition(Value: UInt64);
    procedure SetProgress(Value: Double);
    Function GetStage(Index: Integer): TProgressStageNode;
    procedure SetConsecutiveStages(Value: Boolean);
    procedure SetStrictlyGrowing(Value: Boolean);
    procedure SetMinProgressDelta(Value: Double);
    procedure SetGlobalSettings(Value: Boolean);
  protected
    // list methods
    Function GetCapacity: Integer; override;
    procedure SetCapacity(Value: Integer); override;
    Function GetCount: Integer; override;
    procedure SetCount(Value: Integer); override;
    // recalculations
    procedure RecalculateRelations; virtual;
    procedure RecalculateProgress(ForceChange: Boolean = False); virtual;
    procedure ProgressFromPosition; virtual;
    procedure StageProgressHandler(Sender: TObject); virtual;
    // progress
    procedure DoProgress; virtual;  // also manages internal progress events
    // init/final
    procedure Initialize; virtual;
    procedure Finalize; virtual;
    // macro/utils
    procedure NewStageAt(Index: Integer; AbsoluteLength: Double; StageID: TPTStageID); virtual;
    // internal properties/events
    property AbsoluteLength: Double read fAbsoluteLength write fAbsoluteLength;
    property RelativeLength: Double read fRelativeLength write fRelativeLength;
    property RelativeStart: Double read fRelativeStart write fRelativeStart;
    property RelativeProgress: Double read fRelativeProgress write fRelativeProgress;
    property OnProgressInternal: TNotifyEvent read fOnProgressInternal write fOnProgressInternal;
  public
    constructor Create;
    constructor CreateAsStage(SuperStageNode: TProgressStageNode; AbsoluteLength: Double; StageID: TPTStageID);
    destructor Destroy; override;
    // updating
    Function BeginUpdate: Integer; virtual;
    Function EndUpdate: Integer; virtual;
    // list functions
    Function LowIndex: Integer; override;
    Function HighIndex: Integer; override;
    Function First: TProgressStageNode; virtual;
    Function Last: TProgressStageNode; virtual;
    Function IndexOf(Node: TProgressStageNode): Integer; overload; virtual;
    Function IndexOf(StageID: TPTStageID): Integer; overload; virtual;
    Function Find(Node: TProgressStageNode; out Index: Integer): Boolean; overload; virtual;
    Function Find(StageID: TPTStageID; out Index: Integer): Boolean; overload; virtual;
    Function Add(AbsoluteLength: Double; StageID: TPTStageID = PT_STAGEID_INVALID): Integer; virtual;
    Function Insert(Index: Integer; AbsoluteLength: Double; StageID: TPTStageID = PT_STAGEID_INVALID): Integer; virtual;
    procedure Move(SrcIdx, DstIdx: Integer); virtual;
    procedure Exchange(Idx1, Idx2: Integer); virtual;
    Function Extract(Node: TProgressStageNode): TProgressStageNode; overload; virtual;
    Function Extract(StageID: TPTStageID): TProgressStageNode; overload; virtual;
    Function Remove(Node: TProgressStageNode): Integer; overload; virtual;
    Function Remove(StageID: TPTStageID): Integer; overload; virtual;
    procedure Delete(Index: Integer); virtual;
    procedure Clear; virtual;
    // indirect stages access
    Function SetStageMaximum(StageID: TPTStageID; NewValue: UInt64): Boolean; virtual;
    Function SetStagePosition(StageID: TPTStageID; NewValue: UInt64): Boolean; virtual;
    Function SetStageProgress(StageID: TPTStageID; NewValue: Double): Boolean; virtual;
    // utility function
    Function IsSimpleStage: Boolean; virtual;
    Function StageData: TPTStageData; virtual;
    // properties
    property Maximum: UInt64 read fMaximum write SetMaximum;
    property Position: UInt64 read fPosition write SetPosition;
    property Progress: Double read fProgress write SetProgress;
    property SuperStageNode: TProgressStageNode read fSuperStageNode;
    property StageID: TPTStageID read fStageID write fStageID;
    property Stages[Index: Integer]: TProgressStageNode read GetStage; default;
    property ConsecutiveStages: Boolean read fConsecutiveStages write SetConsecutiveStages;
    property StrictlyGrowing: Boolean read fStrictlyGrowing write SetStrictlyGrowing;
    property MinProgressDelta: Double read fMinProgressDelta write SetMinProgressDelta;
  {
    When global settings is true, the newly added stage node inherits settings
    from owner node and any change to the settings is immediately projected to
    all existing subnodes.

    Global settings is automatically set to the same value in all subnodes when
    changed. Newly added nodes are inheriting the current value.

    False by default.
  }
    property GlobalSettings: Boolean read fGlobalSettings write SetGlobalSettings;
    // events
    property OnProgress: TFloatEvent read fOnProgressEvent write fOnProgressEvent;
    property OnProgressEvent: TFloatEvent read fOnProgressEvent write fOnProgressEvent;
    property OnProgressCallBack: TFloatCallback read fOnProgressCallBack write fOnProgressCallBack;
    property OnStageProgress: TPTStageProgressEvent read fOnStageProgressEvent write fOnStageProgressEvent;
    property OnStageProgressEvent: TPTStageProgressEvent read fOnStageProgressEvent write fOnStageProgressEvent;
    property OnStageProgressCallBack: TPTStageProgressCallback read fOnStageProgressCallBack write fOnStageProgressCallBack;
  end;

{===============================================================================
--------------------------------------------------------------------------------
                                TProgressTracker
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    TProgressTracker - class declaration
===============================================================================}
type
  TProgressTracker = class(TCustomListObject)
  private
    fMasterNode:              TProgressStageNode;
    fStages:                  array of TProgressStageNode;
    fStageCount:              Integer;
    // events
    fOnProgressEvent:         TFloatEvent;
    fOnProgressCallBack:      TFloatCallback;
    fOnStageProgressEvent:    TPTStageProgressEvent;
    fOnStageProgressCallBack: TPTStageProgressCallback;
    // getters, setters
    Function GetConsecutiveStages: Boolean;
    procedure SetConsecutiveStages(Value: Boolean);
    Function GetStrictlyGrowing: Boolean;
    procedure SetStrictlyGrowing(Value: Boolean);
    Function GetMinProgressDelta: Double;
    procedure SetMinProgressDelta(Value: Double);
    Function GetGlobalSettings: Boolean;
    procedure SetGlobalSettings(Value: Boolean);
    Function GetNode(Index: Integer): TProgressStageNode;
    Function GetStageNode(StageID: TPTStageID): TProgressStageNode;
    Function GetStage(StageID: TPTStageID): Double;
    procedure SetStage(StageID: TPTStageID; Value: Double);
  protected
    // list methods
    Function GetCapacity: Integer; override;
    procedure SetCapacity(Value: Integer); override;
    Function GetCount: Integer; override;
    procedure SetCount(Value: Integer); override;
    // events
    procedure OnMasterProgressHandler(Sender: TObject; Progress: Double); virtual;
    procedure OnStageProgressHandler(Sender: TObject; Progress: Double); virtual;
    // init/final
    procedure Initialize; virtual;
    procedure Finalize; virtual;
    // intenal list methods
    Function InternalFirstUnassignedStageID: TPTStageID; virtual; // also grows the list if necessary
    Function ResolveStageID(StageID: TPTStageID): TPTStageID; virtual;
    Function InternalAdd(SuperStageNode: TProgressStageNode; AbsoluteLength: Double; StageID: TPTStageID): TPTStageID; virtual;
    Function InternalInsert(SuperStageNode: TProgressStageNode; Index: Integer; AbsoluteLength: Double; StageID: TPTStageID): TPTStageID; virtual;
    // utility methods
    Function ObtainStageNode(StageID: TPTStageID): TProgressStageNode; virtual;
  public
    constructor Create;
    destructor Destroy; override;
    // updates
    procedure BeginUpdate; virtual;
    procedure EndUpdate; virtual;
    // list methods
    Function LowIndex: Integer; override;
    Function HighIndex: Integer; override;
    Function LowStageID: TPTStageID; virtual;
    Function HighStageID: TPTStageID; virtual;
    // index methods
    Function CheckStageID(StageID: TPTStageID; AllowMaster: Boolean = False): Boolean; virtual;
    Function StageIDAssigned(StageID: TPTStageID): Boolean; virtual;
    Function NodeIndexFromStageID(StageID: TPTStageID): Integer; virtual;
    Function StageIDFromNodeIndex(Index: Integer): TPTStageID; virtual;
    Function FirstUnassignedStageID: TPTStageID; virtual;
    // list manipulation methods  
  {
    IndexOf returns index of stage with given ID within its superstage.

    First overload also returns the ID of superstage for which the searched
    stage is a substage. This can be PT_STAGEID_MASTER, indicating the stage
    does not have explicit superstage.

    To get node index of given stage, use NodeIndexFromStageID.
  }
    Function IndexOf(StageID: TPTStageID; out SuperStage: TPTStageID): Integer; overload; virtual;
    Function IndexOf(StageID: TPTStageID): Integer; overload; virtual;
  {
    Method Add adds new root stage, method AddIn adds new stage as a substage
    of a selected superstage.

    If SuperStageID is not valid, an EPTUnassignedStageID exception will be
    raised.
    When SuperStageID is set to PT_STAGEID_MASTER, the AddIn method is
    equivalent to method Add (although not the same).

    If StageID parameter is not specified (left as invalid), then the newly
    added stage will be assigned a first free stage ID and this ID will also be
    returned.
    When a StageID is specified, and it cannot be used (ie. it is already
    assigned), an EPTStageIDAssigned exception will be raised.
    If specified StageID is beyond allocated space, the space is reallocated so
    that the requested ID can be used. 
  }
    Function Add(AbsoluteLength: Double; StageID: TPTStageID = PT_STAGEID_INVALID): TPTStageID; virtual;
    Function AddIn(SuperStageID: TPTStageID; AbsoluteLength: Double; StageID: TPTStageID = PT_STAGEID_INVALID): TPTStageID; virtual;

    Function Insert(InsertStageID: TPTStageID; AbsoluteLength: Double; StageID: TPTStageID = PT_STAGEID_INVALID): TPTStageID; virtual;
    Function InsertIn(SuperStageID, InsertStageID: TPTStageID; AbsoluteLength: Double; StageID: TPTStageID = PT_STAGEID_INVALID): TPTStageID; virtual;
    Function InsertIndex(Index: Integer; AbsoluteLength: Double; StageID: TPTStageID = PT_STAGEID_INVALID): TPTStageID; virtual;
    Function InsertIndexIn(SuperStageID: TPTStageID; Index: Integer; AbsoluteLength: Double; StageID: TPTStageID = PT_STAGEID_INVALID): TPTStageID; virtual;

    //procedure Exchange(ID1,ID2: TPTStageID); overload; virtual;
    //procedure ExchangeIn(SuperStageID: TPTStageID; ID1,ID2: TPTStageID); overload; virtual;
    //procedure ExchangeIndex(Idx1,Idx2: Integer); overload; virtual;
    //procedure ExchangeIndexIn(SuperStageID: TPTStageID; Idx1,Idx2: Integer); overload; virtual;

    //procedure Move(SrcID,DstID: TPTStageID); overload; virtual;
    //procedure MoveIn(SuperStageID: TPTStageID; SrcID,DstID: TPTStageID); overload; virtual;
    //procedure MoveIndex(SrcIdx,DstIdx: Integer); overload; virtual;
    //procedure MoveIndexIn(SuperStageID: TPTStageID; SrcIdx,DstIdx: Integer); overload; virtual;

    Function Remove(StageID: TPTStageID): TPTStageID; virtual;
    procedure Delete(StageID: TPTStageID); virtual;
    procedure DeleteIndex(Index: Integer); virtual;
    
    procedure Clear(SuperStageID: TPTStageID = PT_STAGEID_INVALID); virtual;
    // stages information
    Function IsSimpleStage(StageID: TPTStageID): Boolean; virtual;
    Function IsSubstageOf(SubStageID,StageID: TPTStageID): Boolean; virtual;
    Function IsSuperstageOf(SuperStageID,StageID: TPTStageID): Boolean; virtual;
    Function SeperstageOf(StageID: TPTStageID): TPTStageID; virtual;
    Function SubstageCountOf(StageID: TPTStageID): Integer; virtual;
    Function SubstagesOf(StageID: TPTStageID): TPTStageArray; virtual;
    Function StagePath(StageID: TPTStageID; IncludeMaster: Boolean = False): TPTStageArray; virtual;
    // managed stages access
    Function GetStageMaximum(StageID: TPTStageID): UInt64; virtual;
    Function SetStageMaximum(StageID: TPTStageID; Maximum: UInt64): UInt64; virtual;
    Function GetStagePosition(StageID: TPTStageID): UInt64; virtual;
    Function SetStagePosition(StageID: TPTStageID; Position: UInt64): UInt64; virtual;
    Function GetStageProgress(StageID: TPTStageID): Double; virtual;
    Function SetStageProgress(StageID: TPTStageID; Progress: Double): Double; virtual;
    Function GetStageReporting(StageID: TPTStageID): Boolean; virtual;
    Function SetStageReporting(StageID: TPTStageID; StageReporting: Boolean): Boolean; virtual;
    // properties
    property ConsecutiveStages: Boolean read GetConsecutiveStages write SetConsecutiveStages;
    property StrictlyGrowing: Boolean read GetStrictlyGrowing write SetStrictlyGrowing;
    property MinProgressDelta: Double read GetMinProgressDelta write SetMinProgressDelta;
    property GlobalSettings: Boolean read GetGlobalSettings write SetGlobalSettings;
    property Nodes[Index: Integer]: TProgressStageNode read GetNode;
    property StageNodes[StageID: TPTStageID]: TProgressStageNode read GetStageNode;
    property Stages[StageID: TPTStageID]: Double read GetStage write SetStage; default;
    // events
    property OnProgress: TFloatEvent read fOnProgressEvent write fOnProgressEvent;
    property OnProgressEvent: TFloatEvent read fOnProgressEvent write fOnProgressEvent;
    property OnProgressCallBack: TFloatCallback read fOnProgressCallBack write fOnProgressCallBack;
    property OnStageProgress: TPTStageProgressEvent read fOnStageProgressEvent write fOnStageProgressEvent;
    property OnStageProgressEvent: TPTStageProgressEvent read fOnStageProgressEvent write fOnStageProgressEvent;
    property OnStageProgressCallBack: TPTStageProgressCallback read fOnStageProgressCallBack write fOnStageProgressCallBack;
  end;

implementation

{$IFDEF FPC_DisableWarns}
  {$DEFINE FPCDWM}
  {$DEFINE W5024:={$WARN 5024 OFF}} // Parameter "$1" not used
{$ENDIF}

{===============================================================================
--------------------------------------------------------------------------------
                               TProgressStageNode                               
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    TProgressStageNode - auxiliary functions
===============================================================================}

Function LimitValue(Value: Double): Double;
begin
If Value < 0.0 then
  Result := 0.0
else If Value > 1.0 then
  Result := 1.0
else
  Result := Value;
end;

{===============================================================================
    TProgressStageNode - class implementation
===============================================================================}
{-------------------------------------------------------------------------------
    TProgressStageNode - private methods
-------------------------------------------------------------------------------}

procedure TProgressStageNode.SetMaximum(Value: UInt64);
begin
If (Value <> fMaximum) and IsSimpleStage then
  begin
    If (Value < fMaximum) or not fStrictlyGrowing or (fMaximum <= 0) then
      begin
        If Value < fPosition then
          fPosition := Value;
        fMaximum := Value;
        ProgressFromPosition;
        DoProgress;
      end;
  end;
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.SetPosition(Value: UInt64);
begin
If (Value <> fPosition) and IsSimpleStage then
  begin
    If (Value > fPosition) or not fStrictlyGrowing then
      begin
        If Value > fMaximum then
          fMaximum := Value;
        fPosition := Value; 
        ProgressFromPosition;
        DoProgress;
      end;
  end;
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.SetProgress(Value: Double);
begin
If (Value <> fProgress) and IsSimpleStage then
  begin
    If (Value > fProgress) or not fStrictlyGrowing then
      begin
        fProgress := LimitValue(Value);
        DoProgress;
      end;
  end;
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.GetStage(Index: Integer): TProgressStageNode;
begin
If CheckIndex(Index) then
  Result := fStages[Index]
else
  raise EPTIndexOutOfBounds.CreateFmt('TProgressStageNode.GetStage: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.SetConsecutiveStages(Value: Boolean);
var
  i:  Integer;
begin
If fGlobalSettings then
  For i := LowIndex to HighIndex do
    fStages[i].ConsecutiveStages := Value;
If Value <> fConsecutiveStages then
  begin
    fConsecutiveStages := Value;
    RecalculateProgress;
    DoProgress;
  end;
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.SetStrictlyGrowing(Value: Boolean);
var
  i:  Integer;
begin
If fGlobalSettings then
  For i := LowIndex to HighIndex do
    fStages[i].StrictlyGrowing := Value;
If Value <> fStrictlyGrowing then
  begin
    fStrictlyGrowing := Value;
    If not IsSimpleStage then
      begin
        RecalculateProgress;
        DoProgress;
      end;
  end;
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.SetMinProgressDelta(Value: Double);
var
  i:  Integer;
begin
If fGlobalSettings then
  For i := LowIndex to HighIndex do
    fStages[i].MinProgressDelta := Value;
If Value <> fMinProgressDelta then
  fMinProgressDelta := LimitValue(Value);
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.SetGlobalSettings(Value: Boolean);
var
  i:  Integer;
begin
For i := LowIndex to HighIndex do
  fStages[i].GlobalSettings := Value;
If Value <> fGlobalSettings then
  begin
    fGlobalSettings := Value;
    If fGlobalSettings then
      For i := LowIndex to HighIndex do
        begin
          fStages[i].ConsecutiveStages := fConsecutiveStages;
          fStages[i].StrictlyGrowing := fStrictlyGrowing;
          fStages[i].MinProgressDelta := fMinProgressDelta;
        end;
  end;
end;

{-------------------------------------------------------------------------------
    TProgressStageNode - protected methods
-------------------------------------------------------------------------------}

Function TProgressStageNode.GetCapacity: Integer;
begin
Result := Length(fStages);
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.SetCapacity(Value: Integer);
var
  i:  Integer;
begin
If Value >= 0 then
  begin
    If Value <> Length(fStages) then
      begin
        If Value < Count then
          For i := Value to HighIndex do
            FreeAndNil(fStages[i]);
        SetLength(fStages,Value);
      end;
  end
else raise EPTInvalidValue.CreateFmt('TProgressStageNode.SetCapacity: Invalid capacity (%d).',[Value]);
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.GetCount: Integer;
begin
Result := fStageCount;
end;

//------------------------------------------------------------------------------

{$IFDEF FPCDWM}{$PUSH}W5024{$ENDIF}
procedure TProgressStageNode.SetCount(Value: Integer);
begin
// do nothing
end;
{$IFDEF FPCDWM}{$POP}{$ENDIF}

//------------------------------------------------------------------------------

procedure TProgressStageNode.RecalculateRelations;
var
  AbsLen:   Double;
  i:        Integer;
  RelStart: Double;
begin
// get total absolute length
AbsLen := 0.0;
For i := LowIndex to HighIndex do
  AbsLen := AbsLen + fStages[i].AbsoluteLength;
// recalculate relative length, start and progress
RelStart := 0.0;
For i := LowIndex to HighIndex do
  begin
    fStages[i].RelativeStart := RelStart;
    If AbsLen <> 0.0 then
      fStages[i].RelativeLength := fStages[i].AbsoluteLength / AbsLen
    else
      fStages[i].RelativeLength := 0.0;
    fStages[i].RelativeProgress := fStages[i].RelativeLength * fStages[i].Progress;
    RelStart := RelStart + fStages[i].RelativeLength;
  end;
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.RecalculateProgress(ForceChange: Boolean = False);
var
  i:            Integer;
  NewProgress:  Double;
begin
If (fStageCount > 0) and (fUpdateCounter <= 0) then
  begin
    NewProgress := 0.0;
    // recalc relative progress of stages
    For i := LowIndex to HighIndex do
      fStages[i].RelativeProgress := fStages[i].RelativeLength * fStages[i].Progress;
    // get new progress
    For i := HighIndex downto LowIndex do
      If fStages[i].Progress <> 0.0 then
        begin
          If fConsecutiveStages then
            begin
              NewProgress := fStages[i].RelativeStart + fStages[i].RelativeProgress;
              Break{For i};
            end
          else NewProgress := NewProgress + fStages[i].RelativeProgress;
        end;
    If (NewProgress > fProgress) or ForceChange or not fStrictlyGrowing then
      fProgress := LimitValue(NewProgress);
  end;
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.ProgressFromPosition;
begin
If fMaximum <> 0 then
  fProgress := LimitValue(fPosition / fMaximum)
else
  fProgress := 0.0;
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.StageProgressHandler(Sender: TObject);
begin
RecalculateProgress;
If (Sender is TProgressStageNode) and Assigned(fOnStageProgressEvent) then
  fOnStageProgressEvent(Self,TProgressStageNode(Sender).StageID,TProgressStageNode(Sender).Progress);
DoProgress;  
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.DoProgress;
begin
If (Abs(fProgress - fLastReportedProgress) >= fMinProgressDelta) or
  ((fProgress <= 0.0) or (fProgress >= 1.0)) then
  begin
    fChanged := True;
    If (fUpdateCounter <= 0) then
      begin
        If Assigned(fOnProgressEvent) then
          fOnProgressEvent(Self,fProgress);
        If Assigned(fOnProgressCallback) then
          fOnProgressCallback(Self,fProgress);
        // put internal at the end of reporting  
        If Assigned(fOnProgressInternal) then
          fOnProgressInternal(Self);          
        fLastReportedProgress := fProgress;
      end;
  end;
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.Initialize;
begin
fMaximum := 0;
fPosition := 0;
fProgress := 0.0;
fLastReportedProgress := 0.0;
// stage (public)
fSuperStageNode := nil;
fStageID := PT_STAGEID_INVALID;
fStageCount := 0;
SetLEngth(fStages,0);
// stage (internal)
fAbsoluteLength := 0.0;
fRelativeLength := 0.0;
fRelativeStart := 0.0;
fRelativeProgress := 0.0;
// settings
fConsecutiveStages := False;
fStrictlyGrowing := False;
fMinProgressDelta := 0.0;
fGlobalSettings := False;
// updates
fChanged := False;
fUpdateCounter := 0;
// events
fOnProgressInternal := nil;
fOnProgressEvent := nil;
fOnProgressCallBack := nil;
fOnStageProgressEvent := nil;
fOnStageProgressCallBack := nil;
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.Finalize;
begin
// prevent reporting
fOnProgressInternal := nil;
fOnProgressEvent := nil;
fOnProgressCallBack := nil;
fOnStageProgressEvent := nil;
fOnStageProgressCallBack := nil;
Clear;
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.NewStageAt(Index: Integer; AbsoluteLength: Double; StageID: TPTStageID);
begin
// do not check index validity
fStages[Index] := TProgressStageNode.CreateAsStage(Self,AbsoluteLength,StageID);
fStages[Index].OnProgressInternal := StageProgressHandler;
If fGlobalSettings then
  begin
    fStages[Index].StrictlyGrowing := fStrictlyGrowing;
    fStages[Index].ConsecutiveStages := fConsecutiveStages;
    fStages[Index].MinProgressDelta := fMinProgressDelta;
    fStages[Index].GlobalSettings := fGlobalSettings;
  end;
Inc(fStageCount);
RecalculateRelations;
RecalculateProgress(True);
DoProgress;
end;

{-------------------------------------------------------------------------------
    TProgressStageNode - public methods
-------------------------------------------------------------------------------}

constructor TProgressStageNode.Create;
begin
inherited Create;
Initialize;
end;

//------------------------------------------------------------------------------

constructor TProgressStageNode.CreateAsStage(SuperStageNode: TProgressStageNode; AbsoluteLength: Double; StageID: TPTStageID);
begin
Create;
fSuperStageNode := SuperStageNode;
fAbsoluteLength := Abs(AbsoluteLength);
fStageID := StageID;
end;

//------------------------------------------------------------------------------

destructor TProgressStageNode.Destroy;
begin
Finalize;
inherited;
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.BeginUpdate: Integer;
var
  i:  Integer;
begin
If fUpdateCounter <= 0 then
  fChanged := False;
Inc(fUpdateCounter);
For i := LowIndex to HighIndex do
  fStages[i].BeginUpdate;
Result := fUpdateCounter;  
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.EndUpdate: Integer;
var
  i:  Integer;
begin
For i := LowIndex to HighIndex do
  fStages[i].EndUpdate;
Dec(fUpdateCounter);
If fUpdateCounter <= 0 then
  begin
    fUpdateCounter := 0;
    If fChanged then
      begin
        RecalculateProgress;
        DoProgress;
      end;
    fChanged := False;
  end;
Result := fUpdateCounter;
end;


//------------------------------------------------------------------------------

Function TProgressStageNode.LowIndex: Integer;
begin
Result := Low(fStages);
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.HighIndex: Integer;
begin
Result := Pred(fStageCount);
end;
 
//------------------------------------------------------------------------------

Function TProgressStageNode.First: TProgressStageNode;
begin
Result := GetStage(LowIndex);
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.Last: TProgressStageNode;
begin
Result := GetStage(HighIndex);
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.IndexOf(Node: TProgressStageNode): Integer;
var
  i:  Integer;
begin
Result := -1;
For i := LowIndex to HighIndex do
  If fStages[i] = Node then
    begin
      Result := i;
      Break{For i};
    end;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TProgressStageNode.IndexOf(StageID: TPTStageID): Integer;
var
  i:  Integer;
begin
Result := -1;
For i := LowIndex to HighIndex do
  If fStages[i].StageID = StageID then
    begin
      Result := i;
      Break{For i};
    end;
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.Find(Node: TProgressStageNode; out Index: Integer): Boolean;
begin
Index := IndexOf(Node);
Result := CheckIndex(Index);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TProgressStageNode.Find(StageID: TPTStageID; out Index: Integer): Boolean;
begin
Index := IndexOf(StageID);
Result := CheckIndex(Index);
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.Add(AbsoluteLength: Double; StageID: TPTStageID = PT_STAGEID_INVALID): Integer;
begin
Grow;
Result := fStageCount;
NewStageAt(Result,AbsoluteLength,StageID);
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.Insert(Index: Integer; AbsoluteLength: Double; StageID: TPTStageID = PT_STAGEID_INVALID): Integer;
var
  i:  Integer;
begin
If CheckIndex(Index) then
  begin
    Grow;
    For i := HighIndex downto Index do
      fStages[i + 1] := fStages[i];
    NewStageAt(Index,AbsoluteLength,StageID);
    Result := Index;
  end
else Result := Add(AbsoluteLength,StageID);
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.Move(SrcIdx, DstIdx: Integer);
var
  Temp: TProgressStageNode;
  i:    Integer;
begin
If SrcIdx <> DstIdx then
  begin
    If not CheckIndex(SrcIdx) then
      raise EPTIndexOutOfBounds.CreateFmt('TProgressStageNode.Move: Source index (%d) out of bounds.',[SrcIdx]);
    If not CheckIndex(DstIdx) then
      raise EPTIndexOutOfBounds.CreateFmt('TProgressStageNode.Move: Destination index (%d) out of bounds.',[DstIdx]);
    Temp := fStages[SrcIdx];
    If SrcIdx < DstIdx then
      For i := SrcIdx to Pred(DstIdx) do
        fStages[i] := fStages[i + 1]
    else
      For i := SrcIdx downto Succ(DstIdx) do
        fStages[i] := fStages[i - 1];
    fStages[DstIdx] := Temp;
    RecalculateRelations;
    RecalculateProgress(True);
    DoProgress;
  end;
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.Exchange(Idx1, Idx2: Integer);
var
  Temp: TProgressStageNode;
begin
If Idx1 <> Idx2 then
  begin
    If not CheckIndex(Idx1) then
      raise EPTIndexOutOfBounds.CreateFmt('TProgressStageNode.Move: Index 1 (%d) out of bounds.',[Idx1]);
    If not CheckIndex(Idx2) then
      raise EPTIndexOutOfBounds.CreateFmt('TProgressStageNode.Move: Index 2 (%d) out of bounds.',[Idx2]);
    Temp := fStages[Idx1];
    fStages[Idx1] := fStages[Idx2];
    fStages[Idx2] := Temp;
    RecalculateRelations;
    RecalculateProgress(True);
    DoProgress;
  end;
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.Extract(Node: TProgressStageNode): TProgressStageNode;
var
  Index:  Integer;
  i:      Integer;
begin
Index := IndexOf(Node);
If CheckIndex(Index) then
  begin
    Result := fStages[Index];
    For i := Index to Pred(HighIndex) do
      fStages[i] := fStages[i + 1];
    Dec(fStageCount);
    RecalculateRelations;
    RecalculateProgress(True);
    DoProgress;
    Shrink;
  end
else Result := nil;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TProgressStageNode.Extract(StageID: TPTStageID): TProgressStageNode;
var
  Index:  Integer;
  i:      Integer;
begin
Index := IndexOf(StageID);
If CheckIndex(Index) then
  begin
    Result := fStages[Index];
    For i := Index to Pred(HighIndex) do
      fStages[i] := fStages[i + 1];
    Dec(fStageCount);
    RecalculateRelations;
    RecalculateProgress(True);
    DoProgress;
    Shrink;
  end
else Result := nil;
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.Remove(Node: TProgressStageNode): Integer;
begin
Result := IndexOf(Node);
If CheckIndex(Result) then
  Delete(Result);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TProgressStageNode.Remove(StageID: TPTStageID): Integer;
begin
Result := IndexOf(StageID);
If CheckIndex(Result) then
  Delete(Result);
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.Delete(Index: Integer);
var
  i:  Integer;
begin
If CheckIndex(Index) then
  begin
    FreeAndNil(fStages[Index]);
    For i := Index to Pred(HighIndex) do
      fStages[i] := fStages[i + 1];
    Dec(fStageCount);
    RecalculateRelations;
    RecalculateProgress(True);
    DoProgress;
    Shrink;
  end
else raise EPTIndexOutOfBounds.CreateFmt('TProgressStageNode.Delete: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.Clear;
var
  i:  Integer;
begin
For i := LowIndex to HighIndex do
  FreeAndNil(fStages[i]);
SetLength(fStages,0);
fStageCount := 0;
fProgress := 0.0;
DoProgress;
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.SetStageMaximum(StageID: TPTStageID; NewValue: UInt64): Boolean;
var
  Index:  Integer;
begin
If Find(StageID,Index) then
  begin
    fStages[Index].Maximum := NewValue;
    Result := True;
  end
else Result := False;
end;
 
//------------------------------------------------------------------------------

Function TProgressStageNode.SetStagePosition(StageID: TPTStageID; NewValue: UInt64): Boolean;
var
  Index:  Integer;
begin
If Find(StageID,Index) then
  begin
    fStages[Index].Position := NewValue;
    Result := True;
  end
else Result := False;
end;
   
//------------------------------------------------------------------------------

Function TProgressStageNode.SetStageProgress(StageID: TPTStageID; NewValue: Double): Boolean;
var
  Index:  Integer;
begin
If Find(StageID,Index) then
  begin
    fStages[Index].Progress := NewValue;
    Result := True;
  end
else Result := False;
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.IsSimpleStage: Boolean;
begin
Result := fStageCount <= 0;
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.StageData: TPTStageData;
begin
Result.AbsoluteLength := fAbsoluteLength;
Result.RelativeLength := fRelativeLength;
Result.RelativeStart := fRelativeStart;
Result.RelativeProgress := fRelativeProgress;
end;

{===============================================================================
--------------------------------------------------------------------------------
                                TProgressTracker
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    TProgressTracker - class implementation
===============================================================================}
{-------------------------------------------------------------------------------
    TProgressTracker - private methods
-------------------------------------------------------------------------------}

Function TProgressTracker.GetConsecutiveStages: Boolean;
begin
Result := fMasterNode.ConsecutiveStages;
end;
  
//------------------------------------------------------------------------------

procedure TProgressTracker.SetConsecutiveStages(Value: Boolean);
begin
fMasterNode.ConsecutiveStages := Value;
end;
 
//------------------------------------------------------------------------------

Function TProgressTracker.GetStrictlyGrowing: Boolean;
begin
Result := fMasterNode.StrictlyGrowing;
end;
 
//------------------------------------------------------------------------------

procedure TProgressTracker.SetStrictlyGrowing(Value: Boolean);
begin
fMasterNode.StrictlyGrowing := Value;
end;
 
//------------------------------------------------------------------------------

Function TProgressTracker.GetMinProgressDelta: Double;
begin
Result := fMasterNode.MinProgressDelta;
end;
  
//------------------------------------------------------------------------------

procedure TProgressTracker.SetMinProgressDelta(Value: Double);
begin
fMasterNode.MinProgressDelta := Value;
end;
  
//------------------------------------------------------------------------------

Function TProgressTracker.GetGlobalSettings: Boolean;
begin
Result := fMasterNode.GlobalSettings;
end;
 
//------------------------------------------------------------------------------

procedure TProgressTracker.SetGlobalSettings(Value: Boolean);
begin
fMasterNode.GlobalSettings := Value;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.GetNode(Index: Integer): TProgressStageNode;
begin
If CheckIndex(Index) then
  Result := GetStageNode(StageIDFromNodeIndex(Index))
else
  raise EPTIndexOutOfBounds.CreateFmt('TProgressTracker.GetNode: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

Function TProgressTracker.GetStageNode(StageID: TPTStageID): TProgressStageNode;
begin
If CheckStageID(StageID) then
  Result := fStages[Integer(StageID)]
else
  raise EPTInvalidStageID.CreateFmt('TProgressTracker.GetStageNode: Invalid stage ID (%d).',[StageID]);
end;

//------------------------------------------------------------------------------

Function TProgressTracker.GetStage(StageID: TPTStageID): Double;
begin
Result := GetStageNode(StageID).Progress;
end;

//------------------------------------------------------------------------------

procedure TProgressTracker.SetStage(StageID: TPTStageID; Value: Double);
begin
GetStageNode(StageID).Progress := Value;
end;

{-------------------------------------------------------------------------------
    TProgressTracker - protected methods
-------------------------------------------------------------------------------}

Function TProgressTracker.GetCapacity: Integer;
begin
Result := Length(fStages);
end;
 
//------------------------------------------------------------------------------

procedure TProgressTracker.SetCapacity(Value: Integer);
var
  OldCap: Integer;
  i:      Integer;
begin
If Value >= 0 then
  begin
    // only allow growing
    If Value > Length(fStages) then
      begin
        OldCap := Length(fStages);
        SetLength(fStages,Value);
        // ensure the newly added items contains nil
        For i := OldCap to High(fStages) do
          fStages[i] := nil;
      end;
  end
else raise EPTInvalidValue.CreateFmt('TProgressTracker.SetCapacity: Invalid capacity (%d).',[Value]);
end;
 
//------------------------------------------------------------------------------

Function TProgressTracker.GetCount: Integer;
begin
Result := fStageCount;
end;

//------------------------------------------------------------------------------

procedure TProgressTracker.SetCount(Value: Integer);
begin
// do nothing
end;

//------------------------------------------------------------------------------

procedure TProgressTracker.OnMasterProgressHandler(Sender: TObject; Progress: Double);
begin
If Assigned(fOnProgressEvent) then
  fOnProgressEvent(Self,Progress);
If Assigned(fOnProgressCallback) then
  fOnProgressCallback(Self,Progress);
end;

//------------------------------------------------------------------------------

procedure TProgressTracker.OnStageProgressHandler(Sender: TObject; Progress: Double);
begin
If Sender is TProgressStageNode then
  begin
    If Assigned(fOnStageProgressEvent) then
      fOnStageProgressEvent(Self,TProgressStageNode(Sender).StageID,Progress);
    If Assigned(fOnStageProgressCallback) then
      fOnStageProgressCallback(Self,TProgressStageNode(Sender).StageID,Progress);
  end;
end;

//------------------------------------------------------------------------------

procedure TProgressTracker.Initialize;
begin
fMasterNode := TProgressStageNode.Create;
fMasterNode.StageID := PT_STAGEID_MASTER;
fMasterNode.OnProgress := OnMasterProgressHandler;
SetLength(fStages,0);
fStageCount := 0;
// events
fOnProgressEvent := nil;
fOnProgressCallBack := nil;
fOnStageProgressEvent := nil;
fOnStageProgressCallBack := nil;
end;

//------------------------------------------------------------------------------

procedure TProgressTracker.Finalize;
begin
// prevent reporting while clearing
fOnProgressEvent := nil;
fOnProgressCallBack := nil;
fOnStageProgressEvent := nil;
fOnStageProgressCallBack := nil;
// no need to explicitly call clear
fMasterNode.Free;
SetLength(fStages,0);
fStageCount := 0;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.InternalFirstUnassignedStageID: TPTStageID;
var
  i:  TPTStageID;
begin
Grow;
For i := LowStageID to HighStageID do
  If not Assigned(fStages[Integer(i)]) then
    begin
      Result := i;
      Exit;
    end;
// if we are here, something bad has happened
raise EPTException.Create('TProgressTracker.FirstUnassignedStageID: Unable to find any unassigned ID.');
end;

//------------------------------------------------------------------------------

Function TProgressTracker.ResolveStageID(StageID: TPTStageID): TPTStageID;
begin
Result := StageID;
// resolve stage ID
If StageID < LowStageID then
  // invalid stage ID, assign first unassigned
  Result := InternalFirstUnassignedStageID
else If StageID > HighStageID then
  // selected stage ID outside of currently allocated space
  SetCapacity(Succ(Integer(StageID)))
else
  // selected stage ID from currently allocated space
  If StageIDAssigned(StageID) then
    raise EPTStageIDAssigned.CreateFmt('TProgressTracker.ResolveStageID: Selected stage ID (%d) already assigned.',[Integer(StageID)]);
end;

//------------------------------------------------------------------------------

Function TProgressTracker.InternalAdd(SuperStageNode: TProgressStageNode; AbsoluteLength: Double; StageID: TPTStageID): TPTStageID;
begin
ResolveStageID(StageID);
fStages[Integer(StageID)] := SuperStageNode[SuperStageNode.Add(AbsoluteLength,StageID)];
Inc(fStageCount);
Result := StageID;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.InternalInsert(SuperStageNode: TProgressStageNode; Index: Integer; AbsoluteLength: Double; StageID: TPTStageID): TPTStageID;
begin
ResolveStageID(StageID);
fStages[Integer(StageID)] := SuperStageNode[SuperStageNode.Insert(Index,AbsoluteLength,StageID)];
Inc(fStageCount);
Result := StageID;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.ObtainStageNode(StageID: TPTStageID): TProgressStageNode;
begin
If CheckStageID(StageID) then
  begin
    If Assigned(fStages[Integer(StageID)]) then
      Result := fStages[Integer(StageID)]
    else
      raise EPTUnassignedStageID.CreateFmt('TProgressTracker.ObtainStageNode: Unassigned stage ID (%d).',[Integer(StageID)]);
  end
else raise EPTInvalidStageID.CreateFmt('TProgressTracker.ObtainStageNode: Invalid stage ID (%d).',[Integer(StageID)]);
end;

{-------------------------------------------------------------------------------
    TProgressTracker - public methods
-------------------------------------------------------------------------------}

constructor TProgressTracker.Create;
begin
inherited Create;
Initialize;
end;

//------------------------------------------------------------------------------

destructor TProgressTracker.Destroy;
begin
Finalize;
inherited;
end;

//------------------------------------------------------------------------------

procedure TProgressTracker.BeginUpdate;
begin
fMasterNode.BeginUpdate;
end;

//------------------------------------------------------------------------------

procedure TProgressTracker.EndUpdate;
begin
fMasterNode.EndUpdate;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.LowIndex: Integer;
begin
Result := 0;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.HighIndex: Integer;
begin
Result := Pred(fStageCount);
end;

//------------------------------------------------------------------------------

Function TProgressTracker.LowStageID: TPTStageID;
begin
Result := TPTStageID(Low(fStages));
end;

//------------------------------------------------------------------------------

Function TProgressTracker.HighStageID: TPTStageID;
begin
Result := TPTStageID(High(fStages));
end;

//------------------------------------------------------------------------------

Function TProgressTracker.CheckStageID(StageID: TPTStageID; AllowMaster: Boolean = False): Boolean;
begin
Result := ((StageID >= LowStageID) and (StageID <= HighStageID)) or
          (AllowMaster and (StageID = PT_STAGEID_MASTER));
end;

//------------------------------------------------------------------------------

Function TProgressTracker.StageIDAssigned(StageID: TPTStageID): Boolean;
begin
If CheckStageID(StageID) then
  Result := Assigned(fStages[Integer(StageID)])
else
  Result := False;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.NodeIndexFromStageID(StageID: TPTStageID): Integer;
var
  i:  Integer;
begin
Result := -1;
i := Low(fStages);
If CheckStageID(StageID) then
  while i <= Integer(StageID) do
    begin
      If Assigned(fStages[i]) then
        Inc(Result);
      Inc(i)
    end;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.StageIDFromNodeIndex(Index: Integer): TPTStageID;
begin
Result := TPTStageID(-1);
If CheckIndex(Index) then
  while Index >= 0 do
    begin
      Inc(Result);
      If Assigned(fStages[Integer(Result)]) then
        Dec(Index);
    end;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.FirstUnassignedStageID: TPTStageID;
var
  i:  TPTStageID;
begin
Result := PT_STAGEID_INVALID;
For i := LowStageID to HighStageID do
  If not Assigned(fStages[Integer(i)]) then
    begin
      Result := i;
      Break{For i};
    end;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.IndexOf(StageID: TPTStageID; out SuperStage: TPTStageID): Integer;
begin
Result := -1;
SuperStage := PT_STAGEID_INVALID;
If StageIDAssigned(StageID) then
  If Assigned(fStages[Integer(StageID)].SuperStageNode) then
    begin
      SuperStage := fStages[Integer(StageID)].SuperStageNode.StageID;
      Result := fStages[Integer(StageID)].SuperStageNode.IndexOf(fStages[Integer(StageID)]);
    end;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TProgressTracker.IndexOf(StageID: TPTStageID): Integer;
var
  SuperStage: TPTStageID;
begin
Result := IndexOf(StageID,SuperStage);
end;

//------------------------------------------------------------------------------

Function TProgressTracker.Add(AbsoluteLength: Double; StageID: TPTStageID = PT_STAGEID_INVALID): TPTStageID;
begin
Result := InternalAdd(fMasterNode,AbsoluteLength,StageID);
end;

//------------------------------------------------------------------------------

Function TProgressTracker.AddIn(SuperStageID: TPTStageID; AbsoluteLength: Double; StageID: TPTStageID = PT_STAGEID_INVALID): TPTStageID;
var
  SuperStageNode: TProgressStageNode;
begin
If CheckStageID(SuperStageID,True) then
  begin
    If SuperStageID = PT_STAGEID_MASTER then
      SuperStageNode := fMasterNode
    else
      SuperStageNode := fStages[Integer(SuperStageID)];
    If Assigned(SuperStageNode) then
      Result := InternalAdd(SuperStageNode,AbsoluteLength,StageID)
    else
      raise EPTUnassignedStageID.CreateFmt('TProgressTracker.AddIn: SuperStageID (%d) not assigned.',[Integer(SuperStageID)]);
  end
else Result := PT_STAGEID_INVALID;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.Insert(InsertStageID: TPTStageID; AbsoluteLength: Double; StageID: TPTStageID = PT_STAGEID_INVALID): TPTStageID;
begin
end;
Function TProgressTracker.InsertIn(SuperStageID, InsertStageID: TPTStageID; AbsoluteLength: Double; StageID: TPTStageID = PT_STAGEID_INVALID): TPTStageID;
begin
end;
Function TProgressTracker.InsertIndex(Index: Integer; AbsoluteLength: Double; StageID: TPTStageID = PT_STAGEID_INVALID): TPTStageID;
begin
end;
Function TProgressTracker.InsertIndexIn(SuperStageID: TPTStageID; Index: Integer; AbsoluteLength: Double; StageID: TPTStageID = PT_STAGEID_INVALID): TPTStageID;
begin
end;

//------------------------------------------------------------------------------

Function TProgressTracker.Remove(StageID: TPTStageID): TPTStageID;
begin
end;

//------------------------------------------------------------------------------

procedure TProgressTracker.Delete(StageID: TPTStageID);
begin
end;

//------------------------------------------------------------------------------

procedure TProgressTracker.DeleteIndex(Index: Integer);
begin
end;

//------------------------------------------------------------------------------

procedure TProgressTracker.Clear(SuperStageID: TPTStageID = PT_STAGEID_INVALID);
var
  Node: TProgressStageNode;
  i:    Integer;
begin
If CheckStageID(SuperStageID) then
  begin
    // clear a specified node
    Node := ObtainStageNode(SuperStageID);
    Dec(fStageCount,Node.Count);
    For i := Node.LowIndex to Node.HighIndex do
      fStages[Integer(Node[i].StageID)] := nil;
    Node.Clear;
  end
else
  begin
    // clear everything
    fStageCount := 0;    
    SetLength(fStages,0);
    fMasterNode.Clear;
  end;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.IsSimpleStage(StageID: TPTStageID): Boolean;
begin
Result := ObtainStageNode(StageID).IsSimpleStage;
end;
 
//------------------------------------------------------------------------------

Function TProgressTracker.IsSubstageOf(SubStageID,StageID: TPTStageID): Boolean;
var
  Index: Integer;
begin
Result := ObtainStageNode(StageID).Find(SubStageID,Index);
end;
   
//------------------------------------------------------------------------------

Function TProgressTracker.IsSuperstageOf(SuperStageID,StageID: TPTStageID): Boolean;
begin
with ObtainStageNode(StageID) do
  begin
    If Assigned(SuperStageNode) then
      Result := SuperStageNode.StageID = SuperStageID
    else
      Result := False;
  end
end;
 
//------------------------------------------------------------------------------

Function TProgressTracker.SeperstageOf(StageID: TPTStageID): TPTStageID;
begin
with ObtainStageNode(StageID) do
  begin
    If Assigned(SuperStageNode) then
      Result := SuperStageNode.StageID
    else
      Result := PT_STAGEID_INVALID;
  end;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.SubstageCountOf(StageID: TPTStageID): Integer;
begin
Result := ObtainStageNode(StageID).Count;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.SubstagesOf(StageID: TPTStageID): TPTStageArray;
var
  Node: TProgressStageNode;
  i:    Integer;
begin
Node := ObtainStageNode(StageID);
SetLength(Result,Node.Count);
For i := Node.LowIndex to Node.HighIndex do
  Result[i - Node.LowIndex] := Node[i].StageID;
end;
 
//------------------------------------------------------------------------------

Function TProgressTracker.StagePath(StageID: TPTStageID; IncludeMaster: Boolean = False): TPTStageArray;
var
  Node:   TProgressStageNode;
  i:      Integer;
begin
// count levels and preallocate result array
i := 1;
Node := ObtainStageNode(StageID);
while Assigned(Node.SuperStageNode) do
  begin
    Inc(i);
    Node := Node.SuperStageNode;
  end;
If IncludeMaster then
  SetLength(Result,i)
else
  SetLength(Result,i - 1);
// store the IDs
Node := ObtainStageNode(StageID);
For i := High(Result) downto Low(Result) do
  begin
    Result[i] := Node.StageID;
    Node := Node.SuperStageNode;
  end;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.GetStageMaximum(StageID: TPTStageID): UInt64;
begin
Result := ObtainStageNode(StageID).Maximum;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.SetStageMaximum(StageID: TPTStageID; Maximum: UInt64): UInt64;
var
  Node: TProgressStageNode;
begin
Node := ObtainStageNode(StageID);
Result := Node.Maximum;
Node.Maximum := Maximum;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.GetStagePosition(StageID: TPTStageID): UInt64;
begin
Result := ObtainStageNode(StageID).Position;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.SetStagePosition(StageID: TPTStageID; Position: UInt64): UInt64;
var
  Node: TProgressStageNode;
begin
Node := ObtainStageNode(StageID);
Result := Node.Position;
Node.Position := Position;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.GetStageProgress(StageID: TPTStageID): Double;
begin
Result := ObtainStageNode(StageID).Progress;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.SetStageProgress(StageID: TPTStageID; Progress: Double): Double;
var
  Node: TProgressStageNode;
begin
Node := ObtainStageNode(StageID);
Result := Node.Progress;
Node.Progress := Progress;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.GetStageReporting(StageID: TPTStageID): Boolean;
var
  Node: TProgressStageNode;
begin
Node := ObtainStageNode(StageID);
Result := TMethod(Node.OnProgress).Code = @TProgressTracker.OnStageProgressHandler;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.SetStageReporting(StageID: TPTStageID; StageReporting: Boolean): Boolean;
var
  Node: TProgressStageNode;
begin
Node := ObtainStageNode(StageID);
Result := TMethod(Node.OnProgress).Code = @TProgressTracker.OnStageProgressHandler;
If StageReporting then
  Node.OnProgress := OnStageProgressHandler
else
  Node.OnProgress := nil;
end;

end.
