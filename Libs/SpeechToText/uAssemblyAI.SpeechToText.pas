unit uAssemblyAI.SpeechToText;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.Generics.Collections,
  System.NetEncoding,
  System.IniFiles,
  System.IOUtils,
  System.JSON,
  System.SyncObjs,
  sgcBase_Classes,
  sgcSocket_Classes,
  sgcTCP_Classes,
  sgcWebSocket_Classes,
  sgcWebSocket_Classes_Indy,
  sgcWebSocket_Client,
  sgcWebSocket
  ;

type
  TOnHandleMessage = procedure(msg: string) of object;
  TOnConnect = procedure(Connection: TsgcWSConnection) of object;

  TTSendThread = class(TThread)
  private
    FAssemblyai_key : string;
    queueItems : TThreadedQueue<TMemoryStream>;
    procedure sgcWebSocketClient1Handshake(Connection: TsgcWSConnection; var Headers: TStringList);
    procedure sgcWebSocketClient1Message(Connection: TsgcWSConnection; const Text: string);
    procedure sgOnConnect(Connection: TsgcWSConnection);
    function Base64EncodedStream(fs: TStream): string;
  public
    procedure Execute; override;
    procedure Add(ms: TMemoryStream);
    constructor Create(CreateSuspended: Boolean; assemblyai_key: string);
  public
    OnHandleMessage : TOnHandleMessage;
    OnConnect: TOnConnect;
  end;

implementation


{ TTSendThread }

procedure TTSendThread.sgcWebSocketClient1Handshake(Connection: TsgcWSConnection; var Headers: TStringList);
begin
  Headers.Add('Authorization: ' + FAssemblyai_key);
end;

procedure TTSendThread.sgcWebSocketClient1Message(Connection: TsgcWSConnection; const Text: string);
begin
  TThread.Queue(nil, procedure()
  var
    msg : TJSONObject;
    value : string;
    response : string;
    question : string;
  begin
    msg := TJSONObject.ParseJSONValue(Text) as TJSONObject;
    if msg.TryGetValue('message_type', Value) then
    begin
      if Assigned(OnHandleMessage) then
      begin
        OnHandleMessage(Text);
      end;
    end;
  end);
end;

procedure TTSendThread.sgOnConnect(Connection: TsgcWSConnection);
begin
  TThread.Queue(nil, procedure()
  begin
    if Assigned(OnConnect) then
    begin
      OnConnect(Connection);
    end;    
  end);
end;

procedure TTSendThread.Add(ms: TMemoryStream);
begin
  queueItems.PushItem(ms);
end;

function TTSendThread.Base64EncodedStream(fs: TStream): string;
var
  mem : TStringStream;
begin
  mem := nil;
  Result := '';
  try
    mem := TStringStream.Create;
    if TNetEncoding.Base64String.Encode(fs, mem) > 0 then
    begin
      Result := mem.DataString;
    end;
  finally
    FreeAndNil(mem);
  end;
end;

constructor TTSendThread.Create(CreateSuspended: Boolean; assemblyai_key: string);
begin
  inherited Create(CreateSuspended);
  FAssemblyai_key := assemblyai_key;
  queueItems := TThreadedQueue<TMemoryStream>.Create;
end;

procedure TTSendThread.Execute;
var
  m : TMemoryStream;
  mm : TMemoryStream;
  sgcWebSocketClient1 : TsgcWebSocketClient;
  msg : TJSONObject;
begin
  inherited;
  sgcWebSocketClient1 := TsgcWebSocketClient.Create(nil);
  sgcWebSocketClient1.URL := 'wss://api.assemblyai.com/v2/realtime/ws?sample_rate=16000';
  sgcWebSocketClient1.Proxy.Host := 'localhost';
  sgcWebSocketClient1.Proxy.Port := 8888;
  sgcWebSocketClient1.Proxy.Enabled := True;
  sgcWebSocketClient1.OnHandshake := sgcWebSocketClient1Handshake;
  sgcWebSocketClient1.OnMessage := sgcWebSocketClient1Message;
  sgcWebSocketClient1.OnConnect := sgOnConnect;
//  sgcWebSocketClient1.NotifyEvents := frmVoiceRecognition.sgcWebSocketClient1.NotifyEvents;
  sgcWebSocketClient1.Connect;
 // Application.ProcessMessages;

  try
    mm := TMemoryStream.Create;
    while not Terminated do
    begin
      m := queueItems.PopItem;
      if mm.Size < 17000 then
      begin
        m.Position := 0;
        mm.CopyFrom(m, m.Size);
        FreeAndNil(m);
        continue;
      end;
      mm.Position := 0;
      OutputDebugString(PChar('Size:' + mm.Size.ToString));
      try
        if not sgcWebSocketClient1.Connected then
          sgcWebSocketClient1.Connect;
        msg := TJSONObject.Create;
        try
          msg.AddPair('audio_data', Base64EncodedStream(mm));
          sgcWebSocketClient1.WriteData(msg.ToJson);
        finally
          FreeAndNil(msg);
        end;

      finally
        FreeandNil(m);
        mm.Clear;
      end;
    end;
  finally
    FreeAndNil(sgcWebSocketClient1);
  end;
end;

end.