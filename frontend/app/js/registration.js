// src/utils.ts
var APIADDR = "http://127.0.0.1:8080";
var WORKSPACE_INDEX = "http://127.0.0.1:4040/workspace/index.html";

class Logger {
  info(msg) {
    console.log("INFO: %s", msg);
  }
  err(msg) {
    console.log("\x1B[31mERROR: %s \x1B[0m", msg);
  }
}

// src/registration.ts
var logger = new Logger;
logger.info("register init");
var registerForm = document.getElementById("registrationForm");
var errorMsg = document.getElementById("error_message");
if (!registerForm)
  logger.err("registerForm not found");
if (!errorMsg)
  logger.err("errorMsg not found");
registerForm.addEventListener("submit", (event) => {
  event.preventDefault();
  if (!event.target) {
    logger.err("no event.target found!");
    return;
  }
  const formData = new FormData(event.target);
  const rawData = Object.fromEntries(formData.entries());
  const data = rawData;
  logger.info(data);
  registerUser(data);
});
async function registerUser(data) {
  try {
    const res = await fetch(APIADDR + "/api/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(data)
    });
    if (!res.ok) {
      const serverMsg = await res.json();
      errorMsg.innerText = "ERROR: " + serverMsg.err;
      return;
    }
    const respData = await res.json();
    if (respData.token) {
      const oldSession = localStorage.getItem("sessionToken");
      if (oldSession)
        localStorage.clear();
      console.log("respData.token: ", respData.token);
      localStorage.setItem("sessionToken", respData.token);
      const token = localStorage.getItem("sessionToken");
      if (token)
        window.location.href = WORKSPACE_INDEX;
    }
    if (respData.err)
      errorMsg.innerText = respData.err;
    console.log(respData);
  } catch (error) {
    console.error("Fetch failed:", error);
  }
}
