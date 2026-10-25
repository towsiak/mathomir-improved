#include "../source/Mathomir/GraphPointLists.h"
#include <cassert>
#include <iostream>
int main(){
    std::vector<RelationGraph::Point> p;std::string error;
    auto check=[&](const std::string &s,GraphPointLists::Result expected){auto result=GraphPointLists::Parse(s,p,error);if(result!=expected){std::cerr<<s<<": "<<error<<"\n";std::abort();}if(result==GraphPointLists::Invalid){assert(p.empty());assert(!error.empty());}};
    check("(1,2)",GraphPointLists::Ready);assert(p.size()==1&&p[0].x==1&&p[0].y==2);
    check(" (1,2), (3,4), (5,6) ",GraphPointLists::Ready);assert(p.size()==3&&p[2].x==5&&p[2].y==6);
    check("(-1.5,2/3), (sqrt(4),log(2,8)), (0,-2)",GraphPointLists::Ready);assert(p.size()==3&&p[1].x==2&&std::fabs(p[1].y-3)<1e-12);
    check("(1,2),\n(1,2), (1,3)",GraphPointLists::Ready);assert(p.size()==3); // duplicates and vertical point sets are data
    for(auto s:{"y=x","(x+1)","sin(x)","log(2,x)","(log(2,x))","x*x+y*y=25"})check(s,GraphPointLists::NotPoints);
    for(auto s:{"(1,2),","(1,2),(3)","(1,2,3)","(1,2),(3,)","(1,2)(3,4)","(1,2)+x","(1,2),(x,4)","(1,2),(1/0,4)","(1,2),(2,3", "(1000000000001,2)"})check(s,GraphPointLists::Invalid);
    check("(0,0)",GraphPointLists::Ready);auto v=TeachingTools::Bounds(p);assert(v.xmin<0&&v.xmax>0&&v.ymin<0&&v.ymax>0);
    for(int width=120;width<1500;width++)for(int zoom:{30,40,60,100,200})for(int toolbox:{80,100,120}){
        int left=50*zoom/100;auto r=GraphPointLists::AxesButton(width,left,toolbox,zoom);
        if(r.right>r.left){assert(r.left>=left&&r.right<width&&r.bottom>r.top);assert(r.Contains(r.left,r.top));assert(!r.Contains(r.right,r.bottom));}
    }
    std::cout<<"Basic grapher point lists passed: exact pairs, constants, nesting, mixed-form rejection, atomic validation and bounded inline controls.\n";
}
