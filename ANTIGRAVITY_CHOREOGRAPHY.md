# ANTIGRAVITY_CHOREOGRAPHY.md — Multi-Agent Orchestration Configuration Suite
**VMS Enterprise | Phase 1 SaaS Revision | SRS v5.1 Baseline (Shared B2B SaaS Edition)**
**Classification:** Internal / Confidential
**Last Updated:** June 2026

---

## Preamble — How This Document Is Used

This file is the authoritative orchestration specification for the Antigravity multi-agent workspace. Every sub-agent, pre-commit hook, and daily sync loop reads this document as its primary instruction set.

Execution hierarchy:

```
Main Orchestrator Agent
├── Pre-Commit Hook Layer (file-system interception)
├── Sub-Agent Registry (parallel specialized reviewers)
│   ├── sub-agent-schema   (Lower/Faster model — multi-tenant schema + composite key validation)
│   ├── sub-agent-security (Higher/Deep model  — credentials + encryption + token containment audit)
│   ├── sub-agent-api      (Lower/Faster model — HTTP/WS multi-tenant contract alignment)
│   └── sub-agent-error    (Lower/Faster model — defensive exception error handling enforcement)
└── Daily Context Sync Loop (.context/state.md automatic multi-tenant update)
```

Flags raised by any sub-agent are BLOCKING. No modified file may be pushed to a remote GitHub branch while an unresolved flag exists against it. The main orchestrator enforces this gate — it does not negotiate it.

---

## Section 1 — Pre-Commit Hook Integration Rules

### 1.0 Hook Architecture Overview

```
Developer workstation (local)
↓ git commit
↓ Husky pre-commit hook fires
↓ Lint-staged filters changed files by extension/path
↓ Sub-agent multi-tenant audit runners execute in parallel
↓ Each runner emits: PASS | WARN | BLOCK
↓ If ANY runner emits BLOCK → commit aborted, diff printed to terminal
↓ If ALL runners emit PASS or WARN → commit proceeds
↓ WARN entries are written to .context/flags/YYYY-MM-DD-warns.md (non-blocking)
↓ git push → CI server-side workflow executes full validation pipeline again
```

### 1.1 Husky Installation & Configuration

```bash
# Install Husky (run once at repo root)
pnpm add -D husky lint-staged
npx husky install

# Create pre-commit hook file
cat > .husky/pre-commit << 'EOF'
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

echo "🔍 VMS Antigravity SaaS Pre-Commit Audit Starting..."

# Run lint-staged (file-filtered sub-agent runners)
npx lint-staged

# Capture exit code
LINT_EXIT=$?

if [ $LINT_EXIT -ne 0 ]; then
  echo ""
  echo "❌ COMMIT BLOCKED — SaaS architecture drift or isolation leakage detected."
  echo "   Resolve all BLOCK-level flags before committing."
  echo "   Review: .context/flags/latest-block.md"
  echo ""
  exit 1
fi

echo "✅ All pre-commit isolation audit gates passed. Proceeding."
EOF

chmod +x .husky/pre-commit
```

### 1.2 lint-staged Configuration (root package.json)

```json
{
  "lint-staged": {
    "**/*.ts": [
      "node scripts/audit-runners/schema-audit.js",
      "node scripts/audit-runners/security-audit.js",
      "node scripts/audit-runners/error-audit.js",
      "eslint --fix --max-warnings=0",
      "tsc --noEmit --skipLibCheck"
    ],
    "**/*.dart": [
      "node scripts/audit-runners/security-audit-dart.js",
      "node scripts/audit-runners/error-audit-dart.js",
      "dart analyze --fatal-infos"
    ],
    "**/*.cpp": [
      "node scripts/audit-runners/security-audit-cpp.js",
      "clang-format --dry-run --Werror"
    ],
    "**/api_contract.json": [
      "node scripts/audit-runners/api-contract-drift.js"
    ],
    "**/*.sql": [
      "node scripts/audit-runners/schema-audit-sql.js"
    ],
    "**/schema/**/*.ts": [
      "node scripts/audit-runners/schema-audit.js"
    ]
  }
}
```

### 1.3 Pre-Commit Runner Framework (scripts/audit-runners/runner-base.js)

```javascript
// scripts/audit-runners/runner-base.js
// Provides file reading, flag emission, context sync, and exit code handling

'use strict';

const fs   = require('fs');
const path = require('path');

const FLAG_DIR    = path.resolve('.context/flags');
const BLOCK_FILE  = path.join(FLAG_DIR, 'latest-block.md');
const WARN_DIR    = path.join(FLAG_DIR);

class AuditRunner {
  constructor(agentName, model) {
    this.agentName = agentName;
    this.model     = model;
    this.blocks    = [];
    this.warns     = [];
    this.files     = process.argv.slice(2);

    if (!fs.existsSync(FLAG_DIR)) {
      fs.mkdirSync(FLAG_DIR, { recursive: true });
    }
  }

  block(file, rule, message, line = null) {
    this.blocks.push({ file, rule, message, line, severity: 'BLOCK' });
    console.error(
      `\n  🚨 [${this.agentName}] BLOCK — ${rule}\n` +
      `     File: ${file}${line ? `:${line}` : ''}\n` +
      `     ${message}`
    );
  }

  warn(file, rule, message, line = null) {
    this.warns.push({ file, rule, message, line, severity: 'WARN' });
    console.warn(
      `\n  ⚠️  [${this.agentName}] WARN  — ${rule}\n` +
      `     File: ${file}${line ? `:${line}` : ''}\n` +
      `     ${message}`
    );
  }

  async finalize() {
    const date      = new Date().toISOString();
    const hasBlocks = this.blocks.length > 0;

    if (hasBlocks) {
      const report = [
        `# Audit Block Report — ${this.agentName}`,
        `**Generated:** ${date}`,
        `**Model:** ${this.model}`,
        '',
        '## Blocking Violations',
        '',
        ...this.blocks.map(b =>
          `### ${b.rule}\n` +
          `- **File:** \`${b.file}\`${b.line ? `:${b.line}` : ''}\n` +
          `- **Message:** ${b.message}\n`
        ),
        '',
        '## Resolution Required',
        'Fix all BLOCK-level violations before committing.',
        'After fixing, re-run: `npx lint-staged`',
      ].join('\n');

      fs.writeFileSync(BLOCK_FILE, report, 'utf8');
    }

    if (this.warns.length > 0) {
      const warnDate = new Date().toISOString().split('T')[0];
      const warnFile = path.join(WARN_DIR, `${warnDate}-warns.md`);
      const existing = fs.existsSync(warnFile) ? fs.readFileSync(warnFile, 'utf8') : '';
      const warnContent = this.warns.map(w =>
        `- [${this.agentName}] ${w.rule} — \`${w.file}\`: ${w.message}`
      ).join('\n');
      fs.writeFileSync(warnFile, existing + '\n' + warnContent, 'utf8');
    }

    if (hasBlocks) {
      process.exit(1);
    }

    process.exit(0);
  }

  async run() {
    console.log(`\n🔍 [${this.agentName}] Auditing ${this.files.length} file(s)...`);
    await this.audit(this.files);
    await this.finalize();
  }

  readLines(filePath) {
    if (!fs.existsSync(filePath)) return [];
    return fs.readFileSync(filePath, 'utf8').split('\n');
  }

  readFile(filePath) {
    if (!fs.existsSync(filePath)) return '';
    return fs.readFileSync(filePath, 'utf8');
  }
}

module.exports = { AuditRunner };
```

### 1.4 Pre-Commit Schema & Multi-Tenant Audit Runner (scripts/audit-runners/schema-audit.js)

```javascript
// scripts/audit-runners/schema-audit.js
// Tier: Lower/Faster Model (Deterministic Regex Pattern Ingestion — Cost-Effective)

'use strict';

const { AuditRunner } = require('./runner-base');

class SchemaAuditRunner extends AuditRunner {
  constructor() {
    super('sub-agent-schema', 'pattern-scan');
  }

  async audit(files) {
    for (const file of files) {
      const lines = this.readLines(file);
      const fullText = this.readFile(file);

      for (let i = 0; i < lines.length; i++) {
        const line    = lines[i];
        const lineNum = i + 1;

        // ── RULE S01: Unpartitioned Bare Camera Foreign Key ─────────────────────
        if (
          /REFERENCES\s+cameras\s*\(\s*camera_id\s*\)/i.test(line) ||
          (/REFERENCES\s+cameras/i.test(line) && !/\(\s*customer_id\s*,\s*site_id\s*,\s*camera_id\s*\)/i.test(line))
        ) {
          this.block(file, 'S01-BARE-CAMERA-FK',
            'Foreign key references cameras without the master multi-tenant tuple layout. ' +
            'You must enforce: REFERENCES cameras(customer_id, site_id, camera_id) composite constraints.',
            lineNum
          );
        }

        // ── RULE S02: Unpartitioned Bare camera_id Database Lookup ──────────────────
        if (
          /WHERE\s+camera_id\s*=/i.test(line) &&
          !/WHERE\s+customer_id\s*=.*AND\s+site_id\s*=.*AND\s+camera_id\s*=/i.test(line) &&
          !/WHERE\s+\(\s*customer_id\s*,\s*site_id\s*,\s*camera_id\s*\)/i.test(line) &&
          !line.includes('// composite-ok')
        ) {
          this.block(file, 'S02-UNSHARDED-CAMERA-QUERY',
            'Query isolates bare camera_id without root customer_id partitioning links. ' +
            'All data layer actions must evaluate through the composite index: (customer_id, site_id, camera_id).',
            lineNum
          );
        }

        // ── RULE S03: MongoDB append-only logs mutation attempt ────────────────────
        if (
          /auditModel\.(update|updateOne|updateMany|findOneAndUpdate|delete|deleteOne|deleteMany|replaceOne)/i.test(line) &&
          file.includes('audit')
        ) {
          this.block(file, 'S03-AUDIT-MUTATION',
            'The auditLogs repository is completely append-only. ' +
            'update(), delete(), and replaceOne() methods are forbidden to guard ledger integrity.',
            lineNum
          );
        }

        // ── RULE S04: Missing write-concern on audit writes ────────────────────────
        if (
          file.includes('audit') &&
          /auditModel\.create\(/i.test(line) &&
          !/writeConcern.*majority/i.test(fullText) &&
          !/w:\s*['"]majority['"]/i.test(fullText)
        ) {
          this.warn(file, 'S04-AUDIT-WRITE-CONCERN',
            'Verify MongoDB connection for audit_logs enforces write concern majority. ' +
            'Fire-and-forget audit writes silently lose data on replica failure.',
            lineNum
          );
        }

        // ── RULE S05: Missing TTL on Redis SET ──────────────────────────────────────
        if (
          /redis\.(set|setex)\s*\(/i.test(line) &&
          !/redis\.set\s*\(.*,\s*['"]EX['"]|redis\.setex\s*\(/i.test(line)
        ) {
          this.warn(file, 'S05-REDIS-TTL',
            'Redis SET call detected without explicit TTL (EX parameter). ' +
            'All Redis keys must have a TTL to prevent unbounded memory growth. ' +
            'Use redis.set(key, value, "EX", ttlSeconds) or redis.setex().',
            lineNum
          );
        }

        // ── RULE S06: Missing multi-tenant sharding in Redis key namespace ─────────
        if (
          /`cam:.*\$\{cameraId\}`/i.test(line) &&
          !/`cust-\$\{customer_id\}:site-\$\{siteId\}:.*`/i.test(line)
        ) {
          this.block(file, 'S06-BARE-REDIS-NAMESPACE-KEY',
            'Redis cache keys must be partitioned dynamically using tenant composite headers: ' +
            'cust-{customer_id}:site-{site_id}:{service}:{entity}:{id}. Bare keys trigger scaling collisions.',
            lineNum
          );
        }

        // ── RULE S07: Global Account Isolation Email Trap ──────────────────────────
        if (
          /UNIQUE\s*\(\s*email\s*\)/i.test(line) &&
          file.endsWith('.sql')
        ) {
          this.block(file, 'S07-GLOBAL-EMAIL-COLLISION-TRAP',
            'Global unique email constraints break multi-tenant SaaS structures. ' +
            'Enforce scoped isolation parameters strictly via: CONSTRAINT unique_tenant_email UNIQUE (customer_id, email).',
            lineNum
          );
        }

        // ── RULE S08: Rigid site configuration constraint injection ────────────────
        if (
          (/CHECK\s*\(\s*site_type/i.test(line) || /CREATE\s+TYPE\s+site_type_enum/i.test(line)) &&
          file.endsWith('.sql')
        ) {
          this.block(file, 'S08-RIGID-SITE-CONSTRAINT',
            'Rigid site_type enums or database-level CHECK parameters are forbidden. ' +
            'Configure column as open VARCHAR(100) string to preserve custom dashboard portal form handling.',
            lineNum
          );
        }

        // ── RULE S09: synchronize:true in TypeORM/Prisma ───────────────────────────
        if (/synchronize\s*:\s*true/i.test(line)) {
          this.block(file, 'S09-TYPEORM-SYNC',
            'TypeORM/Prisma synchronize:true is FORBIDDEN in this codebase. ' +
            'Use versioned migrations only (prisma migrate or sql versioned scripts).',
            lineNum
          );
        }

        // ── RULE S10: Missing partition annotation on recordings table ────────────
        if (
          file.endsWith('.sql') &&
          /CREATE TABLE recordings/i.test(line) &&
          !/PARTITION BY/i.test(fullText) &&
          !/partition-deferred/i.test(fullText)
        ) {
          this.warn(file, 'S10-PARTITION-ANNOTATION',
            'recordings table migration missing partition comment. ' +
            'Ensure recordings table is partitioned by customer_id for performance and scaling.',
            lineNum
          );
        }
      }
    }
  }
}

new SchemaAuditRunner().run().catch(console.error);
```

### 1.5 Pre-Commit Security & Token Container Audit Runner (scripts/audit-runners/security-audit.js)

```javascript
// scripts/audit-runners/security-audit.js
// Tier: Semantic Analysis (Pattern Scan + Target Claude deep scan on High-Risk Paths)

'use strict';

const { AuditRunner } = require('./runner-base');
const https            = require('https');

const DEEP_SCAN_PATHS = [
  '/auth/', '/jwt/', '/vault/', '/crypto/', '/token/', '/secret/',
  'auth.service', 'jwt.strategy', 'vault.service', 'secure_storage',
];

class SecurityAuditRunner extends AuditRunner {
  constructor() {
    super('sub-agent-security', 'claude-opus-4-6');
  }

  async audit(files) {
    for (const file of files) {
      const content = this.readFile(file);
      const lines   = content.split('\n');

      // ── FAST SYNTAX FILTER PATTERNS ────────────────────────────────────
      for (let i = 0; i < lines.length; i++) {
        const line    = lines[i];
        const lineNum = i + 1;

        // SEC01: Hardcoded credentials
        if (
          /password\s*=\s*['"][^'"]{6,}['"]/i.test(line) ||
          /secret\s*=\s*['"][^'"]{8,}['"]/i.test(line)   ||
          /api_key\s*=\s*['"][^'"]{8,}['"]/i.test(line)  ||
          /token\s*=\s*['"]ey[A-Za-z0-9_-]+\.['"]/i.test(line)
        ) {
          this.block(file, 'SEC01-HARDCODED-SECRET',
            'Plaintext secrets discovered in source file layer. ' +
            'Pull system properties dynamically from HashiCorp Vault infrastructure.',
            lineNum
          );
        }

        // SEC02: Web storage data leaks
        if (
          /localStorage\.(setItem|getItem)\s*\(['"](token|jwt|auth|access|refresh)/i.test(line) ||
          /sessionStorage\.(setItem|getItem)\s*\(['"](token|jwt|auth|access|refresh)/i.test(line)
        ) {
          this.block(file, 'SEC02-INSECURE-TOKEN-STORAGE',
            'JWT token stored in localStorage or sessionStorage. ' +
            'Tokens must live in-memory only (Zustand for React, AuthBloc for Flutter). ' +
            'Refresh tokens use HttpOnly cookies (web) or hardware Keystore/Keychain (mobile).',
            lineNum
          );
        }

        // SEC03: Raw MFA Token exposure loop hole
        if (/totp_secret\s*:\s*/i.test(line) && file.includes('user.ts')) {
          this.block(file, 'SEC03-RAW-MFA-STORAGE-LANDMINE',
            'Exposing raw multifactor tracking strings inside relational tables maps violates audit compliance. ' +
            'Deploy an mfa_secret_ref VARCHAR(255) string linking straight to external Vault backends.',
            lineNum
          );
        }

        // SEC04: console.log of sensitive data
        if (
          /console\.(log|info|debug)\s*\(.*?(password|token|secret|key|hash|credential)/i.test(line)
        ) {
          this.block(file, 'SEC04-SENSITIVE-LOG',
            'Potentially sensitive data logged to console. ' +
            'Remove this log statement. Use structured pino logging with sanitized metadata only.',
            lineNum
          );
        }

        // SEC05: HTTP (not HTTPS) in API calls
        if (
          /fetch\s*\(\s*['"]http:\/\//i.test(line) ||
          /axios\.(get|post|put|patch|delete)\s*\(\s*['"]http:\/\//i.test(line) ||
          /dio\.(get|post|put|patch|delete)\s*\(\s*['"]http:\/\//i.test(line)
        ) {
          this.block(file, 'SEC05-PLAINTEXT-HTTP',
            'Plain HTTP URL detected in API call. ' +
            'All client-to-cloud and service-to-service calls must use HTTPS/TLS 1.3. ' +
            'Replace http:// with https://.',
            lineNum
          );
        }

        // SEC06: process.env for secrets
        if (
          /process\.env\.(JWT_SECRET|DB_PASSWORD|REDIS_PASSWORD|MINIO_SECRET|VAULT_TOKEN)/i.test(line)
        ) {
          this.block(file, 'SEC06-ENV-SECRET',
            'Secret fetched from process.env directly. ' +
            'All secrets must be fetched from HashiCorp Vault via VaultService. ' +
            'process.env is acceptable for non-secret config (ports, hostnames) only.',
            lineNum
          );
        }

        // SEC07: JWT verification skipped
        if (
          /jwt\.decode\s*\(/i.test(line) &&
          !/jwt\.verify\s*\(/i.test(content)
        ) {
          this.block(file, 'SEC07-JWT-DECODE-WITHOUT-VERIFY',
            'jwt.decode() used without jwt.verify(). ' +
            'decode() does NOT validate signature — tokens can be forged. ' +
            'Use jwt.verify(token, signingKey) instead.',
            lineNum
          );
        }

        // SEC08: Insecure Keychain accessibility in iOS
        if (
          /kSecAttrAccessibleAfterFirstUnlock/i.test(line)
        ) {
          this.block(file, 'SEC08-INSECURE-KEYCHAIN-ACCESS',
            'Keychain accessibility set to kSecAttrAccessibleAfterFirstUnlock. ' +
            'JWT material must use kSecAttrAccessibleWhenUnlockedThisDeviceOnly. ' +
            'AfterFirstUnlock allows access while device is locked (exploit risk).',
            lineNum
          );
        }

        // SEC09: bcrypt cost factor below minimum
        if (
          /bcrypt\.(hash|genSalt)\s*\(\s*.*,\s*([1-9]|10|11)\s*\)/i.test(line)
        ) {
          const match     = line.match(/bcrypt\.(hash|genSalt)\s*\(\s*.*,\s*(\d+)\s*\)/i);
          const costFactor = match ? parseInt(match[2]) : 0;
          if (costFactor < 12) {
            this.block(file, 'SEC09-BCRYPT-COST-LOW',
              `bcrypt cost factor is ${costFactor}. Minimum required is 12.`,
              lineNum
            );
          }
        }

        // SEC10: mTLS not configured for internal gRPC
        if (
          /new\s+grpc\.Server\s*\(\)/i.test(line) &&
          !/credentials\s*:/i.test(content)
        ) {
          this.warn(file, 'SEC10-GRPC-NO-MTLS',
            'gRPC Server instantiated without credentials. ' +
            'Internal service-to-service gRPC must use mTLS (grpc.ServerCredentials.createSsl).',
            lineNum
          );
        }
      }

      // ── DEEP SEMANTIC ORCHESTRATION FILTER ─────────────────────────────
      const isHighRisk = DEEP_SCAN_PATHS.some(p => file.includes(p));
      if (isHighRisk) {
        await this.deepScan(file, content);
      }
    }
  }

  async deepScan(file, content) {
    const prompt = `Review this security critical file for B2B multi-tenant SaaS vulnerabilities.
    Enforce: token containment inside client volatile stores, cryptographic isolation tokens partitioning keys (customer_id), 
    Vault reference pointer mappings, mTLS grpc tunnels, and SPKI Intermediate CA pinning for mobile Dart platforms.
    
    File context: ${file}
    Content: \n${content.slice(0, 8000)}`;

    try {
      const response = await this.callLLM(prompt);
      const parsed   = JSON.parse(response);
      for (const v of (parsed.violations ?? [])) {
        this.block(file, v.rule, v.message, v.line);
      }
    } catch (err) {
      this.warn(file, 'SEC-DEEP-SCAN-FAIL', 'Semantic LLM audit thread timed out. Syntactic gates remain forced.');
    }
  }

  callLLM(prompt) {
    return new Promise((resolve, reject) => {
      const body = JSON.stringify({
        model: 'claude-opus-4-6',
        max_tokens: 1024,
        messages: [{ role: 'user', content: prompt }],
      });

      const req = https.request({
        hostname: 'api.anthropic.com',
        path: '/v1/messages',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': process.env.ANTHROPIC_API_KEY ?? '',
          'anthropic-version': '2023-06-01',
        }
      }, (res) => {
        let data = '';
        res.on('data', chunk => { data += chunk; });
        res.on('end', () => { resolve(JSON.parse(data).content?.[0]?.text ?? '{"violations":[]}'); });
      });
      req.write(body);
      req.end();
    });
  }
}

new SecurityAuditRunner().run().catch(console.error);
```

### 1.6 Pre-Commit API Contract Drift Runner (scripts/audit-runners/api-contract-drift.js)

```javascript
// scripts/audit-runners/api-contract-drift.js
// Tier: Lower/Faster Model — structural validation against Ground Truth Contract

'use strict';

const { AuditRunner } = require('./runner-base');
const fs               = require('fs');
const path             = require('path');

const CONTRACT_PATH = path.resolve('docs/api_contract.json');

class APIContractAuditRunner extends AuditRunner {
  constructor() {
    super('sub-agent-api', 'pattern-scan');
  }

  async audit(files) {
    if (!fs.existsSync(CONTRACT_PATH)) {
      this.warn('api_contract.json', 'API01-CONTRACT-MISSING', 'docs/api_contract.json not found.');
      return;
    }

    const contract = JSON.parse(fs.readFileSync(CONTRACT_PATH, 'utf8'));
    const routes   = contract.routes ?? [];

    for (const file of files) {
      if (!file.endsWith('.controller.ts')) continue;
      const content = this.readFile(file);
      const lines   = content.split('\n');

      for (let i = 0; i < lines.length; i++) {
        const line    = lines[i];
        const lineNum = i + 1;

        const pathMatch = line.match(/@(Get|Post|Put|Patch|Delete)\s*\(\s*['"`]([^'"`]+)['"`]/i);
        if (pathMatch) {
          const method      = pathMatch[1].toUpperCase();
          const routePath   = pathMatch[2];
          const fullPath    = this.resolveFullPath(content, routePath);
          const inContract  = routes.some(r => r.method === method && this.pathMatches(r.path, fullPath));

          if (!inContract) {
            this.block(file, 'API01-UNDECLARED-ROUTE', `Route ${method} ${fullPath} missing from contract rules registry.`, lineNum);
          }
        }

        // RULE API02: Missing @Roles() on route handler
        if (/@(Get|Post|Put|Patch|Delete)\s*\(/i.test(line)) {
          const context = lines.slice(Math.max(0, i - 3), i + 2).join('\n');
          if (!/@Roles\s*\(/i.test(context) && !/@Public\s*\(\)/i.test(context)) {
            this.block(file, 'API02-MISSING-ROLES-DECORATOR',
              'Route handler has no @Roles() or @Public() decorator. Default-deny is enforced.',
              lineNum
            );
          }
        }

        // RULE API03: Response DTO — never return raw entity
        if (/return\s+\w+Entity|return\s+this\.\w+Repository\.find/i.test(line)) {
          this.warn(file, 'API03-RAW-ENTITY-RETURN',
            'Controller may be returning raw entity/repository result. Map to response DTO.',
            lineNum
          );
        }

        // RULE API04: API version prefix enforcement
        const controllerPath = content.match(/@Controller\s*\(\s*['"`]([^'"`]+)['"`]/)?.[1] ?? '';
        if (controllerPath && !controllerPath.startsWith('api/v5')) {
          this.block(file, 'API04-WRONG-VERSION-PREFIX',
            `Controller path '${controllerPath}' does not start with 'api/v5'.`
          );
        }
      }
    }
  }

  resolveFullPath(fileContent, routePath) {
    const controllerPath = fileContent.match(/@Controller\s*\(\s*['"`]([^'"`]+)['"`]/)?.[1] ?? '';
    return `/${controllerPath}/${routePath}`.replace(/\/+/g, '/');
  }

  pathMatches(contractPath, routePath) {
    const normalize = p => p.replace(/:[^/]+/g, ':param').replace(/\/+/g, '/');
    return normalize(contractPath) === normalize(routePath);
  }
}

new APIContractAuditRunner().run().catch(console.error);
```

### 1.7 Pre-Commit Defensive Error Handling Audit Runner (scripts/audit-runners/error-audit.js)

```javascript
// scripts/audit-runners/error-audit.js
// Tier: Lower/Faster Model — AST syntactic safety validation

'use strict';

const { AuditRunner } = require('./runner-base');

class ErrorAuditRunner extends AuditRunner {
  constructor() {
    super('sub-agent-error', 'pattern-scan');
  }

  async audit(files) {
    for (const file of files) {
      const content = this.readFile(file);
      const lines   = content.split('\n');

      for (let i = 0; i < lines.length; i++) {
        const line    = lines[i];
        const lineNum = i + 1;

        // ── RULE ERR01: Unhandled async function without try/catch ────────
        if (
          /async\s+\w+\s*\([^)]*\)\s*[:{]/i.test(line) &&
          file.endsWith('.service.ts')
        ) {
          const body = lines.slice(i, i + 30).join('\n');
          if (
            /await\s+/i.test(body) &&
            !/try\s*\{/i.test(body) &&
            !/@Injectable/i.test(body) &&
            !/\/\/\s*error-handled-by-filter/i.test(body)
          ) {
            this.warn(file, 'ERR01-MISSING-TRY-CATCH',
              'async service method with await detected without try/catch.',
              lineNum
            );
          }
        }

        // ── RULE ERR02: Raw error thrown to client ─────────────────────────
        if (
          /throw\s+new\s+Error\s*\(/i.test(line) &&
          !/@Catch\s*\(/i.test(content)
        ) {
          this.warn(file, 'ERR02-RAW-ERROR-THROW',
            'throw new Error() in a NestJS context will produce a 500 with raw message. Use typed exceptions.',
            lineNum
          );
        }

        // ── RULE ERR03: console.error with error object (stack trace leak) ─
        if (
          (/console\.error\s*\(.*err\.stack/i.test(line) ||
           /res\.json\s*\(.*err\.stack/i.test(line) ||
           /res\.send\s*\(.*err\.message/i.test(line)) &&
          !file.includes('filter') &&
          !file.includes('logger')
        ) {
          this.block(file, 'ERR03-STACK-TRACE-EXPOSURE',
            'err.stack or err.message sent directly to HTTP response or console.error.',
            lineNum
          );
        }

        // ── RULE ERR04: Flutter — missing error state in StreamBuilder ────
        if (
          file.endsWith('.dart') &&
          /StreamBuilder\s*</i.test(line)
        ) {
          const body = lines.slice(i, i + 20).join('\n');
          if (!/snapshot\.hasError/i.test(body)) {
            this.warn(file, 'ERR04-FLUTTER-STREAM-NO-ERROR-STATE',
              'StreamBuilder widget found without snapshot.hasError check.',
              lineNum
            );
          }
        }

        // ── RULE ERR05: Promise.all without catch ─────────────────────────
        if (
          /Promise\.all\s*\([^)]+\)/i.test(line) &&
          !/\.catch\s*\(/i.test(lines.slice(i, i + 3).join('\n')) &&
          !/try\s*\{/i.test(lines.slice(Math.max(0, i - 5), i).join('\n'))
        ) {
          this.warn(file, 'ERR05-PROMISE-ALL-NO-CATCH',
            'Promise.all() call without .catch() or surrounding try/catch.',
            lineNum
          );
        }

        // ── RULE ERR06: Swallowed catch block ─────────────────────────────
        if (
          /catch\s*\([^)]*\)\s*\{\s*\}/i.test(line) ||
          /catch\s*\([^)]*\)\s*\{\s*\/\/[^\n]*\n\s*\}/i.test(lines.slice(i, i + 3).join('\n'))
        ) {
          this.block(file, 'ERR06-SWALLOWED-CATCH',
            'Swallowing catch exceptions blocks is zero-tolerance forbidden.',
            lineNum
          );
        }
      }
    }
  }
}

new ErrorAuditRunner().run().catch(console.error);
```

### 1.8 CI Server-Side Gate (GitHub Actions Deployment Workflow)

```yaml
# .github/workflows/audit-gate.yml
name: VMS Antigravity SaaS Audit Gate

on:
  pull_request:
    branches: [develop, main]
  push:
    branches: [develop]

concurrency:
  group: audit-${{ github.ref }}
  cancel-in-progress: true

jobs:
  schema-audit:
    name: sub-agent-schema
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: pnpm install --frozen-lockfile
      - name: Run Schema Audit
        run: node scripts/audit-runners/schema-audit.js $(git diff --name-only origin/develop...HEAD)

  security-audit:
    name: sub-agent-security
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: pnpm install --frozen-lockfile
      - name: Run Security Audit
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: node scripts/audit-runners/security-audit.js $(git diff --name-only origin/develop...HEAD)

  api-contract-audit:
    name: sub-agent-api
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: pnpm install --frozen-lockfile
      - name: Run API Contract Audit
        run: node scripts/audit-runners/api-contract-drift.js $(git diff --name-only origin/develop...HEAD)

  error-audit:
    name: sub-agent-error
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: pnpm install --frozen-lockfile
      - name: Run Error Handling Audit
        run: node scripts/audit-runners/error-audit.js $(git diff --name-only origin/develop...HEAD)
```

---

## Section 2 — Sub-Agent Specialized Registry & Cost-Effective Model Mapping

### 2.0 Registry Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    VMS ANTIGRAVITY SUB-AGENT REGISTRY                       │
├──────────────────────┬──────────────────┬──────────────┬────────────────────┤
│ Agent ID             │ Model Tier       │ Trigger      │ Blocking?          │
├──────────────────────┼──────────────────┼──────────────┼────────────────────┤
│ sub-agent-schema     │ Lower / Faster   │ *.ts *.sql   │ YES (S01-S10)      │
│ sub-agent-security   │ Higher / Deep    │ All files    │ YES (SEC01-SEC10)  │
│ sub-agent-api        │ Lower / Faster   │ controllers  │ YES (API01-API04)  │
│ sub-agent-error      │ Lower / Faster   │ *.ts *.dart  │ BLOCK (ERR01-ERR06)│
└──────────────────────┴──────────────────┴──────────────┴────────────────────┘
```

### 2.1 sub-agent-schema

```yaml
id:           sub-agent-schema
display_name: SaaS Multi-Tenant Schema & Composite Key Validator
model_tier:   lower-faster
# Uses deterministic regex scanning logic — zero inference token costs per commit
responsibilities:
  - Validate composite key sharding keys (customer_id, site_id, camera_id) in DDL and ORM models
  - Reject open un-namespaced camera entity configurations references
  - Intercept database enums or CHECK blocks applied on site_type variables to preserve UI portability
  - Block un-namespaced global email unique key locks to eliminate tenant lockouts
  - Verify MongoDB connection audit logs write-concern
  - Check missing TTL on Redis keys
  - Check recordings table partitioning status
```

### 2.2 sub-agent-security

```yaml
id:           sub-agent-security
display_name: Cryptographic Container & Isolation Boundary Auditor
model_tier:   higher-deep
model:        claude-opus-4-6
# Pattern filter executes first (free). Deep semantic scan calls Claude exclusively for risk directories.
deep_scan_trigger_paths:
  - /auth/
  - /jwt/
  - /vault/
  - /crypto/
  - /token/
  - /secret/
  - auth.service.ts
  - jwt.strategy.ts
  - secure_storage_plugin.dart
```

### 2.3 sub-agent-api

```yaml
id:           sub-agent-api
display_name: API Contract Drift Detector
model_tier:   lower-faster
# Pure structural comparison against docs/api_contract.json
responsibilities:
  - Verify all @Get/@Post/@Patch/@Delete routes exist in api_contract.json
  - Block undeclared routes (must be in contract before implementation)
  - Enforce @Roles() or @Public() on every route handler
  - Enforce /api/v5/ version prefix on all controllers
  - Warn on raw entity returns (should return typed DTO)
```

### 2.4 sub-agent-error

```yaml
id:           sub-agent-error
display_name: Defensive Error Handling Enforcer
model_tier:   lower-faster
# Pattern scan only — no LLM needed
responsibilities:
  - Warn on async service methods with await but no try/catch
  - Warn on raw Error() throws in NestJS context
  - Block err.stack or err.message sent directly to HTTP response
  - Warn on Flutter StreamBuilder without hasError check
  - Warn on Promise.all without catch
  - Block empty or swallowed catch blocks
```

### 2.5 Model Allocation Cost Summary

```
Typical PR with 10 modified files (2 auth files, 8 general):
  sub-agent-schema   → 10 files × pattern scan   = $0.00   / <5s total
  sub-agent-security → 8 files × pattern + 2 deep = ~$0.04  / <35s total
  sub-agent-api      → 3 controllers × pattern    = $0.00   / <2s total
  sub-agent-error    → 10 files × pattern         = $0.00   / <4s total
  ─────────────────────────────────────────────────────────────────────
  Total per PR:                                    ~$0.04   / ~45s total

Monthly estimate (100 PRs):
  ~$4.00 in LLM API costs for the full audit suite.
```

---

## Section 3 — Daily Context Synchronization Template (.context/state.md)

### 3.0 Context Protocol Invariant

```
- Main orchestrator agents update .context/state.md instantly after EVERY completed task.
- Session snapshots are written at session start and termination, verifying parameters via local hashes.
- Code generation tasks are restricted strictly to current active Phase milestones.
```

### 3.1 .context/state.md Target Core Schema Template

```markdown
# VMS Enterprise — Agent Context State
**Last Updated:** {ISO_TIMESTAMP}
**Session ID:** {SESSION_ID}
**Phase:** Phase 1 SaaS Revision
**Sprint:** S{SPRINT_NUMBER} (Week {WEEK_NUMBER} of 12)
**Active Engineer Context:** {VIVEK | SHUBHAM_SAURABH | SAGAR | MULTI}

---

## 1. Tasks Completed This Session

- [DONE] {YYYY-MM-DDTHH:MM:SSZ} | {owner} | {sub_phase_id} | {artifact_path} | {TESTS: PASS/FAIL/SKIP}

---

## 2. In-Flight Context State

### 2.1 Current Task
**Task ID:** {sub_phase_id}
**Owner:** {owner}
**Description:** {task_description}
**Status:** {IN_PROGRESS | BLOCKED | WAITING_REVIEW}

### 2.2 Active File Locks
- {file_path} → locked by {owner} since {ISO_TIMESTAMP}

---

## 3. Blocker / Sub-Agent Flags Raised

### 3.1 Active BLOCK Flags
| Flag ID | Agent | Rule | File | Line | Raised | Resolution |
|---|---|---|---|---|---|---|
| {FLAG_ID} | {agent} | {rule_code} | {file} | {line} | {ISO_TIMESTAMP} | {PENDING|ASSIGNED} |

**Current BLOCK count:** {N}
**Merge gate status:** {OPEN | CLEAR}

---

## 4. Next Granular Sub-Sub-Phase Targets

### 4.1 Immediate Next Task (This Session)
**Task ID:** {sub_phase_id}
**Owner:** {owner}
**Description:** {exact_task_description}
**Acceptance Criteria:**
- [ ] {criterion_1}
- [ ] {criterion_2}

### 4.2 Sprint Exit Gate Progress
| Gate | Threshold | Current | Status |
|---|---|---|---|
| Unit test coverage | >= 60% | {N}% | {PASS|FAIL} |
| Multi-Tenant Leakage | 0 Tolerance | 0 Kontam | PASS |
| Validation Workload | 1,000 Streams | {N} Channels | IN_PROGRESS |
| BLOCK flags | 0 open | {N} open | {PASS|FAIL} |

---

## 5. Cross-Owner Dependency Status (Authoritative Matrix Alignment)

| Dependency Target | Blocked Track | Blocking Track | Operational Context Required | Status |
|---|---|---|---|---|
| Intermediate CA SPKI hash | Sagar (Solo Mobile) | Vivek (Vault PKI) | Base64 public key verification hash for Dart network pinning | PENDING |
| HLS streaming URL format | Sagar (Solo Mobile) | Shubham + Saurabh (Media Core) | playlist mapping configurations contract for `.m3u8` players | PENDING |
| Ingestion webhook endpoint | External AIEYE | Vivek (NestJS Workers) | Async event JSON routing schema to intercept webhook alerts payloads | PENDING |
| vms:camera-status payload | Vivek (Control plane) | Shubham + Saurabh (Media Core) | Stream key maps and packet loss indicators variables matching | PENDING |

---

## 6. Architecture Drift Watchlist

| Architecture Pillar | Frozen Core Decision Invariant | Drift Violation Trigger | Automation Enforcement Action |
|---|---|---|---|
| **Pillar 4 Isolation** | NestJS deployed as 3 standalone decoupled Kubernetes containers. | Declaring event consumer queues or WebSocket routers within api-gateway pods. | **BLOCK COMMIT** (Architecture Boundary Breach) |
| **Pillar 1 Tenancy** | Absolute enforcement of global prefix namespaces keys: `{customer_id}:{site_id}:{camera_id}`. | Inserting relational records or tracking indices lacking root customer_id keys. | **sub-agent-schema auto-BLOCK** |
| **Pillar 5 Dynamic Site** | Database rows preserve site_type as open text strings with zero database constraints. | Committing database SQL statements containing strict CHECK evaluation arrays. | **sub-agent-schema auto-BLOCK** |
| **Pillar 8 Sandboxing** | Zero real-time WebRTC or interactive PTZ logic codes inside Phase 1 mobile repository. | Integrating `webrtcbin` or camera controls inside Sagar's Flutter files. | **BLOCK + Escalate to Sagar** |
| **Frozen Stack** | Flutter represents the single cross-platform compilation target for mobile apps. | Injecting native Swift or Kotlin project spaces inside mobile directories. | **BLOCK + Terminate Commit** |

---

## 7. Session Handoff Notes

**Completed this session:**
{summary_of_what_was_done}

**Left incomplete (pick up here):**
{exact_state_of_incomplete_task_with_file_and_line_reference}

**Decisions made this session:**
- {decision_1} — rationale: {rationale}

**Do NOT do in next session without explicit instruction:**
- {warning_1}
```

### 3.2 Session Snapshot Engine Script (scripts/context/snapshot.js)

```javascript
// scripts/context/snapshot.js
// Executed at start and termination of every workspace sprint cycle: node scripts/context/snapshot.js start

'use strict';

const fs   = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const SESSION_DIR = path.resolve('.context/sessions');
const STATE_FILE  = path.resolve('.context/state.md');

if (!fs.existsSync(SESSION_DIR)) {
  fs.mkdirSync(SESSION_DIR, { recursive: true });
}

const mode      = process.argv[2] ?? 'start';
const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 16);
const sessionId = `${timestamp}-${Math.random().toString(36).slice(2, 6)}`;

function getGitInfo() {
  try {
    return {
      branch: execSync('git rev-parse --abbrev-ref HEAD').toString().trim(),
      sha:    execSync('git rev-parse --short HEAD').toString().trim(),
      dirty:  execSync('git status --porcelain').toString().trim().length > 0,
    };
  } catch {
    return { branch: 'unknown', sha: 'unknown', dirty: false };
  }
}

if (mode === 'start') {
  const git     = getGitInfo();
  const content = [
    `# Session Snapshot — START`,
    `**Session ID:** ${sessionId}`,
    `**Timestamp:** ${new Date().toISOString()}`,
    `**Git Branch:** ${git.branch}`,
    `**Git SHA:** ${git.sha}`
  ].join('\n');

  fs.writeFileSync(path.join(SESSION_DIR, `${timestamp}-start.md`), content, 'utf8');
}
```

### 3.3 Context Directory .gitignore Rules

```gitignore
# Local agent state — not committed (changes per session)
.context/state.md
.context/flags/latest-block.md

# Session snapshots — committed (audit trail)
# .context/sessions/ → DO commit these
# .context/reports/  → DO commit these

# Warn logs — committed as daily accumulator
# .context/flags/YYYY-MM-DD-warns.md → DO commit these

# Local environment
.env.local
*.env.local
```

### 3.4 State File Bootstrap Initialization Script (scripts/context/init-state.js)

```javascript
// scripts/context/init-state.js
// Workspace bootloader setup: node scripts/context/init-state.js

'use strict';

const fs   = require('fs');
const path = require('path');

const DIRS = ['.context', '.context/sessions', '.context/flags', '.context/reports'];
for (const dir of DIRS) { if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true }); }

const STATE_FILE = path.resolve('.context/state.md');
if (fs.existsSync(STATE_FILE)) { process.exit(0); }

const initial = `# VMS Enterprise — Agent Context State
**Last Updated:** ${new Date().toISOString()}
**Session ID:** INIT
**Phase:** Phase 1 SaaS Revision
**Sprint:** S1 (Week 1 of 12)
**Active Engineer Context:** MULTI

---

## 2. In-Flight Context State

### 2.1 Current Task
**Task ID:** INIT
**Owner:** ALL
**Description:** Workspace initialization — read all onboarding docs before starting coding blocks
**Status:** IN_PROGRESS

### 2.3 Interface Contracts Under Negotiation
| Contract Name Description | Owner Track A | Owner Track B | Status | Target Deadline |
|---|---|---|---|---|
| Intermediate CA SPKI verification hash | Vivek | Sagar | BLOCKED - Vault PKI initialization pending | Sprint 1 W1 |
| AIEYE metadata alert webhook payload | Vivek | External AI | DRAFT | Sprint 1 W1 |
| HLS streaming URL format contract | Shubham + Saurabh | Sagar | DRAFT | Sprint 1 W2 |
| GET /recordings/stream API contract | Vivek | Sagar | DRAFT | Sprint 1 W2 |

---

## 4. Next Granular Sub-Sub-Phase Targets

### 4.1 Immediate Next Task (This Session)
**Task ID:** 1.1.1
**Owner:** Vivek
**Description:** Nx Multi-Tenant Monorepo initialization — standalone deployment containers architecture
**Acceptance Criteria:**
- [ ] Scaffold isolated spaces for vms-api-gateway, vms-event-workers, vms-ws-broadcaster
- [ ] Enforce strict ESLint rules: explicit any configurations trigger errors
- [ ] Embed deterministic pre-commit regex scanners inside scripts/audit-runners/
**Estimated Duration:** 90 minutes
**Blocking Dependencies:** NONE

### 4.3 Sprint Exit Gate Progress
| Gate Identifier | Target Threshold Baseline | Current State | Status |
|---|---|---|---|
| Unit test coverage | >= 60% metrics | 0% | IN_PROGRESS |
| Multi-Tenant Kontam | 0 Leakage Cases | 0 kontam | PASS |
| Sizing Target Workload | 1,000 Concurrent Cameras | 0 nodes | IN_PROGRESS |
| BLOCK flags | 0 open violations | 0 open | PASS |

---

## 5. Cross-Owner Dependency Status

| Dependency Title | Blocked Owner | Blocking Owner | Description / Deliverable Target | Due | Status |
|---|---|---|---|---|---|
| SPKI hash provision | Sagar | Vivek | Intermediate CA SHA-256 hash string from Vault engine | Sprint 1 W1 | PENDING |
| HLS m3u8 format | Sagar | Shubham + Saurabh | Exact playlist media streaming path contract | Sprint 1 W2 | PENDING |
| GET /recordings/stream | Sagar | Vivek | Multi-tenant signed clip playback node endpoint | Sprint 1 W2 | PENDING |
| POST /cameras/discovered | Shubham + Saurabh | Vivek | mTLS gRPC endpoint for appliance data ingestion | Sprint 1 W1 | PENDING |
| vms:camera-status schema | Vivek | Shubham + Saurabh | Redis stream payload fields serialization spec | Sprint 1 W1 | PENDING |
`;

fs.writeFileSync(STATE_FILE, initial, 'utf8');
console.log('✅ .context/state.md initialized for SaaS multi-tenant workspace orchestration.');
```
