$ErrorActionPreference='Stop'
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class FeatureUI {
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
 public static int DirectChildren(IntPtr parent){int n=0;for(IntPtr h=GetWindow(parent,5);h!=IntPtr.Zero;h=GetWindow(h,2))n++;return n;}
 [DllImport("kernel32.dll")] static extern IntPtr GlobalAlloc(uint f,UIntPtr n);
 [DllImport("kernel32.dll")] static extern IntPtr GlobalLock(IntPtr h);
 [DllImport("kernel32.dll")] static extern bool GlobalUnlock(IntPtr h);
 public static void Open(IntPtr h,string path){byte[] s=Encoding.Unicode.GetBytes(path+"\0\0");IntPtr a=GlobalAlloc(0x42,(UIntPtr)(20+s.Length)),b=GlobalLock(a);Marshal.WriteInt32(b,0,20);Marshal.WriteInt32(b,16,1);Marshal.Copy(s,0,IntPtr.Add(b,20),s.Length);GlobalUnlock(a);PostMessage(h,563,a,IntPtr.Zero);}
 [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
 [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h,IntPtr dc);
 [DllImport("gdi32.dll")] static extern uint GetPixel(IntPtr dc,int x,int y);
 public static int Blue(IntPtr h){IntPtr dc=GetDC(h);try{int count=0;for(int y=190;y<375;y++)for(int x=150;x<500;x++)if(GetPixel(dc,x,y)==0xC00000)count++;return count;}finally{ReleaseDC(h,dc);}}
 public static void Place(IntPtr h){Send(h,512,0,(100<<16)|100);Send(h,513,1,(100<<16)|100);Send(h,514,0,(100<<16)|100);Send(h,258,27);Send(h,512,0,(50<<16)|850);}
}
'@

$exe=(Resolve-Path 'source/build/Mathomir.exe').Path
$app=Start-Process $exe -WorkingDirectory (Split-Path $exe) -PassThru
function Check($ok,$message){if(!$ok){throw $message}}
function Dialog($command,$title) {
 [FeatureUI]::PostMessage($main,273,[IntPtr]$command,[IntPtr]::Zero)|Out-Null
 for($j=0;$j -lt 30;$j++){Start-Sleep -Milliseconds 100;$h=[FeatureUI]::Dialog($app.Id,$title);if($h -ne [IntPtr]::Zero){Start-Sleep -Milliseconds 150;return $h}}
 throw "Dialog did not open: $title"
}
function Rounding($d,$selection,$zeros) {
 [FeatureUI]::Send([FeatureUI]::Child($d,32480),334,$selection)|Out-Null
 [FeatureUI]::Send($d,273,((1-shl 16)-bor 32480))|Out-Null
 [FeatureUI]::Send([FeatureUI]::Child($d,32481),241,$zeros)|Out-Null
 [FeatureUI]::Send($d,273,32481)|Out-Null
}
function Help($d) {
 $tips=[FeatureUI]::Tips($d);$children=[FeatureUI]::DirectChildren($d);Write-Host "Tooltip tools: $tips; direct controls: $children";Check ($tips -ge $children) 'A dialog control has no tooltip registered'
 Check ([FeatureUI]::FooterFits($d)) 'Rounding footer extends beyond the dialog'
}
try {
 Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle
 Check ($main -ne [IntPtr]::Zero) 'Application did not start'
 $bar=[FeatureUI]::Child($main,1110);Check (([FeatureUI]::Tips($main)+[FeatureUI]::Tips($bar)) -ge 9) 'Quick toolbar tooltip coverage missing'
 $d=Dialog 33098 'Number rounding';Help $d
 [FeatureUI]::Hover($d,32480)
 $shown=$false;for($i=0;$i -lt 30;$i++){Start-Sleep -Milliseconds 100;if([FeatureUI]::TipVisible($d)){$shown=$true;break}}
 Check $shown 'Hovering the rounding control did not show its tooltip'
 Check (![FeatureUI]::IsWindowEnabled([FeatureUI]::Child($d,32481))) 'Auto mode should not offer zero padding'
 [FeatureUI]::Hover($d,32481)
 $shown=$false;for($i=0;$i -lt 30;$i++){Start-Sleep -Milliseconds 100;if([FeatureUI]::TipVisible($d)){$shown=$true;break}}
 Check $shown 'Disabled rounding checkbox did not show its explanatory tooltip'
 Rounding $d 3 1
 [FeatureUI]::Send($d,273,1)|Out-Null
 $d=Dialog 33089 'Symbolic derivative finder';Help $d
 [FeatureUI]::Set([FeatureUI]::Child($d,1300),'?')
 Check (![FeatureUI]::IsWindowEnabled([FeatureUI]::Child($d,1))) 'Invalid derivative should disable placement'
 [FeatureUI]::Hover($d,1)
 $shown=$false;for($i=0;$i -lt 30;$i++){Start-Sleep -Milliseconds 100;if([FeatureUI]::TipVisible($d)){$shown=$true;break}}
 Check $shown 'Dynamically disabled Place button did not show its explanatory tooltip'
 Check ([FeatureUI]::Send([FeatureUI]::Child($d,32480),327,0) -eq 3) 'Number format did not carry between dialogs'
 [FeatureUI]::Set([FeatureUI]::Child($d,1300),'x^2');[FeatureUI]::Set([FeatureUI]::Child($d,1307),'1/3');[FeatureUI]::Send($d,273,1303)|Out-Null
 $text=[FeatureUI]::Text([FeatureUI]::Child($d,1309));Check ($text.Contains('Derivative order 1 ') -and $text.EndsWith(': 0.67')) "Rounded derivative incorrect: $text"
 Rounding $d 10 1
 $text=[FeatureUI]::Text([FeatureUI]::Child($d,1309));Check ($text.EndsWith(': 0.667')) "Live significant-figure refresh failed: $text"
 [FeatureUI]::Send($d,273,2)|Out-Null
 $d=Dialog 33071 'Piecewise function grapher';Help $d;Rounding $d 3 1
 [FeatureUI]::Set([FeatureUI]::Child($d,1186),'1/3');[FeatureUI]::Send($d,273,1187)|Out-Null
 $text=[FeatureUI]::Text([FeatureUI]::Child($d,1188));Check ($text.Contains('1.33') -and $text.Contains('+∞')) "Rounded piecewise readout incorrect: $text"
 [FeatureUI]::Send($d,273,2)|Out-Null
 $d=Dialog 33088 'Polygon constructor';Help $d
 $text=[FeatureUI]::Text([FeatureUI]::Child($d,1298));Check ($text.StartsWith('5 vertices')) "Vertex count incorrectly rounded: $text"
 [FeatureUI]::Send($d,273,2)|Out-Null
 $d=Dialog 33097 'Statistics and regression';Help $d
 [FeatureUI]::Set([FeatureUI]::Child($d,1340),"1,3`r`n2,5`r`n3,7`r`n4,9");[FeatureUI]::Send($d,273,1342)|Out-Null
 [FeatureUI]::Set([FeatureUI]::Child($d,1351),'2.333333333333333');[FeatureUI]::Send($d,273,1352)|Out-Null
 $text=[FeatureUI]::Text([FeatureUI]::Child($d,1348));Check ($text.EndsWith(': 5.67')) "Rounded prediction incorrect: $text"
 Check ([FeatureUI]::Text([FeatureUI]::Child($d,1346)).StartsWith('n = 4 pairs')) 'Sample count incorrectly rounded'
 Rounding $d 4 1
 $text=[FeatureUI]::Text([FeatureUI]::Child($d,1348));Check ($text.EndsWith(': 5.667')) "Live regression refresh failed: $text"
 [FeatureUI]::Send($d,273,2)|Out-Null
 # Preferences persist on application restart, including zero padding.
 Stop-Process -Id $app.Id -Force
 $app=Start-Process $exe -WorkingDirectory (Split-Path $exe) -PassThru
 Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle
 $d=Dialog 33098 'Number rounding';Help $d
 Check ([FeatureUI]::Send([FeatureUI]::Child($d,32480),327,0) -eq 4) 'Rounding preference did not survive restart'
 Check ([FeatureUI]::Send([FeatureUI]::Child($d,32481),240,0) -eq 1) 'Trailing-zero preference did not survive restart'
 Rounding $d 0 0;[FeatureUI]::Send($d,273,1)|Out-Null
 Write-Host 'Feature-help Windows checks passed: tooltip coverage, footer layout, live decimal/significant rounding, unchanged integer counts, Unicode infinity, predictions and persistent preferences.'
} finally {if(!$app.HasExited){Stop-Process -Id $app.Id -Force}}
