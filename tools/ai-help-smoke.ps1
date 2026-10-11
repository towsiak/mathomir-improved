param([switch]$OnlineFixture)
$ErrorActionPreference='Stop'
$all=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $all.Substring(0,$all.IndexOf('$exe ='))
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class AiUI {
 [DllImport("user32.dll")] public static extern bool IsWindowUnicode(IntPtr h);
 [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h);
 [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h,int index);
 [DllImport("advapi32.dll",CharSet=CharSet.Unicode)] static extern bool CredReadW(string target,int type,int flags,out IntPtr cred);
 [DllImport("advapi32.dll")] static extern void CredFree(IntPtr cred);
 public static bool SavedKey(string provider){IntPtr cred;if(!CredReadW("Mathomir/"+provider+"/PersonalKey",1,0,out cred))return false;CredFree(cred);return true;}
}
'@
$exe=(Resolve-Path 'source/build/Mathomir.exe').Path
$server=$null;$record=Join-Path (Split-Path $exe) 'ai-request-test.jsonl';$portFile=Join-Path (Split-Path $exe) 'ai-test-port.txt'
if($OnlineFixture){
 Remove-Item $record,$portFile -ErrorAction SilentlyContinue
 $server=Start-Process python -ArgumentList @((Join-Path $PSScriptRoot 'ai-http-fixture.py'),$portFile,$record) -PassThru
 for($i=0;$i -lt 50 -and !(Test-Path $portFile);$i++){Start-Sleep -Milliseconds 100}
 if(!(Test-Path $portFile)){throw 'AI test server did not start'}
 $env:MATHOMIR_AI_TEST_PORT=(Get-Content $portFile -Raw).Trim()
}
$appProcess=Start-Process $exe -WorkingDirectory (Split-Path $exe) -PassThru
function Check($ok,$message){if(!$ok){throw $message}}
function OpenAI {
 [MathomirUiProbe]::PostMessage($main,273,[IntPtr]33102,[IntPtr]::Zero)|Out-Null
 for($i=0;$i -lt 30;$i++){Start-Sleep -Milliseconds 100;$d=[MathomirUiProbe]::Window($appProcess.Id,'AI math help');if($d -ne [IntPtr]::Zero){return $d}}
 throw 'AI panel did not open'
}
function Provider($d,$index){[MathomirUiProbe]::Send([MathomirUiProbe]::Child($d,1416),334,$index)|Out-Null;[MathomirUiProbe]::Send($d,273,((1 -shl 16) -bor 1416))|Out-Null}
function Status($d){[MathomirUiProbe]::Text([MathomirUiProbe]::Child($d,1408))}
function Ask($d,$mathText){[MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1402),$mathText);[MathomirUiProbe]::Send($d,273,1404)|Out-Null}
function WaitReply($d){for($i=0;$i -lt 60;$i++){Start-Sleep -Milliseconds 100;if([AiUI]::IsWindowEnabled([MathomirUiProbe]::Child($d,1404))){return}};throw 'AI worker did not return'}
try{
 for($i=0;$i -lt 40;$i++){Start-Sleep -Milliseconds 200;$appProcess.Refresh();if($appProcess.MainWindowHandle -ne 0){break}}
 $main=$appProcess.MainWindowHandle;$view=[MathomirUiProbe]::Child($main,59648)
 $file=Join-Path (Split-Path $exe) 'ai-help-smoke.mom';'<?xml version="1.0"?><mathomir><o t="1" X="100" Y="130"><ex fh="200"><var t="2" f="00" /></ex></o></mathomir>'|Set-Content $file -Encoding ascii
 [MathomirUiProbe]::OpenFile($main,$file);Start-Sleep -Milliseconds 400;[MathomirUiProbe]::Send($main,273,32775)|Out-Null;[MathomirUiProbe]::Send($main,273,0xE12A)|Out-Null
 [MathomirUiProbe]::Mouse($view,512,0,105,126);[MathomirUiProbe]::Mouse($view,516,2,105,126);[MathomirUiProbe]::Mouse($view,517,0,105,126);Start-Sleep -Milliseconds 100;$popup=[MathomirUiProbe]::Window($appProcess.Id,'PopupMenu');$panel=[MathomirUiProbe]::CaptionChild($popup,'Math selection');Check ($panel -ne [IntPtr]::Zero) 'Selection panel missing'
 [MathomirUiProbe]::Mouse($view,512,0,470,330);Start-Sleep -Milliseconds 350;Check ([MathomirUiProbe]::IsWindowVisible($panel)) 'Approximation panel vanished while crossing the page'
 $button=[MathomirUiProbe]::Child($panel,1394);Check ($button -ne [IntPtr]::Zero) 'AI Explain button missing'
 [MathomirUiProbe]::PostMessage($button,513,[IntPtr]1,[IntPtr](12 -shl 16 -bor 20))|Out-Null;[MathomirUiProbe]::PostMessage($button,514,[IntPtr]0,[IntPtr](12 -shl 16 -bor 20))|Out-Null
 Start-Sleep -Milliseconds 400;$d=[MathomirUiProbe]::Window($appProcess.Id,'AI math help');Check ($d -ne [IntPtr]::Zero) 'AI Explain button did not open the dialog'
 Check ([MathomirUiProbe]::Text([MathomirUiProbe]::Child($d,1402)) -eq '2') 'Selected math was not imported'
 foreach($id in @(1402,1407,1411,1414)){Check ([AiUI]::IsWindowUnicode([MathomirUiProbe]::Child($d,$id))) ('ANSI edit control: '+$id)}
 Check (([AiUI]::GetWindowLong([MathomirUiProbe]::Child($d,1411),-16) -band 32) -ne 0) 'API key field is not masked'
 Provider $d 1;Check ([MathomirUiProbe]::Text([MathomirUiProbe]::Child($d,1414)) -eq 'openai/gpt-oss-120b') 'Groq default model missing';Ask $d 'ln(2)';Check ((Status $d).Contains('API key')) ('Missing key not explained: '+(Status $d));Check ([AiUI]::IsWindowEnabled([MathomirUiProbe]::Child($d,1404))) 'Missing key left panel busy'
 [MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1411),'gsk_mathomir_ci_only');[MathomirUiProbe]::Send($d,273,1412)|Out-Null;Check ([AiUI]::SavedKey('Groq')) 'Windows Credential Manager did not save key'
 Provider $d 0;Check (![AiUI]::SavedKey('OpenAI') -and [MathomirUiProbe]::Send([MathomirUiProbe]::Child($d,1411),193,0) -eq 0) 'Groq key leaked to OpenAI';
 Check ([MathomirUiProbe]::Text([MathomirUiProbe]::Child($d,1414)) -eq 'gpt-4.1-mini-2025-04-14') 'OpenAI model was overwritten';
 [MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1411),'sk-mathomir-ci-only');
 if($OnlineFixture){Ask $d 'ln(2)';WaitReply $d;Check ((Status $d).Contains('AI reply received')) 'OpenAI fixture request failed'}
 Provider $d 1;Check ([MathomirUiProbe]::Send([MathomirUiProbe]::Child($d,1411),193,0) -eq 0) 'Provider switch retained a typed key';
 if($OnlineFixture){
  Ask $d 'ln(2)';WaitReply $d;$reply=[MathomirUiProbe]::Text([MathomirUiProbe]::Child($d,1407));Check ($reply.Contains('ln(2) ≈ 0.6931')) ('Unicode reply failed: '+$reply)
  [MathomirUiProbe]::Send($d,273,1406)|Out-Null;Check ((Get-Clipboard -Raw).Contains('ln(2) ≈ 0.6931')) 'Unicode copy failed'
  Ask $d '[rate-limit]';WaitReply $d;Check ((Status $d).Contains('quota or rate limit')) ('Rate limit not explained: '+(Status $d))
  Ask $d '[unavailable-model]';WaitReply $d;Check ((Status $d).Contains('unavailable for this account')) ('Unavailable model not explained: '+(Status $d))
  Ask $d '[malformed]';WaitReply $d;Check ((Status $d).Contains('invalid response')) ('Malformed response not rejected: '+(Status $d))
  Ask $d '[slow]';[MathomirUiProbe]::Send($d,273,1405)|Out-Null;Check ([AiUI]::IsWindowEnabled([MathomirUiProbe]::Child($d,1404))) 'Stop waiting blocked UI';Ask $d 'ln(2)';WaitReply $d;Start-Sleep -Milliseconds 2300;Check ((Status $d).Contains('AI reply received')) 'Old cancelled reply replaced latest status'
  $requests=Get-Content $record|ForEach-Object{$_|ConvertFrom-Json};Check ($requests.Count -ge 6) 'Test HTTP requests missing';Check (($requests|Where-Object {$_.path -eq '/v1/responses'}).Count -ge 1 -and ($requests|Where-Object {$_.path -eq '/openai/v1/responses'}).Count -ge 5) 'Provider endpoints were not isolated';foreach($r in $requests){Check ($r.authenticated -and !$r.store -and !$r.stream) 'Request authentication/nonstored flags incorrect'}
 }
 Add-Type -AssemblyName System.Drawing;$rect=[MathomirUiProbe]::WindowRect($d);$image=New-Object System.Drawing.Bitmap ($rect.Right-$rect.Left),($rect.Bottom-$rect.Top);$graphics=[System.Drawing.Graphics]::FromImage($image);$graphics.CopyFromScreen($rect.Left,$rect.Top,0,0,$image.Size);$image.Save((Join-Path (Split-Path $exe) 'ai-help-ui.png'));$graphics.Dispose();$image.Dispose()
 [MathomirUiProbe]::Send($d,273,1413)|Out-Null;Check (![AiUI]::SavedKey('Groq')) 'Saved key was not removed';[MathomirUiProbe]::Send($d,273,2)|Out-Null;Start-Sleep -Milliseconds 200
 $d=OpenAI;[MathomirUiProbe]::Send($d,273,2)|Out-Null;[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;Check ((Get-Content $file -Raw) -notmatch 'sk-mathomir|gsk_mathomir|AI reply') 'AI changed document or leaked credentials'
 Write-Output ('AI help passed: built-in fixed selection panel, Groq and OpenAI provider isolation, separate model defaults, cleared typed keys on switching, actual AI Explain click, selection import, Unicode controls, missing-key guidance, masked key, Windows Credential Manager save/remove, unchanged native math, and menu reopening. Test HTTP enabled: '+$OnlineFixture)
}catch{Write-Output ('AI process exited: '+$appProcess.HasExited);if($d -ne [IntPtr]::Zero){Write-Output ([MathomirUiProbe]::AllText($d))};Write-Output ([MathomirUiProbe]::AllText($main));Get-ChildItem (Split-Path $exe) -Filter 'asan*' -File|ForEach-Object{Get-Content $_.FullName|Write-Output};throw}
finally{if(!$appProcess.HasExited){$appProcess.Kill();$appProcess.WaitForExit()};if($server -and !$server.HasExited){$server.Kill();$server.WaitForExit()};Remove-Item Env:MATHOMIR_AI_TEST_PORT -ErrorAction SilentlyContinue}
