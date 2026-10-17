#include "MomDecode.h"
#include <cassert>
#include <cstring>
#include <iostream>
#include <random>
#include <string>
#include <vector>
static bool decode(const std::vector<char>&input,size_t capacity,std::string &result){
    std::vector<char> output(capacity+1);size_t written=0;
    bool ok=MomDecode::Payload(input.data(),input.size(),output.data(),capacity,written);
    if(ok){assert(written<=capacity);assert(output[written]==0);result.assign(output.data(),written);}
    return ok;
}
int main(){
    std::string out;
    assert(decode({'<','x','>'},3,out)&&out=="<x>");
    assert(!decode({'<',1},1,out)); // Reproduced legacy heap write overflow.
    assert(!decode({'<',1},10,out));
    assert(decode({'<',1},11,out)&&out=="<<obj type=");
    // Capacity above includes the leading '<': token 1 has ten bytes.
    assert(decode({'<','x',' ','a','=','"',18,2,'A','B','"','>'},64,out)&&out=="<x a=\"ABABAB\">");
    assert(!decode({'<','"',18},64,out));
    assert(!decode({'<','"',18,3},64,out));
    assert(!decode({'<','"',18,3,'A'},64,out));
    assert(!decode({'<','"',18,3,'A','B'},3,out));
    assert(decode({'<','"',7,'>'},7,out)&&out=="<\"000\">");
    assert(!decode({},8,out));assert(!decode({'M','O','M'},8,out));
    for(unsigned token=1;token<=255;token++){
        std::vector<char> input={'<',(char)token};
        for(size_t capacity=0;capacity<24;capacity++)decode(input,capacity,out);
    }
    std::mt19937 random(20261017);
    for(int iteration=0;iteration<25000;iteration++){
        std::vector<char> input(1+random()%80);input[0]='<';
        for(size_t i=1;i<input.size();i++)input[i]=(char)random();
        decode(input,random()%160,out);
    }
    std::cout<<"MOM decoder passed: exact capacities, legacy tokens, valid runs, truncated runs, claimed-length overflow and 25000 deterministic malformed payloads.\n";
}
