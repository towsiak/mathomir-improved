#include "SmartShader.h"
#include <cassert>
#include <iostream>
using namespace SmartShader;
static void Box(std::vector<Edge>& e,double x,double y,double w,double h){e.push_back(Edge(Point(x,y),Point(x+w,y)));e.push_back(Edge(Point(x+w,y),Point(x+w,y+h)));e.push_back(Edge(Point(x+w,y+h),Point(x,y+h)));e.push_back(Edge(Point(x,y+h),Point(x,y)));}
int main(){
 std::vector<Edge> e;Box(e,0,0,3200,3200);Shape square;square.Build(e);assert(square.Contains(Point(1600,1600)));assert(!square.Contains(Point(-1,1600)));
 double neg,pos;assert(Clip({square},Point(1600,1600),1,4000,0,neg,pos));assert(neg==1600&&pos==1600);
 assert(Clip({square},Point(100,1600),-1,4000,16,neg,pos));assert(neg==84&&pos==1584);
 Box(e,1200,1200,800,800);Shape ring;ring.Build(e);assert(!ring.Contains(Point(1600,1600)));assert(ring.Contains(Point(800,1600)));
 assert(Clip({ring},Point(1000,1600),1,4000,0,neg,pos));assert(pos==200);assert(!Clip({ring},Point(1600,1600),1,4000,0,neg,pos));
 std::vector<Edge> circleEdges;const double pi=3.141592653589793;for(int i=0;i<96;i++)circleEdges.push_back(Edge(Point(1600*std::cos(i*2*pi/96),1600*std::sin(i*2*pi/96)),Point(1600*std::cos((i+1)*2*pi/96),1600*std::sin((i+1)*2*pi/96))));Shape circle;circle.Build(circleEdges);assert(circle.Contains(Point(0,0)));assert(Clip({circle},Point(0,0),1,4000,0,neg,pos));assert(std::fabs(pos-1600/std::sqrt(2.))<2);
 std::vector<Edge> line={Edge(Point(0,1600),Point(4000,1600))};Shape open;open.Build(line);assert(open.paths.empty());
 LineGuide guide;assert(guide.Clip(line,Point(2000,1700),1,400,16,neg,pos));assert(neg==84);assert(!guide.Clip(line,Point(2000,1500),1,400,16,neg,pos));
 LineGuide up;assert(up.Clip(line,Point(2000,1500),-1,400,16,neg,pos));assert(neg==84);
 for(int i=1;i<30;i++)for(int dir:{-1,1}){Point seed(i*100,1500);assert(Clip({square},seed,dir,4000,16,neg,pos));assert(square.Contains(Point(seed.x-neg,seed.y-dir*neg)));assert(square.Contains(Point(seed.x+pos,seed.y+dir*pos)));}
 std::cout<<"Smart shader passed: closed outlines, circles, nested holes, trimmed endpoints, and locked-side single-line inequalities.\n";
}
