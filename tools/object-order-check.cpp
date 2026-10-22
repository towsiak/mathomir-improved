#include "ObjectOrder.h"
#include <cassert>
#include <iostream>
int main(){
    unsigned int seed=81231;
    for(int n=1;n<=60;n++)for(int trial=0;trial<80;trial++){
        std::vector<bool> mask(n);int count=0;
        for(int i=0;i<n;i++){seed=1664525u*seed+1013904223u;mask[i]=(seed>>30)&1;count+=mask[i];}
        for(int target=-2;target<=n+2;target++){
            auto order=ObjectOrder::Permutation(mask,target);assert(order.size()==mask.size());
            std::vector<int> seen(n,0);int lastPicked=-1,lastOther=-1,first=-1;
            for(size_t at=0;at<order.size();at++){size_t i=order[at];assert(i<(size_t)n&&!seen[i]++);if(mask[i]){assert((int)i>lastPicked);lastPicked=(int)i;if(first<0)first=(int)at;}else{assert((int)i>lastOther);lastOther=(int)i;}}
            if(count)assert(first==(std::max)(0,(std::min)(target,n-count)));
        }
    }
    auto single=ObjectOrder::Permutation({true,false},1);assert(single[0]==1&&single[1]==0);
    auto all=ObjectOrder::Permutation({true,true,true},20);assert(all[0]==0&&all[1]==1&&all[2]==2);
    std::cout<<"Stable object ordering: permutation, bounds, selection order and unselected order passed across 4800 selection masks.\n";
}
