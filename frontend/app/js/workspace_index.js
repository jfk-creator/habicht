// src/utils.ts
var SERVERADDR = "http://127.0.0.1:4040";
class Logger {
  info(msg) {
    console.log("INFO: %s", msg);
  }
  err(msg) {
    console.error("ERROR: %s", msg);
  }
}

// src/workspace_index.ts
var logger = new Logger;
var workspace_ui = {
  user_name: document.getElementById("user_name"),
  street_name: document.getElementById("street_name"),
  street_number: document.getElementById("street_number"),
  city_code: document.getElementById("city_code"),
  city_name: document.getElementById("city_name"),
  invoice_gallery_message: document.getElementById("invoice_gallery_message")
};
function checkUI(elements) {
  let allFound = true;
  for (const [name, element] of Object.entries(elements)) {
    if (!element) {
      logger.err(`UI Element '${name}' not found!`);
      allFound = false;
    }
  }
  return allFound;
}
if (checkUI(workspace_ui)) {
  main();
}
function main() {
  console.log("init workspace");
  const sessionToken = checkToken();
  logger.info("token: " + sessionToken);
  const data = getData(sessionToken);
  if (!data.invoices) {
    workspace_ui.invoice_gallery_message.innerText = "Schreibe jetzt deine erste Rechnung";
    return;
  }
}
function checkToken() {
  const token = localStorage.getItem("sessionToken");
  if (!token) {
    logger.err("No sessionToken provided.");
    window.location.href = SERVERADDR + "/login.html";
  }
  return token;
}
async function getData(sendToken) {
  const incomingData = { token: sendToken };
  console.log("sending: ", incomingData);
  try {
    const res = await fetch("http://127.0.0.1:8080/api/data", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(incomingData)
    });
    const respData = await res.json();
    if (!res.ok)
      console.error(respData.err);
    console.log(respData);
    fillAdress(respData.address);
    if (workspace_ui.user_name)
      workspace_ui.user_name.innerText = respData.user.first_name + " " + respData.user.last_name;
    return respData;
  } catch (error) {
    console.error("Fetch failed:", error);
    return null;
  }
}
function fillAdress(data) {
  if (!data)
    console.error("No data provided");
  workspace_ui.street_name.innerText = data.street_name;
  workspace_ui.street_number.innerText = data.street_number;
  workspace_ui.city_code.innerText = data.city_code;
  workspace_ui.city_name.innerText = data.city_name;
}
