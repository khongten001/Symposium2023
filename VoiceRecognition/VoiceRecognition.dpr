program VoiceRecognition;

uses
  Vcl.Forms,
  frmVoiceRecognition in 'frmVoiceRecognition.pas' {VoiceRecognitionForm},
  uBaseSpeechToText in '..\Libs\SpeechToText\uBaseSpeechToText.pas',
  uMicrosoft.SpeechToText in '..\Libs\SpeechToText\uMicrosoft.SpeechToText.pas',
  uOpenAI.Whisper.Online.SpeechToText in '..\Libs\SpeechToText\uOpenAI.Whisper.Online.SpeechToText.pas',
  uGoogle.SpeechToText in '..\Libs\SpeechToText\uGoogle.SpeechToText.pas',
  uAmazon.SpeechToText in '..\Libs\SpeechToText\uAmazon.SpeechToText.pas',
  REST.Authenticator.EnhancedOAuth in '..\Libs\REST.Authenticator.EnhancedOAuth.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TVoiceRecognitionForm, VoiceRecognitionForm);
  Application.Run;
end.
