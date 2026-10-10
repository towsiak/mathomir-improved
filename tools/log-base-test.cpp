#include "SymbolicDerivative.h"
#include "Piecewise.h"
#include "IntegralArea.h"
#include <iostream>
#include <cstdlib>
void check(bool ok,const char *message){if(!ok){std::cerr<<message<<"\n";std::exit(1);}}
int main(){
    SymbolicDerivative::Parser p;std::string error;
    for(const char *formula:{"log(sqrt(3),x)","log(2/3,x)","log(2,x+2)","log(e,x)","log(10,x)","log(100)","log(2,log(3,x))"}){
        auto ast=p.Parse(formula);Piecewise::Formula native;check(native.Parse(formula,error),error.c_str());
        for(double x:{.25,.5,1.,3.,9.,27.}){double a=SymbolicDerivative::Value(ast,"x",x),b=native.Value(x);check((!SymbolicDerivative::Finite(a)&&!Piecewise::Finite(b))||std::fabs(a-b)<1e-12,"Parser/evaluator mismatch");}
    }
    auto root=p.Parse("log(sqrt(3),x)");check(std::fabs(SymbolicDerivative::Value(root,"x",9)-4)<1e-12,"Wrong radical-base log");
    auto xml=SymbolicDerivative::Xml(root);check(xml.find("t=\"log\"")!=std::string::npos && xml.find("E2=\"\"")!=std::string::npos && xml.find("tp=\"8\"")!=std::string::npos,"Lost editable radical base");
    check(SymbolicDerivative::Text(root)=="log(sqrt(3), x)","Formula roundtrip lost base");
    SymbolicDerivative::Result d;double value;check(d.Find("log(sqrt(3),x)","x",1,error)&&d.At(3,value,error),error.c_str());check(std::fabs(value-1/(3*std::log(std::sqrt(3.))))<1e-12,"Wrong logarithm derivative");
    check(d.Find("log(x,x^2)","x",1,error)&&d.At(3,value,error)&&std::fabs(value)<1e-12,"Variable-base quotient rule failed");check(!d.At(1,value,error),"Invalid original base accepted after simplification");
    for(const char *formula:{"log(1,x)","log(0,x)","log(-2,x)","log(2,-1)","log(2,0)"}){auto a=p.Parse(formula);check(!SymbolicDerivative::Finite(SymbolicDerivative::Value(a,"x",3)),"Invalid real log accepted");Piecewise::Formula n;check(n.Parse(formula,error)&&!Piecewise::Finite(n.Value(3)),"Native invalid log accepted");}
    for(const char *formula:{"log(2,)","log(,x)","log(2,x,3)","ln(2,x)"}){bool rejected=false;try{p.Parse(formula);}catch(...){rejected=true;}check(rejected,"Malformed log accepted");Piecewise::Formula n;check(!n.Parse(formula,error),"Malformed native log accepted");}
    IntegralArea::Settings s;s.formula="log(sqrt(3),x)";s.a=1;s.b=9;IntegralArea::Result r;check(IntegralArea::Calculate(s,r,error),error.c_str());check(std::fabs(r.integral-(9*std::log(9.)-8)/std::log(std::sqrt(3.)))<1e-7,"Incorrect integral of custom-base log");
    s.formula="log(x,2)";s.a=.5;s.b=2;check(!IntegralArea::Calculate(s,r,error),"Integral crossed base-one pole");
    std::cout<<"Log-base checks passed: radical/fractional bases, nested logs, domain rejection, editable native XML, derivatives, integrals and both graph parsers.\n";
}
