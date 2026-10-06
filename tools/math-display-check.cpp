#include "Piecewise.h"
#include <cassert>
#include <iostream>
int main(){
 using MathDisplay::Number;
 const double inf=std::numeric_limits<double>::infinity();
 assert(Number(-inf)==L"\u2212\u221e" && Number(inf)==L"+\u221e");
 assert(Number(std::numeric_limits<double>::quiet_NaN())==L"Undefined");
 assert(Number(-0.0)==L"0");assert(Number(.1)==L"0.1");
 assert(Number(-1.25)==L"\u22121.25");
 assert(Number(1e20)==L"1 \u00d7 10\u00b2\u2070");
 assert(Number(1e-20)==L"1 \u00d7 10\u207b\u00b2\u2070");
 assert(Number(1e-300)!=L"0");
 assert(MathDisplay::AxisLabel("-0.00")==L"0.00");
 assert(MathDisplay::AxisLabel("1.5u")==L"1.5\u00b5");
 assert(MathDisplay::AxisLabel("-1+e12")==L"\u22121 \u00d7 10\u00b9\u00b2");
 assert(MathDisplay::AxisLabel("2-e15")==L"2 \u00d7 10\u207b\u00b9\u2075");
 assert(MathDisplay::AxisLabel("Int=-2")==L"Integral \u2248 \u22122");
 assert(MathDisplay::HelpNotation("x >= 0; b != 1; -pi/2; 90 deg; 2*pi; non-overlapping; spinning")==L"x \u2265 0; b \u2260 1; \u2212\u03c0/2; 90\u00b0; 2\u00b7\u03c0; non-overlapping; spinning");
 assert(MathDisplay::HelpNotation("(-infinity, infinity)")==L"(\u2212\u221e, +\u221e)");
 Piecewise::Row row;
 assert(row.DisplayInterval()==L"(\u2212\u221e, +\u221e)");
 row.low=0;row.leftClosed=true;assert(row.DisplayInterval()==L"[0, +\u221e)");
 row.low=-1.25;row.high=.1;row.rightClosed=true;
 assert(row.DisplayInterval()==L"[\u22121.25, 0.1]");
 row.high=inf;assert(row.DisplayInterval()==L"[\u22121.25, +\u221e)");
 // Formatting must leave full-precision saved bounds and formulas untouched.
 const double exact=.12345678901234566;row.low=exact;
 const std::string saved=Piecewise::Number(row.low);row.DisplayInterval();
 assert(Piecewise::StoredBound(saved.c_str())==exact);
 assert(Piecewise::Number(inf)=="inf" && Piecewise::Number(-inf)=="-inf");
 struct Comma : std::numpunct<char>{char do_decimal_point()const{return ',';}};
 std::locale old=std::locale::global(std::locale(std::locale::classic(),new Comma));
 assert(Number(1.25)==L"1.25");std::locale::global(old);
 std::cout<<"Math display passed: signed infinity, Unicode notation, scientific exponents, small values, negative zero, intervals, locale independence and lossless saved bounds.\n";
}
