import json,sys
from http.server import BaseHTTPRequestHandler,HTTPServer
from pathlib import Path
class Handler(BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_POST(self):
  body=json.loads(self.rfile.read(int(self.headers.get('Content-Length','0'))));path=Path(sys.argv[2])
  with path.open('a') as f:f.write(json.dumps({'path':self.path,'model':body.get('model'),'authenticated':self.headers.get('Authorization','').startswith('Bearer '),'input':body.get('input'),'messages':body.get('messages')})+'\n')
  if self.path.endswith('/chat/completions'):
   result={'choices':[{'finish_reason':'stop','message':{'role':'assistant','content':'Connection confirmed. \\[2+2=4\\]'}}]}
  else:result={'status':'completed','output':[{'type':'message','role':'assistant','content':[{'type':'output_text','text':'Connection confirmed. \\[2+2=4\\]'}]}]}
  data=json.dumps(result).encode();self.send_response(200);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
HTTPServer(('127.0.0.1',int(sys.argv[1])),Handler).serve_forever()
