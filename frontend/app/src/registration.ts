import { Logger, APIADDR, WORKSPACE_INDEX } from "./utils.ts";
import { registration_t } from "./types";

const logger = new Logger();

logger.info("register init");

const registerForm = document.getElementById("registrationForm");
const errorMsg = document.getElementById("error_message");

if (!registerForm) logger.err("registerForm not found");
if (!errorMsg) logger.err("errorMsg not found");

registerForm!.addEventListener("submit", (event) => {
  event.preventDefault();

  if (!event.target) {
    logger.err("no event.target found!");
    return;
  }
  const formData = new FormData(event.target as HTMLFormElement);
  const rawData = Object.fromEntries(formData.entries());
  const data = rawData as unknown as registration_t;
  logger.info(data);
  registerUser(data);
});

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

async function registerUser(data: registration_t) {
  try {
    const res = await fetch(APIADDR + "/api/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(data),
    });
    if (!res.ok) {
      const serverMsg = await res.json();
      errorMsg!.innerText = "ERROR: " + serverMsg.err;
      return;
    }

    const respData = await res.json();
    if (respData.token) {
      const oldSession = localStorage.getItem("sessionToken");
      if (oldSession) localStorage.clear();

      console.log("respData.token: ", respData.token);
      localStorage.setItem("sessionToken", respData.token);

      const token = localStorage.getItem("sessionToken");

      // await sleep(50000);

      if (token) window.location.href = WORKSPACE_INDEX;
    }
    if (respData.err) errorMsg!.innerText = respData.err;
    console.log(respData);
  } catch (error) {
    console.error("Fetch failed:", error);
  }
}
