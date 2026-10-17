#include "ObjectPointer.h"
#include <cassert>
#include <cmath>
#include <iostream>
int main(){
 int count=0;
 for(double width:{8.,37.,120.,400.})for(double height:{12.,51.,100.})for(int direction=1;direction<=8;direction++)for(double length:{24.,48.,80.}){
  auto arrow=ObjectPointer::Build(width,height,direction,length);auto d=ObjectPointer::Direction(direction);
  auto tail=arrow.line[0].a,tip=arrow.line[0].b;
  assert(std::fabs(std::hypot(tip.x-tail.x,tip.y-tail.y)-length)<1e-8);
  assert(std::fabs((tip.x-tail.x)*d.y-(tip.y-tail.y)*d.x)<1e-8);
  assert((tail.x<0 || tail.x>width || tail.y<0 || tail.y>height));
  assert(arrow.line[1].a.x==tip.x && arrow.line[2].a.y==tip.y);
  double left=(arrow.line[1].b.x-tip.x)*d.x+(arrow.line[1].b.y-tip.y)*d.y;
  double right=(arrow.line[2].b.x-tip.x)*d.x+(arrow.line[2].b.y-tip.y)*d.y;
  assert(left<0 && std::fabs(left-right)<1e-8);count++;
 }
 std::cout<<"Object pointer geometry passed: "<<count<<" size/direction/length combinations, external tails, exact lengths and symmetric backward arrowheads.\n";
}
