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
('basic', 'Basic', 'Free', 1, 0),
('advanced', 'Advanced', 'TSh 35,000', 3, 1),
('premium', 'Premium', 'TSh 70,000', 5, 0);

INSERT IGNORE INTO `plan_features` (`plan_id`, `feature`) VALUES
('basic', 'Single teacher access'),
('basic', '50 extractions (buy more at 100 TSh/scan)'),
('basic', 'Single image processing'),
('basic', 'Standard Excel export'),
('basic', 'Subject grouping'),
('advanced', 'Up to 3 teachers'),
('advanced', '350 credits included (100 TSh/scan)'),
('advanced', 'Bulk image processing'),
('advanced', 'Enhanced Excel export'),
('advanced', 'Subject grouping'),
('advanced', 'Invite teachers via code'),
('advanced', 'Share credits with team'),
('premium', 'Up to 5 teachers'),
('premium', '700 credits included (100 TSh/scan)'),
('premium', 'Bulk image processing'),
('premium', 'Advanced Excel formatting'),
('premium', 'Subject grouping'),
('premium', 'Invite teachers via code'),
('premium', 'Share credits with team'),
('premium', 'Cloud backup'),
('premium', 'Dedicated support');
