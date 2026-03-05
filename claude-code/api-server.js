const express = require('express');
const { spawn } = require('child_process');
const crypto = require('crypto');
const http = require('http');

const fs = require('fs');

const app = express();
app.use(express.json());

// Write empty MCP config for read-only mode
const EMPTY_MCP_PATH = '/tmp/empty-mcp.json';
fs.writeFileSync(EMPTY_MCP_PATH, '{"mcpServers":{}}');

const PORT = process.env.API_PORT || 8080;
const DEFAULT_MODEL = process.env.DEFAULT_MODEL || 'sonnet';
const SUPERVISOR_TOKEN = process.env.SUPERVISOR_TOKEN || '';

// Read-only tools — can query HA state and read files, no actions
const READ_ONLY_TOOLS = [
  'mcp__homeassistant__GetLiveContext',
  'mcp__homeassistant__GetDateTime',
  'Read',
  'Grep',
  'Glob'
].join(',');

function fireHAEvent(eventType, data) {
  const body = JSON.stringify(data);
  const req = http.request({
    hostname: 'supervisor',
    port: 80,
    path: `/core/api/events/${eventType}`,
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${SUPERVISOR_TOKEN}`,
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(body)
    }
  });
  req.on('error', (err) => console.error('Failed to fire HA event:', err.message));
  req.write(body);
  req.end();
}

function runClaude(prompt, options = {}) {
  return new Promise((resolve, reject) => {
    const {
      model = DEFAULT_MODEL,
      allowActions = false,
      timeout = 60,
      systemPrompt = null
    } = options;

    const args = [
      '-p',
      '--output-format', 'json',
      '--model', model,
      '--dangerously-skip-permissions',
      '--no-session-persistence',
      '--debug-file', '/tmp/claude-debug.log'
    ];

    if (!allowActions) {
      // Read-only: skip MCP to avoid connection delays, only allow file reads
      args.push('--allowedTools', 'Read,Grep,Glob');
      args.push('--strict-mcp-config');
      args.push('--mcp-config', EMPTY_MCP_PATH);
    }

    if (systemPrompt) {
      args.push('--system-prompt', systemPrompt);
    }

    args.push('--');
    args.push(prompt);

    console.log('[claude] spawning:', 'claude', args.join(' '));

    const startTime = Date.now();
    let stdout = '';
    let stderr = '';

    // Remove CLAUDECODE env var entirely to avoid nested session detection
    const env = { ...process.env };
    delete env.CLAUDECODE;

    const proc = spawn('claude', args, {
      cwd: '/config',
      env
    });

    // Handle timeout manually since spawn doesn't support it
    const timer = setTimeout(() => {
      proc.kill('SIGTERM');
    }, timeout * 1000);

    proc.stdout.on('data', (data) => {
      stdout += data.toString();
      console.log('[claude stdout]', data.toString().substring(0, 500));
    });
    proc.stderr.on('data', (data) => {
      stderr += data.toString();
      console.error('[claude stderr]', data.toString().substring(0, 500));
    });

    proc.on('close', (code) => {
      clearTimeout(timer);
      const duration = Date.now() - startTime;
      if (code !== 0) {
        reject(new Error(stderr || stdout || `claude exited with code ${code}`));
      } else {
        let response;
        try {
          const parsed = JSON.parse(stdout);
          response = parsed.result || stdout;
        } catch {
          response = stdout.trim();
        }
        resolve({ response, duration_ms: duration, model });
      }
    });

    proc.on('error', (err) => {
      clearTimeout(timer);
      reject(err);
    });
  });
}

// Health check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    version: '2.2.6',
    api_key_set: !!process.env.ANTHROPIC_API_KEY
  });
});

// Main prompt endpoint
app.post('/api/prompt', async (req, res) => {
  const {
    prompt,
    model,
    async: isAsync = false,
    allow_actions = false,
    timeout = 60,
    system_prompt = null
  } = req.body;

  if (!prompt) {
    return res.status(400).json({ error: 'prompt is required' });
  }


  const requestId = crypto.randomUUID();

  if (isAsync) {
    res.json({ request_id: requestId, status: 'pending' });

    runClaude(prompt, { model, allowActions: allow_actions, timeout, systemPrompt: system_prompt })
      .then((result) => {
        fireHAEvent('claude_code_response', {
          request_id: requestId,
          status: 'completed',
          ...result
        });
      })
      .catch((err) => {
        fireHAEvent('claude_code_response', {
          request_id: requestId,
          status: 'error',
          error: err.message
        });
      });
  } else {
    try {
      const result = await runClaude(prompt, {
        model, allowActions: allow_actions, timeout, systemPrompt: system_prompt
      });
      res.json({ request_id: requestId, status: 'completed', ...result });
    } catch (err) {
      res.status(500).json({ request_id: requestId, status: 'error', error: err.message });
    }
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Claude Code API server listening on port ${PORT}`);
});
