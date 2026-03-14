export const APIADDR: string = "http://127.0.0.1:8080";
export const SERVERADDR: string = "http://127.0.0.1:4040";
export const WORKSPACE_INDEX: string =
  "http://127.0.0.1:4040/workspace/index.html";

export class Logger {
  info(msg: any) {
    console.log("INFO: %s", msg);
  }

  err(msg: string) {
    console.error("ERROR: %s", msg);
  }
}
