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
  [StructLayout(LayoutKind.Sequential)] public struct Rect {public int Left,Top,Right,Bottom;}
  [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr hwnd,out Rect rect);
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd,out Rect rect);
  [DllImport("user32.dll")] static extern int GetSystemMetrics(int index);
  [DllImport("user32.dll")] static extern bool MoveWindow(IntPtr hwnd,int x,int y,int width,int height,bool repaint);
  public static Rect WindowRect(IntPtr hwnd){Rect rect;GetWindowRect(hwnd,out rect);return rect;}
  public static void Resize(IntPtr hwnd,Rect rect,int delta){int width=Math.Min(GetSystemMetrics(0),rect.Right-rect.Left+delta);int left=Math.Max(0,Math.Min(rect.Left,GetSystemMetrics(0)-width));if(!MoveWindow(hwnd,left,rect.Top,width,rect.Bottom-rect.Top,true))throw new Exception("Could not resize window");}
  public static bool WhiteWidth(IntPtr hwnd){Rect rect;GetClientRect(hwnd,out rect);IntPtr dc=GetDC(hwnd);try{uint a=GetPixel(dc,3,100),b=GetPixel(dc,rect.Right-3,100),c=GetPixel(dc,rect.Right-3,200);Console.WriteLine("Paper pixel probe: width="+rect.Right+", left="+a.ToString("X")+", right="+b.ToString("X")+","+c.ToString("X"));return a==0xFFFFFF && b==0xFFFFFF && c==0xFFFFFF;}finally{ReleaseDC(hwnd,dc);}}
  [StructLayout(LayoutKind.Sequential)] struct ScrollInfo {public uint Size,Mask;public int Min,Max;public uint Page;public int Pos,Track;}
  [DllImport("user32.dll")] static extern bool GetScrollInfo(IntPtr hwnd,int bar,ref ScrollInfo info);
  public static bool HorizontalTravel(IntPtr hwnd){ScrollInfo info=new ScrollInfo();info.Size=(uint)Marshal.SizeOf(typeof(ScrollInfo));info.Mask=7;if(!GetScrollInfo(hwnd,0,ref info))throw new Exception("Could not inspect horizontal scrollbar");return info.Max-info.Min-Math.Max(0,(int)info.Page-1)>0;}
  public static bool PageEdgeMarks(IntPtr hwnd){Rect r;GetClientRect(hwnd,out r);IntPtr dc=GetDC(hwnd);try{int left=0,right=0;for(int y=20;y<Math.Min(r.Bottom,350);y++){for(int x=0;x<5;x++){uint c=GetPixel(dc,x,y);if((c&255)>150 && ((c>>8)&255)<80 && ((c>>16)&255)<80){left++;break;}}for(int x=Math.Max(0,r.Right-20);x<r.Right;x++){uint c=GetPixel(dc,x,y);if((c&255)>150 && ((c>>8)&255)<80 && ((c>>16)&255)<80){right++;break;}}}return left>10 && right>10;}finally{ReleaseDC(hwnd,dc);}}
  public static int[] PlotArea(IntPtr hwnd){IntPtr dc=GetDC(hwnd);try{int left=102;while(left<250 && GetPixel(dc,left,170)==0xE0E0E0)left++;int bottom=418;while(bottom>300 && GetPixel(dc,170,bottom)==0xE0E0E0)bottom--;return new int[]{left,102,598,bottom};}finally{ReleaseDC(hwnd,dc);}}
  public static bool CurveNear(IntPtr hwnd,int x,int y,int radius){IntPtr dc=GetDC(hwnd);try{for(int j=-radius;j<=radius;j++)for(int i=-radius;i<=radius;i++)if(GetPixel(dc,x+i,y+j)==0)return true;return false;}finally{ReleaseDC(hwnd,dc);}}
  public static bool OpenCircle(IntPtr hwnd,int x,int y){IntPtr dc=GetDC(hwnd);try{for(int j=-2;j<=2;j++)for(int i=-2;i<=2;i++){int cx=x+i,cy=y+j;if(GetPixel(dc,cx,cy)!=0xFFFFFF)continue;bool left=false,right=false,top=false,bottom=false;for(int r=3;r<=7;r++){left|=GetPixel(dc,cx-r,cy)==0;right|=GetPixel(dc,cx+r,cy)==0;top|=GetPixel(dc,cx,cy-r)==0;bottom|=GetPixel(dc,cx,cy+r)==0;}if(left&&right&&top&&bottom)return true;}return false;}finally{ReleaseDC(hwnd,dc);}}
  public static int MoveGripY(IntPtr hwnd,int x) { IntPtr dc=GetDC(hwnd); try { int first=-1,last=-1; for(int y=20;y<190;y++) if(GetPixel(dc,x,y)==0x009B5F2D){if(first<0)first=y;last=y;} if(first<0) throw new Exception("Move grip was not painted at the object's upper-left"); return (first+last)/2; } finally {ReleaseDC(hwnd,dc);} }
  public static bool SizeGripAt(IntPtr hwnd,int x,int y) { IntPtr dc=GetDC(hwnd); try { for(int k=-6;k<=6;k++) if(GetPixel(dc,x+k,y-6)!=0x009B5F2D) return false; return true; }finally{ReleaseDC(hwnd,dc);} }
  public static int[] SizeGrip(IntPtr hwnd) { IntPtr dc=GetDC(hwnd); try { for(int y=130;y<300;y++) for(int x=110;x<290;x++) {bool line=true;for(int k=0;k<13;k++)if(GetPixel(dc,x+k,y)!=0x009B5F2D){line=false;break;}if(line)return new int[]{x+6,y+6};} throw new Exception("Size grip square was not painted");}finally{ReleaseDC(hwnd,dc);} }
  [DllImport("user32.dll")] static extern IntPtr GetFocus();
  public static IntPtr Focus(IntPtr hwnd){uint pid;uint target=GetWindowThreadProcessId(hwnd,out pid);uint current=GetCurrentThreadId();if(!AttachThreadInput(current,target,true))throw new Exception("Could not inspect keyboard focus");try{return GetFocus();}finally{AttachThreadInput(current,target,false);}}
  [DllImport("user32.dll")] static extern bool AttachThreadInput(uint current,uint target,bool attach);
  [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] static extern bool GetKeyboardState(byte[] state);
  [DllImport("user32.dll")] static extern bool SetKeyboardState(byte[] state);
  public static void ShiftKey(IntPtr hwnd,int key) {uint pid;uint target=GetWindowThreadProcessId(hwnd,out pid);uint current=GetCurrentThreadId();if(!AttachThreadInput(current,target,true))throw new Exception("Could not share selection key state");byte[] old=new byte[256];GetKeyboardState(old);byte[] state=(byte[])old.Clone();state[16]=128;SetKeyboardState(state);try{UIntPtr result;if(SendMessageTimeout(hwnd,256,(IntPtr)key,(IntPtr)0x01000001,2,3000,out result)==IntPtr.Zero)throw new Exception("Selection arrow did not respond");}finally{SetKeyboardState(old);AttachThreadInput(current,target,false);}}
  [StructLayout(LayoutKind.Sequential)] struct Point {public int X,Y;}
  [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr hwnd,ref Point point);
  [DllImport("user32.dll")] static extern bool SetCursorPos(int x,int y);
  public static void Mouse(IntPtr hwnd,uint msg,int flags,int x,int y) { if(msg==512 && flags==0){Point point=new Point{X=x,Y=y};ClientToScreen(hwnd,ref point);SetCursorPos(point.X,point.Y);System.Threading.Thread.Sleep(50);} UIntPtr result; int position=(y<<16)|(x&65535); if(SendMessageTimeout(hwnd,msg,(IntPtr)flags,(IntPtr)position,2,3000,out result)==IntPtr.Zero) throw new Exception("Mouse action did not respond"); }
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
  Start-Sleep -Milliseconds 500
  $startupView=[MathomirUiProbe]::Child($main,0xE900)
  if(![MathomirUiProbe]::WhiteWidth($startupView)){throw 'Startup paper leaves a gray strip at the left or right edge.'}
  if([MathomirUiProbe]::HorizontalTravel($startupView)){throw 'Fit width leaves horizontal scrolling available.'}
  $fitButton=[MathomirUiProbe]::Child($main,1117)
  if($fitButton -eq [IntPtr]::Zero -or ![MathomirUiProbe]::IsWindowVisible($fitButton)){throw 'Visible Fit width button is missing.'}
  $originalWindow=[MathomirUiProbe]::WindowRect($main)
  [MathomirUiProbe]::Resize($main,$originalWindow,-170)
  Start-Sleep -Milliseconds 300
  if(![MathomirUiProbe]::WhiteWidth($startupView)){throw 'Paper width did not follow window resizing.'}
  if([MathomirUiProbe]::HorizontalTravel($startupView)){throw 'Fit width leaves horizontal scrolling available.'}
  [MathomirUiProbe]::Resize($main,$originalWindow,(1000-($originalWindow.Right-$originalWindow.Left)))
  Start-Sleep -Milliseconds 200
  [MathomirUiProbe]::Send($startupView,273,32778)|Out-Null
  Start-Sleep -Milliseconds 100
  if([MathomirUiProbe]::WhiteWidth($startupView)){throw 'Manual zoom was immediately overridden by auto-fit.'}
  if(![MathomirUiProbe]::HorizontalTravel($startupView)){throw 'Manual zoom did not restore horizontal scrolling.'}
  [MathomirUiProbe]::Send($fitButton,245,0)|Out-Null
  Start-Sleep -Milliseconds 100
  if(![MathomirUiProbe]::WhiteWidth($startupView)){throw 'Fit width button did not remove the gray strip.'}
  if([MathomirUiProbe]::HorizontalTravel($startupView)){throw 'Fit width leaves horizontal scrolling available.'}
  [MathomirUiProbe]::Resize($main,$originalWindow,0)
  Start-Sleep -Milliseconds 300
  if(![MathomirUiProbe]::WhiteWidth($startupView)){throw 'Fit width mode did not stay active after restoring window size.'}
  if([MathomirUiProbe]::HorizontalTravel($startupView)){throw 'Restoring the window reactivated horizontal scrolling in Fit width mode.'}
  [MathomirUiProbe]::Send($startupView,276,3)|Out-Null
  Start-Sleep -Milliseconds 100
  if([MathomirUiProbe]::HorizontalTravel($startupView) -or ![MathomirUiProbe]::WhiteWidth($startupView)){throw 'A bottom scrollbar action displaced the fitted page.'}
  $edgeFixture=Join-Path (Split-Path $exe) 'page-edges-smoke.mom'
  @'
<?xml version="1.0"?>
<mathomir>
<o t="2" X="16" Y="100"><dw t="21" d="96|0,0;0,6400" /></o>
<o t="2" X="1213" Y="100"><dw t="21" d="96|0,0;0,6400" /></o>
</mathomir>
'@ | Set-Content -LiteralPath $edgeFixture -Encoding ascii
  [MathomirUiProbe]::OpenFile($main,$edgeFixture)
  Start-Sleep -Milliseconds 350
  [MathomirUiProbe]::Send($fitButton,245,0)|Out-Null
  Start-Sleep -Milliseconds 150
  if(![MathomirUiProbe]::PageEdgeMarks($startupView)){throw 'Fit width clipped a marker at the left or right paper edge.'}
  if([MathomirUiProbe]::HorizontalTravel($startupView)){throw 'Loading a document restored horizontal travel in Fit width mode.'}
  Write-Output 'Page width passed: startup fills between scrollbars, resize follows width, manual zoom remains usable, visible Fit width button restores filling.'
  [MathomirUiProbe]::Send($main,273,32775)|Out-Null
  [MathomirUiProbe]::Send($startupView,276,0)|Out-Null
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
  for($x=105;$x -le 190;$x+=5){[MathomirUiProbe]::Mouse($view,512,0,$x,140)}
  $corner=[MathomirUiProbe]::SizeGrip($view)
  $lowerX=$corner[0]+22;$lowerY=$corner[1]+12
  [MathomirUiProbe]::Mouse($view,513,1,$lowerX,$lowerY)
  [MathomirUiProbe]::Mouse($view,512,1,($lowerX+20),($lowerY+15))
  [MathomirUiProbe]::Mouse($view,514,0,($lowerX+20),($lowerY+15))
  [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null
  [xml]$lowerMoved=Get-Content $fixture -Raw
  $lowerObject=$lowerMoved.SelectSingleNode('/mathomir/*[1]')
  if($lowerObject.X -ne '120' -or $lowerObject.Y -ne '165'){throw 'Lower-right move grip did not move by the pointer displacement.'}
  [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null
  [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null
  Write-Output 'Second move grip passed: right/below the resize corner, correct displacement, Undo.'

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
  for($x=105;$x -le 190;$x+=5){[MathomirUiProbe]::Mouse($view,512,0,$x,140)}
  [MathomirUiProbe]::SizeGrip($view)|Out-Null
  [MathomirUiProbe]::Mouse($view,512,0,900,50)
  Start-Sleep -Milliseconds 100
  $lingeringGrip=$true
  try{[MathomirUiProbe]::SizeGrip($view)|Out-Null}catch{$lingeringGrip=$false}
  if($lingeringGrip){throw 'Object grip lingered after moving the pointer away.'}
  Write-Output 'Grip hover passed: leaving the object clears its grips.'

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
  [MathomirUiProbe]::Mouse($view,512,0,480,410)
  [MathomirUiProbe]::Mouse($view,513,1,480,410)
  [MathomirUiProbe]::Mouse($view,514,0,480,410)
  Start-Sleep -Milliseconds 500
  [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null
  [xml]$buttonPi=Get-Content -LiteralPath $fixture -Raw
  if($buttonPi.SelectSingleNode('/mathomir/*[*[self::dw or self::draw][@spec="51"]]/subexp[1]/*[self::ex or self::expr]').alig -ne '2'){throw 'The graph pi/decimal button did not enable pi fractions.'}
  [MathomirUiProbe]::Mouse($view,512,0,480,410)
  [MathomirUiProbe]::Mouse($view,513,1,480,410)
  [MathomirUiProbe]::Mouse($view,514,0,480,410)
  Start-Sleep -Milliseconds 500
  [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null
  [xml]$buttonDecimal=Get-Content -LiteralPath $fixture -Raw
  if($buttonDecimal.SelectSingleNode('/mathomir/*[*[self::dw or self::draw][@spec="51"]]/subexp[1]/*[self::ex or self::expr]').alig -eq '2'){throw 'The graph pi/decimal button did not return to decimal labels.'}
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
  [MathomirUiProbe]::SetText($search,'use degrees')
  [MathomirUiProbe]::Mouse($list,513,1,20,8)
  [MathomirUiProbe]::Mouse($list,514,0,20,8)
  Start-Sleep -Milliseconds 800
  if([MathomirUiProbe]::IsWindowVisible($popup)){throw 'Search dropdown reopened after choosing a result.'}
  if([MathomirUiProbe]::Focus($main) -ne $view){throw 'Search result did not leave keyboard focus on the page.'}
  [MathomirUiProbe]::Mouse($view,512,0,650,450)
  Start-Sleep -Milliseconds 500
  if([MathomirUiProbe]::Focus($main) -ne $view){throw 'Keyboard focus jumped back into Search after moving across the page.'}
  [MathomirUiProbe]::Send($main,273,33007)|Out-Null
  [MathomirUiProbe]::SetText($search,'use radians')
  [MathomirUiProbe]::PostMessage($search,256,[IntPtr]13,[IntPtr]::Zero)|Out-Null
  Start-Sleep -Milliseconds 800
  if([MathomirUiProbe]::IsWindowVisible($popup) -or [MathomirUiProbe]::Focus($main) -ne $view){throw 'Keyboard search selection did not return focus to the page.'}
  [MathomirUiProbe]::Send($main,273,33007)|Out-Null
  [MathomirUiProbe]::SetText($search,'about')
  [MathomirUiProbe]::Mouse($list,513,1,20,8)
  [MathomirUiProbe]::Mouse($list,514,0,20,8)
  $searchAbout=[IntPtr]::Zero
  for($attempt=0;$attempt -lt 30;$attempt++){Start-Sleep -Milliseconds 100;$searchAbout=[MathomirUiProbe]::Window($appProcess.Id,'About Math-o-mir Improved');if($searchAbout -ne [IntPtr]::Zero){break}}
  if($searchAbout -eq [IntPtr]::Zero){throw 'Search could not open the About dialog.'}
  [MathomirUiProbe]::PostMessage($searchAbout,273,[IntPtr]1,[IntPtr]::Zero)|Out-Null
  Start-Sleep -Milliseconds 800
  if([MathomirUiProbe]::IsWindowVisible($popup) -or [MathomirUiProbe]::Focus($main) -ne $view){throw 'Closing a searched dialog returned focus to Search.'}
  Write-Output 'Search focus passed: mouse choice returns to page, remains there after pointer movement, and stays there after closing a searched dialog.'
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
  if ($aboutText -notmatch 'Improved - v18' -or $aboutText -notmatch 'Danijel Gorupec' -or $aboutText -notmatch 'MIT license') { throw 'About version or author credit is missing.' }
  [MathomirUiProbe]::PostMessage($about,273,[IntPtr]1,[IntPtr]::Zero) | Out-Null
  Write-Output "Windows UI smoke passed: visible Search, $fontMatchCount font results, no-match filter, smart sizing, RAD/DEG, About and original author credit."

  [MathomirUiProbe]::PostMessage($main,273,[IntPtr]33046,[IntPtr]::Zero)|Out-Null
  $tableDialog=[IntPtr]::Zero
  for($attempt=0;$attempt -lt 40;$attempt++){Start-Sleep -Milliseconds 100;$tableDialog=[MathomirUiProbe]::Window($appProcess.Id,'Configure table');if($tableDialog -ne [IntPtr]::Zero){break}}
  if($tableDialog -eq [IntPtr]::Zero){throw 'Table setup did not open.'}
  [MathomirUiProbe]::SetText([MathomirUiProbe]::Child($tableDialog,1121),'3')
  [MathomirUiProbe]::SetText([MathomirUiProbe]::Child($tableDialog,1122),'4')
  [MathomirUiProbe]::SetText([MathomirUiProbe]::Child($tableDialog,1123),'150')
  [MathomirUiProbe]::Send([MathomirUiProbe]::Child($tableDialog,1125),334,1)|Out-Null
  [MathomirUiProbe]::PostMessage($tableDialog,273,[IntPtr]1,[IntPtr]::Zero)|Out-Null
  for($attempt=0;$attempt -lt 40;$attempt++){Start-Sleep -Milliseconds 100;if(![MathomirUiProbe]::IsWindowVisible($tableDialog)){break}}
  Start-Sleep -Milliseconds 400
  [MathomirUiProbe]::Mouse($view,512,0,450,220)
  [MathomirUiProbe]::Mouse($view,513,1,450,220)
  [MathomirUiProbe]::Mouse($view,514,0,450,220)
  [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null
  [xml]$tableSaved=Get-Content $fixture -Raw
  $tableObject=$tableSaved.SelectSingleNode('/mathomir/*[last()]')
  $cells=$tableObject.SelectSingleNode('./*[self::ex or self::expr]/*[self::bra or self::elm[@tp="5"]]/*[self::ex or self::expr]')
  if(!$cells){Write-Output $tableObject.OuterXml;throw 'Editable table was not placed.'}
  if($cells.SelectNodes('./col_sep').Count -ne 9){throw 'Configured table did not create four columns in three rows.'}
  if($cells.SelectNodes('./row_sep').Count -lt 2){throw 'Configured table did not create three rows.'}
  if($cells.SelectNodes('./col_sep[contains(@data,"-")]').Count -ne 9){throw 'Table borders were not retained.'}
  $tableFont=$tableObject.SelectSingleNode('./*[self::ex or self::expr]')
  if(($tableFont.fh -ne '150') -and ($tableFont.fnt_h -ne '150')){Write-Output $tableObject.OuterXml;throw 'Configured table font was not retained.'}
  Write-Output 'Table setup passed: row/column/font/alignment controls, placement, native editable cells and saved borders.'
  $intervalCounts=@()
  foreach($command in 33042,33043,33044,33045){
    [MathomirUiProbe]::Send($main,273,$command)|Out-Null
    $placeY=210+45*($command-33042)
    [MathomirUiProbe]::Mouse($view,512,0,100,$placeY)
    [MathomirUiProbe]::Mouse($view,513,1,100,$placeY)
    [MathomirUiProbe]::Mouse($view,514,0,100,$placeY)
    [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null
    [xml]$intervalSaved=Get-Content $fixture -Raw
    $interval=$intervalSaved.SelectSingleNode('/mathomir/*[last()]')
    $labels=$interval.SelectNodes('./subexp')
    if($labels.Count -ne 2){throw "Interval $command did not place with two editable endpoint labels."}
    $segments=0
    foreach($line in $interval.SelectNodes('./*[self::dw or self::draw]')){if($line.HasAttribute('d')){$segments+=($line.d.Split(';').Count-1)}else{$segments+=@($line.Attributes | Where-Object {$_.Name -match '^X[0-9]+$'}).Count-1}}
    $intervalCounts+=$segments
  }
  if($intervalCounts[1]-$intervalCounts[0] -ne 18 -or $intervalCounts[2]-$intervalCounts[0] -ne 9 -or $intervalCounts[3]-$intervalCounts[0] -ne 9){Write-Output $interval.OuterXml;throw "Endpoint fill choices are inconsistent: $intervalCounts"}
  $beforeRotation=$interval.OuterXml
  $intervalX=0;$intervalY=0
  foreach($obj in $intervalSaved.SelectNodes('/mathomir/*')){if($obj.HasAttribute('X')){$intervalX=[int]$obj.X};if($obj.HasAttribute('Y')){$intervalY=[int]$obj.Y}}
  $firstLine=$interval.SelectSingleNode('./*[self::dw or self::draw]')
  if($firstLine.HasAttribute('d')){$axisData=$firstLine.d.Split('|')[1].Split(';')[0].Split(',');$axisY=[int]$axisData[1]/32}else{$axisY=[int]$firstLine.Y1/1000}
  for($probe=15;$probe -lt 50;$probe+=5){[MathomirUiProbe]::Mouse($view,512,0,($intervalX+$probe),($intervalY+$axisY))}
  [MathomirUiProbe]::Send($main,273,33008)|Out-Null
  $handleX=$intervalX+252;$handleY=$intervalY-10
  [MathomirUiProbe]::Mouse($view,513,1,$handleX,$handleY)
  [MathomirUiProbe]::Mouse($view,512,1,($intervalX+120),($intervalY+150))
  [MathomirUiProbe]::Mouse($view,514,0,($intervalX+120),($intervalY+150))
  [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null
  [xml]$rotated=Get-Content $fixture -Raw
  $rotatedInterval=$rotated.SelectSingleNode('/mathomir/*[last()]')
  if($rotatedInterval.OuterXml -eq $beforeRotation){throw 'Drawing rotation did not change the interval geometry.'}
  if($rotatedInterval.SelectNodes('./subexp/*[@rot_mdeg]').Count -ne 2){throw 'Endpoint labels did not rotate with the interval.'}
  [MathomirUiProbe]::Send($main,273,0xE12B)|Out-Null
  [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null
  [xml]$rotationUndo=Get-Content $fixture -Raw
  if($rotationUndo.SelectSingleNode('/mathomir/*[last()]').OuterXml -ne $beforeRotation){throw 'Undo did not restore interval geometry.'}
  Write-Output 'Interval and drawing rotation passed: four presets, correct open/closed dots, editable labels rotate with the drawing, Undo restores geometry.'
  foreach($tool in 33047..33050) {
    [MathomirUiProbe]::Send($main,273,$tool)|Out-Null
    for($click=0;$click -lt 20;$click++) {
      [MathomirUiProbe]::Mouse($view,512,0,800,160)
      [MathomirUiProbe]::Mouse($view,513,1,800,160)
      [MathomirUiProbe]::Mouse($view,514,0,800,160)
    }
    [MathomirUiProbe]::Mouse($view,512,0,780,180)
    [MathomirUiProbe]::Mouse($view,513,1,780,180)
    [MathomirUiProbe]::Mouse($view,512,1,820,210)
    [MathomirUiProbe]::Mouse($view,514,0,820,210)
    [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null
    [xml]$drawingSaved=Get-Content $fixture -Raw
    if(!$drawingSaved.SelectSingleNode('/mathomir/*[last()]/*[self::dw or self::draw]')){throw "Drawing tool $tool failed after repeated clicks."}
    [MathomirUiProbe]::Send($view,258,27)|Out-Null
  }
  Write-Output 'Drawing-mode regression passed: 20 clicks without Escape followed by a stroke, for pen, line, rectangle and ellipse.'
  $castY=110
  foreach($code in @('inf','frac','int','lim','vec','eq','sqrt','pm','pi','sin','subseteq')) {
    [MathomirUiProbe]::Send($view,258,27)|Out-Null
    [MathomirUiProbe]::Mouse($view,512,0,650,$castY)
    [MathomirUiProbe]::Mouse($view,513,1,650,$castY)
    [MathomirUiProbe]::Mouse($view,514,0,650,$castY)
    foreach($character in ($code+' 1').ToCharArray()){[MathomirUiProbe]::Send($view,258,[int]$character)|Out-Null}
    [MathomirUiProbe]::Send($view,258,27)|Out-Null
    [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null
    [xml]$castSaved=Get-Content $fixture -Raw
    $cast=$castSaved.SelectSingleNode('/mathomir/*[last()]/*[self::ex or self::expr]')
    if(!$cast){throw "Shortcut $code did not create a math expression."}
    $letters=($cast.SelectNodes('.//var')|ForEach-Object {if($_.HasAttribute("t")){$_.t}else{$_.tx}}) -join ''
    if($letters.Contains($code)){Write-Output $cast.OuterXml;throw "Shortcut $code was left as letters."}
    $expectedTypes=@{int=7;lim=6;eq=2;sqrt=8;pm=2;sin=6;subseteq=2}
    if($expectedTypes.ContainsKey($code)) {
      $type=$expectedTypes[$code];$tag=@{2='opr';6='fun'}[$type]
      $found=$cast.SelectSingleNode("./elm[@tp='$type']")
      if(!$found -and $tag){$found=$cast.SelectSingleNode("./$tag")}
      if(!$found){Write-Output $cast.OuterXml;throw "Shortcut $code lost its native structure."}
    }
    if($code -eq 'inf') {
      $symbol=$cast.SelectSingleNode('./var | ./elm[@tp="1"]')
      $font=if($symbol.HasAttribute('f')){$symbol.f}else{$symbol.fnt}
      if(!$font -or ([Convert]::ToInt32($font.Substring(0,2),16) -band 224) -ne 96){Write-Output $cast.OuterXml;throw 'Infinity is not using the native math symbol font.'}
    }
    if($code -eq 'frac' -and !$cast.SelectSingleNode('./fra | ./elm[@tp="4"]')){Write-Output $cast.OuterXml;throw 'Fraction shortcut lost its structure.'}
    if($code -eq 'vec' -and !$cast.SelectSingleNode('./bra | ./elm[@tp="5"]')){throw 'Vector shortcut lost its editable cells.'}
    $castY+=35
  }
  foreach($word in @('limit','infinite','fraction')) {
    [MathomirUiProbe]::Mouse($view,512,0,680,$castY)
    [MathomirUiProbe]::Mouse($view,513,1,680,$castY)
    [MathomirUiProbe]::Mouse($view,514,0,680,$castY)
    foreach($character in ($word+' ').ToCharArray()){[MathomirUiProbe]::Send($view,258,[int]$character)|Out-Null}
    [MathomirUiProbe]::Send($view,258,27)|Out-Null
    [MathomirUiProbe]::Send($main,273,0xE103)|Out-Null
    [xml]$wordSaved=Get-Content $fixture -Raw
    $lastExpression=$wordSaved.SelectSingleNode('/mathomir/*[last()]/*[self::ex or self::expr]')
    $letters=($lastExpression.SelectNodes('.//var | .//elm[@tp="1"]')|ForEach-Object {if($_.HasAttribute('t')){$_.t}else{$_.tx}}) -join ''
    if($letters -ne $word){Write-Output $lastExpression.OuterXml;throw "Ordinary name $word was changed by a default cast."}
    $castY+=35
  }
  Write-Output 'Default casts passed: infinity, fraction, integral, limit, vector, equals, root, plus/minus, pi, sine and subseteq expand with Space.'
  $domainFixture=Join-Path (Split-Path $exe) 'graph-domain-smoke.mom'
  $cases=@(
    @{name='sinc';xmin=-2.7;xmax=3.3;ymin=-.2;ymax=1.4;formula='<fra E1="n" E2="d"><ex><fun t="sin" f="20" E1=""><ex br="2"><var t="x" f="00" /></ex></fun></ex><ex><var t="x" f="00" /></ex></fra>';hx=0;hy=1},
    @{name='rational';xmin=-3.13;xmax=6.07;ymin=-2;ymax=2;formula='<fra E1="n" E2="d"><ex><elm tp="5" E1=""><ex><var t="x" f="00" /><opr s="+" /><var t="2" f="00" /></ex></elm><elm tp="5" E1=""><ex><var t="x" f="00" /><opr s="-" /><var t="1" f="00" /></ex></elm></ex><ex><elm tp="5" E1=""><ex><var t="x" f="00" /><opr s="+" /><var t="2" f="00" /></ex></elm><elm tp="5" E1=""><ex><var t="x" f="00" /><opr s="-" /><var t="5" f="00" /></ex></elm></ex></fra>';hx=-2;hy=(3/7)},
    @{name='power';xmin=-2.7;xmax=3.3;ymin=-.2;ymax=3;formula='<elm tp="3" E1="b" E2="p"><ex><var t="x" f="00" /></ex><ex><fra E1="n" E2="d"><ex><var t="2" f="00" /></ex><ex><var t="3" f="00" /></ex></fra></ex></elm>';cx=-1;cy=1},
    @{name='semicircle';xmin=-1.7;xmax=1.3;ymin=-.2;ymax=1.4;formula='<elm tp="8" E1=""><ex><var t="1" f="00" /><opr s="-" /><elm tp="3" E1="b" E2="p"><ex><var t="x" f="00" /></ex><ex><var t="2" f="00" /></ex></elm></ex></elm>';cx=1;cy=0}
  )
  foreach($case in $cases){
    $axis=@($case.xmin,$case.xmax,$case.ymin,$case.ymax)|ForEach-Object {'<subexp d="0,0;2000,704"><ex fh="100"><var t="'+$_+'" f="00" /></ex></subexp>'}
    $xml='<?xml version="1.0"?><mathomir><o t="2" X="100" Y="100"><dw spec="51" d="32|32,32;16000,32;:,10240;32,:;:,32" />'+($axis -join '')+'<subexp d="0,0;4000,1000"><ex fh="100">'+$case.formula+'</ex></subexp></o></mathomir>'
    $xml|Set-Content -LiteralPath $domainFixture -Encoding ascii
    [MathomirUiProbe]::Send($view,258,27)|Out-Null
    [MathomirUiProbe]::OpenFile($main,$domainFixture)
    Start-Sleep -Milliseconds 2000
    [MathomirUiProbe]::Mouse($view,512,0,850,50)
    $area=[MathomirUiProbe]::PlotArea($view)
    if($case.ContainsKey('hx')){$px=[int]($area[0]+($case.hx-$case.xmin)/($case.xmax-$case.xmin)*($area[2]-$area[0]));$py=[int]($area[3]-($case.hy-$case.ymin)/($case.ymax-$case.ymin)*($area[3]-$area[1]));if(![MathomirUiProbe]::OpenCircle($view,$px,$py)){throw "No open circle in $($case.name) at $px,$py; plot area $area"}}
    else{$px=[int]($area[0]+($case.cx-$case.xmin)/($case.xmax-$case.xmin)*($area[2]-$area[0]));$py=[int]($area[3]-($case.cy-$case.ymin)/($case.ymax-$case.ymin)*($area[3]-$area[1]));if(![MathomirUiProbe]::CurveNear($view,$px,$py,4)){throw "Missing real branch or domain endpoint in $($case.name) at $px,$py"}}
    Write-Output "Native graph domain passed: $($case.name)"
  }

  Start-Sleep -Milliseconds 300
  $recoveryFolder=Join-Path $env:LOCALAPPDATA 'MathomirImproved/Recovery'
  $before=@(Get-ChildItem $recoveryFolder -Filter 'Recovery-*.mom' -ErrorAction SilentlyContinue).Count
  [MathomirUiProbe]::Send($main,273,33010) | Out-Null
  Start-Sleep -Milliseconds 6000
  $latest=Join-Path $recoveryFolder 'Latest.mom'
  if (!(Test-Path $latest)) {throw 'No current recovery snapshot was written.'}
  [xml]$firstRecovery=Get-Content $latest -Raw
  if ((($firstRecovery.SelectNodes('//var') | ForEach-Object {$_.t}) -join '') -notmatch 'constant') {throw 'Recovery lost recent annotation text.'}
  $firstVersions=@(Get-ChildItem $recoveryFolder -Filter 'Recovery-*.mom')
  if ($firstVersions.Count -le $before) {throw 'First timestamped version missing.'}
  $previousVersion=$firstVersions | Sort-Object Name -Descending | Select-Object -First 1
  $previousHash=(Get-FileHash $previousVersion.FullName).Hash
  [MathomirUiProbe]::Send($main,273,33009) | Out-Null
  Start-Sleep -Milliseconds 6000
  if (@(Get-ChildItem $recoveryFolder -Filter 'Recovery-*.mom').Count -le $firstVersions.Count) {throw 'Second timestamped version missing.'}
  if ((Get-FileHash $previousVersion.FullName).Hash -ne $previousHash) {throw 'Older recovery version was overwritten.'}
  [xml]$secondRecovery=Get-Content $latest -Raw
  if ($secondRecovery.SelectSingleNode('/mathomir/*[1]').trig_deg -ne '0') {throw 'Latest recovery does not include the newest angle mode.'}
  Stop-Process -Id $appProcess.Id -Force
  $appProcess=Start-Process @startArgs
  $main=[IntPtr]::Zero
  for($attempt=0;$attempt -lt 40;$attempt++){Start-Sleep -Milliseconds 250;$appProcess.Refresh();if($appProcess.MainWindowHandle -ne 0){$main=$appProcess.MainWindowHandle;break}}
  if($main -eq [IntPtr]::Zero){throw 'App did not restart after forced crash.'}
  [MathomirUiProbe]::PostMessage($main,273,[IntPtr]32854,[IntPtr]::Zero)|Out-Null
  $recover=[IntPtr]::Zero
  for($attempt=0;$attempt -lt 40;$attempt++){Start-Sleep -Milliseconds 100;$recover=[MathomirUiProbe]::Window($appProcess.Id,'Recover latest edits or choose an earlier timestamp');if($recover -ne [IntPtr]::Zero){break}}
  if($recover -eq [IntPtr]::Zero){throw 'Recovery picker did not open.'}
  [MathomirUiProbe]::PostMessage($recover,273,[IntPtr]1,[IntPtr]::Zero)|Out-Null
  Start-Sleep -Milliseconds 1800
  $appProcess.Refresh()
  if($appProcess.HasExited){throw 'Opening recovery snapshot crashed.'}
  if([MathomirUiProbe]::Text($main) -notmatch 'Recovered document'){throw 'Latest recovery was not reopened.'}
  Write-Output 'Recovery smoke passed: latest edits, two timestamped immutable versions, forced crash, restart and reopen Latest.'
} finally {
  $appProcess.Refresh()
  if ($appProcess.HasExited) {Write-Output "App exit code: $($appProcess.ExitCode)"}
  if ($env:MATHOMIR_DIAGNOSTIC_STARTUP -and !$appProcess.HasExited) {for($wait=0;$wait -lt 20 -and !$appProcess.HasExited;$wait++){Start-Sleep -Milliseconds 250;$appProcess.Refresh()}}
  if (!$appProcess.HasExited) { Stop-Process -Id $appProcess.Id -Force }
  Get-Content (Join-Path (Split-Path $exe) 'smoke-stderr.txt') -ErrorAction SilentlyContinue
  Get-ChildItem (Split-Path $exe) -Filter 'asan*' | ForEach-Object { Get-Content $_.FullName }
}

