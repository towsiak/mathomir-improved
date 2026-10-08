#include "Statistics.h"
#include <cassert>
#include <iostream>
using namespace Statistics;
int main(){std::string error;std::vector<Point> p;Result r;
 assert(Parse("  x, y  \r\n1,3\n2,5",p,error));assert(Parse("x,y\n1,3\n2\t5\n3;7\n4 9",p,error));assert(Fit(p,1,r,error));assert(std::fabs(r.Predict(5)-11)<1e-12);assert(std::fabs(r.r2-1)<1e-12);assert(std::fabs(r.correlation-1)<1e-12);assert(r.residualSEDefined);
 assert(SymbolicDerivative::Text(r.Expression())=="2*x+1");
 auto serialized=SymbolicDerivative::NativeNumber(1000000000.045,17);assert(std::strtod(serialized.c_str()+serialized.find("t=\"")+3,0)==1000000000.045);
 assert(r.x.median==2.5&&r.x.q1==1.5&&r.x.q3==3.5);assert(std::fabs(r.x.sampleSD-std::sqrt(5./3))<1e-12);
 for(int model=1;model<=9;model++){p.clear();for(int i=0;i<30;i++){double x=1+i*.2,y=model<=6?2+3*x-(model>1?x*x:0):model==7?2*std::exp(.3*x):model==8?2+3*std::log(x):2*std::pow(x,1.5);p.push_back(Point(x,y));}assert(Fit(p,model,r,error));for(int i=0;i<30;i++){assert(std::fabs(r.Predict(p[i].x)-p[i].y)<1e-8*(1+std::fabs(p[i].y)));assert(std::fabs(SymbolicDerivative::Value(r.Expression(),"x",p[i].x)-r.Predict(p[i].x))<1e-8*(1+std::fabs(p[i].y)));}assert(std::fabs(r.r2-1)<1e-12);}
 p.clear();for(int i=0;i<20;i++){double x=1e9+i*.01,y=3+2*(x-1e9)+.5*(x-1e9)*(x-1e9);p.push_back(Point(x,y));}assert(Fit(p,2,r,error));for(auto v:p)assert(std::fabs(r.Predict(v.x)-v.y)<1e-12);for(auto v:p)assert(std::fabs(SymbolicDerivative::Value(r.Expression(),"x",v.x)-v.y)<1e-12);
 p={Point(1,1e-300),Point(2,1e12)};assert(Fit(p,7,r,error));for(auto v:p)assert(std::fabs(SymbolicDerivative::Value(r.Expression(),"x",v.x)-r.Predict(v.x))<1e-10*(1+std::fabs(v.y)));
 p={Point(1,4),Point(2,4),Point(3,4)};assert(Fit(p,1,r,error));assert(!r.r2Defined&&!r.correlationDefined);assert(r.Predict(2)==4);
 p={Point(1,2),Point(1,3)};assert(!Fit(p,1,r,error));p={Point(1,2),Point(2,3),Point(2,4)};assert(!Fit(p,2,r,error));p={Point(1,-2),Point(2,3)};assert(!Fit(p,7,r,error));p={Point(-1,2),Point(2,3)};assert(!Fit(p,8,r,error));assert(!Fit(p,9,r,error));
 for(const char *bad:{"","1","1,2,3","1,,2","nan 1","1 inf","1e13 2","1junk 2","1,","x y\n1 2\nblah"})assert(!Parse(bad,p,error));
 auto one=Summarize({5});assert(!one.sampleDefined&&one.populationSD==0&&one.q1==5);auto odd=Summarize({1,2,3,4,5});assert(odd.q1==1.5&&odd.q3==4.5);
 std::cout<<"Statistics checks passed: all nine models, summaries, quartiles, large offsets, native equations, fit quality, singular data and invalid domains.\n";
}
