const {onAuthUserCreate} = require('firebase-functions/v2/identity');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();
const auth = admin.auth();

// Plan definitions
const PLANS = {
  starter: {name: 'Starter', teacherCount: 2, scans: 1000, price: 'Tshs 25,000'},
  standard: {name: 'Standard', teacherCount: 5, scans: 5000, price: 'Tshs 100,000'},
  institution: {name: 'Institution', teacherCount: 100, scans: 50000, price: 'Tshs 800,000'},
  unlimited: {name: 'Unlimited', teacherCount: 200, scans: 500000, price: 'Tshs 1,300,000'},
};

// ─── Auth trigger: create user profile in Firestore ───
exports.createUserProfile = onAuthUserCreate(async (event) => {
  const {uid, email, displayName} = event.data;
  const userData = {
    email,
    name: displayName || email?.split('@')[0] || '',
    isAdmin: false,
    credits: 3,
    subscriptionPlan: 'basic',
    institutionName: '',
    parentAdminId: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  await db.collection('users').doc(uid).set(userData);
});

// ─── Helper: get user doc ───
async function getUser(uid) {
  const doc = await db.collection('users').doc(uid).get();
  if (!doc.exists) throw new HttpsError('not-found', 'User not found');
  return {id: doc.id, ...doc.data()};
}

// ─── Helper: deduct credits (common logic) ───
async function deductCredits(uid, count) {
  return db.runTransaction(async (tx) => {
    const ref = db.collection('users').doc(uid);
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'User not found');
    const user = snap.data();
    const currentCredits = user.credits ?? 0;
    if (currentCredits < count) {
      throw new HttpsError('failed-precondition', 'Insufficient credits');
    }
    tx.update(ref, {credits: admin.firestore.FieldValue.increment(-count)});
    return currentCredits - count;
  });
}

// ─── Callable: deduct credits ───
exports.deductCredits = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Not logged in');
  const {count = 1} = request.data;
  if (typeof count !== 'number' || count < 1 || count > 100 || !Number.isInteger(count)) {
    throw new HttpsError('invalid-argument', 'Count must be an integer between 1 and 100');
  }
  const remaining = await deductCredits(request.auth.uid, count);
  return {success: true, creditsRemaining: remaining};
});

// ─── Callable: get credits balance ───
exports.getCreditsBalance = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Not logged in');
  const user = await getUser(request.auth.uid);
  if (user.parentAdminId) {
    const adminUser = await getUser(user.parentAdminId);
    return {success: true, credits: adminUser.credits ?? 0};
  }
  return {success: true, credits: user.credits ?? 0};
});

// ─── Callable: get my usage (for teachers) ───
exports.getMyUsage = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Not logged in');
  const user = await getUser(request.auth.uid);
  if (user.isAdmin || !user.parentAdminId) {
    return {success: true, isTeacher: false, creditsRemaining: user.credits ?? 0};
  }
  const alloc = await db.collection('teachers')
    .where('userId', '==', request.auth.uid)
    .where('adminId', '==', user.parentAdminId)
    .limit(1)
    .get();
  if (alloc.empty) {
    return {success: true, isTeacher: true, allocatedCredits: 0, usedCredits: 0};
  }
  const d = alloc.docs[0].data();
  return {
    success: true, isTeacher: true,
    allocatedCredits: d.allocatedCredits ?? 0,
    usedCredits: d.usedCredits ?? 0,
  };
});

// ─── Callable: join team via invite code ───
exports.joinTeam = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Not logged in');
  const {code} = request.data;
  if (!code) throw new HttpsError('invalid-argument', 'Invite code is required');

  const codeSnap = await db.collection('invite_codes').doc(code.toUpperCase()).get();
  if (!codeSnap.exists) throw new HttpsError('not-found', 'Invalid invite code');

  const invite = codeSnap.data();
  if (invite.usedBy) throw new HttpsError('already-exists', 'Invite code has already been used');

  const adminUser = await getUser(invite.adminId);
  const creditsToAdd = invite.credits ?? PLANS[invite.plan]?.scans ?? 500;

  await db.runTransaction(async (tx) => {
    tx.update(db.collection('users').doc(request.auth.uid), {
      isAdmin: false,
      parentAdminId: invite.adminId,
      subscriptionPlan: invite.plan,
      credits: admin.firestore.FieldValue.increment(creditsToAdd),
      institutionName: adminUser.institutionName || '',
    });
    tx.update(db.collection('invite_codes').doc(code.toUpperCase()), {
      usedBy: request.auth.uid,
      usedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  const planData = PLANS[invite.plan] || PLANS.starter;
  return {
    success: true,
    plan: invite.plan,
    planName: planData.name,
    credits: creditsToAdd,
    institutionName: adminUser.institutionName,
  };
});

// ─── Callable: generate invite code ───
exports.generateInviteCode = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Not logged in');
  const user = await getUser(request.auth.uid);
  if (!user.isAdmin) throw new HttpsError('permission-denied', 'Only admins can generate codes');

  const {plan = 'starter', credits = PLANS[plan]?.scans ?? 500} = request.data;
  if (!PLANS[plan]) throw new HttpsError('invalid-argument', 'Invalid plan');
  if (typeof credits !== 'number' || credits < 1 || credits > 200000) {
    throw new HttpsError('invalid-argument', 'Credits must be between 1 and 200,000');
  }
  const code = Math.random().toString(36).substring(2, 8).toUpperCase();

  await db.collection('invite_codes').doc(code).set({
    code,
    adminId: request.auth.uid,
    plan,
    credits,
    usedBy: null,
    usedAt: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {success: true, code};
});

// ─── Callable: get subscription status ───
exports.getSubscriptionStatus = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Not logged in');
  const user = await getUser(request.auth.uid);

  if (user.parentAdminId) {
    const adminUser = await getUser(user.parentAdminId);
    const inviteSnap = await db.collection('invite_codes')
      .where('usedBy', '==', request.auth.uid)
      .limit(1)
      .get();
    const invite = inviteSnap.empty ? null : inviteSnap.docs[0].data();

    const teachersSnap = await db.collection('users')
      .where('parentAdminId', '==', user.parentAdminId)
      .get();
    const teachers = teachersSnap.docs.map((d) => ({id: d.id, ...d.data()}));

    return {
      success: true,
      subscription: {
        planId: adminUser.subscriptionPlan || 'basic',
        inviteCode: invite?.code || null,
        institutionName: adminUser.institutionName || '',
        defaultInviteCredits: PLANS[adminUser.subscriptionPlan]?.scans ?? 500,
        teachers: teachers.map((t) => ({
          email: t.email,
          name: t.name,
          credits: t.credits,
          createdAt: t.createdAt?.toMillis() || 0,
        })),
        plan: PLANS[adminUser.subscriptionPlan] || PLANS.basic,
      },
    };
  }

  const teachersSnap = await db.collection('users')
    .where('parentAdminId', '==', request.auth.uid)
    .get();
  const teachers = teachersSnap.docs.map((d) => ({id: d.id, ...d.data()}));

  const inviteSnap = await db.collection('invite_codes')
    .where('adminId', '==', request.auth.uid)
    .where('usedBy', '==', null)
    .limit(1)
    .get();
  const invite = inviteSnap.empty ? null : inviteSnap.docs[0].data();

  return {
    success: true,
    subscription: {
      planId: user.subscriptionPlan || 'basic',
      inviteCode: invite?.code || null,
      institutionName: user.institutionName || '',
      defaultInviteCredits: PLANS[user.subscriptionPlan]?.scans ?? 500,
      teachers: teachers.map((t) => ({
        email: t.email,
        name: t.name,
        credits: t.credits,
        createdAt: t.createdAt?.toMillis() || 0,
      })),
      plan: PLANS[user.subscriptionPlan] || PLANS.basic,
    },
  };
});

// ─── Callable: update profile ───
exports.updateProfile = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Not logged in');
  const {name, institutionName} = request.data;
  const update = {};
  if (name !== undefined) update.name = name;
  if (institutionName !== undefined) {
    const user = await getUser(request.auth.uid);
    if (!user.isAdmin) throw new HttpsError('permission-denied', 'Only admins can change institution name');
    update.institutionName = institutionName;
  }
  if (Object.keys(update).length === 0) {
    throw new HttpsError('invalid-argument', 'Nothing to update');
  }
  await db.collection('users').doc(request.auth.uid).update(update);
  if (update.name) {
    await auth.updateUser(request.auth.uid, {displayName: name});
  }
  return {success: true};
});

// ─── Callable: list courses ───
exports.listCourses = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Not logged in');
  const snap = await db.collection('courses')
    .orderBy('code')
    .get();
  const courses = snap.docs.map((d) => ({id: d.id, ...d.data()}));
  return {success: true, courses};
});

// ─── Callable: create course ───
exports.createCourse = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Not logged in');
  const {code, name} = request.data;
  if (!code || !name) throw new HttpsError('invalid-argument', 'Code and name required');
  const ref = await db.collection('courses').add({
    code: code.toUpperCase(),
    name,
    createdBy: request.auth.uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return {success: true, id: ref.id};
});

// ─── Callable: list sessions ───
exports.listSessions = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Not logged in');
  const snap = await db.collection('sessions')
    .where('userId', '==', request.auth.uid)
    .orderBy('createdAt', 'desc')
    .get();
  const sessions = snap.docs.map((d) => ({id: d.id, ...d.data()}));
  return {success: true, sessions};
});

// ─── Callable: delete session ───
exports.deleteSession = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Not logged in');
  const {sessionId} = request.data;
  if (!sessionId) throw new HttpsError('invalid-argument', 'sessionId required');
  const doc = await db.collection('sessions').doc(sessionId).get();
  if (!doc.exists) throw new HttpsError('not-found', 'Session not found');
  const session = doc.data();
  if (session.userId !== request.auth.uid) throw new HttpsError('permission-denied', 'Not your session');
  await db.collection('sessions').doc(sessionId).delete();
  return {success: true};
});

// ─── Callable: create session ───
exports.createSession = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Not logged in');
  const {name, subject, courseCode, maxMark, extractionType} = request.data;
  if (!name) throw new HttpsError('invalid-argument', 'Session name is required');
  const ref = await db.collection('sessions').add({
    name,
    subject: subject || 'General',
    courseCode: courseCode || '',
    maxMark: maxMark || 100,
    extractionType: extractionType || 'Exam',
    userId: request.auth.uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return {success: true, id: ref.id};
});

// ─── Callable: add credits (top-up) ───
exports.addCredits = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Not logged in');
  const user = await getUser(request.auth.uid);
  if (!user.isAdmin) throw new HttpsError('permission-denied', 'Only admins can add credits');
  const {count = 0} = request.data;
  if (count <= 0) throw new HttpsError('invalid-argument', 'Count must be positive');
  await db.collection('users').doc(request.auth.uid).update({
    credits: admin.firestore.FieldValue.increment(count),
  });
  return {success: true, creditsAdded: count};
});

// ─── Callable: get user by email ───
exports.getUserByEmail = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Not logged in');
  const {email} = request.data;
  if (!email) throw new HttpsError('invalid-argument', 'Email required');
  const snap = await db.collection('users')
    .where('email', '==', email)
    .limit(1)
    .get();
  if (snap.empty) return {success: false, user: null};
  const user = snap.docs[0].data();
  return {success: true, user: {id: snap.docs[0].id, ...user}};
});

// ─── Callable: team allocate (admin allocates credits to a teacher) ───
exports.teamAllocate = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Not logged in');
  const {teacherEmail, credits} = request.data;
  if (!teacherEmail || credits === undefined) throw new HttpsError('invalid-argument', 'teacherEmail and credits required');
  if (typeof credits !== 'number' || credits <= 0) throw new HttpsError('invalid-argument', 'Credits must be a positive number');

  const adminUser = await getUser(request.auth.uid);
  if (!adminUser.isAdmin) throw new HttpsError('permission-denied', 'Only admins can allocate');

  const snap = await db.collection('users')
    .where('email', '==', teacherEmail)
    .where('parentAdminId', '==', request.auth.uid)
    .limit(1)
    .get();
  if (snap.empty) throw new HttpsError('not-found', 'Teacher not found');

  const teacherRef = db.collection('users').doc(snap.docs[0].id);
  const adminRef = db.collection('users').doc(request.auth.uid);

  await db.runTransaction(async (tx) => {
    const adminDoc = await tx.get(adminRef);
    const adminCredits = adminDoc.data().credits ?? 0;
    if (adminCredits < credits) {
      throw new HttpsError('failed-precondition', 'Insufficient credits to allocate');
    }
    tx.update(adminRef, {credits: admin.firestore.FieldValue.increment(-credits)});
    tx.update(teacherRef, {credits: credits});
  });

  return {success: true, teacherEmail, credits};
});
