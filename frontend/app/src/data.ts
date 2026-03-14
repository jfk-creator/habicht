import { Logger } from "./utils";

const userMessage = document.getElementById("status");
const street_name = document.getElementById("street_name");
const street_number = document.getElementById("street_number");
const city_code = document.getElementById("city_code");
const city_name = document.getElementById("city_name");

const logger = new Logger();

function main() {
  const sessionToken = checkToken();
  logger.info("token: " + sessionToken);
  getData(sessionToken);
}

main();

function checkToken(): string | null {
  const token = localStorage.getItem("sessionToken");
  if (!token) {
    logger.err("No sessionToken provided.");
    window.location.replace("http://127.0.0.1:5173/login.html");
  }
  return token;
}

function fillAdress(data) {
  if (!data) console.error("No data provided");
  street_name!.innerText = data.street_name;
  street_number!.innerText = data.street_number;
  city_code!.innerText = data.city_code;
  city_name!.innerText = data.city_name;
}

async function getData(sendToken) {
  const incomingData = { token: sendToken };
  console.log("sending: ", incomingData);
  try {
    const res = await fetch("http://127.0.0.1:8080/api/data", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(incomingData),
    });

    const respData = await res.json();
    if (!res.ok) console.error(respData.err);

    console.log(respData);
    fillAdress(respData.address);
    userMessage!.innerText = "Logged in";
    userMessage!.style.color = "green";
  } catch (error) {
    console.error("Fetch failed:", error);
  }
}
