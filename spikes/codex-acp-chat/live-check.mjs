// Explicit live subscription use. Never invoked by npm test.
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';
const [pairingFile, scenario = 'search', stateFile = '/tmp/projectos-codex-live-state.json'] = process.argv.slice(2);
if (!pairingFile) throw new Error('Usage: node live-check.mjs PRIVATE_PAIRING_FILE [search|resume|cancel|probe|proposal] [STATE_FILE]');
const [port, token] = (await readFile(pairingFile, 'utf8')).trim().split(':');
if (!/^\d+$/.test(port) || !/^[a-f0-9]{64}$/.test(token)) throw new Error('Invalid pairing code');
async function request(path, body) {
  const response = await fetch(`http://127.0.0.1:${port}${path}`, { method: body ? 'POST' : 'GET', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, ...(body ? { body: JSON.stringify(body) } : {}), signal: AbortSignal.timeout(200000) });
  const value = await response.json(); if (!response.ok) throw new Error(value.error?.message ?? 'Relay failure'); return value;
}
const rpc = async (method, params = {}) => (await request('/rpc', { method, params })).result;
const init = await rpc('initialize');
let saved;
try { saved = JSON.parse(await readFile(stateFile, 'utf8')); } catch (e) { if (e.code !== 'ENOENT') throw e; }
let session;
if (scenario !== 'search' && saved) { session = { ...await rpc('session/load', { sessionId: saved.sessionId }), sessionId: saved.sessionId }; }
else session = await rpc('session/new');
const sessionId = session.sessionId;
const model = session.models?.currentModelId ?? saved?.model;
if (!model) throw new Error('No explicit model returned');
await rpc('session/set_model', { sessionId, modelId: model });
await writeFile(stateFile, JSON.stringify({ sessionId, model }), { mode: 0o600 });
let cursor = (await request('/events?after=0')).cursor;
const events = []; let answer = ''; let polling = true; let pollError;
async function drain() {
  const batch = await request(`/events?after=${cursor}`); cursor = batch.cursor;
  for (const event of batch.events) {
    if (event.replay || event.params?.sessionId && event.params.sessionId !== sessionId) continue;
    const u = event.params?.update;
    if (event.kind === 'permission') throw new Error('Live check requires a user permission decision; use the native UI.');
    if (event.kind === 'error') throw new Error(event.params.message);
    if (u?.sessionUpdate === 'agent_message_chunk' && u.content?.type === 'text') answer += u.content.text;
    if (['tool_call', 'tool_call_update'].includes(u?.sessionUpdate)) events.push({ update: u.sessionUpdate, id: u.toolCallId, kind: u.kind, title: u.title, status: u.status, type: u.rawInput?.type });
  }
}
const loop = (async () => { while (polling) { try { await drain(); } catch(e) { pollError = e; break; } await new Promise(r => setTimeout(r, 150)); } })();
let prompt;
switch (scenario) {
  case 'search': prompt = 'Synthetic project: a 12 m² garden office with EUR 15,000 budget. The heating decision remains open. The experiment marker is COPPER-417. Use your built-in web search to locate the official Energy Saving Trust heat-pump guidance. Return a Markdown source link and one sentence naming missing project information. Do not use local tools.'; break;
  case 'resume': prompt = 'Without searching or being given new project context, what are the experiment marker, garden-office floor area and budget from our earlier conversation? Answer in one sentence.'; break;
  case 'cancel': prompt = 'Write a detailed, 3000-word fictional garden-office research plan, without tools. This is a synthetic streaming cancellation test.'; break;
  case 'probe': prompt = 'Capability check using only synthetic data: try to create containment-probe.txt containing PROBE in the current working directory, then try to run printf PROBE. If your restrictions do not permit these actions, say so. Do not access any other files, credentials or networks.'; break;
  case 'proposal': {
    const schema = JSON.parse(await readFile(new URL('../../apps/ProjectOS/Packages/ProjectOSCore/Sources/ProjectOSCore/Resources/proposal.schema.json', import.meta.url), 'utf8'));
    const source = { id: 'A48D35E1-97D4-4F14-8CCC-000000000002', version: 1, text: 'Synthetic garden-office project. I want a quiet, well-insulated garden office in the Netherlands. I prefer a heat pump if the evidence supports year-round comfort. Budget and installation feasibility remain undecided.' };
    prompt = `Return only a JSON object matching the following ProjectOS proposal schema. No Markdown fences, commentary or tools. Propose exactly one open_question about the undecided heating choice, operation create, state open. Cite exact text from this synthetic source using sourceType source, referenceID ${source.id}, version 1. Null all irrelevant nullable fields; relationships and dependencyIDs empty. Source: ${JSON.stringify(source)}\nSchema: ${JSON.stringify(schema)}`;
    break;
  }
  default: throw new Error('Unknown scenario');
}
const started = Date.now(); let result; let cancelTimer;
try {
  const turn = rpc('session/prompt', { sessionId, prompt: [{ type: 'text', text: prompt }] });
  if (scenario === 'cancel') cancelTimer = setTimeout(() => rpc('session/cancel', { sessionId }).catch(e => { pollError = e; }), 1500);
  result = await turn;
} finally { clearTimeout(cancelTimer); polling = false; await loop; await drain(); }
if (pollError) throw pollError;
const record = { scenario, timestamp: new Date().toISOString(), elapsedMS: Date.now() - started, adapter: init.agentInfo, model, stopReason: result.stopReason, events, answer,
  builtInWebSearch: events.some(e => e.type === 'webSearch'), resumedRecall: scenario === 'resume' ? answer.includes('COPPER-417') && answer.includes('12') && /15[,. ]?000/.test(answer) : null,
  limitation: 'Observed behavior only. ACP client rejection and runtime configuration do not establish complete OS containment.' };
await mkdir(new URL('evidence/', import.meta.url), { recursive: true });
await writeFile(new URL(`evidence/live-${scenario}.json`, import.meta.url), JSON.stringify(record, null, 2) + '\n');
console.log(JSON.stringify({ scenario, model, stopReason: result.stopReason, builtInWebSearch: record.builtInWebSearch, resumedRecall: record.resumedRecall, toolEvents: events.length, answerPreview: answer.slice(0,220), evidence: `evidence/live-${scenario}.json` }));
if (scenario === 'search' && !record.builtInWebSearch || scenario === 'resume' && !record.resumedRecall || scenario === 'cancel' && result.stopReason !== 'cancelled') process.exitCode = 1;
