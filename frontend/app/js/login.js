// src/utils.ts
class Logger {
  info(msg) {
    console.log("INFO: %s", msg);
  }
  err(msg) {
    console.log("\x1B[31mERROR: %s \x1B[0m", msg);
  }
}

// src/login.ts
var userInput = document.getElementById("user");
var secretInput = document.getElementById("secret");
var sendButton = document.getElementById("send");
var logger = new Logger;
if (!sendButton)
  logger.err("sendButton not found!");
if (!userInput)
  logger.err("userInput not found!");
sendButton.addEventListener("click", (event) => {
  if (userInput.value && secretInput.value) {
    console.log(userInput.value);
    console.log(secretInput.value);
    const loginPackage = {
      email: userInput.value,
      secret: secretInput.value
    };
    login(loginPackage);
  }
});
async function login(data) {
  try {
    const res = await fetch("http://127.0.0.1:8080/api/login", {
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
        window.location.replace("http://127.0.0.1:5173/data.html");
    }
  } catch (error) {
    console.error("Fetch failed:", error);
  }
}
