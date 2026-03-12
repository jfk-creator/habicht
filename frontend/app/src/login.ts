import { Logger } from "./utils";

const userInput = document.getElementById("user") as HTMLInputElement;
const secretInput = document.getElementById("secret") as HTMLInputElement;
const sendButton = document.getElementById("send");

const logger = new Logger();

if (!sendButton) logger.err("sendButton not found!");
if (!userInput) logger.err("userInput not found!");

sendButton!.addEventListener("click", (event) => {
  //TODO: Make it a form
  if (userInput!.value && secretInput!.value) {
    console.log(userInput!.value);
    console.log(secretInput!.value);

    const loginPackage: LoginPackage = {
      email: userInput!.value,
      secret: secretInput!.value,
    };
    login(loginPackage);
  }
});

async function login(data: LoginPackage) {
  try {
    const res = await fetch("http://127.0.0.1:8080/api/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(data),
    });
    //TODO: handle false password and user console.
    if (!res.ok) console.error("Nope");

    const respData = await res.json();
    console.log(respData);
    if (respData.token) {
      const oldSession = localStorage.getItem("sessionToken");
      if (oldSession) localStorage.clear();

      console.log("respData.token: ", respData.token);
      localStorage.setItem("sessionToken", respData.token);

      const token = localStorage.getItem("sessionToken");

      // await sleep(50000);

      if (token) window.location.replace("http://127.0.0.1:5173/data.html");
    }
  } catch (error) {
    console.error("Fetch failed:", error);
  }
}
