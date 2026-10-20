#include "RelationGraph.h"
#include <chrono>
#include <cstdlib>
#include <iostream>
using namespace RelationGraph;
static void Check(bool ok,const char *why){if(!ok){std::cerr<<why<<"\n";std::exit(1);}}
int main(){
    Viewport v;v.width=641;v.height=481;std::string error;Program p;
    InteractiveObjects::Parameters parameters;parameters.a[0].value=2;parameters.a[1].value=3;
    std::vector<Segment> lines;auto emit=[&](Point a,Point b){lines.push_back({a,b});};
    auto shade=[](int,int,int,int){};auto cancel=[](){return false;};
    auto world=[&](Point a){return Point{v.X(a.x/(v.width-1)),v.Y(a.y/(v.height-1))};};
    for(const char *text:{"y=a*sin(x)","a*sin(x)=y","x=a*sin(y)","a*sin(y)=x","x=a","y=a"}){
        Check(p.Parse(text,true,error),"explicit parse");p.Bind(parameters);ExplicitCurve curve;
        Check(Explicit(p,curve),"explicit direction was not recognized");lines.clear();Contour(p,v,emit,shade,cancel);
        Check(lines.size()>100,"explicit curve absent");for(auto s:lines){Check(std::fabs(p.Value(world(s.a)))<1e-8,"explicit curve changed equation");Check(std::hypot(s.a.x-s.b.x,s.a.y-s.b.y)<33,"adaptive segment too long");}
    }
    Check(p.Parse("y=a/(x-0.3)",true,error),"pole parse");p.Bind(parameters);lines.clear();Contour(p,v,emit,shade,cancel);
    Check(!lines.empty(),"rational curve absent");for(auto s:lines)Check((world(s.a).x-.3)*(world(s.b).x-.3)>0,"explicit renderer bridged a pole");
    Check(p.Parse("y=a*sqrt(x)",true,error),"domain parse");p.Bind(parameters);lines.clear();Contour(p,v,emit,shade,cancel);
    for(auto s:lines)Check(world(s.a).x>=-1e-9&&world(s.b).x>=-1e-9,"undefined square-root domain drawn");
    Check(p.Parse("y=a*sin(x)",true,error),"cancel parse");p.Bind(parameters);lines.clear();Contour(p,v,emit,shade,[](){return true;});Check(lines.empty(),"explicit cancellation ignored");
    Check(p.Parse("x*x+y*y=a*a",true,error),"implicit parameter parse");p.Bind(parameters);ExplicitCurve curve;Check(!Explicit(p,curve),"implicit relation misclassified");
    for(int resolution:{64,256}){lines.clear();Contour(p,v,emit,shade,cancel,resolution);Check(lines.size()>100,"implicit circle absent");for(auto s:lines){Point a=world(s.a);Check(std::fabs(a.x*a.x+a.y*a.y-4)<1e-4,"implicit preview changed relation");}}
    v.logx=true;v.xmin=.1;v.xmax=100;Check(p.Parse("y=ln(x)+a",true,error),"log-axis parse");p.Bind(parameters);lines.clear();Contour(p,v,emit,shade,cancel);Check(lines.size()>100,"log-axis explicit curve absent");for(auto s:lines)Check(std::fabs(p.Value(world(s.a)))<1e-8,"log-axis curve distorted");
    v=Viewport();v.width=641;v.height=481;Check(p.Parse("y=a*sin(b*x)",true,error),"benchmark parse");p.Bind(parameters);
    int emitted=0;auto count=[&](Point,Point){emitted++;};auto start=std::chrono::steady_clock::now();
    ImplicitContour(p,v,count,shade,cancel);auto middle=std::chrono::steady_clock::now();
    for(int i=0;i<20;i++){parameters.a[0].value=1+i*.1;p.Bind(parameters);Contour(p,v,count,shade,cancel);}
    auto end=std::chrono::steady_clock::now();double oldTime=std::chrono::duration<double,std::milli>(middle-start).count(),newTime=std::chrono::duration<double,std::milli>(end-middle).count()/20;
    Check(emitted>0&&newTime*4<oldTime,"explicit slider rendering has no material speedup");
    std::cout<<"Slider curves passed: explicit directions, parameter rebinding, poles, domains, cancellation, implicit quality and log axes. Area scan "<<oldTime<<" ms/frame; adaptive trace "<<newTime<<" ms/frame.\n";
}
