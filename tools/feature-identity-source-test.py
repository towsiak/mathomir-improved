"""Run the assembled native ID reservation/allocation bodies with tiny object stubs."""
import argparse
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parent.parent
source = (repo / "source/Mathomir/InteractiveFeatures.inl").read_text(encoding="latin1")
start = source.index("static void ReserveInteractiveIds(")
end = source.index("static InteractiveNode *FindInteractive", start)
body = source[start:end]
prelude = r'''
#include "InteractiveObjects.h"
#include <iostream>
struct CFunctionPlotter {struct {unsigned int source=0;} tableData;};
struct CDrawing {InteractiveObjects::Connector m_Connector;int IsSpecialDrawing=0;void *SpecialData=NULL;};
struct InteractiveNode {InteractiveObjects::Info *info;int type;void *object;};
'''
tests = r'''
int main(){
    InteractiveObjects::Info linked,added,wire,ordinary;
    linked.id=1;linked.tableGraph=2;linked.steps=9;
    CFunctionPlotter data;data.tableData.source=7;
    CDrawing graph,connector;graph.IsSpecialDrawing=51;graph.SpecialData=&data;
    connector.m_Connector.from=5;connector.m_Connector.to=6;
    wire.id=10;
    std::vector<InteractiveNode> nodes={{&linked,1,NULL},{&added,2,&graph},{&wire,2,&connector},{&ordinary,1,NULL}};
    EnsureInteractiveIds(nodes);
    if(added.id!=3||ordinary.id!=4){std::cerr<<"Dangling references reused: "<<added.id<<", "<<ordinary.id<<"\n";return 1;}
    std::set<unsigned int> used;ReserveInteractiveIds(nodes,used);
    for(unsigned int id:{1u,2u,3u,4u,5u,6u,7u,9u,10u})if(!used.count(id))return 2;
    if(NewInteractiveId(used)!=8)return 3;
    NextInteractiveId=0x7fffffffu;if(NewInteractiveId(used)!=11)return 4;
    std::cout<<"Native ID source passed: missing graph/table/connector targets stay reserved, fresh identities remain independent, and allocation wraps safely.\n";
}
'''
parser = argparse.ArgumentParser()
parser.add_argument("--emit", type=Path)
args = parser.parse_args()
output = args.emit or repo / "source/build/feature-identity-source.cpp"
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(prelude + body + tests)
if not args.emit:
    executable = output.with_suffix("")
    subprocess.run(["g++", "-std=c++17", "-O1", "-g", "-fsanitize=address,undefined", "-I", str(repo / "source/Mathomir"), str(output), "-o", str(executable)], check=True)
    import os
    env = dict(os.environ, ASAN_OPTIONS="detect_leaks=0")
    subprocess.run([str(executable)], check=True, env=env)
