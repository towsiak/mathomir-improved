$ErrorActionPreference='Stop'
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class GridUI {
 public delegate bool Callback(IntPtr h,IntPtr p);
 [DllImport("user32.dll")] static extern bool EnumWindows(Callback c,IntPtr p);
 [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr h,Callback c,IntPtr p);
 [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h,out uint pid);
 [DllImport("user32.dll")] static extern int GetDlgCtrlID(IntPtr h);
 [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h);
 [DllImport("user32.dll")] public static extern bool IsWindowUnicode(IntPtr h);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h,StringBuilder b,int n);
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern IntPtr SendMessageTimeout(IntPtr h,uint m,IntPtr w,IntPtr l,uint flags,uint ms,out UIntPtr r);
 [DllImport("user32.dll",CharSet=CharSet.Unicode,EntryPoint="SendMessageTimeoutW")] static extern IntPtr Write(IntPtr h,uint m,IntPtr w,string s,uint f,uint ms,out UIntPtr r);
 [DllImport("user32.dll",CharSet=CharSet.Unicode,EntryPoint="SendMessageTimeoutW")] static extern IntPtr Read(IntPtr h,uint m,IntPtr w,StringBuilder s,uint f,uint ms,out UIntPtr r);
 public static long Send(IntPtr h,uint m,int w,int l=0){UIntPtr r;if(SendMessageTimeout(h,m,(IntPtr)w,(IntPtr)l,2,3000,out r)==IntPtr.Zero)throw new Exception("UI timed out: "+m);return (long)r.ToUInt64();}
 public static void Set(IntPtr h,string s){UIntPtr r;if(Write(h,12,IntPtr.Zero,s,2,3000,out r)==IntPtr.Zero)throw new Exception("Edit timed out");}
 public static string Text(IntPtr h){var s=new StringBuilder(20000);UIntPtr r;Read(h,13,(IntPtr)s.Capacity,s,2,3000,out r);return s.ToString();}
 public static IntPtr Child(IntPtr parent,int id){IntPtr result=IntPtr.Zero;EnumChildWindows(parent,(h,p)=>{if(GetDlgCtrlID(h)==id){result=h;return false;}return true;},IntPtr.Zero);return result;}
 public static IntPtr Dialog(int pid,string title){IntPtr result=IntPtr.Zero;EnumWindows((h,p)=>{uint id;GetWindowThreadProcessId(h,out id);var s=new StringBuilder(100);GetWindowText(h,s,100);if(id==pid&&s.ToString()==title){result=h;return false;}return true;},IntPtr.Zero);return result;}
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h,StringBuilder b,int n);
 [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr h,uint which);
 [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h,out Rect r);
 [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h,out Rect r);
 [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr h,ref Point p);
 [DllImport("user32.dll")] static extern bool ScreenToClient(IntPtr h,ref Point p);
 [StructLayout(LayoutKind.Sequential)] public struct Rect {public int left,top,right,bottom;}
 [StructLayout(LayoutKind.Sequential)] public struct Point {public int x,y;}
 [DllImport("user32.dll")] static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
 public static void Hover(IntPtr owner,int id){SetForegroundWindow(owner);IntPtr h=Child(owner,id);Rect r;GetWindowRect(h,out r);SetCursorPos(r.left-10,r.top-10);SetCursorPos((r.left+r.right)/2,(r.top+r.bottom)/2);if(IsWindowEnabled(h))Send(h,512,0,(((r.bottom-r.top)/2)<<16)|((r.right-r.left)/2));else{Point p=new Point{x=(r.left+r.right)/2,y=(r.top+r.bottom)/2};ScreenToClient(owner,ref p);Send(owner,512,0,(p.y<<16)|p.x);}}
 public static bool TipVisible(IntPtr owner){IntPtr registered=GetProp(owner,"MathomirFeatureTips");if(registered!=IntPtr.Zero)return IsWindowVisible(registered);bool shown=false;EnumWindows((h,p)=>{var c=new StringBuilder(100);GetClassName(h,c,100);if(c.ToString()=="tooltips_class32"&&GetWindow(h,4)==owner&&IsWindowVisible(h))shown=true;return true;},IntPtr.Zero);return shown;}
 public static bool FooterFits(IntPtr d) {Rect c;GetClientRect(d,out c);int right=0;foreach(int id in new[]{32480,32481}){Rect r;GetWindowRect(Child(d,id),out r);Point p=new Point{x=r.right,y=r.bottom};ScreenToClient(d,ref p);if(p.x>c.right||p.y>c.bottom)return false;right=Math.Max(right,p.x);}return right>100;}
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern IntPtr GetProp(IntPtr h,string name);
 public static long Tips(IntPtr owner){IntPtr registered=GetProp(owner,"MathomirFeatureTips");if(registered!=IntPtr.Zero)return Send(registered,1037,0);long count=0;EnumWindows((h,p)=>{var c=new StringBuilder(100);GetClassName(h,c,100);if(c.ToString()=="tooltips_class32"&&GetWindow(h,4)==owner)count+=Send(h,1037,0);return true;},IntPtr.Zero);return count;}
 public static IntPtr CaptionChild(IntPtr parent,string caption){IntPtr result=IntPtr.Zero;EnumChildWindows(parent,(h,p)=>{if(Text(h)==caption){result=h;return false;}return true;},IntPtr.Zero);return result;}
 public static Rect Bounds(IntPtr h){Rect r;GetWindowRect(h,out r);return r;}
 public static Rect Client(IntPtr h){Rect r;GetClientRect(h,out r);return r;}
 public static void Mouse(IntPtr h,uint message,int flags,int x,int y){if(message==512&&flags==0){Point p=new Point{x=x,y=y};ClientToScreen(h,ref p);SetCursorPos(p.x,p.y);System.Threading.Thread.Sleep(50);}Send(h,message,flags,(y<<16)|(x&65535));}
 [DllImport("kernel32.dll")] static extern IntPtr OpenProcess(uint rights,bool inherit,int pid);
 [DllImport("kernel32.dll")] static extern IntPtr VirtualAllocEx(IntPtr p,IntPtr at,UIntPtr size,uint type,uint protection);
 [DllImport("kernel32.dll")] static extern bool VirtualFreeEx(IntPtr p,IntPtr at,UIntPtr size,uint type);
 [DllImport("kernel32.dll")] static extern bool WriteProcessMemory(IntPtr p,IntPtr at,byte[] data,UIntPtr size,out UIntPtr n);
 [DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr p,IntPtr at,byte[] data,UIntPtr size,out UIntPtr n);
 [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
 public static string HintText(IntPtr owner,int pid){
  IntPtr tip=GetProp(owner,"MathomirFeatureTips");if(tip==IntPtr.Zero)return "";
  IntPtr process=OpenProcess(0x38,false,pid);if(process==IntPtr.Zero)throw new Exception("Cannot inspect tooltip process");
  IntPtr mem=VirtualAllocEx(process,IntPtr.Zero,(UIntPtr)8256,0x3000,4);
  try{if(mem==IntPtr.Zero)throw new Exception("Cannot allocate tooltip buffer");
   // The application is Win32: TOOLINFOW version 2 is 44 bytes, regardless of test-process architecture.
   var info=new byte[44];Array.Copy(BitConverter.GetBytes(44),0,info,0,4);Array.Copy(BitConverter.GetBytes(unchecked((int)owner.ToInt64())),0,info,8,4);
   Array.Copy(BitConverter.GetBytes(1),0,info,12,4);Array.Copy(BitConverter.GetBytes(unchecked((int)(mem.ToInt64()+64))),0,info,36,4);
   UIntPtr n;if(!WriteProcessMemory(process,mem,info,(UIntPtr)info.Length,out n))throw new Exception("Cannot write tooltip info");
   Send(tip,1080,4096,unchecked((int)mem.ToInt64()));var text=new byte[8192];
   if(!ReadProcessMemory(process,IntPtr.Add(mem,64),text,(UIntPtr)text.Length,out n))throw new Exception("Cannot read tooltip text");
   return Encoding.Unicode.GetString(text).Split('\0')[0];
  }finally{if(mem!=IntPtr.Zero)VirtualFreeEx(process,mem,UIntPtr.Zero,0x8000);CloseHandle(process);}
 }
 public static int DirectChildren(IntPtr parent){int n=0;for(IntPtr h=GetWindow(parent,5);h!=IntPtr.Zero;h=GetWindow(h,2))n++;return n;}
 [DllImport("kernel32.dll")] static extern IntPtr GlobalAlloc(uint f,UIntPtr n);
 [DllImport("kernel32.dll")] static extern IntPtr GlobalLock(IntPtr h);
 [DllImport("kernel32.dll")] static extern bool GlobalUnlock(IntPtr h);
 public static void Open(IntPtr h,string path){byte[] s=Encoding.Unicode.GetBytes(path+"\0\0");IntPtr a=GlobalAlloc(0x42,(UIntPtr)(20+s.Length)),b=GlobalLock(a);Marshal.WriteInt32(b,0,20);Marshal.WriteInt32(b,16,1);Marshal.Copy(s,0,IntPtr.Add(b,20),s.Length);GlobalUnlock(a);PostMessage(h,563,a,IntPtr.Zero);}
 [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
 [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h,IntPtr dc);
 [DllImport("gdi32.dll")] static extern uint GetPixel(IntPtr dc,int x,int y);
 public static ulong Signature(IntPtr h,int left,int top,int width,int height){IntPtr dc=GetDC(h);try{ulong hash=1469598103934665603;unchecked{for(int y=top;y<top+height;y++)for(int x=left;x<left+width;x++)hash=(hash^GetPixel(dc,x,y))*1099511628211;}return hash;}finally{ReleaseDC(h,dc);}}
 public static int MoveGripY(IntPtr h,int x){IntPtr dc=GetDC(h);try{int first=-1,last=-1;for(int y=20;y<190;y++)if(GetPixel(dc,x,y)==0x009B5F2D){if(first<0)first=y;last=y;}if(first<0)throw new Exception("Move grip not painted");return (first+last)/2;}finally{ReleaseDC(h,dc);}}
 public static int[] Expected(int style,int x,int y,int offset){double px=x+offset,py=y;if(style==3)return new[]{x,(int)Math.Round(py/16,MidpointRounding.AwayFromZero)*16};if(style==4)return new[]{(int)Math.Round(px/16,MidpointRounding.AwayFromZero)*16-offset,y};if(style!=5)return new[]{(int)Math.Round(px/16,MidpointRounding.AwayFromZero)*16-offset,(int)Math.Round(py/16,MidpointRounding.AwayFromZero)*16};double best=double.MaxValue,bx=px,by=py;for(int row=-50;row<=50;row++)for(int col=-50;col<=50;col++){double vx=col*16+Math.Abs(row%2)*8,vy=row*16*Math.Sqrt(3)/2,d=(vx-px)*(vx-px)+(vy-py)*(vy-py);if(d<best){best=d;bx=vx;by=vy;}}return new[]{(int)Math.Round(bx,MidpointRounding.AwayFromZero)-offset,(int)Math.Round(by,MidpointRounding.AwayFromZero)};}
 public static int Blue(IntPtr h){IntPtr dc=GetDC(h);try{int count=0;for(int y=190;y<375;y++)for(int x=150;x<500;x++)if(GetPixel(dc,x,y)==0xC00000)count++;return count;}finally{ReleaseDC(h,dc);}}
 public static void Place(IntPtr h){Send(h,512,0,(100<<16)|100);Send(h,513,1,(100<<16)|100);Send(h,514,0,(100<<16)|100);Send(h,258,27);Send(h,512,0,(50<<16)|850);}
}
'@

$exe=(Resolve-Path 'source/build/Mathomir.exe').Path
$app=Start-Process $exe -WorkingDirectory (Split-Path $exe) -PassThru
function Check($ok,$message){if(!$ok){throw $message}}
function Dialog {
 [GridUI]::PostMessage($main,273,[IntPtr]33099,[IntPtr]::Zero)|Out-Null
 for($i=0;$i -lt 40;$i++){Start-Sleep -Milliseconds 100;$d=[GridUI]::Dialog($app.Id,'Grid styles and snapping');if($d -ne [IntPtr]::Zero){Start-Sleep -Milliseconds 200;return $d}}
 throw 'Grid options did not open'
}
function Style($d,$style){[GridUI]::Send([GridUI]::Child($d,1360),334,$style)|Out-Null;[GridUI]::Send($d,273,((1-shl 16)-bor 1360))|Out-Null}
function Box($d,$id,$checked){[GridUI]::Send([GridUI]::Child($d,$id),241,$checked)|Out-Null;[GridUI]::Send($d,273,$id)|Out-Null}
function Grid($style,$snap,$show=1){$d=Dialog;Style $d $style;Box $d 1363 $snap;Box $d 1362 $show;[GridUI]::Set([GridUI]::Child($d,1361),'16');[GridUI]::Send($d,273,((5-shl 16)-bor 1361))|Out-Null;[GridUI]::Send($d,273,1)|Out-Null;Start-Sleep -Milliseconds 150}
function Blank($suffix){
 $script:fixture=Join-Path (Split-Path $exe) ('grid-'+$suffix+'.mom')
 '<?xml version="1.0"?><mathomir></mathomir>'|Set-Content $fixture -Encoding ascii
 [GridUI]::Open($main,$fixture);Start-Sleep -Milliseconds 250
 [GridUI]::Send($view,276,4)|Out-Null;for($j=0;$j -lt 10;$j++){[GridUI]::Send($view,277,2)|Out-Null};[GridUI]::Send($view,273,32775)|Out-Null
}
try {
 Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle;Check ($main -ne [IntPtr]::Zero) 'Application failed to start';$view=[GridUI]::Child($main,0xE900)
 $d=Dialog
 Check ([GridUI]::Send([GridUI]::Child($d,1360),326,0) -eq 6) 'Six grid styles not present'
 Check ([GridUI]::Tips($d) -ge [GridUI]::DirectChildren($d)) 'A grid dialog control lacks hover help'
 [GridUI]::Hover($d,1363);Start-Sleep -Milliseconds 900;Check ([GridUI]::TipVisible($d)) 'Snap checkbox tooltip did not appear'
 foreach($value in @('0','81','16.5','oops','')){[GridUI]::Set([GridUI]::Child($d,1361),$value);[GridUI]::Send($d,273,((5-shl 16)-bor 1361))|Out-Null;Check (![GridUI]::IsWindowEnabled([GridUI]::Child($d,1))) "Invalid spacing accepted: $value"}
 foreach($value in @('5','80','13')){[GridUI]::Set([GridUI]::Child($d,1361),$value);[GridUI]::Send($d,273,((5-shl 16)-bor 1361))|Out-Null;Check ([GridUI]::IsWindowEnabled([GridUI]::Child($d,1))) "Valid spacing rejected: $value"}
 Style $d 0;Box $d 1363 0;Style $d 1;Box $d 1363 1;Style $d 0;Check ([GridUI]::Send([GridUI]::Child($d,1363),240,0) -eq 0) 'Style switching lost independent snap setting'
 Style $d 1;Check ([GridUI]::Send([GridUI]::Child($d,1363),240,0) -eq 1) 'Second style inherited the first snap setting'
 [GridUI]::Send($d,273,2)|Out-Null
 Blank 'render'
 $signatures=@()
 foreach($style in 0..5){Grid $style 0;$signatures+=[GridUI]::Signature($view,160,160,160,160)}
 Check (($signatures|Select-Object -Unique).Count -eq 6) 'Different grid styles render identically'
 Grid 0 0 0;$hidden=[GridUI]::Signature($view,160,160,160,160);Check ($signatures -notcontains $hidden) 'A grid style did not paint on the page'
 $d=Dialog;Check ([GridUI]::Send([GridUI]::Child($d,1362),240,0) -eq 0) "Opening grid options changed hidden-grid preference";[GridUI]::Send($d,273,2)|Out-Null
 # Test the real toolbar entry, including its visible hover help.
 $bar=[GridUI]::CaptionChild($main,'Toolbar');Check ($bar -ne [IntPtr]::Zero) 'Toolbar missing';$r=[GridUI]::Client($bar);$found=$false
 for($x=5;$x -lt $r.right;$x+=10){[GridUI]::Mouse($bar,512,0,$x,[int]($r.bottom/2));if([GridUI]::HintText($bar,$app.Id) -match 'Grid styles'){$found=$true;break}}
 Check $found 'Grid toolbar button has no options/help'
 Start-Sleep -Milliseconds 800;Check ([GridUI]::TipVisible($bar)) 'Grid toolbar tooltip did not appear'
 [GridUI]::Mouse($bar,513,1,$x,[int]($r.bottom/2));[GridUI]::Mouse($bar,514,0,$x,[int]($r.bottom/2));Start-Sleep -Milliseconds 300
 $d=[GridUI]::Dialog($app.Id,'Grid styles and snapping');Check ($d -ne [IntPtr]::Zero) 'Grid toolbar button failed to open options';[GridUI]::Send($d,273,2)|Out-Null
 # Mouse-draw a native rectangle. Verify saved ink origin against the selected lattice.
 $expected=@(@(128,144),@(128,144),@(128,144),@(131,144),@(128,143),@(128,139))
 foreach($style in 0..5){foreach($snap in 0..1){
  Blank "draw-$style-$snap";Grid $style $snap
  [GridUI]::Send($main,273,33049)|Out-Null
  [GridUI]::Mouse($view,512,0,131,143);[GridUI]::Mouse($view,513,1,131,143);[GridUI]::Mouse($view,512,1,213,237);[GridUI]::Mouse($view,514,0,213,237);[GridUI]::Send($view,258,27)|Out-Null
  [GridUI]::Send($main,273,0xE103)|Out-Null
  [xml]$saved=Get-Content $fixture -Raw;$o=$saved.SelectSingleNode('/mathomir/*[self::o or self::obj][last()]');Check ($null -ne $o) 'Mouse drawing produced no object'
  $xy=if($snap){$expected[$style]}else{@(131,143)}
  $ink=$o.SelectSingleNode("./draw | ./dw");Check ($null -ne $ink -and $ink.HasAttribute("X1")) "Rectangle has no saved ink coordinates"
  $inkX=[int]$o.X+[int]$ink.X1/1000;$inkY=[int]$o.Y+[int]$ink.Y1/1000
  Write-Host "Grid $style snap=${snap}: visible corner $inkX,$inkY"
  Check ($inkX -eq $xy[0] -and $inkY -eq $xy[1]) "Grid $style snap=$snap placed object at wrong coordinates: $($o.OuterXml)"
 }}
 # Placed math uses the ink-origin offset; native move grips must obey the same style.
 foreach($style in 0..5){
  Blank "typed-free-$style";Grid $style 0
  [GridUI]::Mouse($view,512,0,137,157);[GridUI]::Mouse($view,513,1,137,157);[GridUI]::Mouse($view,514,0,137,157);[GridUI]::Send($view,258,120)|Out-Null;[GridUI]::Send($view,258,27)|Out-Null;[GridUI]::Send($main,273,0xE103)|Out-Null
  [xml]$free=Get-Content $fixture -Raw;$o=$free.SelectSingleNode('/mathomir/*[self::o or self::obj][last()]');Check ($null -ne $o) 'Typing produced no math object';$xy=[GridUI]::Expected($style,[int]$o.X,[int]$o.Y,3)
  Blank "typed-snap-$style";Grid $style 1
  [GridUI]::Mouse($view,512,0,137,157);[GridUI]::Mouse($view,513,1,137,157);[GridUI]::Mouse($view,514,0,137,157);[GridUI]::Send($view,258,120)|Out-Null;[GridUI]::Send($view,258,27)|Out-Null;[GridUI]::Send($main,273,0xE103)|Out-Null
  [xml]$snapped=Get-Content $fixture -Raw;$o=$snapped.SelectSingleNode('/mathomir/*[self::o or self::obj][last()]');Write-Host "Typed grid ${style}: $($o.X),$($o.Y)";Check ([int]$o.X -eq $xy[0] -and [int]$o.Y -eq $xy[1]) "Typed math did not use grid $style"
  # Native SDI reuses an already-open path; write a distinct fixture before opening it.
  $fixture=Join-Path (Split-Path $exe) ("grid-native-grip-$style.mom")
  '<?xml version="1.0"?><mathomir><o t="1" X="100" Y="150"><ex><var t="x123456" f="00" /></ex></o></mathomir>'|Set-Content $fixture -Encoding ascii
  [GridUI]::Open($main,$fixture);Start-Sleep -Milliseconds 350;[GridUI]::Send($view,276,4)|Out-Null;for($j=0;$j -lt 10;$j++){[GridUI]::Send($view,277,2)|Out-Null};[GridUI]::Send($view,273,32775)|Out-Null;Grid $style 1
  for($x=105;$x -le 190;$x+=5){[GridUI]::Mouse($view,512,0,$x,150)};Start-Sleep -Milliseconds 400
  $y=[GridUI]::MoveGripY($view,88);[GridUI]::Mouse($view,512,0,88,$y);[GridUI]::Mouse($view,513,1,88,$y);[GridUI]::Mouse($view,512,1,119,($y-7));[GridUI]::Mouse($view,514,0,119,($y-7));[GridUI]::Send($main,273,0xE103)|Out-Null
  [xml]$moved=Get-Content $fixture -Raw;$o=$moved.SelectSingleNode('/mathomir/*[self::o or self::obj][1]');$xy=[GridUI]::Expected($style,131,143,3);Write-Host "Grip grid ${style}: $($o.X),$($o.Y)";Check ([int]$o.X -eq $xy[0] -and [int]$o.Y -eq $xy[1]) "Move grip did not use grid $style"
 }
 # Persist different snap settings, custom spacing and color; check after a full restart.
 Grid 3 0;Grid 5 1
 $d=Dialog;[GridUI]::Set([GridUI]::Child($d,1361),'13');[GridUI]::Send($d,273,((5-shl 16)-bor 1361))|Out-Null;[GridUI]::Send([GridUI]::Child($d,1365),334,2)|Out-Null;[GridUI]::Send($d,273,((1-shl 16)-bor 1365))|Out-Null;[GridUI]::Send($d,273,1)|Out-Null
 Stop-Process -Id $app.Id -Force;$app=Start-Process $exe -WorkingDirectory (Split-Path $exe) -PassThru;Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle;$view=[GridUI]::Child($main,0xE900)
 $d=Dialog;Check ([GridUI]::Send([GridUI]::Child($d,1360),327,0) -eq 5) 'Grid style not persisted';Check ([GridUI]::Text([GridUI]::Child($d,1361)) -eq '13') 'Custom spacing not persisted';Check ([GridUI]::Send([GridUI]::Child($d,1365),327,0) -eq 2) 'Grid color not persisted'
 Style $d 3;Check ([GridUI]::Send([GridUI]::Child($d,1363),240,0) -eq 0) 'Per-style snapping not persisted'
 foreach($style in 0..5){Style $d $style;Box $d 1363 1};Style $d 0;Box $d 1362 0;[GridUI]::Set([GridUI]::Child($d,1361),'16');[GridUI]::Send($d,273,((5-shl 16)-bor 1361))|Out-Null;[GridUI]::Send([GridUI]::Child($d,1365),334,0)|Out-Null;[GridUI]::Send($d,273,((1-shl 16)-bor 1365))|Out-Null;[GridUI]::Send($d,273,1)|Out-Null
 Write-Host 'Grid Windows checks passed: toolbar, all six rendered styles, twelve drawing/snap placements, typed math and grip placement in every style, per-style memory, persistence, validation and hover help.'
} finally {if(!$app.HasExited){Stop-Process -Id $app.Id -Force}}
