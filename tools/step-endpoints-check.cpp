#include "GraphStepEndpoints.h"
#include <cassert>
#include <iostream>
using namespace GraphStepEndpoints;
std::vector<Point> Plot(const char *s,double lo=-3.2,double hi=3.2){Program p;assert(p.Parse(s));return p.Find(lo,hi,true,[](){return false;});}
void Has(const std::vector<Point>& p,double x,double y,bool closed){for(const Point &v:p)if(std::fabs(v.x-x)<1e-8&&std::fabs(v.y-y)<1e-7&&v.closed==closed)return;std::cerr<<"Missing "<<x<<","<<y<<" closed="<<closed<<"\n";for(auto v:p)std::cerr<<v.x<<","<<v.y<<":"<<v.closed<<" ";std::abort();}
int main(){
 auto p=Plot("floor(x)");for(int n=-3;n<=3;n++){Has(p,n,n,true);Has(p,n,n-1,false);}
 p=Plot("ceil(x)");for(int n=-3;n<=3;n++){Has(p,n,n,true);Has(p,n,n+1,false);}
 p=Plot("round(x)");Has(p,.5,0,false);Has(p,.5,1,true);Has(p,-.5,-1,true);Has(p,-.5,0,false);
 p=Plot("trunc(x)");Has(p,1,1,true);Has(p,1,0,false);Has(p,-1,-1,true);Has(p,-1,0,false);for(auto v:p)assert(std::fabs(v.x)>1e-8);
 p=Plot("fract(x)");Has(p,0,0,true);Has(p,0,1,false);Has(p,-1,0,true);Has(p,-1,1,false);
 p=Plot("sgn(x)");Has(p,0,0,true);Has(p,0,1,false);Has(p,0,-1,false);
 p=Plot("floor(2*x+1)+3.4");Has(p,-.5,3.4,true);Has(p,-.5,2.4,false);Has(p,0,4.4,true);
 p=Plot("floor(-x)");Has(p,1,-1,true);Has(p,1,-2,false);
 p=Plot("floor(-x^2)");Has(p,0,0,true);Has(p,0,-1,false);Has(p,1,-1,true);Has(p,1,-2,false);
 p=Plot("floor(x)+x");Has(p,1,2,true);Has(p,1,1,false);
 p=Plot("floor(x)*ceil(x)");Has(p,1,1,true);Has(p,1,0,false);Has(p,1,2,false);
 p=Plot("floor(x)-floor(x)+x");assert(p.empty());
 p=Plot("sqrt(floor(x))");Has(p,0,0,true);Has(p,1,1,true);Has(p,1,0,false);
 p=Plot("1/floor(x)");Has(p,0,-1,false);Has(p,1,1,true);
 for(double span:{.001,3.2,100.,6000.}){p=Plot("floor(x)",-span,span);Has(p,0,0,true);Has(p,0,-1,false);}
 p=Plot("floor(x^2)");for(auto v:p)assert(std::fabs(v.x)>1e-8);
 p=Plot("sgn(x^2)");Has(p,0,0,true);Has(p,0,1,false);
 p=Plot("floor(t)");Has(p,1,1,true);Has(p,1,0,false);
 p=Plot("ceil(-x)");Has(p,1,-1,true);Has(p,1,0,false);
 p=Plot("trunc(-x)");Has(p,1,-1,true);Has(p,1,0,false);
 p=Plot("fract(-x)");Has(p,1,0,true);Has(p,1,1,false);
 p=Plot("sgn(x-1.3)");Has(p,1.3,0,true);Has(p,1.3,-1,false);Has(p,1.3,1,false);
 p=Plot("round(2*x+.1)");Has(p,.2,1,true);Has(p,.2,0,false);Has(p,-.3,-1,true);Has(p,-.3,0,false);
 p=Plot("floor(x^(1/3))",-8.5,-.5);Has(p,-8,-2,true);Has(p,-8,-3,false);Has(p,-1,-1,true);Has(p,-1,-2,false);
 p=Plot("floor(x)+1e9");Has(p,1,1e9+1,true);Has(p,1,1e9,false);assert(p.size()==14);
 p=Plot("1e-9*floor(x)");assert(p.size()==14);int tinyOpen=0,tinyClosed=0;for(auto v:p){if(v.closed)tinyClosed++;else tinyOpen++;}assert(tinyOpen==7&&tinyClosed==7);
 p=Plot("1e-9*(floor(x)-floor(x)+x)");assert(p.empty());
 Program piece;assert(piece.Parse("floor(x)"));p=piece.Find(-.5,1,true,[](){return false;},true,false);Has(p,1,0,false);for(auto v:p)assert(!(v.x==1&&v.y==1));double y;assert(piece.Endpoint(1,-1,1.5,true,y)&&y==0);
 std::cout<<"Step endpoint checks passed.\n";
}
