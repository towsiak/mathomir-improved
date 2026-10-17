#include "RelationGraph.h"
#include <iostream>
#include <cstdlib>
using namespace RelationGraph;
static void Check(bool ok,const char *what){if(!ok){std::cerr<<what<<"\n";std::exit(1);}}
int main(){
    Viewport v;v.width=401;v.height=301;std::string error;Program p;std::vector<Segment> lines;
    auto emit=[&](Point a,Point b){Segment s={a,b};lines.push_back(s);};auto shade=[](int,int,int,int){};auto cancel=[](){return false;};
    auto world=[&](Point a){Point b={v.X(a.x/(v.width-1)),v.Y(a.y/(v.height-1))};return b;};
    Check(p.Parse("x^2+y^2=25",true,error),"circle parse");Contour(p,v,emit,shade,cancel);Check(lines.size()>300,"circle absent");
    bool quadrants[4]={false};for(auto s:lines){Point a=world(s.a);Check(std::fabs(a.x*a.x+a.y*a.y-25)<1e-4,"circle residual");quadrants[(a.x<0?1:0)+(a.y<0?2:0)]=true;}for(bool q:quadrants)Check(q,"circle branch absent");
    lines.clear();Check(p.Parse("x*y=1",true,error),"hyperbola parse");Contour(p,v,emit,shade,cancel);Check(lines.size()>100,"hyperbola absent");for(auto s:lines){Point a=world(s.a);Check(std::fabs(a.x*a.y-1)<1e-4,"hyperbola residual");Check(world(s.a).x*world(s.b).x>0,"hyperbola crosses pole");}
    lines.clear();Check(p.Parse("1/(x-0.3)=0",true,error),"pole parse");Contour(p,v,emit,shade,cancel);Check(lines.empty(),"false zero along asymptote");
    lines.clear();Check(p.Parse("y=1/x",true,error),"rational relation parse");Contour(p,v,emit,shade,cancel);Check(lines.size()>50,"rational relation absent");for(auto s:lines)Check(world(s.a).x*world(s.b).x>0,"rational contour false bridge");
    Check(!p.Parse("x+z=0",true,error),"unknown variable accepted");Check(!p.Parse("x=y=1",true,error),"chained equality accepted");Check(!p.Parse("sin(x=0",true,error),"invalid expression accepted");
    lines.clear();Check(p.Parse("x^2+y^2=25",true,error),"cancel parse");Contour(p,v,emit,shade,[](){return true;});Check(lines.empty(),"contour cancellation ignored");
    Parametric t;t.enabled=true;Check(t.Parse(error),"parametric parse");lines.clear();Trace(t,v,emit,cancel);Check(lines.size()>=512,"ellipse absent");
    for(auto s:lines){Point a=world(s.a);Check(std::fabs(a.x*a.x/9+a.y*a.y/4-1)<1e-9,"ellipse residual");}
    Point start=t.Value(t.low),end=t.Value(t.high);Check(std::hypot(start.x-end.x,start.y-end.y)<1e-12,"ellipse interval closure");
    t.xtext="t";t.ytext="1/(t-0.3)";t.low=-2;t.high=2;Check(t.Parse(error),"parametric pole parse");lines.clear();Trace(t,v,emit,cancel);Check(!lines.empty(),"parametric rational absent");for(auto s:lines)Check((world(s.a).x-.3)*(world(s.b).x-.3)>0,"parametric pole bridge");
    t.xtext="t";t.ytext="sqrt(t)";t.low=-2;t.high=2;Check(t.Parse(error),"partial domain parse");lines.clear();Trace(t,v,emit,cancel);Check(lines.size()>100,"valid parametric domain starved by undefined half");for(auto s:lines)Check(world(s.a).x>=-1e-10,"undefined parametric domain drawn");
    t.xtext="cos(t)";t.ytext="sin(t)";t.radians=false;t.low=0;t.high=360;Check(t.Parse(error),"degrees parse");Check(std::fabs(t.Value(90).y-1)<1e-12,"degrees wrong");
    t.xtext="x";Check(!t.Parse(error),"x accepted as t");t.xtext="t";t.high=t.low;Check(!t.Parse(error),"empty t interval accepted");
    Point a={-1e20,150},b={1e20,150};Check(Clip(a,b,v.width,v.height)&&a.x>=0&&b.x<=v.width-1,"large line clipping");
    std::cout<<"Implicit circle/hyperbola/rational domains, cancellation, parametric ellipse/poles/units and validation passed.\n";
}
