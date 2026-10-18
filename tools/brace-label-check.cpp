#include "BraceLabel.h"
#include <iostream>
#include <cstdlib>
using namespace BraceLabel;
static void Check(bool ok,const char *reason){if(!ok){std::cerr<<reason<<"\n";std::exit(1);}}
static Point Rotate(Point p,double angle){Point q={p.x*std::cos(angle)-p.y*std::sin(angle),p.x*std::sin(angle)+p.y*std::cos(angle)};return q;}
int main(){int count=0;for(int side=0;side<4;side++)for(int degrees=-180;degrees<=180;degrees+=15)for(int size=1;size<=4;size++){
    Point p[11];Outline(120*size,20*size,side,p);double angle=degrees*3.14159265358979323846/180;
    Layout base=Place(p[0],p[10],p[5],90*size,30*size,0,6*size);
    Point first=Rotate(p[0],angle),last=Rotate(p[10],angle),tip=Rotate(p[5],angle);
    Layout a=Place(first,last,tip,90*size,30*size,angle,6*size);
    Check(Contains(a.corner,a.center),"label center outside its box");Check(!Contains(a.corner,tip),"brace tip inside label box");Check(Contains(a.corner,a.contact),"connector misses box");
    Point expected=Rotate(base.center,angle);Check(std::hypot(expected.x-a.center.x,expected.y-a.center.y)<1e-8,"attachment changes when rotated");
    Check(std::fabs(std::hypot(a.contact.x-tip.x,a.contact.y-tip.y)-6*size)<1e-8,"connector gap changed");
    Point q={a.contact.x-a.center.x,a.contact.y-a.center.y};q=Rotate(q,-angle);
    Check(std::fabs(std::fabs(q.x)-45*size)<1e-8||std::fabs(std::fabs(q.y)-15*size)<1e-8,"connector does not end on box edge");
    Layout enlarged=Place(Scale(first,2.5),Scale(last,2.5),Scale(tip,2.5),225*size,75*size,angle,15*size);
    Check(std::hypot(enlarged.center.x-a.center.x*2.5,enlarged.center.y-a.center.y*2.5)<1e-8,"attachment changes when scaled");count++;
}std::cout<<count<<" brace-label direction/rotation/scale geometry cases passed.\n";}
