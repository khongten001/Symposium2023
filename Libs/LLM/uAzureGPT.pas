unit uAzureGPT;

interface
uses
  System.Generics.Collections,
  REST.Client,
  REST.Types,
  REST.Response.Adapter,
  System.JSON,
  REST.Json,
  System.SysUtils,
  uLLM
  ;
type
  TCapabilities = class
    fine_tune: Boolean;
    inference: Boolean;
    completion: Boolean;
    chat_completion: Boolean;
    embeddings: Boolean;
  end;

  TDeprecation = class
    fine_tune: Int64;
    inference: Int64;
  end;

  TModelData = class
    capabilities: TCapabilities;
    lifecycle_status: string;
    deprecation: TDeprecation;
    id: string;
    status: string;
    created_at: Int64;
    updated_at: Int64;
    object_type: string;
  end;

  TModelsResponse = class
    data: TArray<TModelData>;
  end;


  TMicrosoftOpenAI = class(TBaseLLM)
  private
    FEndpoint : string;
    function GetAzureModels: TModelsResponse;
  protected
    function GetModelInfo: TObjectList<TBaseModelInfo>; override;
  public
    constructor Create(const APIKey: string; const Endpoint: string);
    function ChatCompletion(ChatConfig: TChatSettings; AMessages: TObjectList<TChatMessage>): TChatResponse; override;
    function Completion(const AQuestion: string; const AModel: string): string; override;
    function Embeddings(const Texts: TArray<string>): TEmbeddings;
  end;

implementation
{ TMicrosoftOpenAI }

constructor TMicrosoftOpenAI.Create(const APIKey: string; const Endpoint: string);
begin
  inherited Create(APIKey);
  FEndpoint := Endpoint;
end;

function TMicrosoftOpenAI.ChatCompletion(ChatConfig: TChatSettings;
  AMessages: TObjectList<TChatMessage>): TChatResponse;
const
  API_Version = '2023-03-15-preview';
var
  LRESTClient: TRESTClient;
  LRESTRequest: TRESTRequest;
  LRESTResponse: TRESTResponse;
  LJSONObj: TJSONObject;
  LJSONArray: TJSONArray;
  LJSONMessage: TJSONObject;
  LChatMessage: TChatMessage;
  LResponseJSON: TJSONObject;
  LChoicesArray: TJSONArray;
  LUsage: TJSONObject;
  LChoice: TJSONObject;
begin
  LRESTClient := TRESTClient.Create(FEndpoint);
  try
    LRESTRequest := TRESTRequest.Create(nil);
    LRESTResponse := TRESTResponse.Create(nil);

    try
      LRESTRequest.Client := LRESTClient;
      LRESTRequest.Response := LRESTResponse;
      LRESTRequest.Resource := 'openai/deployments/gpt-35-turbo/chat/completions';
      LRESTRequest.Method := TRESTRequestMethod.rmPOST;
      LRESTRequest.Params.AddItem('api-version', API_Version, TRESTRequestParameterKind.pkQUERY);

      LRESTRequest.AddParameter('Content-Type', 'application/json', TRESTRequestParameterKind.pkHTTPHEADER,[poDoNotEncode]);
      LRESTRequest.AddParameter('api-key', FAPIKey, TRESTRequestParameterKind.pkHTTPHEADER);

      LJSONObj := TJSONObject.Create;
      try
        LJSONArray := TJSONArray.Create;
        for LChatMessage in AMessages do
        begin
          LJSONMessage := TJSONObject.Create;
          LJSONMessage.AddPair('role', LChatMessage.Role.ToLower);
          LJSONMessage.AddPair('content', LChatMessage.Content);
          LJSONArray.AddElement(LJSONMessage);
        end;

        LJSONObj.AddPair('messages', LJSONArray);
        LRESTRequest.AddBody(LJSONObj.ToString, TRESTContentType.ctAPPLICATION_JSON);

        LRESTRequest.Execute;

        LResponseJSON := TJSONObject.ParseJSONValue(LRESTResponse.Content) as TJSONObject;
        try
          LChoicesArray := LResponseJSON.GetValue<TJSONArray>('choices');
          LUsage := LResponseJSON.GetValue<TJSONObject>('usage');
          LUsage.TryGetValue('completion_tokens', Result.Completion_Tokens);
          LUsage.TryGetValue('prompt_tokens', Result.Prompt_Tokens);
          LUsage.TryGetValue('total_tokens', Result.Total_Tokens);
          LChoice := LChoicesArray.Items[0] as TJSONObject;
          Result.Content := LChoice.GetValue('message').GetValue<string>('content');
        finally
          FreeAndNil(LResponseJSON);
        end;
      finally
        FreeAndNil(LJSONObj);
      end;
    finally
      FreeAndNil(LRESTRequest);
      FreeAndNil(LRESTResponse);
    end;
  finally
    FreeAndNil(LRESTClient);
  end;
end;


function TMicrosoftOpenAI.Completion(const AQuestion, AModel: string): string;
begin
  raise Exception.Create('Not Implemented');
end;

function TMicrosoftOpenAI.Embeddings(const Texts: TArray<string>): TEmbeddings;
var
  LRestClient: TRESTClient;
  LRestRequest: TRESTRequest;
  LRestResponse: TRESTResponse;
  LJsonRequest: TJSONArray;
  LDataArray, LEmbeddingArray: TJSONArray;
  LJsonResponse : TJSONObject;
  LJson: TJSONObject;
  I, J: Integer;
begin
  LRestClient := TRESTClient.Create(FEndpoint);
  LRestRequest := TRESTRequest.Create(nil);
  LRestResponse := TRESTResponse.Create(nil);

  try
    LRestRequest.Client := LRestClient;
    LRestRequest.Response := LRestResponse;
    LRestRequest.Method := TRESTRequestMethod.rmPOST;
    LRestRequest.Resource := '/openai/deployments/{deployment-id}/embeddings?api-version={api-version}';

    LRestRequest.AddParameter('deployment-id', 'text-embedding-ada-002', pkURLSEGMENT);
    LRestRequest.AddParameter('api-version', '2023-03-15-preview', pkQUERY);


    LJsonRequest := TJSONArray.Create;
    for I := 0 to High(Texts) do
      LJsonRequest.AddElement(TJSONString.Create(Texts[I]));

    LJson := TJSONObject.Create;
    LJson.AddPair('input', LJsonRequest);

    LJson.AddPair('model', 'text-embedding-ada-002');

    LRestRequest.AddBody(LJson.ToString, TRESTContentType.ctAPPLICATION_JSON);
    LRestRequest.AddAuthParameter('Authorization', 'Bearer ' + FAPIKey, TRESTRequestParameterKind.pkHTTPHEADER, [poDoNotEncode]);
    LRestRequest.Execute;

    if LRestResponse.StatusCode = 200 then
    begin
      LJsonResponse := TJSONObject.ParseJSONValue(LRestResponse.Content) as TJSONObject;
      LDataArray := LJsonResponse.GetValue<TJSONArray>('data');
      SetLength(Result, LDataArray.Count);

      for I := 0 to LDataArray.Count - 1 do
      begin
        LEmbeddingArray := LDataArray.Items[I].GetValue<TJSONArray>('embedding');
        SetLength(Result[I], LEmbeddingArray.Count);
        for J := 0 to LEmbeddingArray.Count - 1 do
          Result[I][J] := (LEmbeddingArray.Items[J] as TJSONNumber).AsDouble;
      end;

      FreeAndNil(LJsonResponse);
    end
    else
      raise Exception.CreateFmt('Error: %d - %s', [LRestResponse.StatusCode, LRestResponse.StatusText]);

  finally
    FreeAndNil(LJson);
    FreeAndNil(LRestRequest);
    FreeAndNil(LRestClient);
  end;
end;

function TMicrosoftOpenAI.GetAzureModels: TModelsResponse;
var
  RestClient: TRESTClient;
  RestRequest: TRESTRequest;
  RestResponse: TRESTResponse;
  JsonResponse: TJSONObject;
  JSONValue: TJSONValue;
begin
  Result := nil;
  RestClient := TRESTClient.Create(nil);
  RestRequest := TRESTRequest.Create(nil);
  RestResponse := TRESTResponse.Create(nil);

  try
    RestClient.BaseURL := FEndpoint;
    RestClient.Accept := 'application/json';
    RestClient.AcceptCharset := 'UTF-8';

    RestRequest.Client := RestClient;
    RestRequest.Response := RestResponse;
    RestRequest.Method := rmGET;
    RestRequest.Resource := '/openai/models?api-version=2023-05-15';
    RestRequest.AddParameter('api-key', FAPIKey, TRESTRequestParameterKind.pkHTTPHEADER);

    RestRequest.Execute;

    if RestResponse.StatusCode = 200 then
    begin
      JSONValue := TJSONObject.ParseJSONValue(RestResponse.Content);
      try
        if JSONValue is TJSONObject then
        begin
          JsonResponse := JSONValue as TJSONObject;
          Result := TJSON.JsonToObject<TModelsResponse>(JsonResponse);
        end;
      finally
        JSONValue.Free;
      end;
    end
    else
      raise Exception.CreateFmt('Error: %s (%d)', [RestResponse.StatusText, RestResponse.StatusCode]);
  finally
    RestClient.Free;
    RestRequest.Free;
    RestResponse.Free;
  end;
end;


function TMicrosoftOpenAI.GetModelInfo: TObjectList<TBaseModelInfo>;
var
  modellist : TModelsResponse;
  modelObj: TBaseModelInfo;
  modelData: TModelData;
begin
  FModelInfo.Clear;

  modellist := GetAzureModels;
  try
    for modelData in modelList.data do
    begin
      modelObj := TBaseModelInfo.Create;
      modelObj.modelName := modelData.id;
      FModelInfo.Add(modelObj);
    end;
  finally
    FreeAndNil(modellist);
  end;
  Result := FModelInfo;
end;

end.
