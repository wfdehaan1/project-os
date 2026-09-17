import test from 'node:test';
import assert from 'node:assert/strict';
import { PassThrough } from 'node:stream';
import { EventEmitter } from 'node:events';
import { ACPProcess, createRelay, runtimeEnvironment } from '../relay.mjs';

function fixture(options = {}) {
  const child = new EventEmitter(); child.stdin = new PassThrough(); child.stdout = new PassThrough(); child.stderr = new PassThrough(); child.kill = () => {};
  const sent = []; let buffered = '';
  child.stdin.on('data', data => { buffered += data; while (buffered.includes('\n')) { const p = buffered.indexOf('\n'); sent.push(JSON.parse(buffered.slice(0, p))); buffered = buffered.slice(p + 1); } });
  const agent = new ACPProcess(child, { cwd: '/synthetic', timeout: 1000, ...options });
  function reply(result) { agent.receive({ id: sent.at(-1).id, result }); }
  async function init() { const p = agent.rpc('initialize'); reply({ protocolVersion: 1 }); await p; }
  async function session() { const p = agent.rpc('session/new', { cwd: '/real-project', mcpServers: [{ name: 'bad' }], model: 'other' }); reply({ sessionId: 'owned' }); await p; }
  return { child, sent, agent, reply, init, session };
}

test('owned session setup strips caller cwd, MCP and configuration; rejects escalation', async () => {
  const f = fixture(); await f.init(); await f.session();
  assert.deepEqual(f.sent.at(-1).params, { cwd: '/synthetic', mcpServers: [] });
  await assert.rejects(f.agent.rpc('session/load', { sessionId: 'not-ours' }), /Only sessions/);
  await assert.rejects(f.agent.rpc('session/set_config_option', { sessionId: 'owned', configId: 'mode', value: 'agent-full-access' }), /does not permit/);
  await assert.rejects(f.agent.rpc('authenticate', { methodId: 'api-key', apiKey: 'never-forward' }), /ChatGPT/);
  f.agent.stop();
});

test('split Unicode frames survive; old events fail explicitly after overflow', async () => {
  const f = fixture({ maxEvents: 2 }); await f.init(); await f.session();
  const frame = Buffer.from(JSON.stringify({ method: 'session/update', params: { sessionId: 'owned', update: { text: 'café 🪴' } } }) + '\n');
  for (const byte of frame) f.child.stdout.write(Buffer.from([byte]));
  assert.equal(f.agent.readEvents(0).events[0].params.update.text, 'café 🪴');
  f.agent.emit({ kind: 'notification' }); f.agent.emit({ kind: 'notification' });
  assert.throws(() => f.agent.readEvents(0), /overflow/); f.agent.stop();
});

test('permission choices are exact; stop rejects subsequent approvals and bars overlap until terminal response', async () => {
  const f = fixture(); await f.init(); await f.session();
  const turn = f.agent.rpc('session/prompt', { sessionId: 'owned', prompt: [{ type: 'text', text: 'Research' }] });
  const turnID = f.sent.at(-1).id;
  const request = { id: 99, method: 'session/request_permission', params: { sessionId: 'owned', toolCall: { kind: 'fetch' }, options: [{ optionId: 'once', kind: 'allow_once' }, { optionId: 'forever', kind: 'allow_always' }] } };
  f.agent.receive(request); assert.throws(() => f.agent.permission('99', 'forever')); assert.throws(() => f.agent.permission('99', 'invented'));
  await f.agent.rpc('session/cancel', { sessionId: 'owned' });
  assert.throws(() => f.agent.permission('99', 'once'), /expired/);
  f.agent.receive({ ...request, id: 100 }); assert.equal(f.sent.at(-1).result.outcome.outcome, 'cancelled');
  await assert.rejects(f.agent.rpc('session/prompt', { sessionId: 'owned', prompt: [{ type: 'text', text: 'Overlap' }] }), /running/);
  f.agent.receive({ id: turnID, result: { stopReason: 'cancelled' } }); await turn; f.agent.stop();
});

test('replay is marked; file/terminal requests are refused', async () => {
  const f = fixture({ ownedSessions: ['saved'] }); await f.init();
  const load = f.agent.rpc('session/load', { sessionId: 'saved' });
  f.agent.receive({ method: 'session/update', params: { sessionId: 'saved', update: { sessionUpdate: 'agent_message_chunk' } } });
  assert.equal(f.agent.readEvents(0).events[0].replay, true); f.reply({}); await load;
  f.agent.receive({ id: 12, method: 'fs/read_text_file', params: { path: '/secret' } });
  assert.equal(f.sent.at(-1).error.code, -32601); f.agent.stop();
});

test('adapter failure rejects in-flight work without replay', async () => {
  const f = fixture(); await f.init(); await f.session();
  const turn = f.agent.rpc('session/prompt', { sessionId: 'owned', prompt: [{ type: 'text', text: 'Hi' }] });
  f.child.emit('exit', 1); await assert.rejects(turn, /exited/);
  await assert.rejects(f.agent.rpc('session/prompt', {}), /disconnected/);
});

test('environment contains no API key or inherited agent override', () => {
  const e = runtimeEnvironment('/codex'); const c = JSON.parse(e.CODEX_CONFIG);
  assert.equal(e.OPENAI_API_KEY, undefined); assert.equal(e.CODEX_API_KEY, undefined); assert.equal(e.CODEX_HOME, undefined);
  assert.equal(c.forced_login_method, 'chatgpt'); assert.equal(c.web_search, 'live'); assert.equal(c.features.shell_tool, false); assert.equal(c.features.memories, false);
});

test('loopback HTTP rejects unauthenticated and browser-origin requests; preserves split UTF-8', async t => {
  const calls = []; const agent = { rpc: async (method, params) => { calls.push({ method, params }); return params; }, readEvents: () => ({ events: [], cursor: 0 }) };
  const { server } = createRelay(agent, 'test-token');
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve)); t.after(() => server.close());
  const url = `http://127.0.0.1:${server.address().port}`;
  assert.equal((await fetch(url + '/events')).status, 401);
  assert.equal((await fetch(url + '/events', { headers: { Authorization: 'Bearer test-token', Origin: 'https://example.com' } })).status, 401);
  const response = await fetch(url + '/rpc', { method: 'POST', headers: { Authorization: 'Bearer test-token' }, body: JSON.stringify({ method: 'initialize', params: { text: 'café 🪴' } }) });
  assert.equal((await response.json()).result.text, 'café 🪴'); assert.equal(calls.length, 1);
});

// A new native connection can establish a baseline after bounded history eviction.
test('latest event cursor skips old events without overflowing', () => {
  const agent = Object.create(ACPProcess.prototype);
  agent.events = [{seq: 99}]; agent.seq = 99;
  assert.throws(() => agent.readEvents(0), /overflow/);
  assert.deepEqual(agent.readEvents('latest'), {events: [], cursor: 99});
  agent.dead = true;
  assert.throws(() => agent.readEvents('latest'), /disconnected/);
});
