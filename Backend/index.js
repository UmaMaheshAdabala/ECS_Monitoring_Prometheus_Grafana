const express = require("express");
const client = require("prom-client");

const app = express();
const register = new client.Registry();

client.collectDefaultMetrics({ register });

const httpCounter = new client.Counter({
  name: "app_http_requests_total",
  help: "Total HTTP Requests",
  labelNames: ["method", "route", "status"],
});

const httpDuration = new client.Histogram({
  name: "app_http_request_duration_seconds",
  help: "Duration of HTTP requests in seconds",
  labelNames: ["method", "route", "status"],
  buckets: [0.1, 0.3, 0.5, 1, 1.5, 2, 3],
});

register.registerMetric(httpCounter);
register.registerMetric(httpDuration);

app.use((req, res, next) => {
  const end = httpDuration.startTimer();

  res.on("finish", () => {
    httpCounter.inc({
      method: req.method,
      route: req.route?.path || req.path,
      status: res.statusCode.toString(),
    });

    end({
      method: req.method,
      route: req.route?.path || req.path,
      status: res.statusCode.toString(),
    });
  });

  next();
});

app.get("/", (req, res) => {
  res.send("Monitoring Stack Running 🚀");
});

app.get("/error", (req, res) => {
  res.status(500).send("Internal error");
});

app.get("/metrics", async (req, res) => {
  res.set("Content-Type", register.contentType);
  res.end(await register.metrics());
});

app.listen(5000, () => {
  console.log("App running on port 5000");
});
