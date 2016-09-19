{ JCC (Jan's Chess Componenents) - This file contains classes to handle chess position
  Copyright (C) 2016  Jan Dette

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
}

unit Position;

{$DEFINE LOGGING}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, RegExpr, ArrayTools, MoveList, Pieces, StrTools, BitBoard
  {$IFDEF Logging} , EpikTimer {$ENDIF}  ;

{$INCLUDE ChessPieceLetters.inc}

type
  // Constants are taken from http://chessprogramming.wikispaces.com/10x12+Board
  // Main resource is https://de.wikipedia.org/wiki/Schachprogramm#12.C3.9710-Darstellung

  TCastlingTypes = (ctWKingside, ctWQueenside, ctBKingside, ctBQueenside);

  TCastlingAbility = set of TCastlingTypes;

  // The following allows more control over the output of the function MoveToSAN
  // Based on https://en.wikipedia.org/wiki/Algebraic_notation_%28chess%29

  // Example: csNone: Be5, csColon: B:e5, csColonSuffix: Be5:, csx: Bxe5
  TCaptureSymbol = (csNone, csColon, csColonSuffix, csx);
  // Example: psNone: e8Q, psEqualSign: e8=Q, psBrackets: e8(Q), psSlash: e8/Q
  TPromotionSymbol = (psNone, psEqualSign, psBrackets, psSlash);

  EInvalidFEN = class(Exception);

  { TPosition }

  TPosition = class
  private
  protected
    FBlackWins: TNotifyEvent;
    FDraw: TNotifyEvent;
    FLegalMoves: TMoveList;
    FMoveNumber: integer;
    FWhitesTurn: boolean;
    FWhiteWins: TNotifyEvent;
  const
    DiagonalMoves = [9, 11];   // Too bad, that negative values are not allowed
    HorzVertMoves = [1, 10];
    KnightMoves = [8, 12, 19, 21];

    procedure BlackWins;
    procedure Draw;
    procedure GenerateLegalMoves; virtual; abstract;
    function GetCountOfFiles: byte; virtual; abstract;
    function GetCountOfRanks: byte; virtual; abstract;
    function GetSquares(Index: integer): TPieceType; virtual; abstract;
    procedure WhiteWins;
  public
    // Copies important values from Source to Self
    procedure Copy(Source: TPosition); virtual;
    function IsLegal(AMove: TMove): boolean; virtual;
    procedure PlayMove(AMove: TMove); virtual; abstract;
    procedure SetupInitialPosition; virtual; abstract;
  public
    property CountOfFiles: byte read GetCountOfFiles;
    property CountOfRanks: byte read GetCountOfRanks;
    property LegalMoves: TMoveList read FLegalMoves;
    property MoveNumber: integer read FMoveNumber write FMoveNumber;
    property OnBlackWins: TNotifyEvent read FBlackWins write FBlackWins;
    property OnDraw: TNotifyEvent read FDraw write FDraw;
    property OnWhiteWins: TNotifyEvent read FWhiteWins write FWhiteWins;
    property Squares[Index: integer]: TPieceType read GetSquares;
    property WhitesTurn: boolean read FWhitesTurn write FWhitesTurn;
  end;


  { TStandardPosition }

  TStandardPosition = class(TPosition)//(TPersistent)
  private
  var      // Note: If Variables are added, they need to be added to Assign, too
    FBlackKing: TSquare10x12;
    FCastlingAbility: TCastlingAbility;
    FEnPassant: TSquare10x12;
    FOnChange: TNotifyEvent;
    FPliesSinceLastPawnMoveOrCapture: integer; // Important for 50 move rule
    FSquares: array[0..119] of TPieceType;
    FWhiteKing: TSquare10x12;
    // BitBoards
    // Pawns, Rooks, Knights, Bishops, Queens, Kings, White, Black
    FBitBoards: array[1..8] of QWord;

    procedure Changed;
    // Checks if the side not to move is attacking the given square
    function IsAttacked(Square: TSquare10x12): boolean;
    procedure SilentFromFEN(const AFEN: string);
    // Plays the move without triggering Changed
    procedure SilentPlayMove(AMove: TMove);
  protected
    procedure GenerateLegalMoves; override;
    function GetCountOfFiles: byte; override;
    function GetCountOfRanks: byte; override;
    function GetSquares(Index: integer): TPieceType; override;
  public
  const
    InitialFEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

    constructor Create;
    constructor Create(AFEN: string);
    procedure Copy(Source: TPosition); override;
    destructor Destroy; override;
    // Returns a sub list of LegalMoves with those moves which fulfill the parameters
    function FilterLegalMoves(APiece: TPieceType = ptEmpty;
      StartSquare: TSquare10x12 = 0; DestSquare: TSquare10x12 = 0;
      APromotionPiece: TPieceType = ptEmpty): TMoveList;
    procedure FromFEN(const AFEN: string);
    // Checks if the side to move is check
    function IsCheck: boolean;
    // Checks if the side not to move is in check
    function IsIllegalCheck: boolean;
    function IsMate: boolean;
    function IsStaleMate: boolean;
    function IsValid: boolean;
    function MoveFromSAN(ASAN: string): TMove;
    // This uses the english piece letters
    function MoveToSAN(AMove: TMove; ShowPawnLetter: boolean = False;
      ShowEnPassantSuffix: boolean = False; CaptureSymbol: TCaptureSymbol = csx;
      PromotionSymbol: TPromotionSymbol = psNone): string;
    function MoveToSAN(AMove: TMove; PieceLetters: TChessPieceLetters;
      ShowPawnLetter: boolean = False; ShowEnPassantSuffix: boolean = False;
      CaptureSymbol: TCaptureSymbol = csx;
      PromotionSymbol: TPromotionSymbol = psNone): string;
    procedure PlayMove(AMove: TMove); override;
    procedure SetupInitialPosition; override;
    function ToFEN: string;
  public
    property CastlingAbility: TCastlingAbility
      read FCastlingAbility write FCastlingAbility;
    property EnPassant: TSquare10x12 read FEnPassant write FEnPassant;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property PliesSinceLastPawnMoveOrCapture: integer
      read FPliesSinceLastPawnMoveOrCapture write FPliesSinceLastPawnMoveOrCapture;
  end;

    {$IFDEF Logging}
var
  Zuege: longword = 0;
  Zeit: extended = 0;
  ET: TEpikTimer;

    {$ENDIF}

// Returns a Bitboard with zeroes and a 1 at the given position
function SquareToBitBoard(const ASquare: TSquare10x12): QWord;

implementation

function SquareToBitBoard(const ASquare: TSquare10x12): QWord;
var
  Temp: TSquare8x8;
begin
  if ASquare in OffSquares then
    Result := 0
  else
  begin
    Temp := ASquare;
    // Result := QWord(1) shl (8 * (8 - ASquare.RRank) + ASquare.RFile - 1);
    Result := Ranks[Temp.RRank] and Files[Temp.RFile];
  end;
end;

{ TPosition }

procedure TPosition.BlackWins;
begin
  if Assigned(FBlackWins) then
    FBlackWins(Self);
end;

procedure TPosition.Draw;
begin
  if Assigned(FDraw) then
    FDraw(Self);
end;

procedure TPosition.WhiteWins;
begin
  if Assigned(FWhiteWins) then
    FWhiteWins(Self);
end;

procedure TPosition.Copy(Source: TPosition);
var
  Move: TMove;
begin
  FMoveNumber := Source.FMoveNumber;
  FWhitesTurn := Source.FWhitesTurn;
  FLegalMoves.Clear;
  for Move in Source.FLegalMoves do
    FLegalMoves.Add(Move);
end;

function TPosition.IsLegal(AMove: TMove): boolean;
begin
  Result := AMove in LegalMoves;
end;

{ TStandardPosition }

procedure TStandardPosition.Changed;
begin
  GenerateLegalMoves;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TStandardPosition.Copy(Source: TPosition);
var
  i: integer;
begin
  inherited Copy(Source);
  if Source is TStandardPosition then
  begin
    FCastlingAbility := TStandardPosition(Source).FCastlingAbility;
    FEnPassant := TStandardPosition(Source).FEnPassant;
    FPliesSinceLastPawnMoveOrCapture :=
      TStandardPosition(Source).FPliesSinceLastPawnMoveOrCapture;
    for i := 0 to 119 do
      FSquares[i] := TStandardPosition(Source).FSquares[i];
    FBlackKing := TStandardPosition(Source).FBlackKing;
    FWhiteKing := TStandardPosition(Source).FWhiteKing;
    for i := 1 to 8 do
      FBitBoards[i] := TStandardPosition(Source).FBitBoards[i];
  end;
end;

procedure TStandardPosition.GenerateLegalMoves;
var
  // Useful variables
  BlackPiecesWithoutKing: QWord;
  WhitePiecesWithoutKing: QWord;
  Empty: QWord;
  WP, WR, WN, WB, WQ, WK: QWord;
  BP, BR, BN, BB, BQ, BK: QWord;

  procedure GenerateBishopMoves(Start: TSquare10x12);
  var
    i, j, Dest: integer;
    Sign: integer;
    Flag: boolean;
  begin
    for j := 1 to 2 do
    begin
      if j = 1 then
        Sign := 1
      else
        Sign := -1;
      for i in DiagonalMoves do
      begin
        Dest := Start + Sign * i;
        Flag := False;
        while (FSquares[Dest] <> ptOff) and not Flag do
        begin
          if (FSquares[Dest] = ptEmpty) then
          begin
            FLegalMoves.Add(CreateMove(Start, Dest));
            Dest := Dest + Sign * i;
          end
          else
          begin
            if not SameColor(FSquares[Start], FSquares[Dest]) then
              FLegalMoves.Add(CreateMove(Start, Dest));
            Flag := True;
          end;
        end;
      end;
    end;
  end;

  procedure GenerateCastlingMoves(Start: TSquare10x12);
  begin
    // Check Castlings
    if FWhitesTurn then
    begin
      if (ctWKingside in FCastlingAbility) and not IsAttacked(Start) and
        (FSquares[96] = ptEmpty) and (FSquares[97] = ptEmpty) and not
        IsAttacked(96) and not IsAttacked(97) then
        FLegalMoves.Add(CreateMove(Start, 97));
      if (ctWQueenside in FCastlingAbility) and not IsAttacked(Start) and
        (Fsquares[94] = ptEmpty) and (FSquares[93] = ptEmpty) and
        (FSquares[92] = ptEmpty) and not IsAttacked(94) and not IsAttacked(93) then
        FLegalMoves.Add(CreateMove(Start, 93));
    end
    else
    begin
      if (ctBKingside in FCastlingAbility) and not IsAttacked(Start) and
        (FSquares[26] = ptEmpty) and (FSquares[27] = ptEmpty) and not
        IsAttacked(26) and not IsAttacked(27) then
        FLegalMoves.Add(CreateMove(Start, 27));
      if (ctBQueenside in FCastlingAbility) and not IsAttacked(Start) and
        (Fsquares[24] = ptEmpty) and (FSquares[23] = ptEmpty) and
        (FSquares[22] = ptEmpty) and not IsAttacked(24) and not IsAttacked(23) then
        FLegalMoves.Add(CreateMove(Start, 23));
    end;
  end;

  procedure GenerateKingMoves(Start: TSquare10x12);
  var
    i, j, Sign, Dest: integer;
  begin
    for j := 1 to 2 do
    begin
      if j = 1 then
        Sign := 1
      else
        Sign := -1;
      for i in (HorzVertMoves + DiagonalMoves) do
      begin
        Dest := Start + Sign * i;
        if (FSquares[Dest] <> ptOff) and ((FSquares[Dest] = ptEmpty) or
          not SameColor(FSquares[Start], FSquares[Dest])) then
          FLegalMoves.Add(CreateMove(Start, Dest));
      end;
    end;
  end;

  procedure GenerateKnightMoves(Start: TSquare10x12);
  var
    i, j, Sign, Dest: integer;
  begin
    for j := 1 to 2 do
    begin
      if j = 1 then
        Sign := 1
      else
        Sign := -1;
      for i in KnightMoves do
      begin
        Dest := Start + Sign * i;
        if (FSquares[Dest] <> ptOff) and ((FSquares[Dest] = ptEmpty) or
          not SameColor(FSquares[Start], FSquares[Dest])) then
          FLegalMoves.Add(CreateMove(Start, Dest));
      end;
    end;
  end;

  procedure GeneratePawnPromotionMoves(AMoveList: TMoveList);
  var
    temp: TMoveList;
    Piece: TBasicPieceType;
    i: integer;
    Start, Dest: TSquare10x12;
  begin
    temp := TMoveList.Create;
    i := 0;
    while i < AMoveList.Count do
    begin
      Start := AMoveList.Items[i].Start;
      Dest := AMoveList.Items[i].Dest;
      if (FWhitesTurn and (Start in Rank7) and (FSquares[Start] = ptWPawn)) or
        (not FWhitesTurn and (Start in Rank2) and (FSquares[Start] = ptBPawn)) then
      begin
        for Piece in [bptRook, bptKnight, bptBishop, bptQueen] do
          temp.Add(CreateMove(Start, Dest, PieceType(Piece, FWhitesTurn)));
        AMoveList.Delete(i);
      end
      else
        Inc(i);
    end;
    AMoveList.AddList(temp);
    FreeAndNil(temp);
  end;

  procedure GeneratePawnCaptureMoves;
  var
    i, Trail: integer;
    PawnMoves: QWord;
  begin
    if FWhitesTurn then
    begin
      // White pawn captures to the right
      PawnMoves := ((WP and not Files[8]) shr 7) and
        (BlackPiecesWithoutKing or SquareToBitBoard(FEnPassant));
      Trail := NumberOfTrailingZeroes(PawnMoves);
      PawnMoves := PawnMoves shr Trail;
      if PawnMoves > 0 then
      begin
        for i := 0 to 63 - NumberOfLeadingZeroes(PawnMoves) do
        begin
          if (PawnMoves and 1) = 1 then
            FLegalMoves.Add(CreateMoveFromInt(Trail + i + 7, Trail + i));
          PawnMoves := PawnMoves shr 1;
        end;
      end;
      // White pawn captures to the left
      PawnMoves := ((WP and not Files[1]) shr 9) and
        (BlackPiecesWithoutKing or SquareToBitBoard(FEnPassant));
      Trail := NumberOfTrailingZeroes(PawnMoves);
      PawnMoves := PawnMoves shr Trail;
      if PawnMoves > 0 then
      begin
        for i := 0 to 63 - NumberOfLeadingZeroes(PawnMoves) do
        begin
          if (PawnMoves and 1) = 1 then
            FLegalMoves.Add(CreateMoveFromInt(Trail + i + 9, Trail + i));
          PawnMoves := PawnMoves shr 1;
        end;
      end;
    end
    else
    begin
      // Black pawn captures to the right
      PawnMoves := ((BP and not Files[8]) shl 9) and
        (WhitePiecesWithoutKing or SquareToBitBoard(FEnPassant));
      Trail := NumberOfTrailingZeroes(PawnMoves);
      PawnMoves := PawnMoves shr Trail;
      if PawnMoves > 0 then
      begin
        for i := 0 to 63 - NumberOfLeadingZeroes(PawnMoves) do
        begin
          if (PawnMoves and 1) = 1 then
            FLegalMoves.Add(CreateMoveFromInt(Trail + i - 9, Trail + i));
          PawnMoves := PawnMoves shr 1;
        end;
      end;
      // Black pawn captures to the left
      PawnMoves := ((BP and not Files[1]) shl 7) and
        (WhitePiecesWithoutKing or SquareToBitBoard(FEnPassant));
      Trail := NumberOfTrailingZeroes(PawnMoves);
      PawnMoves := PawnMoves shr Trail;
      if PawnMoves > 0 then
      begin
        for i := 0 to 63 - NumberOfLeadingZeroes(PawnMoves) do
        begin
          if (PawnMoves and 1) = 1 then
            FLegalMoves.Add(CreateMoveFromInt(Trail + i - 7, Trail + i));
          PawnMoves := PawnMoves shr 1;
        end;
      end;
    end;
  end;

  procedure GeneratePawnForwardMoves;
  var
    Sign, i, Trail: integer;
    PawnMoves: Qword;
  begin
    if FWhitesTurn then
    begin
      // White pawn goes one forward
      PawnMoves := (WP shr 8) and Empty;
      Trail := NumberOfTrailingZeroes(PawnMoves);
      PawnMoves := PawnMoves shr Trail;
      if PawnMoves > 0 then
      begin
        for i := 0 to 63 - NumberOfLeadingZeroes(PawnMoves) do
        begin
          if (PawnMoves and 1) = 1 then
            FLegalMoves.Add(CreateMoveFromInt(Trail + i + 8, Trail + i));
          PawnMoves := PawnMoves shr 1;
        end;
      end;
      // White pawn goes two forward
      PawnMoves := ((WP and Ranks[2]) shr 16) and Empty and (Empty shr 8);
      Trail := NumberOfTrailingZeroes(PawnMoves);
      PawnMoves := PawnMoves shr Trail;
      if PawnMoves > 0 then
      begin
        for i := 0 to 63 - NumberOfLeadingZeroes(PawnMoves) do
        begin
          if (PawnMoves and 1) = 1 then
            FLegalMoves.Add(CreateMoveFromInt(Trail + i + 16, Trail + i));
          PawnMoves := PawnMoves shr 1;
        end;
      end;
    end
    else
    begin
      // Black pawn goes one forward
      PawnMoves := (BP shl 8) and Empty;
      Trail := NumberOfTrailingZeroes(PawnMoves);
      PawnMoves := PawnMoves shr Trail;
      if PawnMoves > 0 then
      begin
        for i := 0 to 63 - NumberOfLeadingZeroes(PawnMoves) do
        begin
          if (PawnMoves and 1) = 1 then
            FLegalMoves.Add(CreateMoveFromInt(Trail + i - 8, Trail + i));
          PawnMoves := PawnMoves shr 1;
        end;
      end;
      // Black pawn goes two forward
      PawnMoves := ((WP and Ranks[2]) shl 16) and Empty and (Empty shl 8);
      Trail := NumberOfTrailingZeroes(PawnMoves);
      PawnMoves := PawnMoves shr Trail;
      if PawnMoves > 0 then
      begin
        for i := 0 to 63 - NumberOfLeadingZeroes(PawnMoves) do
        begin
          if (PawnMoves and 1) = 1 then
            FLegalMoves.Add(CreateMoveFromInt(Trail + i - 16, Trail + i));
          PawnMoves := PawnMoves shr 1;
        end;
      end;
    end;
  end;

  procedure GenerateRookMoves(Start: TSquare10x12);
  var
    i, j, Dest, Sign: integer;
    Flag: boolean;
  begin
    for j := 1 to 2 do
    begin
      if j = 1 then
        Sign := 1
      else
        Sign := -1;
      for i in HorzVertMoves do
      begin
        Dest := Start + Sign * i;
        Flag := False;
        while (FSquares[Dest] <> ptOff) and not Flag do
        begin
          if (FSquares[Dest] = ptEmpty) then
          begin
            // Empty Square
            FLegalMoves.Add(CreateMove(Start, Dest));
            Dest := Dest + Sign * i;
          end
          else
          begin
            if not SameColor(FSquares[Start], FSquares[Dest]) then
              FLegalMoves.Add(CreateMove(Start, Dest));
            Flag := True;
          end;
        end;
      end;
    end;
  end;

var
  i: byte;
  j: integer;
  BSquares: array[0..119] of TPieceType;
  BCastlingAbility: TCastlingAbility;
  BEnPassant: TSquare10x12;
  BPliesSinceLastPawnMoveOrCapture: integer;
  BMoveNumer: integer;
  BBlackKing, BWhiteKing: TSquare10x12;
  b, c, tb, tc: extended;
  Temp: boolean;
  {$IFDEF Logging}
  a: extended;
  {$ENDIF}
begin
  // Initiliaze variables
  WP := FBitBoards[1] and FBitBoards[7];
  WR := FBitBoards[2] and FBitBoards[7];
  WN := FBitBoards[3] and FBitBoards[7];
  WB := FBitBoards[4] and FBitBoards[7];
  WQ := FBitBoards[5] and FBitBoards[7];
  WK := FBitBoards[6] and FBitBoards[7];
  BP := FBitBoards[1] and FBitBoards[8];
  BR := FBitBoards[2] and FBitBoards[8];
  BN := FBitBoards[3] and FBitBoards[8];
  BB := FBitBoards[4] and FBitBoards[8];
  BQ := FBitBoards[5] and FBitBoards[8];
  BK := FBitBoards[6] and FBitBoards[8];
  BlackPiecesWithoutKing := FBitBoards[8] and not BK;
  WhitePiecesWithoutKing:= FBitBoards[7] and not WK;
  Empty := not (FBitBoards[7] or FBitBoards[8]);
  //a := ET.Elapsed;
  tb := 0;
  tc := 0;
  // The following takes up to 1 ms, could this be made faster?
  {$IFDEF Logging}
  ET.Start;
  a := ET.Elapsed;
{$ENDIF}
  FLegalMoves.Clear;
  {$IFDEF Logging}
  b := ET.Elapsed;
  {$ENDIF}
  GeneratePawnCaptureMoves;
  GeneratePawnForwardMoves;
  {$IFDEF Logging}
  tb := tb + ET.Elapsed - b;
  {$ENDIF}
  for i in ValidSquares do
  begin
    // First check if there is a piece with the right color
    if (FSquares[i] = ptEmpty) or not (((Ord(FSquares[i]) and 128) = 0) =
      FWhitesTurn) then
      Continue;
    // Then, generate pseudo-legal moves
    case FSquares[i] of
      ptWKnight, ptBKnight:
      begin
        GenerateKnightMoves(i);
      end;
      ptWBishop, ptBBishop:
      begin
        GenerateBishopMoves(i);
      end;
      ptWRook, ptBRook:
      begin
        GenerateRookMoves(i);
      end;
      ptWQueen, ptBQueen:
      begin
        GenerateRookMoves(i);
        GenerateBishopMoves(i);
      end;
      ptWKing, ptBKing:
      begin
        GenerateKingMoves(i);
        GenerateCastlingMoves(i);
      end;
    end;
  end;
  // Backup Position, Play Move, Position Valid?
  j := 0;
  Temp := IsCheck;
  // Backup current Position
  BEnPassant := FEnPassant;
  BPliesSinceLastPawnMoveOrCapture := FPliesSinceLastPawnMoveOrCapture;
  BCastlingAbility := FCastlingAbility;
  BMoveNumer := FMoveNumber;
  BBlackKing := FBlackKing;
  BWhiteKing := FWhiteKing;
  for i := 0 to 119 do
    BSquares[i] := FSquares[i];
  while j < FLegalMoves.Count do
  begin
    Self.SilentPlayMove(FLegalMoves.Items[j]);
    {$IFDEF Logging}
    c := ET.Elapsed;
    {$ENDIF}
    if not Self.IsIllegalCheck then
      Inc(j)
    else
      FLegalMoves.Delete(j);
    {$IFDEF Logging}
    tc := tc + ET.Elapsed - c;
    {$ENDIF}
    // Restore inital values
    FEnPassant := BEnPassant;
    FPliesSinceLastPawnMoveOrCapture := BPliesSinceLastPawnMoveOrCapture;
    FCastlingAbility := BCastlingAbility;
    for i := 0 to 119 do
      FSquares[i] := BSquares[i];
    FMoveNumber := BMoveNumer;
    FBlackKing := BBlackKing;
    FWhiteKing := BWhiteKing;
    FWhitesTurn := not FWhitesTurn;
  end;
  Write(' 1: ', FormatFloat('0.##', (tb) * 1000000), 'µs');
  Write('  2: ', FormatFloat('0.##', (tc) * 1000000), 'µs');
  Writeln('  Total: ', FormatFloat('0.##', (ET.Elapsed - a) * 1000000), 'µs');

  // TODO: Replace pawn moves with actual promotion moves
  GeneratePawnPromotionMoves(FLegalMoves);
  {$IFDEF Logging}
  Inc(Zuege, FLegalMoves.Count);
  Zeit := Zeit + (ET.Elapsed - a);
  ET.Stop;
{$ENDIF}
end;

function TStandardPosition.GetCountOfFiles: byte;
begin
  Result := 8;
end;

function TStandardPosition.GetCountOfRanks: byte;
begin
  Result := 8;
end;

function TStandardPosition.GetSquares(Index: integer): TPieceType;
begin
  Result := FSquares[Index];
end;

function TStandardPosition.IsAttacked(Square: TSquare10x12): boolean;
var
  dest: TSquare10x12;
  i, j, n, Sign: integer;
  LDiag, SDiag, LHorz, SHorz, Knights: set of TPieceType;
  Flag: boolean;
begin
  if FWhitesTurn then
  begin
    LDiag := [ptBQueen, ptBBishop];
    SDiag := [ptBQueen, ptBBishop, ptBPawn, ptBKing];
    LHorz := [ptBQueen, ptBRook];
    SHorz := [ptBQueen, ptBRook, ptBKing];
    Knights := [ptBKnight];
  end
  else
  begin
    LDiag := [ptWQueen, ptWBishop];
    SDiag := [ptWQueen, ptWBishop, ptWPawn, ptWKing];
    LHorz := [ptWQueen, ptWRook];
    SHorz := [ptWQueen, ptWRook, ptWKing];
    Knights := [ptWKnight];
  end;
  Result := False;
  // Basically we go in all directions vertical/horizontal, diagonal
  // and we check knight moves
  for j := 1 to 2 do
  begin
    if j = 1 then
      Sign := 1
    else
      Sign := -1;
    for i in HorzVertMoves do
    begin
      n := 1;
      Dest := Square + Sign * i;
      Flag := False;
      while (FSquares[Dest] <> ptOff) and not Flag do
      begin
        if (FSquares[Dest] = ptEmpty) then
        begin
          Dest := Dest + Sign * i;
          Inc(n);
        end
        else
        begin
          if not SameColor(FSquares[Square], FSquares[Dest]) then
          begin
            if n = 1 then
            begin
              Result := FSquares[Dest] in SHorz;
            end
            else
              Result := FSquares[Dest] in LHorz;
            if Result then
              Exit;
          end;
          Flag := True;
        end;
      end;
    end;
  end;
  for j := 1 to 2 do
  begin
    if j = 1 then
      Sign := 1
    else
      Sign := -1;
    for i in DiagonalMoves do
    begin
      n := 1;
      Dest := Square + Sign * i;
      Flag := False;
      while (FSquares[Dest] <> ptOff) and not Flag do
      begin
        if (FSquares[Dest] = ptEmpty) then
        begin
          Dest := Dest + Sign * i;
          Inc(n);
        end
        else
        begin
          if not SameColor(FSquares[Square], FSquares[Dest]) then
          begin
            if n = 1 then
            begin
              // make sure that the pawn goes in the right direction
              if FWhitesTurn = (Sign = -1) then
              begin
                Result := FSquares[Dest] in SDiag;
              end
              else
                Result := FSquares[Dest] in (SDiag - [ptBPawn, ptWPawn]);
            end
            else
              Result := FSquares[Dest] in LDiag;
            if Result then
              Exit;
          end;
          Flag := True;
        end;
      end;
    end;
  end;
  for j := 1 to 2 do
  begin
    if j = 1 then
      Sign := 1
    else
      Sign := -1;
    for i in KnightMoves do
    begin
      Dest := Square + Sign * i;
      if (FSquares[Dest] <> ptOff) and not SameColor(FSquares[Square],
        FSquares[Dest]) then
      begin
        Result := FSquares[Dest] in Knights;
        if Result then
          exit;
      end;
    end;
  end;
end;

procedure TStandardPosition.SilentFromFEN(const AFEN: string);
var
  c: char;
  s, p: TStringList;
  rk, fl, i, Coordinate: TSquare10x12;
  temp: string;
  RegFEN: TRegExpr;
begin
  RegFEN := TRegExpr.Create;
  RegFEN.Expression := '(([prnbqkPRNBQK1-8]){1,8}\/){7}([prnbqkPRNBQK1-8]){1,8} ' +
    '(w|b) (KQ?k?q?|Qk?q?|kq?|q|-) (-|([a-h][36])) (0|[1-9][0-9]*) [1-9][0-9]*';
  if not RegFEN.Exec(AFEN) then
    raise EInvalidFEN.Create('FEN is invalid');
  FreeAndNil(RegFEN);
  s := Split(AFEN, ' ');
  // Put Pieces on board
  for i in ValidSquares do
    FSquares[i] := ptEmpty;
  p := Split(s.Strings[0], '/');
  for rk := 0 to 7 do
  begin
    temp := p.Strings[rk];
    fl := 1;
    for i := 1 to Length(temp) do
    begin
      Coordinate := rk * 10 + 20 + fl;
      if FSquares[Coordinate] = ptOff then
        raise EInvalidFEN.Create('FEN is invalid');
      case temp[i] of
        '1'..'8': Inc(fl, StrToInt(temp[i]) - 1);
        'p':
        begin
          FSquares[Coordinate] := ptBPawn;
          FBitBoards[1] := FBitBoards[1] or SquareToBitBoard(Coordinate);
          FBitBoards[8] := FBitBoards[8] or SquareToBitBoard(Coordinate);
        end;
        'r':
        begin
          FSquares[Coordinate] := ptBRook;
          FBitBoards[2] := FBitBoards[2] or SquareToBitBoard(Coordinate);
          FBitBoards[8] := FBitBoards[8] or SquareToBitBoard(Coordinate);
        end;
        'n':
        begin
          FSquares[Coordinate] := ptBKnight;
          FBitBoards[3] := FBitBoards[3] or SquareToBitBoard(Coordinate);
          FBitBoards[8] := FBitBoards[8] or SquareToBitBoard(Coordinate);
        end;
        'b':
        begin
          FSquares[Coordinate] := ptBBishop;
          FBitBoards[4] := FBitBoards[4] or SquareToBitBoard(Coordinate);
          FBitBoards[8] := FBitBoards[8] or SquareToBitBoard(Coordinate);
        end;
        'q':
        begin
          FSquares[Coordinate] := ptBQueen;
          FBitBoards[5] := FBitBoards[5] or SquareToBitBoard(Coordinate);
          FBitBoards[8] := FBitBoards[8] or SquareToBitBoard(Coordinate);
        end;
        'k':
        begin
          FSquares[Coordinate] := ptBKing;
          FBitBoards[6] := FBitBoards[6] or SquareToBitBoard(Coordinate);
          FBitBoards[8] := FBitBoards[8] or SquareToBitBoard(Coordinate);
          FBlackKing := Coordinate;
        end;
        'P':
        begin
          FSquares[Coordinate] := ptWPawn;
          FBitBoards[1] := FBitBoards[1] or SquareToBitBoard(Coordinate);
          FBitBoards[7] := FBitBoards[7] or SquareToBitBoard(Coordinate);
        end;
        'R':
        begin
          FSquares[Coordinate] := ptWRook;
          FBitBoards[2] := FBitBoards[2] or SquareToBitBoard(Coordinate);
          FBitBoards[7] := FBitBoards[7] or SquareToBitBoard(Coordinate);
        end;
        'N':
        begin
          FSquares[Coordinate] := ptWKnight;
          FBitBoards[3] := FBitBoards[3] or SquareToBitBoard(Coordinate);
          FBitBoards[7] := FBitBoards[7] or SquareToBitBoard(Coordinate);
        end;
        'B':
        begin
          FSquares[Coordinate] := ptWBishop;
          FBitBoards[4] := FBitBoards[4] or SquareToBitBoard(Coordinate);
          FBitBoards[7] := FBitBoards[7] or SquareToBitBoard(Coordinate);
        end;
        'Q':
        begin
          FSquares[Coordinate] := ptWQueen;
          FBitBoards[5] := FBitBoards[5] or SquareToBitBoard(Coordinate);
          FBitBoards[7] := FBitBoards[7] or SquareToBitBoard(Coordinate);
        end;
        'K':
        begin
          FSquares[Coordinate] := ptWKing;
          FBitBoards[6] := FBitBoards[6] or SquareToBitBoard(Coordinate);
          FBitBoards[7] := FBitBoards[7] or SquareToBitBoard(Coordinate);
          FWhiteKing := Coordinate;
        end;
      end;
      Inc(fl);
    end;
  end;
  {$IFDEF Logging}
  for i := 1 to 8 do
    WriteLn(BitBoardToStr(FBitBoards[i]));
  {$ENDIF}
  FreeAndNil(p);
  // Determine who's to play
  FWhitesTurn := s.Strings[1] = 'w';
  // Determine allowed Castlings
  FCastlingAbility := [];
  for c in s.Strings[2] do
    case c of
      'K': FCastlingAbility := FCastlingAbility + [ctWKingside];
      'Q': FCastlingAbility := FCastlingAbility + [ctWQueenside];
      'k': FCastlingAbility := FCastlingAbility + [ctBKingside];
      'q': FCastlingAbility := FCastlingAbility + [ctBQueenside];
    end;
  // Is en passant possible?
  if s.Strings[3] = '-' then
    FEnPassant := 0
  else
    FEnPassant := AlgebraicSquare(s.Strings[3][1], s.Strings[3][2]);
  // Get plies
  FPliesSinceLastPawnMoveOrCapture := StrToInt(s.Strings[4]);
  // Get start move number
  FMoveNumber := StrToInt(s.Strings[5]);
  FreeAndNil(s);
end;

procedure TStandardPosition.SilentPlayMove(AMove: TMove);
var
  Start, Dest: TSquare10x12;
  CastlingRook: TPieceType;
begin
  Start := AMove.Start;
  Dest := AMove.Dest;
  if FSquares[Start] in [ptEmpty, ptOff] then
    raise Exception.Create('Invalid Start square given!');

  if (FSquares[Start] in [ptWPawn, ptBPawn]) or (FSquares[Dest] <> ptEmpty) then
    FPliesSinceLastPawnMoveOrCapture := 0
  else
    Inc(FPliesSinceLastPawnMoveOrCapture);

  if FSquares[Start] in [ptWBishop, ptWKnight, ptWRook, ptWQueen,
    ptBBishop, ptBKnight, ptBRook, ptBQueen] then
  begin
    FSquares[Dest] := FSquares[Start];
    FSquares[Start] := ptEmpty;
    FEnPassant := 0;
  end
  else
  if FSquares[Start] in [ptWPawn, ptBPawn] then
  begin
    // Promotion
    if (Dest in Rank1) or (Dest in Rank8) then
    begin
      FSquares[Dest] := AMove.PromotionPiece;
      FSquares[Start] := ptEmpty;
    end
    else
    // En Passant
    if Dest = FEnPassant then
    begin
      FSquares[Dest] := FSquares[Start];
      FSquares[Start] := ptEmpty;
      if Dest in Rank3 then
        FSquares[Dest - 10] := ptEmpty
      else
        FSquares[Dest + 10] := ptEmpty;
    end
    else
      // Normal move
    begin
      FSquares[Dest] := FSquares[Start];
      FSquares[Start] := ptEmpty;
      // Set FEnPassant accordingly
      if ((Dest > Start) and (Dest - Start = 20)) then
        FEnPassant := Start + 10
      else
      if ((Start > Dest) and (Start - Dest = 20)) then
        FEnPassant := Start - 10
      else
        FEnPassant := 0;
    end;
  end
  else
  begin
    // King moves
    CastlingRook := PieceType(bptRook, FSquares[Start] in WhitePieces);
    // Kingside castling
    if ((Dest > Start) and (Dest - Start = 2)) then
    begin
      FSquares[Start + 1] := CastlingRook;
      FSquares[Dest] := FSquares[Start];
      FSquares[Start] := ptEmpty;
      FSquares[Dest + 1] := ptEmpty;
    end
    else
    // Queenside castling
    if ((Dest < Start) and (Start - Dest = 2)) then
    begin
      FSquares[Start - 1] := CastlingRook;
      FSquares[Dest] := FSquares[Start];
      FSquares[Start] := ptEmpty;
      FSquares[Dest - 2] := ptEmpty;
    end
    else
    begin
      FSquares[Dest] := FSquares[Start];
      FSquares[Start] := ptEmpty;
    end;
    if WhitesTurn then
      FWhiteKing := Dest
    else
      FBlackKing := Dest;
  end;
  if (ctWKingside in FCastlingAbility) and ((FSquares[95] <> ptWKing) or
    (FSquares[98] <> ptWRook)) then
    FCastlingAbility := FCastlingAbility - [ctWKingside];
  if (ctWQueenside in FCastlingAbility) and ((FSquares[95] <> ptWKing) or
    (FSquares[91] <> ptWRook)) then
    FCastlingAbility := FCastlingAbility - [ctWQueenside];
  if (ctBKingside in FCastlingAbility) and ((FSquares[25] <> ptBKing) or
    (FSquares[28] <> ptBRook)) then
    FCastlingAbility := FCastlingAbility - [ctBKingside];
  if (ctBQueenside in FCastlingAbility) and ((FSquares[25] <> ptBKing) or
    (FSquares[21] <> ptBRook)) then
    FCastlingAbility := FCastlingAbility - [ctBQueenside];
  if not FWhitesTurn then
    Inc(FMoveNumber);
  FWhitesTurn := not FWhitesTurn;
end;

constructor TStandardPosition.Create;
var
  Coordinate: integer;
begin
  FLegalMoves := TMoveList.Create;
  for Coordinate := 0 to 119 do
    if Coordinate in OffSquares then
      FSquares[Coordinate] := ptOff
    else
      FSquares[Coordinate] := ptEmpty;
end;

constructor TStandardPosition.Create(AFEN: string);
begin
  Create;
  FromFEN(AFEN);
end;

destructor TStandardPosition.Destroy;
begin
  FreeAndNil(FLegalMoves);
  inherited Destroy;
end;

function TStandardPosition.FilterLegalMoves(APiece: TPieceType;
  StartSquare: TSquare10x12; DestSquare: TSquare10x12;
  APromotionPiece: TPieceType): TMoveList;
var
  NoFilterPiece, NoFilterStart, NoFilterDest, NoFilterPromo: boolean;
  Move: TMove;
begin
  NoFilterPiece := APiece = ptEmpty;
  NoFilterStart := StartSquare = 0;
  NoFilterDest := DestSquare = 0;
  NoFilterPromo := APromotionPiece = ptEmpty;
  Result := TMoveList.Create;
  for Move in FLegalMoves do
  begin
    if (NoFilterPiece or (FSquares[TSquare10x12(Move.Start)] = APiece)) and
      (NoFilterStart or (Move.Start = StartSquare)) and
      (NoFilterDest or (Move.Dest = DestSquare)) and
      (NoFilterPromo or (Move.PromotionPiece = APromotionPiece)) then
      Result.Add(Move);
  end;
end;

procedure TStandardPosition.FromFEN(const AFEN: string);
begin
  SilentFromFEN(AFEN);
  Changed;
end;

function TStandardPosition.IsCheck: boolean;
begin
  if FWhitesTurn then
    Result := IsAttacked(FWhiteKing)
  else
    Result := IsAttacked(FBlackKing);
end;

function TStandardPosition.IsIllegalCheck: boolean;
begin
  FWhitesTurn := not FWhitesTurn;
  Result := IsCheck;
  FWhitesTurn := not FWhitesTurn;
end;

function TStandardPosition.IsMate: boolean;
begin
  Result := (FLegalMoves.Count = 0) and IsCheck;
end;

function TStandardPosition.IsStaleMate: boolean;
begin
  Result := (FLegalMoves.Count = 0) and not IsCheck;
end;

function TStandardPosition.IsValid: boolean;
var
  // Count white and black pieces in order p, r, n, b, q, k
  WhitePieces, BlackPieces: array[1..6] of integer;
  i: integer;
begin
  Result := True;
  for i := 1 to 6 do
  begin
    WhitePieces[i] := 0;
    BlackPieces[i] := 0;
  end;
  // Check correct count of pieces, i. e. not more than 32
  for i in ValidSquares do
    case FSquares[i] of
      ptWPawn: Inc(WhitePieces[1]);
      ptWKnight: Inc(WhitePieces[2]);
      ptWBishop: Inc(WhitePieces[3]);
      ptWRook: Inc(WhitePieces[4]);
      ptWQueen: Inc(WhitePieces[5]);
      ptWKing: Inc(WhitePieces[6]);
      ptBPawn: Inc(BlackPieces[1]);
      ptBKnight: Inc(BlackPieces[2]);
      ptBBishop: Inc(BlackPieces[3]);
      ptBRook: Inc(BlackPieces[4]);
      ptBQueen: Inc(BlackPieces[5]);
      ptBKing: Inc(BlackPieces[6]);
    end;
  Result := Result and (WhitePieces[6] = 1) and (BlackPieces[6] = 1) and
    (WhitePieces[1] <= 8) and (BlackPieces[1] <= 8) and
    (SumOf(WhitePieces) <= 16) and (SumOf(BlackPieces) <= 16);
  // Check if CastlingAbilities are set correct
  if ctWKingside in FCastlingAbility then
    Result := Result and (FSquares[95] = ptWKing) and (FSquares[98] = ptWRook);
  if ctWQueenside in FCastlingAbility then
    Result := Result and (FSquares[95] = ptWKing) and (FSquares[91] = ptWRook);
  if ctBKingside in FCastlingAbility then
    Result := Result and (FSquares[25] = ptBKing) and (FSquares[28] = ptBRook);
  if ctBQueenside in FCastlingAbility then
    Result := Result and (FSquares[25] = ptBKing) and (FSquares[21] = ptBRook);
  // Check if a king is in illegal check
  Result := Result and not IsIllegalCheck;
end;

function TStandardPosition.MoveFromSAN(ASAN: string): TMove;
var
  i: integer;
  NotValid: boolean;
begin
  NotValid := True;
  // This is one way, but SAN is not unique
  for i := 0 to FLegalMoves.Count - 1 do
  begin
    if MoveToSAN(FLegalMoves.Items[i]) = ASAN then
    begin
      Result := FLegalMoves.Items[i];
      NotValid := False;
    end;
  end;
  if NotValid then
    raise Exception.Create(ASAN + ' is no valid move.');
end;

function TStandardPosition.MoveToSAN(AMove: TMove; ShowPawnLetter: boolean;
  ShowEnPassantSuffix: boolean; CaptureSymbol: TCaptureSymbol;
  PromotionSymbol: TPromotionSymbol): string;
begin
  Result := MoveToSAN(AMove, PieceLetters_EN, ShowPawnLetter,
    ShowEnPassantSuffix, CaptureSymbol, PromotionSymbol);
end;

function TStandardPosition.MoveToSAN(AMove: TMove; PieceLetters: TChessPieceLetters;
  ShowPawnLetter: boolean; ShowEnPassantSuffix: boolean;
  CaptureSymbol: TCaptureSymbol; PromotionSymbol: TPromotionSymbol): string;

  function PieceToStr(Piece: TPieceType): string;
  begin
    case Piece of
      ptWPawn:
      begin
        if ShowPawnLetter then
          Result := PieceLetters[1]
        else
          Result := '';
      end;
      ptWKnight: Result := PieceLetters[2];
      ptWBishop: Result := PieceLetters[3];
      ptWRook: Result := PieceLetters[4];
      ptWQueen: Result := PieceLetters[5];
      ptWKing: Result := PieceLetters[6];
      ptBPawn:
      begin
        if ShowPawnLetter then
          Result := PieceLetters[7]
        else
          Result := '';
      end;
      ptBKnight: Result := PieceLetters[8];
      ptBBishop: Result := PieceLetters[9];
      ptBRook: Result := PieceLetters[10];
      ptBQueen: Result := PieceLetters[11];
      ptBKing: Result := PieceLetters[12];
    end;

  end;

var
  SameDest: TMoveList;
  Piece: TPieceType;
  j: integer;
  Distinguished: boolean;
  Clone: TStandardPosition;
  Castling: boolean;
  AppendColon: boolean;
begin
  SameDest := TMoveList.Create;
  Clone := TStandardPosition.Create;
  Piece := FSquares[TSquare10x12(AMove.Start)];
  Castling := False;
  AppendColon := False;
  case Piece of
    ptWKing, ptBKing:
    begin
      // Handle kingside castling
      if ((AMove.Start = 95) and (AMove.Dest = 97)) or
        ((AMove.Start = 25) and (AMove.Dest = 27)) then
      begin
        Result := 'O-O';
        Castling := True;
      end
      else
      // Handle queenside castling
      if ((AMove.Start = 95) and (AMove.Dest = 93)) or
        ((AMove.Start = 25) and (AMove.Dest = 23)) then
      begin
        Result := 'O-O-O';
        Castling := True;
      end
      else
      begin
        Result := PieceToStr(Piece);
      end;
    end;
    else // every other piece could be multiple times on the board
    begin
      Result := PieceToStr(Piece);
      for j := 0 to FLegalMoves.Count - 1 do
      begin
        // Check if there is another piece of the same kind, which can go to the current square
        if (AMove.Start <> FLegalMoves.Items[j].Start) and
          (FLegalMoves.Items[j].Dest = AMove.Dest) and
          (FSquares[TSquare10x12(FLegalMoves.Items[j].Start)] = Piece) then
          SameDest.Add(FLegalMoves.Items[j]);
      end;
      if SameDest.Count > 0 then  // We need to distinguish
      begin
        Distinguished := True;
        // Check if we can distinguish by file
        for j := 0 to SameDest.Count - 1 do
        begin
          Distinguished := Distinguished and
            (SameDest.Items[j].Start.RFile <> AMove.Start.RFile);
        end;
        if Distinguished then
          Result := Result + TAlgebraicSquare(AMove.Start).RFile
        else
        begin
          Distinguished := True;
          // Check if we can distinguish by rank
          for j := 0 to SameDest.Count - 1 do
          begin
            Distinguished :=
              Distinguished and (SameDest.Items[j].Start.RRank <> AMove.Start.RRank);
          end;
          if Distinguished then
            Result := Result + TAlgebraicSquare(AMove.Start).RRank
          else
            // We cannot distinguish, so we need the whole square
            Result := Result + SquareToString(AMove.Start);
        end;
      end;
    end;
  end;
  if not Castling then
  begin
    // Check if dest is occupied or a pawn is taken en passant
    if (FSquares[TSquare10x12(AMove.Dest)] <> ptEmpty) or
      ((Piece in [ptWPawn, ptBPawn]) and (TSquare10x12(AMove.Dest) = FEnPassant)) then
    begin
      if (Piece in [ptWPawn, ptBPawn]) and (Length(Result) = 0) then
        Result := Result + TAlgebraicSquare(AMove.Start).RFile;
      case CaptureSymbol of
        csNone: ;// Do nothing
        csColon: Result := Result + ':';
        csColonSuffix: AppendColon := True;
        csx: Result := Result + 'x';
      end;
    end;
    Result := Result + SquareToString(AMove.Dest);
    // Add colon if desired
    if AppendColon then
      Result := Result + ':';
    // Optionally add 'e.p.' if it is an en passant move
    if ShowEnPassantSuffix and (Piece in [ptWPawn, ptBPawn]) and
      (TSquare10x12(AMove.Dest) = FEnPassant) then
    begin
      Result := Result + 'e.p.';
    end;
    // Check for promotion
    if AMove.PromotionPiece <> ptEmpty then
    begin
      case PromotionSymbol of
        psNone: Result := Result + PieceToStr(AMove.PromotionPiece);
        psEqualSign: Result := Result + '=' + PieceToStr(AMove.PromotionPiece);
        psBrackets: Result := Result + '(' + PieceToStr(AMove.PromotionPiece) + ')';
        psSlash: Result := Result + '/' + PieceToStr(AMove.PromotionPiece);
      end;
    end;
  end;
  // Look for check and mate
  Clone.Copy(Self);
  Clone.PlayMove(AMove);
  if Clone.IsCheck then
  begin
    if Clone.LegalMoves.Count > 0 then
      Result := Result + '+'
    else
      Result := Result + '#';
  end;
  SameDest.Clear;
  Clone.Free;
  SameDest.Free;
end;

procedure TStandardPosition.PlayMove(AMove: TMove);
begin
  SilentPlayMove(AMove);
  Changed;
  if IsMate then
    if WhitesTurn then
      BlackWins
    else
      WhiteWins;
  if IsStaleMate then
    Draw;
end;

procedure TStandardPosition.SetupInitialPosition;
begin
  FromFEN(InitialFEN);
end;

function TStandardPosition.ToFEN: string;
var
  i, z, j: integer;
begin
  Result := '';
  // Piece placement
  for i := 2 to 9 do
  begin
    z := 0;
    for j := 1 to 8 do
    begin
      if FSquares[10 * i + j] = ptEmpty then
        Inc(z)
      else
      begin
        if z > 0 then
          Result := Result + IntToStr(z);
        case FSquares[10 * i + j] of
          ptWPawn: Result := Result + 'P';
          ptWKnight: Result := Result + 'N';
          ptWBishop: Result := Result + 'B';
          ptWRook: Result := Result + 'R';
          ptWQueen: Result := Result + 'Q';
          ptWKing: Result := Result + 'K';
          ptBPawn: Result := Result + 'p';
          ptBKnight: Result := Result + 'n';
          ptBBishop: Result := Result + 'b';
          ptBRook: Result := Result + 'r';
          ptBQueen: Result := Result + 'q';
          ptBKing: Result := Result + 'k';
        end;
        z := 0;
      end;
    end;
    if z > 0 then
      Result := Result + IntToStr(z);
    if i < 9 then
      Result := Result + '/';
  end;
  // Active color
  if FWhitesTurn then
    Result := Result + ' w '
  else
    Result := Result + ' b ';
  // Castiling availity
  if FCastlingAbility = [] then
    Result := Result + '-'
  else
  begin
    if ctWKingside in FCastlingAbility then
      Result := Result + 'K';
    if ctWQueenside in FCastlingAbility then
      Result := Result + 'Q';
    if ctBKingside in FCastlingAbility then
      Result := Result + 'k';
    if ctBQueenside in FCastlingAbility then
      Result := Result + 'q';
  end;
  Result := Result + ' ';
  // En passant
  if FEnPassant in ValidSquares then
    Result := Result + SquareToString(FEnPassant)
  else
    Result := Result + '-';
  Result := Result + ' ';
  // Halfmove clock
  Result := Result + IntToStr(FPliesSinceLastPawnMoveOrCapture) + ' ';
  // Fullmove number
  Result := Result + IntToStr(FMoveNumber);
end;

end.
