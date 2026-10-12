#include "AiProtocol.h"
#include <iostream>
#include <cstdlib>
using namespace MathomirAI;
void check(bool ok,const char *why){if(!ok){std::cerr<<why<<'\n';std::exit(1);}}
bool bad(const std::string &s){try{JsonReader(s).Read();return false;}catch(...){return true;}}
int main(){
    auto request=JsonReader(RequestBody("gpt-4.1-mini-2025-04-14","ln(2)\n\"hello\" \\ path",1,false)).Read();check(request.Get("input").text=="ln(2)\n\"hello\" \\ path","JSON escaping changed math");check(request.Get("instructions").text.find("first invalid step")!=std::string::npos,"Check working prompt missing");check(request.Get("store").text=="false"&&request.Get("stream").text=="false","Nonstored nonstreaming flags missing");
    auto groq=JsonReader(RequestBody(DefaultModel(Groq),"ln(2)",0,false,Groq)).Read();check(groq.Get("model").text=="openai/gpt-oss-120b"&&groq.Get("reasoning").Get("effort").text=="low"&&groq.Get("max_output_tokens").text=="2400","Groq production model/reasoning payload invalid");check(groq.Get("store").text=="false"&&groq.Get("stream").text=="false"&&KeyValid(L"gsk_mathomir_ci_only"),"Groq key/payload validation failed");
    const std::string reply=R"({"status":"completed","output":[{"type":"reasoning","summary":[]},{"type":"message","role":"assistant","content":[{"type":"output_text","text":"ln(2) \u2248 0.6931"},{"type":"output_text","text":"\u03c0 \uD83D\uDE00"}]}]})";
    auto text=ResponseText(reply,200);check(text.find("\xE2\x89\x88")!=std::string::npos,"Approximation Unicode lost");check(text.find("\xCF\x80")!=std::string::npos&&text.find("\xF0\x9F\x98\x80")!=std::string::npos,"Unicode/surrogate pair lost");check(text.find("\n\n")!=std::string::npos,"Multiple text items not collected");
    for(const char *s:{"{","[1,]","{\"a\":1,\"a\":2}","\"\\uD800\"","\"\\uDC00\"","01","1.","1e","{}x","[true false]","\"\\q\""})check(bad(s),"Invalid JSON accepted");
    std::string deep(40,'[');deep+='0';deep+=std::string(40,']');check(bad(deep),"Nesting limit missing");check(bad(std::string(1024*1024+1,' ')),"Response size limit missing");
    check(KeyValid(L"sk-mathomir-ci-only")&&!KeyValid(L"sk-mathomir\r\nInjected: 1")&&!KeyValid(L"short"),"Unsafe authorization header accepted");check(!Identifier("model\nInjected")&&!Identifier("")&&Identifier("gpt-4.1-mini-2025-04-14"),"Model validation failed");
    for(unsigned status:{401,403,404,429,500,302}){try{ResponseText("not JSON or potentially secret error body",status);check(false,"HTTP failure accepted");}catch(const std::exception &e){check(std::string(e.what()).find("secret")==std::string::npos,"Error leaked provider body");}}
    try{ResponseText(R"({"status":"completed","output":[{"type":"message","role":"assistant","content":[{"type":"refusal","refusal":"No"}]}]})",200);check(false,"Refusal accepted as an answer");}catch(...){ }
    auto partial=ResponseText(R"({"status":"incomplete","output":[{"type":"message","role":"assistant","content":[{"type":"output_text","text":"partial"}]}]})",200);check(partial.find("cut short")!=std::string::npos,"Incomplete answer not labelled");
    std::cout<<"AI protocol passed: payload escaping, prompts, Unicode, surrogate pairs, multiple output items, refusals, incomplete replies, status errors, secret redaction, model/key validation and bounded JSON parsing.\n";
}
