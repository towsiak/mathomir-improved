$ErrorActionPreference='Stop'
# Reuse the native toolbar hover/click and tooltip inspection helpers.
$all=Get-Content (Join-Path $PSScriptRoot 'canvas-grid-smoke.ps1') -Raw
Invoke-Expression $all.Substring(0,$all.IndexOf('$exe='))
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class PageMenuUI {
 [DllImport("user32.dll")] static extern bool EnumWindows(GridUI.Callback c,IntPtr p);
 [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h,out uint pid);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h,StringBuilder b,int n);
 [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
 [DllImport("user32.dll")] public static extern int GetMenuItemCount(IntPtr m);
 [DllImport("user32.dll")] public static extern uint GetMenuItemID(IntPtr m,int p);
 [DllImport("user32.dll")] public static extern uint GetMenuState(IntPtr m,uint id,uint flags);
 [DllImport("user32.dll")] public static extern IntPtr GetSubMenu(IntPtr m,int p);
 [DllImport("user32.dll")] static extern bool GetMenuItemRect(IntPtr owner,IntPtr menu,uint p,out GridUI.Rect r);
 [DllImport("user32.dll")] static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] static extern void mouse_event(uint f,uint x,uint y,uint d,UIntPtr extra);
 [DllImport("user32.dll")] static extern void keybd_event(byte key,byte scan,uint flags,UIntPtr extra);
 public static IntPtr Popup(int pid){IntPtr result=IntPtr.Zero;EnumWindows((h,p)=>{uint id;GetWindowThreadProcessId(h,out id);var c=new StringBuilder(100);GetClassName(h,c,100);if(id==pid&&IsWindowVisible(h)&&c.ToString()=="#32768"){result=h;return false;}return true;},IntPtr.Zero);return result;}
 public static IntPtr Menu(IntPtr popup){return SendMessage(popup,0x1e1,IntPtr.Zero,IntPtr.Zero);}
 public static void Choose(IntPtr main,IntPtr menu,int index){GridUI.Rect r;if(!GetMenuItemRect(main,menu,(uint)index,out r))throw new Exception("Cannot locate page menu row");SetCursorPos((r.left+r.right)/2,(r.top+r.bottom)/2);mouse_event(2,0,0,0,UIntPtr.Zero);mouse_event(4,0,0,0,UIntPtr.Zero);}
 public static void Key(byte key){keybd_event(key,0,0,UIntPtr.Zero);keybd_event(key,0,2,UIntPtr.Zero);}
}
'@
$exe=(Resolve-Path 'source/build/Mathomir.exe').Path
$app=Start-Process $exe -WorkingDirectory (Split-Path $exe) -PassThru
function Check($ok,$message){if(!$ok){throw $message}}
function OpenPage {
 $script:bar=[GridUI]::CaptionChild($main,'Toolbar');Check ($bar -ne [IntPtr]::Zero) 'Toolbar missing'
 $r=[GridUI]::Client($bar);$found=$false
 for($x=5;$x -lt $r.right;$x+=8){[GridUI]::Mouse($bar,512,0,$x,[int]($r.bottom/2));if([GridUI]::HintText($bar,$app.Id) -match 'Page setup:'){$found=$true;break}}
 Check $found 'Page toolbar icon or help missing'
 Start-Sleep -Milliseconds 850;Check ([GridUI]::TipVisible($bar)) 'Page tooltip did not appear'
 [GridUI]::PostMessage($bar,513,[IntPtr]1,[IntPtr](([int]($r.bottom/2)-shl 16)-bor $x))|Out-Null
 for($i=0;$i -lt 40;$i++){Start-Sleep -Milliseconds 100;$popup=[PageMenuUI]::Popup($app.Id);if($popup -ne [IntPtr]::Zero){$script:pageMenu=[PageMenuUI]::Menu($popup);return $popup}}
 throw 'Clicking the Page toolbar icon did not open page configuration'
}
try {
 Start-Sleep -Seconds 2;$app.Refresh();$main=$app.MainWindowHandle;Check ($main -ne [IntPtr]::Zero) 'Application failed to start'
 $popup=OpenPage
 Check ([PageMenuUI]::GetMenuItemCount($pageMenu) -eq 6) 'Page configuration menu is incomplete'
 Check ([PageMenuUI]::GetMenuItemID($pageMenu,0) -eq 32799) 'Page icon opened the wrong settings'
 Check ([PageMenuUI]::GetMenuItemID($pageMenu,3) -eq 32883) 'Letter landscape missing'
 $numbering=[PageMenuUI]::GetSubMenu($pageMenu,5);Check ($numbering -ne [IntPtr]::Zero -and [PageMenuUI]::GetMenuItemCount($numbering) -eq 8) 'Page-numbering choices missing'
 Add-Type -AssemblyName System.Drawing
 $rect=[GridUI]::Bounds($main);$image=New-Object System.Drawing.Bitmap ($rect.right-$rect.left),($rect.bottom-$rect.top);$graphics=[System.Drawing.Graphics]::FromImage($image);$graphics.CopyFromScreen($rect.left,$rect.top,0,0,$image.Size);$image.Save((Join-Path (Split-Path $exe) 'page-toolbar-ui.png'));$graphics.Dispose();$image.Dispose()
 [PageMenuUI]::Key(27);Start-Sleep -Milliseconds 200
 # Choose every actual popup row, then reopen to verify its checked state.
 foreach($index in 0..3){
  $popup=OpenPage;[PageMenuUI]::Choose($main,$pageMenu,$index);Start-Sleep -Milliseconds 300
  $popup=OpenPage
  foreach($other in 0..3){$checked=([PageMenuUI]::GetMenuState($pageMenu,[uint32]$other,0x400)-band 8)-ne 0;Check ($checked -eq ($other -eq $index)) "Page configuration failed to select paper/orientation $index"}
  [PageMenuUI]::Key(27);Start-Sleep -Milliseconds 200
 }
 # Small, medium and large palette sizes keep the direct page control available.
 foreach($size in @(32804,32803,32802)){
  [GridUI]::Send($main,273,$size)|Out-Null;Start-Sleep -Milliseconds 200
  $popup=OpenPage;Check (([PageMenuUI]::GetMenuState($pageMenu,3,0x400)-band 8)-ne 0) 'Opening/canceling page config changed paper settings'
  [PageMenuUI]::Key(27);Start-Sleep -Milliseconds 200
 }
 Check (!$app.HasExited) 'Page settings caused an application crash'
 Write-Output 'Page toolbar passed: real icon click, visible tooltip, all four paper/orientation choices, current checkmarks, numbering submenu, cancel preserves settings, three palette sizes.'
}finally{if(!$app.HasExited){$app.Kill();$app.WaitForExit()}}
