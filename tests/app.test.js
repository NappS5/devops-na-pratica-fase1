const request = require('supertest');
const createApp = require('../src/app');

describe('DevOps Task API', () => {
  let app;

  beforeEach(() => {
    app = createApp();
  });

  test('GET /health retorna 200 e informa que o serviço está funcionando', async () => {
    const res = await request(app).get('/health');

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('status', 'ok');
  });

  test('GET /tasks retorna um array', async () => {
    const res = await request(app).get('/tasks');

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  test('POST /tasks com título válido cria a tarefa com sucesso', async () => {
    const res = await request(app)
      .post('/tasks')
      .send({ title: 'Estudar DevOps', description: 'Ler sobre CI/CD' });

    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('id');
    expect(res.body.title).toBe('Estudar DevOps');
    expect(res.body.description).toBe('Ler sobre CI/CD');
  });

  test('POST /tasks sem título retorna 400 com mensagem clara', async () => {
    const res = await request(app)
      .post('/tasks')
      .send({ description: 'Tarefa sem título' });

    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('error');
    expect(typeof res.body.error).toBe('string');
  });

  test('GET /metrics retorna 200', async () => {
    const res = await request(app).get('/metrics');

    expect(res.status).toBe(200);
  });

  test('GET /metrics retorna conteúdo compatível com o formato do Prometheus', async () => {
    const res = await request(app).get('/metrics');

    expect(res.headers['content-type']).toMatch(/text\/plain/);
    expect(res.text).toContain('# HELP');
    expect(res.text).toContain('# TYPE');
    expect(res.text).toContain('http_requests_total');
    expect(res.text).toContain('http_request_duration_seconds');
  });

  test('Respostas incluem headers de segurança aplicados pelo Helmet', async () => {
    const res = await request(app).get('/health');

    expect(res.headers).toHaveProperty('x-content-type-options', 'nosniff');
    expect(res.headers).toHaveProperty('x-dns-prefetch-control');
  });
});
