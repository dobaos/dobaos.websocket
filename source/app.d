/**
  This module provedes simple websocket interface for dobaos backend.
  
  Request should has following structure:
  [<req_id>, <method>, <payload>]
  where
  <req_id> - int or string. So, result with this id will be send to client.
  <method> - string. request method
  <payload> - payload specified for each request type

  Any request should be valid JSON.

  Response will be given
  [<res_id>, <method>, <payload>]
  res_id = req_id
  method = "success" or "error"
  payload depends on request type. in case of error - error code

  Copyright (c) 2020 Vladimir Shabunin

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:
  
  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.
  
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
  **/

import core.thread;
import std.algorithm : remove;
import std.conv;
import std.json;
import std.functional;
import std.process;
import std.stdio;
import std.socket : Socket;

import ws;
import dobaos_client;

struct WsClient {
  Socket sock;
  string addr;
}

class DobaosWs: WsListener {
  WsClient[] clients;
  DobaosClient dobaos;

  this(ushort port) {
    super(port);
    dobaos = new DobaosClient();
    // register listener for broadcasted datapoint values
    void processValue(const JSONValue value) {
      writeln("broadcasted: ", value);
      broadcast("datapoint value", value);
    }
    dobaos.onDatapointValue(toDelegate(&processValue));
  }
  void broadcast(string method, JSONValue payload) {
    auto json2publish = parseJSON("[]");
    json2publish.array.length = 3;
    json2publish.array[0] = JSONValue(-1);
    json2publish.array[1] = JSONValue(method);
    json2publish.array[2] = payload;
    foreach(WsClient ws; clients) {
      sendWsMessage(ws.sock, json2publish.toJSON());
    }
  }

  override void onConnectionOpen(Socket sock, string addr) {
    writeln("New connection: ", addr);
    clients ~= WsClient(sock, addr);
  }
  override void onConnectionClose(Socket sock, string addr) {
    writeln("Disconnected: ", addr);
    for(auto i = 0; i < clients.length; i += 1) {
      auto c = clients[i];
      // remove all subscriptions
      if (c.addr == addr) {
        clients = clients.remove(i);
        i -= 1;
      }
    }
  }
  override void onWsMessage(Socket sock, string addr, string data) {
    JSONValue j;
    try {
      j = parseJSON(data);
    } catch(Exception e) {
      //writeln("error processing message: ", e.message);
    }

    if (j.type() !is JSONType.array) {
      return;
    }
    if (j.array.length < 3) {
      return;
    }
    // each message should be JSON-serialized array
    // [REQ_ID, method, payload]
    auto jreq_id = j.array[0];
    // req_id: integer or string
    if (jreq_id.type() != JSONType.integer
        && jreq_id.type() != JSONType.string) {
      return;
    }
    // method: only string
    auto jmethod = j.array[1];
    if (jmethod.type() != JSONType.string) {
      return;
    }
    // payload of any type
    auto jpayload = j.array[2];

    void sendResponse(JSONValue method, JSONValue payload) {
      auto jres = parseJSON("[]");
      jres.array ~= jreq_id;
      jres.array ~= method;
      jres.array ~= payload;
      sendWsMessage(sock, jres.toJSON());
    }

    // now depends on method
    auto method = jmethod.str;
    auto jresult = dobaos.commonDatapointRequest(method, jpayload);
    sendResponse(jresult["method"], jresult["payload"]);
  }
  void loop() {
    processWebSocket();
    dobaos.processMessages();
  }
}

void main()
{
  writeln("hello, friend");
  ushort port = to!ushort(environment.get("DWS_PORT", "45000"));
  auto server = new DobaosWs(port);
  writeln("listening on port: ", port);
  while (true) {
    server.loop();
    Thread.sleep(1.msecs);
  }
}
