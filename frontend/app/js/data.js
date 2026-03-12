// src/data.ts
var userMessage = document.getElementById("status");
var street_name = document.getElementById("street_name");
var street_number = document.getElementById("street_number");
var city_code = document.getElementById("city_code");
var city_name = document.getElementById("city_name");
function main() {
  const sessionToken = checkToken();
  if (!sessionToken) {
    console.warn("sessionToken not found: ", sessionToken);
  }
  console.log("sessionToken: ", sessionToken);
  getData(sessionToken);
}
main();
function checkToken() {
  const token = localStorage.getItem("sessionToken");
  if (!token)
    return;
  return token;
}
var AdressData = {
  street_name: "Street Name",
  street_number: "98765",
  city_code: "98765",
  city_name: "City Name"
};
function fillAdress(data) {
  if (!data)
    console.error("No data provided");
  street_name.innerText = data.street_name;
  street_number.innerText = data.street_number;
  city_code.innerText = data.city_code;
  city_name.innerText = data.city_name;
}
fillAdress(AdressData);
async function getData(sendToken) {
  const _package = { token: sendToken };
  console.log("sending: ", _package);
  try {
    const res = await fetch("http://127.0.0.1:8080/api/data", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(_package)
    });
    const respData = await res.json();
    if (!res.ok)
      console.error(respData.err);
    console.log(respData);
    fillAdress(respData);
    userMessage.innerText = "Logged in";
    userMessage.style.color = "green";
  } catch (error) {
    console.error("Fetch failed:", error);
  }
}
