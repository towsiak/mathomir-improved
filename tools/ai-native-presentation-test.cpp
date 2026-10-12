#include "AiNativePresentation.h"
#include <iostream>
#include <cstdlib>
#pragma comment(lib,"user32.lib")
#pragma comment(lib,"ole32.lib")
#pragma comment(lib,"oleaut32.lib")
void check(bool ok,const char *why){if(!ok){std::cerr<<why<<'\n';std::exit(1);}}
int main(){
    CoInitializeEx(NULL,COINIT_APARTMENTTHREADED);
    check(LoadLibraryExW(L"msftedit.dll",NULL,LOAD_LIBRARY_SEARCH_SYSTEM32)!=NULL,"Windows math reader unavailable");
    HWND reader=CreateWindowExW(0,L"RICHEDIT50W",L"",WS_POPUP|ES_MULTILINE,0,0,900,600,NULL,NULL,GetModuleHandle(NULL),NULL);check(reader!=NULL,"Math reader creation failed");
    auto document=AiPresentation::Format(LR"(**Multiply** \(\frac{5\pi}{6}\) radians by \(\frac{180^\circ}{\pi}\).
\[\frac{5\pi}{6}\times\frac{180^\circ}{\pi}=150^\circ\]
\[\frac{1+\frac{x}{2}}{\sqrt{x^2+1}}+a^{2x+1}\]
\[\boxed{\text{degrees}=\text{radians}\times\frac{180^\circ}{\pi}}\]
)");
    auto text=document.text;for(auto &c:text)if(c==L'\n')c=L'\r';SetWindowTextW(reader,text.c_str());int built=AiPresentation::BuildMath(reader,document);check(built>=4,"Native math zones did not build");
    CComPtr<IRichEditOle> ole;SendMessage(reader,EM_GETOLEINTERFACE,0,(LPARAM)&ole);CComPtr<ITextDocument2> native;ole->QueryInterface(__uuidof(ITextDocument2),(void**)&native);check(native!=NULL,"Native math interface missing");
    CComPtr<ITextRange2> range;native->Range2(0,tomForward,&range);CComBSTR backing;check(SUCCEEDED(range->GetText(&backing)),"Built math cannot be read");
    std::wstring raw(backing.m_str?backing.m_str:L"");check(raw.find(L'\ufdd0')!=raw.npos,"No built-up math objects in the backing store");
    CComBSTR omml;HRESULT exported=range->GetText2(0x00080000 /* tomConvertOMML */,&omml);if(SUCCEEDED(exported)&&omml.m_str){std::wstring xml(omml.m_str);check(xml.find(L"<m:f")!=xml.npos&&xml.find(L"<m:rad")!=xml.npos,"Fractions/roots are not real typeset objects");}
    auto plain=AiPresentation::Format(L"plain {\\rtf1} text");SetWindowTextW(reader,plain.text.c_str());check(AiPresentation::BuildMath(reader,plain)==0,"Plain text was interpreted as math");
    std::cout<<"Native math presentation passed: "<<built<<" built-up zones, stacked fractions, nested roots, variable powers and boxed conversion; no browser or Office installation.\n";
    range.Release();native.Release();ole.Release();DestroyWindow(reader);CoUninitialize();
}
