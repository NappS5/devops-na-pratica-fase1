const express = require('express');
const helmet = require('helmet');
const pinoHttp = require('pino-http');
const { register, metricsMiddleware } = require('./metrics');

function createApp() {
  const app = express();

  app.use(helmet());

  app.use(
    pinoHttp({
      level: process.env.NODE_ENV === 'test' ? 'silent' : process.env.LOG_LEVEL || 'info',
      serializers: {
        req(req) {
          return { method: req.method, url: req.url };
        },
        res(res) {
          return { statusCode: res.statusCode };
        },
      },
    })
  );

  app.use(metricsMiddleware);
  app.use(express.json());

  const tasks = [];
  let nextId = 1;

  app.get('/health', (req, res) => {
    res.status(200).json({ status: 'ok', service: 'devops-task-api' });
  });

  app.get('/metrics', async (req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  });

  app.get('/tasks', (req, res) => {
    res.status(200).json(tasks);
  });

  app.post('/tasks', (req, res) => {
    const { title, description } = req.body || {};

    if (!title || typeof title !== 'string' || !title.trim()) {
      return res.status(400).json({ error: 'O campo "title" é obrigatório.' });
    }

    const task = {
      id: nextId++,
      title: title.trim(),
      description: typeof description === 'string' ? description.trim() : '',
      createdAt: new Date().toISOString(),
    };

    tasks.push(task);
    return res.status(201).json(task);
  });

  return app;
}

module.exports = createApp;
