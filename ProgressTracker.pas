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
  SysUtils, Classes,
  AuxTypes, AuxClasses;

{===============================================================================
    Library-specific exeptions
===============================================================================}

type
  EPTException = class(Exception);

  EPTIndexOutOfBounds  = class(EPTException);
  EPTInvalidValue      = class(EPTException);
  EPTInvalidStageID    = class(EPTException);
  EPTAssignedStageID   = class(EPTException);
  EPTUnassignedStageID = class(EPTException);
  EPTNotSubStageOf     = class(EPTException);

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
    fMaximum:                     UInt64;
    fPosition:                    UInt64;
    fProgress:                    Double;
    fLastReportedProgress:        Double;
    // stage (public)
    fSuperStageNode:              TProgressStageNode;
    fID:                          TPTStageID;
    fSubStageCount:               Integer;
    fSubStages:                   array of TProgressStageNode;
    // stage (internal)
    fAbsoluteLength:              Double;
    fRelativeLength:              Double;
    fRelativeStart:               Double;
    fRelativeProgress:            Double;
    // settings
    fConsecutiveStages:           Boolean;
    fStrictlyGrowing:             Boolean;
    fMinProgressDelta:            Double;
    fGlobalSettings:              Boolean;
    // updates
    fChanged:                     Boolean;
    fUpdateCounter:               Integer;
    // events
    fOnProgressInternal:          TNotifyEvent;
    fOnProgressEvent:             TFloatEvent;
    fOnProgressCallBack:          TFloatCallback;
    fOnSubStageProgressEvent:     TPTStageProgressEvent;
    fOnSubStageProgressCallBack:  TPTStageProgressCallback;
    // getters, setters
    procedure SetMaximum(Value: UInt64);
    procedure SetPosition(Value: UInt64);
    procedure SetProgress(Value: Double);
    Function GetSubStage(Index: Integer): TProgressStageNode;
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
    procedure SubStageProgressHandler(Sender: TObject); virtual;
    // progress
    procedure DoProgress; virtual;  // also manages internal progress events
    // init/final
    procedure Initialize; virtual;
    procedure Finalize; virtual;
    // macro/utils
    procedure NewSubStageAt(Index: Integer; AbsoluteLength: Double; ID: TPTStageID); virtual;
    // internal properties/events
    property AbsoluteLength: Double read fAbsoluteLength write fAbsoluteLength;
    property RelativeLength: Double read fRelativeLength write fRelativeLength;
    property RelativeStart: Double read fRelativeStart write fRelativeStart;
    property RelativeProgress: Double read fRelativeProgress write fRelativeProgress;
    property OnProgressInternal: TNotifyEvent read fOnProgressInternal write fOnProgressInternal;
  public
    constructor Create;
    constructor CreateAsStage(SuperStageNode: TProgressStageNode; AbsoluteLength: Double; ID: TPTStageID);
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
    Function IndexOf(SubStage: TPTStageID): Integer; overload; virtual;
    Function Find(Node: TProgressStageNode; out Index: Integer): Boolean; overload; virtual;
    Function Find(SubStage: TPTStageID; out Index: Integer): Boolean; overload; virtual;
    Function Add(AbsoluteLength: Double; ID: TPTStageID = PT_STAGEID_INVALID): Integer; virtual;
    procedure Insert(Index: Integer; AbsoluteLength: Double; ID: TPTStageID = PT_STAGEID_INVALID); virtual;
    procedure Move(SrcIdx, DstIdx: Integer); virtual;
    procedure Exchange(Idx1, Idx2: Integer); virtual;
    Function Extract(Node: TProgressStageNode): TProgressStageNode; overload; virtual;
    Function Extract(SubStage: TPTStageID): TProgressStageNode; overload; virtual;
    Function Remove(Node: TProgressStageNode): Integer; overload; virtual;
    Function Remove(SubStage: TPTStageID): Integer; overload; virtual;
    procedure Delete(Index: Integer); virtual;
    procedure Clear; virtual;
    // indirect stages access
    Function SetSubStageMaximum(SubStage: TPTStageID; NewValue: UInt64): Boolean; virtual;
    Function SetSubStagePosition(SubStage: TPTStageID; NewValue: UInt64): Boolean; virtual;
    Function SetSubStageProgress(SubStage: TPTStageID; NewValue: Double): Boolean; virtual;
    // utility function
    Function IsSimpleStage: Boolean; virtual;
    Function StageData: TPTStageData; virtual;
    Function SubStageLevel: Integer; virtual;
    Function TotalSubStageCount: Integer; virtual;
    // properties
    property Maximum: UInt64 read fMaximum write SetMaximum;
    property Position: UInt64 read fPosition write SetPosition;
    property Progress: Double read fProgress write SetProgress;
    property SuperStageNode: TProgressStageNode read fSuperStageNode;
    property ID: TPTStageID read fID write fID;
    property SubStages[Index: Integer]: TProgressStageNode read GetSubStage; default;
    property ConsecutiveStages: Boolean read fConsecutiveStages write SetConsecutiveStages;
    property StrictlyGrowing: Boolean read fStrictlyGrowing write SetStrictlyGrowing;
    property MinProgressDelta: Double read fMinProgressDelta write SetMinProgressDelta;
  {
    When global settings is true, the newly added substage node inherits
    settings from owner node and any change to the settings is immediately
    projected to all existing subnodes.

    Global settings is automatically set to the same value in all subnodes when
    changed. Newly added nodes are inheriting the current value.

    False by default.
  }
    property GlobalSettings: Boolean read fGlobalSettings write SetGlobalSettings;
    // events
    property OnProgress: TFloatEvent read fOnProgressEvent write fOnProgressEvent;
    property OnProgressEvent: TFloatEvent read fOnProgressEvent write fOnProgressEvent;
    property OnProgressCallBack: TFloatCallback read fOnProgressCallBack write fOnProgressCallBack;
    property OnSubStageProgress: TPTStageProgressEvent read fOnSubStageProgressEvent write fOnSubStageProgressEvent;
    property OnSubStageProgressEvent: TPTStageProgressEvent read fOnSubStageProgressEvent write fOnSubStageProgressEvent;
    property OnSubStageProgressCallBack: TPTStageProgressCallback read fOnSubStageProgressCallBack write fOnSubStageProgressCallBack;
  end;

{===============================================================================
--------------------------------------------------------------------------------
                                TProgressTracker
--------------------------------------------------------------------------------
===============================================================================}
type
  TPTTreeSettingsField = (tsfAbsoluteLen,tsfRelativeLen,tsfProgress,tsfMaximum,tsfPosition);
  
  TPTTreeSettingsFields = set of TPTTreeSettingsField;

  TPTTreeSettings = record
    FullPaths:      Boolean;
    IncludeMaster:  Boolean;
    HexadecimalIDs: Boolean;
    ShowHeader:     Boolean;
    PathDelimiter:  String;
    Indentation:    String;
    ShownFields:    TPTTreeSettingsFields;
  end;

const
  PT_TREESETTINGS_DEFAULT: TPTTreeSettings = (
    FullPaths:      False;
    IncludeMaster:  False;
    HexadecimalIDs: False;
    ShowHeader:     False;
    PathDelimiter:  '.';
    Indentation:    '  ';
    ShownFields:    []);

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
    Function GetProgress: Double;
    Function GetConsecutiveStages: Boolean;
    procedure SetConsecutiveStages(Value: Boolean);
    Function GetStrictlyGrowing: Boolean;
    procedure SetStrictlyGrowing(Value: Boolean);
    Function GetMinProgressDelta: Double;
    procedure SetMinProgressDelta(Value: Double);
    Function GetGlobalSettings: Boolean;
    procedure SetGlobalSettings(Value: Boolean);
    Function GetNode(Index: Integer): TProgressStageNode;
    Function GetStageNode(Stage: TPTStageID): TProgressStageNode;
    Function GetStage(Stage: TPTStageID): Double;
    procedure SetStage(Stage: TPTStageID; Value: Double);
    Function GetSubStageCount(Stage: TPTStageID): Integer;
    Function GetSubStageNode(Stage: TPTStageID; Index: Integer): TProgressStageNode;
    Function GetSubStage(Stage: TPTStageID; Index: Integer): TPTStageID;
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
    Function ResolveNewStageID(StageID: TPTStageID): TPTStageID; virtual;
    Function InternalAdd(SuperStageNode: TProgressStageNode; AbsoluteLength: Double; ID: TPTStageID): TPTStageID; virtual;
    Function InternalInsert(SuperStageNode: TProgressStageNode; Index: Integer; AbsoluteLength: Double; ID: TPTStageID): TPTStageID; virtual;
    procedure InternalDelete(SuperStageNode: TProgressStageNode; Index: Integer); virtual;
    // utility methods
    Function ObtainStageNode(Stage: TPTStageID; AllowMaster: Boolean): TProgressStageNode; virtual;
  public
    constructor Create;
    destructor Destroy; override;
    // updates
    procedure BeginUpdate; virtual;
    procedure EndUpdate; virtual;
    // index and ID methods
  {
    LowIndex/HighIndex returns low/high bound of indices used when accessing
    Nodes property.
  }
    Function LowIndex: Integer; override;
    Function HighIndex: Integer; override;
  {
    LowStageID returns lowest stage ID from allocated range. It is always 0.

    HighStageID returns highest stage ID from allocated range, irrespective of
    whether the id has a node assigned or not.
    When no range is allocated, it will return PT_STAGEID_INVALID.
  }
    Function LowStageID: TPTStageID; virtual;
    Function HighStageID: TPTStageID; virtual;
  {
    LowSubStageIndex/HighSubStageIndex returns lowest/highest allowed index of
    substages list for selected stage.

    The function will raise an EPTInvalidStageID exception when selected stage
    ID is completely outside of allocated range, or EPTUnassignedStageID
    exception when selected stage ID is within range but does not have a node
    assigned.
  }
    Function LowSubStageIndex(Stage: TPTStageID): Integer; virtual;
    Function HighSubStageIndex(Stage: TPTStageID): Integer; virtual;
  {
    CheckStageID returns true when selected stage ID is within allocated range,
    false otherwise. It ignores whether the ID has assigned node or not.

    Parameter AllowMaster indicates whether the function should return true
    on stage ID equal to PT_STAGEID_MASTER.
  }
    Function CheckStageID(StageID: TPTStageID; AllowMaster: Boolean = False): Boolean; virtual;
  {
    StageIDAssigned returns true when selected stage ID is within allocated
    range and a node object is assigned to it, false otherwise.

    Can accept PR_STAGEID_MASTER, in which case it will always return true.
  }
    Function StageIDAssigned(StageID: TPTStageID): Boolean; virtual;
  {
    CheckSubStageIndex returns true when given index is within allowed bounds
    for substage indices in selected stage, false otherwise.

    Stage parameter can be set to PT_STAGEID_MASTER to check index of root
    stages.

    When stage node cannot be obtained, it will raise EPTInvalidStageID or
    EPTUnassignedStageID exception.
  }
    Function CheckSubStageIndex(Stage: TPTStageID; Index: Integer): Boolean; virtual;
  {
    CheckSubStageID returns true when selected stage contains a subnode with
    ID given in SubStageID, false otherwise.

    Stage parameter can be set to PT_STAGEID_MASTER to check ID of root stages.

    When stage node cannot be obtained, it will raise EPTInvalidStageID or
    EPTUnassignedStageID exception.
  }
    Function CheckSubStageID(Stage,SubStageID: TPTStageID): Boolean; virtual;
  {
    NodeIndexFromStageID returns index of node (position in Nodes property)
    assigned to a given stage ID.

    If no node is assigned at this ID, a negative value is returned.
  }
    Function NodeIndexFromStageID(StageID: TPTStageID): Integer; virtual;
  {
    StageIDFromNodeIndex returns stage ID of a node at given index (see Nodes
    property).

    If the index does not point to any node, it will return PT_STAGEID_INVALID.
  }
    Function StageIDFromNodeIndex(Index: Integer): TPTStageID; virtual;
  {
    FirstUnassignedStageID returns first ID that does not have a node assigned.
    
    When no such ID can be found, it will return PT_STAGEID_INVALID.
  }
    Function FirstUnassignedStageID: TPTStageID; virtual;
    // list manipulation methods  
  {
    IndexOf

      Returns index of stage with given ID within its superstage.
      First overload also returns the ID of superstage for which the searched
      stage is a substage. This can be PT_STAGEID_MASTER, indicating the stage
      is a root stage.
      If the stage is not found, then a negative value is returned and value of
      SuperStage is undefined.

    IndexOfIn

      Returns index of selected stage within a given superstage.
      If the stage is not a substage of selected superstage, it will return
      a negative value.
      When the SuperStage does not point to a valid stage, the function will
      return a negative value.
      SuperStage can be set to PT_STAGEID_MASTER to get index of root stage.
  }
    Function IndexOf(Stage: TPTStageID; out SuperStage: TPTStageID): Integer; overload; virtual;
    Function IndexOf(Stage: TPTStageID): Integer; overload; virtual;
    Function IndexOfIn(SuperStage,Stage: TPTStageID): Integer; virtual;
  {
    Add

      Adds new root stage.
      If ID parameter is not specified (left as invalid), then the newly added
      stage will be assigned a first free stage ID and this ID will also be
      returned.
      When an ID is specified, and it cannot be used (ie. it is already
      assigned), an EPTAssignedStageID exception will be raised.
      If specified ID is beyond allocated space, the space is reallocated so
      that the requested ID can be used - be careful when using this feature,
      it will allocate massive memory space when requesting high ID!

    AddIn

      Adds new stage as a substage of a selected superstage.
      If SuperStage is not valid, an EPTInvalidStageID or EPTUnassignedStageID
      (depending whether the ID is completely out of bounds, or it just points
      to an unassigned ID) exception will be raised.
      When SuperStage is set to PT_STAGEID_MASTER, the AddIn method is
      equivalent to method Add.
      Parameter ID and result behaves the same as in method Add.
  }
    Function Add(AbsoluteLength: Double; ID: TPTStageID = PT_STAGEID_INVALID): TPTStageID; virtual;
    Function AddIn(SuperStage: TPTStageID; AbsoluteLength: Double; ID: TPTStageID = PT_STAGEID_INVALID): TPTStageID; virtual;
  {
    The ID parameter behaves the same as in add methods. Return value of all
    insert methods is bound to ID parameter and also behaves the same as in add
    methods.

    Insert

      Inserts new stage at a position occupied by a selected stage. The new
      stage is inserted to the same superstage where the selected insert stage
      is currently placed.
      If the InsertStage does not exists or is invalid, then EPTInvalidStageID
      or EPTUnassignedStageID exception will be raised.

    InsertIn

      Inserts new substage to a selected superstage at position occupied by
      a stage selected by InsertStage parameter.
      When the SuperStage is not valid, an EPTInvalidStageID or
      EPTUnassignedStageID exception will be raised.
      If the InsertStage does not exist or is not a substage of selected
      superstage, then an EPTNotSubStageOf exception is raised.
      SuperStage can be set to PT_STAGEID_MASTER to insert ne stage between
      root stages.

    InsertInAt

      Inserts new substage to a selected superstage at position given by Index
      parameter.
      When the SuperStage is not valid, an EPTInvalidStageID or
      EPTUnassignedStageID exception will be raised.
      If the index is not valid or is not equal to substage count, then an
      EPTIndexOutOfBounds exception will be raised.
      SuperStage can be set to PT_STAGEID_MASTER.
  }
    Function Insert(InsertStage: TPTStageID; AbsoluteLength: Double; ID: TPTStageID = PT_STAGEID_INVALID): TPTStageID; virtual;
    Function InsertIn(SuperStage,InsertStage: TPTStageID; AbsoluteLength: Double; ID: TPTStageID = PT_STAGEID_INVALID): TPTStageID; virtual;
    Function InsertInAt(SuperStage: TPTStageID; Index: Integer; AbsoluteLength: Double; ID: TPTStageID = PT_STAGEID_INVALID): TPTStageID; virtual;

    //procedure Exchange(Stage1,Stage2: TPTStageID); overload; virtual;
    //procedure ExchangeIn(SuperStage: TPTStageID; Stage1,Stage2: TPTStageID); overload; virtual;
    //procedure ExchangeIndex(Idx1,Idx2: Integer); overload; virtual;
    //procedure ExchangeIndexIn(SuperStage: TPTStageID; Idx1,Idx2: Integer); overload; virtual;

    //procedure Move(SrcStage,DstStage: TPTStageID); overload; virtual;
    //procedure MoveIn(SuperStage: TPTStageID; SrcStage,DstStage: TPTStageID); overload; virtual;
    //procedure MoveIndex(SrcIdx,DstIdx: Integer); overload; virtual;
    //procedure MoveIndexIn(SuperStage: TPTStageID; SrcIdx,DstIdx: Integer); overload; virtual;

  {
    Remove

      Removes selected stage, if present, and returns its index in appropriate
      superstage and, in case of first overload, outputs ID of this superstage
      (can be PT_STAGEID_MASTER).
      If the stage is not present, the function will return a negative value
      and value of SuperStage will be undefined.

    RemoveIn

      Removes selected stage, if present, from a given superstage.
      If the SuperStage is not valid, then a negative value is returned.
      If the selected stage is not present in the given superstage, a negative
      value will be returned.
  }
    Function Remove(Stage: TPTStageID; out SuperStage: TPTStageID): Integer; overload; virtual;
    Function Remove(Stage: TPTStageID): Integer; overload; virtual;
    Function RemoveIn(SuperStage,Stage: TPTStageID): Integer; virtual;
  {
    Delete

      Deletes selected stage.
      If the selected stage is not valid, an EPTInvalidStageID exception will
      be raised.

    DeleteIn

      Deletes selected stage from a selected superstage.
      If the superstage does not exists, this method will return an
      EPTInvalidStageID or EPTUnassignedStageID exception.
      If the selected stage is not a substage of selected superstage, an
      EPTNotSubStageOf exception will be raised.

    DeleteInAt

      Deletes stage at a position given by index from a selected superstage.
      If the superstage does not exists, this method will return an
      EPTInvalidStageID or EPTUnassignedStageID exception.
      If the index does not point to a valid substage, it will raise an
      EPTIndexOutOfBounds exception.
  }
    procedure Delete(Stage: TPTStageID); virtual;
    procedure DeleteIn(SuperStage: TPTStageID; Stage: TPTStageID); virtual;
    procedure DeleteInAt(SuperStage: TPTStageID; Index: Integer); virtual;
  {
    If the parameter SuperStage points to a valid stage node, then only
    substages of this stage will be removed, otherwise all known stages will
    be removed.
    If the selected stage is valid and does not contain any substage, then
    nothing will happen.
    Setting Stage parameter to PT_STAGEID_MASTER has the same effect as setting
    it to an invalid value.
  }
    procedure Clear(Stage: TPTStageID = PT_STAGEID_INVALID); virtual;
    // stages information
    Function IsSimpleStage(Stage: TPTStageID): Boolean; virtual;
    Function IsSubStageOf(SubStage,Stage: TPTStageID): Boolean; virtual;
    Function IsSuperStageOf(SuperStage,Stage: TPTStageID): Boolean; virtual;
    Function SuperStageOf(Stage: TPTStageID): TPTStageID; virtual;
    Function StagePath(Stage: TPTStageID; IncludeMaster: Boolean = False): TPTStageArray; virtual;
    procedure StageTree(Tree: TStrings; TreeSettings: TPTTreeSettings); overload; virtual;
    procedure StageTree(Tree: TStrings); overload; virtual;
    // managed stages access
    Function GetStageMaximum(Stage: TPTStageID): UInt64; virtual;
    Function SetStageMaximum(Stage: TPTStageID; Maximum: UInt64): UInt64; virtual;
    Function GetStagePosition(Stage: TPTStageID): UInt64; virtual;
    Function SetStagePosition(Stage: TPTStageID; Position: UInt64): UInt64; virtual;
    Function GetStageProgress(Stage: TPTStageID): Double; virtual;
    Function SetStageProgress(Stage: TPTStageID; Progress: Double): Double; virtual;
    Function GetStageReporting(Stage: TPTStageID): Boolean; virtual;
    Function SetStageReporting(Stage: TPTStageID; StageReporting: Boolean): Boolean; virtual;
    // tree streaming
    {$message 'implement tree streaming'}
    //procedure SaveToIniStream(Stream: TStream); virtual;    // requires IniFileEx
    //procedure LoadFromIniStream(Stream: TStream); virtual;  // -||-
    (*
    procedure SaveToIniFile(const FileName: String); virtual;
    procedure LoadFromIniFile(const FileName: String); virtual;
    procedure SaveToStream(Stream: TStream); virtual;
    procedure LoadFromStream(Stream: TStream); virtual;
    procedure SaveToFile(const FileName: String); virtual;
    procedure LoadFromFile(const FileName: String); virtual;
    procedure LoadFromResource(const ResName: String; IsIniFile: Boolean = False); virtual;
    procedure LoadFromResourceID(ResID: Integer; IsIniFile: Boolean = False); virtual;
    *)    
    // properties
    property Progress: Double read GetProgress;
    property ConsecutiveStages: Boolean read GetConsecutiveStages write SetConsecutiveStages;
    property StrictlyGrowing: Boolean read GetStrictlyGrowing write SetStrictlyGrowing;
    property MinProgressDelta: Double read GetMinProgressDelta write SetMinProgressDelta;
    property GlobalSettings: Boolean read GetGlobalSettings write SetGlobalSettings;
    // nodes/(sub)stages
    property Nodes[Index: Integer]: TProgressStageNode read GetNode;
    property StageNodes[Stage: TPTStageID]: TProgressStageNode read GetStageNode;
    property Stages[Stage: TPTStageID]: Double read GetStage write SetStage; default;
    property SubStageCount[Stage: TPTStageID]: Integer read GetSubStageCount;
    property SubStageNodes[Stage: TPTStageID; Index: Integer]: TProgressStageNode read GetSubstageNode;
    property SubStages[Stage: TPTStageID; Index: Integer]: TPTStageID read GetSubStage;
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

Function TProgressStageNode.GetSubStage(Index: Integer): TProgressStageNode;
begin
If CheckIndex(Index) then
  Result := fSubStages[Index]
else
  raise EPTIndexOutOfBounds.CreateFmt('TProgressStageNode.GetSubStage: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.SetConsecutiveStages(Value: Boolean);
var
  i:  Integer;
begin
If fGlobalSettings then
  For i := LowIndex to HighIndex do
    fSubStages[i].ConsecutiveStages := Value;
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
    fSubStages[i].StrictlyGrowing := Value;
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
    fSubStages[i].MinProgressDelta := Value;
If Value <> fMinProgressDelta then
  fMinProgressDelta := LimitValue(Value);
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.SetGlobalSettings(Value: Boolean);
var
  i:  Integer;
begin
For i := LowIndex to HighIndex do
  fSubStages[i].GlobalSettings := Value;
If Value <> fGlobalSettings then
  begin
    fGlobalSettings := Value;
    If fGlobalSettings then
      For i := LowIndex to HighIndex do
        begin
          fSubStages[i].ConsecutiveStages := fConsecutiveStages;
          fSubStages[i].StrictlyGrowing := fStrictlyGrowing;
          fSubStages[i].MinProgressDelta := fMinProgressDelta;
        end;
  end;
end;

{-------------------------------------------------------------------------------
    TProgressStageNode - protected methods
-------------------------------------------------------------------------------}

Function TProgressStageNode.GetCapacity: Integer;
begin
Result := Length(fSubStages);
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.SetCapacity(Value: Integer);
var
  i:  Integer;
begin
If Value >= 0 then
  begin
    If Value <> Length(fSubStages) then
      begin
        If Value < Count then
          For i := Value to HighIndex do
            FreeAndNil(fSubStages[i]);
        SetLength(fSubStages,Value);
      end;
  end
else raise EPTInvalidValue.CreateFmt('TProgressStageNode.SetCapacity: Invalid capacity (%d).',[Value]);
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.GetCount: Integer;
begin
Result := fSubStageCount;
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
  AbsLen := AbsLen + fSubStages[i].AbsoluteLength;
// recalculate relative length, start and progress
RelStart := 0.0;
For i := LowIndex to HighIndex do
  begin
    fSubStages[i].RelativeStart := RelStart;
    If AbsLen <> 0.0 then
      fSubStages[i].RelativeLength := fSubStages[i].AbsoluteLength / AbsLen
    else
      fSubStages[i].RelativeLength := 0.0;
    fSubStages[i].RelativeProgress := fSubStages[i].RelativeLength * fSubStages[i].Progress;
    RelStart := RelStart + fSubStages[i].RelativeLength;
  end;
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.RecalculateProgress(ForceChange: Boolean = False);
var
  i:            Integer;
  NewProgress:  Double;
begin
If (fSubStageCount > 0) and (fUpdateCounter <= 0) then
  begin
    NewProgress := 0.0;
    // recalc relative progress of stages
    For i := LowIndex to HighIndex do
      fSubStages[i].RelativeProgress := fSubStages[i].RelativeLength * fSubStages[i].Progress;
    // get new progress
    For i := HighIndex downto LowIndex do
      If fSubStages[i].Progress <> 0.0 then
        begin
          If fConsecutiveStages then
            begin
              NewProgress := fSubStages[i].RelativeStart + fSubStages[i].RelativeProgress;
              Break{For i};
            end
          else NewProgress := NewProgress + fSubStages[i].RelativeProgress;
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

procedure TProgressStageNode.SubStageProgressHandler(Sender: TObject);
begin
RecalculateProgress;
If (Sender is TProgressStageNode) and Assigned(fOnSubStageProgressEvent) then
  fOnSubStageProgressEvent(Self,TProgressStageNode(Sender).ID,TProgressStageNode(Sender).Progress);
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
fID := PT_STAGEID_INVALID;
fSubStageCount := 0;
SetLEngth(fSubStages,0);
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
fOnSubStageProgressEvent := nil;
fOnSubStageProgressCallBack := nil;
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.Finalize;
begin
// prevent reporting
fOnProgressInternal := nil;
fOnProgressEvent := nil;
fOnProgressCallBack := nil;
fOnSubStageProgressEvent := nil;
fOnSubStageProgressCallBack := nil;
Clear;
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.NewSubStageAt(Index: Integer; AbsoluteLength: Double; ID: TPTStageID);
begin
// do not check index validity
fSubStages[Index] := TProgressStageNode.CreateAsStage(Self,AbsoluteLength,ID);
fSubStages[Index].OnProgressInternal := SubStageProgressHandler;
If fGlobalSettings then
  begin
    fSubStages[Index].StrictlyGrowing := fStrictlyGrowing;
    fSubStages[Index].ConsecutiveStages := fConsecutiveStages;
    fSubStages[Index].MinProgressDelta := fMinProgressDelta;
    fSubStages[Index].GlobalSettings := fGlobalSettings;
  end;
Inc(fSubStageCount);
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

constructor TProgressStageNode.CreateAsStage(SuperStageNode: TProgressStageNode; AbsoluteLength: Double; ID: TPTStageID);
begin
Create;
fSuperStageNode := SuperStageNode;
fAbsoluteLength := Abs(AbsoluteLength);
fID := ID;
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
  fSubStages[i].BeginUpdate;
Result := fUpdateCounter;  
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.EndUpdate: Integer;
var
  i:  Integer;
begin
For i := LowIndex to HighIndex do
  fSubStages[i].EndUpdate;
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
Result := Low(fSubStages);
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.HighIndex: Integer;
begin
Result := Pred(fSubStageCount);
end;
 
//------------------------------------------------------------------------------

Function TProgressStageNode.First: TProgressStageNode;
begin
Result := GetSubStage(LowIndex);
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.Last: TProgressStageNode;
begin
Result := GetSubStage(HighIndex);
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.IndexOf(Node: TProgressStageNode): Integer;
var
  i:  Integer;
begin
Result := -1;
For i := LowIndex to HighIndex do
  If fSubStages[i] = Node then
    begin
      Result := i;
      Break{For i};
    end;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TProgressStageNode.IndexOf(SubStage: TPTStageID): Integer;
var
  i:  Integer;
begin
Result := -1;
For i := LowIndex to HighIndex do
  If fSubStages[i].ID = SubStage then
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

Function TProgressStageNode.Find(SubStage: TPTStageID; out Index: Integer): Boolean;
begin
Index := IndexOf(SubStage);
Result := CheckIndex(Index);
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.Add(AbsoluteLength: Double; ID: TPTStageID = PT_STAGEID_INVALID): Integer;
begin
Grow;
Result := fSubStageCount;
NewSubStageAt(Result,AbsoluteLength,ID);
end;

//------------------------------------------------------------------------------

procedure TProgressStageNode.Insert(Index: Integer; AbsoluteLength: Double; ID: TPTStageID = PT_STAGEID_INVALID);
var
  i:  Integer;
begin
If CheckIndex(Index) then
  begin
    Grow;
    For i := HighIndex downto Index do
      fSubStages[i + 1] := fSubStages[i];
    NewSubStageAt(Index,AbsoluteLength,ID);
  end
else If Index = Count then
  Add(AbsoluteLength,ID)
else
  raise EPTIndexOutOfBounds.CreateFmt('TProgressStageNode.Insert: Index (%d) out of bounds.',[Index]);
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
    Temp := fSubStages[SrcIdx];
    If SrcIdx < DstIdx then
      For i := SrcIdx to Pred(DstIdx) do
        fSubStages[i] := fSubStages[i + 1]
    else
      For i := SrcIdx downto Succ(DstIdx) do
        fSubStages[i] := fSubStages[i - 1];
    fSubStages[DstIdx] := Temp;
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
    Temp := fSubStages[Idx1];
    fSubStages[Idx1] := fSubStages[Idx2];
    fSubStages[Idx2] := Temp;
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
    Result := fSubStages[Index];
    For i := Index to Pred(HighIndex) do
      fSubStages[i] := fSubStages[i + 1];
    Dec(fSubStageCount);
    RecalculateRelations;
    RecalculateProgress(True);
    DoProgress;
    Shrink;
  end
else Result := nil;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TProgressStageNode.Extract(SubStage: TPTStageID): TProgressStageNode;
var
  Index:  Integer;
  i:      Integer;
begin
Index := IndexOf(SubStage);
If CheckIndex(Index) then
  begin
    Result := fSubStages[Index];
    For i := Index to Pred(HighIndex) do
      fSubStages[i] := fSubStages[i + 1];
    Dec(fSubStageCount);
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

Function TProgressStageNode.Remove(SubStage: TPTStageID): Integer;
begin
Result := IndexOf(SubStage);
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
    FreeAndNil(fSubStages[Index]);
    For i := Index to Pred(HighIndex) do
      fSubStages[i] := fSubStages[i + 1];
    Dec(fSubStageCount);
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
  FreeAndNil(fSubStages[i]);
SetLength(fSubStages,0);
fSubStageCount := 0;
fProgress := 0.0;
DoProgress;
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.SetSubStageMaximum(SubStage: TPTStageID; NewValue: UInt64): Boolean;
var
  Index:  Integer;
begin
If Find(SubStage,Index) then
  begin
    fSubStages[Index].Maximum := NewValue;
    Result := True;
  end
else Result := False;
end;
 
//------------------------------------------------------------------------------

Function TProgressStageNode.SetSubStagePosition(SubStage: TPTStageID; NewValue: UInt64): Boolean;
var
  Index:  Integer;
begin
If Find(SubStage,Index) then
  begin
    fSubStages[Index].Position := NewValue;
    Result := True;
  end
else Result := False;
end;
   
//------------------------------------------------------------------------------

Function TProgressStageNode.SetSubStageProgress(SubStage: TPTStageID; NewValue: Double): Boolean;
var
  Index:  Integer;
begin
If Find(SubStage,Index) then
  begin
    fSubStages[Index].Progress := NewValue;
    Result := True;
  end
else Result := False;
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.IsSimpleStage: Boolean;
begin
Result := fSubStageCount <= 0;
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.StageData: TPTStageData;
begin
Result.AbsoluteLength := fAbsoluteLength;
Result.RelativeLength := fRelativeLength;
Result.RelativeStart := fRelativeStart;
Result.RelativeProgress := fRelativeProgress;
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.SubStageLevel: Integer;
begin
If Assigned(fSuperStageNode) then
  Result := fSuperStageNode.SubStageLevel + 1
else
  Result := 0;
end;

//------------------------------------------------------------------------------

Function TProgressStageNode.TotalSubStageCount: Integer;
var
  i:  Integer;
begin
Result := fSubStageCount;
For i := LowIndex to HighIndex do
  Result := Result + fSubStages[i].TotalSubStageCount;
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

Function TProgressTracker.GetProgress: Double;
begin
Result := fMasterNode.Progress;
end;

//------------------------------------------------------------------------------

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

Function TProgressTracker.GetStageNode(Stage: TPTStageID): TProgressStageNode;
begin
If CheckStageID(Stage) then
  Result := fStages[Integer(Stage)]
else
  raise EPTInvalidStageID.CreateFmt('TProgressTracker.GetStageNode: Invalid stage ID (%d).',[Integer(Stage)]);
end;

//------------------------------------------------------------------------------

Function TProgressTracker.GetStage(Stage: TPTStageID): Double;
begin
Result := ObtainStageNode(Stage,False).Progress;
end;

//------------------------------------------------------------------------------

procedure TProgressTracker.SetStage(Stage: TPTStageID; Value: Double);
begin
ObtainStageNode(Stage,False).Progress := Value;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.GetSubStageCount(Stage: TPTStageID): Integer;
var
  StageNode:  TProgressStageNode;
begin
StageNode := ObtainStageNode(Stage,True);
Result := StageNode.Count;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.GetSubStageNode(Stage: TPTStageID; Index: Integer): TProgressStageNode;
var
  StageNode:  TProgressStageNode;
begin
StageNode := ObtainStageNode(Stage,True);
If StageNode.CheckIndex(Index) then
  Result := StageNode[Index]
else
  raise EPTIndexOutOfBounds.CreateFmt('TProgressTracker.GetSubStageNode: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

Function TProgressTracker.GetSubStage(Stage: TPTStageID; Index: Integer): TPTStageID;
begin
Result := GetSubStageNode(Stage,Index).ID;
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
      fOnStageProgressEvent(Self,TProgressStageNode(Sender).ID,Progress);
    If Assigned(fOnStageProgressCallback) then
      fOnStageProgressCallback(Self,TProgressStageNode(Sender).ID,Progress);
  end;
end;

//------------------------------------------------------------------------------

procedure TProgressTracker.Initialize;
begin
fMasterNode := TProgressStageNode.Create;
fMasterNode.ID := PT_STAGEID_MASTER;
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
For i := TPTStageID(Low(fStages)) to TPTStageID(High(fStages)) do
  If not Assigned(fStages[Integer(i)]) then
    begin
      Result := i;
      Exit;
    end;
// if we are here, something really bad has happened
raise EPTException.Create('TProgressTracker.InternalFirstUnassignedStageID: Unable to find any unassigned ID.');
end;

//------------------------------------------------------------------------------

Function TProgressTracker.ResolveNewStageID(StageID: TPTStageID): TPTStageID;
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
    raise EPTAssignedStageID.CreateFmt('TProgressTracker.ResolveStageID: Selected stage ID (%d) already assigned.',[Integer(StageID)]);
end;

//------------------------------------------------------------------------------

Function TProgressTracker.InternalAdd(SuperStageNode: TProgressStageNode; AbsoluteLength: Double; ID: TPTStageID): TPTStageID;
begin
SuperStageNode.BeginUpdate;
try
  ID := ResolveNewStageID(ID);
  fStages[Integer(ID)] := SuperStageNode[SuperStageNode.Add(AbsoluteLength,ID)];
  Inc(fStageCount);
  Result := ID;
finally
  SuperStageNode.EndUpdate;
end;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.InternalInsert(SuperStageNode: TProgressStageNode; Index: Integer; AbsoluteLength: Double; ID: TPTStageID): TPTStageID;
begin
SuperStageNode.BeginUpdate;
try
  ID := ResolveNewStageID(ID);
  SuperStageNode.Insert(Index,AbsoluteLength,ID);
  fStages[Integer(ID)] := SuperStageNode[Index];
  Inc(fStageCount);
  Result := ID;
finally
  SuperStageNode.EndUpdate;
end;
end;

//------------------------------------------------------------------------------

procedure TProgressTracker.InternalDelete(SuperStageNode: TProgressStageNode; Index: Integer);
begin
SuperStageNode.BeginUpdate;
try
  fStages[Integer(SuperStageNode[Index].ID)] := nil;
  Dec(fStageCount,SuperStageNode[Index].TotalSubStageCount + 1);
  SuperStageNode.Delete(Index);
finally
  SuperStageNode.EndUpdate;
end;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.ObtainStageNode(Stage: TPTStageID; AllowMaster: Boolean): TProgressStageNode;
begin
If not(AllowMaster and (Stage = PT_STAGEID_MASTER)) then
  begin
    If CheckStageID(Stage) then
      begin
        If Assigned(fStages[Integer(Stage)]) then
          Result := fStages[Integer(Stage)]
        else
          raise EPTUnassignedStageID.CreateFmt('TProgressTracker.ObtainStageNode: Unassigned stage ID (%d).',[Integer(Stage)]);
      end
    else raise EPTInvalidStageID.CreateFmt('TProgressTracker.ObtainStageNode: Invalid stage ID (%d).',[Integer(Stage)]);
  end
else Result := fMasterNode;
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
If Length(fStages) > 0 then
  Result := TPTStageID(High(fStages))
else
  Result := PT_STAGEID_INVALID;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.LowSubStageIndex(Stage: TPTStageID): Integer;
begin
Result := ObtainStageNode(Stage,True).LowIndex;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.HighSubStageIndex(Stage: TPTStageID): Integer;
begin
Result := ObtainStageNode(Stage,True).HighIndex;
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
If StageID <> PT_STAGEID_MASTER then
  begin
    If CheckStageID(StageID) then
      Result := Assigned(fStages[Integer(StageID)])
    else
      Result := False;
  end
else Result := True;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.CheckSubStageIndex(Stage: TPTStageID; Index: Integer): Boolean;
begin
Result := ObtainStageNode(Stage,True).CheckIndex(Index);
end;

//------------------------------------------------------------------------------

Function TProgressTracker.CheckSubStageID(Stage,SubStageID: TPTStageID): Boolean;
var
  Index:  Integer;
begin
Result := ObtainStageNode(Stage,True).Find(SubStageID,Index);
end;

//------------------------------------------------------------------------------

Function TProgressTracker.NodeIndexFromStageID(StageID: TPTStageID): Integer;
var
  i:  Integer;
begin
Result := -1;
i := Low(fStages);
If StageIDAssigned(StageID) then
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
Result := PT_STAGEID_INVALID;
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

Function TProgressTracker.IndexOf(Stage: TPTStageID; out SuperStage: TPTStageID): Integer;
begin
Result := -1;
SuperStage := PT_STAGEID_INVALID;
If StageIDAssigned(Stage) then
  If Assigned(fStages[Integer(Stage)].SuperStageNode) then
    begin
      SuperStage := fStages[Integer(Stage)].SuperStageNode.ID;
      If StageIDAssigned(SuperStage) then
        Result := fStages[Integer(Stage)].SuperStageNode.IndexOf(Stage);
    end;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TProgressTracker.IndexOf(Stage: TPTStageID): Integer;
var
  SuperStage: TPTStageID;
begin
Result := IndexOf(Stage,SuperStage);
end;

//------------------------------------------------------------------------------

Function TProgressTracker.IndexOfIn(SuperStage,Stage: TPTStageID): Integer;
var
  SuperStageNode: TProgressStageNode;
begin
If StageIDAssigned(SuperStage) then
  begin
    SuperStageNode := ObtainStageNode(SuperStage,True);
    Result := SuperStageNode.IndexOf(Stage);
  end
else Result := -1;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.Add(AbsoluteLength: Double; ID: TPTStageID = PT_STAGEID_INVALID): TPTStageID;
begin
Result := InternalAdd(fMasterNode,AbsoluteLength,ID);
end;

//------------------------------------------------------------------------------

Function TProgressTracker.AddIn(SuperStage: TPTStageID; AbsoluteLength: Double; ID: TPTStageID = PT_STAGEID_INVALID): TPTStageID;
begin
Result := InternalAdd(ObtainStageNode(SuperStage,True),AbsoluteLength,ID);
end;

//------------------------------------------------------------------------------

Function TProgressTracker.Insert(InsertStage: TPTStageID; AbsoluteLength: Double; ID: TPTStageID = PT_STAGEID_INVALID): TPTStageID;
var
  SuperStageNode: TProgressStageNode;
begin
SuperStageNode := ObtainStageNode(SuperStageOf(InsertStage),True);
Result := InternalInsert(SuperStageNode,SuperStageNode.IndexOf(InsertStage),AbsoluteLength,ID)
end;

//------------------------------------------------------------------------------

Function TProgressTracker.InsertIn(SuperStage,InsertStage: TPTStageID; AbsoluteLength: Double; ID: TPTStageID = PT_STAGEID_INVALID): TPTStageID;
var
  SuperStageNode: TProgressStageNode;
  Index:          Integer;
begin
SuperStageNode := ObtainStageNode(SuperStage,True);
If SuperStageNode.Find(InsertStage,Index) then
  Result := InternalInsert(SuperStageNode,Index,AbsoluteLength,ID)
else
  raise EPTNotSubStageOf.CreateFmt('TProgressTracker.InsertIn: Stage %d is not a substage of stage %d.',[Integer(InsertStage),Integer(SuperStage)]);
end;

//------------------------------------------------------------------------------

Function TProgressTracker.InsertInAt(SuperStage: TPTStageID; Index: Integer; AbsoluteLength: Double; ID: TPTStageID = PT_STAGEID_INVALID): TPTStageID;
var
  SuperStageNode: TProgressStageNode;
begin
SuperStageNode := ObtainStageNode(SuperStage,True);
If SuperStageNode.CheckIndex(Index) or (Index = SuperStageNode.Count) then
  Result := InternalInsert(SuperStageNode,Index,AbsoluteLength,ID)
else
  raise EPTIndexOutOfBounds.CreateFmt('TProgressTracker.InsertInAt: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

Function TProgressTracker.Remove(Stage: TPTStageID; out SuperStage: TPTStageID): Integer;
var
  SuperStageNode: TProgressStageNode;
begin
Result := IndexOf(Stage,SuperStage);
If Result >= 0 then // no need to check SuperStage, it was checked in IndexOf
  begin
    SuperStageNode := ObtainStageNode(SuperStage,True);
    If SuperStageNode.CheckIndex(Result) then
      InternalDelete(SuperStageNode,Result);
  end;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TProgressTracker.Remove(Stage: TPTStageID): Integer;
var
  SuperStage: TPTStageID;
begin
Result := Remove(Stage,SuperStage);
end;

//------------------------------------------------------------------------------

Function TProgressTracker.RemoveIn(SuperStage,Stage: TPTStageID): Integer;
var
  SuperStageNode: TProgressStageNode;
begin
Result := IndexOfIn(SuperStage,Stage);
If Result >= 0 then
  begin
    SuperStageNode := ObtainStageNode(SuperStage,True);
    If SuperStageNode.CheckIndex(Result) then
      InternalDelete(SuperStageNode,Result);
  end;
end;

//------------------------------------------------------------------------------

procedure TProgressTracker.Delete(Stage: TPTStageID);
var
  Index:      Integer;
  SuperStage: TPTStageID;
begin
Index := IndexOf(Stage,SuperStage);
If Index >= 0 then
  InternalDelete(ObtainStageNode(SuperStage,True),Index)
else
  raise EPTInvalidStageID.CreateFmt('TProgressTracker.Delete: Invalid stage ID (%d).',[Integer(Stage)]);
end;

//------------------------------------------------------------------------------

procedure TProgressTracker.DeleteIn(SuperStage: TPTStageID; Stage: TPTStageID);
var
  SuperStageNode: TProgressStageNode;
  Index:          Integer;
begin
SuperStageNode := ObtainStageNode(SuperStage,True);
If SuperStageNode.Find(Stage,Index) then
  InternalDelete(SuperStageNode,Index)
else
  raise EPTNotSubStageOf.CreateFmt('TProgressTracker.DeleteIn: Stage %d is not a substage of stage %d.',[Integer(Stage),Integer(SuperStage)]);
end;

//------------------------------------------------------------------------------

procedure TProgressTracker.DeleteInAt(SuperStage: TPTStageID; Index: Integer);
var
  SuperStageNode: TProgressStageNode;
begin
SuperStageNode := ObtainStageNode(SuperStage,True);
If SuperStageNode.CheckIndex(Index) then
  InternalDelete(SuperStageNode,Index)
else
  raise EPTIndexOutOfBounds.CreateFmt('TProgressTracker.DeleteInAt: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

procedure TProgressTracker.Clear(Stage: TPTStageID = PT_STAGEID_INVALID);
var
  Node: TProgressStageNode;
  i:    Integer;
begin
If CheckStageID(Stage) then
  begin
    // clear a specified node
    Node := ObtainStageNode(Stage,False);
    Dec(fStageCount,Node.TotalSubStageCount);
    For i := Node.LowIndex to Node.HighIndex do
      fStages[Integer(Node[i].ID)] := nil;
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

Function TProgressTracker.IsSimpleStage(Stage: TPTStageID): Boolean;
begin
Result := ObtainStageNode(Stage,False).IsSimpleStage;
end;
 
//------------------------------------------------------------------------------

Function TProgressTracker.IsSubstageOf(SubStage,Stage: TPTStageID): Boolean;
var
  Index: Integer;
begin
Result := ObtainStageNode(Stage,True).Find(SubStage,Index);
end;
   
//------------------------------------------------------------------------------

Function TProgressTracker.IsSuperStageOf(SuperStage,Stage: TPTStageID): Boolean;
begin
with ObtainStageNode(Stage,False) do
  begin
    If Assigned(SuperStageNode) then
      Result := SuperStageNode.ID = SuperStage
    else
      Result := False;
  end
end;
 
//------------------------------------------------------------------------------

Function TProgressTracker.SuperStageOf(Stage: TPTStageID): TPTStageID;
begin
with ObtainStageNode(Stage,False) do
  begin
    If Assigned(SuperStageNode) then
      Result := SuperStageNode.ID
    else
      Result := PT_STAGEID_INVALID;
  end;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.StagePath(Stage: TPTStageID; IncludeMaster: Boolean = False): TPTStageArray;
var
  Node:   TProgressStageNode;
  i:      Integer;
begin
// preallocate result array
Node := ObtainStageNode(Stage,False);
If IncludeMaster then
  SetLength(Result,Node.SubStageLevel + 1)
else
  SetLength(Result,Node.SubStageLevel);
// store the IDs
For i := High(Result) downto Low(Result) do
  begin
    Result[i] := Node.ID;
    Node := Node.SuperStageNode;
  end;
end;

//------------------------------------------------------------------------------

procedure TProgressTracker.StageTree(Tree: TStrings; TreeSettings: TPTTreeSettings);
begin
{$message 'implement stagetree'}
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure TProgressTracker.StageTree(Tree: TStrings);
begin
StageTree(Tree,PT_TREESETTINGS_DEFAULT);
end;

//------------------------------------------------------------------------------

Function TProgressTracker.GetStageMaximum(Stage: TPTStageID): UInt64;
begin
Result := ObtainStageNode(Stage,False).Maximum;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.SetStageMaximum(Stage: TPTStageID; Maximum: UInt64): UInt64;
var
  Node: TProgressStageNode;
begin
Node := ObtainStageNode(Stage,False);
Result := Node.Maximum;
Node.Maximum := Maximum;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.GetStagePosition(Stage: TPTStageID): UInt64;
begin
Result := ObtainStageNode(Stage,False).Position;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.SetStagePosition(Stage: TPTStageID; Position: UInt64): UInt64;
var
  Node: TProgressStageNode;
begin
Node := ObtainStageNode(Stage,False);
Result := Node.Position;
Node.Position := Position;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.GetStageProgress(Stage: TPTStageID): Double;
begin
Result := ObtainStageNode(Stage,False).Progress;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.SetStageProgress(Stage: TPTStageID; Progress: Double): Double;
var
  Node: TProgressStageNode;
begin
Node := ObtainStageNode(Stage,False);
Result := Node.Progress;
Node.Progress := Progress;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.GetStageReporting(Stage: TPTStageID): Boolean;
var
  Node: TProgressStageNode;
begin
Node := ObtainStageNode(Stage,False);
Result := TMethod(Node.OnProgress).Code = @TProgressTracker.OnStageProgressHandler;
end;

//------------------------------------------------------------------------------

Function TProgressTracker.SetStageReporting(Stage: TPTStageID; StageReporting: Boolean): Boolean;
var
  Node: TProgressStageNode;
begin
Node := ObtainStageNode(Stage,False);
Result := TMethod(Node.OnProgress).Code = @TProgressTracker.OnStageProgressHandler;
If StageReporting then
  Node.OnProgress := OnStageProgressHandler
else
  Node.OnProgress := nil;
end;

end.
