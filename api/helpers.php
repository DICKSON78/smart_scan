<?php
require_once __DIR__ . '/db.php';

function jsonResponse(mixed $data, int $code = 200): void {
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

function errorResponse(string $message, int $code = 400): void {
    jsonResponse(['success' => false, 'error' => $message], $code);
}

function getJsonInput(): array {
    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    return is_array($data) ? $data : [];
}

function generateToken(): string {
    return bin2hex(random_bytes(32));
}

function authenticate(): array {
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (!preg_match('/^Bearer\s+(.+)$/', $auth, $m)) {
        errorResponse('Authorization header required', 401);
    }
    $token = $m[1];
    $db = getDB();
    $stmt = $db->prepare(
        "SELECT u.* FROM users u
         JOIN user_tokens t ON u.id = t.user_id
         WHERE t.token = :token AND (t.expires_at IS NULL OR t.expires_at > NOW())"
    );
    $stmt->execute([':token' => $token]);
    $user = $stmt->fetch();
    if (!$user) {
        errorResponse('Invalid or expired token', 401);
    }
    return $user;
}

function requireAdmin(): array {
    $user = authenticate();
    if (!$user['is_admin']) {
        errorResponse('Admin access required', 403);
    }
    return $user;
}

function runSchema(): void {
    $db = getDB();
    // Migration: add credits and parent_admin_id columns if they don't exist
    try {
        $db->exec("ALTER TABLE users ADD COLUMN credits INT NOT NULL DEFAULT 0");
    } catch (PDOException $e) {
        // Column already exists — ignore
    }
    try {
        $db->exec("ALTER TABLE users ADD COLUMN parent_admin_id BIGINT UNSIGNED DEFAULT NULL");
    } catch (PDOException $e) {
        // Column already exists — ignore
    }
    try {
        $db->exec("ALTER TABLE team_members ADD COLUMN allocated_credits INT NOT NULL DEFAULT 0");
    } catch (PDOException $e) {
        // Column already exists — ignore
    }
    try {
        $db->exec("ALTER TABLE team_members ADD COLUMN used_credits INT NOT NULL DEFAULT 0");
    } catch (PDOException $e) {
        // Column already exists — ignore
    }
    $sql = file_get_contents(__DIR__ . '/schema.sql');
    $statements = explode(';', $sql);
    foreach ($statements as $stmt) {
        $stmt = trim($stmt);
        if (!empty($stmt)) {
            $db->exec($stmt);
        }
    }

    // Give existing admins free starting credits if they have none
    $db->exec("UPDATE users SET credits = GREATEST(credits, 50) WHERE is_admin = 1 AND credits < 50");
}
