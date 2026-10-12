$ErrorActionPreference='Stop'
$all=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $all.Substring(0,$all.IndexOf('$exe ='))
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class CursorKeys {
 [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a,uint b,bool attach);
 [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr w,out uint p);
 [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
 [DllImport("user32.dll")] static extern bool GetKeyboardState(byte[] state);
 [DllImport("user32.dll")] static extern bool SetKeyboardState(byte[] state);
 [DllImport("user32.dll")] static extern IntPtr SendMessageTimeout(IntPtr w,uint m,IntPtr wp,IntPtr lp,uint f,uint ms,out UIntPtr result);
 public static void Arrow(IntPtr w,int key){UIntPtr r;if(SendMessageTimeout(w,256,(IntPtr)key,(IntPtr)0x01000001,2,3000,out r)==IntPtr.Zero)throw new Exception("Arrow stalled");}
 public static void Toggle(IntPtr w){uint p;uint t=GetWindowThreadProcessId(w,out p),c=GetCurrentThreadId();if(!AttachThreadInput(c,t,true))throw new Exception("Cannot set typing mode keys");byte[] old=new byte[256];GetKeyboardState(old);byte[] state=(byte[])old.Clone();state[32]=128;SetKeyboardState(state);try{UIntPtr r;if(SendMessageTimeout(w,258,(IntPtr)13,IntPtr.Zero,2,3000,out r)==IntPtr.Zero)throw new Exception("Mode switch stalled");}finally{SetKeyboardState(old);AttachThreadInput(c,t,false);}}
}
'@
$exe=(Resolve-Path 'source/build/Mathomir.exe').Path
$appProcess=Start-Process $exe -WorkingDirectory (Split-Path $exe) -PassThru
function Check($ok,$message){if(!$ok){throw $message}}
function ClickAt($x,$y){[MathomirUiProbe]::Mouse($view,512,0,$x,$y);[MathomirUiProbe]::Mouse($view,513,1,$x,$y);[MathomirUiProbe]::Mouse($view,514,0,$x,$y)}
function EnterText($text){foreach($character in $text.ToCharArray()){[MathomirUiProbe]::Send($view,258,[int]$character)|Out-Null}}
function Saved { [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null;return [xml](Get-Content $file -Raw) }
function Tokens($node){($node.SelectNodes('.//elm[@tp="1"]')|ForEach-Object{$_.tx}) -join ''}
try{
 for($i=0;$i -lt 40;$i++){Start-Sleep -Milliseconds 200;$appProcess.Refresh();if($appProcess.MainWindowHandle -ne 0){break}}
 $main=$appProcess.MainWindowHandle;$view=[MathomirUiProbe]::Child($main,59648);Check ($view -ne [IntPtr]::Zero) 'No editing view'
 $cases=@(
 @{name='text';middle='<var t="WORLD" f="00" />'},
 @{name='mixed power';middle='<var t="2" f="00" mth="1" /><opr s="+" /><elm tp="3" E1="" E2=""><ex><var t="x" f="00" /></ex><ex><var t="2" f="00" /></ex></elm><var t="WORLD" f="00" />'},
 @{name='mixed fraction';middle='<elm tp="4" E1="" E2=""><ex><var t="2" f="00" /></ex><ex><var t="3" f="00" /></ex></elm><var t="WORLD" f="00" />'}
 )
 $n=0
 foreach($case in $cases){
  $n++;$file=Join-Path (Split-Path $exe) ('cursor-stability-'+$n+'.mom')
  ('<?xml version="1.0"?><mathomir><o t="1" X="100" Y="130"><ex fh="200" stxt="1"><var t="HELLO" f="00" />'+$case.middle+'</ex></o><o t="1" X="100" Y="230"><ex fh="200" stxt="1"><var t="SECOND" f="00" /></ex></o></mathomir>')|Set-Content $file -Encoding ascii
  [MathomirUiProbe]::OpenFile($main,$file);Start-Sleep -Milliseconds 450;[MathomirUiProbe]::Send($main,273,32775)|Out-Null
  ClickAt 124 125;EnterText 'Q'
  $doc=Saved;$first=$doc.SelectSingleNode('/mathomir/*[1]');$before=Tokens $first
  Check ($before -match 'H.*Q.*ELLO|HE.*Q.*LLO|HEL.*Q.*LO|HELL.*Q.*O') ('Could not place a mid-word caret: '+$doc.OuterXml)
  # Mouse hover and timer/redraw must not redirect subsequent typing to the other box.
  [MathomirUiProbe]::Mouse($view,512,0,140,225);Start-Sleep -Milliseconds 1200
  EnterText 'R';[CursorKeys]::Arrow($view,37);[CursorKeys]::Arrow($view,39);EnterText 'S'
  $doc=Saved;Check ((Tokens $doc.SelectSingleNode('/mathomir/*[1]')) -eq $before.Replace('Q','QRS')) ('Typing, hover or opposite arrows moved the caret: '+$doc.OuterXml)
  Check ((Tokens $doc.SelectSingleNode('/mathomir/*[2]')) -eq 'SECOND') 'Hover stole text into a different box'
  # Switching modes between an arrow pair must invalidate the saved arrow location.
  [CursorKeys]::Arrow($view,37);[CursorKeys]::Toggle($view);[CursorKeys]::Toggle($view);[CursorKeys]::Arrow($view,39);EnterText 'T'
  $doc=Saved;Check ((Tokens $doc.SelectSingleNode('/mathomir/*[1]')) -eq $before.Replace('Q','QRST')) ('Text/math switches restored an old cursor position: '+$doc.OuterXml)
  [MathomirUiProbe]::Send($view,258,8)|Out-Null;EnterText 'U'
  $doc=Saved;Check ((Tokens $doc.SelectSingleNode('/mathomir/*[1]')) -eq $before.Replace('Q','QRSU')) ('Backspace changed the insertion location: '+$doc.OuterXml)
  # Explicitly clicking another box starts a fresh cursor session.
  ClickAt 124 225;EnterText 'V';[CursorKeys]::Arrow($view,37);[CursorKeys]::Arrow($view,39);EnterText 'W'
  $doc=Saved;Check ((Tokens $doc.SelectSingleNode('/mathomir/*[1]')) -eq $before.Replace('Q','QRSU')) 'New box input modified the previous box'
  Check ((Tokens $doc.SelectSingleNode('/mathomir/*[2]')) -match 'S.*VW.*ECOND|SE.*VW.*COND|SEC.*VW.*OND|SECO.*VW.*ND|SECON.*VW.*D') ('Caret left the newly clicked box: '+$doc.OuterXml)
  if($case.name -eq 'mixed power'){Check ($doc.SelectSingleNode('//elm[@tp="3"]/*[self::ex or self::expr][2]/elm[@tx="2"]')) 'Mixed input changed the power level'}
  if($case.name -eq 'mixed fraction'){Check ($doc.SelectSingleNode('//elm[@tp="4"]/*[self::ex or self::expr][2]/elm[@tx="3"]')) 'Mixed input changed the fraction level'}
  [MathomirUiProbe]::Send($view,258,27)|Out-Null
  Write-Output ('Cursor stability passed: '+$case.name+', mid-word input, idle, other-box hover, arrow roundtrip, mode switch, Backspace and box change.')
 }
}catch{Write-Output ('Cursor test process exited: '+$appProcess.HasExited);if(Test-Path $file){Get-Content $file|Write-Output};Get-ChildItem (Split-Path $exe) -Filter 'asan*' -File|ForEach-Object{Get-Content $_.FullName|Write-Output};throw}finally{if(!$appProcess.HasExited){$appProcess.Kill();$appProcess.WaitForExit()}}
