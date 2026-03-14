// src/utils.ts
var APIADDR = "http://127.0.0.1:8080";
var SERVERADDR = "http://127.0.0.1:4040";
var WORKSPACE_INDEX = "http://127.0.0.1:4040/workspace/index.html";

class Logger {
  info(msg) {
    console.log("INFO: %s", msg);
  }
  err(msg) {
    console.error("ERROR: %s", msg);
  }
}
export {
  WORKSPACE_INDEX,
  SERVERADDR,
  Logger,
  APIADDR
};
