let userInput = document.getElementById("user");
let secretInput = document.getElementById("secret");
let sendButton = document.getElementById("send");

sendButton.addEventListener("click", (event) => {
  if (userInput.value && secretInput.value) {
    console.log(userInput.value);
    console.log(secretInput.value);

    const package = { user: userInput.value, secret: secretInput.value };
    let count = 0;
    setInterval(() => {
      login(package);
      console.log(count++);
    }, 2);
  }
});

async function login(data) {
  try {
    const res = await fetch("http://127.0.0.1:6969", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(data),
    });
    if (!res.ok) console.error("Nope");

    const respData = await res.json();
    console.log(respData);
  } catch (error) {
    console.error("Fetch failed:", error);
  }
}
