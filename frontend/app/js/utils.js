// src/utils.ts
var APIADDR = "http://127.0.0.1:8080";

class Logger {
  info(msg) {
    console.log("INFO: %s", msg);
  }
  err(msg) {
    console.log("\x1B[31mERROR: %s \x1B[0m", msg);
  }
}
export {
  Logger,
  APIADDR
};
