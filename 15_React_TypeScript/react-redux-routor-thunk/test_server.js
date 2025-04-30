const express = require('express');
const app = express();
const PORT = 18080;

// Middleware to parse JSON
app.use(express.json());

app.get('/', (req, res) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.json([{id: 1, name: "Test", count: 10}]);
});

// Start the server
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
