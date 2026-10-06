#include "Piecewise.h"
#include "GraphDiscontinuities.h"
#include <cassert>
#include <iostream>
static void Check(const char *name,double x,double expected){
 double result=ScalarFunctions::Value(name,x);assert(std::fabs(result-expected)<1e-12*(1+std::fabs(expected)));
 Piecewise::Formula formula;std::string error;
 assert(formula.Parse(std::string(name)+"(x)",error));
 assert(std::fabs(formula.Value(x)-expected)<1e-12*(1+std::fabs(expected)));
 assert(formula.Value(x,false)==formula.Value(x,true));
 assert(!formula.Xml().empty());
}
int main(){
 Check("floor",-1.2,-2);Check("ceil",-1.2,-1);Check("abs",-3,3);
 Check("round",-1.5,-2);Check("round",1.5,2);Check("round",-.49,0);
 Check("trunc",-1.8,-1);Check("sgn",-1,-1);Check("sgn",0,0);Check("sgn",1,1);
 Check("fract",-1.2,.8);Check("fract",-2,0);Check("fract",1.999999, .999999);
 Check("cbrt",-8,-2);Check("cbrt",27,3);Check("exp",0,1);
 Check("sinc",0,1);Check("sinc",1e-10,1);Check("sinc",3.141592653589793,0);
 Check("floor",1e20,1e20);Check("ceil",-1e20,-1e20);
 assert(ScalarFunctions::Value("exp",300)>1e130);
 assert(ScalarFunctions::Value("exp",-300)>0);
 assert(std::isinf(ScalarFunctions::Value("exp",1000)));
 assert(std::isnan(ScalarFunctions::Value("sgn",std::numeric_limits<double>::quiet_NaN())));
 for(int code=41;code<=50;code++)assert(ScalarFunctions::Known(ScalarFunctions::Name(code)));
 Piecewise::Formula formula;std::string error;
 assert(formula.Parse("floor(2*x)+cbrt(-8)+sinc(0)+fract(-1.2)",error));assert(std::fabs(formula.Value(1.2)-1.8)<1e-12);
 assert(formula.HasSteps());assert(formula.Xml().find("shp=\"f\"")!=std::string::npos);
 assert(!formula.Parse("floor(x, 2)",error));assert(!formula.Parse("bogus(x)",error));
 using GraphDiscontinuities::FiniteJump;
 for(const char *name:{"floor","ceil","round","trunc","sgn","fract"}){
  double a=std::strcmp(name,"round")==0?.499:-.001,b=std::strcmp(name,"round")==0?.501:.001;
  if(std::strcmp(name,"trunc")==0){a=.999;b=1.001;}
  auto f=[&](double x){return ScalarFunctions::Value(name,x);};assert(FiniteJump(f,a,b,f(a),f(b),.001));
 }
 auto steep=[](double x){return 1e8*x;};assert(!FiniteJump(steep,-.001,.001,steep(-.001),steep(.001),.001));
 auto cusp=[](double x){return std::cbrt(x);};assert(!FiniteJump(cusp,-.001,.001,cusp(-.001),cusp(.001),.001));
 auto cancelled=[](double x){return std::floor(x)-std::floor(x)+x;};assert(!FiniteJump(cancelled,-.001,.001,cancelled(-.001),cancelled(.001),.001));
 std::cout<<"Scalar functions passed: negative inputs, ties, zero, large values, sinc convention, parser, native XML and finite jumps.\n";
}
