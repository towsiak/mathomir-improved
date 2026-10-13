param([switch]$OnlineFixture)
$ErrorActionPreference='Stop'
$all=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $all.Substring(0,$all.IndexOf('$exe ='))
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class FormulaUI {
 [DllImport("user32.dll",CharSet=CharSet.Unicode,EntryPoint="SendMessageTimeoutW")] static extern IntPtr Read(IntPtr h,uint msg,IntPtr wp,StringBuilder text,uint flags,uint timeout,out UIntPtr result);
 [DllImport("advapi32.dll",CharSet=CharSet.Unicode)] static extern bool CredReadW(string target,uint type,int flags,out IntPtr cred);
 [DllImport("advapi32.dll")] static extern void CredFree(IntPtr cred);
 public static string Row(IntPtr h,int row){UIntPtr result;var text=new StringBuilder(1024);if(Read(h,393,(IntPtr)row,text,2,3000,out result)==IntPtr.Zero)throw new Exception("Formula list did not respond");return text.ToString();}
 public static bool Saved(string provider){IntPtr cred;if(!CredReadW("Mathomir/"+provider+"/PersonalKey",1,0,out cred))return false;CredFree(cred);return true;}
}
'@
$exe=(Resolve-Path 'source/build/Mathomir.exe').Path
$folder=Split-Path $exe
$script:fixture=Join-Path $folder 'formula-reference-ui.mom'
$record=Join-Path $folder 'formula-ai-fixture.jsonl'
$server=$null;$app=$null
function Check($ok,$message){if(!$ok){throw $message}}
function Start-App {$script:app=Start-Process $exe -WorkingDirectory $folder -PassThru;Check ($app.WaitForInputIdle(15000)) 'Math-o-mir did not finish starting its message loop';for($n=0;$n -lt 100;$n++){Start-Sleep -Milliseconds 100;$app.Refresh();if($app.HasExited){throw ('Math-o-mir exited during startup: '+$app.ExitCode)};$script:main=$app.MainWindowHandle;if($main -ne [IntPtr]::Zero -and [MathomirUiProbe]::Child($main,1498) -ne [IntPtr]::Zero){break}};Check ($main -ne [IntPtr]::Zero) 'Math-o-mir did not show its main window';$script:view=[MathomirUiProbe]::Child($main,0xE900);Check ($view -ne [IntPtr]::Zero) 'Math-o-mir page view is missing'}
function Stop-App {if($app){$app.Refresh();if(!$app.HasExited){$app.Kill();$app.WaitForExit()}}}
function SaveDoc {[MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;return [xml](Get-Content $script:fixture -Raw)}
function Empty-Scene {'<?xml version="1.0"?><mathomir></mathomir>'|Set-Content $fixture -Encoding ascii;[MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 200;[MathomirUiProbe]::Send($view,273,32775)|Out-Null}
function Await-Dialog($title){for($n=0;$n -lt 60;$n++){Start-Sleep -Milliseconds 100;$d=[MathomirUiProbe]::Window($app.Id,$title);if($d -ne [IntPtr]::Zero){Start-Sleep -Milliseconds 70;return $d}};throw ('Dialog did not open: '+$title)}
function Open-Reference([switch]$Palette){if($Palette){$b=[MathomirUiProbe]::Child($main,1498);Check ($b -ne [IntPtr]::Zero -and [MathomirUiProbe]::IsWindowVisible($b)) 'Formula palette button missing';[MathomirUiProbe]::PostMessage($b,245,[IntPtr]::Zero,[IntPtr]::Zero)|Out-Null}else{[MathomirUiProbe]::PostMessage($main,273,[IntPtr]33104,[IntPtr]::Zero)|Out-Null};$d=Await-Dialog 'Formula reference';[MathomirUiProbe]::Send($d,273,1490)|Out-Null;return $d}
function Close-Dialog($d,$id=2){[MathomirUiProbe]::PostMessage($d,273,[IntPtr]$id,[IntPtr]::Zero)|Out-Null;for($n=0;$n -lt 50;$n++){Start-Sleep -Milliseconds 50;if(![MathomirUiProbe]::IsWindowVisible($d)){return}};throw 'Dialog did not close'}
function List($d){return [MathomirUiProbe]::Child($d,1482)}
function Pick($d,$row){[MathomirUiProbe]::Send((List $d),390,$row)|Out-Null;[MathomirUiProbe]::Send($d,273,((1-shl 16)-bor 1482))|Out-Null}
function Find-Row($d,$title){$count=[MathomirUiProbe]::Send((List $d),395,0);for($i=0;$i -lt $count;$i++){if([FormulaUI]::Row((List $d),$i).EndsWith($title)){return $i}};throw ('Formula missing: '+$title)}
function Search($d,$text){[MathomirUiProbe]::SetText([MathomirUiProbe]::Child($d,1480),$text);Start-Sleep -Milliseconds 40}
function Box($d,$id,$value){[MathomirUiProbe]::Send([MathomirUiProbe]::Child($d,$id),241,$value)|Out-Null;[MathomirUiProbe]::Send($d,273,$id)|Out-Null}
function Capture($h,$file){Add-Type -AssemblyName System.Drawing;$r=[MathomirUiProbe]::WindowRect($h);$im=New-Object System.Drawing.Bitmap ($r.Right-$r.Left),($r.Bottom-$r.Top);$g=[System.Drawing.Graphics]::FromImage($im);$g.CopyFromScreen($r.Left,$r.Top,0,0,$im.Size);$im.Save((Join-Path $folder $file));$g.Dispose();$im.Dispose()}
function Provider($d,$index){[MathomirUiProbe]::Send([MathomirUiProbe]::Child($d,1416),334,$index)|Out-Null;[MathomirUiProbe]::Send($d,273,((1-shl 16)-bor 1416))|Out-Null}
try{
 if($OnlineFixture){$env:MATHOMIR_AI_TEST_PORT='8767';Remove-Item $record -ErrorAction SilentlyContinue;$python=(Get-Command python).Source;$server=Start-Process $python -ArgumentList @((Join-Path $PSScriptRoot 'formula-ai-fixture.py'),'8767',$record) -PassThru -WindowStyle Hidden;Start-Sleep -Milliseconds 500}
 Start-App;Empty-Scene;$baseline=(SaveDoc).OuterXml
 Check ([MathomirUiProbe]::MenuText($main,33104).Contains('Formula')) 'Formula menu missing';Check ([MathomirUiProbe]::MenuText($main,33105).Contains('Free AI')) 'Free AI menu missing'
 $d=Open-Reference -Palette;$list=List $d;Check ([MathomirUiProbe]::IsWindowUnicode($list)) 'Formula list does not support Unicode';Check ([MathomirUiProbe]::Send($list,395,0) -eq 215) 'Formula count is not 215';Check ([MathomirUiProbe]::Send([MathomirUiProbe]::Child($d,1481),326,0) -eq 14) 'Formula subjects missing'
 for($row=0;$row -lt 215;$row++){Pick $d $row;$reader=[MathomirUiProbe]::Text([MathomirUiProbe]::Child($d,1484));Check ($reader.Contains('Conditions and reminders') -and !$reader.Contains('\frac') -and !$reader.Contains('\mathbf') -and !$reader.Contains('\sqrt')) ('Raw/unexplained math in formula row '+$row)}
 foreach($term in @('quadratic roots','sine limit','half life','photon','entropy','cross product','integrating factor')){Search $d $term;Check ([MathomirUiProbe]::Send((List $d),395,0) -gt 0) ('Search missed: '+$term)}
 Search $d 'zzznomatchingformula';Check ([MathomirUiProbe]::Send((List $d),395,0) -eq 0 -and ![MathomirUiProbe]::IsWindowEnabled([MathomirUiProbe]::Child($d,1486))) 'Empty search leaves Place enabled';[MathomirUiProbe]::Send($d,273,1490)|Out-Null
 Pick $d (Find-Row $d 'Quadratic formula');Capture $d 'formula-reference-ui.png';[MathomirUiProbe]::Send($d,273,1487)|Out-Null;Check ([MathomirUiProbe]::Text([MathomirUiProbe]::Child($d,1485)).Contains('Copied')) 'Copy formula failed'
 [MathomirUiProbe]::Send($d,273,1493)|Out-Null;Box $d 1492 1;Check ([MathomirUiProbe]::Send((List $d),395,0) -ge 1) 'Favorite not saved';Close-Dialog $d
 Check ((SaveDoc).OuterXml -eq $baseline) 'Browsing formulas changed the document'
 Stop-App;Start-App;$d=Open-Reference;Box $d 1492 1;Check ((Find-Row $d 'Quadratic formula') -ge 0) 'Favorite lost after app restart';Pick $d (Find-Row $d 'Quadratic formula');[MathomirUiProbe]::Send($d,273,1493)|Out-Null;Close-Dialog $d
 # Native XML for every catalog entry must survive actual document parsing/saving.
 $script:fixture=Join-Path $folder 'formula-all-models.mom';[MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 350;$models=SaveDoc;$objects=$models.SelectNodes('/mathomir/*[self::o or self::obj]');Check ($objects.Count -eq 215) 'Native import lost formula objects';foreach($o in $objects){Check ($o.SelectNodes('./ex/* | ./expr/*').Count -gt 0) 'Native formula became empty'}
 $script:fixture=Join-Path $folder 'formula-reference-ui.mom'
 foreach($title in @('Quadratic formula','Cosine addition and subtraction','Derivative definition','Quotient rule','Fundamental Theorem, evaluation','Taylor series','First-order linear solution','Cross-product components','Gauss law','Faraday-Lenz law','Time-dependent Schrodinger equation','Radioactive decay','Planck constant')){
  Empty-Scene;$d=Open-Reference;Pick $d (Find-Row $d $title);Close-Dialog $d 1486;[MathomirUiProbe]::Mouse($view,512,0,280,170);[MathomirUiProbe]::Mouse($view,513,1,280,170);[MathomirUiProbe]::Mouse($view,514,0,280,170);$placed=SaveDoc;Check ($placed.SelectNodes('/mathomir/*[self::o or self::obj]').Count -eq 1) ('Formula did not place: '+$title);Check ($placed.SelectNodes('/mathomir/*[1]/*[self::ex or self::expr]/*').Count -gt 0) ('Formula is not editable native math: '+$title);[MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null;$undo=SaveDoc;Check ($undo.SelectNodes('/mathomir/*[self::o or self::obj]').Count -eq 0) ('Formula placement Undo failed: '+$title)
 }
 Empty-Scene;$d=Open-Reference;Pick $d (Find-Row $d 'Photon energy');Close-Dialog $d 1489;$ai=Await-Dialog 'AI math help';Check ([MathomirUiProbe]::Text([MathomirUiProbe]::Child($ai,1402)).Contains('Photon energy')) 'Formula not carried into AI dialog';Close-Dialog $ai;Check ((SaveDoc).SelectNodes('/mathomir/*[self::o or self::obj]').Count -eq 0) 'Opening formula AI changed document'
 $button=[MathomirUiProbe]::Child($main,1499);Check ($button -ne [IntPtr]::Zero) 'Free AI palette button missing';$formulaButton=[MathomirUiProbe]::Child($main,1498);$a=[MathomirUiProbe]::WindowRect($formulaButton);$b=[MathomirUiProbe]::WindowRect($button);Check ($a.Bottom -le $b.Top) 'Left palette reference buttons overlap';[MathomirUiProbe]::PostMessage($button,245,[IntPtr]::Zero,[IntPtr]::Zero)|Out-Null;$ai=Await-Dialog 'AI math help';Check ([MathomirUiProbe]::Send([MathomirUiProbe]::Child($ai,1416),326,0) -eq 4) 'Multiple free AI providers are not available'
 $historyBounds=[MathomirUiProbe]::WindowRect([MathomirUiProbe]::Child($ai,1407));$questionBounds=[MathomirUiProbe]::WindowRect([MathomirUiProbe]::Child($ai,1402));Check ($historyBounds.Bottom -lt $questionBounds.Top) 'Question composer must stay below conversation history'
 foreach($p in @(@{index=1;name='Groq';model='openai/gpt-oss-120b';key='gsk_mathomir_ci_only'},@{index=2;name='Gemini';model='gemini-2.5-flash';key='AIzaMathomirCiOnly123456'},@{index=3;name='OpenRouter';model='openrouter/free';key='sk-or-v1-mathomir-ci-only'})){
  Provider $ai $p.index;[MathomirUiProbe]::Send($ai,273,1413)|Out-Null;Check ([MathomirUiProbe]::Text([MathomirUiProbe]::Child($ai,1414)) -eq $p.model) ('Wrong provider model: '+$p.name);Check ([MathomirUiProbe]::Text([MathomirUiProbe]::Child($ai,1415)).Contains('free')) 'Free key link missing';[MathomirUiProbe]::Send($ai,273,1418)|Out-Null;Check ([MathomirUiProbe]::Text([MathomirUiProbe]::Child($ai,1408)).Contains('API key')) ('Missing-key test unclear: '+$p.name)
  [MathomirUiProbe]::SetText([MathomirUiProbe]::Child($ai,1411),$p.key);[MathomirUiProbe]::Send($ai,273,1412)|Out-Null;Check ([FormulaUI]::Saved($p.name)) ('Provider key not saved securely: '+$p.name);[MathomirUiProbe]::SetText([MathomirUiProbe]::Child($ai,1402),'Keep my original input: x^2+sin(x)')
  if($OnlineFixture){[MathomirUiProbe]::Send($ai,273,1418)|Out-Null;for($n=0;$n -lt 80;$n++){Start-Sleep -Milliseconds 100;$status=[MathomirUiProbe]::Text([MathomirUiProbe]::Child($ai,1408));if($status.Contains('Connection works')){break}};Check ($status.Contains('Connection works')) ('Provider test failed: '+$p.name+' '+$status);Check ([MathomirUiProbe]::Text([MathomirUiProbe]::Child($ai,1402)).StartsWith('Keep my original input')) 'Connection test overwrote the entered math'}
  if($OnlineFixture){
   foreach($question in @('Find the derivative of x^2.','Explain that answer using the power rule.')){[MathomirUiProbe]::SetText([MathomirUiProbe]::Child($ai,1402),$question);if($question.StartsWith('Explain')){[MathomirUiProbe]::PostMessage([MathomirUiProbe]::Child($ai,1402),256,[IntPtr]13,[IntPtr]0x001C0001)|Out-Null}else{[MathomirUiProbe]::Send($ai,273,1404)|Out-Null};for($n=0;$n -lt 80;$n++){Start-Sleep -Milliseconds 100;$status=[MathomirUiProbe]::Text([MathomirUiProbe]::Child($ai,1408));if($status.Contains('AI reply received')){break}};Check ($status.Contains('AI reply received')) ('Conversation request failed: '+$p.name);Check ([MathomirUiProbe]::Text([MathomirUiProbe]::Child($ai,1402)) -eq '') 'Successful Send did not clear composer';Check ([MathomirUiProbe]::Focus($main) -eq [MathomirUiProbe]::Child($ai,1402)) 'Reply did not return keyboard focus to the question composer'}
   $history=[MathomirUiProbe]::Text([MathomirUiProbe]::Child($ai,1407));Check ($history.Contains('Find the derivative') -and $history.Contains('power rule')) 'Chat replaced earlier question';Check ([MathomirUiProbe]::Send([MathomirUiProbe]::Child($ai,1407),206,0) -gt 0) 'Chat did not scroll to the latest answer';Capture $ai 'formula-free-ai-ui.png'
   [MathomirUiProbe]::Send($ai,273,1419)|Out-Null;Check (![MathomirUiProbe]::Text([MathomirUiProbe]::Child($ai,1407)).Contains('Find the derivative')) 'New chat retained old questions'
  }
  [MathomirUiProbe]::Send($ai,273,1413)|Out-Null;Check (![FormulaUI]::Saved($p.name)) ('Provider key was not removed: '+$p.name)
 }
 Provider $ai 1;if(!$OnlineFixture){Capture $ai 'formula-free-ai-ui.png'};Close-Dialog $ai
 if($OnlineFixture){$requests=@(Get-Content $record|ForEach-Object{$_|ConvertFrom-Json});Check ($requests.Count -eq 9) 'Provider connection/chat requests missing';foreach($path in @('/openai/v1/responses','/v1beta/openai/chat/completions','/api/v1/chat/completions')){$items=@($requests|Where-Object {$_.path -eq $path -and $_.authenticated});Check ($items.Count -eq 3) ('Wrong provider HTTP route: '+$path);$follow=$items[2];$messages=if($path.EndsWith('/responses')){@($follow.input)}else{@($follow.messages)};Check ($messages.Count -eq $(if($path.EndsWith('/responses')){3}else{4})) 'Follow-up conversation was not sent';Check ($messages[-2].role -eq 'assistant' -and $messages[-1].content.Contains('power rule')) 'Follow-up roles are incorrect'}}

 Write-Output 'Formula reference passed: actual left buttons, all 215 rendered cards and native XML imports, search/empty results, secure favorites across restart, representative editable placement and Undo, formula-to-AI handoff, three free services with isolated keys and defaults, explicit non-destructive connection tests.'
}catch{($_|Out-String)|Set-Content (Join-Path $folder 'formula-reference-test-result.txt');throw}finally{if($app -and !$app.HasExited -and $main -ne [IntPtr]::Zero){try{Capture $main 'formula-reference-canvas-ui.png'}catch{Write-Output ('Could not capture final diagnostic window: '+$_.Exception.Message)}};Stop-App;if($server -and !$server.HasExited){$server.Kill();$server.WaitForExit()};Remove-Item Env:MATHOMIR_AI_TEST_PORT -ErrorAction SilentlyContinue}
