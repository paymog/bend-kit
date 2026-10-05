#include <event2/event.h>
#include <event2/http.h>
#include <event2/buffer.h>
#include <event2/keyvalq_struct.h>
#include <json-c/json.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <time.h>
static struct event_base *base;
static unsigned profile;
static double mono(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec+t.tv_nsec/1e9;}
static void reply(struct evhttp_request *req,int status,const char *type,const void *bytes,size_t n,const char *key,const char *value){
  struct evbuffer *out=evbuffer_new();struct evkeyvalq *headers=evhttp_request_get_output_headers(req);
  if(type)evhttp_add_header(headers,"Content-Type",type);
  if(key)evhttp_add_header(headers,key,value);
  evbuffer_add(out,bytes,n);evhttp_send_reply(req,status,NULL,out);evbuffer_free(out);
}
static void json_id(struct evhttp_request *req,unsigned id){char body[64];int n=snprintf(body,sizeof(body),"{\"id\":%u}",id);reply(req,200,"application/json",body,(size_t)n,NULL,NULL);}
static void handle(struct evhttp_request *req,void *ignored){
  const char *path=evhttp_request_get_uri(req);enum evhttp_cmd_type verb=evhttp_request_get_command(req);
  int post=!strcmp(path,"/decode")||!strcmp(path,"/echo");
  unsigned id=0;char rest=0;int parameter=sscanf(path,"/users/%u%c",&id,&rest)==1;
  unsigned rid=0;int route=sscanf(path,"/route/%u%c",&rid,&rest)==1;
  if(route){char canonical[64];snprintf(canonical,sizeof(canonical),"/route/%u",rid);route=rid<profile&&!strcmp(canonical,path);}
  unsigned hooks=0;int hook_path=!strcmp(path,"/hooks/0")||!strcmp(path,"/hooks/1")||!strcmp(path,"/hooks/5");
  if(!post&&!parameter&&!route&&!hook_path&&strcmp(path,"/text")&&strcmp(path,"/json")){reply(req,404,"text/plain; charset=utf-8","not found",9,NULL,NULL);return;}
  if((post&&verb!=EVHTTP_REQ_POST)||(!post&&verb!=EVHTTP_REQ_GET&&verb!=EVHTTP_REQ_HEAD)){reply(req,405,NULL,"",0,"Allow",post?"OPTIONS, POST":"GET, HEAD, OPTIONS");return;}
  if(parameter||route){json_id(req,parameter?id:rid);return;}
  if(hook_path){unsigned count=(unsigned)atoi(path+7);const char *auth=evhttp_find_header(evhttp_request_get_input_headers(req),"authorization");for(unsigned i=0;i<count;i++){if(!auth||strcmp(auth,"Bearer alice")){reply(req,401,NULL,"",0,"WWW-Authenticate","Bearer");return;}hooks++;}char value[16];snprintf(value,sizeof(value),"%u",hooks);reply(req,200,"application/json","{\"ok\":true}",11,"X-Hook-Count",value);return;}
  if(!strcmp(path,"/text")){reply(req,200,"text/plain; charset=utf-8","OK\n",3,NULL,NULL);return;}
  if(!strcmp(path,"/json")){reply(req,200,"application/json","{\"ok\":true}",11,NULL,NULL);return;}
  struct evbuffer *input=evhttp_request_get_input_buffer(req);
  if(!strcmp(path,"/echo")){
    struct evbuffer *out=evbuffer_new();
    evhttp_add_header(evhttp_request_get_output_headers(req),"Content-Type","application/octet-stream");
    if(evbuffer_add_buffer(out,input))abort();
    evhttp_send_reply(req,200,NULL,out);evbuffer_free(out);return;
  }
  size_t n=evbuffer_get_length(input);unsigned char *bytes=evbuffer_pullup(input,-1);
  const char *media=evhttp_find_header(evhttp_request_get_input_headers(req),"content-type");
  if(!media||strcmp(media,"application/json")){reply(req,415,"text/plain; charset=utf-8","invalid name",12,NULL,NULL);return;}
  struct json_tokener *tok=json_tokener_new_ex(64);json_tokener_set_flags(tok,JSON_TOKENER_STRICT|JSON_TOKENER_VALIDATE_UTF8);
  struct json_object *value=json_tokener_parse_ex(tok,(char*)bytes,(int)n),*name=NULL;
  int valid=json_tokener_get_error(tok)==json_tokener_success&&value&&json_object_is_type(value,json_type_object)&&json_object_object_length(value)==1&&json_object_object_get_ex(value,"name",&name)&&json_object_is_type(name,json_type_string)&&json_object_get_string_len(name)>0&&json_object_get_string_len(name)<=100;
  if(valid){const char *body=json_object_to_json_string_ext(value,JSON_C_TO_STRING_PLAIN);reply(req,200,"application/json",body,strlen(body),NULL,NULL);}else reply(req,400,"text/plain; charset=utf-8","invalid name",12,NULL,NULL);
  if(value)json_object_put(value);json_tokener_free(tok);
}
static void stop(evutil_socket_t signal,short what,void *arg){event_base_loopexit(base,NULL);}
int main(int argc,char **argv){
  if(argc!=3)return 2;
  profile=(unsigned)strtoul(argv[1],NULL,10);
  unsigned port=(unsigned)strtoul(argv[2],NULL,10);
  double start=mono();
  base=event_base_new();
  struct evhttp *http=evhttp_new(base);
  evhttp_set_max_body_size(http,8388608);
  evhttp_set_max_headers_size(http,65536);
  evhttp_set_allowed_methods(http,EVHTTP_REQ_GET|EVHTTP_REQ_POST|EVHTTP_REQ_HEAD|EVHTTP_REQ_OPTIONS);
  for(unsigned id=0;id<profile;id++){
    char path[64];snprintf(path,sizeof(path),"/route/%u",id);
    if(evhttp_set_cb(http,path,handle,NULL))return 4;
  }
  if(!profile)for(const char **p=(const char*[]){"/text","/json","/decode","/echo","/hooks/0","/hooks/1","/hooks/5",NULL};*p;p++){
    if(evhttp_set_cb(http,*p,handle,NULL))return 4;
  }
  evhttp_set_gencb(http,handle,NULL);
  if(evhttp_bind_socket(http,"127.0.0.1",(unsigned short)port))return 3;
  struct event *sig=evsignal_new(base,SIGTERM,stop,NULL);
  event_add(sig,NULL);
  printf("CONSTRUCTION_MS %.6f\nREADY\n",(mono()-start)*1000);fflush(stdout);
  event_base_dispatch(base);
  event_free(sig);evhttp_free(http);event_base_free(base);
  puts("JOINED");return 0;
}
