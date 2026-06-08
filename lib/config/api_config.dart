class ApiConfig {
  /// Set to true to use the PHP backend API instead of local SharedPreferences.
  /// When false (default), the app uses local storage and does not require network.
  static bool useApi = false;

  /// The base URL of the PHP API (e.g., https://kkkt.mbgfw.org/api)
  static const String baseUrl = 'https://kkkt.mbgfw.org/api';

  /// Auth token stored after login
  static String? authToken;

  // Endpoint paths
  static const String signup = '/auth/signup';
  static const String signin = '/auth/signin';
  static const String inviteLogin = '/auth/invite-login';
  static const String profile = '/auth/profile';
  static const String courses = '/courses';
  static const String creditsDeduct = '/credits/deduct';
  static const String teamMembers = '/team/members';
  static const String teamInvite = '/team/invite';
  static const String teamAllocate = '/team/allocate';
  static const String teamUsage = '/team/usage';
  static const String creditsBalance = '/credits/balance';
  static const String creditsTopup = '/credits/topup';
  static const String creditsMyUsage = '/credits/my-usage';
  static const String subscriptionPlans = '/subscription/plans';
  static const String subscriptionStatus = '/subscription/status';
  static const String subscriptionPurchase = '/subscription/purchase';
  static const String logout = '/auth/logout';
  static const String setup = '/setup';
}
