#include "UnitCircleGeometry.h"
#include <vector>
#include <stdexcept>
#include <iostream>
struct Segment { double x1,y1,x2,y2; int width; };
void Require(bool pass) { if(!pass)throw std::runtime_error("Incorrect unit-circle geometry"); }
int main() {
    struct Case {double start,end,sweep;int direction;};
    const Case cases[]={{0,-90,-90,0},{0,90,90,0},{0,-270,-270,0},
        {90,-90,-180,0},{350,370,20,0},{0,-360,-360,0},{0,-720,-720,0},
        {0,720,720,0},{0,0,0,0},{0,-90,270,1},{0,90,-270,2},
        {-90,-180,-90,0},{0,360,-360,2},{0,-360,360,1}};
    const double pi=3.14159265358979323846;
    for(const auto &c:cases) {
        Require(std::fabs(UnitCircleGeometry::Sweep(c.start,c.end,c.direction)-c.sweep)<1e-8);
        std::vector<Segment> lines;
        UnitCircleGeometry::Arc(c.start,c.end,c.direction,105,235,
            [&](double a,double b,double d,double e,int width){lines.push_back({a,b,d,e,width});});
        int n=(int)std::ceil(std::fabs(c.sweep)/2.);
        Require(lines.size()==static_cast<size_t>(n?n+2:0));
        double total=0;
        for(int i=0;i<n;i++) {
            const auto &s=lines[i];Require(s.width==3);
            double a=std::atan2(235-s.y1,s.x1-235),b=std::atan2(235-s.y2,s.x2-235);
            double delta=std::remainder(b-a,2*pi);
            Require(delta*c.sweep>0);total+=delta*180/pi;
            if(c.start==0 && c.end==-90 && c.direction==0)
                Require(s.x1>=235-1e-8 && s.x2>=235-1e-8 && s.y1>=235-1e-8 && s.y2>=235-1e-8);
        }
        Require(std::fabs(total-c.sweep)<1e-7);
        if(n)for(int i=n;i<n+2;i++) {
            const auto &arrow=lines[i];double angle=c.end*pi/180.,sign=c.sweep<0?-1.:1.;
            Require(arrow.width==2);
            Require(std::fabs(arrow.x1-lines[n-1].x2)<1e-7 && std::fabs(arrow.y1-lines[n-1].y2)<1e-7);
            double tx=-std::sin(angle)*sign,ty=-std::cos(angle)*sign;
            Require(std::fabs((arrow.x1-arrow.x2)*tx+(arrow.y1-arrow.y2)*ty-10)<1e-7);
        }
    }
    std::cout << "Signed unit-circle geometry passed: arc extent, quadrant, continuity, full turns, zero sweep and tangent arrowheads.\n";
}
