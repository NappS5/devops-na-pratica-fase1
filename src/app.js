const express = require('express');

function createApp() {
  const app = express();
  app.use(express.json());

  const tasks = [];
  let nextId = 1;

  app.get('/health', (req, res) => {
    res.status(200).json({ status: 'ok', service: 'devops-task-api' });
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
