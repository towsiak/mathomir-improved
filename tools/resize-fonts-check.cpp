#include <algorithm>
#include <cassert>
#include <cmath>
#include <iostream>
using std::max;using std::min;
struct CExpression;
struct CElement {CExpression *Expression1,*Expression2,*Expression3;};
struct tElementStruct {int Type;CElement *pElementObject;};
struct CExpression {short m_FontSize;int m_NumElements;tElementStruct *m_pElementList;};
#include "../source/Mathomir/MouseResizeFonts.h"
int main()
{
    // Root/power/label retain distinct authored sizes and exact live identities.
    CExpression radicand={540,0,NULL},exponent={420,0,NULL},label={250,0,NULL};
    CElement power={&radicand,&exponent,NULL},equals={&label,NULL,NULL};
    tElementStruct items[]={{3,&power},{2,&equals}};
    CExpression root={600,2,items};
    MouseResizeFonts::Capture(&root);
    assert(MouseResizeFonts::fonts.size()==4);
    for(int n=0;n<10000;n++){
        assert(MouseResizeFonts::Apply(&root,1.5));
        assert(root.m_FontSize==900 && radicand.m_FontSize==810 && exponent.m_FontSize==630 && label.m_FontSize==375);
        assert(root.m_pElementList==items && power.Expression1==&radicand && power.Expression2==&exponent && equals.Expression1==&label);
    }
    assert(MouseResizeFonts::Apply(&root,.5));
    assert(root.m_FontSize==300 && radicand.m_FontSize==270 && exponent.m_FontSize==210 && label.m_FontSize==125);
    assert(MouseResizeFonts::Apply(&root,1));
    assert(root.m_FontSize==600 && radicand.m_FontSize==540 && exponent.m_FontSize==420 && label.m_FontSize==250);
    CExpression replacement={123,0,NULL};power.Expression1=&replacement;
    assert(!MouseResizeFonts::Apply(&root,2));
    assert(root.m_FontSize==600 && replacement.m_FontSize==123 && exponent.m_FontSize==420);
    power.Expression1=&radicand;
    root.m_NumElements=1;
    assert(!MouseResizeFonts::Apply(&root,2));
    assert(root.m_FontSize==600 && radicand.m_FontSize==540);
    MouseResizeFonts::fonts.clear();
    std::cout<<"Passed: 10000 repeat updates, exact nested font ratios, unchanged node identities, shrink/cancel, rejected replaced/removed nodes without partial mutations.\n";
}
