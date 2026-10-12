$ErrorActionPreference='Stop'
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class StatsUI {
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
 public static IntPtr Dialog(int pid){IntPtr result=IntPtr.Zero;EnumWindows((h,p)=>{uint id;GetWindowThreadProcessId(h,out id);var s=new StringBuilder(100);GetWindowText(h,s,100);if(id==pid&&s.ToString()=="Statistics and regression"){result=h;return false;}return true;},IntPtr.Zero);return result;}
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
$file=Join-Path (Split-Path $exe) 'statistics-smoke.mom'
[IO.File]::WriteAllText($file,'<?xml version="1.0"?><mathomir></mathomir>')
$app=Start-Process $exe -WorkingDirectory (Split-Path $exe) -PassThru
function Check($ok,$message){if(!$ok){throw $message}}
function Dialog {
 [StatsUI]::PostMessage($main,273,[IntPtr]33097,[IntPtr]::Zero)|Out-Null
 for($j=0;$j -lt 30;$j++){Start-Sleep -Milliseconds 100;$h=[StatsUI]::Dialog($app.Id);if($h -ne [IntPtr]::Zero -and [StatsUI]::IsWindowUnicode([StatsUI]::Child($h,1346)) -and [StatsUI]::Text([StatsUI]::Child($h,1346)).Length -gt 0){return $h}}
 throw 'Statistics dialog did not open'
}
try {
 Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle
 Check ($main -ne [IntPtr]::Zero) 'Application did not start'
 [StatsUI]::Open($main,$file);Start-Sleep -Seconds 1
 $view=[StatsUI]::Child($main,0xE900);Check ($view -ne [IntPtr]::Zero) 'No view'
 [StatsUI]::Send($main,273,32775)|Out-Null
 $d=Dialog
 Check ([StatsUI]::IsWindowUnicode([StatsUI]::Child($d,1346))) 'Statistics readout must support Unicode'
 for($m=0;$m -lt 9;$m++){
  [StatsUI]::Send([StatsUI]::Child($d,1341),334,$m)|Out-Null
  [StatsUI]::Send($d,273,1343)|Out-Null
  $report=[StatsUI]::Text([StatsUI]::Child($d,1346))
  Check ([StatsUI]::IsWindowEnabled([StatsUI]::Child($d,1))) "Model $m failed"
  Check ($report.Contains('R²') -and $report.Contains('RMSE') -and $report.Contains('Q₁') -and $report.Contains('Residual')) "Incomplete readout for model $m"
 }
 [StatsUI]::Send([StatsUI]::Child($d,1341),334,6)|Out-Null
 [StatsUI]::Set([StatsUI]::Child($d,1340),"1,-2`r`n2,3");[StatsUI]::Send($d,273,1342)|Out-Null
 Check (![StatsUI]::IsWindowEnabled([StatsUI]::Child($d,1))) 'Invalid exponential data accepted'
 [StatsUI]::Send([StatsUI]::Child($d,1341),334,0)|Out-Null
 [StatsUI]::Set([StatsUI]::Child($d,1340)," x, y `r`n1,3`r`n2,5`r`n3,7`r`n4,9");[StatsUI]::Send($d,273,1342)|Out-Null
 Check ([StatsUI]::IsWindowEnabled([StatsUI]::Child($d,1))) 'Pasted linear data failed'
 [StatsUI]::Set([StatsUI]::Child($d,1351),'2');[StatsUI]::Send($d,273,1352)|Out-Null
 $prediction=[StatsUI]::Text([StatsUI]::Child($d,1348));Write-Host "Prediction readout: $prediction";Check ($prediction.EndsWith(': 5')) "Prediction incorrect: $prediction"
 [StatsUI]::Send($d,273,1)|Out-Null;[StatsUI]::Place($view);Start-Sleep -Seconds 2
 [StatsUI]::Send($main,273,0xE103)|Out-Null;Start-Sleep -Milliseconds 500
 [xml]$doc=Get-Content $file -Raw
 Check ($doc.SelectNodes('//sample').Count -eq 4) 'Placed data not saved'
 Check ($doc.SelectSingleNode('//stats').GetAttribute('residual') -eq '0') 'Scatter metadata missing'
 Check ([StatsUI]::Blue($view) -gt 20) 'Scatter points not painted'
 [StatsUI]::Open($main,$file);Start-Sleep -Seconds 2
 Check ([StatsUI]::Blue($view) -gt 20) 'Saved scatter points vanished on reload'
 $d=Dialog
 [StatsUI]::Send([StatsUI]::Child($d,1347),241,1)|Out-Null
 [StatsUI]::Send($d,273,1)|Out-Null;[StatsUI]::Place($view);Start-Sleep -Seconds 2
 [StatsUI]::Send($main,273,0xE103)|Out-Null;Start-Sleep -Milliseconds 500
 [xml]$doc=Get-Content $file -Raw
 Check ($doc.SelectNodes('//stats[@residual="1"]').Count -gt 0) 'Residual plot not saved'
 [StatsUI]::Open($main,$file);Start-Sleep -Milliseconds 500
 Write-Host 'Statistics Windows checks passed: 9 models, Unicode summaries, domain rejection, prediction, scatter placement/save/reload and residual plot.'
} finally {if(!$app.HasExited){Stop-Process -Id $app.Id -Force}}
