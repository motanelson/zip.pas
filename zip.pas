program SimpleZip;

uses
  SysUtils, Classes;

const
  SIG_LOCAL_HEADER      = $04034B50;
  SIG_CENTRAL_HEADER    = $02014B50;
  SIG_END_OF_DIRECTORY  = $06054B50;

type
  TFileInfo = record
    FileName: string;
    Data: array of Byte;
    CRC: LongWord;
    Offset: LongWord;
  end;

var
  Files: array of TFileInfo;

function CalcCRC32(const Data: array of Byte): LongWord;
var
  Table: array[0..255] of LongWord;
  i, j: Integer;
  c: LongWord;
  CRC: LongWord;
begin
  for i := 0 to 255 do begin
    c := i;
    for j := 1 to 8 do begin
      if (c and 1) <> 0 then
        c := (c shr 1) xor $EDB88320
      else
        c := c shr 1;
    end;
    Table[i] := c;
  end;

  CRC := $FFFFFFFF;
  for i := 0 to High(Data) do
    CRC := (CRC shr 8) xor Table[(CRC xor Data[i]) and $FF];

  CalcCRC32 := not CRC;
end;

procedure WriteU16(Stream: TStream; Value: Word);
begin
  Stream.WriteBuffer(Value, 2);
end;

procedure WriteU32(Stream: TStream; Value: LongWord);
begin
  Stream.WriteBuffer(Value, 4);
end;

procedure AddFile(const FilePath: string; var List: array of TFileInfo; Index: Integer);
var
  fs: TFileStream;
  size: LongInt;
  buffer: array of Byte;
begin
  fs := TFileStream.Create(FilePath, fmOpenRead);
  size := fs.Size;
  SetLength(buffer, size);
  fs.ReadBuffer(buffer[0], size);
  fs.Free;

  List[Index].FileName := ExtractFileName(FilePath);
  List[Index].Data := buffer;
  List[Index].CRC := CalcCRC32(buffer);
  List[Index].Offset := 0;
end;

procedure WriteZip(const OutZip: string; var Files: array of TFileInfo);
var
  outFile: TFileStream;
  i: Integer;
  filenameLen: Word;
  CDStartPos, CDSize: LongWord;
begin
  outFile := TFileStream.Create(OutZip, fmCreate);

  // Local File Headers
  for i := 0 to High(Files) do
  begin
    Files[i].Offset := outFile.Position;

    WriteU32(outFile, SIG_LOCAL_HEADER);
    WriteU16(outFile, 20);
    WriteU16(outFile, 0);
    WriteU16(outFile, 0);
    WriteU16(outFile, 0);
    WriteU16(outFile, 0);
    WriteU32(outFile, Files[i].CRC);
    WriteU32(outFile, Length(Files[i].Data));
    WriteU32(outFile, Length(Files[i].Data));
    filenameLen := Length(Files[i].FileName);
    WriteU16(outFile, filenameLen);
    WriteU16(outFile, 0);

    outFile.WriteBuffer(PAnsiChar(AnsiString(Files[i].FileName))^, filenameLen);
    outFile.WriteBuffer(Files[i].Data[0], Length(Files[i].Data));
  end;

  // Central Directory
  CDStartPos := outFile.Position;
  for i := 0 to High(Files) do
  begin
    WriteU32(outFile, SIG_CENTRAL_HEADER);
    WriteU16(outFile, $0314);
    WriteU16(outFile, 20);
    WriteU16(outFile, 0);
    WriteU16(outFile, 0);
    WriteU16(outFile, 0);
    WriteU16(outFile, 0);
    WriteU32(outFile, Files[i].CRC);
    WriteU32(outFile, Length(Files[i].Data));
    WriteU32(outFile, Length(Files[i].Data));
    filenameLen := Length(Files[i].FileName);
    WriteU16(outFile, filenameLen);
    WriteU16(outFile, 0);
    WriteU16(outFile, 0);
    WriteU16(outFile, 0);
    WriteU16(outFile, 0);
    WriteU32(outFile, 0);
    WriteU32(outFile, Files[i].Offset);
    outFile.WriteBuffer(PAnsiChar(AnsiString(Files[i].FileName))^, filenameLen);
  end;
  CDSize := outFile.Position - CDStartPos;

  // End of Central Directory
  WriteU32(outFile, SIG_END_OF_DIRECTORY);
  WriteU16(outFile, 0);
  WriteU16(outFile, 0);
  WriteU16(outFile, Length(Files));
  WriteU16(outFile, Length(Files));
  WriteU32(outFile, CDSize);
  WriteU32(outFile, CDStartPos);
  WriteU16(outFile, 0);

  outFile.Free;
end;

var
  Input: string;
  Tokens: TStringList;
  i: Integer;
begin
  Write(Chr(27) +'[43;30mFicheiros para empacotar (separados por espaço): ');
  ReadLn(Input);

  Tokens := TStringList.Create;
  Tokens.Delimiter := ' ';
  Tokens.DelimitedText := Input;

  SetLength(Files, Tokens.Count);
  for i := 0 to Tokens.Count - 1 do
    AddFile(Tokens[i], Files, i);

  WriteZip('output.zip', Files);
  Writeln('ZIP "output.zip" criado com sucesso com ', Tokens.Count, ' ficheiro(s).');

  Tokens.Free;
end.
