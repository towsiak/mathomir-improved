#include "SmartStroke.h"
#include <cassert>
#include <iostream>
using namespace SmartStroke;
double MaxTurn(const std::vector<Point>& p){double result=0;for(size_t i=1;i+1<p.size();i++){Point a(p[i].x-p[i-1].x,p[i].y-p[i-1].y),b(p[i+1].x-p[i].x,p[i+1].y-p[i].y);double l=Distance(p[i],p[i-1])*Distance(p[i+1],p[i]);if(l>.000001)result=std::max(result,std::acos(std::max(-1.,std::min(1.,(a.x*b.x+a.y*b.y)/l))));}return result;}
int main(){
    std::vector<Point> p;for(int i=0;i<=200;i++)p.push_back(Point(i,10*std::sin(i/40.)+(i%2?.75:-.75)));
    auto q=Smooth(p,2);assert(q.size()>5);assert(Distance(q.front(),p.front())==0);assert(Distance(q.back(),p.back())==0);
    double raw=0,smoothed=0;for(size_t i=1;i+1<p.size();i++)raw+=std::fabs(p[i].y-10*std::sin(p[i].x/40.));raw/=p.size()-2;
    for(size_t i=1;i+1<q.size();i++)smoothed+=std::fabs(q[i].y-10*std::sin(q[i].x/40.));smoothed/=q.size()-2;assert(smoothed<raw*.5);
    for(auto x:q){double d=1e9;for(size_t i=1;i<p.size();i++)d=std::min(d,SegmentDistance(x,p[i-1],p[i]));assert(d<1.8);}
    std::vector<Point> corner;for(int i=0;i<=40;i++)corner.push_back(Point(i,0));for(int i=1;i<=40;i++)corner.push_back(Point(40,i));q=Smooth(corner,3);double nearest=1e9;for(auto x:q)nearest=std::min(nearest,Distance(x,Point(40,0)));assert(nearest>2);
    std::vector<Point> line={Point(0,0),Point(30,20),Point(60,40)};q=Smooth(line,3);for(auto x:q)assert(SegmentDistance(x,line.front(),line.back())<1e-10);
    std::vector<Point> loop;for(int i=0;i<101;i++){double a=i*6.283185307179586/100;loop.push_back(Point(30*std::cos(a),30*std::sin(a)));}loop.back()=loop.front();q=Smooth(loop,2);assert(Distance(q.front(),q.back())==0);
    std::vector<Point> duplicate={Point(1,1),Point(1,1),Point(1,1)};assert(Smooth(duplicate,2).size()==3);assert(Smooth(p,0).size()==p.size());
    std::vector<Point> sparse={Point(92,478),Point(334,401),Point(362,373),Point(380,329),Point(373,295),Point(346,271),Point(314,261),Point(262,267),Point(177,284),Point(103,291),Point(67,263),Point(81,203),Point(175,156),Point(262,148),Point(348,172),Point(398,198),Point(499,227),Point(514,224),Point(550,199),Point(579,143),Point(578,103),Point(573,74)};
    for(int level=1;level<=3;level++){q=Smooth(sparse,level);assert(Distance(q.front(),sparse.front())==0&&Distance(q.back(),sparse.back())==0);assert(MaxTurn(q)<.22);assert(MaxTurn(q)<MaxTurn(sparse)*.2);for(auto x:q){double d=1e9;for(size_t i=1;i<sparse.size();i++)d=std::min(d,SegmentDistance(x,sparse[i-1],sparse[i]));assert(d<33);}std::cout<<"Sparse bends level "<<level<<": max turn "<<MaxTurn(q)*180/3.141592653589793<<" degrees\n";}
    std::vector<Point> resampled;for(size_t i=1;i<sparse.size();i++){for(int n=0;n<10;n++)resampled.push_back(Mix(sparse[i-1],sparse[i],n/10.));}resampled.push_back(sparse.back());auto same=Smooth(resampled,2);q=Smooth(sparse,2);assert(q.size()==same.size());for(size_t i=0;i<q.size();i++)assert(Distance(q[i],same[i])<1e-8);
    std::cout<<"Smart stroke checks passed: jitter reduction, displacement bound, exact endpoints, rounded sparse corners, mouse-event invariance, straight paths, closed loops and degenerate strokes.\n";
}
