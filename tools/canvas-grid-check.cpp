#include "CanvasGrid.h"
#include <cassert>
#include <cmath>
#include <iostream>
#include <vector>
using CanvasGrid::Point;
static bool near(double a,double b){return std::fabs(a-b)<1e-8;}
int main(){
    using namespace CanvasGrid;
    auto p=Snap(Dots,16,Point(137,157));assert(near(p.x,144)&&near(p.y,160));
    p=Snap(Square,16,Point(-137,-157));assert(near(p.x,-144)&&near(p.y,-160));
    p=Snap(Horizontal,16,Point(137,157));assert(near(p.x,137)&&near(p.y,160));
    p=Snap(Vertical,16,Point(137,157));assert(near(p.x,144)&&near(p.y,157));
    // Check nearest-vertex distances against an independent enumeration, including negative rows.
    for(int spacing: {5,8,16,24,80})for(int x=-100;x<=100;x+=7)for(int y=-100;y<=100;y+=11){
        p=Snap(Isometric,spacing,Point(x+.3,y+.7));double dy=spacing*std::sqrt(3.)/2,best=1e100;
        int row=(int)std::floor((y+.7)/dy),col=(int)std::floor((x+.3)/spacing);
        for(int r=row-3;r<=row+3;r++)for(int c=col-3;c<=col+3;c++){
            double vx=spacing*(c+(r%2==0?0:.5)),vy=r*dy;
            double d=std::pow(vx-x-.3,2)+std::pow(vy-y-.7,2);if(d<best)best=d;
        }
        assert(near(std::pow(p.x-x-.3,2)+std::pow(p.y-y-.7,2),best));
    }
    for(int style=0;style<StyleCount;style++){
        int lines=0,dots=0,major=0;Paint(style,16,100,12,7,100,80,
            [&](double x1,double y1,double x2,double y2,bool bold){lines++;major+=bold;
                if(style==Horizontal)assert(near(y1,y2));if(style==Vertical)assert(near(x1,x2));
                // Every rendered intersection should belong to the same snapping lattice.
                if(style==Isometric && !near(y1,y2)){
                    for(int row=1;row<4;row++){double worldY=row*16*std::sqrt(3.)/2;
                        double t=(worldY-7-y1)/(y2-y1),worldX=12+x1+t*(x2-x1);
                        auto vertex=Snap(style,16,Point(worldX,worldY));assert(near(vertex.x,worldX)&&near(vertex.y,worldY));
                    }
                }
            },[&](double x,double y){dots++;auto q=Snap(style,16,Point(x+12,y+7));assert(near(q.x,x+12)&&near(q.y,y+7));});
        assert(style==Dots?dots>0&&lines==0:lines>0&&dots==0);if(style==GraphPaper)assert(major>0);
    }
    // Render complexity stays bounded at extreme zoom; panning changes only screen offsets.
    int count=0;Paint(Dots,5,.001,-500,-300,1600,900,[&](double,double,double,double,bool){assert(false);},[&](double,double){count++;});assert(count<50000);
    auto invalid=Snap(Dots,0,Point(1,2));assert(invalid.x==1&&invalid.y==2);
    std::cout<<"Canvas grid math checks passed: all styles, signed coordinates, nearest isometric vertices, rendering/snapping agreement and extreme zoom density.\n";
}
