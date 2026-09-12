unit uFormula;

// A small, self-contained calculator for user-defined transformations:
// the user types a plain-text math expression, it gets compiled ONCE into
// a tiny expression tree, and that tree is then evaluated as many times as
// needed (e.g. once per data point, or once per row of a file) without
// re-parsing the text.
//
// Two ways to evaluate a compiled TFormula:
//  - Evaluate(X, Y, I, N) - X, Y = a point's own values, I = point index,
//    N = point count). TFormula.Create(Expression) compiles for exactly
//    these four variable names.
//  - Evaluate(Names, Values) - general form: any variable used in the
//    formula is looked up by name (case-insensitive) in the supplied
//    Names/Values pair. TFormula.Create(Expression, ValidVars) compiles
//    against an explicit, caller-chosen set of allowed names - e.g. a
//    file reader compiling a per-column formula against 'A','B','C',...
//    A name used in the formula that ISN'T in ValidVars is a compile-time
//    error (Valid = False); a name that's valid but missing at evaluation
//    time (e.g. a short row without that many columns) quietly reads as 0.
//
// Supported syntax:
//   Numbers      : 1  2.5  1e-3  1.2E5
//   Variables    : whatever names the caller allows (case-insensitive)
//   Operators    : +  -  *  /  ^ (power)         and unary minus
//   Parentheses  : ( ... )
//   Constants    : pi
//   Functions    : sin cos tan asin acos atan
//                  exp ln log10 sqrt abs sign sqr round trunc frac
//                  (one argument each, e.g. sqrt(X))
//
// Precedence (highest to lowest): function call / parentheses, ^ (right-
// associative), unary minus, * and /, + and -.  So -2^2 = -4 and
// 2^3^2 = 2^(3^2) = 512, matching common calculator/scripting conventions.

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Math;

type
  EFormulaError = class(Exception);

  TStringArray = array of String;
  TDoubleArray = array of Double;

  TExprNode = class
  public
    function Eval(const Names: array of String; const Values: array of Double): Double; virtual; abstract;
  end;

  { TFormula }
  TFormula = class
  private
    FExpression: String;
    FRoot: TExprNode;
    FValid: Boolean;
    FErrorMessage: String;
    FValidVars: TStringArray; // allowed variable names for THIS formula

    // Tokenizer state
    FSrc: String;
    FPos: Integer;
    FTokKind: (tkEnd, tkNumber, tkIdent, tkSymbol);
    FTokText: String;
    FTokValue: Double;

    procedure NextToken;
    procedure Expect(const Sym: String);
    function IsValidVarName(const Name: String): Boolean;

    // Recursive-descent parser, one level per precedence tier
    function ParseExpr: TExprNode;      // + -
    function ParseTerm: TExprNode;      // * /
    function ParseUnary: TExprNode;     // unary -
    function ParsePower: TExprNode;     // ^
    function ParsePrimary: TExprNode;   // numbers, variables, functions, ( )

    procedure Compile(const Expression: String);
  public
    // Compiles against the fixed variable set X, Y, I, N
    constructor Create(const Expression: String); overload;
    // Compiles against an explicit, caller-chosen set of variable names
    constructor Create(const Expression: String; const ValidVars: array of String); overload;
    destructor Destroy; override;

    function Evaluate(X, Y: Double; I, N: Integer): Double; overload;
    function Evaluate(const Names: array of String; const Values: array of Double): Double; overload;

    property Expression: String read FExpression;
    // False if the expression didn't parse - Evaluate then always returns 0
    property Valid: Boolean read FValid;
    // Human-readable reason when Valid = False; empty otherwise
    property ErrorMessage: String read FErrorMessage;
  end;

// Check for UI validation, without keeping the compiled formula around
// Returns True and clears ErrorMsg if Expr parses cleanly against ValidVars
function TryCompileFormula(const Expr: String; const ValidVars: array of String; out ErrorMsg: String): Boolean;

implementation

var
  // Always parse numeric literals with '.' as the decimal point,
  // regardless of the OS locale (which might use ',' instead)
  FInvariantFormat: TFormatSettings;

// AST node classes

type
  TConstNode = class(TExprNode)
  public
    Value: Double;
    constructor Create(AValue: Double);
    function Eval(const Names: array of String; const Values: array of Double): Double; override;
  end;

  TVarNode = class(TExprNode)
  public
    Name: String; // matched against Names case-insensitively at Eval time
    constructor Create(const AName: String);
    function Eval(const Names: array of String; const Values: array of Double): Double; override;
  end;

  TUnaryMinusNode = class(TExprNode)
  public
    Operand: TExprNode;
    constructor Create(AOperand: TExprNode);
    destructor Destroy; override;
    function Eval(const Names: array of String; const Values: array of Double): Double; override;
  end;

  TBinOpNode = class(TExprNode)
  public
    Op: Char; // '+' '-' '*' '/' '^'
    Left, Right: TExprNode;
    constructor Create(AOp: Char; ALeft, ARight: TExprNode);
    destructor Destroy; override;
    function Eval(const Names: array of String; const Values: array of Double): Double; override;
  end;

  TFuncNode = class(TExprNode)
  public
    FuncName: String; // already lowercased
    Arg: TExprNode;
    constructor Create(const AFuncName: String; AArg: TExprNode);
    destructor Destroy; override;
    function Eval(const Names: array of String; const Values: array of Double): Double; override;
  end;

constructor TConstNode.Create(AValue: Double);
begin
  inherited Create;
  Value := AValue;
end;

function TConstNode.Eval(const Names: array of String; const Values: array of Double): Double;
begin
  Result := Value;
end;

constructor TVarNode.Create(const AName: String);
begin
  inherited Create;
  Name := AName;
end;

function TVarNode.Eval(const Names: array of String; const Values: array of Double): Double;
var
  j: Integer;
begin
  // A name that's valid but not supplied for this particular evaluation
  Result := 0.0;
  for j := 0 to High(Names) do
    if SameText(Names[j], Name) then
    begin
      Result := Values[j];
      Exit;
    end;
end;

constructor TUnaryMinusNode.Create(AOperand: TExprNode);
begin
  inherited Create;
  Operand := AOperand;
end;

destructor TUnaryMinusNode.Destroy;
begin
  Operand.Free;
  inherited Destroy;
end;

function TUnaryMinusNode.Eval(const Names: array of String; const Values: array of Double): Double;
begin
  Result := -Operand.Eval(Names, Values);
end;

constructor TBinOpNode.Create(AOp: Char; ALeft, ARight: TExprNode);
begin
  inherited Create;
  Op := AOp;
  Left := ALeft;
  Right := ARight;
end;

destructor TBinOpNode.Destroy;
begin
  Left.Free;
  Right.Free;
  inherited Destroy;
end;

function TBinOpNode.Eval(const Names: array of String; const Values: array of Double): Double;
var
  L, R: Double;
begin
  L := Left.Eval(Names, Values);
  R := Right.Eval(Names, Values);
  case Op of
    '+': Result := L + R;
    '-': Result := L - R;
    '*': Result := L * R;
    '/':
      if R = 0.0 then
        Result := NaN // no crash on divide-by-zero - let the caller decide what to do with it
      else
        Result := L / R;
    '^':
      if (L < 0.0) and (Frac(R) <> 0.0) then
        Result := NaN // e.g. (-2)^0.5 has no real result
      else if (L = 0.0) and (R < 0.0) then
        Result := NaN
      else
        Result := Power(L, R);
  else
    Result := NaN;
  end;
end;

constructor TFuncNode.Create(const AFuncName: String; AArg: TExprNode);
begin
  inherited Create;
  FuncName := LowerCase(AFuncName);
  Arg := AArg;
end;

destructor TFuncNode.Destroy;
begin
  Arg.Free;
  inherited Destroy;
end;

function TFuncNode.Eval(const Names: array of String; const Values: array of Double): Double;
var
  A: Double;
begin
  A := Arg.Eval(Names, Values);
  if FuncName = 'sin' then Result := Sin(A)
  else if FuncName = 'cos' then Result := Cos(A)
  else if FuncName = 'tan' then Result := Tan(A)
  else if FuncName = 'asin' then Result := ArcSin(A)
  else if FuncName = 'acos' then Result := ArcCos(A)
  else if FuncName = 'atan' then Result := ArcTan(A)
  else if FuncName = 'exp' then Result := Exp(A)
  else if FuncName = 'ln' then
  begin
    if A > 0.0 then Result := Ln(A) else Result := NaN;
  end
  else if FuncName = 'log10' then
  begin
    if A > 0.0 then Result := Log10(A) else Result := NaN;
  end
  else if FuncName = 'sqrt' then
  begin
    if A >= 0.0 then Result := Sqrt(A) else Result := NaN;
  end
  else if FuncName = 'abs' then Result := Abs(A)
  else if FuncName = 'sign' then Result := Math.Sign(A)
  else if FuncName = 'sqr' then Result := Sqr(A)
  else if FuncName = 'round' then Result := Round(A)
  else if FuncName = 'trunc' then Result := Trunc(A)
  else if FuncName = 'frac' then Result := Frac(A)
  else
    Result := NaN; // unreachable: unknown functions are rejected at parse time
end;

{ ---- Tokenizer --------------------------------------------------------- }

procedure TFormula.NextToken;
var
  Start: Integer;
begin
  while (FPos <= Length(FSrc)) and (FSrc[FPos] in [' ', #9]) do
    Inc(FPos);

  if FPos > Length(FSrc) then
  begin
    FTokKind := tkEnd;
    FTokText := '';
    Exit;
  end;

  // Number: digits, optional decimal point, optional exponent
  if (FSrc[FPos] in ['0'..'9', '.']) then
  begin
    Start := FPos;
    while (FPos <= Length(FSrc)) and (FSrc[FPos] in ['0'..'9', '.']) do
      Inc(FPos);
    if (FPos <= Length(FSrc)) and (FSrc[FPos] in ['e', 'E']) then
    begin
      Inc(FPos);
      if (FPos <= Length(FSrc)) and (FSrc[FPos] in ['+', '-']) then
        Inc(FPos);
      while (FPos <= Length(FSrc)) and (FSrc[FPos] in ['0'..'9']) do
        Inc(FPos);
    end;
    FTokText := Copy(FSrc, Start, FPos - Start);
    if not TryStrToFloat(FTokText, FTokValue, FInvariantFormat) then
      raise EFormulaError.CreateFmt('"%s" is not a valid number', [FTokText]);
    FTokKind := tkNumber;
    Exit;
  end;

  // Identifier: variable or function name
  if (FSrc[FPos] in ['A'..'Z', 'a'..'z', '_']) then
  begin
    Start := FPos;
    while (FPos <= Length(FSrc)) and (FSrc[FPos] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
      Inc(FPos);
    FTokText := Copy(FSrc, Start, FPos - Start);
    FTokKind := tkIdent;
    Exit;
  end;

  // Single-character operator/punctuation
  if FSrc[FPos] in ['+', '-', '*', '/', '^', '(', ')', ','] then
  begin
    FTokText := FSrc[FPos];
    Inc(FPos);
    FTokKind := tkSymbol;
    Exit;
  end;

  raise EFormulaError.CreateFmt('Unexpected character "%s"', [FSrc[FPos]]);
end;

procedure TFormula.Expect(const Sym: String);
begin
  if (FTokKind <> tkSymbol) or (FTokText <> Sym) then
    raise EFormulaError.CreateFmt('Expected "%s"', [Sym]);
  NextToken;
end;

// Parser: expr := term (('+'|'-') term)*

function TFormula.ParseExpr: TExprNode;
var
  Op: Char;
begin
  Result := ParseTerm;
  while (FTokKind = tkSymbol) and ((FTokText = '+') or (FTokText = '-')) do
  begin
    Op := FTokText[1];
    NextToken;
    Result := TBinOpNode.Create(Op, Result, ParseTerm);
  end;
end;

// term := unary (('*'|'/') unary)*
function TFormula.ParseTerm: TExprNode;
var
  Op: Char;
begin
  Result := ParseUnary;
  while (FTokKind = tkSymbol) and ((FTokText = '*') or (FTokText = '/')) do
  begin
    Op := FTokText[1];
    NextToken;
    Result := TBinOpNode.Create(Op, Result, ParseUnary);
  end;
end;

// unary := '-' unary | '+' unary | power
function TFormula.ParseUnary: TExprNode;
begin
  if (FTokKind = tkSymbol) and (FTokText = '-') then
  begin
    NextToken;
    Result := TUnaryMinusNode.Create(ParseUnary);
  end
  else if (FTokKind = tkSymbol) and (FTokText = '+') then
  begin
    NextToken;
    Result := ParseUnary;
  end
  else
    Result := ParsePower;
end;

// power := primary ('^' unary)?
// right-associative, exponent may itself be unary so that 2^-1 works
function TFormula.ParsePower: TExprNode;
begin
  Result := ParsePrimary;
  if (FTokKind = tkSymbol) and (FTokText = '^') then
  begin
    NextToken;
    Result := TBinOpNode.Create('^', Result, ParseUnary);
  end;
end;

// primary := number | ident | ident '(' expr ')' | '(' expr ')'
function TFormula.ParsePrimary: TExprNode;
const
  KnownFuncs: array[0..15] of String = (
    'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'exp', 'ln', 'log10',
    'sqrt', 'abs', 'sign', 'sqr', 'round', 'trunc', 'frac'
  );
var
  Name: String;
  Arg: TExprNode;
  j: Integer;
  IsFunc: Boolean;
begin
  case FTokKind of
    tkNumber:
      begin
        Result := TConstNode.Create(FTokValue);
        NextToken;
      end;

    tkSymbol:
      if FTokText = '(' then
      begin
        NextToken;
        Result := ParseExpr;
        Expect(')');
      end
      else
        raise EFormulaError.CreateFmt('Unexpected "%s"', [FTokText]);

    tkIdent:
      begin
        Name := LowerCase(FTokText);
        NextToken;

        if Name = 'pi' then
          Result := TConstNode.Create(Pi)
        else if (FTokKind = tkSymbol) and (FTokText = '(') then
        begin
          IsFunc := False;
          for j := Low(KnownFuncs) to High(KnownFuncs) do
            if KnownFuncs[j] = Name then IsFunc := True;
          if not IsFunc then
            raise EFormulaError.CreateFmt('Unknown function "%s"', [Name]);

          NextToken; // consume '('
          Arg := ParseExpr;
          Expect(')');
          Result := TFuncNode.Create(Name, Arg);
        end
        else
        begin
          if not IsValidVarName(Name) then
            raise EFormulaError.CreateFmt('Unknown variable "%s"', [FTokText]);

          Result := TVarNode.Create(Name);
        end;
      end;
  else
    raise EFormulaError.Create('Expected a number, variable or "("');
  end;
end;

function TFormula.IsValidVarName(const Name: String): Boolean;
var
  j: Integer;
begin
  Result := False;
  for j := 0 to High(FValidVars) do
    if SameText(FValidVars[j], Name) then
    begin
      Result := True;
      Exit;
    end;
end;

// TFormula

procedure TFormula.Compile(const Expression: String);
begin
  FRoot := nil;
  FValid := False;
  FErrorMessage := '';

  FSrc := Trim(Expression);
  FPos := 1;

  if FSrc = '' then
  begin
    FErrorMessage := 'Empty expression';
    Exit;
  end;

  try
    NextToken;
    FRoot := ParseExpr;
    if FTokKind <> tkEnd then
      raise EFormulaError.CreateFmt('Unexpected "%s" after end of expression', [FTokText]);
    FValid := True;
  except
    on E: EFormulaError do
    begin
      FreeAndNil(FRoot);
      FErrorMessage := E.Message;
    end;
  end;
end;

constructor TFormula.Create(const Expression: String);
begin
  Self.Create(Expression, ['X', 'Y', 'I', 'N']);
end;

constructor TFormula.Create(const Expression: String; const ValidVars: array of String);
var
  j: Integer;
begin
  inherited Create;
  FExpression := Expression;
  SetLength(FValidVars, Length(ValidVars));
  for j := 0 to High(ValidVars) do
    FValidVars[j] := ValidVars[j];
  Compile(Expression);
end;

destructor TFormula.Destroy;
begin
  FRoot.Free;
  inherited Destroy;
end;

function TFormula.Evaluate(X, Y: Double; I, N: Integer): Double;
begin
  Result := Evaluate(['X', 'Y', 'I', 'N'], [X, Y, I, N]);
end;

function TFormula.Evaluate(const Names: array of String; const Values: array of Double): Double;
begin
  if FValid and Assigned(FRoot) then
    Result := FRoot.Eval(Names, Values)
  else
    Result := 0.0;
end;

function TryCompileFormula(const Expr: String; const ValidVars: array of String; out ErrorMsg: String): Boolean;
var
  F: TFormula;
begin
  F := TFormula.Create(Expr, ValidVars);
  try
    Result := F.Valid;
    ErrorMsg := F.ErrorMessage;
  finally
    F.Free;
  end;
end;

initialization
  FInvariantFormat := DefaultFormatSettings;
  FInvariantFormat.DecimalSeparator := '.';
  FInvariantFormat.ThousandSeparator := #0;

end.
