// js/workspace_index.js
class Logger {
  info(msg) {
    console.log("INFO: %s", msg);
  }
  err(msg) {
    console.log("\x1B[31mERROR: %s \x1B[0m", msg);
  }
}
var logger = new Logger;
var user_name = document.getElementById("user_name");
var street_name = document.getElementById("street_name");
var street_number = document.getElementById("street_number");
var city_code = document.getElementById("city_code");
var city_name = document.getElementById("city_name");
function main() {
  console.log("init workspace");
  const sessionToken = checkToken();
  logger.info("token: " + sessionToken);
  getData(sessionToken);
}
if (user_name && street_name && street_number && city_code && city_name) {
  main();
} else {
  logger.err(`missing element:
` + `
user_name: ` + user_name + `
street_name:` + street_name + `
street_number: ` + street_number + `
city_code: ` + city_code + `
city_name ` + city_name);
}
function checkToken() {
  const token = localStorage.getItem("sessionToken");
  if (!token) {
    logger.err("No sessionToken provided.");
    window.location.replace("http://127.0.0.1:5173/login.html");
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
      user_name.innerText = "respData.user.first_name";
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
