$ErrorActionPreference = 'Stop'
Add-Type @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class MathomirUiProbe {
  public delegate bool EnumProc(IntPtr hwnd, IntPtr param);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr hwnd, EnumProc callback, IntPtr param);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc callback, IntPtr param);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
  [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr hwnd);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
  [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int count);
  [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder text, int count);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hwnd, uint msg, IntPtr wparam, IntPtr lparam);
  [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint msg, IntPtr wparam, IntPtr lparam, uint flags, uint ms, out UIntPtr result);
  [DllImport("user32.dll",CharSet=CharSet.Unicode,EntryPoint="SendMessageTimeoutW")] static extern IntPtr SendTextTimeout(IntPtr hwnd, uint msg, IntPtr wparam, string text, uint flags, uint ms, out UIntPtr result);
  public static string Text(IntPtr hwnd) { var text=new StringBuilder(512); GetWindowText(hwnd,text,512); return text.ToString(); }
  public static string Class(IntPtr hwnd) { var text=new StringBuilder(128); GetClassName(hwnd,text,128); return text.ToString(); }
  public static long Send(IntPtr hwnd,uint msg,int wparam) { UIntPtr result; if(SendMessageTimeout(hwnd,msg,(IntPtr)wparam,IntPtr.Zero,2,3000,out result)==IntPtr.Zero) throw new Exception("Window did not respond to message "+msg); return (long)result.ToUInt64(); }
  public static void Mouse(IntPtr hwnd,uint msg,int flags,int x,int y) { UIntPtr result; int position=(y<<16)|(x&65535); if(SendMessageTimeout(hwnd,msg,(IntPtr)flags,(IntPtr)position,2,3000,out result)==IntPtr.Zero) throw new Exception("Mouse action did not respond"); }
  public static void SetText(IntPtr hwnd,string text) { UIntPtr result; if(SendTextTimeout(hwnd,12,IntPtr.Zero,text,2,3000,out result)==IntPtr.Zero) throw new Exception("Search text did not respond"); }
  public static IntPtr Child(IntPtr parent,int id) { IntPtr found=IntPtr.Zero; EnumChildWindows(parent,(hwnd,p)=>{if(GetDlgCtrlID(hwnd)==id){found=hwnd;return false;} return true;},IntPtr.Zero); return found; }
  public static IntPtr Window(int process,string caption) { IntPtr found=IntPtr.Zero; EnumWindows((hwnd,p)=>{uint pid; GetWindowThreadProcessId(hwnd,out pid); if(pid==process && IsWindowVisible(hwnd) && Text(hwnd)==caption){found=hwnd;return false;}return true;},IntPtr.Zero); return found; }
  public static string AllText(IntPtr parent) { var lines=new List<string>(); EnumChildWindows(parent,(hwnd,p)=>{lines.Add(Text(hwnd));return true;},IntPtr.Zero);return String.Join("\n",lines); }
}
'@
$exe = (Resolve-Path 'source/build/Mathomir.exe').Path
$fixture=Join-Path (Split-Path $exe) 'root-annotation-smoke.mom'
@'
<?xml version="1.0"?>
<mathomir>
<o t="1" X="100" Y="150" ver="2">
<ex fh="100"><elm tp="8" E1=""><ex fh="90">
<var t="2" f="00"/><var t="x" f="00"/><opr s="-"/><var t="4" f="00"/>
</ex></elm></ex>
</o>
</mathomir>
'@ | Set-Content -LiteralPath $fixture -Encoding ascii
$appProcess = Start-Process -FilePath $exe -ArgumentList "`"$fixture`"" -WorkingDirectory (Split-Path $exe) -PassThru
try {
  $main = [IntPtr]::Zero
  for ($attempt=0; $attempt -lt 40; $attempt++) {
    Start-Sleep -Milliseconds 250
    $appProcess.Refresh()
    if ($appProcess.HasExited) { throw "Application exited during startup: $($appProcess.ExitCode)" }
    if ($appProcess.MainWindowHandle -ne 0) { $main=$appProcess.MainWindowHandle; break }
  }
  if ($main -eq [IntPtr]::Zero) { throw 'No main window was created.' }
  $view=[MathomirUiProbe]::Child($main,0xE900)
  if ($view -eq [IntPtr]::Zero) { throw 'The document view is missing.' }
  [MathomirUiProbe]::Send($main,273,32775) | Out-Null
  for ($x=105; $x -le 190; $x+=5) { [MathomirUiProbe]::Mouse($view,512,0,$x,140) }
  Start-Sleep -Milliseconds 500
  [MathomirUiProbe]::Mouse($view,515,1,130,125)
  [MathomirUiProbe]::Mouse($view,514,0,130,125)
  foreach ($character in 'constant'.ToCharArray()) { [MathomirUiProbe]::Send($view,258,[int]$character) | Out-Null }
  [MathomirUiProbe]::Send($main,273,0xE103) | Out-Null
  [xml]$savedRoot=Get-Content -LiteralPath $fixture -Raw
  $rootNodes=$savedRoot.SelectNodes('//elm[@tp="8"]/ex')
  if ($rootNodes.Count -ne 1) { throw 'The root expression was lost when placing an annotation.' }
  $rootTokens=($rootNodes[0].SelectNodes('./var') | ForEach-Object {$_.t}) -join ''
  if ($rootTokens -ne '2x4') { throw "The root's variables changed: $rootTokens" }
  $annotationTokens=($savedRoot.SelectNodes('/mathomir/o/ex/var') | ForEach-Object {$_.t}) -join ''
  if ($annotationTokens -notmatch 'constant') { throw "Typing the annotation did not save its text: $annotationTokens" }
  Write-Output 'Root placement smoke passed: hover inside root, double-click above the 2, type constant, save label and preserve root.'
  $search=[MathomirUiProbe]::Child($main,1112)
  if ($search -eq [IntPtr]::Zero -or ![MathomirUiProbe]::IsWindowVisible($search)) { throw 'The permanent Search field is missing or hidden.' }
  [MathomirUiProbe]::Send($main,273,33007) | Out-Null
  [MathomirUiProbe]::SetText($search,'font')
  Start-Sleep -Milliseconds 250
  $popup=[MathomirUiProbe]::Window($appProcess.Id,'Search features')
  if ($popup -eq [IntPtr]::Zero) { throw 'The search dropdown did not open.' }
  $list=[MathomirUiProbe]::Child($popup,1102)
  $matches=[MathomirUiProbe]::Send($list,395,0)
  if ($matches -le 0) { throw 'Search found no font commands.' }
  [MathomirUiProbe]::SetText($search,'zzzznonexistentfeaturezzzz')
  if ([MathomirUiProbe]::Send($list,395,0) -ne 0) { throw 'Search did not filter an unmatched query.' }
  [MathomirUiProbe]::SetText($search,'smart')
  if ([MathomirUiProbe]::Send($list,395,0) -lt 2) { throw 'Smart sizing commands are missing from search.' }
  [MathomirUiProbe]::Send($main,273,33010) | Out-Null
  $mode=[MathomirUiProbe]::Child($main,1115)
  if ([MathomirUiProbe]::Text($mode) -ne 'DEG') { throw 'Angle mode button did not update to DEG.' }
  [MathomirUiProbe]::Send($main,273,33009) | Out-Null
  if ([MathomirUiProbe]::Text($mode) -ne 'RAD') { throw 'Angle mode button did not update to RAD.' }
  [MathomirUiProbe]::PostMessage($main,273,[IntPtr]0xE140,[IntPtr]::Zero) | Out-Null
  $about=[IntPtr]::Zero
  for ($attempt=0; $attempt -lt 20; $attempt++) {
    Start-Sleep -Milliseconds 100
    $about=[MathomirUiProbe]::Window($appProcess.Id,'About Math-o-mir Improved')
    if ($about -ne [IntPtr]::Zero) { break }
  }
  if ($about -eq [IntPtr]::Zero) { throw 'The updated About dialog did not open.' }
  $aboutText=[MathomirUiProbe]::AllText($about)
  if ($aboutText -notmatch 'Improved - v11' -or $aboutText -notmatch 'Danijel Gorupec' -or $aboutText -notmatch 'MIT license') { throw 'About version or author credit is missing.' }
  [MathomirUiProbe]::PostMessage($about,273,[IntPtr]1,[IntPtr]::Zero) | Out-Null
  Write-Output "Windows UI smoke passed: visible Search, $matches font results, no-match filter, smart sizing, RAD/DEG, About and original author credit."
} finally {
  if (!$appProcess.HasExited) { Stop-Process -Id $appProcess.Id -Force }
}
