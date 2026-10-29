const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// Load environment variables from .env
const envPath = path.join(__dirname, '.env');
if (fs.existsSync(envPath)) {
  const envContent = fs.readFileSync(envPath, 'utf-8');
  envContent.split(/\r?\n/).forEach(line => {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) return;
    const idx = trimmed.indexOf('=');
    if (idx !== -1) {
      const key = trimmed.slice(0, idx).trim();
      const val = trimmed.slice(idx + 1).trim();
      if (!process.env[key]) {
        process.env[key] = val;
      }
    }
  });
}

const PORT = process.env.PORT || 3000;
const TEMP_PASS = process.env.TEMP_PASS || 'TempPass2026!';
const MAX_ATTEMPTS = parseInt(process.env.LOCKOUT_MAX_ATTEMPTS, 10) || 3;
const LOCKOUT_MINS = parseInt(process.env.LOCKOUT_DURATION_MINUTES, 10) || 15;

const SESSIONS = new Map();

// Load rbac_matrix.json dynamically
const rbacPath = path.join(__dirname, 'rbac_matrix.json');
let RBAC = { roles: [], modules: [], permissions: {} };
if (fs.existsSync(rbacPath)) {
  try {
    RBAC = JSON.parse(fs.readFileSync(rbacPath, 'utf-8'));
  } catch (e) {
    console.error('Error al parsear rbac_matrix.json, usando estructura vacia.', e);
  }
}

// Generate users dynamically from all 15 roles in RBAC.roles
const generatedUsers = (RBAC.roles || []).map((roleName, index) => {
  const username = (roleName === 'administrador') ? 'admin' : roleName;
  return {
    id: index + 1,
    username,
    password: TEMP_PASS,
    role: roleName,
    failedAttempts: 0,
    lockoutUntil: null,
    mustChangePassword: true
  };
});

const DB = {
  users: generatedUsers,
  modules: RBAC.modules,
  permissions: RBAC.permissions,
  moduleData: {
    configuracion_roles: [{ item: 'Matriz cargada dinamicamente desde rbac_matrix.json', author: 'sistema' }],
    estrategia_kpi: [{ item: 'Reporte Q3 EBITDA +18%', author: 'ceo' }],
    proyectos: [{ item: 'Sprint 4 - En progreso', author: 'pm_gerente' }],
    desarrollo_operaciones: [{ item: 'Servicios de operaciones activos', author: 'esp_operativo' }],
    auditoria_logs: [{ item: 'Servidor iniciado con politicas de .env', author: 'ti_secops' }]
  }
};

function saveRbacToFile() {
  RBAC.permissions = DB.permissions;
  fs.writeFileSync(rbacPath, JSON.stringify(RBAC, null, 2), 'utf-8');
}

// Security: Check Allowed Time Window
function checkTimeAllowed(role) {
  const now = new Date();
  const day = now.getDay(); // 0 = Sun, 1 = Mon ... 6 = Sat
  const hour = now.getHours();

  // 24/7
  if (['administrador', 'ceo', 'coo', 'cfo', 'cro', 'ti_secops'].includes(role)) {
    return true;
  }
  // Mon-Sat 07:00-21:00
  if (['pm_gerente', 'tech_lead', 'mkt_gerente', 'ventas_gerente', 'rh_talento', 'legal_compliance'].includes(role)) {
    return (day >= 1 && day <= 6 && hour >= 7 && hour < 21);
  }
  // Mon-Fri 08:00-17:00
  if (['esp_operativo', 'ejec_cuentas', 'esp_soporte'].includes(role)) {
    return (day >= 1 && day <= 5 && hour >= 8 && hour < 17);
  }
  return false;
}

function parseCookies(req) {
  const list = {};
  const cookieHeader = req.headers['cookie'];
  if (!cookieHeader) return list;
  cookieHeader.split(';').forEach(c => {
    const parts = c.split('=');
    list[parts.shift().trim()] = decodeURI(parts.join('='));
  });
  return list;
}

function sendResponse(res, status, contentType, data, extraHeaders = {}) {
  res.writeHead(status, { 'Content-Type': contentType, ...extraHeaders });
  res.end(data);
}

function sendJson(res, status, obj, extraHeaders = {}) {
  sendResponse(res, status, 'application/json', JSON.stringify(obj), extraHeaders);
}

const server = http.createServer((req, res) => {
  const parsedUrl = new URL(req.url, `http://${req.headers.host}`);
  const pathname = parsedUrl.pathname;

  // Static Assets / CSS
  if (pathname === '/styles.css') {
    const file = path.join(__dirname, 'public', 'styles.css');
    fs.readFile(file, (err, content) => {
      if (err) return sendResponse(res, 404, 'text/plain', 'Not found');
      sendResponse(res, 200, 'text/css; charset=utf-8', content);
    });
    return;
  }

  // Static Assets / Login HTML
  if (pathname === '/login.html' || pathname === '/login') {
    const file = path.join(__dirname, 'public', 'login.html');
    fs.readFile(file, (err, content) => {
      if (err) return sendResponse(res, 500, 'text/plain', 'Server error');
      sendResponse(res, 200, 'text/html; charset=utf-8', content);
    });
    return;
  }

  // API Login (POST)
  if (pathname === '/api/login' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const { username, password } = JSON.parse(body);
        const user = DB.users.find(u => u.username === username);

        if (!user) {
          return sendJson(res, 401, { error: 'Credenciales invalidas.' });
        }

        // Lockout Check
        const now = Date.now();
        if (user.lockoutUntil && user.lockoutUntil > now) {
          const remainingMinutes = Math.ceil((user.lockoutUntil - now) / 60000);
          return sendJson(res, 403, { error: `Cuenta bloqueada por intentos fallidos. Intente de nuevo en ${remainingMinutes} minuto(s).` });
        }

        if (user.password !== password) {
          user.failedAttempts += 1;
          if (user.failedAttempts >= MAX_ATTEMPTS) {
            user.lockoutUntil = now + (LOCKOUT_MINS * 60 * 1000);
            user.failedAttempts = 0;
            return sendJson(res, 403, { error: `Ha superado ${MAX_ATTEMPTS} intentos fallidos. Cuenta bloqueada por ${LOCKOUT_MINS} minutos.` });
          }
          return sendJson(res, 401, { error: `Password incorrecto. Intento ${user.failedAttempts} de ${MAX_ATTEMPTS}.` });
        }

        // Schedule check
        if (!checkTimeAllowed(user.role)) {
          return sendJson(res, 403, { error: 'Acceso denegado: Fuera del horario permitido para su rol.' });
        }

        // Reset lockout
        user.failedAttempts = 0;
        user.lockoutUntil = null;

        // Create Session Token
        const token = crypto.randomBytes(32).toString('hex');
        SESSIONS.set(token, {
          userId: user.id,
          username: user.username,
          role: user.role
        });

        sendJson(res, 200, {
          success: true,
          mustChangePassword: user.mustChangePassword
        }, {
          'Set-Cookie': `auth_token=${token}; Path=/; HttpOnly; SameSite=Strict`
        });
      } catch (e) {
        sendJson(res, 400, { error: 'Payload invalido.' });
      }
    });
    return;
  }

  // API Logout
  if (pathname === '/api/logout') {
    const cookies = parseCookies(req);
    if (cookies.auth_token) SESSIONS.delete(cookies.auth_token);
    sendJson(res, 200, { success: true }, {
      'Set-Cookie': 'auth_token=; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT'
    });
    return;
  }

  // --- STRICT AUTH GUARD FOR ALL OTHER ROUTES ---
  const cookies = parseCookies(req);
  const token = cookies.auth_token;
  const session = SESSIONS.get(token);

  if (!session) {
    if (pathname.startsWith('/api/')) {
      return sendJson(res, 401, { error: 'No autenticado. Inicie sesion.' });
    }
    return sendResponse(res, 302, 'text/plain', 'Redirecting to login', { 'Location': '/login.html' });
  }

  // Check Schedule on every request
  if (!checkTimeAllowed(session.role)) {
    SESSIONS.delete(token);
    if (pathname.startsWith('/api/')) {
      return sendJson(res, 403, { error: 'Sesion terminada: Fuera de su ventana horaria permitida.' });
    }
    return sendResponse(res, 302, 'text/plain', 'Session expired by schedule', { 'Location': '/login.html' });
  }

  // Lookup user state
  const currentUser = DB.users.find(u => u.id === session.userId);

  // API: Force Change Password
  if (pathname === '/api/change-password' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const { newPassword } = JSON.parse(body);
        if (!newPassword || newPassword.length < 8) {
          return sendJson(res, 400, { error: 'La nueva contrasena debe tener al menos 8 caracteres.' });
        }
        if (currentUser && newPassword === currentUser.password) {
          return sendJson(res, 400, { error: 'La nueva contrasena debe ser diferente a la contrasena temporal actual.' });
        }
        if (currentUser) {
          currentUser.password = newPassword;
          currentUser.mustChangePassword = false;
        }
        sendJson(res, 200, { success: true, message: 'Contrasena actualizada exitosamente.' });
      } catch (e) {
        sendJson(res, 400, { error: 'Payload invalido.' });
      }
    });
    return;
  }

  // STRICT BLOCK: Block any module or admin API calls while mustChangePassword is true
  if (currentUser && currentUser.mustChangePassword) {
    if (pathname.startsWith('/api/module-') || pathname.startsWith('/api/admin/')) {
      return sendJson(res, 403, { error: 'Acceso bloqueado: Debe cambiar su contrasena temporal antes de operar en el sistema.' });
    }
  }

  // Dashboard HTML
  if (pathname === '/' || pathname === '/dashboard' || pathname === '/index.html') {
    const file = path.join(__dirname, 'public', 'dashboard.html');
    fs.readFile(file, (err, content) => {
      if (err) return sendResponse(res, 500, 'text/plain', 'Server error');
      sendResponse(res, 200, 'text/html; charset=utf-8', content);
    });
    return;
  }

  // API: Get current user profile and RBAC permissions from rbac_matrix
  if (pathname === '/api/me' && req.method === 'GET') {
    const role = session.role;
    const rolePerms = DB.permissions[role] || {};

    const userModules = DB.modules.map(mod => {
      const perm = (role === 'administrador') ? 'admin' : (rolePerms[mod.id] || 'none');
      return {
        ...mod,
        permission: perm,
        canView: perm !== 'none',
        canWrite: ['write', 'admin'].includes(perm),
        canAdmin: perm === 'admin'
      };
    });

    sendJson(res, 200, {
      username: session.username,
      role: session.role,
      isSuperAdmin: session.role === 'administrador',
      mustChangePassword: currentUser ? currentUser.mustChangePassword : false,
      modules: userModules
    });
    return;
  }

  // API: Get Module Data
  if (pathname === '/api/module-data' && req.method === 'GET') {
    const moduleId = parsedUrl.searchParams.get('module');
    const role = session.role;
    const perm = (role === 'administrador') ? 'admin' : (DB.permissions[role]?.[moduleId] || 'none');

    if (perm === 'none') {
      return sendJson(res, 403, { error: 'Acceso denegado: No tiene permisos para este modulo.' });
    }

    sendJson(res, 200, {
      moduleId,
      permission: perm,
      items: DB.moduleData[moduleId] || []
    });
    return;
  }

  // API: Action on Module
  if (pathname === '/api/module-action' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const { moduleId, item } = JSON.parse(body);
        const role = session.role;
        const perm = (role === 'administrador') ? 'admin' : (DB.permissions[role]?.[moduleId] || 'none');

        if (!['write', 'admin'].includes(perm)) {
          return sendJson(res, 403, { error: 'Prohibido: Solo tiene permisos de lectura para este modulo.' });
        }

        if (!DB.moduleData[moduleId]) DB.moduleData[moduleId] = [];
        DB.moduleData[moduleId].push({ item, author: session.username, timestamp: new Date().toISOString() });

        sendJson(res, 200, { success: true, message: 'Accion ejecutada exitosamente.' });
      } catch (e) {
        sendJson(res, 400, { error: 'Payload invalido.' });
      }
    });
    return;
  }

  // API: Admin update role permissions & sync to rbac_matrix.json
  if (pathname === '/api/admin/permissions' && req.method === 'POST') {
    if (session.role !== 'administrador') {
      return sendJson(res, 403, { error: 'Acceso denegado: Se requiere rol administrador.' });
    }

    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const { targetRole, moduleId, newPermission } = JSON.parse(body);
        if (!DB.permissions[targetRole]) DB.permissions[targetRole] = {};
        DB.permissions[targetRole][moduleId] = newPermission;
        saveRbacToFile();

        sendJson(res, 200, { success: true, permissions: DB.permissions });
      } catch (e) {
        sendJson(res, 400, { error: 'Payload invalido.' });
      }
    });
    return;
  }

  // Fallback 404
  sendResponse(res, 404, 'text/plain', 'Recurso no encontrado.');
});

server.listen(PORT, () => {
  console.log(`Sistema RBAC corriendo en http://localhost:${PORT}`);
});
