#include "../../mathomir-source/Mathomir/SymbolicDerivative.h"
#include <iostream>
#include <cassert>
using namespace SymbolicDerivative;
void Check(const char *s,double x,double expected,int order=1,const char *var="x"){
    Result r;std::string error;double actual;assert(r.Find(s,var,order,error));
    if(!r.At(x,actual,error)){std::cerr<<s<<": "<<error<<"\n";std::abort();}
    if(std::fabs(actual-expected)>1e-9*(1+std::fabs(expected))){std::cerr<<s<<" -> "<<Text(r.derivative)<<" = "<<actual<<", expected "<<expected<<"\n";std::abort();}
    assert(Equation(r).find("<opr s=\"=\" />")!=std::string::npos);
}
int main(){
    Check("x^3+2x",2,14);Check("x^4",2,48,2);Check("x^5",2,120,5);
    Check("-x^2",3,-6);Check("(x+1)*(x-1)",2,4);Check("x/(x+1)",2,1./9);
    Check("sin(3x)",.4,3*std::cos(1.2));Check("cos(x^2)",.7,-1.4*std::sin(.49));
    Check("tan(x)",.4,1/std::pow(std::cos(.4),2));Check("cot(x)",.4,-1/std::pow(std::sin(.4),2));
    Check("sec(x)",.4,std::tan(.4)/std::cos(.4));Check("csc(x)",.4,-1/std::sin(.4)/std::tan(.4));
    Check("ln(x)",2,.5);Check("log(x)",2,1/(2*std::log(10.)));Check("ln(x^2+1)",2,.8);
    Check("exp(2x)",.4,2*std::exp(.8));Check("e^x",.4,std::exp(.4));Check("2^x",.4,std::pow(2.,.4)*std::log(2.));
    Check("x^x",2,4*(std::log(2.)+1));Check("sqrt(x)",4,.25);Check("cbrt(x)",-8,1./12);
    Check("asin(x)",.4,1/std::sqrt(.84));Check("acos(x)",.4,-1/std::sqrt(.84));Check("atan(x)",.4,1/1.16);
    Check("sinh(x)",.4,std::cosh(.4));Check("cosh(x)",.4,std::sinh(.4));Check("tanh(x)",.4,1/std::pow(std::cosh(.4),2));
    Check("abs(x)",-2,-1);Check("floor(x)",1.2,0);Check("fract(x)",1.2,1);Check("round(x)",1.2,0);Check("trunc(x)",0,0);Check("sgn(x)",-2,0);
    Check("sinc(x)",.4,(.4*std::cos(.4)-std::sin(.4))/.16);Check("pi*x",2,3.141592653589793);
    Check("t^3+2t",2,14,1,"t");Check("x^(-2)",2,-.25);
    Parser numeric;assert(std::fabs(Value(numeric.Parse("e^(pi)-e"),"",0)-20.4224108043202)<1e-11);assert(std::fabs(Value(numeric.Parse("sin(30)"),"",0,false)-.5)<1e-12);assert(std::fabs(Value(numeric.Parse("asin(0.5)"),"",0,false)-30)<1e-12);
    Result r;std::string e;double value;assert(r.Find("x^3+2x","x",1,e));assert(Text(r.derivative)=="3*x^2+2");
    assert(r.Find("a*x^2","x",2,e));assert(!r.At(2,value,e));assert(Text(r.derivative).find('a')!=std::string::npos);
    for(const char *s:{"sin(","unknown(x)","x$2","xy","1e999","", "sin x"})assert(!r.Find(s,"x",1,e));
    assert(!r.Find("x","e",1,e));assert(!r.Find("x","x",6,e));
    for(const char *s:{"0/x","0*ln(x)","ln(x)-ln(x)","abs(x)","floor(x)","sgn(x)","sqrt(x)","cbrt(x)"}){assert(r.Find(s,"x",1,e));assert(!r.At(0,value,e));}
    assert(r.Find("x/x","x",1,e));assert(!r.At(0,value,e));Check("x/x",2,0);
    // Presentation regressions: exact reduced fractions, collected polynomials,
    // coefficient placement, clean signs, and no dots between 3 and cos or 2 and x.
    const char *polished[][2]={{"sin(3x)+ln(x^2+1)","3*cos(3*x)+2*x/(x^2+1)"},{"ln(2x)","1/x"},{"ln(x^3)","3/x"},{"sqrt(x^2+1)","x/sqrt(x^2+1)"},{"(x^2+1)/(x+1)","(x^2+2*x-1)/(x+1)^2"},{"x/(x+1)","1/(x+1)^2"},{"cos(2x)","-2*sin(2*x)"},{"1/(3x)","-1/(3*x^2)"}};
    for(const auto &sample:polished){assert(r.Find(sample[0],"x",1,e));assert(Text(r.derivative)==sample[1]);}
    assert(r.Find("sin(3x)+ln(x^2+1)","x",1,e));std::string polishedXml=Equation(r);
    assert(polishedXml.find("<opr s=\"\xD7\" />")==std::string::npos);
    assert(polishedXml.find("<var t=\"2\" f=\"00\" /><var t=\"x\" f=\"00\" />")!=std::string::npos);
    assert(polishedXml.find("<fun t=\"d\" f=\"20\" E1=\"\"><ex br=\"1\">")!=std::string::npos);
    assert(r.Find("2*3^x","x",1,e));assert(Xml(r.derivative).find("<opr s=\"\xD7\" />")!=std::string::npos);Check("2*3^x",2,18*std::log(3.));
    assert(r.Find("1e20*x","x",1,e));assert(Xml(r.derivative).find("1e+20")==std::string::npos);assert(Xml(r.derivative).find("<var t=\"10\" f=\"00\" />")!=std::string::npos);
    Parser scientific;assert(Xml(scientific.Parse("1e20^x")).find("<ex><elm tp=\"5\" E1=\"\"><ex br=\"1\">")!=std::string::npos);
    assert(r.Find("ln(2x)","x",1,e));assert(!r.At(0,value,e));assert(!r.At(-1,value,e));
    assert(r.Find("x/(x+1)","x",1,e));assert(!r.At(-1,value,e));
    Check("sqrt(x^2+1)",2,2/std::sqrt(5.));Check("(x^2+1)/(x+1)",2,7./9);Check("1/(3x)",2,-1./12);
    // Independent numeric check across many ordinary smooth functions/points.
    for(const char *s:{"sin(x^2)+exp(x)","(x^2+1)/(x+3)","ln(x)+sqrt(x)","x^(sin(x))","asin(x/2)","tanh(x^2)","ln(2x)","sqrt(x^2+1)","cos(2x)","sin(x)*sin(x)","(x+1)^3","1/(3x)"}){
        assert(r.Find(s,"x",1,e));for(int i=1;i<=20;i++){double x=i*.045,h=1e-5;double diff=(Value(r.original,"x",x+h)-Value(r.original,"x",x-h))/(2*h);assert(r.At(x,value,e));assert(std::fabs(value-diff)<1e-6*(1+std::fabs(value)));}
    }
    std::cout<<"Symbolic derivative checks passed: rules, higher orders, parameters, domains, malformed input and 240 independent numeric comparisons and polished native output.\n";
}
