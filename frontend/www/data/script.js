const userMessage = document.getElementById("status");
const street_name = document.getElementById("street_name");
const street_number = document.getElementById("street_number");
const city_code = document.getElementById("city_code");
const city_name = document.getElementById("city_name");

function main() {
  const sessionToken = checkToken();
  if (!sessionToken) {
    console.warn("sessionToken not found: ", sessionToken);
    // window.location.replace("http://127.0.0.1:5173/login/index.html");
  }
  console.log("sessionToken: ", sessionToken);
  getData(sessionToken);
}

main();

function checkToken() {
  const token = localStorage.getItem("sessionToken");
  if (!token) return;
  return token;
}

const AdressData = {
  street_name: "Street Name",
  street_number: "98765",
  city_code: "98765",
  city_name: "City Name",
};

function fillAdress(data) {
  if (!data) console.error("No data provided");
  street_name.innerText = data.street_name;
  street_number.innerText = data.street_number;
  city_code.innerText = data.city_code;
  city_name.innerText = data.city_name;
}

fillAdress(AdressData);

async function getData(sendToken) {
  const package = { token: sendToken };
  console.log("sending: ", package);
  try {
    const res = await fetch("http://127.0.0.1:8080/app/data", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(package),
    });

    const respData = await res.json();
    if (!res.ok) console.error(respData.err);

    console.log(respData);
    fillAdress(respData);
    userMessage.innerText = "Logged in";
    userMessage.style.color = "green";
  } catch (error) {
    console.error("Fetch failed:", error);
  }
}
