unit uGoogle.SpeechToText;

interface

uses uBaseSpeechToText,
  System.Classes,
  System.SysUtils,
  System.JSON,
  System.IniFiles,
  System.Net.URLClient,
  Winapi.ShellAPI,
  REST.Client,
  REST.Types,
  System.NetEncoding,
  REST.Authenticator.EnhancedOAuth,
  IdHTTPServer,
  IdCustomHTTPServer,
  IdHTTPHeaderInfo,
  IdContext
  ;

type
  TGoogleSpeechToText = class(TBaseSpeechToText)
  strict private
    FOAuth2 : TEnhancedOAuth2Authenticator;
    FHTTPServer : TIdHttpServer;
    FSettings : TIniFile;
    FAccessToken : string;
    procedure IdHTTPServer1CommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
    function Base64EncodedFile(filename: string): string;
    function CreateRequestJSON(const FilePath, ModelName: string): TJSONObject;
  public
    function TranscribeAudio(const FilePath, ModelName: string): string; override;
    procedure Authenticate(ASettings: TIniFile);
    constructor Create(AResourceKey, AApplicationName, AHost: string);
  end;

implementation

{$I ..\apikey.inc}

{ TGoogleSpeechToText }

constructor TGoogleSpeechToText.Create(AResourceKey, AApplicationName, AHost: string);
begin
 // inherited Create(AResourceKey, AApplicationName, AHost);
  FOAuth2 := TEnhancedOAuth2Authenticator.Create(nil);
  FOAuth2.Scope := 'https://www.googleapis.com/auth/cloud-platform';
  FOAuth2.AuthorizationEndpoint := 'https://accounts.google.com/o/oauth2/auth?access_type=offline';
  FOAuth2.AccessTokenEndpoint := 'https://accounts.google.com/o/oauth2/token';
  FOAuth2.RedirectionEndpoint := 'http://localhost:7777/';
  FOAuth2.ClientID := google_clientid;
  FOAuth2.ClientSecret := google_clientsecret;
  FHTTPServer := TIdHttpServer.Create;
  FHTTPServer.DefaultPort := 7777;
  FHTTPServer.OnCommandGet := IdHTTPServer1CommandGet;
  FHTTPServer.Active := True;
end;

procedure TGoogleSpeechToText.IdHTTPServer1CommandGet(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  LCode: string;
  LURL : TURI;
begin
  if ARequestInfo.QueryParams = '' then
    Exit;
  LURL := TURI.Create('https://localhost/?' + ARequestInfo.QueryParams);
  try
    LCode := LURL.ParameterByName['code'];
  except
    Exit;
  end;
  FOAuth2.AuthCode := LCode;
  FOAuth2.ChangeAuthCodeToAccesToken;

  FSettings.WriteString('GoogleAuthentication', 'RefreshToken', FOAuth2.RefreshToken);
end;

procedure TGoogleSpeechToText.Authenticate(ASettings: TIniFile);
begin
  FSettings := ASettings;
  ShellExecute(0, 'OPEN', PChar(FOAuth2.AuthorizationRequestURI), nil,nil,0);
end;


function TGoogleSpeechToText.Base64EncodedFile(filename:string):string;
var
  fs : TFileStream;
  mem : TStringStream;
begin
  fs := nil;
  mem := nil;
  try
    fs := TFileStream.Create(filename, fmOpenRead);
    mem := TStringStream.Create;
    if TNetEncoding.Base64.Encode(fs, mem) > 0 then
    begin
      Result := mem.DataString;
    end;
  finally
    FreeAndNil(fs);
  end;
end;

function TGoogleSpeechToText.CreateRequestJSON(const FilePath, ModelName: string): TJSONObject;
var
  ConfigObj, AudioObj: TJSONObject;
  ConfigPair, EncodingPair, SampleRatePair, LanguageCodePair, ModelPair, AudioPair, ContentPair: TJSONPair;
begin
  // Create the JSON objects and pairs
  ConfigObj := TJSONObject.Create;
  EncodingPair := TJSONPair.Create('encoding', 'FLAC');
  SampleRatePair := TJSONPair.Create('sampleRateHertz', TJSONNumber.Create(16000));
  LanguageCodePair := TJSONPair.Create('languageCode', 'en-US');
  ModelPair := TJSONPair.Create('model', ModelName);
  ConfigObj.AddPair(EncodingPair);
  ConfigObj.AddPair(SampleRatePair);
  ConfigObj.AddPair(LanguageCodePair);
  ConfigObj.AddPair(ModelPair);

  AudioObj := TJSONObject.Create;
  ContentPair := TJSONPair.Create('content', Base64EncodedFile(FilePath));
  AudioObj.AddPair(ContentPair);

  Result := TJSONObject.Create;
  ConfigPair := TJSONPair.Create('config', ConfigObj);
  AudioPair := TJSONPair.Create('audio', AudioObj);
  Result.AddPair(ConfigPair);
  Result.AddPair(AudioPair);
end;

function TGoogleSpeechToText.TranscribeAudio(const FilePath, ModelName: string): string;
var
  RestClient: TRESTClient;
  Request: TRESTRequest;
  Response: TRESTResponse;
  jsonBody: TJSONObject;
//  AccessToken: string;
begin
  // 1. Get authentication credentials
 // AccessToken := 'YOUR_ACCESS_TOKEN';

  // 2. Install a REST client library
  RestClient := TRESTClient.Create('https://speech.googleapis.com');

  // 3. Prepare the audio file
  // ...

  // 4. Send a POST request to the Speech-to-Text API
  Request := TRESTRequest.Create(RestClient);
  Request.Resource := '/v1/speech:recognize';
  Request.Method := rmPOST;
 // Request.Params.AddItem('key', 'YOUR_API_KEY');
  Request.Params.AddItem('access_token', FAccessToken);
  Request.Params.AddItem('Content-Type', 'application/json', TRESTRequestParameterKind.pkHTTPHEADER);

  jsonBody := CreateRequestJSON(FilePath, ModelName);
  try
    Request.AddBody(jsonBody);
    //AddBody('{"config": {"encoding": "FLAC", "sampleRateHertz": 16000, "languageCode": "en-US", "model": "' + ModelName + '"}, "audio": {"content": "' + Base64EncodedFile(FilePath) + '"}}', TRESTContentType.ctAPPLICATION_JSON);
  finally
    FreeAndNil(jsonBody);
  end;
  Response := TRESTResponse.Create(Request);
  try
    Request.Execute;
    Result := Response.Content;
  finally
    Response.Free;
    Request.Free;
    RestClient.Free;
  end;

  // 5. Parse the response
  // ...
end;


end.
