module dobaos_client;

import std.base64;
import std.functional;
import std.json;
import std.stdio;
import std.string;
import std.datetime.stopwatch;

import tinyredis;
import tinyredis.subscriber;

class DobaosClient {
  private Redis pub;
  private Subscriber sub;
  private Subscriber sub_cast;
  private string redis_host, req_channel, bcast_channel, service_channel;
  private ushort redis_port;

  private bool res_received = false;
  private string res_pattern = "ddcli_*";

  private string last_channel;
  private JSONValue response;
  
  private int req_timeout;

  this(string redis_host = "127.0.0.1", 
      ushort redis_port = 6379,
      string req_channel = "dobaos_req",
      string bcast_channel = "dobaos_cast",
      string service_channel = "dobaos_service",
      string service_bcast = "dobaos_cast",
      int req_timeout = 5000
      ) {

    this.redis_host = redis_host;
    this.redis_port = redis_port;
    this.req_channel = req_channel;
    this.bcast_channel = bcast_channel;
    this.service_channel = service_channel;
    this.req_timeout = req_timeout;

        // init publisher
    pub = new Redis(redis_host, redis_port);
    // now handle message
    void handleMessage(string pattern, string channel, string message)
    {
      try {
        if (channel != last_channel) {
          return;
        }

        JSONValue jres = parseJSON(message);

        // check if response is object
        if (!jres.type == JSONType.object) {
          return;
        }
        // check if response has method field
        auto jmethod = ("method" in jres);
        if (jmethod is null) {
          return;
        }

        response = jres;
        res_received = true;
      } catch(Exception e) {
        //writeln("error parsing json: %s ", e.msg);
      } 
    }
    sub = new Subscriber(redis_host, redis_port);
    sub.psubscribe(res_pattern, toDelegate(&handleMessage));
  }

  public void onDatapointValue(void delegate(const JSONValue) handler) {
    void handleMessage(string channel, string message)
    {
      try {
        JSONValue jres = parseJSON(message);

        // check if response is object
        if (jres.type() != JSONType.object) {
          return;
        }
        // check if response has method field
        auto jmethod = ("method" in jres);
        if (jmethod is null) {
          return;
        }
        if ((*jmethod).str != "datapoint value") {
          return;
        }

        auto jpayload = ("payload" in jres);
        if (jpayload is null) {
          return;
        }

        handler(*jpayload);
      } catch(Exception e) {
        //writeln("error parsing json: %s ", e.msg);
      } 
    }
    sub_cast = new Subscriber(redis_host, redis_port);
    sub_cast.subscribe(bcast_channel, toDelegate(&handleMessage));
  }

  public void processMessages() {
    sub_cast.processMessages();
  }
  
  public JSONValue commonRequest(string channel, string method, JSONValue payload) {
    res_received = false;
    response = null;
    // replace pattern with unix time?
    last_channel = res_pattern.replace("*", "42");

    JSONValue jreq = parseJSON("{}");
    jreq["method"] = method;
    jreq["payload"] = payload;
    jreq["response_channel"] = last_channel;
    pub.send("PUBLISH", channel, jreq.toJSON());

    auto sw = StopWatch(AutoStart.yes);
    auto dur = sw.peek();
    while(!res_received && dur < msecs(req_timeout)) {
      sub.processMessages();
      dur = sw.peek();
    }

    return response;
  }
  public JSONValue commonDatapointRequest(string method, JSONValue payload) {
    return commonRequest(req_channel, method, payload);
  }
  public JSONValue commonServiceRequest(string method, JSONValue payload) {
    return commonRequest(service_channel, method, payload);
  }
}
