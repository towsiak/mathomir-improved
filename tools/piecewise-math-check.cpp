#include "Piecewise.h"
#include "GraphDiscontinuities.h"
#include <cassert>
#include <iostream>
static double Evaluate(const char *s,double x=0,bool radians=true){Piecewise::Formula p;std::string e;assert(p.Parse(s,e));return p.Value(x,radians);}
int main(){
 for(double span:{100.0,6000.0,1e9}) {
  std::vector<double> roots;
  GraphDiscontinuities::Roots([](double x){return (x+2)*(x-5);},-2-span*.45,-2+span*.55,roots);
  assert(roots.size()==2);bool left=false,right=false;
  for(double x:roots){left|=std::fabs(x+2)<1e-8;right|=std::fabs(x-5)<1e-8;}assert(left&&right);
  roots.clear();GraphDiscontinuities::Roots([](double x){return x*x+1;},-span*.45,span*.55,roots);assert(roots.empty());
  roots.clear();GraphDiscontinuities::Roots([](double x){return (x-.37)*(x-.37);},-span*.45,span*.55,roots);assert(roots.size()==1 && std::fabs(roots[0]-.37)<1e-8);
 }
 {std::vector<Piecewise::Row> rows(1);rows[0].formula="x";std::string error;
  for(const char *invalid:{"nan","junk","1junk",""}){rows[0].low=Piecewise::StoredBound(invalid);assert(!Piecewise::Validate(rows,true,error));}
  assert(Piecewise::StoredBound("-inf")==-std::numeric_limits<double>::infinity());
  assert(Piecewise::StoredBound("inf")==std::numeric_limits<double>::infinity());
  assert(Piecewise::StoredBound("1.25")==1.25);
 }

 for(double span:{1e-10,1e-6,1.0,6000.0,1e10}) {
  double limit=0;
  assert(GraphDiscontinuities::HoleLimit([](double x){return std::sin(x)/x;},0,span,limit));
  assert(std::fabs(limit-1)<1e-7);
  assert(GraphDiscontinuities::HoleLimit([](double x){return ((x+2)*(x-1))/((x+2)*(x-5));},-2,span,limit));
  assert(std::fabs(limit-3.0/7)<1e-7);
  assert(!GraphDiscontinuities::HoleLimit([](double x){return 1/x;},0,span,limit));
  assert(!GraphDiscontinuities::HoleLimit([](double x){return 1/(x*x);},0,span,limit));
  assert(!GraphDiscontinuities::HoleLimit([](double x){return x<0?-1.0:1.0;},0,span,limit));
 }

 assert(Evaluate("-x^2",3)==-9);assert(Evaluate("(-x)^2",3)==9);assert(Evaluate("2^3^2")==512);
 assert(Evaluate("2x+3",4)==11);assert(Evaluate("(x+1)(x-1)",4)==15);assert(Evaluate("1/2+3/4")==1.25);
 assert(std::fabs(Evaluate("sin(pi/2)")-1)<1e-12);assert(std::fabs(Evaluate("sin(x)",90,false)-1)<1e-12);
 assert(Evaluate("abs(x)",-3)==3);assert(std::fabs(Evaluate("ln(exp(2))")-2)<1e-12);assert(Evaluate("log(100)")==2);
 assert(std::fabs(Evaluate("x^(2/3)",-8)-4)<1e-12);assert(!Piecewise::Finite(Evaluate("sqrt(x)",-1)));
 assert(!Piecewise::Finite(Evaluate("1/x",0)));assert(!Piecewise::Finite(Evaluate("tan(pi/2)")));
 Piecewise::Formula f;std::string error;
 for(const char *bad:{"sin(","2+","foo(x)","x=2","sin x","1..2","x;delete","1e999"})assert(!f.Parse(bad,error));
 double bound;assert(Piecewise::Bound("pi/3",true,bound,error));assert(std::fabs(bound-3.141592653589793/3)<1e-12);assert(!Piecewise::Bound("x+1",true,bound,error));
 Piecewise::Row a,b,c;a.formula="x^2";a.high=0;b.formula="x+1";b.low=0;b.leftClosed=true;
 std::vector<Piecewise::Row> rows={a,b};assert(Piecewise::Validate(rows,true,error));assert(rows[0].Contains(-1));assert(!rows[0].Contains(0));assert(rows[1].Contains(0));
 rows[0].rightClosed=true;assert(!Piecewise::Validate(rows,true,error));rows[0].rightClosed=false;rows[1].low=-1;assert(!Piecewise::Validate(rows,true,error));
 b.low=1;rows={a,b};assert(Piecewise::Validate(rows,true,error));assert(!rows[0].Contains(.5)&&!rows[1].Contains(.5));
 a.formula="0";a.high=0;b.formula="2";b.low=0;b.leftClosed=false;c.formula="1";c.low=c.high=0;c.leftClosed=c.rightClosed=true;
 rows={a,b,c};assert(Piecewise::Validate(rows,true,error));assert(rows[2].Contains(0));rows[2].rightClosed=false;assert(!Piecewise::Validate(rows,true,error));
 c.formula="1/x";c.low=c.high=0;c.leftClosed=c.rightClosed=true;rows={c};assert(!Piecewise::Validate(rows,true,error));
 for(int i=0;i<100;i++){double x=(i-50)/10.;assert(std::fabs(Evaluate("x^2+2x+1",x)-(x+1)*(x+1))<1e-10);}
 assert(Piecewise::Unhex(Piecewise::Hex("sin(x)/(x+1)"))=="sin(x)/(x+1)");
 std::cout<<"Piecewise math passed: precedence, implicit multiplication, functions, trig units, domains, bounds, overlaps, gaps, and isolated points.\n";
}
