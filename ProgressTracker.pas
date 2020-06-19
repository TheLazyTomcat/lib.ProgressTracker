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
  AuxTypes, AuxClasses;

{===============================================================================
    Library-specific exeptions
===============================================================================}

type
  EPTException = class(Exception);

  EPTIndexOutOfBounds = class(EPTException);
  EPTInvalidStageID   = class(EPTException);
  EPTInvalidValue     = class(EPTException);

{===============================================================================
--------------------------------------------------------------------------------
                                 TProgressNode
--------------------------------------------------------------------------------
===============================================================================}
type
  TPTStageID = type Integer;

  TPTStageProgressEvent = procedure(Sender: TObject; Stage: TPTStageID; Progress: Double) of object;
  TPTStageProgressCallback = procedure(Sender: TObject; Stage: TPTStageID; Progress: Double);


  TPTStageData = record
    AbsoluteLength:   Double;
    RelativeLength:   Double;
    RelativeStart:    Double;
    RelativeProgress: Double;
  end;

const
  PT_STAGEID_INVALID = -1;

{===============================================================================
    TProgressNode - class declaration
===============================================================================}
type
  TProgressNode = class(TCustomListObject)
  private
    // progress
    fMaximum:                 UInt64;
    fPosition:                UInt64;
    fProgress:                Double;
    fLastReportedProgress:    Double;
    // stage (public)
    fStageID:                 TPTStageID;
    fStageCount:              Integer;
    fStages:                  array of TProgressNode;
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
    Function GetStage(Index: Integer): TProgressNode;
    procedure SetConsecutiveStages(Value: Boolean);
    procedure SetStrictlyGrowing(Value: Boolean);
    procedure SetMinProgressDelta(Value: Double);
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
    // internal properties/events
    property AbsoluteLength: Double read fAbsoluteLength write fAbsoluteLength;
    property RelativeLength: Double read fRelativeLength write fRelativeLength;
    property RelativeStart: Double read fRelativeStart write fRelativeStart;
    property RelativeProgress: Double read fRelativeProgress write fRelativeProgress;
    property OnProgressInternal: TNotifyEvent read fOnProgressInternal write fOnProgressInternal;
  public
    constructor Create;
    constructor CreateAsStage(AbsoluteLength: Double; StageID: TPTStageID);
    destructor Destroy; override;
    // updating
    Function BeginUpdate: Integer; virtual;
    Function EndUpdate: Integer; virtual;
    // list functions
    Function LowIndex: Integer; override;
    Function HighIndex: Integer; override;
    Function First: TProgressNode; virtual;
    Function Last: TProgressNode; virtual;
    Function IndexOf(Node: TProgressNode): Integer; overload; virtual;
    Function IndexOf(StageID: TPTStageID): Integer; overload; virtual;
    Function Find(Node: TProgressNode; out Index: Integer): Boolean; overload; virtual;
    Function Find(StageID: TPTStageID; out Index: Integer): Boolean; overload; virtual;
    Function Add(AbsoluteLength: Double; StageID: TPTStageID = PT_STAGEID_INVALID): Integer; virtual;
    procedure Insert(Index: Integer; AbsoluteLength: Double; StageID: TPTStageID = PT_STAGEID_INVALID); virtual;
    procedure Move(SrcIdx, DstIdx: Integer); virtual;
    procedure Exchange(Idx1, Idx2: Integer); virtual;
    Function Extract(Node: TProgressNode): TProgressNode; overload; virtual;
    Function Extract(StageID: TPTStageID): TProgressNode; overload; virtual;
    Function Remove(Node: TProgressNode): Integer; overload; virtual;
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
    property StageID: TPTStageID read fStageID write fStageID;
    property Stages[Index: Integer]: TProgressNode read GetStage; default;
    property ConsecutiveStages: Boolean read fConsecutiveStages write SetConsecutiveStages;
    property StrictlyGrowing: Boolean read fStrictlyGrowing write SetStrictlyGrowing;
    property MinProgressDelta: Double read fMinProgressDelta write SetMinProgressDelta;
  {
    When global settings is true, the newly added stages inherits settings from
    owner node (except for GlobalSettings itself), and any change to the
    settings is immediately projected to all existing stages.

    False by default.
  }
    property GlobalSettings: Boolean read fGlobalSettings write fGlobalSettings;
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

const
  PT_STAGEID_MASTER  = Low(TPTStageID);

{===============================================================================
    TProgressTracker - class declaration
===============================================================================}
//type
//  TProgressTracker = class(TCustomListObject);

implementation

{$IFDEF FPC_DisableWarns}
  {$DEFINE FPCDWM}
  {$DEFINE W5024:={$WARN 5024 OFF}} // Parameter "$1" not used
{$ENDIF}

{===============================================================================
--------------------------------------------------------------------------------
                                 TProgressNode
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    TProgressNode - auxiliary functions
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
    TProgressNode - class implementation
===============================================================================}
{-------------------------------------------------------------------------------
    TProgressNode - private methods
-------------------------------------------------------------------------------}

procedure TProgressNode.SetMaximum(Value: UInt64);
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

procedure TProgressNode.SetPosition(Value: UInt64);
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

procedure TProgressNode.SetProgress(Value: Double);
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

Function TProgressNode.GetStage(Index: Integer): TProgressNode;
begin
If CheckIndex(Index) then
  Result := fStages[Index]
else
  raise EPTIndexOutOfBounds.CreateFmt('TProgressNode.GetStage: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

procedure TProgressNode.SetConsecutiveStages(Value: Boolean);
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

procedure TProgressNode.SetStrictlyGrowing(Value: Boolean);
var
  i:  Integer;
begin
If fGlobalSettings then
  For i := LowIndex to HighIndex do
    fStages[i].StrictlyGrowing := Value;
If Value <> fStrictlyGrowing then
  fStrictlyGrowing := Value;
end;

//------------------------------------------------------------------------------

procedure TProgressNode.SetMinProgressDelta(Value: Double);
var
  i:  Integer;
begin
If fGlobalSettings then
  For i := LowIndex to HighIndex do
    fStages[i].MinProgressDelta := Value;
If Value <> fMinProgressDelta then
  fMinProgressDelta := LimitValue(Value);
end;

{-------------------------------------------------------------------------------
    TProgressNode - protected methods
-------------------------------------------------------------------------------}

Function TProgressNode.GetCapacity: Integer;
begin
Result := Length(fStages);
end;

//------------------------------------------------------------------------------

procedure TProgressNode.SetCapacity(Value: Integer);
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
else raise EPTInvalidValue.CreateFmt('TProgressNode.SetCapacity: Invalid capacity (%d).',[Value]);
end;

//------------------------------------------------------------------------------

Function TProgressNode.GetCount: Integer;
begin
Result := fStageCount;
end;

//------------------------------------------------------------------------------

procedure TProgressNode.SetCount(Value: Integer);
begin
// do nothing
end;

//------------------------------------------------------------------------------

procedure TProgressNode.RecalculateRelations;
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

procedure TProgressNode.RecalculateProgress(ForceChange: Boolean = False);
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

procedure TProgressNode.ProgressFromPosition;
begin
If fMaximum <> 0 then
  fProgress := LimitValue(fPosition / fMaximum)
else
  fProgress := 0.0;
end;

//------------------------------------------------------------------------------

procedure TProgressNode.StageProgressHandler(Sender: TObject);
begin
RecalculateProgress;
If (Sender is TProgressNode) and Assigned(fOnStageProgressEvent) then
  fOnStageProgressEvent(Self,TProgressNode(Sender).StageID,TProgressNode(Sender).Progress);
DoProgress;  
end;

//------------------------------------------------------------------------------

procedure TProgressNode.DoProgress;
begin
If (Abs(fProgress - fLastReportedProgress) >= fMinProgressDelta) or
  ((fProgress <= 0.0) or (fProgress >= 1.0)) then
  begin
    fChanged := True;
    If (fUpdateCounter <= 0) then
      begin
        If Assigned(fOnProgressInternal) then
          fOnProgressInternal(Self);
        If Assigned(fOnProgressEvent) then
          fOnProgressEvent(Self,fProgress);
        If Assigned(fOnProgressCallback) then
          fOnProgressCallback(Self,fProgress);
        fLastReportedProgress := fProgress;
      end;
  end;
end;

//------------------------------------------------------------------------------

procedure TProgressNode.Initialize;
begin
fMaximum := 0;
fPosition := 0;
fProgress := 0.0;
fLastReportedProgress := 0.0;
// stage (public)
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

procedure TProgressNode.Finalize;
begin
// prevent reporting
fOnProgressInternal := nil;
fOnProgressEvent := nil;
fOnProgressCallBack := nil;
fOnStageProgressEvent := nil;
fOnStageProgressCallBack := nil;
Clear;
end;

{-------------------------------------------------------------------------------
    TProgressNode - public methods
-------------------------------------------------------------------------------}

constructor TProgressNode.Create;
begin
inherited Create;
Initialize;
end;

//------------------------------------------------------------------------------

constructor TProgressNode.CreateAsStage(AbsoluteLength: Double; StageID: TPTStageID);
begin
Create;
fStageID := StageID;
fAbsoluteLength := AbsoluteLength;
end;

//------------------------------------------------------------------------------

destructor TProgressNode.Destroy;
begin
Finalize;
inherited;
end;

//------------------------------------------------------------------------------

Function TProgressNode.BeginUpdate: Integer;
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

Function TProgressNode.EndUpdate: Integer;
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

Function TProgressNode.LowIndex: Integer;
begin
Result := Low(fStages);
end;

//------------------------------------------------------------------------------

Function TProgressNode.HighIndex: Integer;
begin
Result := Pred(fStageCount);
end;
 
//------------------------------------------------------------------------------

Function TProgressNode.First: TProgressNode;
begin
Result := GetStage(LowIndex);
end;

//------------------------------------------------------------------------------

Function TProgressNode.Last: TProgressNode;
begin
Result := GetStage(HighIndex);
end;

//------------------------------------------------------------------------------

Function TProgressNode.IndexOf(Node: TProgressNode): Integer;
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

Function TProgressNode.IndexOf(StageID: TPTStageID): Integer;
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

Function TProgressNode.Find(Node: TProgressNode; out Index: Integer): Boolean;
begin
Index := IndexOf(Node);
Result := CheckIndex(Index);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TProgressNode.Find(StageID: TPTStageID; out Index: Integer): Boolean;
begin
Index := IndexOf(StageID);
Result := CheckIndex(Index);
end;

//------------------------------------------------------------------------------

Function TProgressNode.Add(AbsoluteLength: Double; StageID: TPTStageID = PT_STAGEID_INVALID): Integer;
begin
Grow;
Result := fStageCount;
fStages[Result] := TProgressNode.CreateAsStage(AbsoluteLength,StageID);
fStages[Result].OnProgressInternal := StageProgressHandler;
If fGlobalSettings then
  begin
    fStages[Result].StrictlyGrowing := fStrictlyGrowing;
    fStages[Result].ConsecutiveStages := fConsecutiveStages;
    fStages[Result].MinProgressDelta := fMinProgressDelta;
  end;
Inc(fStageCount);
RecalculateRelations;
fMaximum := 0;
fPosition := 0;
RecalculateProgress(True);
DoProgress;
end;

//------------------------------------------------------------------------------

procedure TProgressNode.Insert(Index: Integer; AbsoluteLength: Double; StageID: TPTStageID = PT_STAGEID_INVALID);
var
  i:  Integer;
begin
If CheckIndex(Index) then
  begin
    Grow;
    For i := HighIndex downto Index do
      fStages[i + 1] := fStages[i];
    fStages[Index] := TProgressNode.CreateAsStage(AbsoluteLength,StageID);
    fStages[Index].OnProgressInternal := StageProgressHandler;
    If fGlobalSettings then
      begin
        fStages[Index].StrictlyGrowing := fStrictlyGrowing;
        fStages[Index].ConsecutiveStages := fConsecutiveStages;
        fStages[Index].MinProgressDelta := fMinProgressDelta;
      end;
    Inc(fStageCount);
    RecalculateRelations;
    RecalculateProgress(True);
    DoProgress;
  end
else Add(AbsoluteLength,StageID);
end;

//------------------------------------------------------------------------------

procedure TProgressNode.Move(SrcIdx, DstIdx: Integer);
var
  Temp: TProgressNode;
  i:    Integer;
begin
If SrcIdx <> DstIdx then
  begin
    If not CheckIndex(SrcIdx) then
      raise EPTIndexOutOfBounds.CreateFmt('TProgressNode.Move: Source index (%d) out of bounds.',[SrcIdx]);
    If not CheckIndex(DstIdx) then
      raise EPTIndexOutOfBounds.CreateFmt('TProgressNode.Move: Destination index (%d) out of bounds.',[DstIdx]);
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

procedure TProgressNode.Exchange(Idx1, Idx2: Integer);
var
  Temp: TProgressNode;
begin
If Idx1 <> Idx2 then
  begin
    If not CheckIndex(Idx1) then
      raise EPTIndexOutOfBounds.CreateFmt('TProgressNode.Move: Index 1 (%d) out of bounds.',[Idx1]);
    If not CheckIndex(Idx2) then
      raise EPTIndexOutOfBounds.CreateFmt('TProgressNode.Move: Index 2 (%d) out of bounds.',[Idx2]);
    Temp := fStages[Idx1];
    fStages[Idx1] := fStages[Idx2];
    fStages[Idx2] := Temp;
    RecalculateRelations;
    RecalculateProgress(True);
    DoProgress;
  end;
end;

//------------------------------------------------------------------------------

Function TProgressNode.Extract(Node: TProgressNode): TProgressNode;
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

Function TProgressNode.Extract(StageID: TPTStageID): TProgressNode;
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

Function TProgressNode.Remove(Node: TProgressNode): Integer;
begin
Result := IndexOf(Node);
If CheckIndex(Result) then
  Delete(Result);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TProgressNode.Remove(StageID: TPTStageID): Integer;
begin
Result := IndexOf(StageID);
If CheckIndex(Result) then
  Delete(Result);
end;

//------------------------------------------------------------------------------

procedure TProgressNode.Delete(Index: Integer);
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
else raise EPTIndexOutOfBounds.CreateFmt('TProgressNode.Delete: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

procedure TProgressNode.Clear;
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

Function TProgressNode.SetStageMaximum(StageID: TPTStageID; NewValue: UInt64): Boolean;
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

Function TProgressNode.SetStagePosition(StageID: TPTStageID; NewValue: UInt64): Boolean;
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

Function TProgressNode.SetStageProgress(StageID: TPTStageID; NewValue: Double): Boolean;
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

Function TProgressNode.IsSimpleStage: Boolean;
begin
Result := fStageCount <= 0;
end;

//------------------------------------------------------------------------------

Function TProgressNode.StageData: TPTStageData;
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
{-------------------------------------------------------------------------------
    TProgressTracker - protected methods
-------------------------------------------------------------------------------}
{-------------------------------------------------------------------------------
    TProgressTracker - public methods
-------------------------------------------------------------------------------}

end.
