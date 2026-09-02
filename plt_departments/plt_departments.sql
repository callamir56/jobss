-- ============================================================
--  plt_departments (ESX Edition) — Database Schema
--  Import this file into your database (HeidiSQL / phpMyAdmin).
--  Note: the resource also auto-creates these tables on start,
--  so importing is optional but recommended.
-- ============================================================

-- ------------------------------------------------------------
-- Main data blob store (departments, warrants, bolos, cases...)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `plt_departments_data` (
    `key` VARCHAR(50) NOT NULL PRIMARY KEY,
    `value` LONGTEXT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ------------------------------------------------------------
-- Members / roster
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `plt_departments_members` (
    `cid` VARCHAR(50) NOT NULL PRIMARY KEY,
    `name` VARCHAR(100) DEFAULT NULL,
    `dept` VARCHAR(50) DEFAULT 'none',
    `grade` INT DEFAULT 0,
    `onDuty` TINYINT(1) DEFAULT 0,
    `lastClockOn` BIGINT DEFAULT 0,
    `totalTime` INT DEFAULT 0,
    `medals` LONGTEXT,
    `divisions` LONGTEXT,
    `ratings` LONGTEXT,
    INDEX `idx_dept` (`dept`),
    INDEX `idx_onduty` (`onDuty`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ------------------------------------------------------------
-- Warrants
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `plt_departments_warrants` (
    `id` BIGINT NOT NULL PRIMARY KEY,
    `subject` VARCHAR(100) NOT NULL,
    `charges` TEXT DEFAULT NULL,
    `priority` VARCHAR(20) DEFAULT 'Standard',
    `issuedBy` VARCHAR(100) DEFAULT NULL,
    `issuedDate` VARCHAR(50) DEFAULT NULL,
    `description` TEXT DEFAULT NULL,
    `status` VARCHAR(20) DEFAULT 'Active',
    INDEX `idx_subject` (`subject`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ------------------------------------------------------------
-- BOLOs
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `plt_departments_bolos` (
    `id` BIGINT NOT NULL PRIMARY KEY,
    `type` VARCHAR(50) DEFAULT 'Vehicle',
    `title` VARCHAR(100) NOT NULL,
    `description` TEXT DEFAULT NULL,
    `plate` VARCHAR(20) DEFAULT NULL,
    `owner` VARCHAR(100) DEFAULT NULL,
    `lastSeen` VARCHAR(255) DEFAULT NULL,
    `issuedBy` VARCHAR(100) DEFAULT NULL,
    `issuedDate` VARCHAR(50) DEFAULT NULL,
    `status` VARCHAR(20) DEFAULT 'Active',
    INDEX `idx_plate` (`plate`),
    INDEX `idx_title` (`title`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ------------------------------------------------------------
-- Case files
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `plt_departments_cases` (
    `id` BIGINT NOT NULL PRIMARY KEY,
    `title` VARCHAR(255) NOT NULL,
    `description` TEXT DEFAULT NULL,
    `summary` TEXT DEFAULT NULL,
    `status` VARCHAR(50) DEFAULT 'Open',
    `issuedBy` VARCHAR(100) DEFAULT NULL,
    `issuedDate` VARCHAR(50) DEFAULT NULL,
    `officers` TEXT DEFAULT NULL,
    INDEX `idx_case_title` (`title`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ------------------------------------------------------------
-- Duty logs
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `plt_departments_duty_logs` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `cid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(100) DEFAULT NULL,
    `officer` VARCHAR(100) DEFAULT NULL,
    `dept` VARCHAR(50) DEFAULT NULL,
    `action` VARCHAR(50) DEFAULT NULL,
    `time` VARCHAR(50) DEFAULT NULL,
    `date` VARCHAR(50) DEFAULT NULL,
    INDEX `idx_cid` (`cid`),
    INDEX `idx_dept` (`dept`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ------------------------------------------------------------
-- Financial transactions
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `plt_departments_transactions` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `deptId` VARCHAR(50) NOT NULL,
    `type` VARCHAR(50) NOT NULL,
    `amount` INT NOT NULL,
    `from_cid` VARCHAR(50) DEFAULT NULL,
    `from_name` VARCHAR(100) DEFAULT NULL,
    `to_cid` VARCHAR(50) DEFAULT NULL,
    `to_name` VARCHAR(100) DEFAULT NULL,
    `reason` TEXT DEFAULT NULL,
    `timestamp` BIGINT DEFAULT 0,
    INDEX `idx_tx_dept` (`deptId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ------------------------------------------------------------
-- Seized / impounded vehicles
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `plt_departments_seizures` (
    `plate` VARCHAR(20) NOT NULL PRIMARY KEY,
    `data` LONGTEXT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ------------------------------------------------------------
-- Radars
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `plt_departments_radars` (
    `id` VARCHAR(100) NOT NULL PRIMARY KEY,
    `data` LONGTEXT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ------------------------------------------------------------
-- Surveillance cameras
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `plt_departments_cameras` (
    `id` BIGINT NOT NULL PRIMARY KEY,
    `deptId` VARCHAR(50) NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `coords` TEXT NOT NULL,
    `heading` FLOAT DEFAULT 0.0,
    INDEX `idx_cam_dept` (`deptId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ------------------------------------------------------------
-- Vehicle trackers
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `plt_departments_trackers` (
    `plate` VARCHAR(20) NOT NULL PRIMARY KEY,
    `deptId` VARCHAR(50) NOT NULL,
    `model` VARCHAR(50) DEFAULT NULL,
    `placedBy` VARCHAR(100) DEFAULT NULL,
    `timestamp` BIGINT DEFAULT 0,
    INDEX `idx_tracker_dept` (`deptId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ------------------------------------------------------------
-- Inter-department communications (mail)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `plt_departments_comms` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `fromDept` VARCHAR(50) NOT NULL,
    `toDept` VARCHAR(50) NOT NULL,
    `senderName` VARCHAR(100) DEFAULT NULL,
    `message` TEXT DEFAULT NULL,
    `timestamp` BIGINT DEFAULT 0,
    INDEX `idx_from_dept` (`fromDept`),
    INDEX `idx_to_dept` (`toDept`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ============================================================
-- MDT sync tables (Config.MDT.customMappings reads from these)
-- ============================================================
CREATE TABLE IF NOT EXISTS `mdt_bolos` (
    `id` BIGINT NOT NULL PRIMARY KEY,
    `type` VARCHAR(50) DEFAULT 'Vehicle',
    `title` VARCHAR(100) NOT NULL,
    `description` TEXT DEFAULT NULL,
    `plate` VARCHAR(20) DEFAULT NULL,
    `owner` VARCHAR(100) DEFAULT NULL,
    `lastseen` VARCHAR(255) DEFAULT NULL,
    `author` VARCHAR(100) DEFAULT NULL,
    `date` VARCHAR(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mdt_warrants` (
    `id` BIGINT NOT NULL PRIMARY KEY,
    `title` VARCHAR(100) NOT NULL,
    `charges` TEXT DEFAULT NULL,
    `author` VARCHAR(100) DEFAULT NULL,
    `date` VARCHAR(50) DEFAULT NULL,
    `details` TEXT DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
