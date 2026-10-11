#include "AiPresentation.h"
#include <iostream>
#include <cstdlib>
using namespace AiPresentation;
void check(bool ok,const char *why){if(!ok){std::cerr<<why<<'\n';std::exit(1);}}
int main(){
    auto d=Format(LR"(**Goal:** Convert \(\frac{5\pi}{6}\) radians.
### Step-by-step example
1. **Multiply**
   \[
   \frac{5\pi}{6}\times\frac{180^\circ}{\pi}
   \]
2. **Result** \(\frac{5\pi}{6}\text{ rad}=150^\circ\).
---
\[\boxed{\text{degrees}= \text{radians}\times\dfrac{180^\circ}{\pi}}\]
\(180^\circ \times 0.8333\ldots=150^\circ\)
\(2 \times \frac{180}{3.14159}\approx114.5916^\circ\)
)");
    check(!d.unsupported&&d.text.find(L"\\")==d.text.npos&&d.text.find(L"**")==d.text.npos&&d.text.find(L"###")==d.text.npos,"User angle conversion still contains raw commands");
    check(d.text.find(L"5\u03c0\u22156")!=d.text.npos&&d.text.find(L"180\u00b0\u2215\u03c0")!=d.text.npos&&d.text.find(L"150\u00b0")!=d.text.npos&&d.text.find(L"\u2248114.5916\u00b0")!=d.text.npos,"Angles/fractions lost");
    bool heading=false,display=false,bold=false;for(auto r:d.runs){check(r.first<r.last&&r.last<=d.text.size(),"Invalid formatting range");heading|=r.heading!=0;display|=r.display;bold|=r.bold;}
    check(heading&&display&&bold,"Reader styles missing");
    bool linear=false;for(auto r:d.runs)linear|=r.linear.find(L"(5\u03c0)/(6)")!=std::wstring::npos;check(linear,"Native stacked-fraction input missing");
    auto nested=Format(LR"(\(\frac{1+\frac{x}{2}}{\sqrt{x^2+1}}+\sqrt[3]{8}+a_{12}-\infty\))");
    check(!nested.unsupported&&nested.text==L"(1+x\u22152)\u2215(\u221a(x\u00b2+1))+\u221b(8)+a\u2081\u2082\u2212\u221e","Nested fraction/root/script precedence changed");
    check(Format(LR"($$x^{12}=4$$ and $x_1$)").text.find(L"x\u00b9\u00b2=4")!=std::wstring::npos,"Dollar math unsupported");
    check(Format(L"ln(2) \u2248 0.6931\n\nPlain Unicode {text} and $5 cost.").text.find(L"$5 cost.")!=std::wstring::npos,"Plain text/currency corrupted");
    auto unknown=Format(LR"(\(\unknown{x}\))");check(unknown.unsupported&&unknown.text==LR"(\unknown{x})","Unsupported notation silently changed");
    auto malformed=Format(LR"(\(\frac{1}{\))");check(malformed.unsupported&&malformed.text==LR"(\frac{1}{)","Malformed math silently changed");
    check(Format(LR"({\rtf1 \object <script>alert(1)</script>})").text==LR"({\rtf1 \object <script>alert(1)</script>})","Untrusted text interpreted");
    std::wstring deep=L"\\("+std::wstring(40,L'{')+L"x"+std::wstring(40,L'}')+L"\\)";check(Format(deep).unsupported,"Depth bound missing");
    try{Format(std::wstring(64001,L'x'));check(false,"Size bound missing");}catch(...){ }
    std::cout<<"AI presentation passed: radians example, headings/bold/display styles, nested precedence, roots, powers, subscripts, dollar delimiters, Unicode/currency, untrusted text, malformed/unknown preservation and size/depth bounds.\n";
}
