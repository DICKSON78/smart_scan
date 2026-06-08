<?php
require_once __DIR__ . '/helpers.php';

header('Content-Type: application/json; charset=utf-8');

$path = $_GET['path'] ?? '';
$path = trim($path, '/');
$segments = explode('/', $path);
$method = $_SERVER['REQUEST_METHOD'];

// Handle OPTIONS preflight
if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

try {
    $route = $method . ' ' . ($segments[0] ?? '');
    $route .= isset($segments[1]) ? '/' . $segments[1] : '';
    $route .= isset($segments[2]) ? '/' . $segments[2] : '';

    switch ($route) {
        // ---- Auth ----
        case 'POST auth/signup':
            handleSignup();
            break;
        case 'POST auth/signin':
            handleSignin();
            break;
        case 'POST auth/invite-login':
            handleInviteLogin();
            break;
        case 'POST auth/logout':
            $user = authenticate();
            handleLogout($user);
            break;
        case 'GET auth/profile':
            $user = authenticate();
            jsonResponse([
                'success' => true,
                'user' => formatUser($user),
            ]);
            break;

        // ---- Courses ----
        case 'GET courses':
            $user = authenticate();
            handleListCourses($user);
            break;
        case 'POST courses':
            $user = requireAdmin();
            handleCreateCourse($user);
            break;
        default:
            // DELETE courses/{id}
            if ($method === 'DELETE' && $segments[0] === 'courses' && isset($segments[1])) {
                $user = requireAdmin();
                handleDeleteCourse($user, (int)$segments[1]);
                break;
            }

            // ---- Credits (deduct without storing marks) ----
            if ($method === 'POST' && $segments[0] === 'credits' && ($segments[1] ?? '') === 'deduct') {
                $user = authenticate();
                handleDeductCredits($user);
                break;
            }

            // ---- Team ----
            if ($method === 'GET' && $segments[0] === 'team' && ($segments[1] ?? '') === 'members') {
                $user = authenticate();
                handleTeamMembers($user);
                break;
            }
            if ($method === 'POST' && $segments[0] === 'team' && ($segments[1] ?? '') === 'invite') {
                $user = requireAdmin();
                handleTeamInvite($user);
                break;
            }
            // DELETE team/members/{teacherId}
            if ($method === 'DELETE' && $segments[0] === 'team' && ($segments[1] ?? '') === 'members' && isset($segments[2])) {
                $user = requireAdmin();
                handleTeamRemove($user, (int)$segments[2]);
                break;
            }
            // POST team/allocate — admin allocates credits to a teacher
            if ($method === 'POST' && $segments[0] === 'team' && ($segments[1] ?? '') === 'allocate') {
                $user = requireAdmin();
                handleTeamAllocate($user);
                break;
            }
            // GET team/usage — admin sees all teachers' usage stats
            if ($method === 'GET' && $segments[0] === 'team' && ($segments[1] ?? '') === 'usage') {
                $user = requireAdmin();
                handleTeamUsage($user);
                break;
            }

            // ---- Credits ----
            if ($method === 'GET' && $segments[0] === 'credits' && ($segments[1] ?? '') === 'balance') {
                $user = authenticate();
                handleGetCredits($user);
                break;
            }
            if ($method === 'POST' && $segments[0] === 'credits' && ($segments[1] ?? '') === 'topup') {
                $user = requireAdmin();
                handleTopupCredits($user);
                break;
            }
            // GET credits/my-usage — teacher sees their own allocation & usage
            if ($method === 'GET' && $segments[0] === 'credits' && ($segments[1] ?? '') === 'my-usage') {
                $user = authenticate();
                handleMyUsage($user);
                break;
            }

            // ---- Subscription ----
            if ($method === 'GET' && $segments[0] === 'subscription' && ($segments[1] ?? '') === 'plans') {
                handleListPlans();
                break;
            }
            if ($method === 'GET' && $segments[0] === 'subscription' && ($segments[1] ?? '') === 'status') {
                $user = authenticate();
                handleSubscriptionStatus($user);
                break;
            }
            if ($method === 'POST' && $segments[0] === 'subscription' && ($segments[1] ?? '') === 'purchase') {
                $user = authenticate();
                handlePurchase($user);
                break;
            }

            // ---- Setup ----
            if ($route === 'GET setup') {
                runSchema();
                jsonResponse(['success' => true, 'message' => 'Schema applied']);
                break;
            }

            errorResponse('Route not found: ' . $route, 404);
    }
} catch (PDOException $e) {
    errorResponse('Database error: ' . $e->getMessage(), 500);
} catch (Exception $e) {
    errorResponse($e->getMessage(), 400);
}

// ====== Handler Functions ======

function formatUser(array $u): array {
    return [
        'id'               => (int)$u['id'],
        'email'            => $u['email'],
        'name'             => $u['name'],
        'isAdmin'          => (bool)$u['is_admin'],
        'subscriptionPlan' => $u['subscription_plan'],
        'credits'          => (int)$u['credits'],
        'parentAdminId'    => $u['parent_admin_id'] !== null ? (int)$u['parent_admin_id'] : null,
    ];
}

// ----- Auth -----

function handleLogout(array $user): void {
    $db = getDB();
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (preg_match('/^Bearer\s+(.+)$/', $auth, $m)) {
        $token = $m[1];
        $stmt = $db->prepare("DELETE FROM user_tokens WHERE token = :token AND user_id = :uid");
        $stmt->execute([':token' => $token, ':uid' => $user['id']]);
    }
    jsonResponse(['success' => true, 'message' => 'Logged out']);
}

function handleSignup(): void {
    $input = getJsonInput();
    $email = trim($input['email'] ?? '');
    $password = $input['password'] ?? '';
    $name = trim($input['name'] ?? '');

    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        errorResponse('Valid email required');
    }
    if (strlen($password) < 6) {
        errorResponse('Password must be at least 6 characters');
    }
    if (empty($name)) {
        errorResponse('Name required');
    }

    $db = getDB();

    // Check duplicate email
    $stmt = $db->prepare("SELECT id FROM users WHERE email = :email");
    $stmt->execute([':email' => $email]);
    if ($stmt->fetch()) {
        errorResponse('Email already registered', 409);
    }

    $hash = password_hash($password, PASSWORD_BCRYPT);
    $stmt = $db->prepare(
        "INSERT INTO users (email, password_hash, name, is_admin) VALUES (:email, :hash, :name, 1)"
    );
    $stmt->execute([':email' => $email, ':hash' => $hash, ':name' => $name]);
    $userId = (int)$db->lastInsertId();

    $token = generateToken();
    $stmt = $db->prepare(
        "INSERT INTO user_tokens (user_id, token, expires_at) VALUES (:uid, :token, DATE_ADD(NOW(), INTERVAL 90 DAY))"
    );
    $stmt->execute([':uid' => $userId, ':token' => $token]);

    $stmt = $db->prepare("SELECT * FROM users WHERE id = :id");
    $stmt->execute([':id' => $userId]);
    $user = $stmt->fetch();

    jsonResponse([
        'success' => true,
        'token'   => $token,
        'user'    => formatUser($user),
    ], 201);
}

function handleSignin(): void {
    $input = getJsonInput();
    $email = trim($input['email'] ?? '');
    $password = $input['password'] ?? '';

    $db = getDB();
    $stmt = $db->prepare("SELECT * FROM users WHERE email = :email");
    $stmt->execute([':email' => $email]);
    $user = $stmt->fetch();

    if (!$user || !password_verify($password, $user['password_hash'])) {
        errorResponse('Invalid email or password', 401);
    }

    $token = generateToken();
    $stmt = $db->prepare(
        "INSERT INTO user_tokens (user_id, token, expires_at) VALUES (:uid, :token, DATE_ADD(NOW(), INTERVAL 90 DAY))"
    );
    $stmt->execute([':uid' => $user['id'], ':token' => $token]);

    jsonResponse([
        'success' => true,
        'token'   => $token,
        'user'    => formatUser($user),
    ]);
}

function handleInviteLogin(): void {
    $input = getJsonInput();
    $code = strtoupper(trim($input['code'] ?? ''));
    $name = trim($input['name'] ?? '');

    if (empty($code) || empty($name)) {
        errorResponse('Code and name required');
    }

    $db = getDB();

    // Validate invite code
    $stmt = $db->prepare(
        "SELECT * FROM invite_codes WHERE code = :code AND (expires_at IS NULL OR expires_at > NOW())"
    );
    $stmt->execute([':code' => $code]);
    $invite = $stmt->fetch();

    if (!$invite) {
        errorResponse('Invalid or expired invite code', 401);
    }

    // If already used, log in as that user
    if ($invite['used_by'] !== null) {
        $stmt = $db->prepare("SELECT * FROM users WHERE id = :id");
        $stmt->execute([':id' => $invite['used_by']]);
        $user = $stmt->fetch();
        if (!$user) {
            errorResponse('Associated user not found', 500);
        }
    } else {
        // First use — create user account
        $placeholderEmail = 'invite-' . strtolower($code) . '@exam.app';
        $placeholderHash = password_hash($code . time(), PASSWORD_BCRYPT);

        $stmt = $db->prepare(
            "INSERT INTO users (email, password_hash, name, is_admin, subscription_plan, parent_admin_id)
             VALUES (:email, :hash, :name, 0, (SELECT u.subscription_plan FROM users u WHERE u.id = :admin_id), :admin_id)"
        );
        $stmt->execute([
            ':email'    => $placeholderEmail,
            ':hash'     => $placeholderHash,
            ':name'     => $name,
            ':admin_id' => $invite['created_by'],
        ]);
        $teacherId = (int)$db->lastInsertId();

        // Mark invite as used
        $stmt = $db->prepare("UPDATE invite_codes SET used_by = :uid, used_at = NOW() WHERE id = :id");
        $stmt->execute([':uid' => $teacherId, ':id' => $invite['id']]);

        // Add to team
        $stmt = $db->prepare(
            "INSERT IGNORE INTO team_members (admin_id, teacher_id) VALUES (:admin, :teacher)"
        );
        $stmt->execute([':admin' => $invite['created_by'], ':teacher' => $teacherId]);

        // Fetch user
        $stmt = $db->prepare("SELECT * FROM users WHERE id = :id");
        $stmt->execute([':id' => $teacherId]);
        $user = $stmt->fetch();
    }

    $token = generateToken();
    $stmt = $db->prepare(
        "INSERT INTO user_tokens (user_id, token, expires_at) VALUES (:uid, :token, DATE_ADD(NOW(), INTERVAL 90 DAY))"
    );
    $stmt->execute([':uid' => $user['id'], ':token' => $token]);

    jsonResponse([
        'success' => true,
        'token'   => $token,
        'user'    => formatUser($user),
    ]);
}

// ----- Courses -----

function handleListCourses(array $user): void {
    $db = getDB();
    $stmt = $db->query("SELECT id, code, name, created_at FROM courses ORDER BY name ASC");
    $courses = $stmt->fetchAll();

    jsonResponse([
        'success' => true,
        'courses' => array_map(fn($c) => [
            'id'   => (int)$c['id'],
            'code' => $c['code'],
            'name' => $c['name'],
        ], $courses),
    ]);
}

function handleCreateCourse(array $user): void {
    $input = getJsonInput();
    $code = strtoupper(trim($input['code'] ?? ''));
    $name = trim($input['name'] ?? '');

    if (empty($code) || empty($name)) {
        errorResponse('Course code and name required');
    }

    $db = getDB();
    $stmt = $db->prepare("SELECT id FROM courses WHERE code = :code");
    $stmt->execute([':code' => $code]);
    if ($stmt->fetch()) {
        errorResponse('Course code already exists', 409);
    }

    $stmt = $db->prepare(
        "INSERT INTO courses (code, name, created_by) VALUES (:code, :name, :uid)"
    );
    $stmt->execute([':code' => $code, ':name' => $name, ':uid' => $user['id']]);

    $courseId = (int)$db->lastInsertId();
    jsonResponse([
        'success' => true,
        'course'  => ['id' => $courseId, 'code' => $code, 'name' => $name],
    ], 201);
}

function handleDeleteCourse(array $user, int $courseId): void {
    $db = getDB();
    $stmt = $db->prepare("DELETE FROM courses WHERE id = :id");
    $stmt->execute([':id' => $courseId]);

    if ($stmt->rowCount() === 0) {
        errorResponse('Course not found', 404);
    }

    jsonResponse(['success' => true]);
}

// ----- Credits (deduct without storing marks) -----

function handleDeductCredits(array $user): void {
    $input = getJsonInput();
    $count = max(1, (int)($input['count'] ?? 1));

    $db = getDB();

    $creditOwnerId = $user['parent_admin_id'] !== null ? (int)$user['parent_admin_id'] : (int)$user['id'];

    // Check credits
    $stmt = $db->prepare("SELECT credits FROM users WHERE id = :id FOR UPDATE");
    $stmt->execute([':id' => $creditOwnerId]);
    $owner = $stmt->fetch();
    if (!$owner || (int)$owner['credits'] < $count) {
        errorResponse('Insufficient credits. Please top up.', 402);
    }

    // Check teacher allocation
    if ($user['parent_admin_id'] !== null) {
        $stmt = $db->prepare(
            "SELECT allocated_credits, used_credits FROM team_members
             WHERE admin_id = :admin AND teacher_id = :teacher"
        );
        $stmt->execute([':admin' => $creditOwnerId, ':teacher' => $user['id']]);
        $alloc = $stmt->fetch();
        if ($alloc && (int)$alloc['allocated_credits'] > 0) {
            $remaining = (int)$alloc['allocated_credits'] - (int)$alloc['used_credits'];
            if ($remaining < $count) {
                errorResponse('Your scan allocation is exhausted. Contact your HOD to add more credits.', 402);
            }
        }
    }

    $db->beginTransaction();
    try {
        // Deduct from admin pool
        $stmt = $db->prepare("UPDATE users SET credits = credits - :c WHERE id = :id");
        $stmt->execute([':c' => $count, ':id' => $creditOwnerId]);

        // If teacher, increment used_credits
        if ($user['parent_admin_id'] !== null) {
            $stmt = $db->prepare(
                "UPDATE team_members SET used_credits = used_credits + :c
                 WHERE admin_id = :admin AND teacher_id = :teacher"
            );
            $stmt->execute([':c' => $count, ':admin' => $creditOwnerId, ':teacher' => $user['id']]);
        }

        $db->commit();
    } catch (Exception $e) {
        $db->rollBack();
        throw $e;
    }

    // Return updated balances
    $stmt = $db->prepare("SELECT credits FROM users WHERE id = :id");
    $stmt->execute([':id' => $creditOwnerId]);
    $updated = $stmt->fetch();

    $myUsed = 0;
    $myAlloc = 0;
    if ($user['parent_admin_id'] !== null) {
        $stmt = $db->prepare(
            "SELECT allocated_credits, used_credits FROM team_members
             WHERE admin_id = :admin AND teacher_id = :teacher"
        );
        $stmt->execute([':admin' => $creditOwnerId, ':teacher' => $user['id']]);
        $u = $stmt->fetch();
        if ($u) {
            $myUsed = (int)$u['used_credits'];
            $myAlloc = (int)$u['allocated_credits'];
        }
    }

    jsonResponse([
        'success'     => true,
        'creditsLeft' => max(0, (int)$updated['credits']),
        'myUsage'     => $user['parent_admin_id'] !== null ? "$myUsed/$myAlloc" : null,
    ]);
}

// ----- Team -----

function handleTeamMembers(array $user): void {
    $db = getDB();
    if ($user['is_admin']) {
        $stmt = $db->prepare(
            "SELECT u.id, u.email, u.name, u.subscription_plan, tm.created_at AS joined_at,
                    tm.allocated_credits, tm.used_credits
             FROM team_members tm
             JOIN users u ON u.id = tm.teacher_id
             WHERE tm.admin_id = :uid
             ORDER BY u.name ASC"
        );
        $stmt->execute([':uid' => $user['id']]);
    } else {
        $stmt = $db->prepare(
            "SELECT u.id, u.email, u.name, u.subscription_plan, tm.created_at AS joined_at,
                    tm.allocated_credits, tm.used_credits
             FROM team_members tm
             JOIN users u ON u.id = tm.admin_id
             WHERE tm.teacher_id = :uid
             ORDER BY u.name ASC"
        );
        $stmt->execute([':uid' => $user['id']]);
    }
    $members = $stmt->fetchAll();

    jsonResponse([
        'success' => true,
        'members' => array_map(fn($m) => [
            'id'               => (int)$m['id'],
            'email'            => $m['email'],
            'name'             => $m['name'],
            'subscriptionPlan' => $m['subscription_plan'],
            'allocatedCredits' => (int)$m['allocated_credits'],
            'usedCredits'      => (int)$m['used_credits'],
        ], $members),
    ]);
}

function handleTeamInvite(array $user): void {
    $db = getDB();

    // Check teacher limit
    $stmt = $db->prepare("SELECT teacher_count FROM subscription_plans WHERE id = :plan");
    $stmt->execute([':plan' => $user['subscription_plan']]);
    $plan = $stmt->fetch();
    $limit = $plan ? (int)$plan['teacher_count'] : 1;

    $stmt = $db->prepare("SELECT COUNT(*) AS cnt FROM team_members WHERE admin_id = :uid");
    $stmt->execute([':uid' => $user['id']]);
    $count = (int)$stmt->fetch()['cnt'];

    if ($count >= $limit) {
        errorResponse("Teacher limit reached for your plan ($limit)");
    }

    // Generate unique 8-char code
    $code = '';
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    for ($attempt = 0; $attempt < 10; $attempt++) {
        $code = '';
        for ($i = 0; $i < 8; $i++) {
            $code .= $chars[random_int(0, strlen($chars) - 1)];
        }
        $stmt = $db->prepare("SELECT id FROM invite_codes WHERE code = :code");
        $stmt->execute([':code' => $code]);
        if (!$stmt->fetch()) break;
    }

    $stmt = $db->prepare(
        "INSERT INTO invite_codes (code, created_by, expires_at) VALUES (:code, :uid, DATE_ADD(NOW(), INTERVAL 7 DAY))"
    );
    $stmt->execute([':code' => $code, ':uid' => $user['id']]);

    jsonResponse(['success' => true, 'code' => $code], 201);
}

function handleTeamRemove(array $user, int $teacherId): void {
    $db = getDB();
    $stmt = $db->prepare(
        "DELETE FROM team_members WHERE admin_id = :admin AND teacher_id = :teacher"
    );
    $stmt->execute([':admin' => $user['id'], ':teacher' => $teacherId]);

    if ($stmt->rowCount() === 0) {
        errorResponse('Team member not found', 404);
    }

    jsonResponse(['success' => true]);
}

// ----- Subscription -----

function handleListPlans(): void {
    $db = getDB();
    $plans = $db->query(
        "SELECT * FROM subscription_plans ORDER BY FIELD(id, 'basic', 'advanced', 'premium')"
    )->fetchAll();

    $features = $db->query(
        "SELECT * FROM plan_features ORDER BY id ASC"
    )->fetchAll();

    $featuresByPlan = [];
    foreach ($features as $f) {
        $featuresByPlan[$f['plan_id']][] = $f['feature'];
    }

    jsonResponse([
        'success' => true,
        'plans'   => array_map(fn($p) => [
            'id'            => $p['id'],
            'name'          => $p['name'],
            'price'         => $p['price'],
            'teacherCount'  => (int)$p['teacher_count'],
            'isPopular'     => (bool)$p['is_popular'],
            'features'      => $featuresByPlan[$p['id']] ?? [],
        ], $plans),
    ]);
}

function handleSubscriptionStatus(array $user): void {
    $db = getDB();
    $stmt = $db->prepare("SELECT * FROM subscription_plans WHERE id = :plan");
    $stmt->execute([':plan' => $user['subscription_plan']]);
    $plan = $stmt->fetch();

    $stmt = $db->prepare("SELECT COUNT(*) AS cnt FROM team_members WHERE admin_id = :uid");
    $stmt->execute([':uid' => $user['id']]);
    $teamCount = (int)$stmt->fetch()['cnt'];

    jsonResponse([
        'success' => true,
        'plan'    => $plan['id'] ?? 'basic',
        'details' => $plan ? [
            'name'         => $plan['name'],
            'price'        => $plan['price'],
            'teacherCount' => (int)$plan['teacher_count'],
            'teamUsed'     => $teamCount,
        ] : null,
    ]);
}

function handlePurchase(array $user): void {
    $input = getJsonInput();
    $planId = trim($input['planId'] ?? '');

    $validPlans = ['advanced', 'premium'];
    if (!in_array($planId, $validPlans)) {
        errorResponse('Invalid plan');
    }

    $db = getDB();
    $stmt = $db->prepare("SELECT id, teacher_count FROM subscription_plans WHERE id = :id");
    $stmt->execute([':id' => $planId]);
    $plan = $stmt->fetch();
    if (!$plan) {
        errorResponse('Plan not found', 404);
    }

    $db->beginTransaction();
    try {
        $stmt = $db->prepare("UPDATE users SET subscription_plan = :plan WHERE id = :uid");
        $stmt->execute([':plan' => $planId, ':uid' => $user['id']]);

        // Add credits based on plan
        $creditMap = ['advanced' => 350, 'premium' => 700];
        $credits = $creditMap[$planId] ?? 0;
        if ($credits > 0) {
            $stmt = $db->prepare("UPDATE users SET credits = credits + :c WHERE id = :id");
            $stmt->execute([':c' => $credits, ':id' => $user['id']]);
        }

        $db->commit();
    } catch (Exception $e) {
        $db->rollBack();
        throw $e;
    }

    jsonResponse([
        'success' => true,
        'message' => "Upgraded to $planId plan — $credits credits added",
    ]);
}

// ----- Credits -----

function handleGetCredits(array $user): void {
    $db = getDB();

    // Teacher → show parent admin's credits
    $targetId = $user['parent_admin_id'] !== null ? (int)$user['parent_admin_id'] : (int)$user['id'];

    $stmt = $db->prepare("SELECT id, name, credits FROM users WHERE id = :id");
    $stmt->execute([':id' => $targetId]);
    $owner = $stmt->fetch();

    if (!$owner) {
        errorResponse('Credit owner not found', 404);
    }

    jsonResponse([
        'success' => true,
        'credits' => (int)$owner['credits'],
        'ownerName' => $owner['name'],
        'isOwner' => (int)$user['id'] === $targetId,
    ]);
}

function handleTopupCredits(array $user): void {
    $input = getJsonInput();
    $amount = (int)($input['amount'] ?? 0);
    $package = trim($input['package'] ?? '');

    if ($amount <= 0 && empty($package)) {
        errorResponse('Amount or package required');
    }

    // Predefined credit packages
    $packages = [
        'small'   => ['credits' => 50,   'price' => 5000],
        'medium'  => ['credits' => 350,  'price' => 35000],
        'large'   => ['credits' => 700,  'price' => 70000],
        'college' => ['credits' => 5000, 'price' => 500000],
    ];

    $creditsToAdd = $amount;
    if (!empty($package) && isset($packages[$package])) {
        $creditsToAdd = $packages[$package]['credits'];
    }

    if ($creditsToAdd <= 0) {
        errorResponse('Invalid credit amount');
    }

    $db = getDB();
    $stmt = $db->prepare("UPDATE users SET credits = credits + :credits WHERE id = :id AND is_admin = 1");
    $stmt->execute([':credits' => $creditsToAdd, ':id' => $user['id']]);

    if ($stmt->rowCount() === 0) {
        errorResponse('Only admins can top up credits', 403);
    }

    // Return updated balance
    $stmt = $db->prepare("SELECT credits FROM users WHERE id = :id");
    $stmt->execute([':id' => $user['id']]);
    $updated = $stmt->fetch();

    jsonResponse([
        'success' => true,
        'creditsAdded' => $creditsToAdd,
        'newBalance' => (int)$updated['credits'],
        'message' => "$creditsToAdd credits added successfully",
    ]);
}

// ----- Team Allocation -----

function handleTeamAllocate(array $user): void {
    $input = getJsonInput();
    $teacherId = (int)($input['teacherId'] ?? 0);
    $credits = (int)($input['credits'] ?? 0);

    if ($teacherId <= 0 || $credits < 0) {
        errorResponse('teacherId and credits required');
    }

    $db = getDB();

    // Verify teacher belongs to this admin's team
    $stmt = $db->prepare(
        "SELECT id, allocated_credits, used_credits FROM team_members WHERE admin_id = :admin AND teacher_id = :teacher"
    );
    $stmt->execute([':admin' => $user['id'], ':teacher' => $teacherId]);
    $member = $stmt->fetch();

    if (!$member) {
        errorResponse('Teacher not found in your team', 404);
    }

    // Reset used_credits when re-allocating (new semester)
    $stmt = $db->prepare(
        "UPDATE team_members SET allocated_credits = :credits, used_credits = 0
         WHERE admin_id = :admin AND teacher_id = :teacher"
    );
    $stmt->execute([':credits' => $credits, ':admin' => $user['id'], ':teacher' => $teacherId]);

    // Get teacher name
    $stmt = $db->prepare("SELECT name FROM users WHERE id = :id");
    $stmt->execute([':id' => $teacherId]);
    $teacher = $stmt->fetch();

    jsonResponse([
        'success' => true,
        'teacherName' => $teacher['name'] ?? 'Unknown',
        'allocatedCredits' => $credits,
        'message' => "Allocated $credits scans to {$teacher['name']}",
    ]);
}

function handleTeamUsage(array $user): void {
    $db = getDB();

    // Get all teachers with their usage
    $stmt = $db->prepare(
        "SELECT u.id, u.name, u.email, tm.allocated_credits, tm.used_credits
         FROM team_members tm
         JOIN users u ON u.id = tm.teacher_id
         WHERE tm.admin_id = :uid
         ORDER BY u.name ASC"
    );
    $stmt->execute([':uid' => $user['id']]);
    $teachers = $stmt->fetchAll();

    // Get total credits remaining
    $stmt = $db->prepare("SELECT credits FROM users WHERE id = :id");
    $stmt->execute([':id' => $user['id']]);
    $me = $stmt->fetch();

    $totalAllocated = 0;
    $totalUsed = 0;
    $teacherList = [];
    foreach ($teachers as $t) {
        $totalAllocated += (int)$t['allocated_credits'];
        $totalUsed += (int)$t['used_credits'];
        $teacherList[] = [
            'id'               => (int)$t['id'],
            'name'             => $t['name'],
            'email'            => $t['email'],
            'allocatedCredits' => (int)$t['allocated_credits'],
            'usedCredits'      => (int)$t['used_credits'],
        ];
    }

    jsonResponse([
        'success'        => true,
        'creditsRemaining' => (int)$me['credits'],
        'totalAllocated' => $totalAllocated,
        'totalUsed'      => $totalUsed,
        'teachers'       => $teacherList,
    ]);
}

function handleMyUsage(array $user): void {
    $db = getDB();

    if ($user['is_admin'] || $user['parent_admin_id'] === null) {
        // Admin — return global credits
        jsonResponse([
            'success' => true,
            'isTeacher' => false,
            'creditsRemaining' => (int)$user['credits'],
        ]);
        return;
    }

    // Teacher — return allocation and usage
    $stmt = $db->prepare(
        "SELECT allocated_credits, used_credits FROM team_members
         WHERE admin_id = :admin AND teacher_id = :teacher"
    );
    $stmt->execute([':admin' => $user['parent_admin_id'], ':teacher' => $user['id']]);
    $alloc = $stmt->fetch();

    // Also get admin's total remaining credits
    $stmt = $db->prepare("SELECT credits, name FROM users WHERE id = :id");
    $stmt->execute([':id' => $user['parent_admin_id']]);
    $admin = $stmt->fetch();

    jsonResponse([
        'success'          => true,
        'isTeacher'        => true,
        'allocatedCredits' => $alloc ? (int)$alloc['allocated_credits'] : 0,
        'usedCredits'      => $alloc ? (int)$alloc['used_credits'] : 0,
        'adminCreditsLeft' => $admin ? (int)$admin['credits'] : 0,
        'adminName'        => $admin ? $admin['name'] : 'Unknown',
    ]);
}

