#include "QuickToolbar.h"
#include <cassert>
#include <iostream>
int main(){
    const std::vector<int> base={85,70,95,80,95,78,85};int scenarios=0;
    for(int width=40;width<=2200;width+=7)for(int scale=1;scale<=4;scale++){
        auto widths=base;for(auto &w:widths)w=w*scale/2;
        auto layout=QuickToolbar::Arrange(width,widths);assert(layout.buttons.size()==7);
        for(size_t i=0;i<layout.buttons.size();i++){auto r=layout.buttons[i];assert(r.left>=0&&r.width>0&&r.left+r.width<=width&&r.top>=0&&r.top+r.height<=layout.height);
            for(size_t j=0;j<i;j++){auto p=layout.buttons[j];assert(r.left>=p.left+p.width||p.left>=r.left+r.width||r.top>=p.top+p.height||p.top>=r.top+r.height);}}
        scenarios++;
    }
    auto wide=QuickToolbar::Arrange(1000,base),narrow=QuickToolbar::Arrange(360,base);assert(wide.height==34&&narrow.height>wide.height);
    assert(QuickToolbar::Arrange(0,base).buttons.empty()&&QuickToolbar::Arrange(700,{}).height==0);
    std::cout<<"Quick toolbar: "<<scenarios<<" wrapping/size cases, all labeled buttons retained, nonoverlap, bounds and shared height passed.\n";
}
