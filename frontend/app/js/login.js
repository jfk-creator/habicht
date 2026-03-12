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

// src/login.ts
var loginForm = document.getElementById("loginForm");
var logger = new Logger;
if (!loginForm)
  logger.err("loginForm not found!");
loginForm.addEventListener("submit", (event) => {
  event.preventDefault();
  if (!event.target) {
    logger.err("no event.target found!");
    return;
  }
  const formData = new FormData(event.target);
  const rawData = Object.fromEntries(formData.entries());
  const data = rawData;
  logger.info(data);
  login(data);
});
async function login(data) {
  try {
    const res = await fetch(APIADDR + "/api/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(data)
    });
    if (!res.ok)
      console.error("Nope");
    const respData = await res.json();
    console.log(respData);
    if (respData.token) {
      const oldSession = localStorage.getItem("sessionToken");
      if (oldSession)
        localStorage.clear();
      console.log("respData.token: ", respData.token);
      localStorage.setItem("sessionToken", respData.token);
      const token = localStorage.getItem("sessionToken");
      if (token)
        window.location.href = "data.html";
    }
  } catch (error) {
    console.error("Fetch failed:", error);
  }
}
