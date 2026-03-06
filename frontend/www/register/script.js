let userInput = document.getElementById("user");
let secretInput = document.getElementById("secret");
let sendButton = document.getElementById("send");
let consoleTab = document.getElementById("console");

const registerFrom = document.getElementById("registerForm");

registerFrom.addEventListener('submit', (event) => {
    event.preventDefault();

    const formData = new FormData(event.target);
    const data = Object.fromEntries(formData.entries());
    console.log(data);
    login(data);

});

async function login(data) {
    try {
        const res = await fetch('http://127.0.0.1:8080/app/register', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify(data)
        });
        //if(!res.ok) console.error("Nope");

        const respData = await res.json();
        if(respData.key) {
            localStorage.setItem('sessionToken', respData.key);
            const token = localStorage.getItem('sessionToken');

            if(token) window.location.replace("http:127.0.0.1:5173/data/index.html"); 
    }
        if(respData.err) consoleTab.innerHTML = respData.err;
        console.log(respData);
    } catch (error) {
        console.error("Fetch failed:", error);
    }
}
