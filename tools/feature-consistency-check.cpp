#include "../source/Mathomir/GraphPointLists.h"
#include <cassert>
#include <chrono>
#include <iostream>
#include <thread>
int main(){
    using TeachingTools::Axes;Axes original;original.xName="t";original.yName="v";original.xUnit="s";original.yUnit="m/s";
    Axes inlineEdit=original;inlineEdit.yUnit="m/s\xC2\xB2";
    Axes dockEdit=original;dockEdit.xName="time";
    auto afterInline=TeachingTools::MergeAxes(original,original,inlineEdit);
    auto merged=TeachingTools::MergeAxes(afterInline,original,dockEdit);
    assert(merged.xName=="time"&&merged.yUnit=="m/s\xC2\xB2");
    assert(TeachingTools::MergeAxes(merged,original,original)==merged); // stale unchanged form cannot revert newer state
    Axes clear=merged;clear.xUnit="";assert(TeachingTools::MergeAxes(merged,merged,clear).xUnit.empty());
    Axes conflict=original;conflict.yUnit="km/h";assert(TeachingTools::MergeAxes(afterInline,original,conflict).yUnit=="km/h");
    assert(merged.Valid());Axes bad=merged;bad.xName="";assert(!bad.Valid());bad=merged;bad.yUnit.assign(81,'a');assert(!bad.Valid());
    // Refreshing untouched fields while another field is being typed must keep
    // that draft, then still apply it against the new baseline.
    auto draft=TeachingTools::MergeAxes(afterInline,original,dockEdit);
    assert(TeachingTools::MergeAxes(afterInline,afterInline,draft)==merged);
    assert(TeachingTools::SliderPollInterval(false,false,false)==125);
    for(int mask=1;mask<8;mask++)assert(TeachingTools::SliderPollInterval(mask&1,mask&2,mask&4)==16);
    InteractiveObjects::Info linked;linked.id=1;linked.tableGraph=2;linked.steps=9;
    InteractiveObjects::Connector connection;connection.from=5;connection.to=6;
    std::set<unsigned int> reserved;InteractiveObjects::ReserveIds(reserved,linked,&connection,7);
    assert(reserved==std::set<unsigned int>({1,2,5,6,7,9}));
    unsigned int next=1;assert(InteractiveObjects::AllocateId(next,reserved)==3);assert(InteractiveObjects::AllocateId(next,reserved)==4);assert(InteractiveObjects::AllocateId(next,reserved)==8);
    reserved.clear();next=0x7ffffffeu;assert(InteractiveObjects::AllocateId(next,reserved)==0x7ffffffeu);assert(next==1);assert(InteractiveObjects::AllocateId(next,reserved)==1);
    GraphPointLists::Cache cache;auto first=cache.Resolve("(1,2),(3,4),(5,6)");assert(first->kind==GraphPointLists::Ready&&first->points.size()==3);
    for(int i=0;i<10000;i++)assert(cache.Resolve(first->source).get()==first.get());
    auto changed=cache.Resolve("(1,2),(3,4),(5,7)");assert(changed.get()!=first.get()&&changed->points[2].y==7&&first->points[2].y==6);
    auto invalid=cache.Resolve("(1,2),(3,)");assert(invalid->kind==GraphPointLists::Invalid&&invalid->points.empty());assert(cache.Resolve(invalid->source).get()==invalid.get());
    auto curve=cache.Resolve("sin(x)");assert(curve->kind==GraphPointLists::NotPoints&&curve->points.empty());
    // Concurrent UI/worker reads share immutable numeric results. Earlier
    // snapshots remain valid even when the next edit replaces the cache entry.
    auto stable=cache.Resolve("(1,2),(3,4),(5,6)");std::thread threads[4];
    for(auto &t:threads)t=std::thread([&](){for(int i=0;i<5000;i++){auto r=cache.Resolve(stable->source);assert(r.get()==stable.get()&&r->points[2].y==6);}});
    for(auto &t:threads)t.join();
    std::string points;for(int i=0;i<100;i++){if(i)points+=',';points+='('+std::to_string(i)+",sqrt(4))";}
    auto begin=std::chrono::steady_clock::now();
    for(int i=0;i<1000;i++){std::vector<RelationGraph::Point> p;std::string error;assert(GraphPointLists::Parse(points,p,error)==GraphPointLists::Ready);}
    auto middle=std::chrono::steady_clock::now();auto c=cache.Resolve(points);
    for(int i=0;i<1000;i++)assert(cache.Resolve(points).get()==c.get());
    auto end=std::chrono::steady_clock::now();
    std::cout<<"Feature consistency passed: merged axis edits, clear/conflict behavior, validation, adaptive polling, cached invalidation and concurrent immutable point snapshots.\n";
    std::cout<<"100 points, 1000 reads: parse "<<std::chrono::duration_cast<std::chrono::microseconds>(middle-begin).count()<<" us; cache "<<std::chrono::duration_cast<std::chrono::microseconds>(end-middle).count()<<" us.\n";
}
