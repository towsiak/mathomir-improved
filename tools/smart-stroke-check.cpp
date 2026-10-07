#include "../../mathomir-source/Mathomir/SmartStroke.h"
#include <cassert>
#include <iostream>
using namespace SmartStroke;
int main(){
    std::vector<Point> p;for(int i=0;i<=200;i++)p.push_back(Point(i,10*std::sin(i/40.)+(i%2?.75:-.75)));
    auto q=Smooth(p,2);assert(q.size()>5);assert(Distance(q.front(),p.front())==0);assert(Distance(q.back(),p.back())==0);
    double raw=0,smoothed=0;for(size_t i=1;i+1<p.size();i++)raw+=std::fabs(p[i].y-10*std::sin(p[i].x/40.));raw/=p.size()-2;
    for(size_t i=1;i+1<q.size();i++)smoothed+=std::fabs(q[i].y-10*std::sin(q[i].x/40.));smoothed/=q.size()-2;assert(smoothed<raw*.5);
    for(auto x:q){double d=1e9;for(size_t i=1;i<p.size();i++)d=std::min(d,SegmentDistance(x,p[i-1],p[i]));assert(d<1.8);}
    std::vector<Point> corner;for(int i=0;i<=40;i++)corner.push_back(Point(i,0));for(int i=1;i<=40;i++)corner.push_back(Point(40,i));q=Smooth(corner,3);bool found=false;for(auto x:q)if(Distance(x,Point(40,0))<1e-10)found=true;assert(found);
    std::vector<Point> line={Point(0,0),Point(30,20),Point(60,40)};q=Smooth(line,3);for(auto x:q)assert(SegmentDistance(x,line.front(),line.back())<1e-10);
    std::vector<Point> loop;for(int i=0;i<101;i++){double a=i*6.283185307179586/100;loop.push_back(Point(30*std::cos(a),30*std::sin(a)));}loop.back()=loop.front();q=Smooth(loop,2);assert(Distance(q.front(),q.back())==0);
    std::vector<Point> duplicate={Point(1,1),Point(1,1),Point(1,1)};assert(Smooth(duplicate,2).size()==3);assert(Smooth(p,0).size()==p.size());
    std::cout<<"Smart stroke checks passed: jitter reduction, displacement bound, exact endpoints/corners, straight paths, closed loops and degenerate strokes.\n";
}
