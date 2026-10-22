#include "TeachingTools.h"
#include <cassert>
#include <iostream>
using namespace TeachingTools;
int main(){
    Grid grid;Data d;std::string error;
    assert(WindowsLines("a\nb\r\nc\rd")=="a\r\nb\r\nc\r\nd");
    assert(Split("t,v\n0,1\n1/2,3\npi,4\n",grid,error));assert(Pairs(grid,0,1,false,d,error));assert(d.points.size()==3&&d.xLabel=="t"&&d.yLabel=="v"&&d.points[1].x==.5);
    assert(Split("t\t0\t1\t2\nv\t3\t5\t8",grid,error));assert(Pairs(grid,0,1,true,d,error)&&d.points.size()==3&&d.points[2].y==8);
    assert(Split("0,1\n1,\n2,4",grid,error));assert(!Pairs(grid,0,1,false,d,error));
    assert(Split("t,v\n1,nope\n",grid,error));assert(!Pairs(grid,0,1,false,d,error));
    assert(Split("(1,2)\n(2,3)",grid,error)&&Pairs(grid,0,1,false,d,error));
    assert(Split("\"Time (s)\",\"Velocity (m/s)\"\n0,2",grid,error)&&Pairs(grid,0,1,false,d,error)&&d.xLabel=="Time (s)");
    double pi;assert(Constant("\xCF\x80/2",pi)&&std::fabs(pi-1.5707963267948966)<1e-12);
    assert(!Pairs(grid,0,0,false,d,error));auto bounds=Bounds({{2,7}});assert(bounds.xmin<2&&bounds.xmax>2&&bounds.ymin<7&&bounds.ymax>7);
    Curve c;InteractiveObjects::Parameters p;p.a[0].value=3;Point q,dir;
    assert(c.Parse("y=a*x^2",true,p,error)&&c.At(2,0,q)&&q.y==12&&c.Direction(2,q,dir));assert(std::fabs(dir.y/dir.x-12)<1e-5);
    assert(c.Parse("x=y^2",true,p,error)&&c.At(2,0,q)&&q.x==4&&q.y==2);
    assert(c.Parse("x^2+y^2=25",true,p,error)&&c.At(3,4,q)&&c.Direction(3,q,dir));assert(std::fabs(q.x*q.x+q.y*q.y-25)<1e-7&&std::fabs(dir.y/dir.x+.75)<1e-5);
    assert(c.Parse("abs(x)",true,p,error)&&c.At(0,0,q)&&!c.Direction(0,q,dir));
    assert(c.Parse("1/x",true,p,error)&&!c.At(0,0,q));
    RelationGraph::Parametric param;assert(param.Parse(error));c.SetParametric(param,p);assert(c.At(0,0,q)&&std::fabs(q.x-3)<1e-8&&c.Direction(0,q,dir)&&std::fabs(dir.x)<1e-5);
    RelationGraph::Viewport v;double u=0,sy=0;assert(c.Nearest(v,v.Pixel({0,2}),u,sy,q)&&std::fabs(q.x)<.01&&std::fabs(q.y-2)<.01);
    Animation a;InteractiveObjects::Parameter value;value.value=value.low;a.playing=true;a.period=1;a.mode=0;assert(a.Advance(value,.5)&&value.value==0);assert(a.Advance(value,.5)&&value.value==5&&!a.playing);
    a.playing=true;a.mode=2;a.phase=.9;a.direction=1;assert(a.Advance(value,.3)&&a.direction==-1&&std::fabs(a.phase-.8)<1e-8);
    auto align=Align({10,11,30,31},{{50,14,70,34}},4);assert(align.horizontal&&align.dy==3&&!align.vertical);
    Axes ax;ax.xName="t";ax.xUnit="s";ax.yName="v";ax.yUnit="m/s";assert(ax.X()=="t (s)"&&ax.Y()=="v (m/s)");assert(Unhex(Hex("m/s\xC2\xB2"))=="m/s\xC2\xB2");
    InteractiveObjects::Info info;info.id=9;info.hidden=true;info.name="Force diagram";info.tableGraph=18;auto attributes=info.Attributes();assert(attributes.find("hidden=\"1\"")!=std::string::npos);InteractiveObjects::Info saved;saved.Read("oname",InteractiveObjects::Info::Encode(info.name).c_str());saved.Read("tgraph","18");assert(saved.name==info.name&&saved.tableGraph==18);assert(InteractiveObjects::Hidden(info));
    std::cout<<"Teaching tools: table orientations, headings, constants, validation, curve points and directions, animation, alignment, units and persistence passed.\n";
}
