export class Logger {
  info(msg: any) {
    console.log("INFO: %s", msg);
  }

  err(msg: string) {
    console.log("\x1b[31mERROR: %s \x1b[0m", msg);
  }
}
