const express = require('express');
const app = express();
const PORT = 18080;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function delayedResponse(res, body) {
  await sleep(1000);
  res.json(body);
}

// Middleware to parse JSON
app.use(express.json());

app.get('/', (req, res) => {
  res.header("Access-Control-Allow-Origin", "*");
  numCount = Math.floor(Math.random() * 100 + 1);
  delayedResponse(res, {id: 1, name: "Test", count: numCount});
});

app.get('/userList', (req, res) => {
  res.header("Access-Control-Allow-Origin", "*");
  numCount = Math.floor(Math.random() * 100 + 1);
  delayedResponse(
    res,
    [
      {id: 1, name: "Taro Suzuki"},
      {id: 2, name: "Hanako Tanaka"},
      {id: 3, name: "Jiro Sato"},
      {id: 4, name: "Saburo Yamada"},
      {id: 5, name: "Shiro Watanabe"}
    ]
  );
});

// Start the server
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
