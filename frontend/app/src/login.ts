import { APIADDR, Logger, WORKSPACE_INDEX } from "./utils";

const loginForm = document.getElementById("loginForm");

const logger = new Logger();

if (!loginForm) logger.err("loginForm not found!");

loginForm!.addEventListener("submit", (event) => {
  event.preventDefault();

  if (!event.target) {
    logger.err("no event.target found!");
    return;
  }
  const formData = new FormData(event.target as HTMLFormElement);
  const rawData = Object.fromEntries(formData.entries());
  const data = rawData as unknown as LoginPackage;
  logger.info(data);
  login(data);
});

async function login(data: LoginPackage) {
  try {
    const res = await fetch(APIADDR + "/api/login", {
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

      if (token) window.location.href = WORKSPACE_INDEX;
    }
  } catch (error) {
    console.error("Fetch failed:", error);
  }
}
