"""Exercise actual native save/parser functions with controlled MFC dependencies.

--emit generates C++ for MSVC; without it, compile and run under GCC sanitizers.
The function bodies are read from the assembled source, not reimplemented here.
"""
import argparse
import os
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parent.parent


def function(path, signature):
    source = path.read_text(encoding="latin1")
    start = source.index(signature)
    return source[start:source.index("\n}", start) + 2]


def generate():
    source = repo / "source/Mathomir"
    prelude = r'''
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>
typedef int BOOL;
typedef const char *LPCTSTR;
const int IDCANCEL=2, IDYES=6, IDNO=7, MB_YESNOCANCEL=3, MB_ICONQUESTION=32;
int NumDocumentElements=1, answer=IDYES;
char TheFileType=0;
void CopyTranslatedString(char *s,const char *t,int,int){std::strcpy(s,t);}
int AfxMessageBox(const char*,int,void*){return answer;}
class CMathomirDoc {
public:
    bool modified=true, saveWorks=false;
    int writes=0;
    bool IsModified(){return modified;}
    void OnFileSave(){writes++;if(saveWorks)modified=false;}
    int SaveMOMFile(char*,char){return saveWorks?1:0;}
    BOOL SaveModified();
    BOOL OnSaveDocument(LPCTSTR);
};
class CMainFrame {public:char *XML_read_attribute(char*,char*,char*,int);};
'''
    bodies = "\n".join([
        function(source / "MathomirDoc.cpp", "BOOL CMathomirDoc::OnSaveDocument"),
        function(source / "MathomirDoc.cpp", "BOOL CMathomirDoc::SaveModified"),
        function(source / "MainFrm.cpp", "char * CMainFrame::XML_read_attribute"),
    ])
    tests = r'''
static int failures=0;
void check(bool ok,const char *label){if(!ok){std::cerr<<"FAIL: "<<label<<"\n";failures++;}}
int main(){
    CMathomirDoc doc;
    check(!doc.SaveModified(),"canceled/failed save must keep document open");
    check(!doc.OnSaveDocument("failure.mom"),"save callback must report failure");
    NumDocumentElements=0;answer=IDCANCEL;
    check(!doc.SaveModified(),"deleting every object must still allow canceling close");
    NumDocumentElements=1;answer=IDYES;doc.saveWorks=true;
    check(doc.SaveModified(),"successful save permits close");
    check(doc.OnSaveDocument("success.mom"),"save callback reports success");
    doc.modified=true;answer=IDNO;check(doc.SaveModified(),"explicit discard permits close");
    doc.modified=true;answer=IDCANCEL;check(!doc.SaveModified(),"cancel keeps document open");
    doc.modified=false;answer=IDYES;int writes=doc.writes;
    check(doc.SaveModified()&&doc.writes==writes,"unmodified document skips prompt/save");

    CMainFrame frame;
    char attribute[128]={},value[128]={};
    check(!frame.XML_read_attribute(attribute,value,NULL,128),"null input rejected");
    char empty[]={0};check(!frame.XML_read_attribute(attribute,value,empty,0),"zero output capacity rejected");
    const char *cases[]={" name=\"\\", " name=\"\\4", " name=\"\\41\"", " X=\"123\" >", " color=\"blue\"", " >"};
    int prefixes=0;
    for(const char *text:cases){
        size_t length=std::strlen(text);
        for(size_t n=0;n<=length;n++){
            // Exact-sized allocations expose even one-byte lookahead overreads.
            char *input=new char[n+1];std::memcpy(input,text,n);input[n]=0;
            frame.XML_read_attribute(attribute,value,input,128);
            frame.XML_read_attribute(attribute,value,input,1);
            delete[] input;prefixes++;
        }
    }
    char valid[]=" name=\"\\41\"";
    check(frame.XML_read_attribute(attribute,value,valid,128)!=NULL &&
        std::strcmp(attribute,"name")==0 && std::strcmp(value,"A")==0,"valid escaped attributes preserved");
    char shortEscape[]=" name=\"\\";
    check(!frame.XML_read_attribute(attribute,value,shortEscape,128),"truncated escape rejected");
    if(failures)return 1;
    std::cout<<"Native source health passed: save/close results, deleted-all document, "
        <<prefixes<<" truncated XML prefixes, minimal outputs and valid hex escape.\n";
}
'''
    return prelude + bodies + tests


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--emit", type=Path)
    args = parser.parse_args()
    output = args.emit or repo / "source/build/source-health-test.cpp"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(generate(), encoding="utf-8")
    if not args.emit:
        binary = output.with_suffix("")
        subprocess.run(["g++", "-std=c++11", "-O1", "-g", "-fno-omit-frame-pointer",
                        "-fsanitize=address,undefined", str(output), "-o", str(binary)], check=True)
        subprocess.run([str(binary)], check=True, env=dict(os.environ,
                       ASAN_OPTIONS="detect_leaks=0:halt_on_error=1", UBSAN_OPTIONS="halt_on_error=1"))
