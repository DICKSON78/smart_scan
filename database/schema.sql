-- =====================================================
-- Exam Mark Extractor - Database Schema
-- Database: u599372892_exams_db
-- =====================================================

CREATE TABLE IF NOT EXISTS `users` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `email` VARCHAR(255) NOT NULL UNIQUE,
  `password_hash` VARCHAR(255) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `is_admin` TINYINT(1) NOT NULL DEFAULT 1,
  `subscription_plan` VARCHAR(50) NOT NULL DEFAULT 'basic',
  `credits` INT NOT NULL DEFAULT 0,
  `institution_name` VARCHAR(255) DEFAULT NULL,
  `default_invite_credits` INT NOT NULL DEFAULT 500,
  `parent_admin_id` BIGINT UNSIGNED DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`parent_admin_id`) REFERENCES `users`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `user_tokens` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `token` VARCHAR(64) NOT NULL UNIQUE,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `expires_at` TIMESTAMP NULL DEFAULT NULL,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `invite_codes` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `code` VARCHAR(8) NOT NULL UNIQUE,
  `created_by` BIGINT UNSIGNED NOT NULL,
  `used_by` BIGINT UNSIGNED DEFAULT NULL,
  `used_at` TIMESTAMP NULL DEFAULT NULL,
  `invite_credits` INT NOT NULL DEFAULT 500,
  `expires_at` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`created_by`) REFERENCES `users`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`used_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `team_members` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `admin_id` BIGINT UNSIGNED NOT NULL,
  `teacher_id` BIGINT UNSIGNED NOT NULL,
  `allocated_credits` INT NOT NULL DEFAULT 0,
  `used_credits` INT NOT NULL DEFAULT 0,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `unique_team` (`admin_id`, `teacher_id`),
  FOREIGN KEY (`admin_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`teacher_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `courses` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `code` VARCHAR(50) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `created_by` BIGINT UNSIGNED NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `unique_code` (`code`),
  FOREIGN KEY (`created_by`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `subscription_plans` (
  `id` VARCHAR(50) PRIMARY KEY,
  `name` VARCHAR(100) NOT NULL,
  `price` VARCHAR(50) NOT NULL,
  `teacher_count` INT NOT NULL,
  `is_popular` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `plan_features` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `plan_id` VARCHAR(50) NOT NULL,
  `feature` VARCHAR(255) NOT NULL,
  FOREIGN KEY (`plan_id`) REFERENCES `subscription_plans`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed subscription plans
INSERT IGNORE INTO `subscription_plans` (`id`, `name`, `price`, `teacher_count`, `is_popular`) VALUES
('starter', 'Starter', 'Tshs 25,000', 2, 0),
('standard', 'Standard', 'Tshs 100,000', 5, 0),
('school', 'School', 'Tshs 180,000', 20, 1),
('institution', 'Institution', 'Tshs 800,000', 100, 0),
('unlimited', 'Unlimited', 'Tshs 1,300,000', 200, 0);

INSERT IGNORE INTO `plan_features` (`plan_id`, `feature`) VALUES
('starter', 'Up to 2 teachers'),
('starter', '1,000 scans'),
('starter', 'Single image processing'),
('starter', 'Standard Excel export'),
('starter', 'Subject grouping'),
('standard', 'Up to 5 teachers'),
('standard', '5,000 scans'),
('standard', 'Bulk image processing'),
('standard', 'Enhanced Excel export'),
('standard', 'Subject grouping'),
('standard', 'Priority support'),
('school', 'Up to 20 teachers'),
('school', '10,000 scans'),
('school', 'Bulk image processing'),
('school', 'Advanced Excel formatting'),
('school', 'Subject grouping'),
('school', 'Cloud backup'),
('school', 'Priority support'),
('institution', 'Up to 100 teachers'),
('institution', '50,000 scans'),
('institution', 'Bulk image processing'),
('institution', 'Advanced Excel formatting'),
('institution', 'Subject grouping'),
('institution', 'Invite teachers via code'),
('institution', 'Cloud backup'),
('institution', 'Dedicated support'),
('institution', 'Custom branding'),
('unlimited', 'Up to 200 teachers'),
('unlimited', 'Unlimited scans'),
('unlimited', 'Bulk image processing'),
('unlimited', 'Advanced Excel formatting'),
('unlimited', 'Subject grouping'),
('unlimited', 'Invite teachers via code'),
('unlimited', 'Cloud backup'),
('unlimited', 'Dedicated support'),
('unlimited', 'Custom branding');
