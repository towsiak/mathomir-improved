param([switch]$BaselineProbe)
$ErrorActionPreference='Stop'
$helpers=Get-Content (Join-Path $PSScriptRoot 'windows-smoke.ps1') -Raw
Invoke-Expression $helpers.Substring(0,$helpers.IndexOf('$exe ='))
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class SearchClickUI {
 public static bool RequireListHit=true;
 [StructLayout(LayoutKind.Sequential)] public struct Rect {public int Left,Top,Right,Bottom;}
 [StructLayout(LayoutKind.Sequential)] struct Point {public int X,Y;}
 [DllImport("user32.dll",CharSet=CharSet.Unicode,EntryPoint="SendMessageTimeoutW")] static extern IntPtr Read(IntPtr h,uint m,IntPtr w,StringBuilder text,uint f,uint ms,out UIntPtr r);
 [DllImport("user32.dll",CharSet=CharSet.Unicode,EntryPoint="SendMessageTimeoutW")] static extern IntPtr Bounds(IntPtr h,uint m,IntPtr w,out Rect rect,uint f,uint ms,out UIntPtr r);
 [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr h,ref Point p);
 [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point p);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h,StringBuilder text,int size);
 [DllImport("user32.dll")] static extern int GetDlgCtrlID(IntPtr h);
 [DllImport("user32.dll")] static extern void mouse_event(uint flags,uint x,uint y,uint data,UIntPtr extra);
 [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h,int x,int y,int w,int height,bool paint);
 public static string Label(IntPtr list,int row){var text=new StringBuilder(2048);UIntPtr r;if(Read(list,0x189,(IntPtr)row,text,2,3000,out r)==IntPtr.Zero)throw new Exception("Cannot read result");return text.ToString();}
 public static Rect Row(IntPtr list,int row){Rect rect;UIntPtr r;if(Bounds(list,0x198,(IntPtr)row,out rect,2,3000,out r)==IntPtr.Zero||r.ToUInt64()==UInt64.MaxValue)throw new Exception("Cannot locate result");return rect;}
 public static void Pointer(IntPtr frame,IntPtr list,int row){Rect rect=Row(list,row);Point p=new Point{X=rect.Left+20,Y=(rect.Top+rect.Bottom)/2};ClientToScreen(list,ref p);SetForegroundWindow(frame);SetCursorPos(p.X,p.Y);System.Threading.Thread.Sleep(120);IntPtr hit=WindowFromPoint(p);var name=new StringBuilder(100);GetClassName(hit,name,100);Console.WriteLine("Search hit: row="+row+", x="+p.X+", y="+p.Y+", class="+name+", control="+GetDlgCtrlID(hit)+", list="+(hit==list));if(RequireListHit&&hit!=list)throw new Exception("Result is covered by native "+name+" control "+GetDlgCtrlID(hit));}
 public static void Down(){mouse_event(2,0,0,0,UIntPtr.Zero);System.Threading.Thread.Sleep(90);}
 public static void Up(){mouse_event(4,0,0,0,UIntPtr.Zero);System.Threading.Thread.Sleep(120);}
 public static void Click(IntPtr frame,IntPtr list,int row){Pointer(frame,list,row);Down();Up();}
 public static void Outside(IntPtr list){Point p=new Point{X=20,Y=-12};ClientToScreen(list,ref p);SetCursorPos(p.X,p.Y);System.Threading.Thread.Sleep(80);}
}
'@
function Check($ok,$why){if(!$ok){throw $why}}
function Capture($h,$name){
 $r=[MathomirUiProbe]::WindowRect($h);$image=New-Object Drawing.Bitmap ($r.Right-$r.Left),($r.Bottom-$r.Top);$g=[Drawing.Graphics]::FromImage($image)
 try{$g.CopyFromScreen($r.Left,$r.Top,0,0,$image.Size);$image.Save((Join-Path $folder $name))}finally{$g.Dispose();$image.Dispose()}
}
function WaitDialog($caption,[int]$attempts=30){
 for($i=0;$i -lt $attempts;$i++){Start-Sleep -Milliseconds 100;$d=[MathomirUiProbe]::Window($app.Id,$caption);if($d -ne [IntPtr]::Zero){return $d}}
 return [IntPtr]::Zero
}
function CloseDialog($d,[int]$action=2){
 [MathomirUiProbe]::PostMessage($d,273,[IntPtr]$action,[IntPtr]::Zero)|Out-Null
 for($i=0;$i -lt 30;$i++){Start-Sleep -Milliseconds 50;if(![MathomirUiProbe]::IsWindowVisible($d)){return}}
 throw 'Searched dialog did not close'
}
function Query($text){
 [MathomirUiProbe]::Send($main,273,33007)|Out-Null;[MathomirUiProbe]::SetText($search,$text)
 $script:popup=WaitDialog 'Search features';Check ($popup -ne [IntPtr]::Zero) 'Search popup missing'
 $script:list=[MathomirUiProbe]::Child($popup,1102);Check ($list -ne [IntPtr]::Zero) 'Search result list missing'
}
function Result($pattern){
 $rows=[MathomirUiProbe]::Send($list,0x18B,0)
 for($i=0;$i -lt $rows;$i++){if([SearchClickUI]::Label($list,$i) -match $pattern){return $i}}
 throw "Missing search result: $pattern"
}
function SaveDoc {
 [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null
 return [xml](Get-Content $fixture -Raw)
}
$exe=(Resolve-Path source/build/Mathomir.exe).Path;$folder=Split-Path $exe
$env:MATHOMIR_DIAGNOSTIC_STARTUP='1'
$app=Start-Process $exe -WorkingDirectory $folder -PassThru
try{
 Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle;Check ($main -ne [IntPtr]::Zero) 'App did not start'
 [SearchClickUI]::RequireListHit=(!$BaselineProbe)
 [SearchClickUI]::MoveWindow($main,15,15,1050,760,$true)|Out-Null
 $view=[MathomirUiProbe]::Child($main,0xE900);$search=[MathomirUiProbe]::Child($main,1112)
 $fixture=Join-Path $folder 'search-click-steps.mom'
 '<?xml version="1.0"?><mathomir><o t="1" X="180" Y="180"><ex fh="100" stxt="1"><var t="STEP ONE" f="00"/></ex></o><o t="1" X="180" Y="260"><ex fh="100" stxt="1"><var t="STEP TWO" f="00"/></ex></o><o t="1" X="180" Y="340"><ex fh="100" stxt="1"><var t="STEP THREE" f="00"/></ex></o></mathomir>'|Set-Content $fixture -Encoding ascii
 [MathomirUiProbe]::OpenFile($main,$fixture);Start-Sleep -Milliseconds 250
 [MathomirUiProbe]::Send($view,273,32775)|Out-Null;[MathomirUiProbe]::Send($view,276,4)|Out-Null
 for($i=0;$i -lt 10;$i++){[MathomirUiProbe]::Send($view,277,2)|Out-Null}
 [MathomirUiProbe]::Send($main,273,0xE12A)|Out-Null
 Query 'ste';$step=Result '^View > Make or edit step sequence';Check ($step -gt 0) 'Fixture must exercise a nonfirst row'
 Capture $main 'search-click-results.png'
 [SearchClickUI]::Click($main,$list,$step);$d=WaitDialog 'Step-by-step sequence'
 if($BaselineProbe){
  $r=@{real_mouse_opened_step_dialog=($d -ne [IntPtr]::Zero);selected_row=[MathomirUiProbe]::Send($list,0x188,0);intended_row=$step}
  if($d -ne [IntPtr]::Zero){CloseDialog $d}
  Query 'Make or edit step sequence';[SearchClickUI]::Click($main,$list,0);$first=WaitDialog 'Step-by-step sequence'
  $r['uncovered_first_row_opened_step_dialog']=($first -ne [IntPtr]::Zero)
  if($first -ne [IntPtr]::Zero){CloseDialog $first}
  Query 'ste';for($i=0;$i -lt $step;$i++){[MathomirUiProbe]::PostMessage($search,256,[IntPtr]40,[IntPtr]::Zero)|Out-Null};Start-Sleep -Milliseconds 100
  $r['selection_before_resize']=[MathomirUiProbe]::Send($list,0x188,0)
  [SearchClickUI]::MoveWindow($main,15,15,1060,760,$true)|Out-Null;Start-Sleep -Milliseconds 150
  $r['selection_after_resize']=[MathomirUiProbe]::Send($list,0x188,0)
  $r|ConvertTo-Json|Set-Content (Join-Path $folder 'search-click-baseline.json')
  Capture $main 'search-click-baseline.png';Write-Output ('Previous release mouse probe: '+($r|ConvertTo-Json -Compress));return
 }
 Check ($d -ne [IntPtr]::Zero) 'A real mouse click on the nonfirst step-sequence result did not open it'
 Check ([MathomirUiProbe]::Send([MathomirUiProbe]::Child($d,1470),0x18B,0) -eq 3) 'Search lost the three selected page objects'
 Capture $d 'search-click-step-dialog.png';CloseDialog $d
 # Selection survives toolbar repositioning, not just keyboard and mouse input.
 Query 'ste';for($i=0;$i -lt $step;$i++){[MathomirUiProbe]::PostMessage($search,256,[IntPtr]40,[IntPtr]::Zero)|Out-Null};Start-Sleep -Milliseconds 100
 Check ([MathomirUiProbe]::Send($list,0x188,0) -eq $step) 'Search arrow keys did not select the intended result'
 [SearchClickUI]::MoveWindow($main,15,15,1060,760,$true)|Out-Null;Start-Sleep -Milliseconds 150
 Check ([MathomirUiProbe]::Send($list,0x188,0) -eq $step) 'Resizing reset the chosen search result to the first row'
 [MathomirUiProbe]::PostMessage($search,256,[IntPtr]13,[IntPtr]::Zero)|Out-Null;$d=WaitDialog 'Step-by-step sequence'
 Check ($d -ne [IntPtr]::Zero) 'Enter did not run the selected step-sequence result';CloseDialog $d
 # Same-row single click and drag-out cancellation work without a native double click.
 Query 'Make or edit step sequence';Check ((Result 'step sequence') -eq 0) 'Exact search did not put the command first'
 [SearchClickUI]::Pointer($main,$list,0);[SearchClickUI]::Down();[SearchClickUI]::Outside($list);[SearchClickUI]::Up();Start-Sleep -Milliseconds 100
 Check ([MathomirUiProbe]::IsWindowVisible($popup)) 'Dragging out of the results executed a command'
 [SearchClickUI]::Click($main,$list,0);$d=WaitDialog 'Step-by-step sequence';Check ($d -ne [IntPtr]::Zero) 'Single click failed on the initially selected first row'
 [MathomirUiProbe]::Send([MathomirUiProbe]::Child($d,1474),241,0)|Out-Null;CloseDialog $d 1
 $saved=SaveDoc;Check ($saved.SelectNodes('//ex[@steps] | //expr[@steps]').Count -eq 3) 'Sequence created from search was not saved'
 Query 'ste';$reveal=Result '^View > Reveal step sequence';Check ($reveal -gt 0) 'Reveal must also exercise a lower row'
 [SearchClickUI]::Click($main,$list,$reveal);Start-Sleep -Milliseconds 250
 $status=[MathomirUiProbe]::Child($view,1460);Check ($status -ne [IntPtr]::Zero -and [MathomirUiProbe]::Text($status) -eq 'Step 1 of 3') 'Searched reveal did not start the existing sequence'
 Capture $main 'search-click-reveal.png';[MathomirUiProbe]::Send($main,273,33114)|Out-Null
 # A different command in the same ambiguous query must open its own dialog.
 Query 'ste';$piecewise=Result '^Graph > Piecewise function grapher';Check ($piecewise -gt 0) 'Piecewise must exercise a lower row'
 [SearchClickUI]::Click($main,$list,$piecewise);$d=WaitDialog 'Piecewise function grapher';Check ($d -ne [IntPtr]::Zero) 'Clicking the piecewise result ran a different command';CloseDialog $d
 Query 'use degrees';[SearchClickUI]::Click($main,$list,0);Start-Sleep -Milliseconds 150
 Check ([MathomirUiProbe]::Text([MathomirUiProbe]::Child($main,1115)) -eq 'DEG') 'First-row mouse choice did not dispatch its command'
 Query 'use radians';[MathomirUiProbe]::PostMessage($search,256,[IntPtr]13,[IntPtr]::Zero)|Out-Null;Start-Sleep -Milliseconds 150
 Check ([MathomirUiProbe]::Text([MathomirUiProbe]::Child($main,1115)) -eq 'RAD') 'Keyboard search stopped dispatching commands'
 Check (![MathomirUiProbe]::IsWindowVisible($popup) -and [MathomirUiProbe]::Focus($main) -eq $view) 'Search reopened or stole focus after dispatch'
 $after=SaveDoc;Check ($after.SelectNodes('//ex[@steps] | //expr[@steps]').Count -eq 3 -and $after.mathomir.ChildNodes.Count -eq 3) 'Search gestures altered the authored sequence'
 Write-Output 'Search clicks passed: real mouse input, first and lower rows, selected objects retained, step setup/save/reveal, piecewise dispatch, drag-out cancellation, resize preserves choice, arrows/Enter and final canvas focus.'
}catch{
 $failure=$_;try{if($main -ne [IntPtr]::Zero){Capture $main 'search-click-failure.png'}}catch{}
 throw $failure
}finally{
 [SearchClickUI]::Up()
 if(!$app.HasExited){Stop-Process -Id $app.Id -Force}
}
