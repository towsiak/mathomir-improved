$ErrorActionPreference = 'Stop'
function Get-GraphRange([xml]$document) {
  $graph=$document.SelectSingleNode('/mathomir/*[*[self::dw or self::draw][@spec="51"]]')
  $numbers=@()
  foreach ($sub in $graph.SelectNodes('./subexp[position()<=4]')) {
    $expression=$sub.SelectSingleNode('./*[self::ex or self::expr]')
    $variable=$expression.SelectSingleNode('./*[self::var or self::elm[@tp="1"]]')
    $text=if ($variable.HasAttribute('t')) {$variable.t} else {$variable.tx}
    $number=[double]::Parse($text,[Globalization.CultureInfo]::InvariantCulture)
    if ($expression.SelectSingleNode('./opr[@s="-"] | ./elm[@tp="2"][@stp="-"]')) {$number=-$number}
    $numbers+=$number
  }
  return $numbers
}

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
  [DllImport("kernel32.dll")] static extern IntPtr GlobalAlloc(uint flags,UIntPtr bytes);
  [DllImport("kernel32.dll")] static extern IntPtr GlobalLock(IntPtr memory);
  [DllImport("kernel32.dll")] static extern bool GlobalUnlock(IntPtr memory);
  public static void OpenFile(IntPtr hwnd,string path) { byte[] file=Encoding.Unicode.GetBytes(path+"\0\0"); IntPtr handle=GlobalAlloc(0x42,(UIntPtr)(20+file.Length)); IntPtr memory=GlobalLock(handle); Marshal.WriteInt32(memory,0,20); Marshal.WriteInt32(memory,16,1); Marshal.Copy(file,0,IntPtr.Add(memory,20),file.Length); GlobalUnlock(handle); PostMessage(hwnd,563,handle,IntPtr.Zero); }
  [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr hwnd);
  [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr hwnd,IntPtr dc);
  [DllImport("gdi32.dll")] static extern uint GetPixel(IntPtr dc,int x,int y);
  public static int MoveGripY(IntPtr hwnd,int x) { IntPtr dc=GetDC(hwnd); try { int first=-1,last=-1; for(int y=20;y<190;y++) if(GetPixel(dc,x,y)==0x009B5F2D){if(first<0)first=y;last=y;} if(first<0) throw new Exception("Move grip was not painted at the object's upper-left"); return (first+last)/2; } finally {ReleaseDC(hwnd,dc);} }
  public static bool SizeGripAt(IntPtr hwnd,int x,int y) { IntPtr dc=GetDC(hwnd); try { for(int k=-6;k<=6;k++) if(GetPixel(dc,x+k,y-6)!=0x009B5F2D) return false; return true; }finally{ReleaseDC(hwnd,dc);} }
  public static int[] SizeGrip(IntPtr hwnd) { IntPtr dc=GetDC(hwnd); try { for(int y=130;y<300;y++) for(int x=110;x<290;x++) {bool line=true;for(int k=0;k<13;k++)if(GetPixel(dc,x+k,y)!=0x009B5F2D){line=false;break;}if(line)return new int[]{x+6,y+6};} throw new Exception("Size grip square was not painted");}finally{ReleaseDC(hwnd,dc);} }
  [DllImport("user32.dll")] static extern bool AttachThreadInput(uint current,uint target,bool attach);
  [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] static extern bool GetKeyboardState(byte[] state);
  [DllImport("user32.dll")] static extern bool SetKeyboardState(byte[] state);
  public static void ShiftKey(IntPtr hwnd,int key) {uint pid;uint target=GetWindowThreadProcessId(hwnd,out pid);uint current=GetCurrentThreadId();if(!AttachThreadInput(current,target,true))throw new Exception("Could not share selection key state");byte[] old=new byte[256];GetKeyboardState(old);byte[] state=(byte[])old.Clone();state[16]=128;SetKeyboardState(state);try{UIntPtr result;if(SendMessageTimeout(hwnd,256,(IntPtr)key,(IntPtr)0x01000001,2,3000,out result)==IntPtr.Zero)throw new Exception("Selection arrow did not respond");}finally{SetKeyboardState(old);AttachThreadInput(current,target,false);}}
  public static void Mouse(IntPtr hwnd,uint msg,int flags,int x,int y) { UIntPtr result; int position=(y<<16)|(x&65535); if(SendMessageTimeout(hwnd,msg,(IntPtr)flags,(IntPtr)position,2,3000,out result)==IntPtr.Zero) throw new Exception("Mouse action did not respond"); }
  [DllImport("user32.dll")] static extern IntPtr GetMenu(IntPtr hwnd);
  [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetMenuString(IntPtr menu,uint id,StringBuilder text,int count,uint flags);
  public static string MenuText(IntPtr hwnd,uint id) {var text=new StringBuilder(256);GetMenuString(GetMenu(hwnd),id,text,256,0);return text.ToString();}
  public static void SetText(IntPtr hwnd,string text) { UIntPtr result; if(SendTextTimeout(hwnd,12,IntPtr.Zero,text,2,3000,out result)==IntPtr.Zero) throw new Exception("Search text did not respond"); }
  public static IntPtr Child(IntPtr parent,int id) { IntPtr found=IntPtr.Zero; EnumChildWindows(parent,(hwnd,p)=>{if(GetDlgCtrlID(hwnd)==id){found=hwnd;return false;} return true;},IntPtr.Zero); return found; }
  public static IntPtr Window(int process,string caption) { IntPtr found=IntPtr.Zero; EnumWindows((hwnd,p)=>{uint pid; GetWindowThreadProcessId(hwnd,out pid); if(pid==process && IsWindowVisible(hwnd) && Text(hwnd)==caption){found=hwnd;return false;}return true;},IntPtr.Zero); return found; }
  public static IntPtr Dialog(int process) { IntPtr found=IntPtr.Zero; EnumWindows((hwnd,p)=>{uint pid; GetWindowThreadProcessId(hwnd,out pid); if(pid==process && IsWindowVisible(hwnd) && Class(hwnd)=="#32770"){found=hwnd;return false;}return true;},IntPtr.Zero); return found; }
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
<var t="2" f="00" /><var t="x" f="00" /><opr s="-" /><var t="4" f="00" />
</ex></elm></ex>
</o>
<o t="2" X="300" Y="400">
<dw spec="51" d="32|32,32;13600,32;:,9056;32,:;:,32" />
<subexp d="64,64;2544,704">
	<ex fh="100"><opr s="-" /><var t="6.283185307179586" f="00" /></ex></subexp>
<subexp d="64,64;2464,704">
	<ex fh="100"><var t="6.283185307179586" f="00" /></ex></subexp>
<subexp d="64,64;2837,704">
	<ex fh="100"><opr s="-" /><var t="2" f="00" /></ex></subexp>
<subexp d="64,64;2464,704">
	<ex fh="100"><var t="2" f="00" /></ex></subexp>
<subexp d="0,0;5386,1280">
	<ex fh="100">
		<fun t="f" f="20" E1="">
		<ex fh="100" br="3">
			<var t="t" f="00" />
		</ex>
		</fun>
		<opr s="=" />
		<fun t="sin" f="20" E1="">
		<ex fh="100" br="2">
			<fra stp="" E1="n" E2="d">
			<ex fh="90">
				<var t="t" f="00" />
			</ex>
			<ex fh="90">
				<var t="10" f="00" />
			</ex>
			</fra>
		</ex>
		</fun>
		<opr s="+" />
		<var t="1.0" f="00" />
		<opr s="+" />
		<fra stp="" E1="n" E2="d">
		<ex fh="90">
			<var t="t" f="00" />
		</ex>
		<ex fh="90">
			<var t="10" f="00" />
		</ex>
		</fra>
	</ex>
</subexp>
<subexp d="0,0;5386,1280">
	<ex fh="100">
		<fun t="f" f="20" E1="">
		<ex fh="100" br="3">
			<var t="t" f="00" />
		</ex>
		</fun>
		<opr s="=" />
		<fun t="sin" f="20" E1="">
		<ex fh="100" br="2">
			<fra stp="" E1="n" E2="d">
			<ex fh="90">
				<var t="t" f="00" />
			</ex>
			<ex fh="90">
				<var t="10" f="00" />
			</ex>
			</fra>
		</ex>
		</fun>
		<opr s="+" />
		<var t="1.1" f="00" />
		<opr s="+" />
		<fra stp="" E1="n" E2="d">
		<ex fh="90">
			<var t="t" f="00" />
		</ex>
		<ex fh="90">
			<var t="10" f="00" />
		</ex>
		</fra>
	</ex>
</subexp>
<subexp d="0,0;5386,1280">
	<ex fh="100">
		<fun t="f" f="20" E1="">
		<ex fh="100" br="3">
			<var t="t" f="00" />
		</ex>
		</fun>
		<opr s="=" />
		<fun t="sin" f="20" E1="">
		<ex fh="100" br="2">
			<fra stp="" E1="n" E2="d">
			<ex fh="90">
				<var t="t" f="00" />
			</ex>
			<ex fh="90">
				<var t="10" f="00" />
			</ex>
			</fra>
		</ex>
		</fun>
		<opr s="+" />
		<var t="1.2" f="00" />
		<opr s="+" />
		<fra stp="" E1="n" E2="d">
		<ex fh="90">
			<var t="t" f="00" />
		</ex>
		<ex fh="90">
			<var t="10" f="00" />
		</ex>
		</fra>
	</ex>
</subexp>
<subexp d="0,0;5386,1280">
	<ex fh="100">
		<fun t="f" f="20" E1="">
		<ex fh="100" br="3">
			<var t="t" f="00" />
		</ex>
		</fun>
		<opr s="=" />
		<fun t="sin" f="20" E1="">
		<ex fh="100" br="2">
			<fra stp="" E1="n" E2="d">
			<ex fh="90">
				<var t="t" f="00" />
			</ex>
			<ex fh="90">
				<var t="10" f="00" />
			</ex>
			</fra>
		</ex>
		</fun>
		<opr s="+" />
		<var t="1.3" f="00" />
		<opr s="+" />
		<fra stp="" E1="n" E2="d">
		<ex fh="90">
			<var t="t" f="00" />
		</ex>
		<ex fh="90">
			<var t="10" f="00" />
		</ex>
		</fra>
	</ex>
</subexp>
<subexp d="0,0;5386,1280">
	<ex fh="100">
		<fun t="f" f="20" E1="">
		<ex fh="100" br="3">
			<var t="t" f="00" />
		</ex>
		</fun>
		<opr s="=" />
		<fun t="sin" f="20" E1="">
		<ex fh="100" br="2">
			<fra stp="" E1="n" E2="d">
			<ex fh="90">
				<var t="t" f="00" />
			</ex>
			<ex fh="90">
				<var t="10" f="00" />
			</ex>
			</fra>
		</ex>
		</fun>
		<opr s="+" />
		<var t="1.4" f="00" />
		<opr s="+" />
		<fra stp="" E1="n" E2="d">
		<ex fh="90">
			<var t="t" f="00" />
		</ex>
		<ex fh="90">
			<var t="10" f="00" />
		</ex>
		</fra>
	</ex>
</subexp>
<subexp d="0,0;5386,1280">
	<ex fh="100">
		<fun t="f" f="20" E1="">
		<ex fh="100" br="3">
			<var t="t" f="00" />
		</ex>
		</fun>
		<opr s="=" />
		<fun t="sin" f="20" E1="">
		<ex fh="100" br="2">
			<fra stp="" E1="n" E2="d">
			<ex fh="90">
				<var t="t" f="00" />
			</ex>
			<ex fh="90">
				<var t="10" f="00" />
			</ex>
			</fra>
		</ex>
		</fun>
		<opr s="+" />
		<var t="1.5" f="00" />
		<opr s="+" />
		<fra stp="" E1="n" E2="d">
		<ex fh="90">
			<var t="t" f="00" />
		</ex>
		<ex fh="90">
			<var t="10" f="00" />
		</ex>
		</fra>
	</ex>
</subexp>
<subexp d="0,0;5386,1280">
	<ex fh="100">
		<fun t="f" f="20" E1="">
		<ex fh="100" br="3">
			<var t="t" f="00" />
		</ex>
		</fun>
		<opr s="=" />
		<fun t="sin" f="20" E1="">
		<ex fh="100" br="2">
			<fra stp="" E1="n" E2="d">
			<ex fh="90">
				<var t="t" f="00" />
			</ex>
			<ex fh="90">
				<var t="10" f="00" />
			</ex>
			</fra>
		</ex>
		</fun>
		<opr s="+" />
		<var t="1.6" f="00" />
		<opr s="+" />
		<fra stp="" E1="n" E2="d">
		<ex fh="90">
			<var t="t" f="00" />
		</ex>
		<ex fh="90">
			<var t="10" f="00" />
		</ex>
		</fra>
	</ex>
</subexp>
<subexp d="0,0;5386,1280">
	<ex fh="100">
		<fun t="f" f="20" E1="">
		<ex fh="100" br="3">
			<var t="t" f="00" />
		</ex>
		</fun>
		<opr s="=" />
		<fun t="sin" f="20" E1="">
		<ex fh="100" br="2">
			<fra stp="" E1="n" E2="d">
			<ex fh="90">
				<var t="t" f="00" />
			</ex>
			<ex fh="90">
				<var t="10" f="00" />
			</ex>
			</fra>
		</ex>
		</fun>
		<opr s="+" />
		<var t="1.7000000000000002" f="00" />
		<opr s="+" />
		<fra stp="" E1="n" E2="d">
		<ex fh="90">
			<var t="t" f="00" />
		</ex>
		<ex fh="90">
			<var t="10" f="00" />
		</ex>
		</fra>
	</ex>
</subexp>
</o>

</mathomir>
'@ | Set-Content -LiteralPath $fixture -Encoding ascii
$startArgs=@{FilePath=$exe; WorkingDirectory=(Split-Path $exe); PassThru=$true; RedirectStandardError=(Join-Path (Split-Path $exe) 'smoke-stderr.txt')}

$appProcess = Start-Process @startArgs
try {
  $main = [IntPtr]::Zero
  for ($attempt=0; $attempt -lt 40; $attempt++) {
    Start-Sleep -Milliseconds 250
    $appProcess.Refresh()
    if ($appProcess.HasExited) { throw "Application exited during startup: $($appProcess.ExitCode)" }
    if ($appProcess.MainWindowHandle -ne 0) { $main=$appProcess.MainWindowHandle; break }
  }
  if ($main -eq [IntPtr]::Zero) { throw 'No main window was created.' }
  [MathomirUiProbe]::PostMessage($main,273,[IntPtr]0xE101,[IntPtr]::Zero) | Out-Null
  $open=[IntPtr]::Zero
  for ($attempt=0; $attempt -lt 80; $attempt++) {
    Start-Sleep -Milliseconds 100
    $open=[MathomirUiProbe]::Dialog($appProcess.Id)
    if ($open -ne [IntPtr]::Zero) { break }
  }
  if ($open -eq [IntPtr]::Zero) { throw 'The file-open dialog did not appear.' }
  $fileEdit=[MathomirUiProbe]::Child($open,1148)
  if ($fileEdit -eq [IntPtr]::Zero) { $fileEdit=[MathomirUiProbe]::Child($open,1001) }
  if ($fileEdit -eq [IntPtr]::Zero) { $fileEdit=[MathomirUiProbe]::Child($open,1152) }
  if ($fileEdit -eq [IntPtr]::Zero) { throw ('Filename control not found. '+[MathomirUiProbe]::AllText($open)) }
  [MathomirUiProbe]::SetText($fileEdit,$fixture)
  [MathomirUiProbe]::PostMessage($open,273,[IntPtr]1,[IntPtr]::Zero) | Out-Null
  for ($attempt=0; $attempt -lt 30; $attempt++) {
    Start-Sleep -Milliseconds 100
    $appProcess.Refresh()
    if ($appProcess.HasExited) { throw "Application exited while opening the root fixture: $($appProcess.ExitCode)" }
    if ([MathomirUiProbe]::Text($main) -match 'root-annotation-smoke') { break }
  }
  if ([MathomirUiProbe]::Text($main) -notmatch 'root-annotation-smoke') { throw ('The root fixture did not open. '+[MathomirUiProbe]::AllText($open)) }
  $view=[MathomirUiProbe]::Child($main,0xE900)
  if ($view -eq [IntPtr]::Zero) { throw 'The document view is missing.' }
  [MathomirUiProbe]::Send($main,273,32775) | Out-Null
  for ($x=105; $x -le 190; $x+=5) { [MathomirUiProbe]::Mouse($view,512,0,$x,140) }
  Start-Sleep -Milliseconds 500
  $gripY=[MathomirUiProbe]::MoveGripY($view,88)
  [MathomirUiProbe]::Mouse($view,512,0,88,$gripY)
  [MathomirUiProbe]::Mouse($view,513,1,88,$gripY)
  [MathomirUiProbe]::Mouse($view,512,1,118,($gripY+20))
  [MathomirUiProbe]::Mouse($view,514,0,118,($gripY+20))
  [MathomirUiProbe]::Send($main,273,0xE103) | Out-Null
  [xml]$moved=Get-Content -LiteralPath $fixture -Raw
  $movedRoot=$moved.SelectSingleNode('/mathomir/o[1]')
  if ($movedRoot.X -ne '130' -or $movedRoot.Y -ne '170') { throw 'Dragging the move grip did not move the object by the expected distance.' }
  Write-Output ("Undo menu before command: "+[MathomirUiProbe]::MenuText($main,0xE12B))
  [MathomirUiProbe]::Send($main,273,0xE12B) | Out-Null
  [MathomirUiProbe]::Send($main,273,0xE103) | Out-Null
  [xml]$undone=Get-Content -LiteralPath $fixture -Raw
  $restoredObject=$undone.SelectSingleNode('/mathomir/*[self::o or self::obj]')
  if ($restoredObject.X -ne '100' -or $restoredObject.Y -ne '150') { throw ("Undo did not restore the grip move. Saved position: $($restoredObject.X), $($restoredObject.Y)") }
  Write-Output 'Move grip smoke passed: drag without whole-object selection, save expected position, Undo restores position.'
  for ($x=105; $x -le 190; $x+=5) { [MathomirUiProbe]::Mouse($view,512,0,$x,140) }
  $sizeGrip=[MathomirUiProbe]::SizeGrip($view)
  [MathomirUiProbe]::Mouse($view,513,1,$sizeGrip[0],$sizeGrip[1])
  [MathomirUiProbe]::Mouse($view,512,1,($sizeGrip[0]+12),($sizeGrip[1]+12))
  [MathomirUiProbe]::Mouse($view,512,1,($sizeGrip[0]+24),($sizeGrip[1]+24))
  [MathomirUiProbe]::Send($main,273,0xE103) | Out-Null
  [xml]$firstResize=Get-Content -LiteralPath $fixture -Raw
  $firstExpression=$firstResize.SelectSingleNode('/mathomir/*[self::o or self::obj][1]/*[self::ex or self::expr]')
  $expectedFont=if($firstExpression.HasAttribute('fh')){[int]$firstExpression.fh}else{[int]$firstExpression.fnt_h}
  if($expectedFont -le 100 -or $expectedFont -gt 200){throw "The corner drag produced an unexpected size: $expectedFont"}
  for ($repeat=0; $repeat -lt 30; $repeat++) { [MathomirUiProbe]::Mouse($view,512,1,($sizeGrip[0]+24),($sizeGrip[1]+24)) }
  $actualGrip=[MathomirUiProbe]::SizeGrip($view)
  Write-Output "Resize grip before: $sizeGrip; after: $actualGrip; font: $expectedFont"
  [MathomirUiProbe]::Mouse($view,514,0,($sizeGrip[0]+24),($sizeGrip[1]+24))
  for ($repeat=0; $repeat -lt 10; $repeat++) { [MathomirUiProbe]::Mouse($view,512,0,($sizeGrip[0]+80),($sizeGrip[1]+80)) }
  [MathomirUiProbe]::Send($main,273,0xE103) | Out-Null
  [xml]$resized=Get-Content -LiteralPath $fixture -Raw
  $resizedExpression=$resized.SelectSingleNode('/mathomir/*[self::o or self::obj][1]/*[self::ex or self::expr]')
  $fontSize=if ($resizedExpression.HasAttribute('fh')) {[int]$resizedExpression.fh} else {[int]$resizedExpression.fnt_h}
  if ([Math]::Abs($fontSize-$expectedFont) -gt 1) { throw "Repeated stationary resize events compounded the font size or release failed: $fontSize, expected $expectedFont." }
  $resizedChild=$resizedExpression.SelectSingleNode('./elm[@tp="8"]/*[self::ex or self::expr]')
  $childSize=if ($resizedChild.HasAttribute('fh')) {[int]$resizedChild.fh} else {[int]$resizedChild.fnt_h}
  if ([Math]::Abs($childSize-90*$fontSize/100) -gt 1) { throw "Nested root contents scaled incorrectly: $childSize, expected proportional root contents." }
  [MathomirUiProbe]::Send($main,273,0xE12B) | Out-Null
  for ($x=105; $x -le 190; $x+=5) { [MathomirUiProbe]::Mouse($view,512,0,$x,140) }
  $sizeGrip=[MathomirUiProbe]::SizeGrip($view)
  [MathomirUiProbe]::Mouse($view,513,1,$sizeGrip[0],$sizeGrip[1])
  [MathomirUiProbe]::Mouse($view,512,1,($sizeGrip[0]+60),($sizeGrip[1]+60))
  [MathomirUiProbe]::Send($view,256,27) | Out-Null
  [MathomirUiProbe]::Send($view,258,27) | Out-Null
  [MathomirUiProbe]::Send($main,273,0xE103) | Out-Null
  [xml]$cancelled=Get-Content -LiteralPath $fixture -Raw
  $cancelledExpression=$cancelled.SelectSingleNode('/mathomir/*[self::o or self::obj][1]/*[self::ex or self::expr]')
  $cancelledSize=if ($cancelledExpression.HasAttribute('fh')) {[int]$cancelledExpression.fh} else {[int]$cancelledExpression.fnt_h}
  if ($cancelledSize -ne 100) { throw "Escape did not restore the original font size: $cancelledSize." }
  Write-Output 'Resize regression passed: 30 identical drag events do not compound size, grip stays at the object corner, nested root stays proportional, release stops growth, Undo and Escape restore size.'
  [MathomirUiProbe]::Mouse($view,513,1,130,125)
  [MathomirUiProbe]::Mouse($view,514,0,130,125)
  [MathomirUiProbe]::Mouse($view,515,1,130,125)
  [MathomirUiProbe]::Mouse($view,514,0,130,125)
  foreach ($character in 'constant'.ToCharArray()) { [MathomirUiProbe]::Send($view,258,[int]$character) | Out-Null }
  for ($i=0;$i -lt 8;$i++){[MathomirUiProbe]::ShiftKey($view,37)}
  [MathomirUiProbe]::Send($view,258,[int][char]'r') | Out-Null
  [MathomirUiProbe]::Send($view,258,[int][char]'b') | Out-Null
  [MathomirUiProbe]::Send($main,273,33038) | Out-Null
  [MathomirUiProbe]::Mouse($view,513,1,300,300)
  [MathomirUiProbe]::Mouse($view,514,0,300,300)
  [MathomirUiProbe]::Send($main,273,0xE103) | Out-Null
  [xml]$savedRoot=Get-Content -LiteralPath $fixture -Raw
  $rootNodes=$savedRoot.SelectNodes('//elm[@tp="8"]/*[self::ex or self::expr]')
  if ($rootNodes.Count -ne 1) { throw 'The root expression was lost when placing an annotation.' }
  $rootTokens=($rootNodes[0].SelectNodes('./*[self::var or self::elm[@tp="1"]]') | ForEach-Object {if ($_.HasAttribute('t')) {$_.t} else {$_.tx}}) -join ''
  if ($rootTokens -ne '2x4') { throw "The root's variables changed: $rootTokens" }
  $annotationTokens=($savedRoot.SelectNodes('/mathomir/*[self::o or self::obj]/*[self::ex or self::expr]/*[self::var or self::elm[@tp="1"]]') | ForEach-Object {if ($_.HasAttribute('t')) {$_.t} else {$_.tx}}) -join ''
  if ($annotationTokens -notmatch 'constant') { throw "Typing the annotation did not save its text: $annotationTokens" }
  $coloredRuns=$savedRoot.SelectNodes('/mathomir/*[self::o or self::obj]/*[self::ex or self::expr]/*[self::var or self::elm[@tp="1"]][@color="6" or @clr="6"]')
  $coloredText=($coloredRuns | ForEach-Object {if($_.HasAttribute('t')){$_.t}else{$_.tx}}) -join ''
  if($coloredText -notmatch 'constant'){Write-Output ($savedRoot.SelectNodes('/mathomir/*[self::o or self::obj]/*[self::ex or self::expr]') | ForEach-Object {$_.OuterXml});throw "Highlighted text did not save purple: $coloredText"}
  foreach($run in $coloredRuns){$format=if($run.HasAttribute('f')){$run.f}else{$run.fnt};if(([Convert]::ToInt32($format.Substring(0,2),16) -band 1) -ne 0){throw 'B unexpectedly made highlighted text bold.'}}
  Write-Output 'Writing color passed: highlight constant, R then B preserve selection, purple saves, B does not apply bold.'
  Write-Output 'Root placement smoke passed: hover inside root, double-click above the 2, type constant, click away to finish, save label and preserve root.'
  [MathomirUiProbe]::Send($main,273,33026) | Out-Null
  [MathomirUiProbe]::Send($main,273,0xE103) | Out-Null
  [xml]$piSaved=Get-Content -LiteralPath $fixture -Raw
  $piMinimum=$piSaved.SelectSingleNode('/mathomir/*[*[self::dw or self::draw][@spec="51"]]/subexp[1]/*[self::ex or self::expr]')
  if ($piMinimum.alig -ne '2') { throw 'Pi graph mode did not save its axis setting.' }
  [MathomirUiProbe]::Send($main,273,33029) | Out-Null
  Start-Sleep -Milliseconds 1800
  [MathomirUiProbe]::Send($main,273,0xE103) | Out-Null
  [xml]$resetGraph=Get-Content -LiteralPath $fixture -Raw
  $graphSlots=$resetGraph.SelectNodes('/mathomir/*[*[self::dw or self::draw][@spec="51"]]/subexp')
  if ($graphSlots.Count -lt 12) {throw 'The graph did not create eight function slots.'}
  $resetRange=Get-GraphRange $resetGraph
  if ([Math]::Abs($resetRange[0]+2*[Math]::PI) -gt .001 -or [Math]::Abs($resetRange[1]-2*[Math]::PI) -gt .001) {throw "Graph reset did not restore the pi window: $resetRange"}
  if ($resetRange[2] -lt -5 -or $resetRange[3] -gt 5 -or $resetRange[2] -ge $resetRange[3]) {throw "Graph smart fit did not produce useful finite y limits: $resetRange"}
  [MathomirUiProbe]::Send($main,273,33030) | Out-Null
  Start-Sleep -Milliseconds 500
  [MathomirUiProbe]::Send($main,273,0xE103) | Out-Null
  [xml]$zoomedGraph=Get-Content -LiteralPath $fixture -Raw
  $zoomedRange=Get-GraphRange $zoomedGraph
  $ratio=($zoomedRange[1]-$zoomedRange[0])/($resetRange[1]-$resetRange[0])
  if ([Math]::Abs($ratio-.8) -gt .001) {throw "Graph zoom did not shrink the span gently: $ratio"}
  $zoomedMode=$zoomedGraph.SelectSingleNode('/mathomir/*[*[self::dw or self::draw][@spec="51"]]/subexp[1]/*[self::ex or self::expr]')
  if ($zoomedMode.alig -ne '2') {throw 'Graph zoom lost the saved pi label mode.'}
  [MathomirUiProbe]::Send($main,273,33028) | Out-Null
  Start-Sleep -Milliseconds 1800
  [MathomirUiProbe]::Send($main,273,0xE103) | Out-Null
  [xml]$fitGraph=Get-Content -LiteralPath $fixture -Raw
  $fitRange=Get-GraphRange $fitGraph
  if ([Math]::Abs($fitRange[0]-$zoomedRange[0]) -gt .001 -or [Math]::Abs($fitRange[1]-$zoomedRange[1]) -gt .001) {throw 'Smart fit changed the horizontal viewing window.'}
  [MathomirUiProbe]::Send($main,273,33031) | Out-Null
  Start-Sleep -Milliseconds 500
  [MathomirUiProbe]::Send($main,273,0xE103) | Out-Null
  [xml]$widerGraph=Get-Content -LiteralPath $fixture -Raw
  $widerRange=Get-GraphRange $widerGraph
  if ([Math]::Abs(($widerRange[1]-$widerRange[0])/($fitRange[1]-$fitRange[0])-1.25) -gt .001) {throw 'Graph zoom out did not expand the span by 25%.'}
  Write-Output 'Graph smart zoom passed: pi reset window, finite fitted y range, gentle in/out, horizontal window preservation and saved pi labels.'
  [MathomirUiProbe]::Send($main,273,33027) | Out-Null
  [MathomirUiProbe]::Send($main,273,0xE103) | Out-Null
  [xml]$decimalSaved=Get-Content -LiteralPath $fixture -Raw
  $decimalMinimum=$decimalSaved.SelectSingleNode('/mathomir/*[*[self::dw or self::draw][@spec="51"]]/subexp[1]/*[self::ex or self::expr]')
  if ($decimalMinimum.alig -eq '2' -or $decimalMinimum.alig -eq '1') { throw 'Decimal graph mode did not restore linear labels.' }
  Write-Output 'Graph axis smoke passed: pi fraction mode and decimal mode both save correctly.'
  $search=[MathomirUiProbe]::Child($main,1112)
  if ($search -eq [IntPtr]::Zero -or ![MathomirUiProbe]::IsWindowVisible($search)) { throw 'The permanent Search field is missing or hidden.' }
  [MathomirUiProbe]::Send($main,273,33007) | Out-Null
  [MathomirUiProbe]::SetText($search,'font')
  Start-Sleep -Milliseconds 250
  $popup=[MathomirUiProbe]::Window($appProcess.Id,'Search features')
  if ($popup -eq [IntPtr]::Zero) { throw 'The search dropdown did not open.' }
  $list=[MathomirUiProbe]::Child($popup,1102)
  $fontMatchCount=[MathomirUiProbe]::Send($list,395,0)
  if ($fontMatchCount -le 0) { throw 'Search found no font commands.' }
  [MathomirUiProbe]::SetText($search,'zzzznonexistentfeaturezzzz')
  if ([MathomirUiProbe]::Send($list,395,0) -ne 0) { throw 'Search did not filter an unmatched query.' }
  [MathomirUiProbe]::SetText($search,'smart')
  if ([MathomirUiProbe]::Send($list,395,0) -lt 2) { throw 'Smart sizing commands are missing from search.' }
  [MathomirUiProbe]::SetText($search,'pi fractions')
  if ([MathomirUiProbe]::Send($list,395,0) -lt 1) { throw 'Pi graph labels are missing from search.' }
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
  if ($aboutText -notmatch 'Improved - v13' -or $aboutText -notmatch 'Danijel Gorupec' -or $aboutText -notmatch 'MIT license') { throw 'About version or author credit is missing.' }
  [MathomirUiProbe]::PostMessage($about,273,[IntPtr]1,[IntPtr]::Zero) | Out-Null
  Write-Output "Windows UI smoke passed: visible Search, $fontMatchCount font results, no-match filter, smart sizing, RAD/DEG, About and original author credit."
} finally {
  $appProcess.Refresh()
  if ($appProcess.HasExited) {Write-Output "App exit code: $($appProcess.ExitCode)"}
  if ($env:MATHOMIR_DIAGNOSTIC_STARTUP -and !$appProcess.HasExited) {for($wait=0;$wait -lt 20 -and !$appProcess.HasExited;$wait++){Start-Sleep -Milliseconds 250;$appProcess.Refresh()}}
  if (!$appProcess.HasExited) { Stop-Process -Id $appProcess.Id -Force }
  Get-Content (Join-Path (Split-Path $exe) 'smoke-stderr.txt') -ErrorAction SilentlyContinue
  Get-ChildItem (Split-Path $exe) -Filter 'asan*' | ForEach-Object { Get-Content $_.FullName }
}
