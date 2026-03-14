// js/workspace_index.js
var SERVERADDR = "http://127.0.0.1:4040";

class Logger {
  info(msg) {
    console.log("INFO: %s", msg);
  }
  err(msg) {
    console.error("ERROR: %s", msg);
  }
}
var logger = new Logger;
var user_name = document.getElementById("user_name");
var street_name = document.getElementById("street_name");
var street_number = document.getElementById("street_number");
var city_code = document.getElementById("city_code");
var city_name = document.getElementById("city_name");
var ui_elements = {
  user_name,
  street_name,
  street_number,
  city_code,
  city_name
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
if (checkUI(ui_elements)) {
  main();
}
function main() {
  console.log("init workspace");
  const sessionToken = checkToken();
  logger.info("token: " + sessionToken);
  getData(sessionToken);
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
    if (user_name)
      user_name.innerText = respData.user.first_name + " " + respData.user.last_name;
  } catch (error) {
    console.error("Fetch failed:", error);
  }
}
function fillAdress(data) {
  if (!data)
    console.error("No data provided");
  street_name.innerText = data.street_name;
  street_number.innerText = data.street_number;
  city_code.innerText = data.city_code;
  city_name.innerText = data.city_name;
}
