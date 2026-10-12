#include "IntegralArea.h"
#include <iostream>
#include <cstdlib>
static void check(bool ok,const char *message){if(!ok){std::cerr<<message<<"\n";std::exit(1);}}
static IntegralArea::Result run(const char *formula,double a,double b,double expected,double area,bool radians=true){
    IntegralArea::Settings s;s.formula=formula;s.a=a;s.b=b;s.radians=radians;IntegralArea::Result r;std::string error;
    check(IntegralArea::Calculate(s,r,error),error.c_str());check(std::fabs(r.integral-expected)<1e-7,"Wrong signed integral");check(std::fabs(r.area-area)<1e-7,"Wrong absolute area");return r;
}
int main(){
    const double pi=3.14159265358979323846;
    run("sin(x)",0,pi,2,2);run("sin(x)",0,2*pi,0,4);run("x",-2,2,0,4);run("x",2,-2,0,4);
    run("x^2",-1,2,3,3);run("x^2",2,-1,-3,3);run("ln(x)",1,2,2*std::log(2.)-1,2*std::log(2.)-1);
    run("sin(x)",0,180,360/pi,360/pi,false);run("floor(x)",-1,2,0,2);run("floor(x)",-.2,1.7,.5,.9);
    run("abs(x)",-1,1,1,1);run("exp(-x^2)",-1,1,1.493648265624854,1.493648265624854);
    IntegralArea::Settings s;IntegralArea::Result r;std::string error;
    for(const char *formula:{"1/x","1/(x-0.3)","1/(x-0.3)^2","sqrt(x)","ln(x)","tan(x)","y+x"}){
        s.formula=formula;s.a=-2;s.b=2;check(!IntegralArea::Calculate(s,r,error),"Undefined/pole/parameter accepted");check(!r.ready,"Rejected result left ready");}
    s.formula="x";s.a=s.b=0;check(!IntegralArea::Calculate(s,r,error),"Equal bounds accepted");
    double constant;check(IntegralArea::Constant("pi/2",constant,error)&&std::fabs(constant-pi/2)<1e-12,"Constant parser");check(!IntegralArea::Constant("x",constant,error),"Variable bound accepted");
    std::cout<<"Integral checks passed: signed/absolute/reversed areas, radians/degrees, logarithm, step functions, adaptive refinement, poles, invalid domains and bounds.\n";
}
