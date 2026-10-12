#include "PolygonConstructor.h"
#include <cassert>
#include <iostream>
using namespace PolygonConstructor;
int main(){
 Shape s;std::string e;const double pi=3.14159265358979323846;
 for(int n=3;n<=64;n++)for(bool clockwise:{false,true})for(double angle:{0.,90.,-45.,1e5}){
  assert(Regular(n,2,true,angle,clockwise,s,e));assert(s.points.size()==(size_t)n && s.convex);
  double angleSum=0;for(size_t i=0;i<s.points.size();i++)angleSum+=InteriorAngle(s,i);assert(std::fabs(angleSum-(n-2)*pi)<1e-8);
  assert(std::fabs(s.perimeter-2*n)<1e-8);assert(std::fabs(s.area-n/std::tan(pi/n))<1e-8);
  for(size_t i=0;i<s.points.size();i++)assert(std::fabs(Distance(s.points[i],s.points[(i+1)%n])-2)<1e-8);
  Point a=PagePoint(s,0,300),b=PagePoint(s,1,300);assert(a.x>=-1e-8&&a.y>=-1e-8);assert(std::fabs(Distance(a,b)-2*PageScale(s,300))<1e-8);
 }
 assert(Parse("(0,0); (4,0); (4,1); (1,1); (1,3); (0,3)",s,e));assert(!s.convex && s.area==6 && s.perimeter==14);assert(std::fabs(InteriorAngle(s,3)-1.5*pi)<1e-12);int lines=0;AngleMarker(s,0,300,[&](double,double,double,double){lines++;});assert(lines==2);
 std::reverse(s.points.begin(),s.points.end());double sum=0;for(size_t i=0;i<s.points.size();i++)sum+=InteriorAngle(s,i);assert(std::fabs(sum-4*pi)<1e-12);
 assert(Parse("0,0\n4,0\n4,3\n0,3\n0,0",s,e));assert(s.points.size()==4 && s.area==12 && s.perimeter==14);
 assert(Parse("(0,0); ((1+2),0); (3,sqrt(4)); (0,2)",s,e));assert(s.area==6);
 assert(Parse("(0,0); (pi,0); (pi,1/2); (0,1/2)",s,e));assert(std::fabs(s.area-pi/2)<1e-12);
 assert(Parse("999990,999990;999994,999990;999994,999993;999990,999993",s,e));assert(s.area==12);
 assert(Parse("0,0;2,0;4,0;4,3;0,3",s,e));assert(s.convex && s.area==12);
 for(const char *bad:{"","0,0;1,1","0,0;1,1;2,2","0,0;2,2;0,2;2,0","0,0;3,0;1,0;1,2;0,2","0,0;4,0;4,4;2,0;0,4","0,0;4,0;4,3;4,0;0,3","(0,0;1,0;0,1","0,0;1,0;0,nan","0,0;1,0;0,inf","0,0;1,0;0,x","0,0;1,0;0,1/0","0,0;1,0;0,1000001","0,0;1,0;0,1,2","0,0;1,0;0,","0,0;1,0;,1"})assert(!Parse(bad,s,e));
 assert(!Regular(2,3,false,0,false,s,e));assert(!Regular(65,3,false,0,false,s,e));assert(!Regular(5,0,false,0,false,s,e));assert(!Regular(5,-1,false,0,false,s,e));
 assert(Regular(64,2,false,0,false,s,e));assert(Parse(Coordinates(s),s,e));assert(s.points.size()==64);
 assert(VertexName(0)=="A" && VertexName(25)=="Z" && VertexName(26)=="A1" && VertexName(63)=="L2");
 std::cout<<"Polygon math passed: regular 3-64 sides, side length, rotation, winding, concave outlines, constant expressions, measurements, page scaling, repeated closing points, and invalid/crossing edges.\n";
}
