-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Aug 13, 2025 at 06:51 AM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `non_prod_crm_master_db`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `getCustomerList` ()   BEGIN
              -- Start building the SELECT query
              SET @query = 'SELECT DISTINCT c.id AS customer_id';

              -- Check if business_history table exists
              SET @business_history_exists = (
                  SELECT COUNT(*)
                  FROM INFORMATION_SCHEMA.TABLES
                  WHERE TABLE_NAME = 'business_history' 
                  AND TABLE_SCHEMA = DATABASE()
              );

              -- If business_history exists, join with it
              IF @business_history_exists > 0 THEN
                  -- If the table exists, the query should select from both tables
                  SET @query = CONCAT(@query, ' FROM customers c');
                  SET @query = CONCAT(@query, ' LEFT JOIN business_history bh ON bh.customer_id = c.id');
                  SET @query = CONCAT(@query, ' WHERE (bh.current_status = ''Service/ProductPurchased'' OR c.`group` = ''Customer'')');
              ELSE
                  -- If business_history does not exist, select only from customers
                  SET @query = CONCAT(@query, ' FROM customers c');
                  SET @query = CONCAT(@query, ' WHERE c.`group` = ''Customer''');
              END IF;

              -- Finalize the query
              SET @query = CONCAT(@query, ' ORDER BY c.id');

              -- Debug: Output the query for debugging purposes (in production, this can be removed)
              -- SELECT @query; -- Uncomment for debugging the query

              -- Execute the dynamically constructed query
              PREPARE stmt FROM @query;
              EXECUTE stmt;
              DEALLOCATE PREPARE stmt;
          END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getFollowUpList` (IN `from_date` DATE, IN `to_date` DATE)   BEGIN
        DECLARE column_exists BOOLEAN DEFAULT FALSE;

        -- Check if the column `follow_up_on` exists in the table `business_history`
        SELECT COUNT(1) INTO column_exists
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'business_history'
          AND COLUMN_NAME = 'follow_up_on'
          AND TABLE_SCHEMA = DATABASE();

        -- If the column exists, proceed with the query
        IF column_exists THEN
            SET @query = CONCAT(
                'SELECT DISTINCT bh.customer_id
                 FROM business_history bh
                 WHERE bh.current_status = "Followup"
                   AND DATE(bh.follow_up_on) BETWEEN "', from_date, '" AND "', to_date, '"
                   AND NOT EXISTS (
                       SELECT 1
                       FROM business_history bh_future
                       WHERE bh_future.customer_id = bh.customer_id
                         AND DATE(bh_future.follow_up_on) > "', to_date, '"
                   )'
            );

            -- Prepare and execute the dynamic query
            PREPARE stmt FROM @query;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;
        ELSE
            -- If the column doesn't exist, return an empty result set
            SELECT NULL WHERE FALSE;
        END IF;
    END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getLeadsList` (IN `from_date` DATE, IN `to_date` DATE)   BEGIN
            -- Initialize query parts
            SET @query1 = NULL;
            SET @query2 = NULL;
            SET @date_conditions = '';

            -- Check if business_history table exists
            SET @business_history_exists = (
                SELECT COUNT(*)
                FROM INFORMATION_SCHEMA.TABLES
                WHERE TABLE_NAME = 'business_history'
                AND TABLE_SCHEMA = DATABASE()
            );

            -- Query to get customers from business_history within date range
            IF @business_history_exists > 0 THEN
                -- Start constructing query1
                SET @query1 = 'SELECT DISTINCT bh.customer_id FROM business_history bh WHERE ';

                -- Check and add date range conditions dynamically
                IF EXISTS (
                    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
                    WHERE TABLE_SCHEMA = DATABASE() 
                    AND TABLE_NAME = 'business_history' 
                    AND COLUMN_NAME = 'hold_till'
                ) THEN
                    SET @date_conditions = CONCAT(@date_conditions, ' DATE(bh.hold_till) BETWEEN ''', from_date, ''' AND ''', to_date, ''' OR');
                END IF;

                IF EXISTS (
                    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
                    WHERE TABLE_SCHEMA = DATABASE() 
                    AND TABLE_NAME = 'business_history' 
                    AND COLUMN_NAME = 'schedule_on'
                ) THEN
                    SET @date_conditions = CONCAT(@date_conditions, ' DATE(bh.schedule_on) BETWEEN ''', from_date, ''' AND ''', to_date, ''' OR');
                END IF;

                IF EXISTS (
                    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
                    WHERE TABLE_SCHEMA = DATABASE() 
                    AND TABLE_NAME = 'business_history' 
                    AND COLUMN_NAME = 'follow_up_on'
                ) THEN
                    SET @date_conditions = CONCAT(@date_conditions, ' DATE(bh.follow_up_on) BETWEEN ''', from_date, ''' AND ''', to_date, ''' OR');
                END IF;

                -- Remove trailing OR and finalize query1
                IF LENGTH(@date_conditions) > 0 THEN
                    SET @date_conditions = LEFT(@date_conditions, LENGTH(@date_conditions) - 3);
                    SET @query1 = CONCAT(@query1, @date_conditions);
                ELSE
                    -- If no valid date columns exist, do not use business_history query
                    SET @query1 = NULL;
                END IF;
            END IF;

            -- Query to get customers from customers table where group = 'Leads'
            SET @query2 = 'SELECT DISTINCT c.id AS customer_id FROM customers c WHERE c.`group` = ''Leads''';

            -- Final query: Combine both queries with UNION to get distinct customer_id
            SET @final_query = '';

            IF @query1 IS NOT NULL THEN
                SET @final_query = CONCAT('(', @query1, ') UNION ALL (', @query2, ')');
            ELSE
                SET @final_query = @query2; -- If business_history does not exist or no valid date columns exist, use only customers query
            END IF;

            -- Finalizing with DISTINCT to remove duplicates
            SET @final_query = CONCAT('SELECT DISTINCT customer_id FROM (', @final_query, ') AS combined_result ORDER BY customer_id');

            -- Debug: Uncomment to check query output
            -- SELECT @final_query;

            -- Execute the dynamically constructed query
            PREPARE stmt FROM @final_query;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;
        END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getMostLiklyList` (IN `from_date` DATE, IN `to_date` DATE)   BEGIN
              -- Start building the SELECT query
              SET @query = 'SELECT DISTINCT bh.customer_id, bh.current_status';

              -- Variable to track if any columns exist
              SET @columns_exist = FALSE;

              -- Check and add columns dynamically
              IF EXISTS (
                  SELECT 1 
                  FROM INFORMATION_SCHEMA.COLUMNS 
                  WHERE TABLE_NAME = 'business_history' 
                  AND COLUMN_NAME = 'hold_till' 
                  AND TABLE_SCHEMA = DATABASE()
              ) THEN
                  SET @query = CONCAT(@query, ', bh.hold_till');
                  SET @columns_exist = TRUE;
              END IF;

              IF EXISTS (
                  SELECT 1 
                  FROM INFORMATION_SCHEMA.COLUMNS 
                  WHERE TABLE_NAME = 'business_history' 
                  AND COLUMN_NAME = 'tentative_revisit' 
                  AND TABLE_SCHEMA = DATABASE()
              ) THEN
                  SET @query = CONCAT(@query, ', bh.tentative_revisit');
                  SET @columns_exist = TRUE;
              END IF;

              -- Check if no relevant columns exist
              IF @columns_exist = FALSE THEN
                  -- No columns to include, return an empty result set
                  SET @query = 'SELECT NULL AS customer_id, NULL AS current_status, NULL AS hold_till, NULL AS tentative_revisit WHERE FALSE';
              ELSE
                  -- Add the FROM clause
                  SET @query = CONCAT(@query, ' FROM business_history bh WHERE bh.is_deleted = 0');

                  -- Add conditions dynamically
                  SET @condition = '';

                  -- Adjust from_date and to_date with ±2 days
                  IF from_date IS NOT NULL AND to_date IS NOT NULL THEN
                      SET @adjusted_from_date = DATE_SUB(from_date, INTERVAL 2 DAY);
                      SET @adjusted_to_date = DATE_ADD(to_date, INTERVAL 2 DAY);
                  ELSE
                      SET @adjusted_from_date = DATE_SUB(CURRENT_DATE, INTERVAL 2 DAY);
                      SET @adjusted_to_date = DATE_ADD(CURRENT_DATE, INTERVAL 2 DAY);
                  END IF;

                  -- Check if `hold_till` exists before adding the condition
                  IF EXISTS (
                      SELECT 1
                      FROM INFORMATION_SCHEMA.COLUMNS
                      WHERE TABLE_NAME = 'business_history'
                      AND COLUMN_NAME = 'hold_till'
                      AND TABLE_SCHEMA = DATABASE()
                  ) THEN
                      SET @condition = CONCAT(@condition, ' DATE(bh.hold_till) BETWEEN ''', @adjusted_from_date, ''' AND ''', @adjusted_to_date, '''');
                  END IF;

                  -- Check if `tentative_revisit` exists before adding the condition
                  IF EXISTS (
                      SELECT 1
                      FROM INFORMATION_SCHEMA.COLUMNS
                      WHERE TABLE_NAME = 'business_history'
                      AND COLUMN_NAME = 'tentative_revisit'
                      AND TABLE_SCHEMA = DATABASE()
                  ) THEN
                      SET @condition = CONCAT(@condition, 
                          IF(@condition != '', ' OR ', ''), 
                          ' DATE(bh.tentative_revisit) BETWEEN ''', @adjusted_from_date, ''' AND ''', @adjusted_to_date, ''''
                      );
                  END IF;

                  -- If there is any condition, wrap it in parentheses and append it
                  IF @condition != '' THEN
                      SET @query = CONCAT(@query, ' AND (', @condition, ')');
                  END IF;

                  -- Add the condition for `current_status`
                  SET @query = CONCAT(@query, ' AND bh.current_status IN (''Hold'', ''Service/ProductPurchased'')');
              END IF;

              -- Execute the dynamically constructed query
              PREPARE stmt FROM @query;
              EXECUTE stmt;
              DEALLOCATE PREPARE stmt;
          END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getScheduleList` (IN `from_date` DATE, IN `to_date` DATE)   BEGIN
          SELECT DISTINCT a1.customer_id
          FROM appointment a1
          WHERE a1.is_deleted = 0
            AND (
              -- Apply date range filter if provided
              (
                from_date IS NOT NULL AND to_date IS NOT NULL 
                AND DATE(STR_TO_DATE(a1.date, '%Y-%m-%d %H:%i:%s')) 
                    BETWEEN STR_TO_DATE(from_date, '%Y-%m-%d') 
                    AND STR_TO_DATE(to_date, '%Y-%m-%d')
              )
              OR 
              -- If no date range is provided, default to today
              (
                (from_date IS NULL OR from_date = '') 
                AND (to_date IS NULL OR to_date = '') 
                AND DATE(STR_TO_DATE(a1.date, '%Y-%m-%d %H:%i:%s')) = CURDATE()
              )
            )
            AND NOT EXISTS (
              SELECT 1
              FROM appointment a2
              WHERE a2.customer_id = a1.customer_id
                AND STR_TO_DATE(a2.date, '%Y-%m-%d %H:%i:%s') > STR_TO_DATE(a1.date, '%Y-%m-%d %H:%i:%s')
                AND a2.is_deleted = 0
            );
      END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `getStatusNotUpdatedList` (IN `from_date` DATE, IN `to_date` DATE)   BEGIN
          -- Declare variables
          DECLARE business_history_exists INT DEFAULT 0;
          DECLARE sql_query TEXT;

          -- Check if `business_history` table exists
          SET business_history_exists = (SELECT COUNT(*)
                                         FROM information_schema.tables
                                         WHERE table_schema = DATABASE()
                                         AND table_name = 'business_history');

          -- Start building the query
          IF business_history_exists = 1 THEN
              -- If `business_history` exists, apply the full logic
              SET sql_query = 'SELECT DISTINCT bh.customer_id
                               FROM business_history bh
                               INNER JOIN (
                                   SELECT ch.customer_id, MAX(ch.timestamp) AS latest_call
                                   FROM call_history ch
                                   WHERE ch.duration > 0
                                   AND DATE(ch.timestamp) BETWEEN '''; 

              -- Add date range dynamically
              SET sql_query = CONCAT(sql_query, from_date, ''' AND ''', to_date, ''' 
                                   GROUP BY ch.customer_id
                               ) latest_calls
                               ON bh.customer_id = latest_calls.customer_id
                               WHERE bh.current_status IN (''Hold'', ''Schedule'', ''Followup'')');

              -- Check if created_at or updated_at is greater than latest call timestamp
              SET sql_query = CONCAT(sql_query, ' AND NOT EXISTS (
                                                    SELECT 1
                                                    FROM business_history bh2
                                                    WHERE bh2.customer_id = bh.customer_id
                                                    AND (
                                                        bh2.created_at > latest_calls.latest_call
                                                        OR bh2.updated_at > latest_calls.latest_call
                                                    )
                                                    AND (DATE(bh2.created_at) BETWEEN ''', from_date, ''' AND ''', to_date, '''
                                                    OR DATE(bh2.updated_at) BETWEEN ''', from_date, ''' AND ''', to_date, ''')
                                                  )');

              -- Now, also check for customers with `group` as `Leads` or `Customer`
              SET sql_query = CONCAT(sql_query, ' UNION 
                                                  SELECT DISTINCT c.id AS customer_id
                                                  FROM call_history ch
                                                  INNER JOIN customers c ON ch.customer_id = c.id
                                                  WHERE ch.duration > 0
                                                  AND c.group IN (''Leads'', ''Customer'')
                                                  AND DATE(ch.timestamp) BETWEEN ''', from_date, ''' AND ''', to_date, '''
                                                  AND NOT EXISTS (
                                                      SELECT 1
                                                      FROM business_history bh3
                                                      WHERE bh3.customer_id = c.id
                                                      AND (
                                                          bh3.created_at > ch.timestamp
                                                          OR bh3.updated_at > ch.timestamp
                                                      )
                                                      AND (DATE(bh3.created_at) BETWEEN ''', from_date, ''' AND ''', to_date, '''
                                                      OR DATE(bh3.updated_at) BETWEEN ''', from_date, ''' AND ''', to_date, ''')
                                                  )');
          ELSE
              -- If `business_history` does not exist, fetch only from `call_history` and `customers`
              SET sql_query = 'SELECT DISTINCT c.id AS customer_id
                               FROM call_history ch
                               INNER JOIN customers c ON ch.customer_id = c.id
                               WHERE ch.duration > 0
                               AND c.group IN (''Leads'', ''Customer'')
                               AND DATE(ch.timestamp) BETWEEN '''; 

              -- Add date range dynamically
              SET sql_query = CONCAT(sql_query, from_date, ''' AND ''', to_date, '''');
          END IF;

          -- Prepare and execute the query
          PREPARE dynamic_query FROM sql_query;
          EXECUTE dynamic_query;
          DEALLOCATE PREPARE dynamic_query;
      END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `ai_feature_list`
--

CREATE TABLE `ai_feature_list` (
  `id` int(11) NOT NULL,
  `name` varchar(100) DEFAULT NULL,
  `description` varchar(250) DEFAULT NULL,
  `module_id` bigint(20) DEFAULT NULL,
  `uid` varchar(50) DEFAULT NULL,
  `status` tinyint(4) DEFAULT 1,
  `is_deleted` tinyint(4) DEFAULT 0,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `apks`
--

CREATE TABLE `apks` (
  `id` int(11) NOT NULL,
  `version` varchar(100) NOT NULL,
  `type` varchar(100) NOT NULL,
  `message` text DEFAULT NULL,
  `force_update` tinyint(1) NOT NULL DEFAULT 0,
  `file_path` varchar(250) DEFAULT NULL,
  `download_password` varchar(50) DEFAULT NULL,
  `status` int(11) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `apks`
--

INSERT INTO `apks` (`id`, `version`, `type`, `message`, `force_update`, `file_path`, `download_password`, `status`, `created_at`, `updated_at`) VALUES
(1, '1.0.1', 'non-prod', '', 0, 'public/apks/APK_1.0.0_non-prod_waqin.ai.non-prod.apk', NULL, 1, '2025-02-20 05:19:10', '2025-06-06 06:07:29'),
(2, '1.0.16', 'non prod', 'New update is available, update to the newest version', 1, NULL, NULL, 1, '2025-06-06 07:32:52', '2025-06-06 07:32:52'),
(3, '1.0.16', 'android', 'New update is available, update to the newest version', 0, NULL, NULL, 1, '2025-06-06 08:15:05', '2025-06-06 08:15:05'),
(4, '1.0.16', 'android', 'New update is available, update to the newest version', 0, NULL, NULL, 1, '2025-06-06 08:15:05', '2025-06-06 08:15:05'),
(5, '1.0.18', 'android', 'An app update is needed to improve the user experience', 1, NULL, NULL, 1, '2025-06-06 09:13:20', '2025-06-06 09:13:20'),
(6, '1.0.16', 'android', 'we need update', 0, NULL, NULL, 1, '2025-06-06 09:19:47', '2025-06-06 09:19:47'),
(7, '1.0.17', 'android', 'to jh', 0, NULL, NULL, 1, '2025-06-06 14:49:04', '2025-06-06 14:49:04'),
(8, '1.0.17', 'android', 'update your app to enhance user experience', 1, NULL, NULL, 1, '2025-06-06 14:51:05', '2025-06-06 14:51:05'),
(9, '1.0.16', 'android', 'tyty', 0, NULL, NULL, 1, '2025-06-06 14:51:39', '2025-06-06 14:51:39'),
(10, '1.0.17', 'android', 'your app now nedkjd', 0, NULL, NULL, 1, '2025-06-06 15:00:01', '2025-06-06 15:00:01'),
(11, '1.0.16', 'android', 'no update', 0, NULL, NULL, 1, '2025-06-06 15:34:57', '2025-06-06 15:34:57'),
(12, '1.0.19', 'android', 'we', 1, NULL, NULL, 1, '2025-07-07 08:09:57', '2025-07-07 08:09:57'),
(13, '1.0.20', 'android', 's', 1, NULL, NULL, 1, '2025-07-07 08:10:26', '2025-07-07 08:10:26'),
(14, '1.0.19', 'android', 'no Updates', 0, NULL, NULL, 1, '2025-07-07 08:11:22', '2025-07-07 08:11:22');

-- --------------------------------------------------------

--
-- Table structure for table `appointment`
--

CREATE TABLE `appointment` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `status` tinyint(1) NOT NULL DEFAULT 1,
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `phone` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `date` varchar(255) DEFAULT NULL,
  `looking_for` varchar(255) DEFAULT NULL,
  `assignedTo` varchar(255) DEFAULT NULL,
  `customer_id` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `appointment`
--

INSERT INTO `appointment` (`id`, `status`, `is_deleted`, `created_at`, `updated_at`, `phone`, `name`, `date`, `looking_for`, `assignedTo`, `customer_id`) VALUES
(1, 1, 0, '2025-08-12 06:46:42', '2025-08-12 06:46:42', '9677003373', 'Carvewing Yoga', '2025-08-13 12:16:00 PM', NULL, 'null', '248');

-- --------------------------------------------------------

--
-- Table structure for table `app_permissions`
--

CREATE TABLE `app_permissions` (
  `id` int(11) NOT NULL,
  `permission_key` varchar(100) NOT NULL,
  `module` varchar(50) DEFAULT NULL,
  `permission_group` varchar(50) DEFAULT NULL,
  `android_permissions` text DEFAULT NULL,
  `purpose` text NOT NULL,
  `usage_description` text NOT NULL,
  `user_control` text DEFAULT NULL,
  `is_optional` tinyint(1) DEFAULT 1,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `app_permissions`
--

INSERT INTO `app_permissions` (`id`, `permission_key`, `module`, `permission_group`, `android_permissions`, `purpose`, `usage_description`, `user_control`, `is_optional`, `created_at`, `updated_at`) VALUES
(8, 'CONTACT_ACCESS', 'CRM', 'Contacts', 'READ_CONTACTS,WRITE_CONTACTS', 'To allow you to view, add, or manage client contact information within the CRM dashboard.', 'The app reads contacts to display customer information and allows you to add new leads or update details.', 'You can revoke contact access at any time from your device settings.', 0, '2025-07-04 04:15:39', '2025-07-04 05:06:56'),
(9, 'CALL_LOG_ACCESS', 'CRM', 'Call Log', 'READ_CALL_LOG', 'To log and track client interactions, including incoming and outgoing call history.', 'This helps CRM users automatically record call activity with clients for future reference or follow-up.', 'You may deny this permission; the app will continue to work with limited functionality.', 1, '2025-07-04 04:16:04', '2025-07-04 05:07:02'),
(10, 'PHONE_STATE_ACCESS', 'CRM', 'Phone State', 'READ_PHONE_STATE', 'To identify call state and associate real-time call data with CRM records (e.g., call-in progress).', 'Used strictly to enhance communication logging for CRM users.', 'Optional for most features unless real-time call handling is used.', 1, '2025-07-04 04:18:29', '2025-07-04 05:10:46'),
(11, 'LOCATION_ACCESS', 'Billing', 'Location', 'ACCESS_FINE_LOCATION,ACCESS_COARSE_LOCATION', 'To capture the precise location of a business when the business owner or tenant uploads images of their premises.', 'Location is accessed only during the image upload process by business owners/tenants to tag the business\'s physical location.', NULL, 1, '2025-07-04 04:19:21', '2025-07-04 04:19:21'),
(12, 'MEDIA_ACCESS', 'Billing', 'Camera and Media', 'CAMERA,READ_MEDIA_IMAGES', 'To allow users to upload images for products, services, marketing templates, and billing references.', 'Access is used only when uploading media manually. The app does not access photos or use the camera in the background.', NULL, 1, '2025-07-04 04:19:21', '2025-07-04 04:19:21'),
(13, 'NOTIFICATION_ACCESS', 'System', 'Notifications', 'POST_NOTIFICATIONS', 'To send you important alerts about new tasks, reminders, or updates from your account.', 'You can manage notification preferences from within the app settings.', NULL, 1, '2025-07-04 04:19:21', '2025-07-04 05:06:39'),
(14, 'AD_ID_ACCESS', 'System', 'Analytics', 'com.google.android.gms.permission.AD_ID', 'Used to support internal analytics and improve app performance. We do not show third-party ads.', 'Used internally for analytics, not affecting user-facing features.', NULL, 1, '2025-07-04 04:21:03', '2025-07-04 05:06:41');

-- --------------------------------------------------------

--
-- Table structure for table `bill_items`
--

CREATE TABLE `bill_items` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `document_id` bigint(20) UNSIGNED NOT NULL,
  `item_name` varchar(255) NOT NULL,
  `qty` int(11) NOT NULL,
  `mrp` decimal(10,2) NOT NULL,
  `offer` decimal(10,2) NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `total_amount` decimal(10,2) NOT NULL,
  `employee_percentage` decimal(5,2) DEFAULT NULL,
  `product_id` bigint(20) UNSIGNED DEFAULT NULL,
  `service_id` bigint(20) UNSIGNED DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `bill_items`
--

INSERT INTO `bill_items` (`id`, `document_id`, `item_name`, `qty`, `mrp`, `offer`, `amount`, `total_amount`, `employee_percentage`, `product_id`, `service_id`, `created_at`, `updated_at`) VALUES
(1, 1, 'Designer saree', 1, 3500.00, 2999.00, 2999.00, 2999.00, 0.00, 2, NULL, '2025-08-12 06:46:41', '2025-08-12 06:46:41'),
(2, 1, 'Bridal lehanga', 1, 2500.00, 1500.00, 1500.00, 1680.00, 0.00, 1, NULL, '2025-08-12 06:46:41', '2025-08-12 06:46:41');

-- --------------------------------------------------------

--
-- Table structure for table `boutique_design_areas`
--

CREATE TABLE `boutique_design_areas` (
  `id` int(10) UNSIGNED NOT NULL,
  `item_id` int(10) UNSIGNED NOT NULL,
  `name` varchar(100) NOT NULL,
  `status` tinyint(4) NOT NULL DEFAULT 1,
  `is_deleted` tinyint(4) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `boutique_design_areas`
--

INSERT INTO `boutique_design_areas` (`id`, `item_id`, `name`, `status`, `is_deleted`) VALUES
(1, 1, 'Sleeve Type', 1, 0),
(2, 1, 'Front Neck Design', 1, 0),
(3, 2, 'Sleeve Type', 1, 0),
(4, 2, 'Front Neck Design', 1, 0),
(5, 3, 'Sleeve Type', 1, 0),
(6, 3, 'Neck Design', 1, 0),
(7, 3, 'Style Type', 1, 0),
(8, 4, 'Sleeve Type', 1, 0),
(9, 4, 'Neck Design', 1, 0),
(10, 4, 'Closure Type', 1, 0),
(11, 5, 'Waist Type', 1, 0),
(12, 5, 'Fit Type', 1, 0),
(13, 5, 'Length Type', 1, 0),
(14, 6, 'Salwar Type', 1, 0),
(15, 6, 'Kameez Style', 1, 0),
(16, 6, 'Neck Design', 1, 0),
(17, 7, 'Cutting', 1, 0),
(18, 7, 'Lock Type', 1, 0),
(19, 7, 'Lining', 1, 0),
(20, 8, 'Sleeve Type', 1, 0),
(21, 8, 'Collar Type', 1, 0),
(22, 8, 'Fit Type', 1, 0),
(23, 9, 'Side Pocket Type', 1, 0),
(24, 9, 'Pleats', 1, 0),
(25, 9, 'Number of Back Pockets', 1, 0),
(26, 10, 'Waist Type', 1, 0),
(27, 10, 'Length Type', 1, 0),
(28, 10, 'Material Type', 1, 0);

-- --------------------------------------------------------

--
-- Table structure for table `boutique_design_options`
--

CREATE TABLE `boutique_design_options` (
  `id` int(10) UNSIGNED NOT NULL,
  `design_area_id` int(10) UNSIGNED NOT NULL,
  `name` varchar(100) NOT NULL,
  `image_url` text DEFAULT NULL,
  `price` decimal(10,2) NOT NULL DEFAULT 0.00,
  `stagePrices` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`stagePrices`)),
  `is_default` tinyint(1) DEFAULT 0,
  `display_order` int(11) NOT NULL,
  `status` tinyint(4) NOT NULL DEFAULT 1,
  `is_deleted` tinyint(4) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `boutique_design_options`
--

INSERT INTO `boutique_design_options` (`id`, `design_area_id`, `name`, `image_url`, `price`, `stagePrices`, `is_default`, `display_order`, `status`, `is_deleted`) VALUES
(1, 1, 'Half', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M20 30 Q15 25 15 35 L15 55 Q15 60 20 60 L35 60 L35 85 Q35 90 40 90 L60 90 Q65 90 65 85 L65 60 L80 60 Q85 60 85 55 L85 35 Q85 25 80 30 L65 35 L65 25 Q65 20 60 20 L40 20 Q35 20 35 25 L35 35 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 1, 1, 1, 0),
(2, 1, 'Full', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M20 30 Q15 25 15 35 L15 75 Q15 80 20 80 L25 80 L25 85 Q25 90 30 90 L35 90 L35 85 L35 60 L65 60 L65 85 L70 90 Q75 90 75 85 L75 80 L80 80 Q85 80 85 75 L85 35 Q85 25 80 30 L65 35 L65 25 Q65 20 60 20 L40 20 Q35 20 35 25 L35 35 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 2, 1, 0),
(3, 1, 'No', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M35 25 Q35 20 40 20 L60 20 Q65 20 65 25 L65 85 Q65 90 60 90 L40 90 Q35 90 35 85 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 3, 1, 0),
(4, 1, 'Cap', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M25 30 Q20 25 20 35 L20 45 Q20 50 25 50 L35 50 L35 85 Q35 90 40 90 L60 90 Q65 90 65 85 L65 50 L75 50 Q80 50 80 45 L80 35 Q80 25 75 30 L65 35 L65 25 Q65 20 60 20 L40 20 Q35 20 35 25 L35 35 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 4, 1, 0),
(5, 2, 'U-Neck', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M30 20 L30 45 Q30 60 50 60 Q70 60 70 45 L70 20\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><circle cx=\"50\" cy=\"25\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 1, 1, 0),
(6, 2, 'V-Neck', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M30 20 L50 50 L70 20\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><circle cx=\"50\" cy=\"40\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 2, 1, 0),
(7, 2, 'Boat Neck', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M25 35 Q50 25 75 35\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><circle cx=\"50\" cy=\"30\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 3, 1, 0),
(8, 2, 'Basket', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M30 20 L30 35 Q30 45 40 45 L60 45 Q70 45 70 35 L70 20\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><rect x=\"40\" y=\"30\" width=\"20\" height=\"3\" fill=\"#e48e42\" rx=\"1\"/></svg>', 0.00, NULL, 0, 4, 1, 0),
(9, 2, 'Wide Square', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M25 20 L25 40 L75 40 L75 20\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\" strokeLinejoin=\"round\"/><rect x=\"45\" y=\"25\" width=\"10\" height=\"3\" fill=\"#e48e42\" rx=\"1\"/></svg>', 0.00, NULL, 0, 5, 1, 0),
(10, 2, 'Halter', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M40 50 Q50 20 50 20 Q50 20 60 50\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><circle cx=\"50\" cy=\"25\" r=\"3\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 6, 1, 0),
(11, 2, 'Collar', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M30 20 L30 30 Q30 35 35 35 L65 35 Q70 35 70 30 L70 20\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><path d=\"M35 25 L50 30 L65 25\" fill=\"none\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 7, 1, 0),
(12, 2, 'Round', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><circle cx=\"50\" cy=\"35\" r=\"15\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\"/><circle cx=\"50\" cy=\"30\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 8, 1, 0),
(13, 2, 'Deep U', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M30 20 L30 50 Q30 70 50 70 Q70 70 70 50 L70 20\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><circle cx=\"50\" cy=\"35\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 9, 1, 0),
(14, 2, '5 Corner Neck', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M30 20 L40 30 L50 25 L60 30 L70 20\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\" strokeLinejoin=\"round\"/><circle cx=\"50\" cy=\"27\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 1, 10, 1, 0),
(15, 2, 'Sweet Heart', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M30 30 Q30 20 40 25 Q50 30 50 40 Q50 30 60 25 Q70 20 70 30 Q70 40 50 50\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 11, 1, 0),
(16, 3, 'Half', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M20 30 Q15 25 15 35 L15 55 Q15 60 20 60 L35 60 L35 85 Q35 90 40 90 L60 90 Q65 90 65 85 L65 60 L80 60 Q85 60 85 55 L85 35 Q85 25 80 30 L65 35 L65 25 Q65 20 60 20 L40 20 Q35 20 35 25 L35 35 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 1, 1, 0),
(17, 3, 'Full', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M20 30 Q15 25 15 35 L15 75 Q15 80 20 80 L25 80 L25 85 Q25 90 30 90 L35 90 L35 85 L35 60 L65 60 L65 85 L70 90 Q75 90 75 85 L75 80 L80 80 Q85 80 85 75 L85 35 Q85 25 80 30 L65 35 L65 25 Q65 20 60 20 L40 20 Q35 20 35 25 L35 35 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 2, 1, 0),
(18, 3, 'No', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M35 25 Q35 20 40 20 L60 20 Q65 20 65 25 L65 85 Q65 90 60 90 L40 90 Q35 90 35 85 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 3, 1, 0),
(19, 3, 'Cap', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M25 30 Q20 25 20 35 L20 45 Q20 50 25 50 L35 50 L35 85 Q35 90 40 90 L60 90 Q65 90 65 85 L65 50 L75 50 Q80 50 80 45 L80 35 Q80 25 75 30 L65 35 L65 25 Q65 20 60 20 L40 20 Q35 20 35 25 L35 35 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 4, 1, 0),
(20, 4, 'U-Neck', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M30 20 L30 45 Q30 60 50 60 Q70 60 70 45 L70 20\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><circle cx=\"50\" cy=\"25\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 1, 1, 0),
(21, 4, 'V-Neck', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M30 20 L50 50 L70 20\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><circle cx=\"50\" cy=\"40\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 2, 1, 0),
(22, 4, 'Boat Neck', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M25 35 Q50 25 75 35\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><circle cx=\"50\" cy=\"30\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 3, 1, 0),
(23, 4, 'Basket', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M30 20 L30 35 Q30 45 40 45 L60 45 Q70 45 70 35 L70 20\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><rect x=\"40\" y=\"30\" width=\"20\" height=\"3\" fill=\"#e48e42\" rx=\"1\"/></svg>', 0.00, NULL, 0, 4, 1, 0),
(24, 4, 'Wide Square', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M25 20 L25 40 L75 40 L75 20\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\" strokeLinejoin=\"round\"/><rect x=\"45\" y=\"25\" width=\"10\" height=\"3\" fill=\"#e48e42\" rx=\"1\"/></svg>', 0.00, NULL, 0, 5, 1, 0),
(25, 4, 'Halter', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M40 50 Q50 20 50 20 Q50 20 60 50\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><circle cx=\"50\" cy=\"25\" r=\"3\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 6, 1, 0),
(26, 4, 'Collar', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M30 20 L30 30 Q30 35 35 35 L65 35 Q70 35 70 30 L70 20\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><path d=\"M35 25 L50 30 L65 25\" fill=\"none\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 7, 1, 0),
(27, 4, 'Round', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><circle cx=\"50\" cy=\"35\" r=\"15\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\"/><circle cx=\"50\" cy=\"30\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 8, 1, 0),
(28, 4, 'Deep U', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M30 20 L30 50 Q30 70 50 70 Q70 70 70 50 L70 20\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><circle cx=\"50\" cy=\"35\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 9, 1, 0),
(29, 4, '5 Corner Neck', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M30 20 L40 30 L50 25 L60 30 L70 20\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\" strokeLinejoin=\"round\"/><circle cx=\"50\" cy=\"27\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 10, 1, 0),
(30, 4, 'Sweet Heart', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M30 30 Q30 20 40 25 Q50 30 50 40 Q50 30 60 25 Q70 20 70 30 Q70 40 50 50\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 11, 1, 0),
(31, 5, 'Half', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M20 30 Q15 25 15 35 L15 55 Q15 60 20 60 L35 60 L35 85 Q35 90 40 90 L60 90 Q65 90 65 85 L65 60 L80 60 Q85 60 85 55 L85 35 Q85 25 80 30 L65 35 L65 25 Q65 20 60 20 L40 20 Q35 20 35 25 L35 35 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 1, 1, 0),
(32, 5, 'Full', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M20 30 Q15 25 15 35 L15 75 Q15 80 20 80 L25 80 L25 85 Q25 90 30 90 L35 90 L35 85 L35 60 L65 60 L65 85 L70 90 Q75 90 75 85 L75 80 L80 80 Q85 80 85 75 L85 35 Q85 25 80 30 L65 35 L65 25 Q65 20 60 20 L40 20 Q35 20 35 25 L35 35 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 2, 1, 0),
(33, 5, '3/4th', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M20 30 Q15 25 15 35 L15 65 Q15 70 20 70 L30 70 L30 85 Q30 90 35 90 L40 90 L40 85 L40 60 L60 60 L60 85 L65 90 Q70 90 70 85 L70 70 L80 70 Q85 70 85 65 L85 35 Q85 25 80 30 L60 35 L60 25 Q60 20 55 20 L45 20 Q40 20 40 25 L40 35 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 3, 1, 0),
(34, 5, 'Sleeveless', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M40 25 Q40 20 45 20 L55 20 Q60 20 60 25 L60 85 Q60 90 55 90 L45 90 Q40 90 40 85 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 4, 1, 0),
(35, 5, 'Cap', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M25 30 Q20 25 20 35 L20 45 Q20 50 25 50 L35 50 L35 85 Q35 90 40 90 L60 90 Q65 90 65 85 L65 50 L75 50 Q80 50 80 45 L80 35 Q80 25 75 30 L65 35 L65 25 Q65 20 60 20 L40 20 Q35 20 35 25 L35 35 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 5, 1, 0),
(36, 5, 'Bell', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M15 30 Q10 25 10 35 L10 75 Q10 85 25 85 L35 85 L35 60 L65 60 L65 85 L75 85 Q90 85 90 75 L90 35 Q90 25 85 30 L65 35 L65 25 Q65 20 60 20 L40 20 Q35 20 35 25 L35 35 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 6, 1, 0),
(37, 6, 'Round Neck', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><circle cx=\"50\" cy=\"35\" r=\"12\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\"/><circle cx=\"50\" cy=\"30\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 1, 1, 0),
(38, 6, 'Boat Neck', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M25 35 Q50 25 75 35\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><circle cx=\"50\" cy=\"30\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 2, 1, 0),
(39, 6, 'V-Neck', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M30 20 L50 50 L70 20\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><circle cx=\"50\" cy=\"40\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 3, 1, 0),
(40, 6, 'Collar Neck', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M30 20 L30 30 Q30 35 35 35 L65 35 Q70 35 70 30 L70 20\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><path d=\"M35 25 L50 30 L65 25\" fill=\"none\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 4, 1, 0),
(41, 6, 'Keyhole Neck', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><circle cx=\"50\" cy=\"30\" r=\"8\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"3\"/><path d=\"M50 38 L50 50\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><circle cx=\"50\" cy=\"25\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 5, 1, 0),
(42, 6, 'Square Neck', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"35\" y=\"25\" width=\"30\" height=\"20\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" rx=\"2\"/><rect x=\"47\" y=\"30\" width=\"6\" height=\"3\" fill=\"#e48e42\" rx=\"1\"/></svg>', 0.00, NULL, 0, 6, 1, 0),
(43, 7, 'A-Line Kurti', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M40 20 L60 20 L75 80 L25 80 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 1, 1, 0),
(44, 7, 'Straight Kurti', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"35\" y=\"20\" width=\"30\" height=\"60\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"5\"/></svg>', 0.00, NULL, 0, 2, 1, 0),
(45, 7, 'Anarkali Kurti', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M40 20 L60 20 L65 50 Q65 60 75 65 L80 80 L20 80 L25 65 Q35 60 35 50 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 3, 1, 0),
(46, 7, 'High-Low Kurti', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M40 20 L60 20 L60 60 L75 80 L50 70 L25 80 L40 60 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 4, 1, 0),
(47, 7, 'Flared Kurti', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M40 20 L60 20 L60 50 L70 80 L30 80 L40 50 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 5, 1, 0),
(48, 7, 'Panelled Kurti', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M35 20 L65 20 L70 80 L30 80 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><line x1=\"42\" y1=\"20\" x2=\"38\" y2=\"80\" stroke=\"#e48e42\" strokeWidth=\"2\"/><line x1=\"50\" y1=\"20\" x2=\"50\" y2=\"80\" stroke=\"#e48e42\" strokeWidth=\"2\"/><line x1=\"58\" y1=\"20\" x2=\"62\" y2=\"80\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 6, 1, 0),
(49, 8, 'Half', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M20 30 Q15 25 15 35 L15 55 Q15 60 20 60 L35 60 L35 85 Q35 90 40 90 L60 90 Q65 90 65 85 L65 60 L80 60 Q85 60 85 55 L85 35 Q85 25 80 30 L65 35 L65 25 Q65 20 60 20 L40 20 Q35 20 35 25 L35 35 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 1, 1, 0),
(50, 8, 'Full', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M20 30 Q15 25 15 35 L15 75 Q15 80 20 80 L25 80 L25 85 Q25 90 30 90 L35 90 L35 85 L35 60 L65 60 L65 85 L70 90 Q75 90 75 85 L75 80 L80 80 Q85 80 85 75 L85 35 Q85 25 80 30 L65 35 L65 25 Q65 20 60 20 L40 20 Q35 20 35 25 L35 35 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 2, 1, 0),
(51, 8, 'Sleeveless', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M40 25 Q40 20 45 20 L55 20 Q60 20 60 25 L60 85 Q60 90 55 90 L45 90 Q40 90 40 85 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 3, 1, 0),
(52, 8, 'Puff', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M20 30 Q10 20 10 40 Q10 50 20 50 L30 50 L30 85 Q30 90 35 90 L40 90 L40 85 L40 60 L60 60 L60 85 L65 90 Q70 90 70 85 L70 50 L80 50 Q90 50 90 40 Q90 20 80 30 L65 35 L65 25 Q65 20 60 20 L40 20 Q35 20 35 25 L35 35 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><circle cx=\"25\" cy=\"40\" r=\"8\" fill=\"#e48e42\" opacity=\"0.7\"/><circle cx=\"75\" cy=\"40\" r=\"8\" fill=\"#e48e42\" opacity=\"0.7\"/></svg>', 0.00, NULL, 0, 4, 1, 0),
(53, 8, 'Cap', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M25 30 Q20 25 20 35 L20 45 Q20 50 25 50 L35 50 L35 85 Q35 90 40 90 L60 90 Q65 90 65 85 L65 50 L75 50 Q80 50 80 45 L80 35 Q80 25 75 30 L65 35 L65 25 Q65 20 60 20 L40 20 Q35 20 35 25 L35 35 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 5, 1, 0),
(54, 9, 'Round Neck', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><circle cx=\"50\" cy=\"35\" r=\"12\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\"/><circle cx=\"50\" cy=\"30\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 1, 1, 0),
(55, 9, 'V-Neck', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M30 20 L50 50 L70 20\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><circle cx=\"50\" cy=\"40\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 2, 1, 0),
(56, 9, 'Square Neck', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"35\" y=\"25\" width=\"30\" height=\"20\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" rx=\"2\"/><rect x=\"47\" y=\"30\" width=\"6\" height=\"3\" fill=\"#e48e42\" rx=\"1\"/></svg>', 0.00, NULL, 0, 3, 1, 0),
(57, 10, 'Button Front', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><circle cx=\"50\" cy=\"35\" r=\"6\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><circle cx=\"50\" cy=\"50\" r=\"6\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><circle cx=\"50\" cy=\"65\" r=\"6\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><circle cx=\"50\" cy=\"35\" r=\"2\" fill=\"#e48e42\"/><circle cx=\"50\" cy=\"50\" r=\"2\" fill=\"#e48e42\"/><circle cx=\"50\" cy=\"65\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 1, 1, 0),
(58, 10, 'Zipper', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><line x1=\"50\" y1=\"25\" x2=\"50\" y2=\"75\" stroke=\"#5d4fa2\" strokeWidth=\"4\"/><rect x=\"45\" y=\"20\" width=\"10\" height=\"8\" fill=\"#e48e42\" rx=\"2\"/><path d=\"M40 30 L60 30 M40 40 L60 40 M40 50 L60 50 M40 60 L60 60 M40 70 L60 70\" stroke=\"#5d4fa2\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 2, 1, 0),
(59, 10, 'Tie Front', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M30 40 Q35 30 40 40 M60 40 Q65 30 70 40\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"3\" strokeLinecap=\"round\"/><circle cx=\"35\" cy=\"45\" r=\"3\" fill=\"#e48e42\"/><circle cx=\"65\" cy=\"45\" r=\"3\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 3, 1, 0),
(60, 11, 'Elastic Waist', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M25 30 Q30 25 35 30 Q40 35 45 30 Q50 25 55 30 Q60 35 65 30 Q70 25 75 30\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><rect x=\"30\" y=\"35\" width=\"40\" height=\"45\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"5\"/></svg>', 0.00, NULL, 0, 1, 1, 0),
(61, 11, 'Drawstring', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"30\" y=\"30\" width=\"40\" height=\"50\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"5\"/><circle cx=\"45\" cy=\"35\" r=\"3\" fill=\"none\" stroke=\"#e48e42\" strokeWidth=\"2\"/><circle cx=\"55\" cy=\"35\" r=\"3\" fill=\"none\" stroke=\"#e48e42\" strokeWidth=\"2\"/><path d=\"M40 35 Q35 25 30 35 M60 35 Q65 25 70 35\" fill=\"none\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 2, 1, 0),
(62, 11, 'Button & Zip', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"30\" y=\"30\" width=\"40\" height=\"50\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"5\"/><circle cx=\"50\" cy=\"35\" r=\"4\" fill=\"#e48e42\"/><line x1=\"50\" y1=\"40\" x2=\"50\" y2=\"75\" stroke=\"#e48e42\" strokeWidth=\"3\"/></svg>', 0.00, NULL, 0, 3, 1, 0),
(63, 12, 'Regular Fit', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"30\" y=\"20\" width=\"40\" height=\"60\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"5\"/><text x=\"50\" y=\"55\" textAnchor=\"middle\" fill=\"#e48e42\" fontSize=\"12\" fontWeight=\"bold\">R</text></svg>', 0.00, NULL, 0, 1, 1, 0),
(64, 12, 'Slim Fit', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M35 20 L65 20 L60 80 L40 80 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><text x=\"50\" y=\"55\" textAnchor=\"middle\" fill=\"#e48e42\" fontSize=\"12\" fontWeight=\"bold\">S</text></svg>', 0.00, NULL, 0, 2, 1, 0),
(65, 12, 'Wide Leg', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M35 20 L65 20 L75 80 L25 80 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><text x=\"50\" y=\"55\" textAnchor=\"middle\" fill=\"#e48e42\" fontSize=\"12\" fontWeight=\"bold\">W</text></svg>', 0.00, NULL, 0, 3, 1, 0),
(66, 12, 'Bootcut', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M35 20 L65 20 L65 60 L70 80 L30 80 L35 60 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><text x=\"50\" y=\"45\" textAnchor=\"middle\" fill=\"#e48e42\" fontSize=\"12\" fontWeight=\"bold\">B</text></svg>', 0.00, NULL, 0, 4, 1, 0),
(67, 13, 'Full Length', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"35\" y=\"20\" width=\"30\" height=\"70\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"5\"/><text x=\"50\" y=\"55\" textAnchor=\"middle\" fill=\"#e48e42\" fontSize=\"10\" fontWeight=\"bold\">F</text></svg>', 0.00, NULL, 0, 1, 1, 0),
(68, 13, 'Ankle Length', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"35\" y=\"20\" width=\"30\" height=\"60\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"5\"/><text x=\"50\" y=\"50\" textAnchor=\"middle\" fill=\"#e48e42\" fontSize=\"10\" fontWeight=\"bold\">A</text></svg>', 0.00, NULL, 0, 2, 1, 0),
(69, 13, 'Capri', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"35\" y=\"20\" width=\"30\" height=\"45\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"5\"/><text x=\"50\" y=\"45\" textAnchor=\"middle\" fill=\"#e48e42\" fontSize=\"10\" fontWeight=\"bold\">C</text></svg>', 0.00, NULL, 0, 3, 1, 0),
(70, 13, '7/8 Length', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"35\" y=\"20\" width=\"30\" height=\"55\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"5\"/><text x=\"50\" y=\"48\" textAnchor=\"middle\" fill=\"#e48e42\" fontSize=\"8\" fontWeight=\"bold\">7/8</text></svg>', 0.00, NULL, 0, 4, 1, 0),
(71, 14, 'Traditional Salwar', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M30 30 L70 30 L75 50 Q75 60 70 65 L70 80 L30 80 L30 65 Q25 60 25 50 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 1, 1, 0),
(72, 14, 'Churidar', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M35 30 L65 30 L65 70 Q65 75 60 75 L40 75 Q35 75 35 70 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><path d=\"M40 75 L40 85 Q40 90 45 90 L55 90 Q60 90 60 85 L60 75\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 2, 1, 0),
(73, 14, 'Palazzo', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M30 30 L70 30 L80 80 L20 80 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 3, 1, 0),
(74, 14, 'Patiala', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M25 30 L75 30 L80 50 Q80 65 70 70 L70 80 L30 80 L30 70 Q20 65 20 50 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><line x1=\"35\" y1=\"40\" x2=\"35\" y2=\"70\" stroke=\"#e48e42\" strokeWidth=\"1\"/><line x1=\"50\" y1=\"40\" x2=\"50\" y2=\"70\" stroke=\"#e48e42\" strokeWidth=\"1\"/><line x1=\"65\" y1=\"40\" x2=\"65\" y2=\"70\" stroke=\"#e48e42\" strokeWidth=\"1\"/></svg>', 0.00, NULL, 0, 4, 1, 0),
(75, 15, 'Straight Cut', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"35\" y=\"20\" width=\"30\" height=\"60\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"5\"/></svg>', 0.00, NULL, 0, 1, 1, 0),
(76, 15, 'A-Line', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M40 20 L60 20 L70 80 L30 80 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 2, 1, 0),
(77, 15, 'Anarkali', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M40 20 L60 20 L65 50 Q65 60 75 65 L80 80 L20 80 L25 65 Q35 60 35 50 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 3, 1, 0),
(78, 15, 'Sharara Style', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M40 20 L60 20 L60 50 L75 80 L25 80 L40 50 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 4, 1, 0),
(79, 16, 'Round Neck', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><circle cx=\"50\" cy=\"35\" r=\"12\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\"/><circle cx=\"50\" cy=\"30\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 1, 1, 0),
(80, 16, 'V-Neck', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M30 20 L50 50 L70 20\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><circle cx=\"50\" cy=\"40\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 2, 1, 0),
(81, 16, 'Boat Neck', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M25 35 Q50 25 75 35\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><circle cx=\"50\" cy=\"30\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 3, 1, 0),
(82, 16, 'High Neck', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"35\" y=\"20\" width=\"30\" height=\"15\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" rx=\"7\"/><circle cx=\"50\" cy=\"27\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 4, 1, 0),
(83, 17, 'Katori', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M25 40 Q25 25 50 25 Q75 25 75 40 L75 70 Q75 80 65 80 L35 80 Q25 80 25 70 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><path d=\"M35 35 Q50 45 65 35\" fill=\"none\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 1, 1, 0),
(84, 17, 'Princes Cut', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M30 25 L70 25 L75 80 L25 80 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><line x1=\"50\" y1=\"25\" x2=\"50\" y2=\"80\" stroke=\"#e48e42\" strokeWidth=\"2\"/><line x1=\"40\" y1=\"25\" x2=\"35\" y2=\"80\" stroke=\"#e48e42\" strokeWidth=\"1\"/><line x1=\"60\" y1=\"25\" x2=\"65\" y2=\"80\" stroke=\"#e48e42\" strokeWidth=\"1\"/></svg>', 0.00, NULL, 0, 2, 1, 0),
(85, 17, 'Four Tucks', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M25 25 L75 25 L75 80 L25 80 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><line x1=\"35\" y1=\"25\" x2=\"35\" y2=\"80\" stroke=\"#e48e42\" strokeWidth=\"2\"/><line x1=\"45\" y1=\"25\" x2=\"45\" y2=\"80\" stroke=\"#e48e42\" strokeWidth=\"2\"/><line x1=\"55\" y1=\"25\" x2=\"55\" y2=\"80\" stroke=\"#e48e42\" strokeWidth=\"2\"/><line x1=\"65\" y1=\"25\" x2=\"65\" y2=\"80\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 3, 1, 0),
(86, 17, 'Three Tucks', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M25 25 L75 25 L75 80 L25 80 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><line x1=\"37\" y1=\"25\" x2=\"37\" y2=\"80\" stroke=\"#e48e42\" strokeWidth=\"2\"/><line x1=\"50\" y1=\"25\" x2=\"50\" y2=\"80\" stroke=\"#e48e42\" strokeWidth=\"2\"/><line x1=\"63\" y1=\"25\" x2=\"63\" y2=\"80\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 4, 1, 0),
(87, 18, 'Hook', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M30 40 Q30 30 40 30 Q50 30 50 40 L50 60\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><circle cx=\"60\" cy=\"50\" r=\"8\" fill=\"#e48e42\"/><circle cx=\"60\" cy=\"50\" r=\"3\" fill=\"#5d4fa2\"/></svg>', 0.00, NULL, 0, 1, 1, 0),
(88, 18, 'Button', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><circle cx=\"50\" cy=\"35\" r=\"8\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><circle cx=\"50\" cy=\"50\" r=\"8\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><circle cx=\"50\" cy=\"65\" r=\"8\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><circle cx=\"50\" cy=\"35\" r=\"3\" fill=\"#e48e42\"/><circle cx=\"50\" cy=\"50\" r=\"3\" fill=\"#e48e42\"/><circle cx=\"50\" cy=\"65\" r=\"3\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 2, 1, 0),
(89, 18, 'Zipper', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><line x1=\"50\" y1=\"20\" x2=\"50\" y2=\"80\" stroke=\"#5d4fa2\" strokeWidth=\"4\"/><rect x=\"45\" y=\"15\" width=\"10\" height=\"8\" fill=\"#e48e42\" rx=\"2\"/><path d=\"M40 25 L60 25 M40 35 L60 35 M40 45 L60 45 M40 55 L60 55 M40 65 L60 65 M40 75 L60 75\" stroke=\"#5d4fa2\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 3, 1, 0),
(90, 18, 'Chain', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><circle cx=\"50\" cy=\"25\" r=\"6\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"3\"/><circle cx=\"50\" cy=\"40\" r=\"6\" fill=\"none\" stroke=\"#e48e42\" strokeWidth=\"3\"/><circle cx=\"50\" cy=\"55\" r=\"6\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"3\"/><circle cx=\"50\" cy=\"70\" r=\"6\" fill=\"none\" stroke=\"#e48e42\" strokeWidth=\"3\"/></svg>', 0.00, NULL, 0, 4, 1, 0),
(91, 19, 'Yes', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><circle cx=\"50\" cy=\"50\" r=\"30\" fill=\"#5d4fa2\"/><path d=\"M35 50 L45 60 L65 40\" fill=\"none\" stroke=\"#e48e42\" strokeWidth=\"4\" strokeLinecap=\"round\" strokeLinejoin=\"round\"/></svg>', 0.00, NULL, 0, 1, 1, 0),
(92, 19, 'No', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><circle cx=\"50\" cy=\"50\" r=\"30\" fill=\"#5d4fa2\"/><path d=\"M35 35 L65 65 M65 35 L35 65\" stroke=\"#e48e42\" strokeWidth=\"4\" strokeLinecap=\"round\"/></svg>', 0.00, NULL, 0, 2, 1, 0),
(93, 20, 'Half', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M20 30 Q15 25 15 35 L15 55 Q15 60 20 60 L35 60 L35 85 Q35 90 40 90 L60 90 Q65 90 65 85 L65 60 L80 60 Q85 60 85 55 L85 35 Q85 25 80 30 L65 35 L65 25 Q65 20 60 20 L40 20 Q35 20 35 25 L35 35 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 1, 1, 0),
(94, 20, 'Full', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M20 30 Q15 25 15 35 L15 75 Q15 80 20 80 L25 80 L25 85 Q25 90 30 90 L35 90 L35 85 L35 60 L65 60 L65 85 L70 90 Q75 90 75 85 L75 80 L80 80 Q85 80 85 75 L85 35 Q85 25 80 30 L65 35 L65 25 Q65 20 60 20 L40 20 Q35 20 35 25 L35 35 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 2, 1, 0),
(95, 20, '3/4th', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M20 30 Q15 25 15 35 L15 65 Q15 70 20 70 L30 70 L30 85 Q30 90 35 90 L40 90 L40 85 L40 60 L60 60 L60 85 L65 90 Q70 90 70 85 L70 70 L80 70 Q85 70 85 65 L85 35 Q85 25 80 30 L60 35 L60 25 Q60 20 55 20 L45 20 Q40 20 40 25 L40 35 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 3, 1, 0),
(96, 20, 'Roll-Up', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M20 30 Q15 25 15 35 L15 55 Q15 60 20 60 L25 60 L25 65 Q25 70 30 70 L35 70 L35 60 L65 60 L65 70 L70 70 Q75 70 75 65 L75 60 L80 60 Q85 60 85 55 L85 35 Q85 25 80 30 L65 35 L65 25 Q65 20 60 20 L40 20 Q35 20 35 25 L35 35 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><rect x=\"25\" y=\"55\" width=\"10\" height=\"8\" fill=\"#e48e42\" rx=\"2\"/><rect x=\"65\" y=\"55\" width=\"10\" height=\"8\" fill=\"#e48e42\" rx=\"2\"/></svg>', 0.00, NULL, 0, 4, 1, 0),
(97, 21, 'Standard Collar', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M35 25 L50 35 L65 25 L70 30 L70 40 L65 45 L50 40 L35 45 L30 40 L30 30 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><line x1=\"50\" y1=\"35\" x2=\"50\" y2=\"50\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 1, 1, 0),
(98, 21, 'Mandarin Collar', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"30\" y=\"25\" width=\"40\" height=\"8\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"4\"/><circle cx=\"50\" cy=\"29\" r=\"2\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 0, 2, 1, 0),
(99, 21, 'Spread Collar', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M25 25 L50 40 L75 25 L80 35 L75 45 L50 45 L25 45 L20 35 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><line x1=\"50\" y1=\"40\" x2=\"50\" y2=\"55\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 3, 1, 0),
(100, 21, 'Band Collar', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"25\" y=\"25\" width=\"50\" height=\"6\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"3\"/><rect x=\"47\" y=\"27\" width=\"6\" height=\"2\" fill=\"#e48e42\" rx=\"1\"/></svg>', 0.00, NULL, 0, 4, 1, 0),
(101, 22, 'Regular Fit', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"30\" y=\"20\" width=\"40\" height=\"60\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"5\"/><text x=\"50\" y=\"55\" textAnchor=\"middle\" fill=\"#e48e42\" fontSize=\"12\" fontWeight=\"bold\">R</text></svg>', 0.00, NULL, 0, 1, 1, 0),
(102, 22, 'Slim Fit', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M35 20 L65 20 L60 80 L40 80 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><text x=\"50\" y=\"55\" textAnchor=\"middle\" fill=\"#e48e42\" fontSize=\"12\" fontWeight=\"bold\">S</text></svg>', 0.00, NULL, 0, 2, 1, 0),
(103, 22, 'Comfort Fit', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"25\" y=\"20\" width=\"50\" height=\"60\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"8\"/><text x=\"50\" y=\"55\" textAnchor=\"middle\" fill=\"#e48e42\" fontSize=\"12\" fontWeight=\"bold\">C</text></svg>', 0.00, NULL, 0, 3, 1, 0),
(104, 22, 'Boxy Fit', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"20\" y=\"20\" width=\"60\" height=\"60\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"3\"/><text x=\"50\" y=\"55\" textAnchor=\"middle\" fill=\"#e48e42\" fontSize=\"12\" fontWeight=\"bold\">B</text></svg>', 0.00, NULL, 0, 4, 1, 0),
(105, 23, 'Cross', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"30\" y=\"20\" width=\"40\" height=\"60\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"5\"/><path d=\"M20 35 L35 50 L20 65\" fill=\"none\" stroke=\"#e48e42\" strokeWidth=\"3\" strokeLinecap=\"round\" strokeLinejoin=\"round\"/><path d=\"M80 35 L65 50 L80 65\" fill=\"none\" stroke=\"#e48e42\" strokeWidth=\"3\" strokeLinecap=\"round\" strokeLinejoin=\"round\"/></svg>', 0.00, NULL, 0, 1, 1, 0),
(106, 23, 'Straight', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"30\" y=\"20\" width=\"40\" height=\"60\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"5\"/><line x1=\"20\" y1=\"35\" x2=\"20\" y2=\"65\" stroke=\"#e48e42\" strokeWidth=\"3\" strokeLinecap=\"round\"/><line x1=\"80\" y1=\"35\" x2=\"80\" y2=\"65\" stroke=\"#e48e42\" strokeWidth=\"3\" strokeLinecap=\"round\"/></svg>', 0.00, NULL, 0, 2, 1, 0),
(107, 24, 'Yes', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M25 20 L30 80 M35 20 L40 80 M45 20 L50 80 M55 20 L60 80 M65 20 L70 80 M75 20 L80 80\" stroke=\"#5d4fa2\" strokeWidth=\"3\" strokeLinecap=\"round\"/><path d=\"M30 25 Q35 30 40 25 Q45 30 50 25 Q55 30 60 25 Q65 30 70 25\" fill=\"none\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 1, 1, 0),
(108, 24, 'No', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"25\" y=\"20\" width=\"50\" height=\"60\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"5\"/><path d=\"M35 35 L65 65 M65 35 L35 65\" stroke=\"#e48e42\" strokeWidth=\"3\" strokeLinecap=\"round\"/></svg>', 0.00, NULL, 0, 2, 1, 0),
(109, 25, '0', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"25\" y=\"20\" width=\"50\" height=\"60\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"5\"/><text x=\"50\" y=\"55\" textAnchor=\"middle\" fill=\"#e48e42\" fontSize=\"24\" fontWeight=\"bold\">0</text></svg>', 0.00, NULL, 0, 1, 1, 0),
(110, 25, '1', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"25\" y=\"20\" width=\"50\" height=\"60\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"5\"/><rect x=\"40\" y=\"35\" width=\"20\" height=\"15\" fill=\"none\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"2\"/><text x=\"50\" y=\"65\" textAnchor=\"middle\" fill=\"#e48e42\" fontSize=\"16\" fontWeight=\"bold\">1</text></svg>', 0.00, NULL, 0, 2, 1, 0),
(111, 25, '2', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"25\" y=\"20\" width=\"50\" height=\"60\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"5\"/><rect x=\"30\" y=\"35\" width=\"15\" height=\"12\" fill=\"none\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"2\"/><rect x=\"55\" y=\"35\" width=\"15\" height=\"12\" fill=\"none\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"2\"/><text x=\"50\" y=\"65\" textAnchor=\"middle\" fill=\"#e48e42\" fontSize=\"16\" fontWeight=\"bold\">2</text></svg>', 0.00, NULL, 0, 3, 1, 0),
(112, 26, 'Elastic Waist', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M25 30 Q30 25 35 30 Q40 35 45 30 Q50 25 55 30 Q60 35 65 30 Q70 25 75 30\" fill=\"none\" stroke=\"#5d4fa2\" strokeWidth=\"4\" strokeLinecap=\"round\"/><rect x=\"30\" y=\"35\" width=\"40\" height=\"45\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"5\"/></svg>', 0.00, NULL, 0, 1, 1, 0),
(113, 26, 'Drawstring', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"30\" y=\"30\" width=\"40\" height=\"50\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"5\"/><circle cx=\"45\" cy=\"35\" r=\"3\" fill=\"none\" stroke=\"#e48e42\" strokeWidth=\"2\"/><circle cx=\"55\" cy=\"35\" r=\"3\" fill=\"none\" stroke=\"#e48e42\" strokeWidth=\"2\"/><path d=\"M40 35 Q35 25 30 35 M60 35 Q65 25 70 35\" fill=\"none\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 2, 1, 0),
(114, 26, 'Hook & Zip', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"30\" y=\"30\" width=\"40\" height=\"50\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"5\"/><circle cx=\"25\" cy=\"35\" r=\"4\" fill=\"#e48e42\"/><line x1=\"25\" y1=\"40\" x2=\"25\" y2=\"75\" stroke=\"#e48e42\" strokeWidth=\"3\"/></svg>', 0.00, NULL, 1, 3, 1, 0),
(115, 26, 'Side Zip', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"30\" y=\"30\" width=\"40\" height=\"50\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"5\"/><line x1=\"70\" y1=\"35\" x2=\"70\" y2=\"75\" stroke=\"#e48e42\" strokeWidth=\"3\"/><rect x=\"68\" y=\"33\" width=\"4\" height=\"6\" fill=\"#e48e42\" rx=\"1\"/></svg>', 0.00, NULL, 0, 4, 1, 0),
(116, 27, 'Ankle Length', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M35 20 L65 20 L70 85 L30 85 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><text x=\"50\" y=\"55\" textAnchor=\"middle\" fill=\"#e48e42\" fontSize=\"10\" fontWeight=\"bold\">A</text></svg>', 0.00, NULL, 1, 1, 1, 0),
(117, 27, 'Floor Length', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M35 20 L65 20 L70 90 L30 90 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><text x=\"50\" y=\"55\" textAnchor=\"middle\" fill=\"#e48e42\" fontSize=\"10\" fontWeight=\"bold\">F</text></svg>', 0.00, NULL, 0, 2, 1, 0),
(118, 27, 'Mid-Calf', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M35 20 L65 20 L68 70 L32 70 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><text x=\"50\" y=\"45\" textAnchor=\"middle\" fill=\"#e48e42\" fontSize=\"10\" fontWeight=\"bold\">M</text></svg>', 0.00, NULL, 0, 3, 1, 0),
(119, 27, 'Knee Length', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><path d=\"M35 20 L65 20 L67 55 L33 55 Z\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><text x=\"50\" y=\"40\" textAnchor=\"middle\" fill=\"#e48e42\" fontSize=\"10\" fontWeight=\"bold\">K</text></svg>', 0.00, NULL, 0, 4, 1, 0),
(120, 28, 'Cotton', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><circle cx=\"50\" cy=\"50\" r=\"25\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\"/><circle cx=\"40\" cy=\"40\" r=\"4\" fill=\"#e48e42\"/><circle cx=\"60\" cy=\"40\" r=\"4\" fill=\"#e48e42\"/><circle cx=\"45\" cy=\"55\" r=\"3\" fill=\"#e48e42\"/><circle cx=\"55\" cy=\"55\" r=\"3\" fill=\"#e48e42\"/><circle cx=\"50\" cy=\"65\" r=\"3\" fill=\"#e48e42\"/></svg>', 0.00, NULL, 1, 1, 1, 0),
(121, 28, 'Satin', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"25\" y=\"25\" width=\"50\" height=\"50\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"8\"/><path d=\"M30 35 Q50 25 70 35 Q50 45 30 35\" fill=\"#e48e42\" opacity=\"0.7\"/><path d=\"M30 55 Q50 45 70 55 Q50 65 30 55\" fill=\"#e48e42\" opacity=\"0.5\"/></svg>', 0.00, NULL, 0, 2, 1, 0),
(122, 28, 'Silk', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"25\" y=\"25\" width=\"50\" height=\"50\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"8\"/><path d=\"M30 30 L70 70 M70 30 L30 70\" stroke=\"#e48e42\" strokeWidth=\"2\" opacity=\"0.6\"/><circle cx=\"50\" cy=\"50\" r=\"8\" fill=\"#e48e42\" opacity=\"0.4\"/></svg>', 0.00, NULL, 0, 3, 1, 0),
(123, 28, 'Poplin', '<svg viewBox=\"0 0 100 100\" className=\"w-16 h-16\" fill=\"none\"><rect x=\"25\" y=\"25\" width=\"50\" height=\"50\" fill=\"#5d4fa2\" stroke=\"#e48e42\" strokeWidth=\"2\" rx=\"8\"/><line x1=\"30\" y1=\"35\" x2=\"70\" y2=\"35\" stroke=\"#e48e42\" strokeWidth=\"2\"/><line x1=\"30\" y1=\"45\" x2=\"70\" y2=\"45\" stroke=\"#e48e42\" strokeWidth=\"2\"/><line x1=\"30\" y1=\"55\" x2=\"70\" y2=\"55\" stroke=\"#e48e42\" strokeWidth=\"2\"/><line x1=\"30\" y1=\"65\" x2=\"70\" y2=\"65\" stroke=\"#e48e42\" strokeWidth=\"2\"/></svg>', 0.00, NULL, 0, 4, 1, 0),
(124, 1, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(125, 2, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(126, 3, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(127, 4, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(128, 5, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(129, 6, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(130, 7, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0);
INSERT INTO `boutique_design_options` (`id`, `design_area_id`, `name`, `image_url`, `price`, `stagePrices`, `is_default`, `display_order`, `status`, `is_deleted`) VALUES
(131, 8, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(132, 9, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(133, 10, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(134, 11, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(135, 12, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(136, 13, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(137, 14, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(138, 15, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(139, 16, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(140, 17, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(141, 18, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(142, 19, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(143, 20, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(144, 21, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(145, 22, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(146, 23, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(147, 24, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(148, 25, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(149, 26, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(150, 27, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0),
(151, 28, 'Custom', '<svg width=\"208px\" height=\"208px\" viewBox=\"-13.44 -13.44 50.88 50.88\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"#e48e42\" stroke=\"#e48e42\" stroke-width=\"0.00024000000000000003\"><g id=\"SVGRepo_bgCarrier\" stroke-width=\"0\" transform=\"translate(4.92,4.92), scale(0.59)\"><rect x=\"-13.44\" y=\"-13.44\" width=\"50.88\" height=\"50.88\" rx=\"25.44\" fill=\"#5d4fa2\" strokewidth=\"0\"></rect></g><g id=\"SVGRepo_tracerCarrier\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#CCCCCC\" stroke-width=\"0.048\"></g><g id=\"SVGRepo_iconCarrier\"> <rect x=\"0\" fill=\"none\" width=\"24\" height=\"24\"></rect> <g> <path d=\"M19 3H5c-1.105 0-2 .895-2 2v14c0 1.105.895 2 2 2h14c1.105 0 2-.895 2-2V5c0-1.105-.895-2-2-2zM6 6h5v5H6V6zm4.5 13C9.12 19 8 17.88 8 16.5S9.12 14 10.5 14s2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5zm3-6l3-5 3 5h-6z\"></path> </g> </g></svg>', 0.00, NULL, 0, 0, 1, 0);

-- --------------------------------------------------------

--
-- Table structure for table `boutique_items`
--

CREATE TABLE `boutique_items` (
  `id` int(20) UNSIGNED NOT NULL,
  `item_name` varchar(100) DEFAULT NULL,
  `status` tinyint(1) NOT NULL DEFAULT 1,
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `boutique_items`
--

INSERT INTO `boutique_items` (`id`, `item_name`, `status`, `is_deleted`, `created_at`, `updated_at`) VALUES
(1, 'Churidar', 1, 0, '2025-06-17 12:10:08', '2025-06-17 12:10:08'),
(2, 'Frock', 1, 0, '2025-06-17 12:10:52', '2025-06-17 12:10:52'),
(3, 'Kurti', 1, 0, '2025-06-17 12:10:52', '2025-06-17 12:10:52'),
(4, 'Night Gown', 1, 0, '2025-06-17 12:26:45', '2025-06-17 12:26:45'),
(5, 'Pants', 1, 0, '2025-06-17 12:26:45', '2025-06-17 12:26:45'),
(6, 'Salwar Kameez', 1, 0, '2025-06-17 12:26:45', '2025-06-17 12:26:45'),
(7, 'Saree Blouse', 1, 0, '2025-06-17 12:26:45', '2025-06-17 12:26:45'),
(8, 'Shirt', 1, 0, '2025-06-17 12:26:45', '2025-06-17 12:26:45'),
(9, 'Shorts', 1, 0, '2025-06-17 12:26:45', '2025-06-17 12:26:45'),
(10, 'Under Skirt', 1, 0, '2025-06-17 12:26:45', '2025-06-17 12:26:45');

-- --------------------------------------------------------

--
-- Table structure for table `boutique_item_measurements`
--

CREATE TABLE `boutique_item_measurements` (
  `id` int(10) UNSIGNED NOT NULL,
  `item_id` int(10) UNSIGNED NOT NULL,
  `name` varchar(100) NOT NULL,
  `status` tinyint(4) NOT NULL DEFAULT 1,
  `is_deleted` tinyint(4) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `boutique_item_measurements`
--

INSERT INTO `boutique_item_measurements` (`id`, `item_id`, `name`, `status`, `is_deleted`) VALUES
(1, 1, 'Length', 1, 0),
(2, 1, 'Shoulder', 1, 0),
(3, 1, 'Upper Chest (All Around)', 1, 0),
(4, 1, 'Bust (All Around)', 1, 0),
(5, 1, 'Waist(All Around)', 1, 0),
(6, 1, 'Seat (All Around)', 1, 0),
(7, 1, 'Armhole (All Around)', 1, 0),
(8, 1, 'Sleeve Length', 1, 0),
(9, 1, 'Sleeve Circumf. (All Around)', 1, 0),
(10, 1, 'Front Neck Depth', 1, 0),
(11, 1, 'Back Neck Depth', 1, 0),
(12, 1, 'Bottom\'s Length', 1, 0),
(13, 1, 'Bottoms Waist (All Around)', 1, 0),
(14, 1, 'Bottoms Hip (All Around)', 1, 0),
(15, 1, 'Knee/Calf (All Around)', 1, 0),
(16, 1, 'Ankle (All Around)', 1, 0),
(17, 2, 'Waist', 1, 0),
(18, 2, 'Seat', 1, 0),
(19, 2, 'Calf', 1, 0),
(20, 2, 'Ankle ', 1, 0),
(21, 2, 'Length', 1, 0),
(22, 3, 'Length', 1, 0),
(23, 3, 'Shoulder', 1, 0),
(24, 3, 'Upper Chest (All Around)', 1, 0),
(25, 3, 'Bust (All Around)', 1, 0),
(26, 3, 'Waist(All Around)', 1, 0),
(27, 3, 'Seat (All Around)', 1, 0),
(28, 3, 'Armhole (All Around)', 1, 0),
(29, 3, 'Sleeve Length', 1, 0),
(30, 3, 'Sleeve Circumf. (All Around)', 1, 0),
(31, 3, 'Front Neck Depth', 1, 0),
(32, 3, 'Back Neck Depth', 1, 0),
(33, 4, 'Gown Length', 1, 0),
(34, 4, 'Chest (All Around)', 1, 0),
(35, 4, 'Upper Chest (All Around)', 1, 0),
(36, 4, 'Waist(All Around)', 1, 0),
(37, 4, 'Shoulder', 1, 0),
(38, 4, 'Armhole (All Around)', 1, 0),
(39, 4, 'Sleeve Length', 1, 0),
(40, 4, 'Sleeve Circumf. (All Around)', 1, 0),
(41, 4, 'Back Neck Depth', 1, 0),
(42, 4, 'Front Neck Depth', 1, 0),
(43, 5, 'Waist', 1, 0),
(44, 5, 'Seat', 1, 0),
(45, 5, 'Calf/Knee', 1, 0),
(46, 5, 'Bottom/Bells', 1, 0),
(47, 5, 'Length', 1, 0),
(48, 5, 'Fly (Ply)', 1, 0),
(49, 6, 'Kameez Length', 1, 0),
(50, 6, 'Shoulder', 1, 0),
(51, 6, 'Upper Chest (All Around)', 1, 0),
(52, 6, 'Bust (All Around)', 1, 0),
(53, 6, 'Waist(All Around)', 1, 0),
(54, 6, 'Seat (All Around)', 1, 0),
(55, 6, 'Armhole (All Around)', 1, 0),
(56, 6, 'Sleeve Length', 1, 0),
(57, 6, 'Sleeve Circumf. (All Around)', 1, 0),
(58, 6, 'Front Neck Depth', 1, 0),
(59, 6, 'Back Neck Depth', 1, 0),
(60, 6, 'Salwar\'s Length', 1, 0),
(61, 6, 'Salwar\'s Waist (All Around)', 1, 0),
(62, 6, 'Salwar\'s Hip (All Around)', 1, 0),
(63, 6, 'Knee/Calf (All Around)', 1, 0),
(64, 6, 'Ankle (All Around)', 1, 0),
(65, 7, 'Blouse Length', 1, 0),
(66, 7, 'Bust (All Around)', 1, 0),
(67, 7, 'Upper Chest (All Around)', 1, 0),
(68, 7, 'Below Bust (All Around)', 1, 0),
(69, 7, 'Shoulder', 1, 0),
(70, 7, 'Armhole (All Around)', 1, 0),
(71, 7, 'Sleeve Length', 1, 0),
(72, 7, 'Sleeve Circumf. (All Around)', 1, 0),
(73, 7, 'Shoulder To Apex Point', 1, 0),
(74, 7, 'Apex Point To Apex Point', 1, 0),
(75, 7, 'Back Neck Depth', 1, 0),
(76, 7, 'Front Neck Depth', 1, 0),
(77, 8, 'Length', 1, 0),
(78, 8, 'Neck', 1, 0),
(79, 8, 'Shoulder', 1, 0),
(80, 8, 'Chest', 1, 0),
(81, 8, 'Waist', 1, 0),
(82, 8, 'Seat', 1, 0),
(83, 8, 'Sleeves', 1, 0),
(84, 8, 'Sleeve Circumf. (All Around)', 1, 0),
(85, 9, 'Waist', 1, 0),
(86, 9, 'Seat', 1, 0),
(87, 9, 'Knee Circumf. (All Around)', 1, 0),
(88, 9, 'Length', 1, 0),
(89, 9, 'Fly (Ply)', 1, 0),
(90, 10, 'Waist', 1, 0),
(91, 10, 'Length', 1, 0);

-- --------------------------------------------------------

--
-- Table structure for table `boutique_pattern`
--

CREATE TABLE `boutique_pattern` (
  `id` bigint(20) NOT NULL,
  `item_id` bigint(20) NOT NULL,
  `name` varchar(50) NOT NULL,
  `image` varchar(250) DEFAULT NULL,
  `price` decimal(10,2) NOT NULL,
  `stagePrices` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`stagePrices`)),
  `is_default` tinyint(4) NOT NULL DEFAULT 0,
  `status` tinyint(1) NOT NULL DEFAULT 1,
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_categories`
--

CREATE TABLE `business_categories` (
  `id` int(11) NOT NULL,
  `name` varchar(250) NOT NULL,
  `slug` varchar(50) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `status` tinyint(4) NOT NULL DEFAULT 1,
  `is_deleted` tinyint(4) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `business_categories`
--

INSERT INTO `business_categories` (`id`, `name`, `slug`, `created_at`, `updated_at`, `status`, `is_deleted`) VALUES
(1, 'SPA and Saloon', 'SPA_SALOON', '2025-02-05 03:32:25', '2025-08-09 01:46:24', 1, 0),
(2, 'Boutique', 'BOUTIQUE', '2025-02-05 03:35:17', '2025-08-09 01:46:24', 1, 0),
(3, 'Gift Centre', 'GIFT_CENTRE', '2025-02-05 03:35:17', '2025-08-09 01:46:24', 1, 0),
(4, 'Distribution or Retail', 'DISTRIBUTION_RETAIL', '2025-02-05 03:35:17', '2025-08-09 01:46:24', 1, 0),
(5, 'Laptop Sales and Service', 'LAPTOP_SERVICE', '2025-02-05 03:35:17', '2025-08-09 01:46:24', 1, 0),
(6, 'Repairs and Services', 'REPAIRS_SERVICES', '2025-02-05 03:35:17', '2025-08-09 01:46:24', 1, 0),
(7, 'Real Estate', 'REAL_ESTATE', '2025-02-05 03:35:17', '2025-08-09 01:46:24', 1, 0),
(8, 'Optical', 'OPTICAL', '2025-04-08 22:29:24', '2025-08-09 01:46:24', 1, 0),
(9, 'Veterinary', 'VETERINARY', '2025-04-08 22:30:17', '2025-08-09 01:46:24', 1, 0),
(10, 'Event Management', 'EVENT_MANAGEMENT', '2025-04-08 22:30:37', '2025-08-09 01:46:24', 1, 0),
(11, 'Financial Collection', 'FINANCIAL_COLLECTION', '2025-04-22 09:27:06', '2025-08-09 01:46:24', 1, 0),
(13, 'Dry Cleaners, Laundries & Laundromats', 'DRY_CLEANERS', '2025-05-26 07:47:33', '2025-08-09 01:46:24', 1, 0);

-- --------------------------------------------------------

--
-- Table structure for table `business_sub_categories`
--

CREATE TABLE `business_sub_categories` (
  `id` int(11) NOT NULL,
  `business_id` int(11) NOT NULL,
  `sub_category_name` varchar(250) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `is_deleted` int(11) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `business_sub_categories`
--

INSERT INTO `business_sub_categories` (`id`, `business_id`, `sub_category_name`, `status`, `created_at`, `updated_at`, `is_deleted`) VALUES
(1, 4, 'Fish Supply', 1, '2025-02-06 13:58:44', '2025-02-06 13:58:44', 0),
(2, 4, 'Software & Products', 1, '2025-02-06 14:01:46', '2025-02-06 14:01:46', 0),
(3, 4, 'Fruits & Vegetables', 1, '2025-02-06 14:01:46', '2025-02-06 14:01:46', 0),
(4, 4, 'Beauty & Healthcare Products', 1, '2025-02-06 14:01:46', '2025-02-06 14:01:46', 0),
(5, 4, 'Clothing Supply', 1, '2025-02-06 14:01:46', '2025-02-06 14:01:46', 0),
(6, 4, 'Food Products', 1, '2025-02-06 14:01:46', '2025-02-06 14:01:46', 0),
(7, 6, 'Electronics & Appliances Repair', 1, '2025-02-06 15:07:16', '2025-02-06 15:07:16', 0),
(8, 6, 'Automotive Repair & Maintenance', 1, '2025-02-06 15:10:11', '2025-02-06 15:10:11', 0),
(9, 6, 'Plumbing Services', 1, '2025-02-06 15:10:11', '2025-02-06 15:10:11', 0),
(10, 6, 'Electrical Services', 1, '2025-02-06 15:10:11', '2025-02-06 15:10:11', 0),
(11, 6, 'Ventilation, and Air Conditioning', 1, '2025-02-06 15:10:11', '2025-02-06 15:10:11', 0),
(12, 6, 'Furniture & Home Improvement', 1, '2025-02-06 15:10:11', '2025-02-06 15:10:11', 0),
(13, 6, 'Home & Office Cleaning', 1, '2025-02-06 15:10:11', '2025-02-06 15:10:11', 0),
(14, 9, 'Pet clinic', 1, '2025-04-09 09:31:52', '2025-04-09 09:31:52', 0),
(15, 9, 'Pet care', 1, '2025-04-09 09:32:11', '2025-04-09 09:32:11', 0),
(16, 11, 'Pigmi', 1, '2025-04-22 14:58:05', '2025-04-22 14:58:05', 0),
(17, 11, 'Loan/EMI', 1, '2025-04-22 14:58:13', '2025-04-22 14:58:13', 0),
(18, 11, 'Chit Fund', 1, '2025-04-22 14:58:29', '2025-04-22 14:58:29', 0),
(19, 4, 'Fasteners', 1, '2025-04-25 09:54:35', '2025-04-25 09:54:35', 0),
(20, 4, 'Hardware', 1, '2025-07-05 12:41:38', '2025-07-05 12:41:38', 0);

-- --------------------------------------------------------

--
-- Table structure for table `cache`
--

CREATE TABLE `cache` (
  `key` varchar(255) NOT NULL,
  `value` mediumtext NOT NULL,
  `expiration` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `cache_locks`
--

CREATE TABLE `cache_locks` (
  `key` varchar(255) NOT NULL,
  `owner` varchar(255) NOT NULL,
  `expiration` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `chances`
--

CREATE TABLE `chances` (
  `id` int(11) NOT NULL,
  `value` varchar(250) NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `status` tinyint(4) NOT NULL DEFAULT 1,
  `is_deleted` tinyint(4) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `chances`
--

INSERT INTO `chances` (`id`, `value`, `created_at`, `updated_at`, `status`, `is_deleted`) VALUES
(1, 'High', '2024-11-19 17:31:51', '2024-11-19 17:31:51', 1, 0),
(2, 'Medium', '2024-11-19 17:31:51', '2024-11-19 17:31:51', 1, 0),
(3, 'Low', '2024-11-19 17:32:21', '2024-11-19 17:32:21', 1, 0);

-- --------------------------------------------------------

--
-- Table structure for table `channel_partners`
--

CREATE TABLE `channel_partners` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `full_name` varchar(255) NOT NULL,
  `email` varchar(255) NOT NULL,
  `mobile` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `created_by` varchar(100) DEFAULT NULL,
  `cp_id` bigint(20) DEFAULT NULL,
  `is_strategic_cp` tinyint(4) NOT NULL DEFAULT 0,
  `location` varchar(50) DEFAULT NULL,
  `status` tinyint(4) NOT NULL DEFAULT 1,
  `is_deleted` tinyint(4) NOT NULL DEFAULT 0,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `channel_partners`
--

INSERT INTO `channel_partners` (`id`, `full_name`, `email`, `mobile`, `password`, `created_by`, `cp_id`, `is_strategic_cp`, `location`, `status`, `is_deleted`, `created_at`, `updated_at`) VALUES
(1, 'Vignesh', 'vignesh@adeptek.co.in', '9840913457', '$2y$12$rfgbxnTejutlrmSTe7CKm.bxkq/X3QhEpJjPy6g7p4uNyvelsKHde', 'admin', NULL, 1, 'Bangalore', 1, 0, '2025-07-31 10:36:33', '2025-07-31 10:36:33');

-- --------------------------------------------------------

--
-- Table structure for table `cities`
--

CREATE TABLE `cities` (
  `id` int(11) NOT NULL,
  `city_name` varchar(255) NOT NULL,
  `state_id` int(11) NOT NULL,
  `country_id` int(11) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp(),
  `status` int(11) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `cities`
--

INSERT INTO `cities` (`id`, `city_name`, `state_id`, `country_id`, `created_at`, `updated_at`, `status`) VALUES
(3, 'Ramanagara', 1, 91, '2024-07-28 13:21:30', '2024-07-28 13:21:30', 0),
(4, 'Kolar', 1, 91, '2024-07-28 13:21:30', '2024-07-28 13:21:30', 0),
(5, 'Chikkaballapura', 1, 91, '2024-07-28 13:21:30', '2024-07-28 13:21:30', 0),
(6, 'Tumkur', 1, 91, '2024-07-28 13:21:30', '2024-07-28 13:21:30', 0),
(7, 'Mandya', 1, 91, '2024-07-28 13:21:30', '2024-07-28 13:21:30', 0),
(8, 'Mysore', 1, 91, '2024-07-28 13:21:30', '2024-07-28 13:21:30', 0),
(9, 'Chamarajanagara', 1, 91, '2024-07-28 13:21:30', '2024-07-28 13:21:30', 0),
(10, 'Hassan', 1, 91, '2024-07-28 13:21:30', '2024-07-28 13:21:30', 0),
(11, 'Chitradurga', 1, 91, '2024-07-28 13:21:30', '2024-07-28 13:21:30', 0),
(12, 'Davanagere', 1, 91, '2024-07-28 13:21:30', '2024-07-28 13:21:30', 0),
(13, 'Ballari', 1, 91, '2024-07-28 13:21:30', '2024-07-28 08:27:15', 1),
(14, 'Uttarkashi', 3, 91, '2024-07-28 08:04:03', '2024-08-03 13:39:01', 1),
(16, 'Dehradun1', 3, 91, '2024-08-03 13:40:28', '2024-08-04 07:26:04', 0);

-- --------------------------------------------------------

--
-- Table structure for table `color_master`
--

CREATE TABLE `color_master` (
  `id` bigint(20) NOT NULL,
  `color_name` varchar(100) NOT NULL,
  `status` tinyint(1) NOT NULL DEFAULT 1,
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `color_master`
--

INSERT INTO `color_master` (`id`, `color_name`, `status`, `is_deleted`, `created_at`, `updated_at`) VALUES
(1, 'Black', 1, 0, '2025-06-16 17:16:23', '2025-06-18 08:05:18'),
(2, 'Red', 1, 0, '2025-06-16 17:16:23', '2025-06-18 08:05:23');

-- --------------------------------------------------------

--
-- Table structure for table `contact_groups`
--

CREATE TABLE `contact_groups` (
  `id` int(11) NOT NULL,
  `business_id` varchar(250) DEFAULT NULL,
  `name` varchar(250) NOT NULL,
  `type` varchar(50) DEFAULT NULL,
  `status` tinyint(4) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp(),
  `is_deleted` tinyint(4) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `contact_groups`
--

INSERT INTO `contact_groups` (`id`, `business_id`, `name`, `type`, `status`, `created_at`, `updated_at`, `is_deleted`) VALUES
(1, 'all', 'Most Likely', 'D', 1, '2024-11-30 06:30:21', '2024-11-30 06:30:21', 0),
(2, 'all', 'Followup', 'D', 1, '2024-12-25 10:36:11', '2024-12-25 10:36:11', 0),
(3, 'all', 'Schedule', 'D', 1, '2024-11-30 06:30:21', '2024-11-30 06:30:21', 0),
(4, 'all', 'Status Not Updated', 'D', 1, '2024-11-30 06:30:21', '2024-11-30 06:30:21', 0),
(5, 'all', 'Customer', 'S', 1, '2024-11-30 06:30:21', '2024-11-30 06:30:21', 0),
(6, 'all', 'Leads', 'S', 1, '2024-11-30 06:30:21', '2024-11-30 06:30:21', 0),
(7, 'all', 'Friend', 'S', 1, '2024-11-30 06:30:21', '2024-11-30 06:30:21', 0),
(8, 'all', 'Vendor/Supplier', 'S', 1, '2024-11-30 06:30:21', '2024-11-30 06:30:21', 0),
(9, 'all', 'Family', 'S', 1, '2024-12-25 10:35:25', '2024-12-25 10:35:25', 0),
(10, 'all', 'Partner', 'S', 1, '2024-12-25 10:35:34', '2024-12-25 10:35:34', 0),
(11, 'all', 'Rejected', 'S', 1, '2025-02-17 11:38:07', '2025-02-17 11:38:07', 0),
(12, 'all', 'Contact', 'D', 1, '2024-11-30 06:30:21', '2024-11-30 06:30:21', 0),
(13, 'all', 'Others', 'D', 1, '2024-12-25 10:36:11', '2024-12-25 10:36:11', 0);

-- --------------------------------------------------------

--
-- Table structure for table `countries`
--

CREATE TABLE `countries` (
  `id` int(11) NOT NULL,
  `country_code` varchar(255) NOT NULL,
  `country_name` varchar(255) NOT NULL,
  `time_zone` varchar(255) NOT NULL,
  `standard_time_zone` varchar(255) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp(),
  `status` int(11) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `countries`
--

INSERT INTO `countries` (`id`, `country_code`, `country_name`, `time_zone`, `standard_time_zone`, `created_at`, `updated_at`, `status`) VALUES
(1, 'AF', 'Afghanistan', 'Asia/Kabul', 'UTC+04:30', '2024-07-27 22:17:20', '2024-07-27 17:19:27', 0),
(2, 'AL', 'Albania', 'Europe/Tirane', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(3, 'DZ', 'Algeria', 'Africa/Algiers', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(4, 'AS', 'American Samoa', 'Pacific/Pago_Pago', 'UTC-11:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(5, 'AD', 'Andorra', 'Europe/Andorra', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(6, 'AO', 'Angola', 'Africa/Luanda', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(7, 'AI', 'Anguilla', 'America/Anguilla', 'UTC-04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(8, 'AQ', 'Antarctica', 'Antarctica/McMurdo', 'UTC+12:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(9, 'AG', 'Antigua and Barbuda', 'America/Antigua', 'UTC-04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(10, 'AR', 'Argentina', 'America/Argentina/Buenos_Aires', 'UTC-03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(11, 'AM', 'Armenia', 'Asia/Yerevan', 'UTC+04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(12, 'AW', 'Aruba', 'America/Aruba', 'UTC-04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(13, 'AU', 'Australia', 'Australia/Sydney', 'UTC+10:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(14, 'AT', 'Austria', 'Europe/Vienna', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(15, 'AZ', 'Azerbaijan', 'Asia/Baku', 'UTC+04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(16, 'BS', 'Bahamas', 'America/Nassau', 'UTC-05:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(17, 'BH', 'Bahrain', 'Asia/Bahrain', 'UTC+03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(18, 'BD', 'Bangladesh', 'Asia/Dhaka', 'UTC+06:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(19, 'BB', 'Barbados', 'America/Barbados', 'UTC-04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(20, 'BY', 'Belarus', 'Europe/Minsk', 'UTC+03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(21, 'BE', 'Belgium', 'Europe/Brussels', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(22, 'BZ', 'Belize', 'America/Belize', 'UTC-06:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(23, 'BJ', 'Benin', 'Africa/Porto-Novo', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(24, 'BM', 'Bermuda', 'Atlantic/Bermuda', 'UTC-04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(25, 'BT', 'Bhutan', 'Asia/Thimphu', 'UTC+06:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(26, 'BO', 'Bolivia', 'America/La_Paz', 'UTC-04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(27, 'BA', 'Bosnia and Herzegovina', 'Europe/Sarajevo', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(28, 'BW', 'Botswana', 'Africa/Gaborone', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(29, 'BR', 'Brazil', 'America/Sao_Paulo', 'UTC-03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(30, 'BN', 'Brunei Darussalam', 'Asia/Brunei', 'UTC+08:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(31, 'BG', 'Bulgaria', 'Europe/Sofia', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(32, 'BF', 'Burkina Faso', 'Africa/Ouagadougou', 'UTC+00:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(33, 'BI', 'Burundi', 'Africa/Bujumbura', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(34, 'CV', 'Cabo Verde', 'Atlantic/Cape_Verde', 'UTC-01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(35, 'KH', 'Cambodia', 'Asia/Phnom_Penh', 'UTC+07:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(36, 'CM', 'Cameroon', 'Africa/Douala', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(37, 'CA', 'Canada', 'America/Toronto', 'UTC-05:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(38, 'KY', 'Cayman Islands', 'America/Cayman', 'UTC-05:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(39, 'CF', 'Central African Republic', 'Africa/Bangui', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(40, 'TD', 'Chad', 'Africa/Ndjamena', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(41, 'CL', 'Chile', 'America/Santiago', 'UTC-03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(42, 'CN', 'China', 'Asia/Shanghai', 'UTC+08:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(43, 'CO', 'Colombia', 'America/Bogota', 'UTC-05:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(44, 'KM', 'Comoros', 'Indian/Comoro', 'UTC+03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(45, 'CG', 'Congo', 'Africa/Brazzaville', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(46, 'CD', 'Congo, Democratic Republic of the', 'Africa/Kinshasa', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(47, 'CR', 'Costa Rica', 'America/Costa_Rica', 'UTC-06:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(48, 'HR', 'Croatia', 'Europe/Zagreb', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(49, 'CU', 'Cuba', 'America/Havana', 'UTC-05:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(50, 'CY', 'Cyprus', 'Asia/Nicosia', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(51, 'CZ', 'Czechia', 'Europe/Prague', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(52, 'DK', 'Denmark', 'Europe/Copenhagen', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(53, 'DJ', 'Djibouti', 'Africa/Djibouti', 'UTC+03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(54, 'DM', 'Dominica', 'America/Dominica', 'UTC-04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(55, 'DO', 'Dominican Republic', 'America/Santo_Domingo', 'UTC-04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(56, 'EC', 'Ecuador', 'America/Guayaquil', 'UTC-05:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(57, 'EG', 'Egypt', 'Africa/Cairo', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(58, 'SV', 'El Salvador', 'America/El_Salvador', 'UTC-06:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(59, 'GQ', 'Equatorial Guinea', 'Africa/Malabo', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(60, 'ER', 'Eritrea', 'Africa/Asmara', 'UTC+03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(61, 'EE', 'Estonia', 'Europe/Tallinn', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(62, 'SZ', 'Eswatini', 'Africa/Mbabane', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(63, 'ET', 'Ethiopia', 'Africa/Addis_Ababa', 'UTC+03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(64, 'FO', 'Faroe Islands', 'Atlantic/Faroe', 'UTC+00:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(65, 'FJ', 'Fiji', 'Pacific/Fiji', 'UTC+12:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(66, 'FI', 'Finland', 'Europe/Helsinki', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(67, 'FR', 'France', 'Europe/Paris', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(68, 'GF', 'French Guiana', 'America/Cayenne', 'UTC-03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(69, 'PF', 'French Polynesia', 'Pacific/Tahiti', 'UTC-10:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(70, 'GA', 'Gabon', 'Africa/Libreville', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(71, 'GM', 'Gambia', 'Africa/Banjul', 'UTC+00:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(72, 'GE', 'Georgia', 'Asia/Tbilisi', 'UTC+04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(73, 'DE', 'Germany', 'Europe/Berlin', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(74, 'GH', 'Ghana', 'Africa/Accra', 'UTC+00:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(75, 'GI', 'Gibraltar', 'Europe/Gibraltar', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(76, 'GR', 'Greece', 'Europe/Athens', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(77, 'GL', 'Greenland', 'America/Godthab', 'UTC-03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(78, 'GD', 'Grenada', 'America/Grenada', 'UTC-04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(79, 'GP', 'Guadeloupe', 'America/Guadeloupe', 'UTC-04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(80, 'GU', 'Guam', 'Pacific/Guam', 'UTC+10:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(81, 'GT', 'Guatemala', 'America/Guatemala', 'UTC-06:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(82, 'GG', 'Guernsey', 'Europe/Guernsey', 'UTC+00:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(83, 'GN', 'Guinea', 'Africa/Conakry', 'UTC+00:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(84, 'GW', 'Guinea-Bissau', 'Africa/Bissau', 'UTC+00:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(85, 'GY', 'Guyana', 'America/Guyana', 'UTC-04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(86, 'HT', 'Haiti', 'America/Port-au-Prince', 'UTC-05:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(87, 'HN', 'Honduras', 'America/Tegucigalpa', 'UTC-06:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(88, 'HK', 'Hong Kong', 'Asia/Hong_Kong', 'UTC+08:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(89, 'HU', 'Hungary', 'Europe/Budapest', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(90, 'IS', 'Iceland', 'Atlantic/Reykjavik', 'UTC+00:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(91, 'IN', 'India', 'Asia/Kolkata', 'UTC+05:30', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(92, 'ID', 'Indonesia', 'Asia/Jakarta', 'UTC+07:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(93, 'IR', 'Iran', 'Asia/Tehran', 'UTC+03:30', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(94, 'IQ', 'Iraq', 'Asia/Baghdad', 'UTC+03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(95, 'IE', 'Ireland', 'Europe/Dublin', 'UTC+00:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(96, 'IM', 'Isle of Man', 'Europe/Isle_of_Man', 'UTC+00:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(97, 'IL', 'Israel', 'Asia/Jerusalem', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(98, 'IT', 'Italy', 'Europe/Rome', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(99, 'JM', 'Jamaica', 'America/Jamaica', 'UTC-05:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(100, 'JP', 'Japan', 'Asia/Tokyo', 'UTC+09:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(101, 'JE', 'Jersey', 'Europe/Jersey', 'UTC+00:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(102, 'JO', 'Jordan', 'Asia/Amman', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(103, 'KZ', 'Kazakhstan', 'Asia/Almaty', 'UTC+06:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(104, 'KE', 'Kenya', 'Africa/Nairobi', 'UTC+03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(105, 'KI', 'Kiribati', 'Pacific/Tarawa', 'UTC+12:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(106, 'KP', 'Korea, North', 'Asia/Pyongyang', 'UTC+09:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(107, 'KR', 'Korea, South', 'Asia/Seoul', 'UTC+09:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(108, 'KW', 'Kuwait', 'Asia/Kuwait', 'UTC+03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(109, 'KG', 'Kyrgyzstan', 'Asia/Bishkek', 'UTC+06:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(110, 'LV', 'Latvia', 'Europe/Riga', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(111, 'LB', 'Lebanon', 'Asia/Beirut', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(112, 'LS', 'Lesotho', 'Africa/Maseru', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(113, 'LR', 'Liberia', 'Africa/Monrovia', 'UTC+00:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(114, 'LY', 'Libya', 'Africa/Tripoli', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(115, 'LI', 'Liechtenstein', 'Europe/Vaduz', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(116, 'LT', 'Lithuania', 'Europe/Vilnius', 'UTC+03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(117, 'LU', 'Luxembourg', 'Europe/Luxembourg', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(118, 'MO', 'Macao', 'Asia/Macau', 'UTC+08:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(119, 'MG', 'Madagascar', 'Indian/Antananarivo', 'UTC+03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(120, 'MW', 'Malawi', 'Africa/Blantyre', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(121, 'MY', 'Malaysia', 'Asia/Kuala_Lumpur', 'UTC+08:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(122, 'MV', 'Maldives', 'Indian/Maldives', 'UTC+05:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(123, 'ML', 'Mali', 'Africa/Bamako', 'UTC+00:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(124, 'MT', 'Malta', 'Europe/Malta', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(125, 'MH', 'Marshall Islands', 'Pacific/Majuro', 'UTC+12:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(126, 'MQ', 'Martinique', 'America/Martinique', 'UTC-04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(127, 'MR', 'Mauritania', 'Africa/Nouakchott', 'UTC+00:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(128, 'MU', 'Mauritius', 'Indian/Mauritius', 'UTC+04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(129, 'MX', 'Mexico', 'America/Mexico_City', 'UTC-06:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(130, 'FM', 'Micronesia', 'Pacific/Chuuk', 'UTC+10:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(131, 'MD', 'Moldova', 'Europe/Chisinau', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(132, 'MC', 'Monaco', 'Europe/Monaco', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(133, 'MN', 'Mongolia', 'Asia/Ulaanbaatar', 'UTC+08:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(134, 'ME', 'Montenegro', 'Europe/Podgorica', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(135, 'MA', 'Morocco', 'Africa/Casablanca', 'UTC+00:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(136, 'MZ', 'Mozambique', 'Africa/Maputo', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(137, 'MM', 'Myanmar', 'Asia/Yangon', 'UTC+06:30', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(138, 'NA', 'Namibia', 'Africa/Windhoek', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(139, 'NR', 'Nauru', 'Pacific/Nauru', 'UTC+12:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(140, 'NP', 'Nepal', 'Asia/Kathmandu', 'UTC+05:45', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(141, 'NL', 'Netherlands', 'Europe/Amsterdam', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(142, 'NZ', 'New Zealand', 'Pacific/Auckland', 'UTC+12:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(143, 'NI', 'Nicaragua', 'America/Managua', 'UTC-06:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(144, 'NE', 'Niger', 'Africa/Niamey', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(145, 'NG', 'Nigeria', 'Africa/Lagos', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(146, 'NO', 'Norway', 'Europe/Oslo', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(147, 'OM', 'Oman', 'Asia/Muscat', 'UTC+04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(148, 'PK', 'Pakistan', 'Asia/Karachi', 'UTC+05:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(149, 'PW', 'Palau', 'Pacific/Palau', 'UTC+09:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(150, 'PS', 'Palestine', 'Asia/Gaza', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(151, 'PA', 'Panama', 'America/Panama', 'UTC-05:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(152, 'PG', 'Papua New Guinea', 'Pacific/Port_Moresby', 'UTC+10:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(153, 'PY', 'Paraguay', 'America/Asuncion', 'UTC-04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(154, 'PE', 'Peru', 'America/Lima', 'UTC-05:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(155, 'PH', 'Philippines', 'Asia/Manila', 'UTC+08:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(156, 'PL', 'Poland', 'Europe/Warsaw', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(157, 'PT', 'Portugal', 'Europe/Lisbon', 'UTC+00:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(158, 'QA', 'Qatar', 'Asia/Qatar', 'UTC+03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(159, 'RE', 'Reunion', 'Indian/Reunion', 'UTC+04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(160, 'RO', 'Romania', 'Europe/Bucharest', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(161, 'RU', 'Russia', 'Europe/Moscow', 'UTC+03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(162, 'RW', 'Rwanda', 'Africa/Kigali', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(163, 'KN', 'Saint Kitts and Nevis', 'America/St_Kitts', 'UTC-04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(164, 'LC', 'Saint Lucia', 'America/St_Lucia', 'UTC-04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(165, 'VC', 'Saint Vincent and the Grenadines', 'America/St_Vincent', 'UTC-04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(166, 'WS', 'Samoa', 'Pacific/Apia', 'UTC+13:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(167, 'SM', 'San Marino', 'Europe/San_Marino', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(168, 'ST', 'Sao Tome and Principe', 'Africa/Sao_Tome', 'UTC+00:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(169, 'SA', 'Saudi Arabia', 'Asia/Riyadh', 'UTC+03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(170, 'SN', 'Senegal', 'Africa/Dakar', 'UTC+00:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(171, 'RS', 'Serbia', 'Europe/Belgrade', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(172, 'SC', 'Seychelles', 'Indian/Mahe', 'UTC+04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(173, 'SL', 'Sierra Leone', 'Africa/Freetown', 'UTC+00:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(174, 'SG', 'Singapore', 'Asia/Singapore', 'UTC+08:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(175, 'SK', 'Slovakia', 'Europe/Bratislava', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(176, 'SI', 'Slovenia', 'Europe/Ljubljana', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(177, 'SB', 'Solomon Islands', 'Pacific/Guadalcanal', 'UTC+11:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(178, 'SO', 'Somalia', 'Africa/Mogadishu', 'UTC+03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(179, 'ZA', 'South Africa', 'Africa/Johannesburg', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(180, 'SS', 'South Sudan', 'Africa/Juba', 'UTC+03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(181, 'ES', 'Spain', 'Europe/Madrid', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(182, 'LK', 'Sri Lanka', 'Asia/Colombo', 'UTC+05:30', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(183, 'SD', 'Sudan', 'Africa/Khartoum', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(184, 'SR', 'Suriname', 'America/Paramaribo', 'UTC-03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(185, 'SE', 'Sweden', 'Europe/Stockholm', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(186, 'CH', 'Switzerland', 'Europe/Zurich', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(187, 'SY', 'Syria', 'Asia/Damascus', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(188, 'TW', 'Taiwan', 'Asia/Taipei', 'UTC+08:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(189, 'TJ', 'Tajikistan', 'Asia/Dushanbe', 'UTC+05:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(190, 'TZ', 'Tanzania', 'Africa/Dar_es_Salaam', 'UTC+03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(191, 'TH', 'Thailand', 'Asia/Bangkok', 'UTC+07:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(192, 'TL', 'Timor-Leste', 'Asia/Dili', 'UTC+09:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(193, 'TG', 'Togo', 'Africa/Lome', 'UTC+00:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(194, 'TO', 'Tonga', 'Pacific/Tongatapu', 'UTC+13:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(195, 'TT', 'Trinidad and Tobago', 'America/Port_of_Spain', 'UTC-04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(196, 'TN', 'Tunisia', 'Africa/Tunis', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(197, 'TR', 'Turkey', 'Europe/Istanbul', 'UTC+03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(198, 'TM', 'Turkmenistan', 'Asia/Ashgabat', 'UTC+05:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(199, 'TV', 'Tuvalu', 'Pacific/Funafuti', 'UTC+12:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(200, 'UG', 'Uganda', 'Africa/Kampala', 'UTC+03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(201, 'UA', 'Ukraine', 'Europe/Kiev', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 17:15:34', 0),
(202, 'AE', 'United Arab Emirates', 'Asia/Dubai', 'UTC+04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(203, 'GB', 'United Kingdom', 'Europe/London', 'UTC+00:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(204, 'US', 'United States', 'America/New_York', 'UTC-05:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(205, 'UY', 'Uruguay', 'America/Montevideo', 'UTC-03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(206, 'UZ', 'Uzbekistan', 'Asia/Tashkent', 'UTC+05:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(207, 'VU', 'Vanuatu', 'Pacific/Efate', 'UTC+11:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(208, 'VA', 'Vatican City', 'Europe/Vatican', 'UTC+01:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(209, 'VE', 'Venezuela', 'America/Caracas', 'UTC-04:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(210, 'VN', 'Vietnam', 'Asia/Ho_Chi_Minh', 'UTC+07:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(211, 'YE', 'Yemen', 'Asia/Aden', 'UTC+03:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(212, 'ZM', 'Zambia', 'Africa/Lusaka', 'UTC+02:00', '2024-07-27 22:17:20', '2024-07-27 22:17:20', 1),
(213, 'ZW', 'Zimbabwe', 'Africa/Harare', 'UTC+02:00', '2024-07-27 22:17:20', '2024-08-03 16:20:50', 1);

-- --------------------------------------------------------

--
-- Table structure for table `cron_jobs`
--

CREATE TABLE `cron_jobs` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `name` varchar(255) NOT NULL,
  `url` varchar(255) NOT NULL,
  `schedule` varchar(255) NOT NULL,
  `status` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `cron_jobs`
--

INSERT INTO `cron_jobs` (`id`, `name`, `url`, `schedule`, `status`, `created_at`, `updated_at`) VALUES
(1, 'Send Lead Notification', '/api/send-lead-notification', '0 10 * * *', 1, NULL, NULL),
(2, 'Store Recommended Leads', '/api/storeRecommendedLeads', '0 0 * * *', 1, NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `documents`
--

CREATE TABLE `documents` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `type` varchar(255) NOT NULL,
  `serial_number` varchar(255) NOT NULL,
  `customer_id` bigint(20) UNSIGNED DEFAULT NULL,
  `employee_id` bigint(20) UNSIGNED DEFAULT NULL,
  `ref_invoice` varchar(255) DEFAULT NULL,
  `ref_order_no` varchar(100) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `total_amount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `net_amount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `pending_amount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `discount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `advance` decimal(10,2) NOT NULL DEFAULT 0.00,
  `delivery_date` timestamp NULL DEFAULT NULL,
  `discount_precentage` decimal(5,2) NOT NULL DEFAULT 0.00,
  `payment_mode` varchar(255) DEFAULT NULL,
  `discount_type` varchar(255) DEFAULT NULL,
  `total_items` int(11) NOT NULL DEFAULT 0,
  `total_qty` int(11) NOT NULL DEFAULT 0,
  `total_gst` decimal(10,2) NOT NULL DEFAULT 0.00,
  `discount_amount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `created_by` int(11) NOT NULL DEFAULT 0,
  `updated_by` int(11) NOT NULL DEFAULT 0,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `documents`
--

INSERT INTO `documents` (`id`, `type`, `serial_number`, `customer_id`, `employee_id`, `ref_invoice`, `ref_order_no`, `description`, `total_amount`, `net_amount`, `pending_amount`, `discount`, `advance`, `delivery_date`, `discount_precentage`, `payment_mode`, `discount_type`, `total_items`, `total_qty`, `total_gst`, `discount_amount`, `created_by`, `updated_by`, `created_at`, `updated_at`) VALUES
(1, 'order', 'ORD-2025-08-001', 248, NULL, '123', NULL, NULL, 4000.00, 4499.00, 2000.00, 14.51, 2000.00, '2025-08-13 06:46:00', 679.00, 'UPI', 'amount', 2, 2, 180.00, 679.00, 3, 0, '2025-08-12 06:46:41', '2025-08-12 06:46:41');

-- --------------------------------------------------------

--
-- Table structure for table `employee_commission`
--

CREATE TABLE `employee_commission` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `employee_id` bigint(20) UNSIGNED NOT NULL,
  `doc_id` bigint(20) UNSIGNED NOT NULL,
  `product` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`product`)),
  `service` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`service`)),
  `total_amount` decimal(12,2) NOT NULL DEFAULT 0.00,
  `status` tinyint(1) NOT NULL DEFAULT 1,
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `employee_login_setting`
--

CREATE TABLE `employee_login_setting` (
  `id` int(11) NOT NULL,
  `business_ids` varchar(50) DEFAULT NULL,
  `type` enum('business user','sales user','operational user','Both') NOT NULL,
  `status` tinyint(1) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `employee_login_setting`
--

INSERT INTO `employee_login_setting` (`id`, `business_ids`, `type`, `status`) VALUES
(1, '2', 'operational user', 1),
(2, '1,3,5,6,7,8,9,10,11,12,13', 'business user', 1),
(3, '4', 'sales user', 1);

-- --------------------------------------------------------

--
-- Table structure for table `ent_form_builder`
--

CREATE TABLE `ent_form_builder` (
  `id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `bussiness_ids` varchar(255) NOT NULL,
  `status_master` varchar(250) DEFAULT NULL,
  `form` longtext DEFAULT NULL,
  `status` int(11) NOT NULL DEFAULT 1,
  `is_deleted` tinyint(4) NOT NULL DEFAULT 0,
  `created_on` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_on` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ent_form_builder`
--

INSERT INTO `ent_form_builder` (`id`, `name`, `bussiness_ids`, `status_master`, `form`, `status`, `is_deleted`, `created_on`, `updated_on`) VALUES
(1, 'service_catalogs', '1,3,4,5,6,7,8,9,10,13', NULL, '[{\"type\":\"text\",\"required\":true,\"label\":\"Service Name/Title\",\"name\":\"title\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"select\",\"required\":true,\"label\":\"Category\",\"name\":\"category_name\",\"access\":false,\"multiple\":false,\"DataType\":\"varchar\",\"QueryRule\":\"get_category_by_service\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 2\",\"value\":\"option-2\",\"selected\":false}]},{\"type\":\"file\",\"required\":false,\"label\":\"Service Image\",\"name\":\"image\",\"access\":false,\"multiple\":false},{\"type\":\"number\",\"required\":false,\"label\":\"Enter Price in Rupees\",\"name\":\"price\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"number\",\"required\":false,\"label\":\"Enter Offer Price if Any\",\"name\":\"offer\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"textarea\",\"required\":false,\"label\":\"Service Description\",\"name\":\"description\",\"access\":false,\"subtype\":\"textarea\"},{\"type\":\"select\",\"required\":false,\"label\":\"Select GST\",\"name\":\"gst_percentage\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"0\",\"value\":\"0%\",\"selected\":true},{\"label\":\"5\",\"value\":\"5%\",\"selected\":false},{\"label\":\"12\",\"value\":\"12%\",\"selected\":false},{\"label\":\"18\",\"value\":\"18%\",\"selected\":false}]},{\"type\":\"number\",\"required\":false,\"label\":\"Employee Percentage\",\"name\":\"employee_percentage\",\"access\":false,\"subtype\":\"number\"}]', 1, 0, '2024-09-19 10:43:04', '2024-09-19 10:43:04'),
(2, 'appointment', '1,2,3,4,5,6,7,8,9,10,11,12,13', NULL, '[{\"type\":\"number\",\"required\":true,\"label\":\"Phone\",\"name\":\"phone\",\"access\":false,\"subtype\":\"number\",\"DataType\":\"varchar(255)\"},{\"type\":\"text\",\"required\":true,\"label\":\"Name\",\"name\":\"name\",\"access\":false,\"subtype\":\"text\",\"DataType\":\"varchar(255)\"},{\"type\":\"date\",\"subtype\":\"datetime-local\",\"required\":true,\"label\":\"Scheduled On\",\"name\":\"date\",\"access\":false,\"DataType\":\"DATETIME\"},{\"type\":\"select\",\"required\":false,\"label\":\"Visiting or looking for\",\"name\":\"looking_for\",\"access\":false,\"multiple\":true,\"DataType\":\"varchar(255)\",\"QueryRule\":\"get_category_by_name\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1-\",\"selected\":true},{\"label\":\"Option 3\",\"value\":\"option-3-\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Assigned To\",\"name\":\"assignedTo\",\"access\":false,\"multiple\":false,\"DataType\":\"varchar\",\"QueryRule\":\"get_employeeNameList\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1-\",\"selected\":true},{\"label\":\"Option 2\",\"value\":\"option-2-\",\"selected\":false}]}]', 1, 0, '2024-10-17 06:15:32', '2024-10-17 06:15:32'),
(3, 'employees', '1,3,5,6,7,8,9,10,11,12,13', NULL, '[{\"type\":\"file\",\"required\":false,\"label\":\"Employee Picture\",\"name\":\"image\",\"access\":false,\"multiple\":false},{\"type\":\"text\",\"required\":true,\"label\":\"First Name\",\"name\":\"first_name\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":true,\"label\":\"Last Name\",\"name\":\"last_name\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":false,\"label\":\"Business Name or Alias\",\"name\":\"business_name\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"number\",\"required\":false,\"label\":\"Mobile Number\",\"name\":\"mobile\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"number\",\"required\":false,\"label\":\"Alternative Mobile Number\",\"name\":\"alternative_mobile\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"radio-group\",\"required\":false,\"label\":\"Salary Type\",\"inline\":false,\"name\":\"salary_type\",\"access\":false,\"other\":false,\"values\":[{\"label\":\"Monthly\",\"value\":\"monthly\",\"selected\":false},{\"label\":\"Yearly\",\"value\":\"yearly\",\"selected\":false},{\"label\":\"Hourly\",\"value\":\"hourly\",\"selected\":false}]},{\"type\":\"number\",\"required\":false,\"label\":\"Salary Value (in Rupees)\",\"name\":\"salary_value\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"date\",\"required\":false,\"label\":\"Date of Birth\",\"name\":\"dob\",\"access\":false,\"subtype\":\"date\"},{\"type\":\"date\",\"required\":false,\"label\":\"Date of Joining\",\"name\":\"date_of_joining\",\"access\":false,\"subtype\":\"date\"},{\"type\":\"number\",\"required\":false,\"label\":\"Years of Experience\",\"name\":\"experience\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"radio-group\",\"required\":false,\"label\":\"Select Gender\",\"inline\":false,\"name\":\"gender\",\"access\":false,\"other\":false,\"values\":[{\"label\":\"Male\",\"value\":\"option-1\",\"selected\":false},{\"label\":\"Female\",\"value\":\"option-2\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Job Profile\",\"name\":\"job_profile\",\"access\":false,\"multiple\":false,\"QueryRule\":\"get_job_profile_by_business_id\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 2\",\"value\":\"option-2\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Highest Education\",\"name\":\"highest_education\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"High School\",\"value\":\"High School\",\"selected\":true},{\"label\":\"Intermediate\",\"value\":\"Intermediate\",\"selected\":false},{\"label\":\"Undergraduate\",\"value\":\"Undergraduate(UG)\",\"selected\":false},{\"label\":\"Postgraduate\",\"value\":\"Postgraduate(PG)\",\"selected\":false},{\"label\":\"Doctoral\",\"value\":\"Doctoral(Ph.D.)\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Native Location\",\"name\":\"native_location\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"Karnataka\",\"value\":\"karnataka\",\"selected\":true},{\"label\":\"Other\",\"value\":\"other\",\"selected\":false}]},{\"type\":\"checkbox-group\",\"required\":false,\"label\":\"Language Known\",\"toggle\":false,\"inline\":false,\"name\":\"language_known\",\"access\":false,\"other\":false,\"values\":[{\"label\":\"Kannada\",\"value\":\"kannada\",\"selected\":false},{\"label\":\"English\",\"value\":\"english\",\"selected\":false},{\"label\":\"Hindi\",\"value\":\"hindi\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Employee Type\",\"name\":\"employee_type\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"Business User\",\"value\":\"business user\",\"selected\":true},{\"label\":\"Operational User\",\"value\":\"operational user\",\"selected\":false}]}]', 1, 0, '2024-11-10 06:39:41', '2024-11-10 06:39:41'),
(4, 'product_catalogs', '1,3,4,5,6,7,9,10,13', NULL, '[{\"type\":\"text\",\"required\":true,\"label\":\"Product Name/Title\",\"name\":\"title\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"select\",\"required\":true,\"label\":\"Category\",\"name\":\"category_name\",\"access\":false,\"multiple\":false,\"DataType\":\"varchar\",\"QueryRule\":\"get_category_by_product\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 3\",\"value\":\"option-3\",\"selected\":false}]},{\"type\":\"file\",\"required\":false,\"label\":\"Product Image\",\"name\":\"image\",\"access\":false,\"multiple\":true},{\"type\":\"number\",\"required\":false,\"label\":\"Enter Price in Rupees\",\"name\":\"price\",\"access\":false,\"subtype\":\"number\",\"DataType\":\"VARCHAR\"},{\"type\":\"number\",\"required\":false,\"label\":\"Enter Offer Price if Any\",\"name\":\"offer\",\"access\":false,\"subtype\":\"number\",\"DataType\":\"varchar(255)\"},{\"type\":\"textarea\",\"required\":false,\"label\":\"Product Description\",\"name\":\"description\",\"access\":false,\"subtype\":\"textarea\"},{\"type\":\"text\",\"required\":false,\"label\":\"Size\",\"name\":\"size\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":false,\"label\":\"Color\",\"name\":\"color\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"checkbox-group\",\"required\":false,\"label\":\"Inventory Selling\",\"toggle\":false,\"inline\":false,\"name\":\"is_inventory\",\"access\":false,\"other\":false,\"DataType\":\"integer(11)default(0)\",\"values\":[{\"label\":\"Inventory Selling\",\"value\":\"1\",\"selected\":false}]},{\"type\":\"number\",\"required\":false,\"label\":\"Available Quantity\",\"name\":\"available_quantity\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"select\",\"required\":false,\"label\":\"Select GST\",\"name\":\"gst_percentage\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"0\",\"value\":\"0%\",\"selected\":true},{\"label\":\"5\",\"value\":\"5%\",\"selected\":false},{\"label\":\"12\",\"value\":\"12%\",\"selected\":false},{\"label\":\"18\",\"value\":\"18%\",\"selected\":false}]},{\"type\":\"number\",\"required\":false,\"label\":\"Employee Percentage\",\"name\":\"employee_percentage\",\"access\":false,\"subtype\":\"number\"}]', 1, 0, '2024-09-19 10:35:59', '2024-09-19 10:35:59'),
(5, 'business history', '1,2,3,4,5,6,7,8,9,10,11,12,13', '1', '[{\"type\":\"date\",\"required\":true,\"label\":\"Schedule on\",\"name\":\"schedule_on\",\"access\":false,\"subtype\":\"date\"},{\"type\":\"select\",\"required\":true,\"label\":\"Looking for/Interested\",\"name\":\"looking_for\",\"access\":false,\"multiple\":false,\"DataType\":\"varchar(255)\",\"QueryRule\":\"get_category_by_name\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1-\",\"selected\":true},{\"label\":\"Option 3\",\"value\":\"option-3-\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Assigned To\",\"name\":\"assignedTo\",\"access\":false,\"multiple\":false,\"QueryRule\":\"get_employeeNameList\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 2\",\"value\":\"option-2\",\"selected\":false}]}]', 1, 0, '2024-11-11 11:08:02', '2024-11-11 11:08:02'),
(6, 'business history', '1,2,3,4,5,6,7,8,9,10,11,12,13', '2', '[{\"type\":\"date\",\"required\":true,\"label\":\"Follow Up On\",\"name\":\"follow_up_on\",\"access\":false,\"subtype\":\"date\"},{\"type\":\"select\",\"required\":false,\"label\":\"Level\",\"name\":\"level\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"NA\",\"value\":\"NA\",\"selected\":true},{\"label\":\"Hot\",\"value\":\"Hot\",\"selected\":false},{\"label\":\"Warm\",\"value\":\"Warm\",\"selected\":false},{\"label\":\"Cold\",\"value\":\"Cold\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Deal Stage\",\"name\":\"deal_stage\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"NA\",\"value\":\"NA\",\"selected\":true},{\"label\":\"Enquiry\",\"value\":\"Enquiry\",\"selected\":false},{\"label\":\"Proposal\",\"value\":\"Proposal\",\"selected\":false},{\"label\":\"Lost\",\"value\":\"Lost\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Chances\",\"name\":\"chances\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"High\",\"value\":\"High\",\"selected\":true},{\"label\":\"Medium\",\"value\":\"Medium\",\"selected\":false},{\"label\":\"Low\",\"value\":\"Low\",\"selected\":false}]},{\"type\":\"select\",\"required\":true,\"label\":\"Follow Up For\",\"name\":\"follow_up_for\",\"access\":false,\"multiple\":false,\"QueryRule\":\"get_category_by_name\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 2\",\"value\":\"option-2\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Business Value\",\"name\":\"business_value\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"NA\",\"value\":\"NA\",\"selected\":true},{\"label\":\"High\",\"value\":\"High\",\"selected\":false},{\"label\":\"Medium\",\"value\":\"Medium\",\"selected\":false},{\"label\":\"Average\",\"value\":\"Average\",\"selected\":false}]}]', 1, 0, '2024-11-12 02:38:34', '2024-11-12 02:38:34'),
(7, 'business history', '1,2,3,4,5,6,7,8,9,10,11,12,13', '3', '[{\"type\":\"date\",\"required\":true,\"label\":\"Hold Till\",\"name\":\"hold_till\",\"access\":false,\"subtype\":\"date\"},{\"type\":\"select\",\"required\":true,\"label\":\"Reason\",\"name\":\"reason\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"Not Interested\",\"value\":\"Not Interested\",\"selected\":true},{\"label\":\"Out of Reach\",\"value\":\"Out of Reach\",\"selected\":false},{\"label\":\"Other\",\"value\":\"Other\",\"selected\":false}]}]', 1, 0, '2024-11-12 02:40:15', '2024-11-12 02:40:15'),
(8, 'business history', '1,2,3,4,5,6,7,8,9,10,11,12,13', '4', '[{\"type\":\"date\",\"required\":true,\"label\":\"Service/Product Purchased On\",\"name\":\"purchased_on\",\"access\":false,\"subtype\":\"date\"},{\"type\":\"select\",\"required\":true,\"label\":\"Current Visited For\",\"name\":\"visited_for\",\"access\":false,\"multiple\":false,\"QueryRule\":\"get_category_by_name\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1-\",\"selected\":true},{\"label\":\"Option 2\",\"value\":\"option-2-\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Chances of Revisit/Purchase ?\",\"name\":\"chances_of_revisit\",\"access\":false,\"multiple\":false,\"QueryRule\":\"get_chances\",\"values\":[{\"label\":\"High\",\"value\":\"high\",\"selected\":true},{\"label\":\"Low\",\"value\":\"low\",\"selected\":false}]},{\"type\":\"date\",\"required\":false,\"label\":\"Tentative Revisit/Purchase ?\",\"name\":\"tentative_revisit\",\"access\":false,\"subtype\":\"date\"}]', 1, 0, '2024-11-18 05:01:38', '2024-11-18 05:01:38'),
(9, 'account_details', '1,2,3,4,5,6,7,8,9,10,11,12,13', NULL, '[{\"type\":\"text\",\"required\":true,\"label\":\"Name in UPI\",\"name\":\"upi_name\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":true,\"label\":\"UPI ID\",\"name\":\"upi_id\",\"access\":false,\"subtype\":\"text\"}]', 1, 0, '2025-02-06 12:18:32', '2025-02-06 12:18:32'),
(10, 'customer_bank_detail', '11', NULL, '[{\"type\":\"text\",\"required\":true,\"label\":\"Company Name\",\"name\":\"company_name\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":true,\"label\":\"Bank Name\",\"name\":\"bank_name\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"select\",\"required\":true,\"label\":\"Account Type\",\"name\":\"account_type\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"Saving Account\",\"value\":\"Saving Account\",\"selected\":true},{\"label\":\"Current Account\",\"value\":\"Current Account\",\"selected\":false},{\"label\":\"Loan Account\",\"value\":\"Loan Account\",\"selected\":false}]},{\"type\":\"text\",\"required\":true,\"label\":\"IFSC Code\",\"name\":\"ifsc\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":true,\"label\":\"Account Number\",\"name\":\"account_number\",\"access\":false,\"value\":\"Account Number\",\"subtype\":\"text\"}]', 1, 0, '2025-04-22 04:02:55', '2025-04-22 04:02:55'),
(11, 'service_catalogs', '11', NULL, '[{\"type\":\"text\",\"required\":true,\"label\":\"Product Name\",\"name\":\"product_name\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":false,\"label\":\"Sub Name\",\"name\":\"sub_name\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":false,\"label\":\"Type\",\"name\":\"type\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":false,\"label\":\"Service Tax\",\"name\":\"service_tax\",\"access\":false,\"subtype\":\"text\"}]', 1, 0, '2025-04-22 04:02:55', '2025-04-22 04:02:55'),
(12, 'priscription', '8', NULL, '[{\"type\":\"checkbox-group\",\"required\":false,\"label\":\"Wear Type\",\"toggle\":false,\"inline\":false,\"name\":\"wear_type\",\"access\":false,\"other\":false,\"values\":[{\"label\":\"Full Time\",\"value\":\"full_time\",\"selected\":true},{\"label\":\"Distance Only\",\"value\":\"distance_only\",\"selected\":true},{\"label\":\"Intermediate Only\",\"value\":\"intermediate_only\",\"selected\":true},{\"label\":\"Reading Only\",\"value\":\"reading_only\",\"selected\":true},{\"label\":\"AS Needed\",\"value\":\"as_needed\",\"selected\":true}]},{\"type\":\"checkbox-group\",\"required\":false,\"label\":\"Lens Design\",\"toggle\":false,\"inline\":false,\"name\":\"lens_design\",\"access\":false,\"other\":false,\"values\":[{\"label\":\"Single Vision\",\"value\":\"single_vision\",\"selected\":true},{\"label\":\"Bifocal\",\"value\":\"bifocal\",\"selected\":true},{\"label\":\"Progressive\",\"value\":\"progressive\",\"selected\":true}]},{\"type\":\"checkbox-group\",\"required\":false,\"label\":\"Materials / Coats\",\"toggle\":false,\"inline\":false,\"name\":\"materials_coats\",\"access\":false,\"other\":false,\"values\":[{\"label\":\"Plastic\",\"value\":\"plastic\",\"selected\":true},{\"label\":\"Transition\",\"value\":\"transition\",\"selected\":true},{\"label\":\"Tint\",\"value\":\"tint\",\"selected\":true},{\"label\":\"UV Coating\",\"value\":\"uv_coating\",\"selected\":true},{\"label\":\"AR Coating\",\"value\":\"ar_coating\",\"selected\":true}]},{\"type\":\"number\",\"required\":false,\"label\":\"Age\",\"name\":\"age\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"textarea\",\"required\":false,\"label\":\"Prescription\",\"name\":\"priscription\",\"access\":false,\"subtype\":\"textarea\"}]', 1, 0, '2025-05-17 08:20:17', '2025-05-17 08:20:17'),
(13, 'invoice', '1,2,3,4,5,6,7,8,9,10,11,12,13', NULL, '[{\"type\":\"textarea\",\"required\":false,\"label\":\"Descrition\",\"name\":\"description\",\"access\":false,\"subtype\":\"textarea\"},{\"type\":\"number\",\"required\":false,\"label\":\"Discount\",\"name\":\"discount\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"number\",\"required\":false,\"label\":\"Advance\",\"name\":\"advance\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"date\",\"required\":false,\"label\":\"Delivery Date\",\"name\":\"delivery_date\",\"access\":false,\"subtype\":\"date\"},{\"type\":\"file\",\"required\":false,\"label\":\"Attachment\",\"name\":\"attachment\",\"access\":false,\"multiple\":true}]', 1, 0, '2025-06-03 11:26:32', '2025-06-03 11:26:32'),
(14, 'product_catalogs', '8', NULL, '[{\"type\":\"text\",\"required\":true,\"label\":\"Product Name/Title\",\"name\":\"title\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"select\",\"required\":true,\"label\":\"Category\",\"name\":\"category_name\",\"access\":false,\"multiple\":false,\"DataType\":\"varchar\",\"QueryRule\":\"get_category_by_product\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 3\",\"value\":\"option-3\",\"selected\":false}]},{\"type\":\"autocomplete\",\"required\":false,\"label\":\"Brand\",\"name\":\"brand\",\"access\":true,\"requireValidOption\":false,\"QueryRule\":\"get_brand_list\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 2\",\"value\":\"option-2\",\"selected\":false}]},{\"type\":\"file\",\"required\":false,\"label\":\"Product Image\",\"name\":\"image\",\"access\":false,\"multiple\":true},{\"type\":\"number\",\"required\":false,\"label\":\"Enter Price in Rupees\",\"name\":\"price\",\"access\":false,\"subtype\":\"number\",\"DataType\":\"VARCHAR\"},{\"type\":\"number\",\"required\":false,\"label\":\"Enter Offer Price if Any\",\"name\":\"offer\",\"access\":false,\"subtype\":\"number\",\"DataType\":\"varchar(255)\"},{\"type\":\"textarea\",\"required\":false,\"label\":\"Product Description\",\"name\":\"description\",\"access\":false,\"subtype\":\"textarea\"},{\"type\":\"select\",\"required\":false,\"label\":\"Size\",\"name\":\"size\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 2\",\"value\":\"option-2\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Color\",\"name\":\"color\",\"access\":false,\"multiple\":false,\"QueryRule\":\"get_color_list\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 2\",\"value\":\"option-2\",\"selected\":false}]},{\"type\":\"checkbox-group\",\"required\":false,\"label\":\"Inventory Selling\",\"toggle\":false,\"inline\":false,\"name\":\"is_inventory\",\"access\":false,\"other\":false,\"DataType\":\"integer(11)default(0)\",\"values\":[{\"label\":\"Inventory Selling\",\"value\":\"1\",\"selected\":false}]},{\"type\":\"number\",\"required\":false,\"label\":\"Available Quantity\",\"name\":\"available_quantity\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"select\",\"required\":false,\"label\":\"Select GST\",\"name\":\"gst_percentage\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"0\",\"value\":\"0%\",\"selected\":true},{\"label\":\"5\",\"value\":\"5%\",\"selected\":false},{\"label\":\"12\",\"value\":\"12%\",\"selected\":false},{\"label\":\"18\",\"value\":\"18%\",\"selected\":false}]},{\"type\":\"number\",\"required\":false,\"label\":\"Employee Percentage\",\"name\":\"employee_percentage\",\"access\":false,\"subtype\":\"number\"}]', 1, 0, '2025-06-16 17:09:14', '2025-06-16 17:09:14'),
(15, 'product_catalogs', '2', NULL, '[{\"type\":\"text\",\"required\":true,\"label\":\"Product Name/Title\",\"name\":\"title\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"select\",\"required\":false,\"label\":\"Select Item\",\"name\":\"item_name\",\"access\":false,\"multiple\":false,\"QueryRule\":\"get_item_list\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 2\",\"value\":\"option-2\",\"selected\":false}]},{\"type\":\"select\",\"required\":true,\"label\":\"Category\",\"name\":\"category_name\",\"access\":false,\"multiple\":false,\"DataType\":\"varchar\",\"QueryRule\":\"get_category_by_product\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 3\",\"value\":\"option-3\",\"selected\":false}]},{\"type\":\"file\",\"required\":false,\"label\":\"Product Image\",\"name\":\"image\",\"access\":false,\"multiple\":true},{\"type\":\"number\",\"required\":false,\"label\":\"Enter Price in Rupees\",\"name\":\"price\",\"access\":false,\"subtype\":\"number\",\"DataType\":\"VARCHAR\"},{\"type\":\"number\",\"required\":false,\"label\":\"Enter Offer Price if Any\",\"name\":\"offer\",\"access\":false,\"subtype\":\"number\",\"DataType\":\"varchar(255)\"},{\"type\":\"textarea\",\"required\":false,\"label\":\"Product Description\",\"name\":\"description\",\"access\":false,\"subtype\":\"textarea\"},{\"type\":\"text\",\"required\":false,\"label\":\"Size\",\"name\":\"size\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":false,\"label\":\"Color\",\"name\":\"color\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"checkbox-group\",\"required\":false,\"label\":\"Inventory Selling\",\"toggle\":false,\"inline\":false,\"name\":\"is_inventory\",\"access\":false,\"other\":false,\"DataType\":\"integer(11)default(0)\",\"values\":[{\"label\":\"Inventory Selling\",\"value\":\"1\",\"selected\":false}]},{\"type\":\"number\",\"required\":false,\"label\":\"Available Quantity\",\"name\":\"available_quantity\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"select\",\"required\":false,\"label\":\"Select GST\",\"name\":\"gst_percentage\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"0\",\"value\":\"0%\",\"selected\":true},{\"label\":\"5\",\"value\":\"5%\",\"selected\":false},{\"label\":\"12\",\"value\":\"12%\",\"selected\":false},{\"label\":\"18\",\"value\":\"18%\",\"selected\":false}]},{\"type\":\"number\",\"required\":false,\"label\":\"Employee Percentage\",\"name\":\"employee_percentage\",\"access\":false,\"subtype\":\"number\"}]', 1, 0, '2025-07-09 11:37:07', '2025-07-09 11:37:07'),
(16, 'service_catalogs', '2', NULL, '[{\"type\":\"text\",\"required\":true,\"label\":\"Service Name/Title\",\"name\":\"title\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"select\",\"required\":true,\"label\":\"Category\",\"name\":\"category_name\",\"access\":false,\"multiple\":false,\"DataType\":\"varchar\",\"QueryRule\":\"get_category_by_service\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 2\",\"value\":\"option-2\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Select Item\",\"name\":\"item_name\",\"access\":false,\"multiple\":false,\"QueryRule\":\"get_item_list\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 2\",\"value\":\"option-2\",\"selected\":false}]},{\"type\":\"file\",\"required\":false,\"label\":\"Service Image\",\"name\":\"image\",\"access\":false,\"multiple\":false},{\"type\":\"number\",\"required\":false,\"label\":\"Enter Price in Rupees\",\"name\":\"price\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"number\",\"required\":false,\"label\":\"Enter Offer Price if Any\",\"name\":\"offer\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"textarea\",\"required\":false,\"label\":\"Service Description\",\"name\":\"description\",\"access\":false,\"subtype\":\"textarea\"},{\"type\":\"select\",\"required\":false,\"label\":\"Select GST\",\"name\":\"gst_percentage\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"0\",\"value\":\"0%\",\"selected\":true},{\"label\":\"5\",\"value\":\"5%\",\"selected\":false},{\"label\":\"12\",\"value\":\"12%\",\"selected\":false},{\"label\":\"18\",\"value\":\"18%\",\"selected\":false}]},{\"type\":\"number\",\"required\":false,\"label\":\"Employee Percentage\",\"name\":\"employee_percentage\",\"access\":false,\"subtype\":\"number\"}]', 1, 0, '2024-09-19 10:43:04', '2024-09-19 10:43:04'),
(17, 'employees', '2', NULL, '[{\"type\":\"file\",\"required\":false,\"label\":\"Employee Picture\",\"name\":\"image\",\"access\":false,\"multiple\":false},{\"type\":\"text\",\"required\":true,\"label\":\"First Name\",\"name\":\"first_name\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":true,\"label\":\"Last Name\",\"name\":\"last_name\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":false,\"label\":\"Business Name or Alias\",\"name\":\"business_name\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"number\",\"required\":false,\"label\":\"Mobile Number\",\"name\":\"mobile\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"number\",\"required\":false,\"label\":\"Alternative Mobile Number\",\"name\":\"alternative_mobile\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"radio-group\",\"required\":false,\"label\":\"Salary Type\",\"inline\":false,\"name\":\"salary_type\",\"access\":false,\"other\":false,\"values\":[{\"label\":\"Monthly\",\"value\":\"monthly\",\"selected\":false},{\"label\":\"Yearly\",\"value\":\"yearly\",\"selected\":false},{\"label\":\"Hourly\",\"value\":\"hourly\",\"selected\":false}]},{\"type\":\"number\",\"required\":false,\"label\":\"Salary Value (in Rupees)\",\"name\":\"salary_value\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"date\",\"required\":false,\"label\":\"Date of Birth\",\"name\":\"dob\",\"access\":false,\"subtype\":\"date\"},{\"type\":\"date\",\"required\":false,\"label\":\"Date of Joining\",\"name\":\"date_of_joining\",\"access\":false,\"subtype\":\"date\"},{\"type\":\"number\",\"required\":false,\"label\":\"Years of Experience\",\"name\":\"experience\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"radio-group\",\"required\":false,\"label\":\"Select Gender\",\"inline\":false,\"name\":\"gender\",\"access\":false,\"other\":false,\"values\":[{\"label\":\"Male\",\"value\":\"option-1\",\"selected\":false},{\"label\":\"Female\",\"value\":\"option-2\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Job Profile\",\"name\":\"job_profile\",\"access\":false,\"multiple\":false,\"QueryRule\":\"get_job_profile_by_business_id\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 2\",\"value\":\"option-2\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Highest Education\",\"name\":\"highest_education\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"High School\",\"value\":\"High School\",\"selected\":true},{\"label\":\"Intermediate\",\"value\":\"Intermediate\",\"selected\":false},{\"label\":\"Undergraduate\",\"value\":\"Undergraduate(UG)\",\"selected\":false},{\"label\":\"Postgraduate\",\"value\":\"Postgraduate(PG)\",\"selected\":false},{\"label\":\"Doctoral\",\"value\":\"Doctoral(Ph.D.)\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Native Location\",\"name\":\"native_location\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"Karnataka\",\"value\":\"karnataka\",\"selected\":true},{\"label\":\"Other\",\"value\":\"other\",\"selected\":false}]},{\"type\":\"checkbox-group\",\"required\":false,\"label\":\"Language Known\",\"toggle\":false,\"inline\":false,\"name\":\"language_known\",\"access\":false,\"other\":false,\"values\":[{\"label\":\"Kannada\",\"value\":\"kannada\",\"selected\":false},{\"label\":\"English\",\"value\":\"english\",\"selected\":false},{\"label\":\"Hindi\",\"value\":\"hindi\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Employee Type\",\"name\":\"employee_type\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"Business User\",\"value\":\"business user\",\"selected\":true},{\"label\":\"Operational User\",\"value\":\"operational user\",\"selected\":false}]},{\"type\":\"text\",\"required\":false,\"label\":\"Designation\",\"className\":\"form-control\",\"name\":\"designation\",\"access\":false,\"subtype\":\"text\"}]', 1, 0, '2024-11-10 06:39:41', '2024-11-10 06:39:41'),
(18, 'employees', '4', NULL, '[{\"type\":\"file\",\"required\":false,\"label\":\"Employee Picture\",\"name\":\"image\",\"access\":false,\"multiple\":false},{\"type\":\"text\",\"required\":true,\"label\":\"First Name\",\"name\":\"first_name\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":true,\"label\":\"Last Name\",\"name\":\"last_name\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":false,\"label\":\"Business Name or Alias\",\"name\":\"business_name\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"number\",\"required\":false,\"label\":\"Mobile Number\",\"name\":\"mobile\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"number\",\"required\":false,\"label\":\"Alternative Mobile Number\",\"name\":\"alternative_mobile\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"radio-group\",\"required\":false,\"label\":\"Salary Type\",\"inline\":false,\"name\":\"salary_type\",\"access\":false,\"other\":false,\"values\":[{\"label\":\"Monthly\",\"value\":\"monthly\",\"selected\":false},{\"label\":\"Yearly\",\"value\":\"yearly\",\"selected\":false},{\"label\":\"Hourly\",\"value\":\"hourly\",\"selected\":false}]},{\"type\":\"number\",\"required\":false,\"label\":\"Salary Value (in Rupees)\",\"name\":\"salary_value\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"date\",\"required\":false,\"label\":\"Date of Birth\",\"name\":\"dob\",\"access\":false,\"subtype\":\"date\"},{\"type\":\"date\",\"required\":false,\"label\":\"Date of Joining\",\"name\":\"date_of_joining\",\"access\":false,\"subtype\":\"date\"},{\"type\":\"number\",\"required\":false,\"label\":\"Years of Experience\",\"name\":\"experience\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"radio-group\",\"required\":false,\"label\":\"Select Gender\",\"inline\":false,\"name\":\"gender\",\"access\":false,\"other\":false,\"values\":[{\"label\":\"Male\",\"value\":\"option-1\",\"selected\":false},{\"label\":\"Female\",\"value\":\"option-2\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Job Profile\",\"name\":\"job_profile\",\"access\":false,\"multiple\":false,\"QueryRule\":\"get_job_profile_by_business_id\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 2\",\"value\":\"option-2\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Highest Education\",\"name\":\"highest_education\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"High School\",\"value\":\"High School\",\"selected\":true},{\"label\":\"Intermediate\",\"value\":\"Intermediate\",\"selected\":false},{\"label\":\"Undergraduate\",\"value\":\"Undergraduate(UG)\",\"selected\":false},{\"label\":\"Postgraduate\",\"value\":\"Postgraduate(PG)\",\"selected\":false},{\"label\":\"Doctoral\",\"value\":\"Doctoral(Ph.D.)\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Native Location\",\"name\":\"native_location\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"Karnataka\",\"value\":\"karnataka\",\"selected\":true},{\"label\":\"Other\",\"value\":\"other\",\"selected\":false}]},{\"type\":\"checkbox-group\",\"required\":false,\"label\":\"Language Known\",\"toggle\":false,\"inline\":false,\"name\":\"language_known\",\"access\":false,\"other\":false,\"values\":[{\"label\":\"Kannada\",\"value\":\"kannada\",\"selected\":false},{\"label\":\"English\",\"value\":\"english\",\"selected\":false},{\"label\":\"Hindi\",\"value\":\"hindi\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Employee Type\",\"name\":\"employee_type\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"Business User\",\"value\":\"business user\",\"selected\":true},{\"label\":\"Operational User\",\"value\":\"operational user\",\"selected\":false},{\"label\":\"Sales User\",\"value\":\"sales user\",\"selected\":false}]},{\"type\":\"text\",\"required\":false,\"label\":\"Designation\",\"className\":\"form-control\",\"name\":\"designation\",\"access\":false,\"subtype\":\"text\"}]', 1, 0, '2024-11-10 06:39:41', '2024-11-10 06:39:41');

-- --------------------------------------------------------

--
-- Table structure for table `failed_jobs`
--

CREATE TABLE `failed_jobs` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `uuid` varchar(255) NOT NULL,
  `connection` text NOT NULL,
  `queue` text NOT NULL,
  `payload` longtext NOT NULL,
  `exception` longtext NOT NULL,
  `failed_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `fcm_routes`
--

CREATE TABLE `fcm_routes` (
  `id` int(11) NOT NULL,
  `route_name` varchar(100) NOT NULL,
  `page_name` varchar(100) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1,
  `is_deleted` int(11) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `fcm_routes`
--

INSERT INTO `fcm_routes` (`id`, `route_name`, `page_name`, `status`, `is_deleted`, `created_at`, `updated_at`) VALUES
(1, '/bottomnavbar', 'Main navigation bar', 1, 0, '2025-03-31 07:04:17', '2025-03-31 07:04:17'),
(2, '/service-view', 'View service details', 1, 0, '2025-03-31 07:07:58', '2025-03-31 07:07:58'),
(3, '/marketing-view', 'View marketing campaigns', 1, 0, '2025-03-31 07:07:58', '2025-03-31 07:07:58'),
(4, '/product', 'View product listing', 1, 0, '2025-03-31 07:23:56', '2025-03-31 07:23:56'),
(5, '/add-product', 'Add new product', 1, 0, '2025-03-31 07:23:56', '2025-03-31 07:23:56'),
(6, '/add-service', 'Add new service', 1, 0, '2025-03-31 07:23:56', '2025-03-31 07:23:56'),
(7, '/add-marketing', 'Add new marketing content', 1, 0, '2025-03-31 07:23:56', '2025-03-31 07:23:56'),
(8, '/profile', 'User profile screen', 1, 0, '2025-03-31 07:23:56', '2025-03-31 07:23:56'),
(9, '/add-contact', 'Add a new contact', 1, 0, '2025-03-31 07:23:56', '2025-03-31 07:23:56'),
(10, '/appointment', 'Schedule an appointment', 1, 0, '2025-03-31 07:23:56', '2025-03-31 07:23:56'),
(11, '/add-employee', 'Add a new employee', 1, 0, '2025-03-31 07:23:56', '2025-03-31 07:23:56'),
(12, '/employee-list', 'View employee directory', 1, 0, '2025-03-31 07:23:56', '2025-03-31 07:23:56'),
(13, '/contact', 'View contact details', 1, 0, '2025-03-31 07:23:56', '2025-03-31 07:23:56'),
(14, '/billing-history', 'View previous bills', 1, 0, '2025-03-31 07:23:56', '2025-03-31 07:23:56'),
(15, '/newbilling', 'Create a new bill', 1, 0, '2025-03-31 07:23:56', '2025-03-31 07:23:56'),
(16, '/select-product', 'Choose a product for billing', 1, 0, '2025-03-31 07:23:56', '2025-03-31 07:23:56'),
(17, '/select-service', 'Choose a service for billing', 1, 0, '2025-03-31 07:23:56', '2025-03-31 07:23:56'),
(18, '/appointment-list', 'View scheduled appointments', 1, 0, '2025-03-31 07:23:56', '2025-03-31 07:23:56'),
(19, '/quick-billing', 'Generate quick bills', 1, 0, '2025-03-31 07:23:56', '2025-03-31 07:23:56'),
(20, '/quick-billing-qrcode', 'Scan QR code for quick billing', 1, 0, '2025-03-31 07:23:56', '2025-03-31 07:23:56'),
(21, '/qr-scanner', 'Scan QR codes', 1, 0, '2025-03-31 07:23:56', '2025-03-31 07:23:56'),
(22, '/add-u-p-i', 'Add a new UPI payment method', 1, 0, '2025-03-31 07:23:56', '2025-03-31 07:23:56'),
(23, '/BulkUpdate-FilterView', 'Filter bulk updates', 1, 0, '2025-03-31 07:23:56', '2025-03-31 07:23:56'),
(24, '/QuickBillHistoryview', 'View quick billing history', 1, 0, '2025-03-31 07:23:56', '2025-03-31 07:23:56'),
(25, '/QuickBillHistorypreview', 'Preview quick bills', 1, 0, '2025-03-31 07:23:56', '2025-03-31 07:23:56');

-- --------------------------------------------------------

--
-- Table structure for table `form_builder`
--

CREATE TABLE `form_builder` (
  `id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `bussiness_ids` varchar(255) NOT NULL,
  `status_master` varchar(250) DEFAULT NULL,
  `form` longtext DEFAULT NULL,
  `status` int(11) NOT NULL DEFAULT 1,
  `is_deleted` tinyint(4) NOT NULL DEFAULT 0,
  `created_on` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_on` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `form_builder`
--

INSERT INTO `form_builder` (`id`, `name`, `bussiness_ids`, `status_master`, `form`, `status`, `is_deleted`, `created_on`, `updated_on`) VALUES
(1, 'service_catalogs', '1,3,4,5,6,7,8,9,10,13', NULL, '[{\"type\":\"text\",\"required\":true,\"label\":\"Service Name/Title\",\"name\":\"title\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"select\",\"required\":true,\"label\":\"Category\",\"name\":\"category_name\",\"access\":false,\"multiple\":false,\"DataType\":\"varchar\",\"QueryRule\":\"get_category_by_service\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 2\",\"value\":\"option-2\",\"selected\":false}]},{\"type\":\"file\",\"required\":false,\"label\":\"Service Image\",\"name\":\"image\",\"access\":false,\"multiple\":false},{\"type\":\"number\",\"required\":false,\"label\":\"Enter Price in Rupees\",\"name\":\"price\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"number\",\"required\":false,\"label\":\"Enter Offer Price if Any\",\"name\":\"offer\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"textarea\",\"required\":false,\"label\":\"Service Description\",\"name\":\"description\",\"access\":false,\"subtype\":\"textarea\"},{\"type\":\"select\",\"required\":false,\"label\":\"Select GST\",\"name\":\"gst_percentage\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"0\",\"value\":\"0%\",\"selected\":true},{\"label\":\"5\",\"value\":\"5%\",\"selected\":false},{\"label\":\"12\",\"value\":\"12%\",\"selected\":false},{\"label\":\"18\",\"value\":\"18%\",\"selected\":false}]},{\"type\":\"number\",\"required\":false,\"label\":\"Employee Percentage\",\"name\":\"employee_percentage\",\"access\":false,\"subtype\":\"number\"}]', 1, 0, '2024-09-19 16:13:04', '2024-09-19 16:13:04'),
(2, 'appointment', '1,2,3,4,5,6,7,8,9,10,11,12,13', NULL, '[{\"type\":\"number\",\"required\":true,\"label\":\"Phone\",\"name\":\"phone\",\"access\":false,\"subtype\":\"number\",\"DataType\":\"varchar(255)\"},{\"type\":\"text\",\"required\":true,\"label\":\"Name\",\"name\":\"name\",\"access\":false,\"subtype\":\"text\",\"DataType\":\"varchar(255)\"},{\"type\":\"date\",\"subtype\":\"datetime-local\",\"required\":true,\"label\":\"Scheduled On\",\"name\":\"date\",\"access\":false,\"DataType\":\"DATETIME\"},{\"type\":\"select\",\"required\":false,\"label\":\"Visiting or looking for\",\"name\":\"looking_for\",\"access\":false,\"multiple\":true,\"DataType\":\"varchar(255)\",\"QueryRule\":\"get_category_by_name\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1-\",\"selected\":true},{\"label\":\"Option 3\",\"value\":\"option-3-\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Assigned To\",\"name\":\"assignedTo\",\"access\":false,\"multiple\":false,\"DataType\":\"varchar\",\"QueryRule\":\"get_employeeNameList\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1-\",\"selected\":true},{\"label\":\"Option 2\",\"value\":\"option-2-\",\"selected\":false}]}]', 1, 0, '2024-10-17 11:45:32', '2024-10-17 11:45:32'),
(3, 'employees', '1,2,3,4,5,6,7,8,9,10,11,13', NULL, '[{\"type\":\"file\",\"required\":false,\"label\":\"Employee Picture\",\"name\":\"image\",\"access\":false,\"multiple\":false},{\"type\":\"text\",\"required\":true,\"label\":\"First Name\",\"name\":\"first_name\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":true,\"label\":\"Last Name\",\"name\":\"last_name\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":false,\"label\":\"Business Name or Alias\",\"name\":\"business_name\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"number\",\"required\":false,\"label\":\"Mobile Number\",\"name\":\"mobile\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"number\",\"required\":false,\"label\":\"Alternative Mobile Number\",\"name\":\"alternative_mobile\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"radio-group\",\"required\":false,\"label\":\"Salary Type\",\"inline\":false,\"name\":\"salary_type\",\"access\":false,\"other\":false,\"values\":[{\"label\":\"Monthly\",\"value\":\"monthly\",\"selected\":false},{\"label\":\"Yearly\",\"value\":\"yearly\",\"selected\":false},{\"label\":\"Hourly\",\"value\":\"hourly\",\"selected\":false}]},{\"type\":\"number\",\"required\":false,\"label\":\"Salary Value (in Rupees)\",\"name\":\"salary_value\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"date\",\"required\":false,\"label\":\"Date of Birth\",\"name\":\"dob\",\"access\":false,\"subtype\":\"date\"},{\"type\":\"date\",\"required\":false,\"label\":\"Date of Joining\",\"name\":\"date_of_joining\",\"access\":false,\"subtype\":\"date\"},{\"type\":\"number\",\"required\":false,\"label\":\"Years of Experience\",\"name\":\"experience\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"radio-group\",\"required\":false,\"label\":\"Select Gender\",\"inline\":false,\"name\":\"gender\",\"access\":false,\"other\":false,\"values\":[{\"label\":\"Male\",\"value\":\"option-1\",\"selected\":false},{\"label\":\"Female\",\"value\":\"option-2\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Job Profile\",\"name\":\"job_profile\",\"access\":false,\"multiple\":false,\"QueryRule\":\"get_job_profile_by_business_id\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 2\",\"value\":\"option-2\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Highest Education\",\"name\":\"highest_education\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"High School\",\"value\":\"High School\",\"selected\":true},{\"label\":\"Intermediate\",\"value\":\"Intermediate\",\"selected\":false},{\"label\":\"Undergraduate\",\"value\":\"Undergraduate(UG)\",\"selected\":false},{\"label\":\"Postgraduate\",\"value\":\"Postgraduate(PG)\",\"selected\":false},{\"label\":\"Doctoral\",\"value\":\"Doctoral(Ph.D.)\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Native Location\",\"name\":\"native_location\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"Karnataka\",\"value\":\"karnataka\",\"selected\":true},{\"label\":\"Other\",\"value\":\"other\",\"selected\":false}]},{\"type\":\"checkbox-group\",\"required\":false,\"label\":\"Language Known\",\"toggle\":false,\"inline\":false,\"name\":\"language_known\",\"access\":false,\"other\":false,\"values\":[{\"label\":\"Kannada\",\"value\":\"kannada\",\"selected\":false},{\"label\":\"English\",\"value\":\"english\",\"selected\":false},{\"label\":\"Hindi\",\"value\":\"hindi\",\"selected\":false}]}]', 1, 0, '2024-11-10 12:09:41', '2024-11-10 12:09:41'),
(4, 'product_catalogs', '1,3,4,5,6,7,9,10,13', NULL, '[{\"type\":\"text\",\"required\":true,\"label\":\"Product Name/Title\",\"name\":\"title\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"select\",\"required\":true,\"label\":\"Category\",\"name\":\"category_name\",\"access\":false,\"multiple\":false,\"DataType\":\"varchar\",\"QueryRule\":\"get_category_by_product\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 3\",\"value\":\"option-3\",\"selected\":false}]},{\"type\":\"file\",\"required\":false,\"label\":\"Product Image\",\"name\":\"image\",\"access\":false,\"multiple\":true},{\"type\":\"number\",\"required\":false,\"label\":\"Enter Price in Rupees\",\"name\":\"price\",\"access\":false,\"subtype\":\"number\",\"DataType\":\"VARCHAR\"},{\"type\":\"number\",\"required\":false,\"label\":\"Enter Offer Price if Any\",\"name\":\"offer\",\"access\":false,\"subtype\":\"number\",\"DataType\":\"varchar(255)\"},{\"type\":\"textarea\",\"required\":false,\"label\":\"Product Description\",\"name\":\"description\",\"access\":false,\"subtype\":\"textarea\"},{\"type\":\"text\",\"required\":false,\"label\":\"Size\",\"name\":\"size\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":false,\"label\":\"Color\",\"name\":\"color\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"checkbox-group\",\"required\":false,\"label\":\"Inventory Selling\",\"toggle\":false,\"inline\":false,\"name\":\"is_inventory\",\"access\":false,\"other\":false,\"DataType\":\"integer(11)default(0)\",\"values\":[{\"label\":\"Inventory Selling\",\"value\":\"1\",\"selected\":false}]},{\"type\":\"number\",\"required\":false,\"label\":\"Available Quantity\",\"name\":\"available_quantity\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"select\",\"required\":false,\"label\":\"Select GST\",\"name\":\"gst_percentage\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"0\",\"value\":\"0%\",\"selected\":true},{\"label\":\"5\",\"value\":\"5%\",\"selected\":false},{\"label\":\"12\",\"value\":\"12%\",\"selected\":false},{\"label\":\"18\",\"value\":\"18%\",\"selected\":false}]},{\"type\":\"number\",\"required\":false,\"label\":\"Employee Percentage\",\"name\":\"employee_percentage\",\"access\":false,\"subtype\":\"number\"}]', 1, 0, '2024-09-19 16:05:59', '2024-09-19 16:05:59'),
(5, 'business history', '1,2,3,4,5,6,7,8,9,10,11,12,13', '1', '[{\"type\":\"date\",\"required\":true,\"label\":\"Schedule on\",\"name\":\"schedule_on\",\"access\":false,\"subtype\":\"date\"},{\"type\":\"select\",\"required\":true,\"label\":\"Looking for/Interested\",\"name\":\"looking_for\",\"access\":false,\"multiple\":false,\"DataType\":\"varchar(255)\",\"QueryRule\":\"get_category_by_name\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1-\",\"selected\":true},{\"label\":\"Option 3\",\"value\":\"option-3-\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Assigned To\",\"name\":\"assignedTo\",\"access\":false,\"multiple\":false,\"QueryRule\":\"get_employeeNameList\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 2\",\"value\":\"option-2\",\"selected\":false}]}]', 1, 0, '2024-11-11 16:38:02', '2024-11-11 16:38:02'),
(6, 'business history', '1,2,3,4,5,6,7,8,9,10,11,12,13', '2', '[{\"type\":\"date\",\"required\":true,\"label\":\"Follow Up On\",\"name\":\"follow_up_on\",\"access\":false,\"subtype\":\"date\"},{\"type\":\"select\",\"required\":false,\"label\":\"Level\",\"name\":\"level\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"NA\",\"value\":\"NA\",\"selected\":true},{\"label\":\"Hot\",\"value\":\"Hot\",\"selected\":false},{\"label\":\"Warm\",\"value\":\"Warm\",\"selected\":false},{\"label\":\"Cold\",\"value\":\"Cold\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Deal Stage\",\"name\":\"deal_stage\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"NA\",\"value\":\"NA\",\"selected\":true},{\"label\":\"Enquiry\",\"value\":\"Enquiry\",\"selected\":false},{\"label\":\"Proposal\",\"value\":\"Proposal\",\"selected\":false},{\"label\":\"Lost\",\"value\":\"Lost\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Chances\",\"name\":\"chances\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"High\",\"value\":\"High\",\"selected\":true},{\"label\":\"Medium\",\"value\":\"Medium\",\"selected\":false},{\"label\":\"Low\",\"value\":\"Low\",\"selected\":false}]},{\"type\":\"select\",\"required\":true,\"label\":\"Follow Up For\",\"name\":\"follow_up_for\",\"access\":false,\"multiple\":false,\"QueryRule\":\"get_category_by_name\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 2\",\"value\":\"option-2\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Business Value\",\"name\":\"business_value\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"NA\",\"value\":\"NA\",\"selected\":true},{\"label\":\"High\",\"value\":\"High\",\"selected\":false},{\"label\":\"Medium\",\"value\":\"Medium\",\"selected\":false},{\"label\":\"Average\",\"value\":\"Average\",\"selected\":false}]}]', 1, 0, '2024-11-12 08:08:34', '2024-11-12 08:08:34'),
(7, 'business history', '1,2,3,4,5,6,7,8,9,10,11,12,13', '3', '[{\"type\":\"date\",\"required\":true,\"label\":\"Hold Till\",\"name\":\"hold_till\",\"access\":false,\"subtype\":\"date\"},{\"type\":\"select\",\"required\":true,\"label\":\"Reason\",\"name\":\"reason\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"Not Interested\",\"value\":\"Not Interested\",\"selected\":true},{\"label\":\"Out of Reach\",\"value\":\"Out of Reach\",\"selected\":false},{\"label\":\"Other\",\"value\":\"Other\",\"selected\":false}]}]', 1, 0, '2024-11-12 08:10:15', '2024-11-12 08:10:15'),
(8, 'business history', '1,2,3,4,5,6,7,8,9,10,11,12,13', '4', '[{\"type\":\"date\",\"required\":true,\"label\":\"Service/Product Purchased On\",\"name\":\"purchased_on\",\"access\":false,\"subtype\":\"date\"},{\"type\":\"select\",\"required\":true,\"label\":\"Current Visited For\",\"name\":\"visited_for\",\"access\":false,\"multiple\":false,\"QueryRule\":\"get_category_by_name\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1-\",\"selected\":true},{\"label\":\"Option 2\",\"value\":\"option-2-\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Chances of Revisit/Purchase ?\",\"name\":\"chances_of_revisit\",\"access\":false,\"multiple\":false,\"QueryRule\":\"get_chances\",\"values\":[{\"label\":\"High\",\"value\":\"high\",\"selected\":true},{\"label\":\"Low\",\"value\":\"low\",\"selected\":false}]},{\"type\":\"date\",\"required\":false,\"label\":\"Tentative Revisit/Purchase ?\",\"name\":\"tentative_revisit\",\"access\":false,\"subtype\":\"date\"}]', 1, 0, '2024-11-18 10:31:38', '2024-11-18 10:31:38'),
(9, 'account_details', '1,2,3,4,5,6,7,8,9,10,11,12,13', NULL, '[{\"type\":\"text\",\"required\":true,\"label\":\"Name in UPI\",\"name\":\"upi_name\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":true,\"label\":\"UPI ID\",\"name\":\"upi_id\",\"access\":false,\"subtype\":\"text\"}]', 1, 0, '2025-02-06 17:48:32', '2025-02-06 17:48:32'),
(10, 'customer_bank_detail', '11', NULL, '[{\"type\":\"text\",\"required\":true,\"label\":\"Company Name\",\"name\":\"company_name\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":true,\"label\":\"Bank Name\",\"name\":\"bank_name\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"select\",\"required\":true,\"label\":\"Account Type\",\"name\":\"account_type\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"Saving Account\",\"value\":\"Saving Account\",\"selected\":true},{\"label\":\"Current Account\",\"value\":\"Current Account\",\"selected\":false},{\"label\":\"Loan Account\",\"value\":\"Loan Account\",\"selected\":false}]},{\"type\":\"text\",\"required\":true,\"label\":\"IFSC Code\",\"name\":\"ifsc\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":true,\"label\":\"Account Number\",\"name\":\"account_number\",\"access\":false,\"value\":\"Account Number\",\"subtype\":\"text\"}]', 1, 0, '2025-04-22 09:32:55', '2025-04-22 09:32:55'),
(11, 'service_catalogs', '11', NULL, '[{\"type\":\"text\",\"required\":true,\"label\":\"Service Name\",\"name\":\"title\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":false,\"label\":\"Sub Name\",\"name\":\"sub_name\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":false,\"label\":\"Type\",\"name\":\"type\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":false,\"label\":\"Service Tax\",\"name\":\"service_tax\",\"access\":false,\"subtype\":\"text\"}]', 1, 0, '2025-04-22 09:32:55', '2025-04-22 09:32:55'),
(12, 'priscription', '8', NULL, '[{\"type\":\"checkbox-group\",\"required\":false,\"label\":\"Wear Type\",\"toggle\":false,\"inline\":false,\"name\":\"wear_type\",\"access\":false,\"other\":false,\"values\":[{\"label\":\"Full Time\",\"value\":\"full_time\",\"selected\":true},{\"label\":\"Distance Only\",\"value\":\"distance_only\",\"selected\":true},{\"label\":\"Intermediate Only\",\"value\":\"intermediate_only\",\"selected\":true},{\"label\":\"Reading Only\",\"value\":\"reading_only\",\"selected\":true},{\"label\":\"AS Needed\",\"value\":\"as_needed\",\"selected\":true}]},{\"type\":\"checkbox-group\",\"required\":false,\"label\":\"Lens Design\",\"toggle\":false,\"inline\":false,\"name\":\"lens_design\",\"access\":false,\"other\":false,\"values\":[{\"label\":\"Single Vision\",\"value\":\"single_vision\",\"selected\":true},{\"label\":\"Bifocal\",\"value\":\"bifocal\",\"selected\":true},{\"label\":\"Progressive\",\"value\":\"progressive\",\"selected\":true}]},{\"type\":\"checkbox-group\",\"required\":false,\"label\":\"Materials / Coats\",\"toggle\":false,\"inline\":false,\"name\":\"materials_coats\",\"access\":false,\"other\":false,\"values\":[{\"label\":\"Plastic\",\"value\":\"plastic\",\"selected\":true},{\"label\":\"Transition\",\"value\":\"transition\",\"selected\":true},{\"label\":\"Tint\",\"value\":\"tint\",\"selected\":true},{\"label\":\"UV Coating\",\"value\":\"uv_coating\",\"selected\":true},{\"label\":\"AR Coating\",\"value\":\"ar_coating\",\"selected\":true}]},{\"type\":\"number\",\"required\":false,\"label\":\"Age\",\"name\":\"age\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"textarea\",\"required\":false,\"label\":\"Prescription\",\"name\":\"priscription\",\"access\":false,\"subtype\":\"textarea\"}]', 1, 0, '2025-05-17 08:19:17', '2025-05-17 08:19:17'),
(13, 'invoice', '1,2,3,4,5,6,7,8,9,10,11,13', NULL, '[{\"type\":\"textarea\",\"required\":false,\"label\":\"Descrition\",\"name\":\"description\",\"access\":false,\"subtype\":\"textarea\"},{\"type\":\"number\",\"required\":false,\"label\":\"Discount\",\"name\":\"discount\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"number\",\"required\":false,\"label\":\"Advance\",\"name\":\"advance\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"date\",\"required\":false,\"label\":\"Delivery Date\",\"name\":\"delivery_date\",\"access\":false,\"subtype\":\"date\"},{\"type\":\"file\",\"required\":false,\"label\":\"Attachment\",\"name\":\"attachment\",\"access\":false,\"multiple\":true}]', 1, 0, '2025-06-03 11:24:04', '2025-06-03 11:24:04'),
(15, 'product_catalogs', '8', NULL, '[{\"type\":\"text\",\"required\":true,\"label\":\"Product Name/Title\",\"name\":\"title\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"select\",\"required\":true,\"label\":\"Category\",\"name\":\"category_name\",\"access\":false,\"multiple\":false,\"DataType\":\"varchar\",\"QueryRule\":\"get_category_by_product\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 3\",\"value\":\"option-3\",\"selected\":false}]},{\"type\":\"autocomplete\",\"required\":false,\"label\":\"Brand\",\"name\":\"brand\",\"access\":true,\"requireValidOption\":false,\"QueryRule\":\"get_brand_list\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 2\",\"value\":\"option-2\",\"selected\":false}]},{\"type\":\"file\",\"required\":false,\"label\":\"Product Image\",\"name\":\"image\",\"access\":false,\"multiple\":true},{\"type\":\"number\",\"required\":false,\"label\":\"Enter Price in Rupees\",\"name\":\"price\",\"access\":false,\"subtype\":\"number\",\"DataType\":\"VARCHAR\"},{\"type\":\"number\",\"required\":false,\"label\":\"Enter Offer Price if Any\",\"name\":\"offer\",\"access\":false,\"subtype\":\"number\",\"DataType\":\"varchar(255)\"},{\"type\":\"textarea\",\"required\":false,\"label\":\"Product Description\",\"name\":\"description\",\"access\":false,\"subtype\":\"textarea\"},{\"type\":\"select\",\"required\":false,\"label\":\"Size\",\"name\":\"size\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"Small\",\"value\":\"small\",\"selected\":true},{\"label\":\"Medium\",\"value\":\"medium\",\"selected\":false},{\"label\":\"Large\",\"value\":\"large\",\"selected\":false},{\"label\":\"Custom\",\"value\":\"custom\",\"selected\":false}]},{\"type\":\"select\",\"required\":false,\"label\":\"Color\",\"name\":\"color\",\"access\":false,\"multiple\":false,\"QueryRule\":\"get_color_list\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 2\",\"value\":\"option-2\",\"selected\":false}]},{\"type\":\"checkbox-group\",\"required\":false,\"label\":\"Inventory Selling\",\"toggle\":false,\"inline\":false,\"name\":\"is_inventory\",\"access\":false,\"other\":false,\"DataType\":\"integer(11)default(0)\",\"values\":[{\"label\":\"Inventory Selling\",\"value\":\"1\",\"selected\":false}]},{\"type\":\"number\",\"required\":false,\"label\":\"Available Quantity\",\"name\":\"available_quantity\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"select\",\"required\":false,\"label\":\"Select GST\",\"name\":\"gst_percentage\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"0\",\"value\":\"0%\",\"selected\":true},{\"label\":\"5\",\"value\":\"5%\",\"selected\":false},{\"label\":\"12\",\"value\":\"12%\",\"selected\":false},{\"label\":\"18\",\"value\":\"18%\",\"selected\":false}]},{\"type\":\"number\",\"required\":false,\"label\":\"Employee Percentage\",\"name\":\"employee_percentage\",\"access\":false,\"subtype\":\"number\"}]', 1, 0, '2025-06-18 08:09:17', '2025-06-18 08:09:17'),
(17, 'product_catalogs', '2', NULL, '[{\"type\":\"text\",\"required\":true,\"label\":\"Product Name/Title\",\"name\":\"title\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"select\",\"required\":true,\"label\":\"Category\",\"name\":\"category_name\",\"access\":false,\"multiple\":false,\"DataType\":\"varchar\",\"QueryRule\":\"get_category_by_product\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 3\",\"value\":\"option-3\",\"selected\":false}]},{\"type\":\"file\",\"required\":false,\"label\":\"Product Image\",\"name\":\"image\",\"access\":false,\"multiple\":true},{\"type\":\"number\",\"required\":false,\"label\":\"Enter Price in Rupees\",\"name\":\"price\",\"access\":false,\"subtype\":\"number\",\"DataType\":\"VARCHAR\"},{\"type\":\"number\",\"required\":false,\"label\":\"Enter Offer Price if Any\",\"name\":\"offer\",\"access\":false,\"subtype\":\"number\",\"DataType\":\"varchar(255)\"},{\"type\":\"textarea\",\"required\":false,\"label\":\"Product Description\",\"name\":\"description\",\"access\":false,\"subtype\":\"textarea\"},{\"type\":\"text\",\"required\":false,\"label\":\"Size\",\"name\":\"size\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"text\",\"required\":false,\"label\":\"Color\",\"name\":\"color\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"checkbox-group\",\"required\":false,\"label\":\"Inventory Selling\",\"toggle\":false,\"inline\":false,\"name\":\"is_inventory\",\"access\":false,\"other\":false,\"DataType\":\"integer(11)default(0)\",\"values\":[{\"label\":\"Inventory Selling\",\"value\":\"1\",\"selected\":false}]},{\"type\":\"number\",\"required\":false,\"label\":\"Available Quantity\",\"name\":\"available_quantity\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"select\",\"required\":false,\"label\":\"Select GST\",\"name\":\"gst_percentage\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"0\",\"value\":\"0%\",\"selected\":true},{\"label\":\"5\",\"value\":\"5%\",\"selected\":false},{\"label\":\"12\",\"value\":\"12%\",\"selected\":false},{\"label\":\"18\",\"value\":\"18%\",\"selected\":false}]},{\"type\":\"number\",\"required\":false,\"label\":\"Employee Percentage\",\"name\":\"employee_percentage\",\"access\":false,\"subtype\":\"number\"}]', 1, 0, '2025-07-09 11:17:20', '2025-07-09 11:17:20'),
(18, 'service_catalogs', '2', NULL, '[{\"type\":\"text\",\"required\":true,\"label\":\"Service Name/Title\",\"name\":\"title\",\"access\":false,\"subtype\":\"text\"},{\"type\":\"select\",\"required\":true,\"label\":\"Category\",\"name\":\"category_name\",\"access\":false,\"multiple\":false,\"DataType\":\"varchar\",\"QueryRule\":\"get_category_by_service\",\"values\":[{\"label\":\"Option 1\",\"value\":\"option-1\",\"selected\":true},{\"label\":\"Option 2\",\"value\":\"option-2\",\"selected\":false}]},{\"type\":\"file\",\"required\":false,\"label\":\"Service Image\",\"name\":\"image\",\"access\":false,\"multiple\":false},{\"type\":\"number\",\"required\":false,\"label\":\"Enter Price in Rupees\",\"name\":\"price\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"number\",\"required\":false,\"label\":\"Enter Offer Price if Any\",\"name\":\"offer\",\"access\":false,\"subtype\":\"number\"},{\"type\":\"textarea\",\"required\":false,\"label\":\"Service Description\",\"name\":\"description\",\"access\":false,\"subtype\":\"textarea\"},{\"type\":\"select\",\"required\":false,\"label\":\"Select GST\",\"name\":\"gst_percentage\",\"access\":false,\"multiple\":false,\"values\":[{\"label\":\"0\",\"value\":\"0%\",\"selected\":true},{\"label\":\"5\",\"value\":\"5%\",\"selected\":false},{\"label\":\"12\",\"value\":\"12%\",\"selected\":false},{\"label\":\"18\",\"value\":\"18%\",\"selected\":false}]},{\"type\":\"number\",\"required\":false,\"label\":\"Employee Percentage\",\"name\":\"employee_percentage\",\"access\":false,\"subtype\":\"number\"}]', 1, 0, '2024-09-19 16:13:04', '2024-09-19 16:13:04');

-- --------------------------------------------------------

--
-- Table structure for table `jobs`
--

CREATE TABLE `jobs` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `queue` varchar(255) NOT NULL,
  `payload` longtext NOT NULL,
  `attempts` tinyint(3) UNSIGNED NOT NULL,
  `reserved_at` int(10) UNSIGNED DEFAULT NULL,
  `available_at` int(10) UNSIGNED NOT NULL,
  `created_at` int(10) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `job_batches`
--

CREATE TABLE `job_batches` (
  `id` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `total_jobs` int(11) NOT NULL,
  `pending_jobs` int(11) NOT NULL,
  `failed_jobs` int(11) NOT NULL,
  `failed_job_ids` longtext NOT NULL,
  `options` mediumtext DEFAULT NULL,
  `cancelled_at` int(11) DEFAULT NULL,
  `created_at` int(11) NOT NULL,
  `finished_at` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `job_profile_master`
--

CREATE TABLE `job_profile_master` (
  `id` int(11) NOT NULL,
  `business_id` int(11) NOT NULL,
  `job_title` varchar(255) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1,
  `is_deleted` int(11) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `job_profile_master`
--

INSERT INTO `job_profile_master` (`id`, `business_id`, `job_title`, `status`, `is_deleted`, `created_at`, `updated_at`) VALUES
(1, 1, 'Hair Stylist', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(2, 1, 'Therapist', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(3, 1, 'Manager', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(4, 1, 'Beautician', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(5, 1, 'Receptionist', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(6, 2, 'Fashion Designer', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(7, 2, 'Sales Associate', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(8, 2, 'Store Manager', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(9, 2, 'Tailor', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(10, 2, 'Support Staff', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(11, 3, 'Store Manager', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(12, 3, 'Sales Executive', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(13, 3, 'Manager', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(14, 3, 'Customer Service Executive', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(15, 3, 'Store Supervisor', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(16, 4, 'Manager', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(17, 4, 'Sales Executive', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(18, 4, 'Inventory Coordinator', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(19, 4, 'Accountant', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(20, 4, 'Field Sales Executive', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(21, 5, 'Sales Executive', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(22, 5, 'Accountant', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(23, 5, 'Customer Service Executive', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(24, 5, 'Technician', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(25, 5, 'Store Manager', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(26, 6, 'Technician', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(27, 6, 'Field Service Executive', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(28, 6, 'Customer Service Executive', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(29, 6, 'Store Manager', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(30, 6, 'Technical Support', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(31, 7, 'Real Estate Agent', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(32, 7, 'Property Consultant', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(33, 7, 'Support Staff', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(34, 7, 'Manager', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18'),
(35, 7, 'Sales Executive', 1, 0, '2025-02-23 13:03:18', '2025-02-23 13:03:18');

-- --------------------------------------------------------

--
-- Table structure for table `leads_history`
--

CREATE TABLE `leads_history` (
  `id` int(11) NOT NULL,
  `tenant_id` bigint(20) NOT NULL,
  `lead_id` bigint(20) NOT NULL,
  `status` tinyint(4) NOT NULL DEFAULT 0,
  `is_deleted` tinyint(4) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `leads_history`
--

INSERT INTO `leads_history` (`id`, `tenant_id`, `lead_id`, `status`, `is_deleted`, `created_at`) VALUES
(1, 2, 7, 0, 0, '2025-05-09 18:30:04'),
(2, 2, 18, 0, 0, '2025-05-09 18:30:04'),
(3, 2, 20, 0, 0, '2025-05-03 18:30:04'),
(4, 2, 31, 0, 0, '2025-05-03 18:30:04'),
(5, 2, 32, 0, 0, '2025-05-03 18:30:04'),
(6, 2, 7, 0, 0, '2025-05-04 18:30:05'),
(7, 2, 18, 0, 0, '2025-05-04 18:30:05'),
(8, 2, 20, 0, 0, '2025-05-04 18:30:05'),
(9, 2, 31, 0, 0, '2025-05-04 18:30:05'),
(10, 2, 32, 0, 0, '2025-05-04 18:30:05'),
(11, 2, 7, 0, 0, '2025-05-05 18:30:04'),
(12, 2, 18, 0, 0, '2025-05-05 18:30:04'),
(13, 2, 20, 0, 0, '2025-05-05 18:30:04'),
(14, 2, 31, 0, 0, '2025-05-05 18:30:04'),
(15, 2, 32, 0, 0, '2025-05-05 18:30:04'),
(16, 2, 7, 0, 0, '2025-05-06 18:30:04'),
(17, 2, 18, 0, 0, '2025-05-06 18:30:04'),
(18, 2, 20, 0, 0, '2025-05-06 18:30:04'),
(19, 2, 31, 0, 0, '2025-05-06 18:30:04'),
(20, 2, 32, 0, 0, '2025-05-06 18:30:04'),
(21, 1, 8, 0, 0, '2025-05-10 18:30:04'),
(22, 1, 14, 0, 0, '2025-05-10 18:30:04'),
(23, 1, 17, 0, 0, '2025-05-10 18:30:04'),
(24, 1, 37, 0, 0, '2025-05-10 18:30:04'),
(25, 1, 39, 0, 0, '2025-05-10 18:30:04'),
(26, 1, 8, 0, 0, '2025-05-17 18:30:06'),
(27, 1, 14, 0, 0, '2025-05-17 18:30:06'),
(28, 1, 17, 0, 0, '2025-05-17 18:30:06'),
(29, 1, 37, 0, 0, '2025-05-17 18:30:06'),
(30, 1, 39, 0, 0, '2025-05-17 18:30:06'),
(31, 1, 8, 0, 0, '2025-05-18 18:30:04'),
(32, 1, 14, 0, 0, '2025-05-18 18:30:04'),
(33, 1, 17, 0, 0, '2025-05-18 18:30:04'),
(34, 1, 37, 0, 0, '2025-05-18 18:30:04'),
(35, 1, 39, 0, 0, '2025-05-18 18:30:04');

-- --------------------------------------------------------

--
-- Table structure for table `leads_master`
--

CREATE TABLE `leads_master` (
  `id` int(10) UNSIGNED NOT NULL,
  `name` varchar(255) NOT NULL,
  `email` varchar(255) DEFAULT NULL,
  `mobile` varchar(100) NOT NULL,
  `another_mobile` varchar(100) DEFAULT NULL,
  `company` varchar(255) DEFAULT NULL,
  `gst` varchar(100) DEFAULT NULL,
  `location` varchar(255) DEFAULT NULL,
  `dob` varchar(255) DEFAULT NULL,
  `anniversary` varchar(255) DEFAULT NULL,
  `source` varchar(100) DEFAULT NULL,
  `looking_for` varchar(100) DEFAULT NULL,
  `status` int(11) DEFAULT 1,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `is_deleted` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `leads_master`
--

INSERT INTO `leads_master` (`id`, `name`, `email`, `mobile`, `another_mobile`, `company`, `gst`, `location`, `dob`, `anniversary`, `source`, `looking_for`, `status`, `created_at`, `updated_at`, `is_deleted`) VALUES
(1, 'Aayush Ganesh', 'garganiruddh@sane-sani.com', '03198911987', '9894162055', 'Sathe, Ramachandran and Zachariah', 'hy5031IZ77', 'Koramangala', '1981-02-12', '2019-01-12', 'Google', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(2, 'Jayesh Bail', 'uchacko@yahoo.com', '07002723839', '3337698616', 'Kothari and Sons', 'Ly6283FX91', 'Whitefield', '1989-09-27', '2019-08-09', 'Instagram', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(3, 'Nirvaan Talwar', 'erao@choudhry.info', '+916398046483', '+912660239541', 'Kaul PLC', 'Qv0986lN68', 'BTM Layout', '1988-03-16', '2023-05-21', 'Facebook', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(4, 'Tejas Ratta', 'amira31@gmail.com', '04160812028', '+911371612096', 'Dugar-Vora', 'SH2095yq92', 'Whitefield', '1984-12-05', '2019-04-30', 'Walk-in', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(5, 'Nehmat Mani', 'anvi46@gmail.com', '01805597518', '4312441678', 'Dhillon, Rau and Bath', 'ql9813iT21', 'Malleshwaram', '1985-03-19', '2016-02-14', 'Google', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(6, 'Alia Warrior', 'buchlavanya@gupta.com', '07651875828', '+919273429298', 'Suresh PLC', 'DB4983wm10', 'Rajajinagar', '2001-06-01', '2022-03-15', 'Google', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(7, 'Rohan Chhabra', 'mannatkala@gmail.com', '+916466746352', '06551029787', 'Sani-Raman', 'NA7258TH29', 'BTM Layout', '1983-09-28', '2017-04-08', 'Instagram', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(8, 'Divij Balakrishnan', 'kiaan94@raja.com', '09810041114', '02992743502', 'Bala-Behl', 'eG5956ze14', 'Electronic City', '1967-02-15', '2017-05-21', 'Walk-in', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(9, 'Inaaya  Goel', 'grewaljivika@gmail.com', '02489926261', '+915587751915', 'Chana LLC', 'qJ8937Sa28', 'Hebbal', '1993-06-20', '2024-04-13', 'Instagram', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(10, 'Jivika Edwin', 'samarth25@soni.info', '+912410948742', '08854982326', 'Chahal Group', 'Oi2778gU28', 'Banashankari', '1992-12-06', '2023-10-11', 'Instagram', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(11, 'Zeeshan Sharaf', 'anayloyal@kadakia.com', '1578719711', '2980747513', 'Gupta, Vala and Taneja', 'sA7705Db50', 'Malleshwaram', '1982-08-05', '2018-09-04', 'Facebook', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(12, 'Anay Keer', 'kdin@chaudhary.com', '0766369630', '1335110005', 'Rajagopal-Ray', 'ue2702xH41', 'Marathahalli', '1964-09-29', '2018-04-26', 'Google', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(13, 'Kiaan Solanki', 'himmatmallick@gmail.com', '+910046434517', '04988481402', 'Manda-Varkey', 'ny4442IA92', 'Malleshwaram', '1973-11-14', '2016-03-26', 'Google', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(14, 'Ishita Raju', 'hdeshpande@gmail.com', '01163158766', '+918632167450', 'Bhalla, Mander and Gill', 'tl4156gS98', 'Jayanagar', '1990-03-07', '2024-12-06', 'Instagram', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(15, 'Pihu Krishnamurthy', 'aarav26@desai-chaudry.info', '08037633143', '06242080909', 'Walla, Shah and Manda', 'SD0036jJ92', 'Banashankari', '1999-08-29', '2023-01-30', 'Google', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(16, 'Hrishita Choudhury', 'mallkiaan@sama.info', '+918466981650', '+918855538503', 'Comar-Ganesan', 'tv2305MB23', 'Banashankari', '1988-01-24', '2016-05-02', 'Walk-in', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(17, 'Rhea Zachariah', 'karpetaimur@gmail.com', '6702714268', '08453100349', 'Bath-Gill', 'Qm1659vI04', 'Electronic City', '2000-10-29', '2024-12-12', 'Google', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(18, 'Aniruddh Ramanathan', 'sainidharmajan@gaba.biz', '05180712847', '+913911287689', 'Ravel, Gola and Som', 'WK7197sm61', 'Basavanagudi', '1996-07-29', '2016-08-31', 'Google', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(19, 'Shalv Datta', 'osunder@ranganathan.info', '04984957768', '+912243171207', 'Kanda Inc', 'gH8852ZV73', 'RT Nagar', '1982-03-06', '2018-08-02', 'Facebook', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(20, 'Diya Shanker', 'saksham02@gmail.com', '0399987090', '+913724378784', 'Biswas, Andra and Jaggi', 'ZH7232HU56', 'HSR Layout', '1976-03-28', '2021-09-25', 'Walk-in', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(21, 'Yashvi Walia', 'ttailor@gmail.com', '07224636496', '9260733478', 'Virk-Krish', 'as7054ik56', 'Indiranagar', '1975-02-19', '2021-09-13', 'Instagram', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(22, 'Rohan Saini', 'faiyazagate@walia.biz', '07428054840', '+918707268950', 'Bali-Madan', 'WL2577dp01', 'Yelahanka', '1978-04-24', '2021-02-10', 'Instagram', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(23, 'Vedika Sehgal', 'sumer94@sur-sagar.com', '1103504319', '+913790926635', 'Bobal, Agate and Singh', 'Ew0795rk58', 'Hebbal', '1993-04-05', '2019-01-14', 'Walk-in', 'Cakes & Chocolates', 1, '2025-04-30 10:03:08', '2025-04-30 10:23:01', 0),
(24, 'Dhanush Rattan', 'advikaiyengar@gmail.com', '+914808389186', '1153819692', 'Garde, Kulkarni and Ray', 'xY3913jt08', 'Rajajinagar', '1979-01-21', '2020-12-21', 'Instagram', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(25, 'Hiran Tripathi', 'lsathe@das-lall.com', '02274471733', '9977658467', 'Soman Inc', 'Gc6733Qq56', 'Basavanagudi', '1982-05-04', '2018-11-22', 'Google', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(26, 'Kartik Chada', 'yogiyuvaan@gmail.com', '3203242047', '08266685890', 'Shah and Sons', 'ER6441Me13', 'BTM Layout', '1980-12-31', '2018-10-06', 'Instagram', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(27, 'Jiya Raj', 'jbanik@gmail.com', '6535143633', '+911562658875', 'Bhakta, Mandal and Deol', 'aV3597eg47', 'Marathahalli', '1993-08-20', '2018-09-25', 'Walk-in', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(28, 'Chirag Karan', 'jayan55@yahoo.com', '+919984477786', '+913474648518', 'Kanda-Kumer', 'lH6494Zx99', 'Malleshwaram', '2003-04-20', '2017-04-07', 'Instagram', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(29, 'Kavya Raju', 'ugala@walia.com', '02152595397', '+913889438216', 'Sur-Char', 'Dn9618na78', 'HSR Layout', '1991-11-09', '2018-03-07', 'Walk-in', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(30, 'Raghav Borde', 'jrama@hotmail.com', '3655439906', '+914318131743', 'Bhatnagar PLC', 'Al0490Zw94', 'Electronic City', '2005-09-14', '2017-10-26', 'Facebook', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(31, 'Zeeshan Choudhry', 'vermamadhav@hotmail.com', '+918797171509', '+919658802261', 'Datta and Sons', 'pc0049lj19', 'Yelahanka', '1973-06-03', '2019-12-13', 'Google', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(32, 'Ishita Balan', 'faiyaz41@kulkarni-mann.org', '3813672871', '4779242465', 'Doshi and Sons', 'Pb4952Oq74', 'Indiranagar', '1985-01-20', '2021-04-04', 'Google', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(33, 'Anya Tandon', 'madhavswamy@sen.com', '1390153336', '03218551201', 'Lalla Ltd', 'Kg3815ua59', 'Jayanagar', '1982-06-10', '2015-09-27', 'Google', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(34, 'Nirvi Mann', 'dharmajan88@bhardwaj.net', '03785126431', '2779102155', 'Ravel Inc', 'cl0662pi42', 'Marathahalli', '1993-08-10', '2015-05-27', 'Walk-in', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(35, 'Shayak Dani', 'yuvraj-10@kaur-chana.com', '8202649155', '09694643266', 'Wable-Date', 'pZ5810oH17', 'Marathahalli', '1975-06-22', '2022-09-07', 'Instagram', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(36, 'Ayesha Kuruvilla', 'ddubey@hotmail.com', '+917679020514', '+913147540919', 'Iyengar, Sidhu and Seshadri', 'Vb6883NG21', 'RT Nagar', '1999-05-26', '2018-02-08', 'Walk-in', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(37, 'Farhan Sahota', 'hazeljani@hotmail.com', '9071855063', '02966377429', 'Ganguly, Bandi and Raja', 'Zr7321Vk52', 'HSR Layout', '1999-06-12', '2017-11-08', 'Instagram', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(38, 'Sana Halder', 'xacharya@yahoo.com', '+912868292891', '08951157659', 'Kaul, Dalal and Varma', 'Dw0572vt27', 'Koramangala', '1980-09-07', '2017-11-14', 'Google', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(39, 'Anay Setty', 'indrajitkannan@gmail.com', '2649521095', '+915797898874', 'Agarwal, Sabharwal and Johal', 'nm2952mm92', 'Electronic City', '1981-11-11', '2017-01-01', 'Google', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(40, 'Samarth Chad', 'rattiindranil@yahoo.com', '+915187647625', '08227591713', 'Kulkarni LLC', 'uJ1156Lh53', 'Hebbal', '1994-06-07', '2016-03-15', 'Walk-in', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(41, 'Zoya Bir', 'vyasranbir@amble.biz', '3048348084', '3599767727', 'Aggarwal-Khanna', 'FJ8829oH73', 'Yelahanka', '1996-07-01', '2024-09-15', 'Google', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(42, 'Armaan Sekhon', 'shraybajwa@yahoo.com', '00928966524', '+912824840743', 'Sarna, Gokhale and Mall', 'eY3552BO06', 'Yelahanka', '1974-08-20', '2025-04-22', 'Walk-in', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(43, 'Gatik Agrawal', 'ubadami@kota.net', '8983472022', '+914070911957', 'Bajwa and Sons', 'jh3102gP45', 'Hebbal', '1967-10-27', '2018-06-20', 'Walk-in', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(44, 'Renee Sanghvi', 'samihaamble@hotmail.com', '05014029949', '03667845984', 'Rajagopal LLC', 'cb9891fK24', 'Indiranagar', '1973-04-27', '2020-11-01', 'Walk-in', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(45, 'Amani Grover', 'ekumar@deo.com', '4221545246', '+918041218298', 'Chakraborty, Iyengar and Karpe', 'Oj8245Nk06', 'Banashankari', '1967-09-11', '2019-12-23', 'Google', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(46, 'Arhaan Venkataraman', 'buchdrishya@hotmail.com', '4941482498', '+910650317310', 'Bhandari and Sons', 'jW3508Xu22', 'Rajajinagar', '1988-07-18', '2015-08-06', 'Walk-in', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(47, 'Prerak Dutt', 'nehmatbedi@hotmail.com', '03119678689', '8207656553', 'Saini and Sons', 'IE8179OP90', 'Basavanagudi', '1994-07-17', '2017-07-26', 'Instagram', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(48, 'Aarush Apte', 'chaudhurikartik@yahoo.com', '8142145588', '7084283439', 'Dasgupta LLC', 'Zw3246tq53', 'Malleshwaram', '1994-01-28', '2019-04-29', 'Facebook', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(49, 'Shaan Yogi', 'anikaghosh@hotmail.com', '+915632746958', '04637843383', 'Sha, Jha and Sem', 'fz2990KG60', 'HSR Layout', '1965-12-13', '2016-07-29', 'Google', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(50, 'Jivika Chad', 'zkapoor@yahoo.com', '+912889792885', '01345286146', 'Dube, Keer and Ray', 'pO1564AE38', 'Koramangala', '1983-07-25', '2018-07-31', 'Walk-in', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(51, 'Yasmin Srivastava', 'kumarmiraya@agate-sidhu.com', '03791444287', '+911096005731', 'Suri Group', 'lv0467po49', 'Whitefield', '1993-03-24', '2022-06-26', 'Google', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(52, 'Indrajit Sachar', 'daliaheer@kar.org', '3950434842', '08901717800', 'Suri, Koshy and Mann', 'Fc8236Sj12', 'Marathahalli', '1998-07-29', '2019-09-14', 'Instagram', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(53, 'Zoya Lala', 'lagan48@balakrishnan.biz', '09307435103', '+915788007230', 'Devi, Kala and Mand', 'ag9302ov69', 'Marathahalli', '1966-04-28', '2021-05-18', 'Walk-in', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(54, 'Baiju Goel', 'vardaniyabhavsar@lad.com', '00540216857', '05520854271', 'Sood-Kapadia', 'wt9956Ta63', 'Malleshwaram', '2002-10-14', '2017-10-26', 'Walk-in', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(55, 'Saksham Brar', 'nakulsetty@yahoo.com', '0515232080', '3731272973', 'Bajwa, Gopal and Sarma', 'bO7945ZI87', 'RT Nagar', '1976-08-07', '2020-09-03', 'Facebook', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(56, 'Chirag Trivedi', 'adah22@tank.com', '+919658400921', '9585247355', 'Solanki Group', 'RB5987Lc48', 'Koramangala', '1976-05-23', '2020-06-09', 'Facebook', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(57, 'Anya Balay', 'hrishitarandhawa@koshy-ratta.com', '+911409026078', '3188425738', 'Sathe-Kadakia', 'Ad3419BK53', 'BTM Layout', '1970-05-01', '2017-04-04', 'Facebook', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(58, 'Nehmat Sunder', 'divyansh31@majumdar.com', '+915157257852', '00828568524', 'Bedi-Kakar', 'Po2479Ob87', 'Whitefield', '1977-07-05', '2019-12-20', 'Walk-in', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(59, 'Tushar Kakar', 'mallickamani@hotmail.com', '00076031304', '0396302048', 'Seth, Char and Chander', 'BE4266vS13', 'Malleshwaram', '1983-02-17', '2019-10-04', 'Google', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(60, 'Amira Dutt', 'obasak@ramaswamy.com', '+911259411949', '+919183842912', 'Kar-Loke', 'gI5735PL04', 'RT Nagar', '1968-06-10', '2023-12-09', 'Google', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(61, 'Dishani Dash', 'charvi50@yahoo.com', '+918563861319', '06045497940', 'Deshpande, Balakrishnan and Raju', 'EX2489XA71', 'Koramangala', '2005-10-21', '2022-02-14', 'Facebook', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(62, 'Shamik Date', 'zbahl@hotmail.com', '7808056108', '3030634909', 'Dave, Reddy and Majumdar', 'HP0776FR83', 'Basavanagudi', '1981-10-15', '2024-03-18', 'Walk-in', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(63, 'Sana Dugar', 'elakshiandra@kapadia.com', '09356872794', '2831363431', 'Koshy-Sidhu', 'el1859wf46', 'Hebbal', '1981-10-24', '2020-09-13', 'Instagram', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(64, 'Miraan Mander', 'garakartik@gmail.com', '+919907638689', '+912877963531', 'Handa-Sule', 'Ti3562pF80', 'Marathahalli', '1993-04-10', '2017-07-24', 'Walk-in', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(65, 'Madhav Bhardwaj', 'jgour@gmail.com', '03266711626', '+919872050494', 'Kunda-Bedi', 'il5122Eh02', 'HSR Layout', '1981-06-12', '2016-03-12', 'Walk-in', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(66, 'Kabir Chad', 'himmatkashyap@hotmail.com', '05087667156', '09815087206', 'Devi-Guha', 'JF0861ks73', 'Malleshwaram', '1979-02-15', '2022-11-03', 'Walk-in', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(67, 'Hiran Swaminathan', 'chackotara@yahoo.com', '05481274499', '+919594926993', 'Goswami-Dhar', 'lt8855QC42', 'Whitefield', '1982-09-16', '2023-04-19', 'Google', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(68, 'Jivika Goda', 'nirvigoswami@apte.com', '5960343306', '5875524295', 'Chaudhry Ltd', 'Lr4527PD94', 'HSR Layout', '1991-11-23', '2019-03-31', 'Instagram', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(69, 'Kashvi Rastogi', 'romilgaba@sehgal.biz', '+918076346499', '+913378199878', 'Anand-Ram', 'Za7950FY72', 'Whitefield', '1964-08-10', '2023-09-22', 'Walk-in', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(70, 'Shalv Taneja', 'tusharrajan@basu.org', '8272067285', '+910649127348', 'Khare, Chaudhary and Tripathi', 'Yt5212EW28', 'BTM Layout', '1969-06-12', '2017-10-13', 'Walk-in', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(71, 'Kartik Balay', 'berashray@gmail.com', '00563760176', '05910253624', 'Sachdeva, Raj and Das', 'oV7814hh10', 'Koramangala', '1976-07-01', '2021-09-05', 'Walk-in', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(72, 'Tiya Yadav', 'oorjadesai@yahoo.com', '09319705423', '03988801969', 'Kothari LLC', 'eQ7525tx13', 'Koramangala', '1966-09-08', '2024-04-22', 'Facebook', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(73, 'Sana Ghosh', 'jayeshbhat@bala-sodhi.com', '+911088915904', '+917230479495', 'Dada-Hayer', 'yl7487ie78', 'HSR Layout', '1997-01-09', '2017-08-02', 'Walk-in', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(74, 'Jivin Kashyap', 'ryanbasak@gmail.com', '+910126128594', '4336391934', 'Biswas, Desai and Kota', 'ry3283Df57', 'Malleshwaram', '1999-05-03', '2018-01-24', 'Facebook', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(75, 'Hridaan Chokshi', 'vritika72@kunda.biz', '01223933607', '5080249521', 'Agarwal-Chopra', 'Vq7261mO33', 'RT Nagar', '1974-01-23', '2021-03-29', 'Google', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(76, 'Nehmat Hora', 'darshit54@barad-sankar.com', '7983532556', '04647100329', 'Randhawa LLC', 'Np8035Ux53', 'Electronic City', '1977-03-26', '2020-02-03', 'Google', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(77, 'Vanya Kannan', 'lbhardwaj@sura.com', '0859119308', '00576860745', 'Vaidya Ltd', 'dJ4854KZ80', 'HSR Layout', '1983-03-25', '2020-07-09', 'Google', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(78, 'Amira Gour', 'baradkhushi@bhargava.com', '02704782154', '+916011234083', 'Kala-Bahl', 'vM5304VS35', 'Banashankari', '2005-11-03', '2020-07-20', 'Walk-in', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(79, 'Urvi Shukla', 'siya47@gmail.com', '07001569655', '+918696692725', 'Roy, Comar and Deshpande', 'QL5192HM82', 'Whitefield', '1967-05-09', '2018-07-21', 'Instagram', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(80, 'Gokul Bahri', 'hunar85@yahoo.com', '9528448577', '+917984999034', 'Jayaraman LLC', 'jY0638uF59', 'HSR Layout', '1995-08-16', '2016-05-05', 'Facebook', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(81, 'Zaina Bhavsar', 'jiyasidhu@desai.com', '3945137479', '2906056646', 'Sanghvi and Sons', 'rg9478Tp76', 'Indiranagar', '1973-06-22', '2023-06-20', 'Walk-in', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(82, 'Yashvi Talwar', 'dchoudhary@agate.com', '+910460472951', '01322389845', 'Goel-Sundaram', 'vN5861zH72', 'RT Nagar', '1983-08-21', '2016-11-13', 'Facebook', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(83, 'Gokul D’Alia', 'taratanya@gmail.com', '8459449838', '06129257565', 'Subramanian Group', 'da9541zP91', 'Marathahalli', '2001-11-16', '2021-06-23', 'Instagram', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(84, 'Pari Suresh', 'jmani@sharaf.info', '+916877366384', '08453325202', 'Banik Ltd', 'AV8475YS23', 'HSR Layout', '1987-06-17', '2018-05-16', 'Google', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(85, 'Rohan Tara', 'prisha68@gmail.com', '4707298338', '08980948706', 'Kale-Gala', 'pp6616CF32', 'Koramangala', '2002-02-21', '2016-08-20', 'Facebook', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(86, 'Jivika Sanghvi', 'nayantara99@gmail.com', '8510746747', '+915231513787', 'Roy PLC', 'bb2124cG28', 'Marathahalli', '1992-05-30', '2020-05-09', 'Google', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(87, 'Lakshit Kade', 'kavyagaba@gmail.com', '2251211972', '+912400462155', 'Thakur-Char', 'Od7916rw51', 'RT Nagar', '1997-12-21', '2018-07-17', 'Instagram', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(88, 'Pari Srinivas', 'samarth70@gmail.com', '01443281800', '3746740418', 'Shere, Bhargava and Bala', 'RO6850KX62', 'Electronic City', '1980-05-22', '2020-08-16', 'Facebook', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(89, 'Charvi Balan', 'aradhyasamra@hotmail.com', '04582306304', '07079032699', 'Kant-Chandran', 'Ca3720yi85', 'Indiranagar', '2000-02-21', '2021-11-16', 'Google', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(90, 'Ishaan Madan', 'gjain@trivedi.com', '+917007241650', '9892545883', 'Sharma-Ratta', 'me9426hW74', 'Indiranagar', '1998-02-09', '2017-01-24', 'Facebook', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(91, 'Akarsh Ramachandran', 'bchaudhuri@yahoo.com', '+917246308135', '07362309085', 'Loyal-Dewan', 'IT7210pP42', 'Yelahanka', '2001-11-15', '2020-10-02', 'Instagram', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(92, 'Zara Dara', 'keerdevansh@bains-raju.info', '04475748138', '03713539387', 'Mannan PLC', 'Uj5538hq03', 'Malleshwaram', '1967-04-30', '2025-04-11', 'Google', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(93, 'Baiju Mangat', 'piyasaha@amble.info', '+913235724376', '+911138156145', 'Ramaswamy Ltd', 'oj1889EG20', 'RT Nagar', '1968-04-19', '2022-08-18', 'Facebook', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(94, 'Akarsh Vasa', 'ojas31@badami.net', '+911227499719', '+915432116913', 'Datta Group', 'Cs7547lc17', 'Jayanagar', '1973-02-02', '2018-06-04', 'Walk-in', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(95, 'Prisha Thakur', 'thakerumang@hotmail.com', '2815775917', '+913033759702', 'Sarin-Kulkarni', 'HW3449Uj07', 'Basavanagudi', '2003-11-18', '2018-09-29', 'Walk-in', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(96, 'Azad Comar', 'alisha00@gmail.com', '9336733829', '03873987577', 'Tripathi PLC', 'kX4838tT00', 'Jayanagar', '2002-09-29', '2022-07-24', 'Facebook', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(97, 'Siya Mangat', 'lavanya09@chacko-barman.com', '+914942420555', '05712402298', 'Kanda, Mangat and Khalsa', 'IO2005co73', 'Banashankari', '1991-12-16', '2021-06-02', 'Google', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(98, 'Indranil Som', 'balinitya@devan.net', '8545049774', '01559680082', 'Kala and Sons', 'yG5176ml15', 'Whitefield', '2003-05-26', '2023-08-10', 'Google', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(99, 'Prerak Joshi', 'tusharvasa@dutt.com', '8003396261', '+912357231800', 'Dixit, Badami and Raman', 'Qb3002km31', 'Malleshwaram', '1982-06-08', '2016-08-25', 'Facebook', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(100, 'Raunak Kadakia', 'ddhar@yahoo.com', '0153786218', '+910599577671', 'Hans-Malhotra', 'KX5811jq82', 'Hebbal', '1964-11-05', '2022-04-21', 'Walk-in', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(101, 'Kavya Dalal', 'baiju94@gmail.com', '1205622828', '02736349132', 'Kakar-Swaminathan', 'kl8438zD28', 'RT Nagar', '1990-04-13', '2017-06-12', 'Walk-in', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(102, 'Samiha Raja', 'anika59@mane.org', '07659346333', '9683678630', 'Datta Group', 'Oj5035Yu64', 'Whitefield', '1993-08-23', '2017-04-17', 'Facebook', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(103, 'Drishya Bath', 'bajajaaina@bedi-tara.com', '+915309501852', '7679081127', 'Tak Group', 'Gi3941Vw82', 'Electronic City', '1973-11-22', '2018-04-11', 'Google', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(104, 'Piya Joshi', 'sbhakta@swamy.org', '00935988246', '7632509800', 'Salvi LLC', 'OT6212uE15', 'Hebbal', '1987-10-27', '2017-07-26', 'Google', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(105, 'Nehmat Magar', 'ilanka@bath-mallick.net', '+918977448564', '7395742710', 'Sarna Inc', 'vF2857pJ41', 'Malleshwaram', '1992-01-19', '2020-08-12', 'Instagram', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(106, 'Ela Savant', 'cthaman@sethi-balasubramanian.com', '06110420135', '+918689259895', 'Dasgupta LLC', 'el9205Xu28', 'Electronic City', '2000-12-14', '2021-01-29', 'Walk-in', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(107, 'Samiha Chhabra', 'wraman@sood.biz', '6586881002', '+912960314925', 'Lad-Sampath', 'Ar5340qt52', 'HSR Layout', '1964-09-07', '2023-06-17', 'Google', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(108, 'Hridaan Bawa', 'deviraghav@yahoo.com', '0270221358', '4805031702', 'Sidhu, Warrior and Chacko', 'ie2726JS79', 'Koramangala', '1986-12-23', '2017-03-09', 'Walk-in', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(109, 'Vardaniya Chana', 'cgoel@gmail.com', '+913968550425', '04383684091', 'Bhatia Group', 'mP5382we42', 'Banashankari', '1989-06-23', '2023-05-31', 'Walk-in', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(110, 'Darshit Hans', 'vjohal@bora.info', '06412690092', '9738990593', 'Dyal-Konda', 'LC7057sF03', 'Basavanagudi', '2004-12-19', '2021-11-09', 'Google', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(111, 'Divij Venkatesh', 'ishaan14@loyal.com', '09740446661', '4159009110', 'Bassi Group', 'wc8049AS89', 'Marathahalli', '1981-11-11', '2019-08-01', 'Walk-in', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(112, 'Dharmajan Kamdar', 'divit88@zacharia.com', '4356379747', '5754269620', 'Brahmbhatt-Das', 'So1667Iq02', 'Koramangala', '1972-02-07', '2024-09-28', 'Walk-in', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(113, 'Aradhya Contractor', 'abramdeol@rout.com', '01894746298', '5306641473', 'Salvi, Rege and Brar', 'NA4482ad38', 'Hebbal', '2001-07-16', '2016-03-26', 'Walk-in', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(114, 'Tiya Sanghvi', 'goleanahi@biswas.info', '+917324922953', '+916816394249', 'Dora PLC', 'wL0175Gw96', 'RT Nagar', '1987-03-20', '2018-06-03', 'Walk-in', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(115, 'Lakshit Varma', 'kkhosla@gokhale.com', '06639116508', '01046329710', 'Kapur Ltd', 'Zn6641Cs17', 'Rajajinagar', '1974-04-13', '2017-02-04', 'Google', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(116, 'Jayan Dani', 'vwason@divan.com', '02344655430', '1705357480', 'Bhandari, Kakar and Badal', 'IF6725qj70', 'Marathahalli', '1997-04-21', '2021-08-08', 'Instagram', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(117, 'Tara Bawa', 'zbahl@keer.info', '02617321243', '4911820813', 'Kari and Sons', 'Tz3420KN29', 'Marathahalli', '1982-12-10', '2016-08-22', 'Walk-in', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(118, 'Tanya Shere', 'toorindrans@dixit.com', '1882851067', '07330087690', 'Dutt, Gulati and Johal', 'rZ8643pY29', 'Basavanagudi', '1998-12-17', '2021-11-02', 'Walk-in', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(119, 'Inaaya  Mahajan', 'jchoudhary@hotmail.com', '9118505458', '+917670529565', 'Bhakta, Bhardwaj and Suri', 'pR4852bJ69', 'Indiranagar', '2003-01-18', '2023-11-06', 'Google', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(120, 'Yakshit Biswas', 'irakhatri@kata.info', '08401451327', '4969347701', 'Rattan-Mander', 'HW5406RS13', 'RT Nagar', '1968-04-16', '2022-06-16', 'Instagram', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(121, 'Ehsaan Sachar', 'iyerkhushi@jayaraman.com', '5354674902', '1500169877', 'Shankar-Shetty', 'qQ3765fk46', 'Koramangala', '1965-12-04', '2021-10-11', 'Walk-in', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(122, 'Kismat Balasubramanian', 'zara26@khare.com', '+914351542862', '1899969995', 'Sachdeva, Khalsa and Doctor', 'pH0321Ts03', 'Marathahalli', '1986-01-12', '2020-01-26', 'Walk-in', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(123, 'Raunak Bath', 'dorazeeshan@dugar.net', '+911733768424', '05906047995', 'Ganesh-Boase', 'iL8543uO12', 'RT Nagar', '1989-10-23', '2015-06-24', 'Google', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(124, 'Drishya Mand', 'kallasiya@swamy.net', '07175855614', '+919698987597', 'Kibe-Batta', 'Sl1152fl67', 'Whitefield', '1966-03-23', '2022-07-23', 'Google', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(125, 'Shlok Mannan', 'nehmatlanka@yahoo.com', '4882076418', '+911830823706', 'Vala-Kapadia', 'TY6761Sg82', 'BTM Layout', '1996-08-16', '2017-05-18', 'Instagram', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(126, 'Jivika Sood', 'fatehsen@wali.com', '06684312598', '8035626581', 'Char LLC', 'YI3317CG11', 'HSR Layout', '1986-08-07', '2023-02-27', 'Walk-in', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(127, 'Arhaan Srinivas', 'mamooty60@gmail.com', '+911685232975', '8231248957', 'Borra Group', 'BJ9188ue04', 'Banashankari', '1990-01-23', '2018-09-13', 'Walk-in', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(128, 'Divij Khalsa', 'dhruvaurora@hotmail.com', '00388590730', '9874558718', 'Chowdhury, Yohannan and Bath', 'Dc6707cp38', 'Rajajinagar', '1997-07-13', '2022-06-19', 'Google', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(129, 'Ivana Joshi', 'mannanjhanvi@badami-soni.biz', '06754764773', '01165121977', 'Bhatti, Loke and Wason', 'NQ9080Ul37', 'Marathahalli', '1989-03-29', '2025-01-01', 'Facebook', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(130, 'Aradhya Hora', 'emagar@yahoo.com', '2218542753', '+916952453306', 'Hayer LLC', 'Fp5741Zs34', 'Hebbal', '1967-11-21', '2017-06-04', 'Instagram', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(131, 'Advika Dhar', 'rasha55@saran-kamdar.com', '3479549171', '3646661658', 'Dyal, Rama and Walla', 'LS9916sg20', 'Basavanagudi', '1972-11-19', '2024-12-14', 'Facebook', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(132, 'Jiya Babu', 'kimaya36@yahoo.com', '+917042085837', '+916567833035', 'Gara Group', 'pl8577bA30', 'Koramangala', '1967-09-17', '2016-08-08', 'Google', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(133, 'Krish Gara', 'bariarohan@bhasin-kurian.net', '9441243296', '07516442185', 'Krish, Kala and Dixit', 'hj8304oj78', 'Rajajinagar', '1966-12-21', '2022-11-06', 'Walk-in', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(134, 'Gokul Sastry', 'dharmajanchandran@sarma.com', '+910895403457', '+910404189031', 'Ganguly, Balakrishnan and Guha', 'zE2536UZ16', 'Basavanagudi', '1967-12-10', '2023-07-24', 'Instagram', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(135, 'Adira Tak', 'mamootychaudhry@dewan.com', '04097460958', '03898455080', 'Datta PLC', 'ZG1809Vm61', 'BTM Layout', '2001-03-29', '2022-10-06', 'Google', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(136, 'Rhea Ganesan', 'krishraju@grewal-dash.biz', '04188284092', '3517884353', 'Sarkar Group', 'wW1381VC01', 'Whitefield', '1966-03-26', '2018-10-24', 'Walk-in', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(137, 'Urvi Banerjee', 'madhav39@kata.net', '+912452567674', '9230069310', 'Char-Balasubramanian', 'Fo0744nh85', 'Indiranagar', '1996-03-17', '2021-07-16', 'Google', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(138, 'Indrajit Kadakia', 'keyavenkataraman@vig.biz', '2328912444', '+914902962443', 'Contractor Ltd', 'sL9269sO73', 'Jayanagar', '1979-05-24', '2022-12-05', 'Instagram', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(139, 'Raunak Soni', 'parinaaz07@hotmail.com', '+911802323493', '+914644770574', 'Uppal-Tandon', 'Es4609Uh79', 'HSR Layout', '1995-10-20', '2017-03-20', 'Walk-in', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(140, 'Ryan Chaudhari', 'shankashvi@bora-varughese.com', '2474431244', '+910644542717', 'Kota Ltd', 'Nr5088aJ12', 'Rajajinagar', '2000-03-17', '2019-05-23', 'Facebook', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(141, 'Aaina Raj', 'samihabaral@hotmail.com', '7969731078', '+911257337884', 'Gara-Wagle', 'fY9816ua80', 'Yelahanka', '1984-07-15', '2017-05-20', 'Instagram', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(142, 'Divit Sandhu', 'jayantmaharaj@kumar.net', '2553833183', '09925489140', 'Halder Ltd', 'Hy1589tc43', 'Whitefield', '1993-10-28', '2018-03-14', 'Facebook', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(143, 'Arnav Chokshi', 'iyengaradvika@gmail.com', '03144121975', '+913267043867', 'Chhabra Inc', 'yI8700wI89', 'HSR Layout', '2006-10-28', '2022-11-12', 'Google', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(144, 'Heer Char', 'nchaudhuri@gmail.com', '+910848169046', '9246366236', 'Goda, Bath and Chaudhry', 'Lv8717sv97', 'BTM Layout', '1993-05-02', '2017-07-19', 'Walk-in', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(145, 'Inaaya  Mammen', 'divit20@gmail.com', '03879560029', '+911776811958', 'Mane LLC', 'ni5812AK43', 'Yelahanka', '1966-03-24', '2017-03-18', 'Walk-in', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(146, 'Miraan Bhatnagar', 'edwinpurab@yahoo.com', '+911745336364', '06108856443', 'Sahni Inc', 'AD6794AW57', 'BTM Layout', '2000-03-17', '2017-10-05', 'Facebook', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(147, 'Madhav Manda', 'jjohal@dhar.com', '+912434832751', '5613339136', 'Dara and Sons', 'dn4252fs83', 'BTM Layout', '1969-06-15', '2019-02-24', 'Walk-in', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(148, 'Aniruddh Suri', 'xchahal@barad.com', '09263089844', '9505111420', 'Acharya Group', 'lD8587Aj44', 'BTM Layout', '2004-08-17', '2019-02-17', 'Instagram', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(149, 'Samar Sharaf', 'shaanchahal@doctor.com', '7686477779', '6588253333', 'Anand-Mander', 'Nz1054qa86', 'Rajajinagar', '1977-01-23', '2021-07-26', 'Google', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(150, 'Hrishita Desai', 'bkhare@hotmail.com', '02991145636', '2705099985', 'Dara-Ahuja', 'Dh0647aa38', 'Indiranagar', '1979-08-07', '2017-08-16', 'Facebook', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(151, 'Devansh Datta', 'urvishan@badami.org', '3086775792', '6347232245', 'Yadav, Bawa and Gandhi', 'BG1580JJ67', 'Hebbal', '2007-01-28', '2018-07-28', 'Facebook', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(152, 'Veer Saxena', 'zoyalalla@yahoo.com', '1697509385', '08855405526', 'Reddy, Garg and Sankar', 'oT0162Ze26', 'Indiranagar', '1993-01-22', '2022-02-02', 'Facebook', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(153, 'Trisha Mani', 'siyahalder@hotmail.com', '+915119142342', '07614957952', 'Keer-Varkey', 'BP9866jJ02', 'Banashankari', '2005-06-08', '2022-07-07', 'Instagram', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(154, 'Mishti Master', 'bathnitara@gmail.com', '+913083194889', '+913674268036', 'Sha Inc', 'QP2893OC10', 'Koramangala', '1996-12-22', '2015-09-01', 'Google', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(155, 'Romil Sarin', 'bhavsarfarhan@ramaswamy-wason.com', '+915067457331', '03659557842', 'Dara, Vig and Master', 'LD5426LS85', 'HSR Layout', '1997-11-03', '2024-10-01', 'Instagram', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(156, 'Parinaaz Ghose', 'abram05@sharma.net', '07849979378', '07117327752', 'Garg, Chaudry and Balakrishnan', 'bl4361Rj24', 'Banashankari', '1982-08-24', '2016-08-17', 'Google', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(157, 'Emir Tank', 'freddy@balay.com', '09357204867', '4773090651', 'Agate, Master and Sodhi', 'LL0746iK38', 'Rajajinagar', '1970-04-18', '2018-01-16', 'Facebook', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(158, 'Kavya Kibe', 'danikanav@gmail.com', '8697384843', '2201625963', 'Lall-Khosla', 'cu7657FB34', 'Rajajinagar', '2004-10-27', '2018-11-21', 'Walk-in', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(159, 'Divit Sem', 'anaygopal@yahoo.com', '01202003094', '+916138716716', 'Bhasin Inc', 'mE4720PL22', 'Electronic City', '1995-05-26', '2017-06-30', 'Instagram', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(160, 'Adah Sama', 'thakerveer@master.com', '+918321418094', '+919538247958', 'Sunder, Dhingra and Sharaf', 'Aj0059Rs46', 'Rajajinagar', '1979-04-20', '2023-05-23', 'Instagram', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(161, 'Indranil Dhillon', 'vchand@zachariah.com', '+914614088953', '5955314138', 'Gulati, Upadhyay and Gour', 'eO7854gm32', 'Marathahalli', '1982-02-01', '2016-12-10', 'Instagram', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(162, 'Purab Varughese', 'ishaanbera@hotmail.com', '09194673920', '+917987727015', 'Khare-Jhaveri', 'aY5202sv52', 'Hebbal', '2003-06-12', '2018-05-01', 'Walk-in', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(163, 'Oorja Chokshi', 'umang09@yahoo.com', '08283200349', '9392725335', 'Luthra-Uppal', 'Fm7336MM40', 'Whitefield', '1989-04-17', '2019-12-03', 'Instagram', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(164, 'Vidur Deo', 'okala@konda-tiwari.com', '+913099022737', '08506023532', 'Srivastava-Bose', 'IK4452GI63', 'RT Nagar', '1984-01-03', '2025-04-28', 'Walk-in', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(165, 'Kashvi Dora', 'arorahunar@hotmail.com', '+918027595912', '+913520242700', 'Kala, Tata and Solanki', 'HG6579Am56', 'Jayanagar', '1968-11-18', '2019-10-25', 'Walk-in', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(166, 'Yakshit Gopal', 'tiwarikeya@gmail.com', '08753058029', '+917726239748', 'Sridhar-Gopal', 'bT6975yh64', 'Electronic City', '1973-07-03', '2020-01-26', 'Google', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(167, 'Anay Krish', 'gokhaleeva@sehgal.com', '6272305514', '+912018632592', 'Wadhwa LLC', 'hh1271Jr53', 'Hebbal', '1979-09-07', '2018-08-14', 'Instagram', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(168, 'Amira Contractor', 'shanvaibhav@hotmail.com', '8229126427', '+913700219704', 'Kade Group', 'Dj7377UV98', 'Basavanagudi', '1970-03-03', '2016-10-24', 'Walk-in', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(169, 'Advik Ganesh', 'barmanjiya@hotmail.com', '+916818550969', '+915576672684', 'Badal, Bhatia and Swamy', 'RR1640KY28', 'BTM Layout', '1978-11-01', '2024-04-10', 'Walk-in', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(170, 'Ehsaan Sinha', 'nehmatkakar@bhardwaj.info', '3585906851', '06699808793', 'Samra LLC', 'wB9604JJ01', 'Rajajinagar', '1981-06-02', '2023-06-24', 'Walk-in', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(171, 'Tara Raja', 'varmaadira@choudhury.com', '09303544174', '+913305828254', 'Varma-Sule', 'eS4199xL01', 'HSR Layout', '1968-09-30', '2021-12-31', 'Facebook', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(172, 'Yashvi Dave', 'neysa05@dani.com', '3050928068', '7568982512', 'Ravel-Jayaraman', 'jm5333bf43', 'Yelahanka', '2004-03-04', '2017-10-20', 'Instagram', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(173, 'Hansh Sule', 'kavya20@chhabra.org', '05511866605', '02212670001', 'Balasubramanian, Sagar and Tara', 'PX7522wW56', 'Electronic City', '1966-05-14', '2021-05-23', 'Walk-in', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(174, 'Diya Dar', 'rhea34@hotmail.com', '+911625186595', '3817424151', 'Lala-Saha', 'kp7870wO48', 'Yelahanka', '1967-04-04', '2016-07-17', 'Walk-in', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(175, 'Tushar Dugal', 'vkota@hotmail.com', '03433460758', '00873871723', 'Walla-Chad', 'ex4406Kw01', 'Indiranagar', '1965-01-20', '2021-03-30', 'Facebook', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(176, 'Damini Sagar', 'vritikalala@borra.net', '09145236405', '8055073009', 'Goel-Sarraf', 'Tl3788UV53', 'Koramangala', '1984-07-16', '2022-12-12', 'Walk-in', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(177, 'Mahika Jain', 'virkanahi@gmail.com', '07009430209', '+915830773215', 'Dhawan, Basak and Dhar', 'VP4957mA73', 'Banashankari', '1989-09-03', '2018-03-22', 'Walk-in', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(178, 'Pranay Sekhon', 'advikdutta@yahoo.com', '3796259095', '+910149294297', 'Cheema PLC', 'NA3517HY52', 'Banashankari', '1992-04-11', '2016-12-29', 'Google', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(179, 'Divit Sidhu', 'khareritvik@kibe.com', '04976915434', '1611417948', 'Randhawa, Krishnamurthy and Gara', 'vF4765jA73', 'Koramangala', '1992-05-06', '2020-11-22', 'Facebook', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(180, 'Pihu Garde', 'kavyaagate@yahoo.com', '+916171490039', '3242146951', 'Mall and Sons', 'Jf2289Co02', 'Malleshwaram', '1976-12-10', '2020-02-01', 'Instagram', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(181, 'Ahana  Bhalla', 'dharhimmat@grewal-zacharia.net', '2682834520', '08000075651', 'Dar, Dora and Solanki', 'pT3749xW19', 'BTM Layout', '1987-01-26', '2022-09-30', 'Facebook', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(182, 'Vivaan Chadha', 'farhanbuch@bhardwaj-bhargava.com', '+910704624782', '04396039133', 'Chatterjee-Bora', 'dH8529xB41', 'Yelahanka', '1974-02-21', '2016-01-03', 'Walk-in', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(183, 'Biju Karan', 'deybhavin@bora.com', '9233252984', '+910678967243', 'Shukla, Bhandari and Barman', 'aY7980Iu52', 'Koramangala', '1997-05-30', '2018-11-16', 'Walk-in', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(184, 'Mehul Sibal', 'zaina29@roy-chanda.org', '00182571711', '8132347353', 'Loyal Group', 'BF1535Td21', 'Jayanagar', '1999-03-25', '2023-02-24', 'Instagram', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(185, 'Romil Sheth', 'annereyansh@keer.org', '5695048988', '0491754030', 'Sachdev, Jain and Bhatti', 'Tq7962To54', 'Hebbal', '1988-08-30', '2022-01-13', 'Walk-in', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(186, 'Shlok Mangal', 'ojasraman@som-de.org', '03093687868', '0111195062', 'Rana-Wagle', 'Yn6381Cr72', 'HSR Layout', '1986-07-08', '2022-01-06', 'Walk-in', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(187, 'Yakshit Goda', 'esethi@gmail.com', '8815914056', '+913135685712', 'Dewan-Bhagat', 'cy3479xK55', 'Whitefield', '1990-03-01', '2023-10-14', 'Walk-in', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(188, 'Anahita Dugal', 'goyaldishani@mall-gokhale.com', '+919725023293', '09072209310', 'Mangal-Gaba', 'RH7345Za99', 'Banashankari', '1984-06-02', '2015-12-24', 'Google', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(189, 'Jhanvi Batta', 'balaynitara@gmail.com', '+918943333527', '+919888389150', 'Doctor and Sons', 'nj4023Zs94', 'Yelahanka', '1964-12-27', '2020-05-29', 'Google', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(190, 'Zara Walla', 'riaandave@gmail.com', '01995545718', '05006043983', 'Malhotra, Mand and Kalita', 'VP4821kD35', 'Hebbal', '1994-08-11', '2021-01-22', 'Facebook', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(191, 'Nayantara Edwin', 'halderkartik@venkataraman.com', '7810935168', '9722972945', 'Saini-Hari', 'Cj6188mh41', 'Malleshwaram', '1984-04-25', '2022-07-30', 'Facebook', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(192, 'Tanya Sanghvi', 'choprazeeshan@hotmail.com', '+911922791402', '02186723531', 'Bhattacharyya Group', 'lb1879OD61', 'BTM Layout', '1983-02-17', '2024-02-22', 'Facebook', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(193, 'Keya Bose', 'thamannirvi@yahoo.com', '+911717979823', '00722461460', 'Bali, Kaul and Halder', 'vh7865hg59', 'Marathahalli', '1987-06-01', '2025-01-20', 'Google', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(194, 'Adah Sachar', 'birbaiju@sahota.com', '08596363289', '+917430143838', 'Rattan, Zachariah and Jha', 'rx5886aI67', 'Malleshwaram', '1980-09-16', '2016-04-22', 'Instagram', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(195, 'Yakshit Roy', 'cbora@yahoo.com', '02206556805', '09278527543', 'Singh-Srinivasan', 'tG9621FJ82', 'Rajajinagar', '1989-07-15', '2019-11-12', 'Facebook', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(196, 'Damini Ramanathan', 'ramachandranrati@hotmail.com', '07172620723', '1872726201', 'Viswanathan-Reddy', 'hG1751AN73', 'Yelahanka', '1982-06-05', '2019-03-12', 'Google', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(197, 'Lakshay Krishna', 'tbrar@hotmail.com', '02674726251', '+916142406690', 'Kannan, Chaudhry and Bala', 'KL5815ra76', 'Indiranagar', '1984-05-03', '2023-03-10', 'Google', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(198, 'Aaryahi Vaidya', 'zhanda@sura-srinivas.net', '8828077679', '+916737079487', 'Datta-Vaidya', 'hp9196lS28', 'Hebbal', '1973-07-03', '2022-06-17', 'Walk-in', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(199, 'Ahana  Lad', 'bhamini10@gmail.com', '00168773017', '08347983888', 'Solanki, Rege and Soman', 'Ar9853FB03', 'Whitefield', '1993-03-15', '2018-03-16', 'Google', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(200, 'Neelofar Shah', 'krish40@mahal.com', '+916585004767', '2344064972', 'Bhalla, Sarraf and Sagar', 'zS5867ga79', 'Whitefield', '1981-08-28', '2024-09-25', 'Instagram', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(201, 'Advik Basak', 'singhalvaibhav@gmail.com', '3872621450', '1594154304', 'Thaman Inc', 'cq6945Ig70', 'Whitefield', '1976-01-30', '2018-10-04', 'Instagram', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(202, 'Indrajit Sastry', 'gulatiakarsh@gmail.com', '5202917673', '+919599933231', 'Rege-Kadakia', 'IM3667Rv22', 'Whitefield', '1974-01-27', '2017-07-18', 'Instagram', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(203, 'Oorja Sachar', 'anahitabal@hotmail.com', '+915145617921', '2453751254', 'Dhar-Wable', 'Ge5189GR13', 'Rajajinagar', '1972-12-22', '2017-08-05', 'Facebook', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(204, 'Uthkarsh Vaidya', 'bhattidivij@yahoo.com', '9102928682', '4648147657', 'Das, Behl and Magar', 'Rq9481Ft43', 'Hebbal', '2005-12-07', '2017-09-17', 'Google', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(205, 'Rhea Mand', 'kantdishani@hotmail.com', '09899423877', '0440220498', 'Roy-Lata', 'iZ4459ii04', 'Koramangala', '1974-01-31', '2023-08-02', 'Walk-in', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(206, 'Ehsaan Kunda', 'saanvi06@kakar.info', '+914750881265', '3464087529', 'Gera-Kunda', 'aa4945Md28', 'HSR Layout', '2003-01-17', '2021-05-10', 'Instagram', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(207, 'Veer Butala', 'lakshay68@jain.info', '+918373686299', '00832387605', 'Sekhon LLC', 'Lm2843zI84', 'RT Nagar', '1978-10-22', '2021-08-21', 'Walk-in', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(208, 'Lagan Uppal', 'oghosh@karnik.com', '+916103404204', '4222279502', 'Loyal Ltd', 'fX5534pd23', 'Marathahalli', '1985-01-15', '2020-08-11', 'Google', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(209, 'Akarsh Gera', 'lakshit55@gmail.com', '02720480508', '05315726603', 'Sawhney LLC', 'Ne6960vb62', 'Yelahanka', '1970-09-19', '2016-10-16', 'Google', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(210, 'Rania Agarwal', 'biswasgokul@das.com', '08257219428', '02078886956', 'Garde Inc', 'Rh2306Zd51', 'Jayanagar', '1993-12-04', '2018-07-18', 'Walk-in', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(211, 'Krish Sachdeva', 'bdara@jayaraman.net', '0292664117', '07540094279', 'Dhillon LLC', 'Xd4017Il15', 'Banashankari', '2000-04-14', '2016-05-07', 'Facebook', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0);
INSERT INTO `leads_master` (`id`, `name`, `email`, `mobile`, `another_mobile`, `company`, `gst`, `location`, `dob`, `anniversary`, `source`, `looking_for`, `status`, `created_at`, `updated_at`, `is_deleted`) VALUES
(212, 'Pihu Iyer', 'zoya18@gmail.com', '+915381939390', '+913873562920', 'Krish Group', 'Bm7620Kj36', 'BTM Layout', '2001-04-14', '2022-10-02', 'Google', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(213, 'Prisha Wable', 'vidurvarma@kanda-shere.net', '+913626070878', '03659015567', 'Acharya Inc', 'QU9541xH91', 'Whitefield', '1969-12-17', '2020-11-12', 'Instagram', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(214, 'Advik Mahal', 'samiha88@yahoo.com', '9325987286', '00631824408', 'Shah-Maharaj', 'gG7645Rr70', 'Yelahanka', '1997-05-07', '2024-05-13', 'Facebook', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(215, 'Bhamini Bal', 'ugopal@hotmail.com', '+919709708774', '08257831603', 'Anne-Bir', 'eo8889BB39', 'Koramangala', '1982-03-25', '2016-10-17', 'Instagram', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(216, 'Nitya Kaur', 'himmat39@hotmail.com', '08995754526', '7625015708', 'Saha, Chander and Dhawan', 'IJ3618kA06', 'Electronic City', '1985-10-25', '2018-09-26', 'Walk-in', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(217, 'Neelofar Sampath', 'ldugal@gaba.com', '01612190282', '07680644927', 'Ghose-Dalal', 'jq3921tP81', 'Hebbal', '1981-02-15', '2018-12-12', 'Walk-in', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(218, 'Aarush Wali', 'gkala@hotmail.com', '1454835907', '05078103806', 'Golla Ltd', 'CI0439fT32', 'Jayanagar', '1976-06-09', '2019-11-10', 'Google', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(219, 'Dhanuk Dass', 'bakshianika@subramaniam.com', '+919642270190', '+915830318345', 'Krishnamurthy LLC', 'Id2973tf61', 'Electronic City', '1980-05-14', '2016-05-19', 'Instagram', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(220, 'Raghav Dhawan', 'sjaggi@bala-loke.com', '+919487111743', '01990003960', 'Batra, Sekhon and Dara', 'hz4096tk41', 'Hebbal', '2002-12-23', '2018-01-26', 'Facebook', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(221, 'Aniruddh Arora', 'sarafjayan@yahoo.com', '+918052113896', '+910398642621', 'Kibe Group', 'WP5519Vy44', 'Marathahalli', '1980-03-31', '2018-02-16', 'Google', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(222, 'Shaan Tella', 'trishabajaj@gmail.com', '+915970750514', '0402561210', 'Ben Ltd', 'CT4071qq59', 'Rajajinagar', '1971-05-28', '2021-03-20', 'Google', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(223, 'Jivika Sunder', 'jkhurana@hotmail.com', '08610380593', '05625672834', 'Shetty-Master', 'gz2642NF80', 'Malleshwaram', '1984-09-20', '2021-04-17', 'Instagram', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(224, 'Hazel Chanda', 'dharmajan29@sachar.net', '5755727101', '9466391597', 'Raj LLC', 'ix9209zS48', 'Marathahalli', '1997-10-20', '2023-02-13', 'Walk-in', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(225, 'Kavya Viswanathan', 'malldishani@hotmail.com', '06196795539', '+913983859658', 'Mannan, Bava and Taneja', 'nY0908KP18', 'Whitefield', '2001-01-24', '2016-12-18', 'Google', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(226, 'Zoya Bahri', 'indrajitsood@hotmail.com', '05789209439', '6790991021', 'Kothari, Sachar and Datta', 'wA7947fS56', 'Jayanagar', '2005-01-10', '2024-05-08', 'Instagram', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(227, 'Neelofar Gole', 'uacharya@yahoo.com', '+914130508023', '5925886460', 'Shroff-Gokhale', 'KC9701PI14', 'Rajajinagar', '1982-12-26', '2023-11-28', 'Instagram', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(228, 'Lakshay Yadav', 'adviksuresh@mangat.info', '+915644050967', '3159072748', 'Chandra-Cherian', 'Lx9952Nc18', 'Hebbal', '1972-03-09', '2024-03-31', 'Facebook', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(229, 'Hunar Garg', 'biraniruddh@magar.com', '02899183662', '+916062634015', 'Kalla, Date and Devi', 'pq8548Ak24', 'Malleshwaram', '1978-09-17', '2017-07-18', 'Walk-in', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(230, 'Dhruv Gour', 'jayaramanaarna@gala-iyer.com', '7217476183', '+916034992753', 'Sundaram-Dayal', 'wO7371Bj61', 'Basavanagudi', '1988-07-27', '2015-10-16', 'Google', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(231, 'Prisha Swaminathan', 'ycheema@hotmail.com', '+913407719297', '00211032927', 'Bala, Ahluwalia and Bal', 'wc6970xv91', 'Koramangala', '1972-03-11', '2019-09-15', 'Facebook', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(232, 'Indrans Kulkarni', 'azad18@yahoo.com', '4816068197', '7031328687', 'Gade, Kunda and Sachar', 'AZ2198cF47', 'Jayanagar', '1997-10-09', '2015-12-03', 'Walk-in', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(233, 'Indranil Thakkar', 'dchaudhry@hotmail.com', '08347179852', '+915257148613', 'Sachdev Group', 'ho2286MZ37', 'Banashankari', '1969-12-30', '2015-09-22', 'Google', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(234, 'Heer Raja', 'lakshay90@hotmail.com', '3514031699', '+913310459158', 'Tailor Inc', 'XN7554NE45', 'Hebbal', '1991-08-18', '2019-10-30', 'Instagram', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(235, 'Mohanlal Acharya', 'misha44@gmail.com', '00039943835', '09162115014', 'Keer, Bajwa and Kashyap', 'Gs7901XZ74', 'Electronic City', '1986-02-11', '2020-08-24', 'Google', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(236, 'Renee Dani', 'nayantarabala@kata.com', '07167988961', '+917444806287', 'Mander LLC', 'xX4063Te64', 'Indiranagar', '1970-10-26', '2021-12-26', 'Google', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(237, 'Dharmajan Buch', 'ishitashenoy@shukla.com', '07957934092', '5190094961', 'Basak-Apte', 'iz6926rY93', 'Rajajinagar', '1977-09-12', '2024-06-07', 'Google', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(238, 'Aarav Ramesh', 'chandrapari@gulati-sur.com', '09924925758', '07815093362', 'Vora PLC', 'ZI3846wA25', 'Yelahanka', '2002-06-30', '2016-08-21', 'Google', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(239, 'Khushi Badami', 'kartik49@hotmail.com', '5957350114', '7857915139', 'Brahmbhatt-Bassi', 'lI7167Pi81', 'BTM Layout', '1969-02-11', '2016-01-12', 'Instagram', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(240, 'Neelofar Deshpande', 'xghosh@balay-chada.biz', '3757846577', '+916638803842', 'Ben-Bose', 'XY9478bw83', 'Banashankari', '1982-10-16', '2018-04-07', 'Walk-in', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(241, 'Krish Shetty', 'tanya16@yahoo.com', '+919942885799', '+910840443238', 'Subramaniam-Sharma', 'qT4486Dj84', 'Banashankari', '1981-02-13', '2015-06-06', 'Facebook', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(242, 'Sana Kuruvilla', 'gabaaaryahi@sehgal.com', '+917393720033', '4415235089', 'Cheema and Sons', 'FX0836DN98', 'Jayanagar', '1998-03-03', '2017-03-02', 'Walk-in', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(243, 'Rohan Sridhar', 'pranayhalder@yahoo.com', '0757783969', '+918716091946', 'Konda PLC', 'dp6015rV58', 'Marathahalli', '2006-12-22', '2022-05-20', 'Facebook', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(244, 'Biju Biswas', 'chandivan@wali.biz', '+913909569345', '02208765455', 'Mane-Manne', 'QK7480BH67', 'Basavanagudi', '1968-06-05', '2017-08-07', 'Walk-in', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(245, 'Tiya Khanna', 'saanvisant@iyengar.net', '+919507018912', '8882582268', 'Kade-Banerjee', 'fS5054Eg44', 'Indiranagar', '1986-05-27', '2016-11-09', 'Facebook', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(246, 'Dhanuk Jani', 'kantonkar@edwin.com', '08684465266', '+919671433154', 'Sharma, Bail and Tara', 'rS4409ZO59', 'Electronic City', '1996-12-27', '2016-05-03', 'Google', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(247, 'Anya Krishna', 'jivingola@ramaswamy.com', '07135971066', '+915956938303', 'Sandhu Group', 'DX7144My75', 'Basavanagudi', '1992-11-11', '2020-08-05', 'Walk-in', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(248, 'Anaya Arora', 'romildeo@roy.com', '09606146086', '6525245838', 'Sibal Ltd', 'zL7891pe44', 'Koramangala', '1968-08-06', '2022-06-19', 'Walk-in', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(249, 'Divit Hayre', 'craman@de.com', '03024083542', '+913298999288', 'Aurora, Aurora and Thaman', 'on3570MT38', 'Yelahanka', '2003-04-22', '2023-06-21', 'Instagram', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(250, 'Taran Hayer', 'hrishitasibal@balay-chacko.net', '3199042350', '4735538082', 'Ben, Wagle and Kannan', 'Ry2786Dj76', 'RT Nagar', '1972-10-10', '2020-06-17', 'Walk-in', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(251, 'Ivana Saraf', 'saanvi88@gmail.com', '9035589122', '+915055576048', 'Bhatia Ltd', 'jy6287if72', 'Koramangala', '1986-11-19', '2019-05-24', 'Walk-in', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(252, 'Indranil Sur', 'yakshit07@sibal-krishnamurthy.net', '7036032097', '01033239441', 'Shroff-Lad', 'uv3189Ju46', 'Hebbal', '2001-10-08', '2022-07-03', 'Facebook', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(253, 'Keya Guha', 'qchadha@hotmail.com', '02754106667', '3833023839', 'Kota Ltd', 'RE7496dY13', 'Indiranagar', '1970-05-11', '2022-01-08', 'Walk-in', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(254, 'Saksham Sethi', 'hgara@soman.info', '2057869547', '+912989659079', 'Kata Group', 'Dr9669nO38', 'Whitefield', '1987-04-18', '2024-09-28', 'Google', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(255, 'Yuvraj  Gera', 'eshani29@bassi.com', '9312233812', '2343367366', 'Kibe Ltd', 'ar2002Ew38', 'Koramangala', '1975-10-30', '2016-07-06', 'Instagram', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(256, 'Eshani Chokshi', 'soodnehmat@hotmail.com', '6544790655', '05369835376', 'Khare-Dasgupta', 'fZ7069Fy54', 'Indiranagar', '1966-03-27', '2024-03-26', 'Instagram', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(257, 'Umang Badal', 'aaina73@gmail.com', '5870918859', '+918051184000', 'Sarkar, Talwar and Bali', 'aE6094zT84', 'Rajajinagar', '2006-06-09', '2023-04-07', 'Instagram', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(258, 'Tanya Setty', 'sdesai@grover-dass.info', '+918039693943', '+913573582882', 'Dugar, Ramachandran and Ghosh', 'bH7837hE12', 'Koramangala', '1985-09-27', '2016-09-20', 'Walk-in', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(259, 'Akarsh Kapadia', 'himmatvarghese@thakkar-sabharwal.com', '4743013070', '+918584122792', 'Bhalla Inc', 'Im3956qT05', 'HSR Layout', '2000-02-15', '2019-06-11', 'Facebook', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(260, 'Riya Chakrabarti', 'nehmat34@yahoo.com', '07107538416', '+910969488857', 'Lad-Wable', 'Rn7100Mw63', 'Basavanagudi', '1989-07-01', '2020-11-21', 'Instagram', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(261, 'Madhup Ahuja', 'eshani81@yahoo.com', '05976345006', '03785302046', 'Dass PLC', 'gD9083tE61', 'Yelahanka', '1964-08-12', '2017-12-28', 'Facebook', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(262, 'Yuvaan Thaker', 'ishaanedwin@saini-bahri.com', '05390862854', '5672181821', 'Gupta PLC', 'Vc6381dp75', 'Jayanagar', '1964-11-21', '2018-05-17', 'Walk-in', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(263, 'Lakshay Amble', 'doctorkanav@hotmail.com', '+919825326643', '6690092708', 'Vaidya-Yogi', 'yD6089fk15', 'Banashankari', '1975-04-17', '2017-06-20', 'Walk-in', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(264, 'Himmat Bala', 'samarranganathan@gmail.com', '6179540479', '06362446350', 'Lall Ltd', 'yb1826AG21', 'Banashankari', '1985-05-08', '2021-11-19', 'Instagram', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(265, 'Dishani Babu', 'balansamiha@dave.com', '6151514853', '03876730105', 'Bava, Bali and Aggarwal', 'IG2346za98', 'RT Nagar', '1999-07-29', '2022-06-17', 'Walk-in', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(266, 'Gatik Sachar', 'rwalia@hotmail.com', '+913197724241', '+912748336768', 'Choudhry Group', 'uD4408Ez99', 'Hebbal', '1967-09-04', '2019-11-29', 'Walk-in', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(267, 'Riya Venkatesh', 'taimursinghal@gmail.com', '3356334947', '+918121725184', 'Hans-Sarna', 'YL7309ld26', 'Marathahalli', '1965-07-07', '2019-05-17', 'Facebook', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(268, 'Amira Gulati', 'iloke@bahri-keer.org', '+913228620605', '+910703517541', 'Agarwal, Dass and Gaba', 'CW1442Tf30', 'Marathahalli', '1976-11-12', '2025-02-17', 'Instagram', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(269, 'Miraya Karnik', 'anvikhurana@gmail.com', '5395667153', '1182483798', 'Deshmukh-Boase', 'tI5233DQ01', 'BTM Layout', '1985-12-29', '2024-02-24', 'Google', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(270, 'Aarav Thaker', 'kimayavenkataraman@yahoo.com', '+913128582667', '+916063870397', 'Saxena-Rege', 'MD6088DX13', 'HSR Layout', '1985-11-18', '2021-08-09', 'Instagram', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(271, 'Drishya Bhargava', 'dhanushwason@ramachandran-karpe.com', '02566780916', '2397917650', 'Sankar, Baral and Raj', 'mA5634Dt53', 'RT Nagar', '1999-04-03', '2024-02-26', 'Instagram', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(272, 'Nehmat Venkataraman', 'rkrish@yahoo.com', '4102511364', '09390323624', 'Venkatesh-Chaudhary', 'mj1789RU94', 'BTM Layout', '1987-08-23', '2019-02-03', 'Google', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(273, 'Ishita Kapoor', 'krishnazaina@gmail.com', '08770979552', '+913670522232', 'Chacko Group', 'QA8773ct38', 'Indiranagar', '2000-06-28', '2020-10-18', 'Walk-in', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(274, 'Vivaan Kumer', 'kashvi88@gmail.com', '03509997922', '0480723202', 'Chand, Thakur and Dey', 'DE4520EO61', 'Banashankari', '1968-09-04', '2016-10-13', 'Facebook', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(275, 'Aniruddh Bhardwaj', 'kartikborah@yahoo.com', '+916336026723', '+914446365014', 'Bumb, Kapur and Chaudhuri', 'Cz8183WN72', 'Electronic City', '1993-06-10', '2019-07-01', 'Instagram', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(276, 'Kanav Barad', 'jbarad@sekhon.info', '+917970183139', '00278633157', 'Din, Randhawa and Savant', 'EG9039IR54', 'Hebbal', '1975-09-13', '2016-11-19', 'Google', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(277, 'Divyansh Jaggi', 'chakrabartiraunak@sura.com', '3367820634', '1077455229', 'Balasubramanian LLC', 'PA9861hQ22', 'Marathahalli', '2005-01-30', '2019-03-09', 'Instagram', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(278, 'Aaina Sane', 'badal98@tailor.info', '+911871274018', '+914016014086', 'Gola LLC', 'Le8296Aw97', 'Indiranagar', '1973-09-21', '2018-01-16', 'Walk-in', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(279, 'Reyansh Mannan', 'balakrishnanshray@hotmail.com', '03063725894', '8351684192', 'Choudhary-Kadakia', 'Dr3150sZ09', 'Indiranagar', '1970-08-26', '2021-09-12', 'Walk-in', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(280, 'Vidur Grewal', 'kauraayush@yahoo.com', '7213999332', '4055194167', 'Ahluwalia-Tara', 'ru1069dO24', 'Whitefield', '2004-03-20', '2022-10-07', 'Facebook', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(281, 'Vritika Kade', 'qshukla@hotmail.com', '2066049402', '01284355018', 'Sengupta-Varughese', 'pX2686rT01', 'Koramangala', '1975-08-06', '2022-05-01', 'Google', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(282, 'Raunak Samra', 'umannan@hotmail.com', '0429721234', '7158502407', 'Amble Inc', 'vG1260nj22', 'Indiranagar', '1965-02-02', '2018-04-09', 'Facebook', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(283, 'Ryan Mannan', 'indrajit25@hotmail.com', '+913202764940', '8453601470', 'Yadav Inc', 'sk1508PT99', 'BTM Layout', '2005-10-19', '2020-11-21', 'Facebook', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(284, 'Piya Banik', 'anika48@hotmail.com', '2460756259', '00081556087', 'Vasa, Hans and Manne', 'co0514Az13', 'RT Nagar', '1999-10-09', '2023-08-28', 'Instagram', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(285, 'Taimur Verma', 'rsanghvi@yahoo.com', '04054987359', '+914407329024', 'Chandra Ltd', 'oc7622AZ52', 'Basavanagudi', '1969-09-14', '2024-04-06', 'Instagram', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(286, 'Elakshi Sagar', 'darakaira@hotmail.com', '05159432954', '0844977593', 'Kapoor-Bath', 'Ne6020tt72', 'Basavanagudi', '2001-10-06', '2017-02-02', 'Google', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(287, 'Pihu Tata', 'navya92@iyer-dewan.com', '04943067915', '+912564145518', 'Banik, Vaidya and Barad', 'rE0543Om21', 'Whitefield', '1969-12-10', '2017-12-14', 'Facebook', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(288, 'Tushar Shenoy', 'eray@gmail.com', '06927258830', '07762100587', 'Dutt-Baral', 'be5468vm63', 'Jayanagar', '1997-09-01', '2016-03-03', 'Facebook', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(289, 'Zaina Srinivas', 'ratitaneja@gmail.com', '00287224563', '+913590797203', 'Bhatti-Dhaliwal', 'pz1329ja44', 'Jayanagar', '1970-10-06', '2023-02-19', 'Walk-in', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(290, 'Nitara Kapoor', 'shaan67@sahota.biz', '5565060968', '2703254390', 'Anand, Sarraf and Mander', 'es3931oT63', 'RT Nagar', '1977-11-24', '2021-06-18', 'Walk-in', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(291, 'Tushar Sahni', 'dhawanjhanvi@ramakrishnan.biz', '+913655036570', '7627412415', 'Lala-Chokshi', 'Lx2369HY74', 'RT Nagar', '2004-10-30', '2023-09-08', 'Instagram', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(292, 'Jayant Seshadri', 'virkkeya@gmail.com', '4038163677', '+919199834252', 'Devan Ltd', 'hi5022Hq50', 'HSR Layout', '1987-06-25', '2024-04-08', 'Instagram', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(293, 'Zaina Sem', 'shaankarpe@gmail.com', '+916773278440', '+916782299928', 'Brar, Swamy and Trivedi', 'nA1382wu78', 'Rajajinagar', '1995-02-18', '2025-04-01', 'Facebook', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(294, 'Samaira Bal', 'tiwariaarush@gmail.com', '3620041770', '02844255133', 'Ranganathan, Luthra and Karnik', 'ZE0282Up84', 'Electronic City', '1968-06-06', '2024-06-30', 'Facebook', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(295, 'Madhup Vala', 'pmadan@wagle-subramaniam.com', '1789477142', '09665488656', 'Bhatti-Dutta', 'pA9141lG68', 'BTM Layout', '1980-05-12', '2021-12-01', 'Facebook', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(296, 'Neelofar Dewan', 'kwable@grewal.info', '0056092776', '+910756495018', 'Singhal-Dubey', 'rH0522Ud37', 'Yelahanka', '1989-10-31', '2025-01-23', 'Facebook', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(297, 'Yuvaan Banik', 'osahota@gmail.com', '+914592246925', '06934949034', 'Gulati, Lad and Varty', 'nX5868OK60', 'HSR Layout', '2000-05-18', '2024-11-10', 'Instagram', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(298, 'Taimur Chatterjee', 'tara04@hotmail.com', '04130235564', '+912344994760', 'Deep, Dayal and Anne', 'dy3822IY42', 'Indiranagar', '1995-12-03', '2023-02-12', 'Facebook', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(299, 'Stuvan Balay', 'shlok03@gmail.com', '3023981366', '09547079560', 'Sastry, Batta and Chandran', 'gb1415gB13', 'BTM Layout', '1992-04-17', '2022-01-25', 'Facebook', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(300, 'Abram Solanki', 'kashvibora@dhaliwal-kapadia.org', '00723387782', '4163427270', 'Kumar-Dave', 'jW3216wr60', 'HSR Layout', '1984-08-05', '2021-11-19', 'Facebook', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(301, 'Ojas Behl', 'mishti23@bal-ghose.org', '2767196909', '7941273178', 'Batra PLC', 'Id0305Pu40', 'Rajajinagar', '1973-02-15', '2023-12-10', 'Walk-in', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(302, 'Advik Sarkar', 'keerpurab@yadav-zachariah.net', '3046866941', '05923905108', 'Konda-Suresh', 'Sp9846Ak62', 'Marathahalli', '1966-12-06', '2017-06-20', 'Facebook', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(303, 'Myra Kalla', 'eladey@yahoo.com', '4489840861', '+918019244214', 'Atwal, D’Alia and Goyal', 'vQ2968yR97', 'Yelahanka', '1991-10-25', '2020-01-24', 'Google', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(304, 'Jayant Thaman', 'garashalv@roy.info', '03369311717', '4833127665', 'Tripathi, Thaman and Ray', 'bH2757qz31', 'RT Nagar', '2002-12-02', '2018-05-28', 'Google', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(305, 'Damini Thakur', 'ishita26@kulkarni-kala.biz', '3843966047', '5960673574', 'Loyal, Thakur and Lall', 'Dt7498KM31', 'Yelahanka', '2007-01-13', '2020-08-29', 'Walk-in', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(306, 'Onkar Balasubramanian', 'ojas30@ramanathan.info', '+910830804029', '+912689274821', 'Hayer Group', 'uF5210El38', 'Whitefield', '1975-03-02', '2018-06-09', 'Facebook', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(307, 'Dishani Bhandari', 'badaldalal@bains-chauhan.com', '03897263605', '+917483588821', 'Anand-Sundaram', 'iT6122Cw36', 'Hebbal', '1977-08-09', '2016-08-28', 'Instagram', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(308, 'Kavya Kant', 'baiju98@bhakta.com', '06056820077', '+917888804608', 'Rastogi-Walla', 'PX4417Rf50', 'Basavanagudi', '1982-08-16', '2018-12-15', 'Walk-in', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(309, 'Devansh Varughese', 'anikabhalla@chada.com', '+916368904051', '+917927153448', 'Karan-Raval', 'Za6428hI06', 'Electronic City', '1989-03-13', '2020-10-19', 'Walk-in', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(310, 'Emir Mani', 'dorasamiha@dixit.com', '00202683562', '09955906978', 'Walla, Viswanathan and Chaudry', 'jR0464Fl92', 'Yelahanka', '1991-11-21', '2022-03-04', 'Facebook', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(311, 'Anya Khare', 'pranay49@apte-sarkar.info', '+918054454331', '7064399117', 'Dhar Group', 'So0592JL18', 'HSR Layout', '1998-02-18', '2021-02-04', 'Google', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(312, 'Shray Thakur', 'nchhabra@hotmail.com', '+913135480870', '+915867792389', 'Setty, Talwar and Verma', 'Ve8465Dg38', 'Rajajinagar', '1999-08-19', '2023-06-18', 'Google', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(313, 'Aarav Virk', 'sampathrohan@yahoo.com', '07786754340', '+911267484551', 'Bhagat, Sen and Barad', 'xN7337LD77', 'RT Nagar', '1975-03-27', '2015-10-12', 'Facebook', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(314, 'Nakul Mann', 'wsachar@chakrabarti.org', '03688853098', '+919225721337', 'Garde LLC', 'IA0210PA66', 'Jayanagar', '1976-11-02', '2019-05-07', 'Instagram', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(315, 'Arnav Mane', 'khushichander@gmail.com', '+912597738881', '07818478453', 'Kadakia-Aurora', 'Dh0495jd97', 'Rajajinagar', '2004-07-24', '2023-08-31', 'Google', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(316, 'Amani Viswanathan', 'hirandasgupta@krishnan.info', '04697466014', '+917255938533', 'Ramaswamy, Date and Ghose', 'wH0203jz52', 'Whitefield', '1994-07-17', '2023-05-01', 'Facebook', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(317, 'Azad Kaul', 'urvi39@yahoo.com', '05730936932', '+915290663276', 'Raju, Sant and Batra', 'Xe6305pu19', 'Whitefield', '1993-04-01', '2016-06-24', 'Instagram', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(318, 'Badal Bhargava', 'divyansh03@hotmail.com', '+910779823569', '+917391319394', 'Grewal, Bhandari and Sur', 'Ds0119wg33', 'Malleshwaram', '1982-01-14', '2017-09-16', 'Facebook', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(319, 'Uthkarsh Dugal', 'ivohra@bobal.com', '02961400884', '2995368312', 'Shan-Shenoy', 'CS7465PN10', 'Basavanagudi', '1989-11-25', '2021-12-05', 'Instagram', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(320, 'Prisha Raval', 'raghav12@gmail.com', '+918480110631', '09734296460', 'Chaudhari PLC', 'yO6415xE49', 'BTM Layout', '1989-05-10', '2022-01-02', 'Facebook', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(321, 'Renee Hari', 'tdasgupta@gera.biz', '3145099091', '2695969086', 'Krish, Dada and Bal', 'hZ4975wy10', 'Indiranagar', '1972-08-20', '2025-01-09', 'Walk-in', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(322, 'Jiya Reddy', 'mgola@yahoo.com', '9485751326', '+912040869292', 'Bajwa, Brahmbhatt and Bora', 'Nj4613hF60', 'Indiranagar', '1979-05-05', '2018-03-08', 'Google', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(323, 'Anika Yogi', 'chiragchada@sule.com', '6209771631', '4710642165', 'Sundaram-Bhattacharyya', 'qX4563GV21', 'Banashankari', '1995-06-23', '2023-07-22', 'Facebook', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(324, 'Jivin Bala', 'raghav45@sawhney-sood.com', '09342461168', '8932485084', 'Grewal Group', 'jD5551kx72', 'Basavanagudi', '1985-04-18', '2022-04-07', 'Walk-in', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(325, 'Eshani Chandra', 'kumareshani@virk.com', '07415720031', '01328756533', 'Ramakrishnan, Boase and Borah', 'NU5110la70', 'BTM Layout', '1982-03-17', '2024-10-07', 'Instagram', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(326, 'Nirvi Bhattacharyya', 'xdixit@yahoo.com', '00676768456', '5985683736', 'Gandhi, Date and Bhagat', 'lh2709Ne62', 'BTM Layout', '1971-07-24', '2022-01-29', 'Walk-in', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(327, 'Sana Dora', 'samaira63@gmail.com', '+915685675752', '+910644758302', 'Maharaj PLC', 'RB7806Xv99', 'Whitefield', '2002-05-26', '2023-03-03', 'Instagram', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(328, 'Shaan Kohli', 'myrachauhan@yahoo.com', '+911376575549', '2946620131', 'Vaidya, Som and Lalla', 'DW7788Ew81', 'Basavanagudi', '1967-10-02', '2021-08-02', 'Instagram', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(329, 'Prisha Tak', 'bhagatshlok@yahoo.com', '1972421972', '06060313870', 'Dasgupta-Ganguly', 'DR5886Ra99', 'Jayanagar', '1996-03-25', '2019-09-05', 'Instagram', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(330, 'Romil Srivastava', 'virkemir@saha-ganesan.org', '9699485335', '+913864092843', 'Kulkarni-Roy', 'Cb2283ou05', 'HSR Layout', '1996-07-01', '2018-07-07', 'Facebook', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(331, 'Darshit Sastry', 'vartypranay@ravel.com', '0866539709', '+913819393927', 'Ghosh-Barad', 'NS5662aO60', 'Electronic City', '1989-04-07', '2019-08-20', 'Instagram', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(332, 'Azad Ramanathan', 'batraanaya@ramakrishnan.biz', '06691155138', '3028987158', 'Sachdev LLC', 'GC5293LK70', 'Indiranagar', '2002-01-03', '2025-02-27', 'Walk-in', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(333, 'Indrans Ramaswamy', 'dhawanlakshay@kala-sule.com', '2449704132', '1614983032', 'Das-Sarraf', 'yu0192rs42', 'Basavanagudi', '1967-05-31', '2017-04-20', 'Facebook', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(334, 'Heer Bir', 'ehsaanmander@taneja.com', '1077835512', '07585737601', 'Kadakia, Dar and Bhatia', 'Yv0131UB05', 'Jayanagar', '1974-07-11', '2017-10-06', 'Google', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(335, 'Reyansh Jhaveri', 'hbassi@ganesan-shetty.com', '+913056700489', '7276369042', 'Ramakrishnan, Bhatnagar and Vala', 'qi4350FY85', 'Basavanagudi', '1989-06-21', '2020-10-27', 'Walk-in', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(336, 'Keya Kunda', 'miraya12@gmail.com', '06299783116', '9003940403', 'Basu, Varughese and Sachdev', 'sH1552qi41', 'Malleshwaram', '1980-07-31', '2021-12-03', 'Walk-in', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(337, 'Madhav Rajagopalan', 'raunak10@sur-chowdhury.com', '08314059566', '+911142956834', 'Varma-Chandran', 'WN2204Qz95', 'Yelahanka', '1979-03-14', '2024-04-17', 'Google', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(338, 'Hridaan Thaman', 'vramaswamy@hotmail.com', '07818435267', '3278243607', 'Dash, Shetty and Apte', 'bL4906sh11', 'Jayanagar', '1993-12-03', '2019-10-17', 'Instagram', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(339, 'Advika Deep', 'tarasarma@hotmail.com', '+915461613550', '06283786069', 'Basu-Hegde', 'st5119yG06', 'Marathahalli', '1991-01-21', '2018-09-02', 'Google', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(340, 'Akarsh Rana', 'cthakur@sachdev.info', '02410930172', '+910434075941', 'Loyal Ltd', 'yT5159DB63', 'HSR Layout', '1972-02-17', '2016-08-07', 'Instagram', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(341, 'Saanvi Raja', 'hloke@gmail.com', '9813749112', '+912180644317', 'Datta, Sastry and Chadha', 'Nf2718uX70', 'Banashankari', '1977-06-01', '2018-04-26', 'Google', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(342, 'Armaan Sawhney', 'gadelagan@gmail.com', '02713759662', '00987879238', 'Sethi Ltd', 'gj0977Zi75', 'Jayanagar', '1996-05-14', '2017-09-06', 'Instagram', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(343, 'Rasha Arora', 'hrishita37@yahoo.com', '04269763410', '+912813376524', 'Salvi-Roy', 'Nu6622Ts08', 'RT Nagar', '1978-10-22', '2022-01-24', 'Facebook', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(344, 'Navya Samra', 'behlyashvi@hotmail.com', '+915773081923', '09643838777', 'Shukla and Sons', 'ho4918td65', 'BTM Layout', '1966-12-31', '2024-06-16', 'Walk-in', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(345, 'Manjari Sarraf', 'renee41@chander-gopal.info', '4324117136', '+915148853682', 'Kala Inc', 'Il1445rs45', 'RT Nagar', '1982-10-05', '2024-06-05', 'Walk-in', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(346, 'Ishita Kota', 'kalaprerak@yahoo.com', '01164765260', '2357153516', 'Devi-Bakshi', 'es1526Oo56', 'Whitefield', '1978-02-23', '2016-03-15', 'Google', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(347, 'Hazel Lal', 'veerbanik@balakrishnan.com', '4124651037', '1643517241', 'Brahmbhatt, Borra and Dass', 'yU1072mj02', 'RT Nagar', '1995-09-18', '2015-09-07', 'Walk-in', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(348, 'Darshit Batta', 'mohanlalkanda@vyas-dora.info', '4875722806', '05866289810', 'Lala Inc', 'Cv9070EP97', 'Rajajinagar', '1988-02-04', '2020-04-15', 'Walk-in', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(349, 'Saira Mani', 'aarushwarrior@cherian.org', '+911012823529', '07382835287', 'Dada, Ramesh and Sem', 'bb4352Px59', 'Rajajinagar', '1999-08-06', '2021-07-31', 'Google', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(350, 'Zoya Chaudhari', 'emir64@date.biz', '00103677479', '3003365781', 'Rout, Sami and Saran', 'wM9525Ed32', 'Yelahanka', '1982-04-26', '2020-02-22', 'Google', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(351, 'Adira Mann', 'cdeep@yahoo.com', '1613745182', '0234050954', 'Butala LLC', 'fa5448Gc90', 'Indiranagar', '1969-01-17', '2017-10-18', 'Google', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(352, 'Ivan Kaur', 'aniruddhchanda@halder.info', '+916562724763', '3407583750', 'Ramesh, Shenoy and Manda', 'oF9474KM29', 'Banashankari', '1970-06-19', '2021-10-22', 'Google', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(353, 'Amani Khalsa', 'raunaksidhu@yahoo.com', '+914473589757', '+910571008031', 'Behl, Rau and Thakur', 'tQ6972YB72', 'Electronic City', '1974-01-07', '2020-10-09', 'Google', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(354, 'Onkar Acharya', 'zoyakhanna@bhandari.com', '08067302667', '4119639475', 'Rattan, Vora and Sagar', 'Mo9829sL46', 'Malleshwaram', '1982-08-03', '2024-02-07', 'Facebook', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(355, 'Hunar Rana', 'semgatik@yadav.org', '6701226686', '5317493060', 'Mani Inc', 'ZI3352Uw58', 'Whitefield', '1996-12-10', '2021-02-02', 'Instagram', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(356, 'Azad Sankar', 'sairasodhi@bhakta.com', '+910277405827', '0157985226', 'Varghese, Bhargava and Bajaj', 'NH7626AZ39', 'Malleshwaram', '1980-10-26', '2018-05-08', 'Facebook', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(357, 'Aniruddh Lalla', 'nehmatkala@yahoo.com', '2023177546', '+913735640124', 'Lad, Banik and Cheema', 'AS1455oD91', 'Banashankari', '2000-01-26', '2023-10-29', 'Walk-in', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(358, 'Vihaan Batra', 'tushardhar@yahoo.com', '1235222852', '00490617338', 'Sethi and Sons', 'Ia6352pS53', 'Whitefield', '1969-01-28', '2024-11-23', 'Instagram', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(359, 'Rati Sarin', 'ranganathandhanush@gmail.com', '+914727951356', '05069759599', 'Bhandari, Agrawal and Aurora', 'CC6692YP35', 'Hebbal', '1967-04-26', '2019-10-07', 'Facebook', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(360, 'Aradhya Sur', 'tara31@yahoo.com', '00542751385', '01241791133', 'Reddy-Rao', 'dL8259SS39', 'Yelahanka', '1972-02-18', '2016-09-06', 'Instagram', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(361, 'Raunak Devan', 'mjain@arora.info', '3103423558', '+919931990347', 'Bumb, Sarma and Hora', 'MG6429FJ86', 'Yelahanka', '1994-06-20', '2016-04-28', 'Facebook', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(362, 'Uthkarsh Borde', 'miraansood@hotmail.com', '+915068470166', '6692318181', 'Chand Ltd', 'JS5760iP92', 'Hebbal', '1996-10-03', '2018-03-18', 'Google', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(363, 'Khushi Hari', 'kimayakaran@gmail.com', '+913558402704', '+918800333506', 'Lala LLC', 'DO9046ef89', 'Yelahanka', '2005-04-03', '2015-07-18', 'Instagram', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(364, 'Nitara Bali', 'jben@khatri-singhal.com', '05487425337', '+916015240876', 'Ratta PLC', 'sQ8638SQ12', 'Marathahalli', '1996-10-19', '2015-08-12', 'Google', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(365, 'Himmat Verma', 'rohandar@rege.com', '+910081122363', '08314213144', 'Goswami, Ben and Manda', 'ab2773SL81', 'Yelahanka', '1966-04-27', '2018-02-06', 'Google', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(366, 'Yuvraj  Lad', 'mahika45@gmail.com', '+913877993912', '+919197073335', 'Bal, Krishna and Sur', 'KJ3744sK53', 'Koramangala', '1965-05-25', '2024-09-05', 'Google', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(367, 'Kabir Kashyap', 'ycontractor@gmail.com', '05966654077', '8692413028', 'Bajaj, Thakur and Virk', 'Gt7259IZ27', 'Indiranagar', '1968-06-17', '2022-02-06', 'Walk-in', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(368, 'Umang Ganesan', 'sumergupta@lalla-reddy.info', '08135125588', '+913783338640', 'Bhavsar and Sons', 'Vr6146hM61', 'Rajajinagar', '2006-11-07', '2020-08-27', 'Facebook', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(369, 'Bhavin Maharaj', 'vanyachanda@gmail.com', '02188712839', '08422157305', 'Basak LLC', 'Um5988SP22', 'BTM Layout', '1974-11-30', '2021-09-08', 'Walk-in', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(370, 'Ritvik Mand', 'prerak77@upadhyay-seth.org', '3103640704', '+913658677536', 'Keer-Jha', 'EK5612eW09', 'HSR Layout', '1965-03-02', '2020-09-20', 'Facebook', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(371, 'Samaira Varughese', 'xsama@gmail.com', '0641378476', '06978912310', 'Sastry-Kuruvilla', 'Db3234pY68', 'Basavanagudi', '1977-08-25', '2017-06-25', 'Walk-in', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(372, 'Darshit Kanda', 'prishadada@gmail.com', '+912233816764', '02522456217', 'Raman-Comar', 'Gx8298du86', 'Yelahanka', '1978-07-09', '2022-08-01', 'Walk-in', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(373, 'Aradhya Sundaram', 'ebhatt@gmail.com', '+912340454584', '09427461320', 'Suresh, Sethi and Agate', 'CZ3733tU93', 'BTM Layout', '1992-03-16', '2022-08-21', 'Walk-in', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(374, 'Fateh Agate', 'aarna88@dasgupta-mane.net', '02858756369', '05889239237', 'Wali-Grewal', 'WV1875It37', 'Whitefield', '1979-11-10', '2021-09-16', 'Walk-in', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(375, 'Lavanya Ahuja', 'ydevi@seth.com', '01555885324', '3798416848', 'Koshy-Lala', 'RQ5088hq13', 'Electronic City', '2007-01-02', '2021-03-22', 'Google', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(376, 'Ojas Buch', 'bdube@hotmail.com', '09325804575', '+915646269621', 'Tella, Hari and Kothari', 'xH9754fT07', 'RT Nagar', '1993-02-06', '2018-07-16', 'Facebook', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(377, 'Rati Koshy', 'samaira48@chada-shroff.net', '06465877634', '6165717148', 'Divan-Sibal', 'Rx2992ET39', 'Hebbal', '1988-02-03', '2016-06-15', 'Instagram', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(378, 'Manjari Karan', 'vbanerjee@dass.com', '8087124300', '+918896799956', 'Apte Inc', 'QU8770BR15', 'Marathahalli', '2002-10-09', '2022-01-08', 'Google', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(379, 'Shlok Koshy', 'aggarwalalisha@kaur.net', '+914336010033', '05797965854', 'Divan, Yadav and Ravi', 'rj7646vb63', 'Malleshwaram', '1980-08-23', '2024-11-25', 'Facebook', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(380, 'Chirag Sachdev', 'sandhufaiyaz@hotmail.com', '06101960432', '+917159031331', 'Venkataraman, Amble and Sarma', 'Gh7541ta81', 'Indiranagar', '2005-09-06', '2016-02-12', 'Facebook', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(381, 'Siya Dugal', 'trishadugar@khanna.com', '+913849644082', '6621052919', 'Chaudhary, Mahal and Borra', 'Ih2789Xd60', 'HSR Layout', '2006-07-16', '2015-09-08', 'Facebook', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(382, 'Saanvi Jani', 'hansnitya@buch.net', '+919945141830', '01998819191', 'Bir-Balan', 'nc8433lZ23', 'Hebbal', '2003-11-07', '2023-03-24', 'Google', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(383, 'Taimur Gill', 'kbanerjee@hotmail.com', '4415051582', '+917621537365', 'Dave-Soni', 'yS9747iG47', 'Banashankari', '1968-07-13', '2018-08-04', 'Facebook', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(384, 'Suhana Bal', 'vritika93@butala.com', '+915234008099', '+918797206583', 'Sridhar, Sathe and Lal', 'PQ2249cr53', 'Marathahalli', '1970-03-11', '2018-10-07', 'Google', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(385, 'Neelofar Buch', 'ahana-45@hotmail.com', '5121273641', '+918810690183', 'Kale, Tiwari and Shanker', 'OS9714Jv13', 'Indiranagar', '1976-09-17', '2024-05-30', 'Instagram', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(386, 'Lakshit Bumb', 'advikabahri@dara.com', '+919809432276', '8867594034', 'Divan Ltd', 'pM8362DS22', 'Marathahalli', '1999-10-16', '2016-12-22', 'Instagram', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(387, 'Yuvaan Verma', 'gluthra@comar.net', '9374995169', '8255252627', 'Chand, Datta and Bedi', 'zl0345Rj19', 'Banashankari', '1990-01-14', '2025-01-17', 'Google', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(388, 'Ehsaan Chokshi', 'ramivana@wadhwa.info', '04287592860', '5462686634', 'Karnik-Chaudhuri', 'jI6365SX64', 'HSR Layout', '1975-10-21', '2015-09-26', 'Instagram', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(389, 'Divit Sastry', 'ldatta@gmail.com', '7546959104', '08173961497', 'Bhargava, Lad and Arora', 'Zd2228an28', 'Banashankari', '1980-01-14', '2017-12-22', 'Facebook', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(390, 'Mohanlal Chakraborty', 'divanseher@yahoo.com', '4470086624', '02998468037', 'Raju Ltd', 'SC6547uW39', 'HSR Layout', '1973-10-11', '2018-05-14', 'Instagram', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(391, 'Nirvaan Bobal', 'jainzaina@buch.com', '07184846792', '03616923327', 'Biswas, Saini and Sankar', 'Bx1670bZ25', 'Marathahalli', '1968-08-31', '2018-05-31', 'Facebook', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(392, 'Navya Kapur', 'chaudryaarush@yahoo.com', '2944006622', '9710607608', 'Ratti-Tiwari', 'PB2171Mk05', 'Marathahalli', '1998-04-28', '2021-03-06', 'Instagram', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(393, 'Pihu Thakkar', 'manianaya@gmail.com', '03998514038', '09373139320', 'Wadhwa-Barman', 'OC8915jP32', 'Whitefield', '1969-07-02', '2015-06-09', 'Walk-in', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(394, 'Nitara Keer', 'anikasuri@gill.com', '+912892687299', '07495474718', 'Mannan LLC', 'fT5002kg04', 'Banashankari', '1979-07-05', '2023-11-24', 'Instagram', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(395, 'Heer Kara', 'mamootyganesan@chaudhuri-balan.com', '0697926448', '5644322827', 'Bhasin-Buch', 'kn4063Mp20', 'Jayanagar', '2003-03-15', '2024-08-06', 'Google', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(396, 'Aradhya Basu', 'handamisha@yahoo.com', '6739054330', '1766189732', 'Balay, Badal and Sandal', 'eY8925qQ22', 'Koramangala', '1982-07-24', '2017-05-12', 'Google', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(397, 'Kartik Loyal', 'ngill@hotmail.com', '+912605705850', '+910510322949', 'Salvi-Thaman', 'GX6902TV72', 'HSR Layout', '1994-06-20', '2021-03-07', 'Walk-in', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(398, 'Vritika Sodhi', 'fatehsankar@yahoo.com', '05643314400', '+912064181129', 'Lata PLC', 'cU7252CO54', 'Rajajinagar', '1973-01-22', '2024-07-11', 'Walk-in', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(399, 'Adah Tata', 'viswanathanriya@tank.com', '04333566753', '4743004785', 'Buch, Char and Thakkar', 'zf4449JA10', 'Yelahanka', '1974-01-02', '2015-11-05', 'Google', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(400, 'Zeeshan Gour', 'urvi05@behl.com', '+912933447878', '09764733504', 'Sangha, Sahota and Apte', 'if0718Ob38', 'Koramangala', '1974-02-14', '2017-07-13', 'Walk-in', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(401, 'Gatik Vaidya', 'shankareshani@yahoo.com', '1904128676', '8613683674', 'Karan-Gulati', 'gQ2473Og45', 'Whitefield', '1973-06-24', '2017-12-03', 'Instagram', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(402, 'Nehmat Guha', 'ntella@hotmail.com', '09477849542', '01439951734', 'Bandi-Bahl', 'NS0691Cg05', 'Whitefield', '1996-08-20', '2016-04-18', 'Facebook', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(403, 'Kavya Taneja', 'wravel@chandran.info', '+913856856245', '09581673156', 'Bath-Bhavsar', 'Co5237Uu95', 'RT Nagar', '1977-07-26', '2015-11-08', 'Facebook', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(404, 'Nitara Maharaj', 'shahzeeshan@rajan.com', '+917683520242', '+915796616657', 'Deshmukh Ltd', 'oW0806ad07', 'Yelahanka', '1969-01-03', '2019-11-01', 'Instagram', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(405, 'Trisha Hans', 'yvarkey@wable-kohli.com', '9982557521', '00514401121', 'Chakraborty, Deol and Khosla', 'oq6168XS30', 'Marathahalli', '1971-01-24', '2018-10-26', 'Walk-in', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(406, 'Anahita Wable', 'ojasbobal@hotmail.com', '00411268571', '+917415477983', 'Manda PLC', 'cO3029Nr28', 'Yelahanka', '2002-10-24', '2022-12-24', 'Facebook', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(407, 'Tiya Sankaran', 'irasankaran@kade.com', '7029787650', '+917962701656', 'Ramachandran-Bose', 'ds3316cF23', 'Electronic City', '1997-12-04', '2019-03-13', 'Instagram', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(408, 'Shlok Bail', 'mishtikrish@cherian.info', '7344950659', '+915113759087', 'Chandra Ltd', 'Wd4054qO94', 'Whitefield', '2000-07-16', '2017-11-26', 'Facebook', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(409, 'Vivaan Srinivasan', 'myra12@hotmail.com', '+919536442299', '+912256701947', 'Dugar, Som and Randhawa', 'ZL9352aQ71', 'Basavanagudi', '1976-06-24', '2016-04-18', 'Facebook', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(410, 'Abram Datta', 'ishita31@sandal-balan.com', '+917069759025', '8318130151', 'Mall LLC', 'Iy1294we85', 'Jayanagar', '1988-09-27', '2023-04-24', 'Facebook', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(411, 'Reyansh Sengupta', 'aainaseshadri@viswanathan-lalla.com', '8599942603', '+912505059793', 'Kalita, Swamy and Deshpande', 'KW2628aF19', 'Marathahalli', '1970-05-06', '2018-10-20', 'Instagram', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(412, 'Mahika Dhaliwal', 'zaina23@hotmail.com', '+910140169227', '8504629577', 'Kothari LLC', 'eS0083xy82', 'Indiranagar', '1978-04-19', '2022-02-27', 'Instagram', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(413, 'Priyansh Gulati', 'biju20@hotmail.com', '8190574067', '3793542112', 'Vig, Soni and Agate', 'in9316fv40', 'Indiranagar', '1979-11-25', '2023-01-01', 'Instagram', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(414, 'Dishani Chada', 'riaansethi@hotmail.com', '+911213369786', '1277612143', 'Mann-Kale', 'Zt6680sy20', 'Whitefield', '2004-08-10', '2023-03-13', 'Walk-in', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(415, 'Krish Rau', 'xchopra@gmail.com', '04254597793', '04351500843', 'Soni, Verma and Biswas', 'Mz8913Po35', 'Indiranagar', '1979-10-31', '2022-03-09', 'Google', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(416, 'Ishaan Uppal', 'tiya36@bhatnagar-yohannan.com', '07665182285', '4005762174', 'Batra-Vaidya', 'oL0672ER68', 'Malleshwaram', '2004-01-05', '2020-02-27', 'Instagram', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(417, 'Seher Barman', 'bahlsiya@yahoo.com', '03223150013', '+916795744466', 'Kapadia Inc', 'oX6435Lf28', 'RT Nagar', '1992-11-18', '2017-02-08', 'Instagram', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(418, 'Kavya Soni', 'sabharwaljhanvi@goswami.com', '06052179300', '+914190627516', 'Karnik, Chada and Suresh', 'qV6249bX05', 'Rajajinagar', '1989-02-11', '2022-11-18', 'Instagram', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(419, 'Zaina Sinha', 'anaychadha@hotmail.com', '+916433539710', '+911507377344', 'Hora LLC', 'Mf2850Sf84', 'Jayanagar', '1994-05-17', '2024-04-12', 'Google', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0);
INSERT INTO `leads_master` (`id`, `name`, `email`, `mobile`, `another_mobile`, `company`, `gst`, `location`, `dob`, `anniversary`, `source`, `looking_for`, `status`, `created_at`, `updated_at`, `is_deleted`) VALUES
(420, 'Jayant Chana', 'chhabrayuvraj@ravi-varkey.info', '+919444688141', '+919637493063', 'Chaudhary-Yadav', 'TG5231GY19', 'Koramangala', '1969-05-02', '2022-10-14', 'Facebook', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(421, 'Nakul Koshy', 'duberiya@hayer.com', '06903737236', '09081939368', 'Jain, Koshy and Bhalla', 'LD1886Rq99', 'Malleshwaram', '1993-04-03', '2017-11-03', 'Walk-in', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(422, 'Madhup Kumer', 'kashvi31@gmail.com', '+913630731146', '+913615729780', 'Balan PLC', 'lV5150bH48', 'Basavanagudi', '1981-03-05', '2019-11-03', 'Walk-in', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(423, 'Ishaan Karan', 'miraanzachariah@gmail.com', '+910501050479', '0009576622', 'Balasubramanian LLC', 'yZ8599RL31', 'BTM Layout', '1968-05-09', '2016-09-21', 'Facebook', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(424, 'Vardaniya Ramaswamy', 'lchokshi@sura.com', '05150269374', '05267958759', 'Sharaf PLC', 'Kf2692oY23', 'Electronic City', '1998-12-17', '2021-02-01', 'Walk-in', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(425, 'Elakshi Agarwal', 'eraja@jani.biz', '08713423194', '+913784204273', 'Kunda Ltd', 'Ju2830Tg02', 'Jayanagar', '1972-01-26', '2015-11-01', 'Facebook', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(426, 'Pihu Hayre', 'advik63@sarkar.com', '09680060787', '2421171191', 'Dyal PLC', 'nY8773pH44', 'RT Nagar', '1980-12-17', '2017-03-11', 'Walk-in', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(427, 'Raghav Dugar', 'nityawalla@kala-chopra.com', '6813281607', '03430172641', 'Maharaj-Bose', 'AI5835yq77', 'Jayanagar', '1992-03-30', '2022-07-20', 'Facebook', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(428, 'Stuvan Ramakrishnan', 'ranbirbasu@mall-rastogi.com', '01374714584', '+912059638249', 'Chowdhury, Sarin and Dora', 'dj2709aL57', 'Koramangala', '1984-12-23', '2015-12-31', 'Instagram', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(429, 'Jhanvi Kade', 'kalitamanikya@hotmail.com', '4379947054', '+919344423617', 'Bhasin, Saini and Walia', 'TN2764wO24', 'Koramangala', '1990-04-19', '2024-03-13', 'Facebook', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(430, 'Kismat Badal', 'shayak20@tripathi.org', '+919089249895', '+913602463427', 'Kaul Ltd', 'AU4174bh21', 'Whitefield', '1987-08-18', '2020-12-19', 'Walk-in', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(431, 'Nitya Madan', 'alisha60@goda.com', '4302802059', '0972628463', 'Halder Group', 'Zx2713pI93', 'Electronic City', '1979-06-03', '2019-06-20', 'Instagram', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(432, 'Yasmin Kalla', 'raunak50@kaur-gara.info', '07839216835', '8626492884', 'Vig, Varkey and Dhaliwal', 'yq3228wh47', 'Basavanagudi', '1966-04-23', '2022-02-28', 'Walk-in', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(433, 'Ivan Atwal', 'hazel51@dar.com', '+915848107916', '0013334380', 'Ahluwalia, Toor and Goswami', 'dV1119xr22', 'Koramangala', '1992-10-09', '2022-01-24', 'Google', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(434, 'Akarsh Sami', 'devinirvi@yahoo.com', '04546740288', '+910083505105', 'Zacharia, Tandon and Luthra', 'km2997Is34', 'Malleshwaram', '1990-06-23', '2020-09-09', 'Walk-in', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(435, 'Dharmajan Banerjee', 'rajagopalanivana@grewal-joshi.com', '7268780306', '+912643874942', 'Chakraborty Ltd', 'pC2234hQ98', 'Indiranagar', '1992-06-27', '2018-01-04', 'Instagram', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(436, 'Mamooty Thaker', 'vihaandate@kale-balasubramanian.com', '+913924580232', '2935273891', 'Borah Ltd', 'nO1725bB95', 'Jayanagar', '2003-07-02', '2021-11-20', 'Walk-in', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(437, 'Ahana  Handa', 'smangat@yahoo.com', '01671872742', '03634053902', 'Chadha Ltd', 'Or3944EH24', 'HSR Layout', '1978-10-28', '2016-08-07', 'Google', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(438, 'Purab Srivastava', 'uthkarshtrivedi@rajagopal.com', '02728623221', '+910985281651', 'Ratti, Sengupta and Sarraf', 'lG4032fo99', 'Jayanagar', '1993-11-08', '2024-03-29', 'Walk-in', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(439, 'Anya Dutta', 'tchadha@yogi.org', '+910929921912', '+912733744235', 'Gokhale-Johal', 'uv1256xG31', 'Jayanagar', '1967-07-05', '2016-04-22', 'Google', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(440, 'Ryan Thaker', 'grao@gmail.com', '05832825783', '8522371930', 'Gopal, Deshpande and Vohra', 'hg2867Yc04', 'Electronic City', '1971-01-07', '2020-06-27', 'Google', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(441, 'Dhruv Varghese', 'charvi71@rout.net', '0923351397', '+911483035047', 'Sridhar, Savant and Keer', 'Gi9315jW24', 'HSR Layout', '2005-08-05', '2022-08-29', 'Instagram', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(442, 'Ayesha Rastogi', 'drishyakamdar@yahoo.com', '1468433339', '08756278223', 'Tella Inc', 'HR3162ff89', 'Marathahalli', '2005-05-16', '2024-07-01', 'Walk-in', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(443, 'Yakshit Dar', 'bhandariyuvraj@gmail.com', '6323901226', '+918201677511', 'Tak Group', 'yP1270Xu69', 'RT Nagar', '1976-04-01', '2021-11-20', 'Google', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(444, 'Dhruv Grewal', 'ojasbalasubramanian@gmail.com', '0713610285', '+913022132969', 'Sanghvi, Bansal and Raval', 'ss6065Xs75', 'Whitefield', '1985-10-19', '2016-02-22', 'Walk-in', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(445, 'Lakshit Choudhary', 'zganguly@hotmail.com', '08959812818', '+914581259978', 'Dixit Ltd', 'GE5031qH85', 'Basavanagudi', '2003-08-23', '2022-02-03', 'Google', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(446, 'Ritvik Setty', 'amiradar@khanna-bali.com', '03313274197', '05488097115', 'Thaman Group', 'uY3433pv24', 'Hebbal', '1992-06-11', '2024-01-08', 'Facebook', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(447, 'Adah Bhatt', 'balanahana@gmail.com', '06998850335', '+912298356090', 'Dani-Subramanian', 'XS7757Sh09', 'Electronic City', '1977-01-30', '2015-05-22', 'Instagram', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(448, 'Kiaan Dhawan', 'anahita74@hotmail.com', '0658174268', '08071838534', 'Zacharia, Desai and Iyer', 'GV3923Fo18', 'RT Nagar', '1992-02-21', '2021-02-07', 'Facebook', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(449, 'Shalv Datta', 'samraaarna@raju-thakur.com', '3906276235', '4050166486', 'Bora-Raju', 'ay8155YX56', 'Malleshwaram', '1969-04-13', '2016-03-19', 'Facebook', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(450, 'Saksham Bir', 'faiyaz24@zacharia.org', '+911163349922', '8080779630', 'Dixit Group', 'Kh0754Rn07', 'RT Nagar', '1982-01-27', '2017-01-10', 'Walk-in', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(451, 'Gokul Rajagopalan', 'anahibawa@chandran-sura.biz', '+915271186213', '04319991421', 'Gola-Shanker', 'rX0792dG65', 'Whitefield', '1965-02-21', '2018-01-12', 'Walk-in', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(452, 'Saanvi Saraf', 'hrishita35@gmail.com', '+910400441712', '+912982464976', 'Malhotra Ltd', 'HG9987Mi02', 'HSR Layout', '1978-08-19', '2023-11-13', 'Instagram', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(453, 'Umang Dey', 'xbobal@gmail.com', '05752282360', '+910703861685', 'Ram, Mangal and Chaudhry', 'Xa1126kv39', 'Rajajinagar', '1969-01-15', '2023-07-30', 'Google', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(454, 'Heer Baria', 'ramgokul@hotmail.com', '00427810726', '9002589361', 'Lal-Sachdev', 'RB6880jU36', 'HSR Layout', '2000-07-03', '2016-04-25', 'Instagram', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(455, 'Yuvraj  Jhaveri', 'borrajivika@yahoo.com', '5399997245', '08519608821', 'Choudhary, Kota and Sabharwal', 'oX0310Ql61', 'Basavanagudi', '1988-01-19', '2018-02-07', 'Facebook', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(456, 'Yasmin Ratta', 'anyakata@gmail.com', '+918227190962', '05576586145', 'Srinivas and Sons', 'ci6389wC80', 'Yelahanka', '1991-05-07', '2024-12-25', 'Instagram', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(457, 'Fateh Sekhon', 'bhattacharyyakhushi@yahoo.com', '+917939055320', '+919506444685', 'Cherian, Mammen and Tiwari', 'IQ6851cF17', 'Whitefield', '1982-11-06', '2019-12-02', 'Walk-in', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(458, 'Devansh Varkey', 'samihajohal@yahoo.com', '+911838097574', '03850024482', 'Basu-Savant', 'Sb4521bS63', 'Whitefield', '1976-07-30', '2019-09-01', 'Google', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(459, 'Ritvik Kaul', 'sumer16@gmail.com', '07088789202', '7731277071', 'Chacko Inc', 'fN2707HJ41', 'Indiranagar', '2002-08-05', '2022-05-03', 'Walk-in', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(460, 'Renee Sarna', 'bvala@dada.com', '02518072595', '0033772524', 'Ramaswamy-Datta', 'XQ6096tV41', 'Electronic City', '1981-11-03', '2023-03-14', 'Walk-in', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(461, 'Yashvi Sagar', 'oben@ranganathan.info', '7133174983', '09403169565', 'Chakrabarti-Kalita', 'Qu5675BA76', 'Marathahalli', '1974-05-13', '2024-01-19', 'Walk-in', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(462, 'Heer Kakar', 'deshpandehansh@mander-kar.info', '+916188874921', '6727793275', 'Ravi, Manne and Deshpande', 'UD1523BV18', 'Yelahanka', '1970-01-18', '2019-03-22', 'Instagram', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(463, 'Shaan Suresh', 'karajhanvi@krish-sahota.net', '+913847483479', '+915225854823', 'Kaul and Sons', 'SR5940FV15', 'Marathahalli', '1990-08-06', '2019-12-23', 'Instagram', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(464, 'Ela Reddy', 'kanav81@gmail.com', '+914942191592', '0117404305', 'Shetty Ltd', 'eZ8970dc73', 'Jayanagar', '1968-10-27', '2022-07-04', 'Google', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(465, 'Raunak Bhargava', 'bsankar@bhat.com', '+912155176831', '08327799607', 'Sundaram Inc', 'dh6904tP77', 'Indiranagar', '2003-06-12', '2022-08-05', 'Facebook', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(466, 'Indrans Baria', 'chauhanveer@tripathi.com', '09046960156', '07904351921', 'Mani PLC', 'Vp6385bo81', 'Electronic City', '1975-03-18', '2024-12-19', 'Walk-in', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(467, 'Vidur Gade', 'ramira@sunder.com', '09715288272', '+913054266010', 'Maharaj Group', 'Wz3782QA33', 'HSR Layout', '2004-08-02', '2021-09-05', 'Walk-in', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(468, 'Manikya Sawhney', 'choudhryzaina@bhatti.com', '0087656972', '8961553817', 'Master-Deo', 'UW4601Sy17', 'Banashankari', '2006-04-29', '2016-12-11', 'Facebook', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(469, 'Anahi Kala', 'wwagle@choudhary.com', '5418144954', '+911785307412', 'Sane, Jain and Chopra', 'UK4090EK90', 'Rajajinagar', '1987-12-27', '2018-05-10', 'Google', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(470, 'Akarsh Date', 'adasgupta@kapur-madan.com', '05472191854', '1540396362', 'Dayal and Sons', 'Em8135Dx27', 'Yelahanka', '2003-08-15', '2021-06-13', 'Facebook', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(471, 'Mohanlal Sarma', 'smaster@hotmail.com', '02513277470', '03734846903', 'Chadha-Mahajan', 'HS2066wY79', 'HSR Layout', '1985-02-11', '2022-05-22', 'Instagram', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(472, 'Umang Sundaram', 'basakraghav@dutt.biz', '+910421706357', '8607290087', 'Kanda Group', 'KI0370bj93', 'Koramangala', '2005-06-25', '2018-01-02', 'Instagram', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(473, 'Hazel Batra', 'gardearmaan@yahoo.com', '08766341436', '07272060050', 'Johal, Tiwari and Manne', 'ov3761Ho25', 'Koramangala', '1986-02-28', '2019-09-01', 'Instagram', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(474, 'Divij Sandal', 'acharyaritvik@sangha-ganguly.com', '+910992934813', '+915072739641', 'Deshmukh-Sarkar', 'PN8558iX63', 'Indiranagar', '2001-07-17', '2021-03-24', 'Instagram', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(475, 'Vivaan Dhaliwal', 'madananahita@yahoo.com', '4866993767', '9966224610', 'Tak Group', 'eC1636Xp54', 'Indiranagar', '2001-05-08', '2017-03-09', 'Instagram', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(476, 'Pranay Sankaran', 'baladhanush@yahoo.com', '+917714928912', '3564899013', 'Gulati, Garde and Bera', 'He1688Sr06', 'Jayanagar', '1986-01-28', '2016-01-20', 'Walk-in', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(477, 'Suhana Borra', 'vihaandada@yahoo.com', '4057892146', '+911281891196', 'Balasubramanian, Virk and Saraf', 'Ep7480RQ01', 'Whitefield', '1987-07-16', '2019-06-16', 'Facebook', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(478, 'Indrajit Golla', 'madhuplall@jain.com', '+916331887595', '+914774617565', 'Wable, Chhabra and Salvi', 'jY4189FT99', 'Malleshwaram', '1988-06-15', '2016-04-13', 'Walk-in', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(479, 'Ryan Goda', 'ira59@bhavsar.net', '7097896389', '3876290625', 'Singh-Kashyap', 'KQ5248st63', 'Yelahanka', '2003-10-06', '2024-09-09', 'Instagram', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(480, 'Sumer Kapur', 'darshit63@srinivasan.net', '3322706862', '04227584608', 'Banik-Balan', 'fQ8158wy80', 'RT Nagar', '1984-08-25', '2016-04-17', 'Facebook', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(481, 'Prerak Dara', 'aainasabharwal@ganesh.com', '+918663762475', '+918184736087', 'Sodhi, Khanna and Wadhwa', 'Bl0241ed36', 'Electronic City', '1980-12-10', '2017-11-19', 'Instagram', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(482, 'Nitya Gandhi', 'lakshayiyengar@gmail.com', '01208752915', '+918507254229', 'Chokshi, Barad and Sehgal', 'jM7461BV06', 'BTM Layout', '2004-04-07', '2015-12-16', 'Facebook', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(483, 'Shray Salvi', 'yakshit64@gmail.com', '+918981768215', '+910429658430', 'Walla LLC', 'Od0925EW90', 'Whitefield', '1981-12-29', '2018-09-27', 'Google', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(484, 'Anay Lata', 'hiran90@ramanathan.com', '+918267442742', '8657226430', 'Agrawal-Cherian', 'WA1151aC19', 'Whitefield', '1987-03-04', '2020-10-02', 'Walk-in', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(485, 'Rhea Vyas', 'gthaker@hans.com', '9184441387', '8767155211', 'Kamdar Group', 'NE7824OX42', 'Marathahalli', '1986-01-24', '2017-08-02', 'Instagram', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(486, 'Hrishita Sen', 'mdash@dada.com', '+914235284660', '+915992845568', 'Varma-Dhaliwal', 'xq3359Xk58', 'Malleshwaram', '1992-07-05', '2021-11-01', 'Google', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(487, 'Jayesh Gola', 'zeeshanzacharia@dugar.info', '05183226910', '0396366616', 'Gole Ltd', 'it0965UA41', 'Malleshwaram', '1966-10-04', '2019-01-27', 'Walk-in', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(488, 'Himmat Rout', 'vermaanvi@krishnan.net', '01187662066', '+918173431337', 'Bose-Mangal', 'dC4516ZZ00', 'Banashankari', '1977-05-21', '2021-04-01', 'Instagram', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(489, 'Azad Kumer', 'abramsha@raj.org', '0051408250', '02669740559', 'Gulati-Varughese', 'Th9140Iy92', 'Basavanagudi', '1992-12-05', '2016-10-30', 'Instagram', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(490, 'Hridaan Rau', 'sairakanda@hotmail.com', '+914619957163', '+915853859159', 'Kumer-Ravi', 'mS4054OA82', 'Whitefield', '1993-06-25', '2023-05-11', 'Walk-in', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(491, 'Yashvi Gokhale', 'chatterjeeinaaya@mahajan.com', '+911601997511', '2096886112', 'Chakraborty-Shankar', 'rg0911Jh00', 'Electronic City', '1984-04-04', '2020-08-04', 'Facebook', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(492, 'Lavanya Mani', 'andraprerak@vaidya-borde.com', '00955148476', '02602117588', 'Bumb-Dhar', 'Ds4404GK52', 'Marathahalli', '1965-05-14', '2015-05-09', 'Facebook', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(493, 'Abram Andra', 'aliagaba@dada-kumer.net', '5850857234', '8984116050', 'Manda-Manda', 'rf7705oM07', 'Rajajinagar', '1971-07-23', '2017-11-04', 'Walk-in', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(494, 'Jivika Chatterjee', 'tarinisavant@yahoo.com', '7193581540', '07746291180', 'Sibal LLC', 'Iz6878ba35', 'Koramangala', '1984-04-03', '2017-11-16', 'Facebook', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(495, 'Dhanush Khare', 'khannakimaya@ram.org', '4385276956', '+915586159061', 'Comar-Mammen', 'On9307TH96', 'Whitefield', '1985-05-30', '2016-11-17', 'Instagram', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(496, 'Kavya Karan', 'akarsh16@hotmail.com', '06032068893', '04703244648', 'Dhaliwal, Madan and Rama', 'bI2454GU58', 'Koramangala', '1970-06-14', '2022-03-30', 'Google', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(497, 'Kimaya Sampath', 'arhaandugal@bhardwaj-rattan.com', '03381013063', '+918497835963', 'Venkatesh-Krish', 'KC9472Vh36', 'Banashankari', '1988-11-03', '2016-08-13', 'Facebook', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(498, 'Heer Ganguly', 'gsha@gmail.com', '03680483447', '8209907660', 'Sura Inc', 'De4098lC05', 'Indiranagar', '1970-10-04', '2020-08-22', 'Facebook', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(499, 'Raghav Kumer', 'chandraaarna@yahoo.com', '07457827664', '00221546074', 'Sane, Gour and Kota', 'MG8106pI92', 'BTM Layout', '1983-11-07', '2022-08-18', 'Instagram', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(500, 'Elakshi Sane', 'anayramesh@gmail.com', '02252055184', '+919292286389', 'Ram LLC', 'nn1265kO42', 'Electronic City', '1992-05-23', '2024-05-29', 'Facebook', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(501, 'Yasmin Bedi', 'kartik57@hotmail.com', '+919280867969', '+910296040790', 'Gole, Goyal and Chaudry', 'au6445Dj33', 'Rajajinagar', '1981-03-05', '2018-01-12', 'Google', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(502, 'Saira Yogi', 'anayjhaveri@yahoo.com', '02679289051', '06483391807', 'Mannan, Raju and Tiwari', 'VU1440Nl67', 'Hebbal', '1972-08-24', '2019-10-04', 'Facebook', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(503, 'Vanya Rout', 'pbehl@zachariah.org', '6904764343', '+914691732512', 'Sharaf and Sons', 'mv8123ej03', 'Hebbal', '1971-06-30', '2022-10-02', 'Instagram', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(504, 'Ishita Suresh', 'heerroy@yahoo.com', '05427552963', '7560532250', 'Setty, Deep and Chacko', 'Af8980cb24', 'Hebbal', '1982-10-20', '2019-10-05', 'Google', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(505, 'Kanav Ranganathan', 'nganguly@kothari.com', '2080959682', '0466680223', 'Kara LLC', 'Fl9007xO95', 'Yelahanka', '1975-11-20', '2017-10-26', 'Google', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(506, 'Samarth Vig', 'ujha@yahoo.com', '+910800529046', '+916055620166', 'Lall-Dani', 'JF1103wI35', 'Whitefield', '1970-05-23', '2023-04-10', 'Instagram', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(507, 'Jivika Shroff', 'skale@yahoo.com', '05397646275', '4116598075', 'Sankaran PLC', 'Wz8735yL51', 'Hebbal', '1994-11-01', '2023-06-04', 'Instagram', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(508, 'Mamooty Goda', 'vardaniyakhare@hotmail.com', '3579663204', '00214793889', 'Kulkarni LLC', 'sy6446pq71', 'Jayanagar', '1971-10-23', '2020-10-23', 'Google', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(509, 'Oorja Wali', 'manikya56@hotmail.com', '7573253805', '7167703372', 'Dugar LLC', 'aP2185nX32', 'Marathahalli', '1994-11-19', '2023-10-16', 'Instagram', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(510, 'Ranbir Doctor', 'hrishita14@hotmail.com', '+911506935802', '+913237903779', 'Warrior, Bali and Roy', 'xn2114oX48', 'Malleshwaram', '1968-11-13', '2015-06-25', 'Walk-in', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(511, 'Kabir Kurian', 'ghoseryan@hotmail.com', '04811906677', '+916976052064', 'Barman-Comar', 'fq4171kA79', 'Malleshwaram', '1975-12-29', '2023-06-12', 'Walk-in', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(512, 'Shalv Sibal', 'dbhatti@hotmail.com', '4829030314', '2850943346', 'Dewan and Sons', 'Sp1515ok72', 'Electronic City', '1971-06-08', '2022-09-03', 'Google', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(513, 'Kiaan Dubey', 'tlal@tripathi.info', '04769617816', '01541731805', 'Khosla, Jhaveri and Bhalla', 'No8931aq01', 'Marathahalli', '1992-12-04', '2024-06-20', 'Instagram', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(514, 'Khushi Balakrishnan', 'ishaan36@gmail.com', '8284875847', '02056251881', 'Mangat-Khurana', 'qo7346Ng82', 'RT Nagar', '2001-03-17', '2017-02-07', 'Instagram', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(515, 'Bhamini Gour', 'wtiwari@barad.biz', '7124685453', '+911615835285', 'Johal-Raval', 'dq1100Qf72', 'BTM Layout', '2002-03-10', '2015-05-13', 'Instagram', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(516, 'Yakshit Lata', 'shaanissac@kashyap-kaur.net', '7431123931', '0909767065', 'Chana, Talwar and Sami', 'Bx2410lU09', 'Hebbal', '1987-03-12', '2019-05-30', 'Walk-in', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(517, 'Hansh Chad', 'samiha18@gmail.com', '06911352099', '2958267355', 'Baral, Saxena and Buch', 'nO3153Qi84', 'Malleshwaram', '1983-06-15', '2018-04-03', 'Walk-in', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(518, 'Keya Bains', 'jiyakala@devan.com', '+913082257335', '00364893358', 'Chakraborty-Manne', 'iw4415tU21', 'Basavanagudi', '1972-11-18', '2017-05-26', 'Walk-in', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(519, 'Adah Wali', 'hanshsandal@amble.com', '+915106518111', '02690781174', 'Sengupta, Kamdar and Tandon', 'mW8383Gs44', 'Marathahalli', '2000-07-05', '2025-04-17', 'Walk-in', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(520, 'Neysa Golla', 'lalivan@gola-tandon.com', '09452272498', '+913948957675', 'Manda, Bedi and Dutt', 'MP4016Ko57', 'Malleshwaram', '1981-03-07', '2018-05-15', 'Google', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(521, 'Nitya Toor', 'dchawla@verma.com', '08656769634', '4803993917', 'Tripathi PLC', 'gZ0442Ho81', 'BTM Layout', '1985-06-19', '2024-08-07', 'Google', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(522, 'Riya Dasgupta', 'desaipihu@yahoo.com', '02607935689', '07361571798', 'Aggarwal LLC', 'Wh9119Ht55', 'Banashankari', '1990-02-12', '2024-09-23', 'Google', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(523, 'Madhav Bhalla', 'aarushvora@doctor.org', '3948091159', '04848396855', 'Basu Group', 'MN5951wE26', 'Yelahanka', '1979-05-18', '2020-01-30', 'Facebook', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(524, 'Zeeshan Basu', 'evadatta@gmail.com', '5759073619', '08022248967', 'Goel, Buch and Madan', 'nk2394pR53', 'Whitefield', '1976-11-15', '2023-11-12', 'Instagram', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(525, 'Akarsh Ghose', 'swamyparinaaz@yahoo.com', '+913358293663', '9268583368', 'Ray-Lall', 'wS5511vi48', 'HSR Layout', '1974-06-10', '2016-11-01', 'Google', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(526, 'Indrans Cheema', 'alia95@lata.com', '+919331099807', '9592272118', 'Kothari-Iyengar', 'sf9944ua95', 'Hebbal', '1964-07-21', '2024-07-01', 'Google', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(527, 'Purab Baria', 'bassimadhup@hotmail.com', '+911060198633', '07662571585', 'Acharya-Dewan', 'nh7754yC59', 'Banashankari', '1978-12-17', '2022-02-12', 'Walk-in', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(528, 'Raghav Chaudhry', 'baijuchawla@randhawa.com', '5617612167', '7830796328', 'Bal, Sankaran and Sridhar', 'UR1432wS75', 'Malleshwaram', '1972-06-08', '2022-11-01', 'Walk-in', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(529, 'Mishti Gara', 'saira38@kale.com', '+914944630261', '+918476219463', 'Ramakrishnan-Korpal', 'pV7170KN22', 'Rajajinagar', '1981-09-16', '2018-05-24', 'Facebook', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(530, 'Bhavin Khare', 'damini58@hotmail.com', '3028896815', '+916826826417', 'Buch, Tak and Sidhu', 'aD9193cH62', 'Hebbal', '1969-02-01', '2020-08-15', 'Google', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(531, 'Tarini Bawa', 'taradara@yahoo.com', '2044462945', '1973075945', 'Singhal-Zachariah', 'TU2611ya62', 'Basavanagudi', '1987-07-07', '2019-08-05', 'Google', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(532, 'Badal Vasa', 'dharkrish@yahoo.com', '2703623872', '08819767738', 'Chand, Babu and Gulati', 'AW6067Ne04', 'Jayanagar', '1989-11-17', '2024-02-09', 'Walk-in', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(533, 'Pari Wadhwa', 'shanayatata@gmail.com', '+912170508935', '+918342474504', 'Barad-Brahmbhatt', 'Fa6862Tl83', 'Koramangala', '1966-04-10', '2024-12-03', 'Facebook', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(534, 'Armaan Hari', 'drishya93@bal-kala.info', '02275460055', '00922989966', 'Chaudry-Cherian', 'Sc2228Sz05', 'Banashankari', '2005-04-16', '2019-01-09', 'Facebook', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(535, 'Madhav Gade', 'madhupsubramaniam@yahoo.com', '5512630648', '02298432627', 'Char, Choudhry and Vora', 'Ql4339fC35', 'Electronic City', '1996-05-19', '2023-09-06', 'Instagram', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(536, 'Tara Khurana', 'vbobal@dugal.info', '+913664305467', '3077587155', 'Thakkar PLC', 'WK7871Ah06', 'Electronic City', '1967-03-09', '2024-06-22', 'Facebook', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(537, 'Vritika Tandon', 'shaan06@chawla-yogi.biz', '06870262487', '01900995095', 'Sood-Som', 'nM9374BR53', 'Yelahanka', '1965-07-05', '2023-11-20', 'Google', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(538, 'Shamik Thaman', 'khushi16@wable.com', '+914283896544', '+918437843274', 'Badal Inc', 'Gd7602Kp90', 'Koramangala', '1984-03-26', '2019-07-13', 'Walk-in', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(539, 'Madhav Devi', 'fkalla@brahmbhatt.com', '+911282934933', '7490050872', 'Kar, Arora and Kata', 'FR8185Hz24', 'Basavanagudi', '1983-04-27', '2015-09-02', 'Facebook', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(540, 'Ryan Bala', 'armaan84@srinivas-majumdar.com', '09176719352', '+918598296343', 'Sharaf Group', 'UP1656MF64', 'Indiranagar', '1966-01-03', '2017-11-19', 'Facebook', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(541, 'Abram Chacko', 'akade@zacharia-dutt.com', '08843657536', '0563902521', 'Sarma-Sahota', 'Pk8622sz49', 'RT Nagar', '1966-05-21', '2017-04-06', 'Google', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(542, 'Vihaan Ramanathan', 'shlok28@yahoo.com', '9158588428', '+914496772934', 'Hans PLC', 'sb8754bm59', 'Yelahanka', '1986-12-05', '2024-08-24', 'Google', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(543, 'Nirvi Sahni', 'udey@yahoo.com', '8171896627', '03104834687', 'Sarkar, Dara and Jayaraman', 'bq7657Di74', 'Koramangala', '2002-11-21', '2020-03-26', 'Walk-in', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(544, 'Vihaan Acharya', 'mohanlal52@dasgupta.net', '+918084071025', '02038701472', 'Kade Group', 'FW5770vv89', 'Indiranagar', '1988-04-15', '2018-12-24', 'Facebook', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(545, 'Taran Gala', 'tarasane@yahoo.com', '03371114046', '01782861976', 'Salvi, Balasubramanian and Chokshi', 'QX6902Vi06', 'HSR Layout', '1986-07-24', '2023-11-13', 'Instagram', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(546, 'Shalv Bhatnagar', 'koshyritvik@guha.com', '9417360908', '+912555215463', 'Karnik, Comar and Tailor', 'AD3942bq83', 'Indiranagar', '1986-04-25', '2017-11-12', 'Google', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(547, 'Arnav Trivedi', 'kamdarriaan@gmail.com', '+914316456366', '00983700799', 'Grover Inc', 'hu0807ga41', 'HSR Layout', '1999-04-14', '2023-03-04', 'Instagram', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(548, 'Nishith Jhaveri', 'pari19@hotmail.com', '03161765299', '+919921932171', 'Choudhury, Gole and Chad', 'Ss0063Ra19', 'Marathahalli', '1996-09-29', '2022-11-03', 'Facebook', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(549, 'Aradhya Gara', 'purab63@kashyap.com', '+917637326237', '06921114632', 'Manne, Shetty and Sangha', 'Ta4767AB28', 'HSR Layout', '2000-12-17', '2023-09-05', 'Walk-in', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(550, 'Oorja Buch', 'arnavhari@hotmail.com', '5393173260', '+914401170029', 'Sachdev Inc', 'DK2674Ks14', 'BTM Layout', '1985-01-30', '2016-10-19', 'Walk-in', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(551, 'Zaina Boase', 'gokhalesamiha@gmail.com', '+914634129910', '6724525559', 'Saran LLC', 'RN0422ZA70', 'Hebbal', '2004-05-01', '2015-05-10', 'Facebook', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(552, 'Madhav Rajagopalan', 'elaborde@basu.com', '00291983452', '5486342002', 'Bahri-Kibe', 'Vm6299GL63', 'Electronic City', '2001-01-05', '2017-07-22', 'Walk-in', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(553, 'Mohanlal Rajan', 'kaira68@kar-kant.com', '1621622199', '+916428381544', 'Dhar-Mangat', 'SX7971HS83', 'Hebbal', '1974-04-10', '2024-09-15', 'Facebook', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(554, 'Priyansh Dara', 'mvarkey@gmail.com', '+914370891841', '+911486359113', 'Loke, D’Alia and Kapadia', 'eE3484Fr46', 'Yelahanka', '1983-02-01', '2022-05-13', 'Instagram', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(555, 'Nitara Karpe', 'yogihimmat@gmail.com', '+913627361032', '+918966014514', 'Arya Group', 'CW1553rY80', 'Yelahanka', '1984-08-19', '2022-08-31', 'Instagram', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(556, 'Damini Gaba', 'kartikdara@yahoo.com', '5917568902', '04300021646', 'Kota, Singhal and Dugal', 'kv5315aT09', 'Koramangala', '1984-02-08', '2016-04-06', 'Facebook', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(557, 'Akarsh Thakur', 'nsarna@yahoo.com', '+913063600707', '5392810750', 'Chatterjee PLC', 'aK5939Ck80', 'Indiranagar', '1968-11-15', '2022-07-29', 'Instagram', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(558, 'Vanya Warrior', 'tdash@gmail.com', '4536309503', '+915097010087', 'Kothari-Solanki', 'vf0100iw46', 'RT Nagar', '2000-05-13', '2023-07-14', 'Facebook', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(559, 'Neelofar Bhagat', 'jayanttoor@suri.org', '2502303711', '+910582058577', 'Tandon, Dara and Raval', 'CP5844lg37', 'RT Nagar', '1969-05-30', '2017-11-03', 'Walk-in', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(560, 'Madhav Doshi', 'kmaster@choudhury.com', '1182991571', '+913766813164', 'Ghose and Sons', 'Mq7900wB53', 'Banashankari', '1964-09-07', '2023-05-26', 'Walk-in', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(561, 'Zain Ranganathan', 'mkibe@hotmail.com', '+918687885788', '+916808796086', 'Borra Group', 'UG7960Ds65', 'Basavanagudi', '1996-03-31', '2024-05-02', 'Walk-in', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(562, 'Lakshit Sahota', 'mannanindranil@apte-kata.com', '1739577350', '03104276091', 'Madan Inc', 'hz7757oW49', 'Electronic City', '1965-05-21', '2019-12-30', 'Google', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(563, 'Kartik Sha', 'bhattacharyyamishti@yahoo.com', '04536458609', '6004052441', 'Gill Inc', 'uA3623qw20', 'Hebbal', '1984-02-04', '2015-12-28', 'Instagram', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(564, 'Tiya Chadha', 'suradishani@krishnan-bali.com', '9214352440', '04171008815', 'Gole-Sharma', 'MY9183Ei68', 'HSR Layout', '1994-10-10', '2018-01-07', 'Walk-in', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(565, 'Kismat Sampath', 'odoctor@bedi-badami.com', '08291732362', '+910957666782', 'Ratti-Hari', 'Tj7076IU77', 'Banashankari', '1983-04-27', '2023-07-12', 'Walk-in', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(566, 'Rati Zachariah', 'bsubramaniam@yahoo.com', '+910733421926', '08154688727', 'Badami-Desai', 'JK3651qW05', 'Rajajinagar', '2000-03-07', '2021-01-07', 'Instagram', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(567, 'Kimaya Mannan', 'aradhya34@mann.com', '+911087343070', '+913398891122', 'Dhar Group', 'Wf5979KL59', 'Marathahalli', '1999-06-25', '2018-07-27', 'Google', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(568, 'Sumer Rajan', 'pbaral@sura.org', '9706286886', '8475038437', 'Brar-Sankaran', 'tK7356zu28', 'Marathahalli', '1983-06-13', '2025-01-09', 'Walk-in', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(569, 'Dishani Rau', 'jsunder@gmail.com', '9328348525', '1827910138', 'Bawa and Sons', 'Kw5138Uj38', 'Hebbal', '1999-01-03', '2016-11-25', 'Google', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(570, 'Manjari Kunda', 'randhawaanahita@kara.info', '9578442054', '+914003848163', 'Virk, Chaudhari and Mall', 'Qq1370HY07', 'Indiranagar', '1976-02-19', '2023-02-22', 'Instagram', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(571, 'Yashvi Tailor', 'pyogi@yahoo.com', '+915730709785', '0326403365', 'Khurana, Dave and Sule', 'Em2393DF26', 'Jayanagar', '1993-06-06', '2016-02-08', 'Walk-in', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(572, 'Samiha Thaker', 'rdhingra@gmail.com', '09231388941', '09950680414', 'Bakshi PLC', 'WX0421Zf01', 'Rajajinagar', '1984-02-19', '2022-12-20', 'Walk-in', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(573, 'Baiju Thaker', 'indranilsoman@shenoy.com', '04236176101', '+917712929699', 'Singhal Ltd', 'oL9077hd59', 'HSR Layout', '1969-03-26', '2024-08-27', 'Walk-in', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(574, 'Rhea Ahluwalia', 'lsane@gmail.com', '+917098864095', '06421933976', 'Choudhry, Ganesan and Sunder', 'Ls2810WT23', 'Malleshwaram', '1969-12-20', '2020-08-01', 'Facebook', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(575, 'Yakshit Sha', 'tarinikumer@hotmail.com', '+912704618756', '+911989830726', 'Sami, Sathe and Hora', 'Wk5444QB75', 'Koramangala', '1975-07-15', '2016-10-29', 'Facebook', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(576, 'Bhavin Dada', 'inaaya-kota@jhaveri.com', '+915929145754', '03445224528', 'Walia and Sons', 'px7198TL36', 'Banashankari', '1973-05-09', '2023-07-24', 'Instagram', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(577, 'Elakshi Som', 'tiyabadal@goswami.com', '05791330902', '2786303285', 'Sridhar-Mall', 'xu0759XU43', 'Banashankari', '1983-02-17', '2016-05-08', 'Walk-in', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(578, 'Bhavin Bhattacharyya', 'zara07@hotmail.com', '+918739185807', '+916607440972', 'Choudhry LLC', 'bh3103WE23', 'Hebbal', '1993-07-25', '2021-12-12', 'Instagram', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(579, 'Stuvan Acharya', 'ayeshabanik@hotmail.com', '5553689312', '08006560078', 'Chana-Dhawan', 'rJ9132se64', 'BTM Layout', '1977-10-13', '2018-02-28', 'Facebook', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(580, 'Kimaya Ahuja', 'nakul71@sood.info', '+919508992668', '7777281657', 'Maharaj and Sons', 'YX5555Iv99', 'Malleshwaram', '1974-06-30', '2020-03-23', 'Instagram', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(581, 'Misha Bedi', 'lbarad@salvi-shanker.biz', '1257053704', '09876317152', 'Konda and Sons', 'XS3861Mc49', 'HSR Layout', '1985-10-18', '2016-06-17', 'Walk-in', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(582, 'Saira Sridhar', 'karniknayantara@bhattacharyya-dubey.net', '04044313664', '02972294682', 'Sura-Deshpande', 'Pr8951Wr41', 'Marathahalli', '1993-10-11', '2021-11-28', 'Instagram', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(583, 'Rati Dayal', 'samarth85@yahoo.com', '09672552573', '08562866203', 'Goda-Wali', 'GS8177Jw15', 'Jayanagar', '1981-12-04', '2021-04-14', 'Google', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(584, 'Raunak Bhalla', 'samairasrivastava@gmail.com', '1498694383', '4973469745', 'Gopal LLC', 'Er4898dK72', 'Rajajinagar', '1976-12-01', '2023-12-21', 'Instagram', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(585, 'Manjari Srinivasan', 'iyeraradhya@yahoo.com', '+911687561538', '+917893482878', 'Karpe, Sama and Kata', 'Ii1983Xf81', 'Basavanagudi', '2001-04-06', '2023-09-03', 'Google', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(586, 'Rhea Vaidya', 'rsama@kuruvilla-randhawa.com', '01068623306', '+913199826881', 'Dhar, Shankar and Tandon', 'Ay8396Ji97', 'BTM Layout', '1971-02-19', '2016-10-13', 'Walk-in', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(587, 'Kashvi Contractor', 'ntara@hotmail.com', '0596545147', '02285377130', 'Shah, Singhal and Bhatt', 'iP0213nR78', 'Rajajinagar', '2006-02-02', '2023-06-11', 'Walk-in', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(588, 'Ivan Virk', 'reneesagar@hotmail.com', '05636341840', '09783195660', 'Ram Ltd', 'VB5916DD81', 'Basavanagudi', '1987-05-30', '2020-07-31', 'Google', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(589, 'Nitara Doshi', 'saanvibhavsar@contractor.biz', '+919074317599', '8062805225', 'Sood, Shroff and Lanka', 'Kl1480ft36', 'Banashankari', '1973-07-27', '2019-06-14', 'Instagram', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(590, 'Suhana Bobal', 'umang34@yahoo.com', '7610934380', '+917984404326', 'Bhatnagar-Tata', 'WR4105mh57', 'Koramangala', '1999-02-06', '2024-05-03', 'Instagram', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(591, 'Mishti Chaudhary', 'rohandalal@hotmail.com', '+918344257334', '+914960037820', 'Gade-Bath', 'QP1363UC24', 'RT Nagar', '2002-10-02', '2020-02-13', 'Facebook', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(592, 'Renee Vala', 'goyalpurab@srinivas-kamdar.net', '+910822618597', '08122907445', 'Dugar, Chopra and Iyengar', 'OZ0527ab93', 'HSR Layout', '1983-11-06', '2020-06-15', 'Walk-in', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(593, 'Badal Balasubramanian', 'lagan85@bora-grewal.info', '06012158419', '6770855979', 'Chand, Mand and Johal', 'aU6192wN89', 'Yelahanka', '1985-12-01', '2021-06-16', 'Walk-in', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(594, 'Anika Edwin', 'ryansami@hayer.com', '3172524966', '2369368840', 'Sachdev PLC', 'Zo1692VV24', 'Electronic City', '1998-01-30', '2018-01-04', 'Walk-in', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(595, 'Rohan Chaudhuri', 'hridaankuruvilla@malhotra.net', '2232597694', '09649257837', 'Kota, Warrior and Kala', 'rv0336vW89', 'Marathahalli', '1984-04-09', '2016-02-18', 'Walk-in', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(596, 'Shamik Varkey', 'ssule@kar.com', '+910832946012', '6233769289', 'Ben, Bal and Ben', 'sD6429aN48', 'Jayanagar', '1967-03-31', '2022-05-24', 'Instagram', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(597, 'Elakshi Vala', 'guhanitara@gmail.com', '+915156420416', '05728657026', 'Bakshi-Saraf', 'He1286Rh35', 'Rajajinagar', '2001-08-29', '2018-12-01', 'Instagram', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(598, 'Mahika Bal', 'shraymander@trivedi.com', '06714866906', '4613544825', 'Wali PLC', 'wr4582Qs77', 'RT Nagar', '1972-04-23', '2022-05-20', 'Facebook', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(599, 'Yashvi Master', 'psur@randhawa.net', '09594040604', '09255712530', 'Chhabra LLC', 'LS2045pu00', 'Indiranagar', '1988-09-10', '2020-07-20', 'Facebook', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(600, 'Vivaan Ram', 'edwinzeeshan@gmail.com', '00563332277', '+919289670362', 'Madan-Khosla', 'Yz7467tG94', 'Hebbal', '1983-09-17', '2017-01-11', 'Instagram', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(601, 'Nehmat Chawla', 'ksarna@shah.com', '6406893646', '7545849377', 'Uppal Inc', 'Am6743wR66', 'Rajajinagar', '1988-12-13', '2019-07-19', 'Google', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(602, 'Prisha Ahluwalia', 'echerian@manne.org', '05435800835', '06053672960', 'Sibal Group', 'hg4294pb67', 'Basavanagudi', '1978-06-18', '2016-08-31', 'Walk-in', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(603, 'Shanaya Behl', 'manjariramakrishnan@yahoo.com', '6996048494', '+918893164210', 'Agate-Vohra', 'wv1279Gp39', 'Rajajinagar', '1966-01-21', '2022-02-09', 'Google', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(604, 'Abram Sood', 'sahotapihu@hotmail.com', '01251825366', '03381363210', 'Venkataraman-Khare', 'gv7954GE35', 'Rajajinagar', '2003-07-16', '2015-07-10', 'Facebook', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(605, 'Alia Sule', 'mangatmahika@rout.com', '3011989184', '+910532822863', 'Biswas LLC', 'PP8848iz77', 'Malleshwaram', '1985-02-16', '2020-03-31', 'Instagram', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(606, 'Siya Anne', 'akarshsekhon@keer-vohra.org', '+914814277062', '02925836359', 'Shukla-De', 'zK9922is49', 'Jayanagar', '2003-03-09', '2018-11-03', 'Walk-in', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(607, 'Hansh Kurian', 'uthkarshsule@lad-sundaram.com', '+913741461062', '01350411125', 'Sura-Tiwari', 'Nf9936lI33', 'Malleshwaram', '1995-11-11', '2021-02-26', 'Walk-in', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(608, 'Urvi Kalita', 'sureshmannat@dube.info', '+913978099083', '+914908704068', 'Sidhu-Sani', 'OI2504UA50', 'BTM Layout', '1998-07-19', '2015-06-03', 'Walk-in', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(609, 'Lagan Thakkar', 'vritikalata@gmail.com', '03869640188', '02228519405', 'Shetty LLC', 'aE6346Xf46', 'Rajajinagar', '2007-03-01', '2017-07-01', 'Facebook', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(610, 'Alisha Char', 'chauhanmadhav@apte-kalita.biz', '2987163495', '0493354369', 'Hora-Srivastava', 'ya2670Kz12', 'Whitefield', '1981-04-05', '2016-12-24', 'Google', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(611, 'Sumer Bhatti', 'bshroff@krishnan-kapur.com', '04599322405', '9257122677', 'Tailor Ltd', 'Wo0780lS50', 'HSR Layout', '1992-11-19', '2023-11-24', 'Walk-in', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(612, 'Anya Khare', 'charvi18@bir.com', '03492949026', '2817877360', 'Rajan and Sons', 'iJ4016Uu52', 'Marathahalli', '1999-09-03', '2023-11-09', 'Google', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(613, 'Miraya Koshy', 'prerak30@hotmail.com', '+910941615885', '7332974690', 'Biswas-Ahuja', 'Pn5613ni48', 'Rajajinagar', '1973-01-06', '2020-12-02', 'Walk-in', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(614, 'Vivaan Chatterjee', 'ygolla@yahoo.com', '5641668224', '8661454044', 'Chaudry-Wadhwa', 'aY1545vA80', 'Electronic City', '1972-09-23', '2023-06-29', 'Google', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(615, 'Armaan Din', 'kimayaratti@arora-datta.com', '+917928737633', '04112457635', 'Vasa-Gokhale', 'Vl1429rL46', 'Rajajinagar', '1979-07-29', '2020-04-16', 'Walk-in', 'ERP', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(616, 'Yakshit Sharaf', 'buchhridaan@gmail.com', '08738189504', '05993259080', 'Iyer-Sengupta', 'bb6488th21', 'Malleshwaram', '1971-03-31', '2017-08-30', 'Instagram', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(617, 'Shlok Gera', 'qbasu@hotmail.com', '3379582830', '5830796593', 'Sankaran-Venkataraman', 'gg0555Oy92', 'Yelahanka', '1971-10-10', '2019-12-07', 'Facebook', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(618, 'Riaan Sibal', 'karanojas@barad.com', '0710412180', '03259515888', 'Sha-Jhaveri', 'Xw1110lX28', 'HSR Layout', '1973-01-16', '2015-11-30', 'Google', 'Dairy Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(619, 'Raunak Garde', 'khannanakul@ravel.net', '7460636131', '9143445414', 'Chand, Ratta and Manne', 'ze6817ap42', 'Jayanagar', '1986-07-24', '2024-06-03', 'Walk-in', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(620, 'Ela Manne', 'korpalromil@gmail.com', '02900708793', '+919320015775', 'Dar-Solanki', 'xB2255vE39', 'BTM Layout', '1993-03-25', '2021-02-02', 'Instagram', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(621, 'Piya Jain', 'kanav93@devan.biz', '06876367919', '+918548437641', 'Dubey LLC', 'nt3352Hb71', 'Yelahanka', '1970-02-21', '2017-01-23', 'Instagram', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(622, 'Mishti Chacko', 'sibalindranil@samra.org', '+915145629967', '7230479432', 'Seshadri-Chandran', 'vE9165Zo04', 'Malleshwaram', '1986-10-09', '2021-12-10', 'Google', 'Flat Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(623, 'Zain Bera', 'mandveer@yahoo.com', '7393792141', '04568594073', 'Dixit PLC', 'Nk0739jL49', 'Electronic City', '1985-11-27', '2016-08-24', 'Instagram', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(624, 'Eva Sundaram', 'samihajayaraman@bhakta.net', '08109454516', '04088775123', 'Chaudry Ltd', 'Iw3826iZ00', 'Yelahanka', '1998-08-24', '2021-02-06', 'Google', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(625, 'Myra Chahal', 'shayakchana@gmail.com', '05822579493', '09118717009', 'Goel, Sani and Kapur', 'oV0017gt63', 'Electronic City', '1997-11-06', '2020-08-07', 'Facebook', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(626, 'Nitara Dutt', 'ude@varghese.com', '7354995860', '+910592603124', 'Viswanathan-Dar', 'qM3089TD53', 'Electronic City', '1967-05-14', '2017-01-23', 'Google', 'Massage & Body Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(627, 'Parinaaz Bhat', 'ghoseyasmin@kara-bhagat.com', '1610696172', '5377240749', 'Seth Ltd', 'qY6658ew73', 'Banashankari', '1998-11-06', '2019-03-12', 'Google', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(628, 'Hridaan Lad', 'nchandra@sen-balakrishnan.com', '5444519472', '7064978186', 'Iyengar PLC', 'Iw8313Ck82', 'HSR Layout', '2001-09-28', '2021-11-04', 'Instagram', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0);
INSERT INTO `leads_master` (`id`, `name`, `email`, `mobile`, `another_mobile`, `company`, `gst`, `location`, `dob`, `anniversary`, `source`, `looking_for`, `status`, `created_at`, `updated_at`, `is_deleted`) VALUES
(629, 'Shamik Badal', 'qdugal@yahoo.com', '+919308312083', '4165070418', 'Agate, Bhattacharyya and Karan', 'zZ2443dm81', 'BTM Layout', '1971-01-24', '2022-07-16', 'Instagram', 'Cakes & Chocolates', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(630, 'Eva Sethi', 'baijudar@hotmail.com', '+919823841018', '+913125467475', 'Chandra, Randhawa and Ray', 'od5371Cu24', 'Rajajinagar', '1964-10-31', '2022-02-07', 'Google', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(631, 'Kaira Dayal', 'rati64@kant-date.com', '05933036012', '6794674648', 'Varma-Manne', 'Bh1181HL79', 'Rajajinagar', '1974-12-23', '2025-02-06', 'Google', 'Hex Head Bolt', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(632, 'Aayush Zacharia', 'alisha60@singhal.org', '05998356511', '2783918582', 'Raval Inc', 'GV9551YT35', 'Banashankari', '1981-04-22', '2020-04-22', 'Instagram', 'Birthday Parties', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(633, 'Vanya Bail', 'nakul26@sant.com', '+918193255629', '00334756516', 'Srinivasan Inc', 'Ik2267Ip18', 'Marathahalli', '2005-02-18', '2023-01-18', 'Facebook', 'Haircare Products', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(634, 'Khushi Varty', 'tataparinaaz@kaur-bakshi.com', '+915609736252', '+913004234283', 'Kari-Dara', 'vO3037XI69', 'Banashankari', '1999-02-09', '2015-10-08', 'Facebook', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(635, 'Jayant Venkataraman', 'bhargavaalisha@yahoo.com', '03332837916', '1354800956', 'Kibe-Malhotra', 'WH6454Xa31', 'BTM Layout', '1977-10-15', '2021-11-18', 'Walk-in', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(636, 'Vedika Dar', 'prerakgokhale@zacharia.biz', '7586478622', '+915300958620', 'Tripathi, Sen and Sem', 'TK8475Nw97', 'Electronic City', '1995-12-09', '2021-11-11', 'Facebook', 'Battery  & Charging', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(637, 'Siya Warrior', 'ritvik89@sanghvi.com', '0163511630', '5265833240', 'Dutta-Kunda', 'AC0504pM49', 'Electronic City', '1989-10-03', '2022-05-03', 'Instagram', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(638, 'Kiaan Balasubramanian', 'kapoorahana@hotmail.com', '8088816207', '1616983415', 'Halder-Dara', 'xI7026xG29', 'BTM Layout', '1969-05-01', '2018-03-04', 'Walk-in', 'Pet Grooming', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(639, 'Rhea Sundaram', 'zeeshan46@hotmail.com', '07844817512', '+915946737226', 'Barman and Sons', 'wl5599Cu08', 'Electronic City', '1980-08-21', '2018-03-19', 'Facebook', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(640, 'Chirag Konda', 'borahyasmin@venkataraman-dash.org', '+911273342343', '+917251522922', 'Dass, Bala and Bava', 'Wu2182on82', 'Rajajinagar', '1966-07-17', '2023-05-13', 'Instagram', 'CRM', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(641, 'Jayant Shan', 'yrajagopal@agrawal.biz', '9610409697', '06744833258', 'Sane LLC', 'Bg4677Qk27', 'Yelahanka', '2004-03-19', '2024-09-01', 'Instagram', 'Photography & Videographers', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(642, 'Darshit Bahri', 'warriorsana@kamdar.biz', '4419902768', '6784711774', 'Kanda-Kadakia', 'Ez7615iG70', 'RT Nagar', '1979-01-08', '2018-07-28', 'Walk-in', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(643, 'Mohanlal Amble', 'himmatchander@doctor-divan.com', '5658410040', '+919538823540', 'Agate-Golla', 'Tm7138Rd45', 'Whitefield', '1996-03-07', '2016-05-25', 'Instagram', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(644, 'Trisha Wali', 'ibhargava@kurian-chadha.org', '06536947958', '05822693188', 'Barad PLC', 'Rx8421wY36', 'Basavanagudi', '1998-12-16', '2016-07-03', 'Walk-in', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(645, 'Stuvan Devi', 'jkashyap@hotmail.com', '1715450540', '7199424616', 'Chacko Ltd', 'Id8280sM16', 'Basavanagudi', '2007-01-24', '2025-04-27', 'Walk-in', 'Deep Cleaning Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(646, 'Dhruv Savant', 'rgarde@gmail.com', '03954441873', '+910870233187', 'Chaudhuri, Issac and Kanda', 'Yw1464Wp80', 'Malleshwaram', '1999-03-13', '2019-11-28', 'Facebook', 'Yoga', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(647, 'Lakshit Babu', 'mehul85@hotmail.com', '2528151075', '2448531866', 'Dutta and Sons', 'wW2442eo85', 'Hebbal', '1990-09-29', '2015-06-09', 'Facebook', 'Software Maintenance', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(648, 'Indrans Thakur', 'dsavant@hotmail.com', '00105630356', '3214859236', 'Dhaliwal Group', 'HM0759jv98', 'Marathahalli', '1979-11-25', '2024-07-14', 'Google', 'Hair Services', 1, '2025-04-29 10:03:08', '2025-04-29 10:03:08', 0),
(649, 'Emir Soman', 'preraksengupta@contractor-devi.com', '4629675687', '07125675550', 'Kade-Toor', 'El9040Rm29', 'BTM Layout', '1967-07-09', '2022-12-13', 'Instagram', 'Cakes & Chocolates', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(650, 'Neelofar Biswas', 'nishithzacharia@gmail.com', '+913582578304', '8516944498', 'Ray LLC', 'Kq1367Et64', 'HSR Layout', '1986-07-17', '2015-07-06', 'Walk-in', 'Hex Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(651, 'Farhan Ramakrishnan', 'ghoshtiya@gmail.com', '+910485269447', '+915860367044', 'Bhardwaj, Madan and Gera', 'FT5744vi82', 'Electronic City', '1967-11-14', '2019-08-17', 'Google', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(652, 'Ritvik Savant', 'dharemir@gmail.com', '09747299178', '+917616369405', 'Talwar-Ahuja', 'hj0151rW01', 'Malleshwaram', '1985-08-11', '2016-12-18', 'Walk-in', 'Hair Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(653, 'Aayush Mahajan', 'sarnashayak@hotmail.com', '00882031334', '3293525593', 'Din, Chauhan and Manne', 'gM7801HI71', 'Marathahalli', '1976-05-12', '2015-07-25', 'Instagram', 'Hex Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(654, 'Bhavin Grover', 'sankareshani@brahmbhatt.org', '9473127880', '+911727044572', 'Sachdeva PLC', 'NQ1567SH19', 'Malleshwaram', '1977-06-21', '2019-12-02', 'Instagram', 'ERP', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(655, 'Vritika Wagle', 'ryan23@gmail.com', '00033741075', '+910423136803', 'Jani Group', 'fz4350KO85', 'Malleshwaram', '2005-11-05', '2021-01-17', 'Facebook', 'Deep Cleaning Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(656, 'Aaina Gandhi', 'lrege@yahoo.com', '+913383118612', '+914887090065', 'Banerjee-Dubey', 'QA3312iw78', 'Banashankari', '1974-07-20', '2016-07-26', 'Walk-in', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(657, 'Tushar Singh', 'gbrar@gmail.com', '6155453496', '06610963795', 'Das, Rastogi and Chauhan', 'ND1127nt98', 'Whitefield', '2001-09-05', '2021-06-10', 'Google', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(658, 'Anvi Chhabra', 'anay58@shroff.com', '+913578332377', '+916106476573', 'Thaker-Ramachandran', 'GQ7471oU47', 'Yelahanka', '1998-12-30', '2019-04-07', 'Google', 'Cakes & Chocolates', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(659, 'Eva Korpal', 'ishita54@chaudhari-bath.net', '03685944219', '+914427111614', 'Bir LLC', 'YV2466XF47', 'Whitefield', '1973-03-16', '2017-04-25', 'Google', 'Birthday Parties', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(660, 'Rohan Chaudhry', 'chokshikhushi@lala.info', '02746267698', '3800944228', 'Sahota-Kaur', 'KU9750cf20', 'Electronic City', '1997-02-25', '2020-04-05', 'Walk-in', 'Software Maintenance', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(661, 'Baiju Samra', 'priyansh52@gmail.com', '6993836189', '03959517296', 'Cheema, Chopra and Sodhi', 'mv1846jg85', 'Yelahanka', '1977-11-10', '2015-07-05', 'Instagram', 'Hair Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(662, 'Divij Kibe', 'neysa45@warrior-vyas.info', '+912433829117', '9475280185', 'Zacharia Ltd', 'tZ1561gl88', 'Jayanagar', '1995-05-09', '2018-09-17', 'Facebook', 'CRM', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(663, 'Umang Arora', 'bsaran@sundaram.com', '08460411770', '07434620851', 'Vora-De', 'AC7510uc13', 'Rajajinagar', '1999-10-27', '2016-12-04', 'Google', 'Yoga', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(664, 'Jayant Comar', 'gandhikanav@majumdar.net', '06233179416', '7519473076', 'Randhawa-Trivedi', 'Of6187xC70', 'Electronic City', '1991-03-29', '2024-09-28', 'Walk-in', 'Battery  & Charging', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(665, 'Darshit Bhatt', 'lrajan@sule.com', '+915550527016', '08703392953', 'Kamdar, Sibal and Keer', 'RA3470DF81', 'Rajajinagar', '1994-08-11', '2018-07-21', 'Google', 'CRM', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(666, 'Anika Badami', 'osachdeva@solanki.com', '02910211509', '+918920234987', 'Trivedi-Som', 'ei7580yr43', 'Koramangala', '1992-10-27', '2021-11-27', 'Walk-in', 'Hex Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(667, 'Riya Deol', 'chandpranay@sur.info', '+919530652200', '08009208459', 'Sura, Kaul and Chadha', 'gX6094Xa53', 'Electronic City', '1968-03-02', '2016-12-08', 'Instagram', 'Haircare Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(668, 'Nishith Halder', 'odasgupta@gmail.com', '7556190945', '02126790423', 'Rattan, Sani and Raj', 'oD7713io04', 'RT Nagar', '1966-11-02', '2024-12-24', 'Instagram', 'Battery  & Charging', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(669, 'Dhruv Mangal', 'lshroff@maharaj.net', '09062996769', '+912538451228', 'Chauhan, Manda and Chaudhary', 'wD0344Fr57', 'Marathahalli', '1983-10-19', '2021-01-21', 'Facebook', 'Yoga', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(670, 'Uthkarsh Manne', 'parinaazandra@gupta-comar.com', '+917916597246', '+918809257179', 'Thakur and Sons', 'jP8683wj53', 'Marathahalli', '1998-01-16', '2023-06-12', 'Facebook', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(671, 'Taran Dhingra', 'jhaverisaanvi@sabharwal.com', '06011125110', '7022965809', 'Sachdeva Ltd', 'jp5658jA44', 'Rajajinagar', '1972-08-16', '2017-09-27', 'Google', 'Yoga', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(672, 'Yakshit Varghese', 'shettydharmajan@sankaran.org', '09943233353', '00434470999', 'Sami-Dara', 'ko2494Nz92', 'Banashankari', '1991-03-06', '2019-10-10', 'Facebook', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(673, 'Riya Khalsa', 'vardaniya10@varma-dubey.net', '02568396503', '09823774891', 'Banik-Ben', 'Br1435Gb57', 'Basavanagudi', '1982-05-09', '2020-01-29', 'Walk-in', 'Photography & Videographers', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(674, 'Baiju Dyal', 'cdas@rastogi-shukla.com', '06693945275', '03579976383', 'Basak, Bobal and Baral', 'MG4655JX36', 'Yelahanka', '1998-01-24', '2024-08-06', 'Instagram', 'Haircare Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(675, 'Damini Sura', 'jchakraborty@hotmail.com', '0022544149', '5052883957', 'Ramachandran PLC', 'FZ1360FV44', 'Basavanagudi', '1985-05-25', '2017-05-06', 'Walk-in', 'Flat Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(676, 'Sumer Grewal', 'gkumar@bandi-samra.info', '9518641704', '+912032102434', 'Rout, Barman and Rana', 'Mk8728wR42', 'RT Nagar', '1982-07-05', '2018-06-26', 'Instagram', 'Hex Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(677, 'Bhamini Sood', 'ztoor@bhatti-vasa.org', '+917170727399', '+918193385636', 'Rama, Goswami and Chauhan', 'zz3520eT63', 'RT Nagar', '2001-04-16', '2025-02-21', 'Facebook', 'Haircare Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(678, 'Shayak Kibe', 'katacharvi@balan.com', '04729746206', '07597071745', 'Kata and Sons', 'WT3311CW40', 'Banashankari', '1975-05-22', '2023-09-04', 'Google', 'Battery  & Charging', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(679, 'Gokul Dugar', 'rattanfarhan@sandhu.net', '9486221342', '09281251399', 'Handa Group', 'Sv1940GS12', 'Marathahalli', '1983-05-23', '2020-12-21', 'Google', 'Dairy Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(680, 'Umang Ahuja', 'elakshi05@gmail.com', '01261972469', '4570388882', 'Singh Inc', 'pe9032gi53', 'RT Nagar', '1982-03-02', '2021-07-04', 'Facebook', 'Deep Cleaning Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(681, 'Aarush Golla', 'mvarma@yogi.org', '07816893874', '+914204653899', 'Mander, Bora and Malhotra', 'Zs9301KL60', 'Marathahalli', '1977-06-20', '2015-11-03', 'Instagram', 'Deep Cleaning Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(682, 'Prisha Sami', 'pvarma@hotmail.com', '01814721070', '+911057529532', 'Sabharwal-Tella', 'tL2884td09', 'Hebbal', '1971-01-17', '2022-05-13', 'Walk-in', 'Deep Cleaning Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(683, 'Sahil Bava', 'riyasundaram@anand-balan.com', '5435754158', '4635013065', 'Sarraf LLC', 'fR7938rq19', 'Indiranagar', '2001-06-18', '2016-02-12', 'Google', 'Hex Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(684, 'Kiara Gade', 'shray75@hotmail.com', '+915064345257', '+913147467785', 'Halder LLC', 'Aq6382ak65', 'Marathahalli', '1969-10-10', '2017-04-25', 'Facebook', 'Cakes & Chocolates', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(685, 'Jayesh Khanna', 'samarthsidhu@hotmail.com', '08459174934', '7505789306', 'Ramakrishnan, Mand and Dash', 'wz0537mk57', 'Yelahanka', '2005-11-09', '2022-11-12', 'Instagram', 'Cakes & Chocolates', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(686, 'Manikya Dube', 'rvaidya@chakrabarti.com', '04803900112', '6510911432', 'Bawa, Savant and Gala', 'jI3141LL41', 'Malleshwaram', '1964-09-28', '2018-04-29', 'Walk-in', 'Birthday Parties', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(687, 'Ryan Dhar', 'veerlalla@yahoo.com', '9974780719', '4162389907', 'Singhal, Varughese and Bains', 'ue3224LI89', 'HSR Layout', '1968-09-05', '2016-01-16', 'Facebook', 'Software Maintenance', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(688, 'Kabir Manda', 'lakshit47@rau.com', '05321000407', '4132707024', 'Deol-Sur', 'uC5506qM51', 'Hebbal', '1992-02-29', '2025-03-05', 'Google', 'ERP', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(689, 'Yashvi Gola', 'mmalhotra@doctor.biz', '+910293659832', '8663450636', 'Keer-Venkataraman', 'JP2322QE89', 'Whitefield', '1977-11-08', '2016-07-13', 'Instagram', 'Photography & Videographers', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(690, 'Vaibhav Chacko', 'renee08@zacharia.biz', '+912987852864', '+914898970385', 'Sani, Kunda and Tank', 'nd2320Ml66', 'HSR Layout', '1982-06-02', '2018-12-15', 'Instagram', 'CRM', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(691, 'Tanya Gade', 'sarkarmadhav@seth-soman.com', '+916829122818', '01440131712', 'Roy, Kala and Chaudry', 'Ty8368ZW98', 'Banashankari', '1994-12-31', '2021-01-01', 'Walk-in', 'Cakes & Chocolates', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(692, 'Saira Reddy', 'zaina35@hotmail.com', '0002362095', '8679643298', 'Bora and Sons', 'os5769ZN42', 'Electronic City', '1987-02-24', '2018-06-20', 'Facebook', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(693, 'Nishith Thakkar', 'cchauhan@yahoo.com', '+910039441171', '3512999897', 'Tak-Dugar', 'FU5045QJ07', 'Yelahanka', '1971-08-18', '2020-12-15', 'Google', 'ERP', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(694, 'Piya Mahajan', 'jayeshcontractor@gmail.com', '4399988488', '5611264841', 'Varughese LLC', 'kR8211BZ36', 'Marathahalli', '1989-04-20', '2021-02-06', 'Walk-in', 'Haircare Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(695, 'Ishita Srinivasan', 'mallkiaan@tailor.com', '+917659784078', '+910826305229', 'Acharya, Sethi and Chhabra', 'ah1780bE32', 'Banashankari', '1974-10-14', '2021-08-31', 'Instagram', 'Cakes & Chocolates', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(696, 'Mehul Badami', 'sonidharmajan@gmail.com', '+917208395281', '+913941441571', 'Bandi, Rajagopalan and Ganesan', 'tW6939Ej65', 'Banashankari', '1964-06-18', '2016-10-19', 'Google', 'Massage & Body Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(697, 'Zara D’Alia', 'chowdhurystuvan@kapur.com', '7642114241', '+918910966491', 'Din LLC', 'Dj5216qH42', 'BTM Layout', '2003-07-09', '2018-06-20', 'Google', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(698, 'Pihu Ranganathan', 'jivika80@yahoo.com', '00016722797', '0291597001', 'Dani-Banik', 'zh8187XG37', 'Basavanagudi', '1971-01-08', '2018-06-28', 'Walk-in', 'Photography & Videographers', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(699, 'Yashvi Lata', 'dbala@yahoo.com', '8894909035', '07541409001', 'Choudhry-Bains', 'jT0676Ak84', 'BTM Layout', '1990-11-23', '2017-03-07', 'Google', 'Flat Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(700, 'Manikya Ramakrishnan', 'ishita05@hotmail.com', '9893288606', '+912351339383', 'Chaudhary, Rama and Sastry', 'GZ2495ZS08', 'RT Nagar', '2006-08-10', '2022-03-29', 'Instagram', 'Photography & Videographers', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(701, 'Raunak Walia', 'jkhalsa@bath.com', '4942512346', '05090383155', 'Keer Group', 'kO9192IL26', 'Indiranagar', '2001-03-01', '2016-06-06', 'Walk-in', 'Hex Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(702, 'Urvi Desai', 'balasubramanianritvik@mandal-bhatt.com', '07065079271', '+919198286603', 'Mahajan PLC', 'xX5808dH96', 'Indiranagar', '1982-02-14', '2018-03-06', 'Instagram', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(703, 'Zain Wason', 'shlok58@joshi.info', '06895243512', '04914308842', 'Khatri, Swamy and Devi', 'zH0592co71', 'HSR Layout', '1991-04-17', '2022-08-01', 'Google', 'Hair Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(704, 'Jhanvi Borde', 'shlokwadhwa@gmail.com', '03411728979', '+919481168802', 'Mander-Mammen', 'uA4598DP10', 'Koramangala', '1988-03-27', '2020-05-01', 'Instagram', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(705, 'Ivan Singhal', 'siya89@sachar-thakur.com', '1073556248', '+919948619272', 'Ranganathan LLC', 'Ol3587Br85', 'Malleshwaram', '1975-09-21', '2021-06-12', 'Facebook', 'Dairy Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(706, 'Misha Barman', 'dashshanaya@yahoo.com', '+910096832298', '05845672051', 'Chaudhari, Kala and Sha', 'PH0781Wc14', 'Electronic City', '1967-03-09', '2022-10-27', 'Google', 'Yoga', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(707, 'Uthkarsh Lata', 'thamanshanaya@hotmail.com', '+915841041685', '+910419244241', 'Gulati-Shere', 'Bx6122nR93', 'RT Nagar', '1994-02-10', '2024-06-10', 'Instagram', 'Dairy Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(708, 'Dhanuk Tripathi', 'isarna@yahoo.com', '6546744442', '05525962764', 'Tiwari Inc', 'SX8959xb81', 'Whitefield', '1981-01-17', '2020-12-26', 'Facebook', 'Cakes & Chocolates', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(709, 'Farhan Desai', 'wbhardwaj@yahoo.com', '09584599622', '+911206059883', 'Ramachandran LLC', 'IJ6259is19', 'Malleshwaram', '1986-07-14', '2015-08-10', 'Walk-in', 'Yoga', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(710, 'Kimaya Bumb', 'ogoswami@agarwal-deshmukh.com', '06165145292', '+914904628462', 'Lata Group', 'Ld0589Eg35', 'Rajajinagar', '1973-03-05', '2021-09-16', 'Google', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(711, 'Damini Dhaliwal', 'savantkiaan@gmail.com', '5334251826', '07785609796', 'Ray, Magar and Maharaj', 'ZK3597ER61', 'Rajajinagar', '2005-06-29', '2017-10-23', 'Google', 'Haircare Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(712, 'Damini Deshmukh', 'divitsolanki@hotmail.com', '+911720583664', '2861879759', 'Gandhi, Ramesh and Apte', 'Cf0776ID18', 'Koramangala', '1968-09-19', '2018-05-12', 'Walk-in', 'Software Maintenance', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(713, 'Jayant Shanker', 'nakul66@wason.biz', '+917133559416', '3854690901', 'Sethi Inc', 'yF1306VL46', 'BTM Layout', '1966-11-14', '2023-06-12', 'Instagram', 'CRM', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(714, 'Shamik Dixit', 'anayakeer@gmail.com', '6900267834', '00509147558', 'Aurora, Dhaliwal and Manda', 'fV9527ZO96', 'Marathahalli', '1988-08-03', '2015-05-18', 'Instagram', 'Flat Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(715, 'Saanvi Rastogi', 'siya44@hotmail.com', '+918315898177', '+912594853512', 'Char, Krishnan and Shere', 'tw7521cC57', 'Koramangala', '1975-01-04', '2024-07-08', 'Google', 'ERP', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(716, 'Shanaya Reddy', 'indranil44@gmail.com', '6714955274', '06836438792', 'Jhaveri, Chaudhary and Basu', 'WT1843kS08', 'Banashankari', '1995-10-14', '2016-03-06', 'Walk-in', 'Birthday Parties', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(717, 'Yakshit Sangha', 'trisha06@gmail.com', '+911636477785', '9647734116', 'Bumb, Gokhale and Mannan', 'xN7971he51', 'Hebbal', '2002-11-09', '2015-07-22', 'Instagram', 'Massage & Body Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(718, 'Khushi Ganesh', 'ksaha@gmail.com', '5473365963', '+913307011905', 'Barad, Korpal and Khosla', 'ZJ7164vF31', 'Whitefield', '1996-02-26', '2016-10-30', 'Walk-in', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(719, 'Rania Saraf', 'darshitdeol@hotmail.com', '2043979273', '+917670519727', 'Bansal-Chana', 'Io1250xK47', 'Jayanagar', '1977-01-19', '2018-01-29', 'Walk-in', 'Deep Cleaning Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(720, 'Manjari Shukla', 'nchakraborty@yahoo.com', '05244535709', '02740490879', 'Tiwari and Sons', 'LN5874dI17', 'Basavanagudi', '1998-02-08', '2015-09-30', 'Instagram', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(721, 'Nakul Doctor', 'vidursani@dhawan.com', '+913498951922', '05885079055', 'Loke PLC', 'gP1296ZI99', 'Jayanagar', '1986-11-02', '2021-02-22', 'Facebook', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(722, 'Adira Kapadia', 'miraan96@thaman.com', '2828907161', '1544619821', 'Vala and Sons', 'Te1322WI02', 'HSR Layout', '1979-12-25', '2016-08-07', 'Walk-in', 'Deep Cleaning Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(723, 'Emir Sarma', 'badamiaayush@gmail.com', '+917760246591', '+916588107643', 'Apte, Sur and Rajan', 'dt4030bP50', 'HSR Layout', '1965-09-17', '2019-01-19', 'Google', 'Hair Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(724, 'Dhanuk Karan', 'maharajhrishita@yahoo.com', '+919785645195', '1828853413', 'Ramaswamy-Sehgal', 'yV0199dx96', 'Banashankari', '1991-12-21', '2018-10-09', 'Walk-in', 'ERP', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(725, 'Zaina Shanker', 'bhargavastuvan@sur-srinivasan.com', '9748772034', '09231555799', 'Tripathi-Rattan', 'gT3773TS11', 'Basavanagudi', '1985-06-28', '2024-12-25', 'Google', 'Yoga', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(726, 'Hunar Kumar', 'dhanukhora@johal.com', '05202019037', '+918241871656', 'Kurian-Tella', 'uj3461EI87', 'Malleshwaram', '1997-05-30', '2015-11-01', 'Facebook', 'Hex Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(727, 'Shalv Basak', 'tkulkarni@gola.biz', '0895115825', '5067046161', 'Walla-Bal', 'lw6301eh63', 'Banashankari', '1971-02-03', '2020-01-11', 'Google', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(728, 'Sahil Kuruvilla', 'eguha@yahoo.com', '8352634776', '0435249395', 'Sheth LLC', 'Uh3081Ae74', 'RT Nagar', '1984-12-10', '2023-06-23', 'Google', 'Battery  & Charging', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(729, 'Nehmat Khalsa', 'echakraborty@ahluwalia.com', '4253969796', '+910750277426', 'Jaggi and Sons', 'Ke2729gh67', 'RT Nagar', '1986-06-07', '2017-09-29', 'Walk-in', 'Haircare Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(730, 'Urvi Hari', 'madanjhanvi@gmail.com', '1215801032', '+911067684920', 'D’Alia-Bal', 'TW6872UA68', 'Basavanagudi', '1994-12-16', '2019-08-27', 'Facebook', 'Hex Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(731, 'Shayak Sodhi', 'gillyasmin@yahoo.com', '04954291810', '+916023718848', 'Kuruvilla, Lala and Kunda', 'wp6305NG17', 'Hebbal', '2003-10-06', '2019-10-30', 'Walk-in', 'CRM', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(732, 'Trisha Talwar', 'samarkarpe@hotmail.com', '2380982801', '03490531316', 'Gokhale PLC', 'Sg7072oJ84', 'HSR Layout', '2003-02-25', '2015-10-10', 'Instagram', 'Yoga', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(733, 'Eva Wali', 'phari@sathe.com', '5677889955', '02442422804', 'Soni-Varghese', 'RA5886lC61', 'Koramangala', '1976-12-13', '2016-01-21', 'Instagram', 'Software Maintenance', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(734, 'Aayush Goda', 'eamble@hotmail.com', '02958266700', '01261018394', 'Mani-Jhaveri', 'zE2508Rk57', 'Koramangala', '2004-07-14', '2020-08-29', 'Walk-in', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(735, 'Mannat Dey', 'bsaran@gmail.com', '+918369918016', '09158313053', 'Ghose PLC', 'EO8178Nn62', 'Whitefield', '1971-05-10', '2017-04-04', 'Facebook', 'ERP', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(736, 'Dishani Balakrishnan', 'karashalv@yahoo.com', '7690562331', '2143915046', 'Sharaf, Lad and Babu', 'Mb1801Oi28', 'Indiranagar', '1966-07-10', '2016-09-20', 'Google', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(737, 'Arnav Dugal', 'ddua@gmail.com', '+919984403297', '08357133907', 'Kunda, Dayal and Date', 'fI9311vT49', 'Malleshwaram', '1966-06-21', '2023-08-22', 'Instagram', 'Hair Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(738, 'Renee Reddy', 'badaltara@garde-majumdar.com', '1680423272', '01942727089', 'Sankaran Group', 'XG6524UI61', 'RT Nagar', '1994-10-27', '2020-11-07', 'Google', 'Hex Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(739, 'Divyansh Zacharia', 'taimur57@gmail.com', '+917533144215', '08368647667', 'Dass, Mann and Yohannan', 'im7058CA22', 'Rajajinagar', '2002-04-25', '2023-07-11', 'Facebook', 'Haircare Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(740, 'Yuvaan Ramakrishnan', 'dhruv61@hotmail.com', '+913646507519', '6010770297', 'Kapoor-Chaudhari', 'IV9133Pm08', 'Indiranagar', '1977-10-01', '2023-04-21', 'Walk-in', 'Hair Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(741, 'Sahil Bora', 'miraankalla@gmail.com', '6434124806', '+914199395952', 'De-Madan', 'Jk9802sK54', 'Electronic City', '1972-12-15', '2024-03-31', 'Instagram', 'Haircare Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(742, 'Onkar Vig', 'aradhyasachdev@deshmukh.net', '+917497511014', '+919366353557', 'Boase-Talwar', 'pd1632IZ82', 'Indiranagar', '1982-10-31', '2018-10-22', 'Facebook', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(743, 'Shlok Raju', 'rajagopalantanya@hotmail.com', '0454686097', '+912397865294', 'Choudhary-Bhatt', 'BR5196Ag21', 'HSR Layout', '1987-11-04', '2018-02-18', 'Walk-in', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(744, 'Aayush Shenoy', 'hazelyogi@loyal-lala.org', '+910665506580', '+915495367614', 'Madan Ltd', 'YV9319Ts61', 'Koramangala', '2004-04-13', '2022-01-13', 'Instagram', 'Hex Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(745, 'Samarth Seshadri', 'drishya40@yahoo.com', '+917538992968', '6990438747', 'Kamdar-Butala', 'ub3601Wd25', 'RT Nagar', '2004-02-09', '2020-12-04', 'Walk-in', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(746, 'Prisha Raval', 'jayan43@gmail.com', '06121430133', '+910599792549', 'Vohra and Sons', 'Za7493GO86', 'HSR Layout', '2004-03-05', '2016-09-15', 'Facebook', 'Dairy Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(747, 'Taran Dhawan', 'tkaran@hotmail.com', '+917550491936', '1675622324', 'Lalla, Handa and Kala', 'fx1668Lr65', 'Rajajinagar', '2005-12-07', '2020-10-16', 'Facebook', 'Battery  & Charging', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(748, 'Adah Mangat', 'zkoshy@yahoo.com', '08625979289', '06603403019', 'Ramakrishnan-Loke', 'Ro7041MU34', 'Koramangala', '1971-11-14', '2022-07-14', 'Google', 'Birthday Parties', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(749, 'Ojas Chanda', 'chandapriyansh@gmail.com', '05021322421', '01934505280', 'Brahmbhatt Ltd', 'Sp4358bX46', 'Basavanagudi', '1984-12-27', '2024-10-19', 'Instagram', 'Birthday Parties', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(750, 'Rhea Tripathi', 'misharajan@banik-sant.biz', '9745612425', '7256608186', 'Kar PLC', 'PR8571hU23', 'Indiranagar', '2005-01-29', '2022-06-07', 'Facebook', 'Yoga', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(751, 'Adah Aggarwal', 'priyansh92@yahoo.com', '+914982391143', '06200279238', 'Shah, D’Alia and Chadha', 'FP9168zF49', 'Rajajinagar', '1978-02-07', '2022-01-13', 'Walk-in', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(752, 'Raghav Mammen', 'rajuishita@chaudhuri.biz', '02226275180', '2625865953', 'Roy, Ratti and Deol', 'Jc2051ZP94', 'Basavanagudi', '2000-01-12', '2017-01-09', 'Facebook', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(753, 'Vivaan Mani', 'prishakuruvilla@deol.net', '4568277738', '09997065185', 'Madan-Buch', 'Jw2042HN01', 'RT Nagar', '1965-12-11', '2017-12-15', 'Google', 'Dairy Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(754, 'Samarth Handa', 'gatik51@yahoo.com', '6138273462', '09655846729', 'Sule Group', 'Aw0292jz40', 'Basavanagudi', '2006-04-01', '2015-10-25', 'Walk-in', 'ERP', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(755, 'Mamooty Chad', 'lavanya63@sagar-dhar.com', '09611196065', '06545338410', 'Goswami, Sen and Buch', 'hW5957Dj01', 'Marathahalli', '1994-06-11', '2019-01-25', 'Instagram', 'Photography & Videographers', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(756, 'Ojas Dhillon', 'usabharwal@yahoo.com', '+911285143406', '01919476849', 'Choudhary Ltd', 'eB9869Gx12', 'Yelahanka', '2006-05-02', '2021-06-08', 'Facebook', 'Birthday Parties', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(757, 'Vivaan Bahri', 'kapurivan@hotmail.com', '03163502076', '+917697415768', 'Anne and Sons', 'yM4543CC09', 'Rajajinagar', '1993-02-27', '2021-09-23', 'Google', 'Hair Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(758, 'Misha Mannan', 'raunakvirk@yahoo.com', '06721372921', '+910951536049', 'Chander, Dey and Bir', 'TU3234gU57', 'Indiranagar', '1981-01-24', '2024-02-08', 'Walk-in', 'Cakes & Chocolates', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(759, 'Shamik Yogi', 'ladriya@yahoo.com', '5960066273', '06379186861', 'Sami-Lal', 'xV1012Em89', 'RT Nagar', '1970-06-27', '2017-02-23', 'Google', 'Birthday Parties', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(760, 'Seher Kapoor', 'zainadoshi@hotmail.com', '+918769171204', '4036990540', 'Chander LLC', 'xC3567XJ98', 'Electronic City', '2000-04-24', '2021-11-15', 'Google', 'CRM', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(761, 'Mamooty Sami', 'ngaba@yahoo.com', '09874329108', '+911255593439', 'Srivastava, Sanghvi and Soni', 'iu8832Lo49', 'Hebbal', '1997-07-06', '2023-01-12', 'Google', 'Massage & Body Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(762, 'Rania Atwal', 'dubeysumer@sahni.com', '+915909691105', '+913333019963', 'Kadakia, Vala and Mane', 'Wo9370UP81', 'Indiranagar', '1992-03-10', '2021-06-26', 'Walk-in', 'Flat Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(763, 'Shayak Dara', 'deshmukhindrajit@biswas-rajan.com', '+916364551560', '+916175613136', 'Salvi, Dewan and Ravel', 'Ad6307gn03', 'Indiranagar', '2004-03-18', '2022-02-21', 'Instagram', 'CRM', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(764, 'Rasha Sidhu', 'ranbir92@uppal.com', '+911231747275', '03853606637', 'Venkataraman-Setty', 'GB2192pf98', 'Electronic City', '1995-10-13', '2021-02-24', 'Facebook', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(765, 'Kartik Bal', 'kdevan@hotmail.com', '9228888041', '08144273340', 'Anne, Ramesh and Mangat', 'eC0540WI65', 'Jayanagar', '1980-11-02', '2021-03-29', 'Walk-in', 'Battery  & Charging', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(766, 'Kabir Balakrishnan', 'renee97@yahoo.com', '+912413901583', '+914093131959', 'Dubey-Issac', 'IU9169si91', 'Jayanagar', '1983-03-27', '2015-11-25', 'Instagram', 'ERP', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(767, 'Mahika Raman', 'zsaha@yahoo.com', '08837622884', '09481489385', 'Khurana, Randhawa and Talwar', 'DX3402Tr90', 'Rajajinagar', '1969-04-19', '2022-11-01', 'Instagram', 'CRM', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(768, 'Rhea Comar', 'anahibhat@hotmail.com', '1202414560', '09932133693', 'Ratti, Bhasin and Aggarwal', 'li2505JJ14', 'Malleshwaram', '1983-05-23', '2022-06-05', 'Google', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(769, 'Advik Kibe', 'jayesh62@yahoo.com', '07828995057', '1532155203', 'Sandhu-Ram', 'Wg0875tW92', 'Basavanagudi', '1980-05-17', '2021-02-14', 'Google', 'Dairy Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(770, 'Piya Bahri', 'tlal@sen-kannan.com', '+918226654900', '08150209748', 'Shetty LLC', 'ip8194ON20', 'Basavanagudi', '2003-08-09', '2025-04-25', 'Facebook', 'Birthday Parties', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(771, 'Tanya Behl', 'tanya86@soman.com', '6726178351', '2592070259', 'Kalita, Borra and Bose', 'IO8907LT79', 'Hebbal', '1976-10-08', '2024-05-09', 'Instagram', 'Photography & Videographers', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(772, 'Divit Srivastava', 'gsodhi@yahoo.com', '03172068082', '7390656512', 'Choudhary, Ramanathan and Anand', 'BM7887va25', 'Whitefield', '2007-04-27', '2015-09-27', 'Walk-in', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(773, 'Nishith Agrawal', 'yasmin91@deshpande.com', '04959152203', '05332837249', 'Master, Hayre and Kaur', 'vp9155Kv79', 'Hebbal', '1965-09-15', '2022-11-03', 'Facebook', 'CRM', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(774, 'Myra Barad', 'buchaayush@hotmail.com', '+910837549073', '+914537674318', 'Bail, Ghosh and Konda', 'sR1443EZ65', 'Rajajinagar', '1970-10-24', '2022-08-01', 'Facebook', 'Haircare Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(775, 'Dhanuk Manda', 'venkateshtushar@hotmail.com', '06264475340', '1627716433', 'Raj Inc', 'yZ8942DJ06', 'Banashankari', '1972-10-30', '2024-11-02', 'Google', 'Cakes & Chocolates', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(776, 'Navya Bhavsar', 'sana87@gmail.com', '05122051989', '07536023118', 'D’Alia Group', 'JC1724el98', 'Jayanagar', '1999-10-17', '2022-04-01', 'Google', 'CRM', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(777, 'Bhavin Dora', 'ramachandrantaimur@anne-ray.org', '+916299674515', '1402460081', 'Chada-Mangal', 'vL1811Xl30', 'Banashankari', '1981-04-15', '2024-08-14', 'Instagram', 'Deep Cleaning Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(778, 'Anaya Anand', 'manikyawable@yahoo.com', '6897693653', '7383458086', 'Vig, Sachdeva and Reddy', 'Ic8198DQ23', 'Malleshwaram', '2002-10-14', '2024-09-27', 'Facebook', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(779, 'Oorja Buch', 'stuvanbahri@yahoo.com', '2253954411', '03208061161', 'Borah and Sons', 'kB5766jF06', 'Basavanagudi', '1995-07-31', '2015-07-14', 'Google', 'Flat Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(780, 'Ayesha Desai', 'kanne@yahoo.com', '8829369536', '00162255912', 'Sen, Kamdar and Shukla', 'rD0364Tj74', 'Malleshwaram', '1982-12-16', '2021-12-17', 'Walk-in', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(781, 'Mehul Wason', 'ivanbhardwaj@hotmail.com', '05716622784', '+915955400650', 'Brar-Mall', 'CQ6892JN67', 'BTM Layout', '2006-11-20', '2025-01-23', 'Facebook', 'Software Maintenance', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(782, 'Shlok Gade', 'karshlok@deshpande.com', '+915439154905', '01942661308', 'Korpal, Divan and Bail', 'jP7618Zr05', 'Banashankari', '1968-10-22', '2016-06-22', 'Google', 'Flat Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(783, 'Ivan Badal', 'sarnaayesha@yahoo.com', '+914951369709', '+917405621862', 'Das, Kashyap and Bala', 'Jg3388Mi17', 'BTM Layout', '2004-12-15', '2019-08-24', 'Google', 'Photography & Videographers', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(784, 'Ojas Vig', 'neysasama@ahuja.com', '9203130010', '05837431692', 'Yohannan-Hora', 'rH8690jx47', 'Electronic City', '1992-04-19', '2023-04-12', 'Facebook', 'Software Maintenance', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(785, 'Jayesh Khalsa', 'semamira@hotmail.com', '+913925744196', '+918087328360', 'Karan LLC', 'wo9184GA21', 'Marathahalli', '1967-01-02', '2022-07-24', 'Google', 'Deep Cleaning Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(786, 'Amira Srinivasan', 'kuriantejas@sami-ahluwalia.info', '+910743757702', '04480280714', 'Chahal, Agrawal and Bhagat', 'us7001IZ71', 'Electronic City', '1978-08-19', '2021-12-06', 'Instagram', 'Massage & Body Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(787, 'Navya Mangal', 'heerbarad@wason.net', '8966638365', '+913528740733', 'Sampath-Lanka', 'nz4753hr53', 'Indiranagar', '1972-12-28', '2020-09-22', 'Walk-in', 'Cakes & Chocolates', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(788, 'Nakul Edwin', 'divijyogi@sengupta.com', '+919725333628', '08511547428', 'Tandon, Kannan and Loyal', 'aA8891dY51', 'Whitefield', '1977-02-06', '2018-05-26', 'Walk-in', 'Software Maintenance', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(789, 'Advika Bassi', 'aniruddhdhawan@gmail.com', '+916190840062', '01202615453', 'Choudhury, Bajaj and Jha', 'QF2417gv17', 'BTM Layout', '1996-07-23', '2023-06-06', 'Facebook', 'Birthday Parties', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(790, 'Mishti Andra', 'eshani96@johal-ramaswamy.info', '08144406631', '+913111316022', 'Bhatia-Saha', 'pt5092bo14', 'Whitefield', '2005-12-24', '2019-09-24', 'Walk-in', 'Yoga', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(791, 'Yuvaan Lala', 'dhanushkant@halder.org', '+914459828574', '08661942074', 'Saraf and Sons', 'wc2135Bb22', 'Hebbal', '1977-08-31', '2016-05-14', 'Google', 'Dairy Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(792, 'Ivana Malhotra', 'bandizain@rao.net', '0351241569', '2461349364', 'Sani-Ramachandran', 'gu6034sV47', 'Rajajinagar', '2002-06-26', '2022-11-12', 'Google', 'Yoga', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(793, 'Neysa D’Alia', 'priyansh26@de.com', '3888771782', '+916284149406', 'Ranganathan, Bhat and Iyengar', 'RV0251yX79', 'Marathahalli', '1973-12-23', '2017-11-17', 'Facebook', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(794, 'Misha Dutt', 'rattiriya@hari.com', '+912617001378', '4253401874', 'Chaudhari-Bava', 'KY4566oN65', 'Yelahanka', '1999-09-15', '2019-05-27', 'Walk-in', 'Yoga', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(795, 'Uthkarsh Sagar', 'pdhillon@apte.info', '+919847204656', '3921201971', 'Shere, Samra and Gopal', 'kl7161HV54', 'BTM Layout', '1991-06-27', '2018-08-03', 'Instagram', 'Flat Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(796, 'Amani Lad', 'yuvraj-66@yahoo.com', '+914461969081', '09366757943', 'Handa PLC', 'kh2528md02', 'Marathahalli', '1980-05-24', '2020-07-18', 'Facebook', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(797, 'Azad Ramakrishnan', 'tiwarianya@gmail.com', '08765009704', '2477483138', 'Sankaran, Bora and Kannan', 'OO7511xm22', 'Malleshwaram', '1974-11-06', '2022-02-07', 'Facebook', 'Battery  & Charging', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(798, 'Trisha Koshy', 'yuvaanbhavsar@hotmail.com', '03853415017', '9797317014', 'Devi LLC', 'aj7741MK03', 'RT Nagar', '1967-08-18', '2015-10-10', 'Walk-in', 'Software Maintenance', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(799, 'Fateh Acharya', 'aarnabehl@yahoo.com', '1831306126', '+911112672589', 'Chowdhury-Kapoor', 'Eo7854xN60', 'Hebbal', '1968-02-07', '2019-05-13', 'Facebook', 'Hex Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(800, 'Tara Yohannan', 'batraindrajit@dhillon.org', '+912442250978', '1056430550', 'Date, Kant and Bhatnagar', 'SP2863cI67', 'Marathahalli', '2000-04-14', '2024-01-04', 'Instagram', 'Flat Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(801, 'Prerak Jaggi', 'qkala@hotmail.com', '+916067115666', '+914652902420', 'Bedi Ltd', 'UO1071fn40', 'HSR Layout', '1983-07-02', '2015-06-10', 'Walk-in', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(802, 'Rohan Badami', 'aainachada@sahota.info', '5098926191', '0853877806', 'Khatri-Borde', 'qV4641ez18', 'Electronic City', '1998-09-19', '2022-12-02', 'Google', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(803, 'Sara Mane', 'dsabharwal@gmail.com', '+919999068974', '02479215367', 'Dhaliwal, Borde and Devan', 'ZV7412NQ43', 'Basavanagudi', '1981-06-12', '2024-11-02', 'Walk-in', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(804, 'Aradhya Vora', 'umangkade@gmail.com', '03200480895', '+911383759335', 'Swaminathan-Gupta', 'Qu6370MW25', 'Rajajinagar', '2003-03-22', '2020-11-10', 'Google', 'Birthday Parties', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(805, 'Advik Sinha', 'nayantaraverma@datta.com', '00598317435', '07769731064', 'Srivastava-Arya', 'hc6223Bb74', 'Yelahanka', '1973-02-15', '2016-05-13', 'Facebook', 'Birthday Parties', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(806, 'Anvi Khosla', 'csood@hotmail.com', '8751144590', '04687907935', 'Ram, Bora and Lad', 'oh3193Br38', 'HSR Layout', '1981-10-21', '2025-02-27', 'Instagram', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(807, 'Ahana  Dass', 'dishani93@boase-kuruvilla.info', '03462073502', '06463237485', 'Kala, Konda and Grewal', 'IQ7766Mo43', 'Rajajinagar', '2003-10-16', '2018-01-18', 'Google', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(808, 'Khushi Dhar', 'yramakrishnan@srivastava.com', '+919470519241', '5091498430', 'Kibe, Salvi and Ramakrishnan', 'zw5981MQ51', 'Indiranagar', '1997-07-12', '2017-09-12', 'Instagram', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(809, 'Alisha Wason', 'indranil89@gmail.com', '03321516029', '7915146382', 'Shanker, Dara and Jhaveri', 'Nz3318JP97', 'RT Nagar', '1981-03-04', '2019-11-28', 'Walk-in', 'Hex Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(810, 'Vihaan Bora', 'jayantsuresh@hotmail.com', '+910765025119', '00533649597', 'Acharya, Bava and Savant', 'zs1303Ga69', 'Electronic City', '1990-01-02', '2025-02-13', 'Google', 'ERP', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(811, 'Tejas Kanda', 'hunarbarad@gmail.com', '5891322040', '+910232043961', 'Lala-Bail', 'tJ2283LB35', 'HSR Layout', '1975-02-03', '2018-08-19', 'Facebook', 'Dairy Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(812, 'Dhruv Lad', 'bhavinraja@sethi.com', '09898435368', '04060843397', 'Kadakia-Virk', 'qs2602TN50', 'Koramangala', '1980-06-10', '2022-09-03', 'Facebook', 'Flat Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(813, 'Advik Sarkar', 'sastryvedika@yahoo.com', '8832019540', '+918742325086', 'Dubey-Reddy', 'cw7835dr43', 'BTM Layout', '1966-09-10', '2024-02-01', 'Instagram', 'Deep Cleaning Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(814, 'Kimaya Ramaswamy', 'kavya30@gmail.com', '0636646280', '06397025049', 'Jayaraman, Ramesh and Kurian', 'lP3049Fc03', 'Malleshwaram', '1984-05-02', '2021-02-24', 'Instagram', 'Hex Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(815, 'Aradhya Randhawa', 'zeeshan00@hotmail.com', '+914981267022', '09811178668', 'Bahri, Raju and Dhawan', 'xp4159ON85', 'Malleshwaram', '1965-07-20', '2019-01-24', 'Facebook', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(816, 'Lagan Dhawan', 'onkarzachariah@hotmail.com', '07934695926', '+917926260551', 'Amble Ltd', 'Ni4729do17', 'HSR Layout', '1984-05-26', '2025-04-27', 'Facebook', 'CRM', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(817, 'Diya Amble', 'dkurian@gmail.com', '8861162978', '08421069503', 'Rajagopal-Balasubramanian', 'nA2265On97', 'Electronic City', '2005-03-04', '2023-01-30', 'Walk-in', 'Haircare Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(818, 'Gatik Khanna', 'jayandubey@ram.biz', '+919598616953', '04768854970', 'Kannan PLC', 'oX2511KK93', 'Electronic City', '1970-01-29', '2015-08-27', 'Walk-in', 'Software Maintenance', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(819, 'Gatik Gopal', 'sara88@gade.com', '+910771463204', '+916607552534', 'Lall, Chaudry and Varghese', 'NV6271Na59', 'Marathahalli', '2004-06-30', '2017-02-13', 'Google', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(820, 'Tara Setty', 'echawla@ravel-sarin.net', '+916592320812', '+910010638264', 'Bumb Group', 'vg0858VM97', 'Electronic City', '1998-07-04', '2021-10-16', 'Google', 'Hair Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(821, 'Anay Bora', 'sumer78@hotmail.com', '+918875325878', '5379099431', 'Datta Inc', 'un6011Bb38', 'Indiranagar', '1996-04-09', '2018-02-17', 'Facebook', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(822, 'Mehul Bala', 'wmani@hotmail.com', '9741372949', '04155295299', 'Banerjee, Mahajan and Babu', 'UM4257Db21', 'HSR Layout', '1995-02-02', '2018-09-15', 'Instagram', 'CRM', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(823, 'Aradhya Krishnamurthy', 'sherearnav@garg.com', '+917470443707', '+915646271535', 'Talwar-Sengupta', 'pk9085xq10', 'Hebbal', '1964-11-16', '2016-08-14', 'Facebook', 'Dairy Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(824, 'Advika Basak', 'qhayer@gupta-wali.org', '+918170927203', '+917485512446', 'Cheema Ltd', 'Bh8462vn34', 'Marathahalli', '2007-04-18', '2017-12-12', 'Facebook', 'Massage & Body Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(825, 'Fateh Sastry', 'vravel@hotmail.com', '06691968942', '01960949001', 'Sinha Group', 'gR9716sz97', 'Electronic City', '1979-09-02', '2016-10-31', 'Instagram', 'Flat Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(826, 'Misha Keer', 'ksom@ratta-wagle.com', '+911703082786', '+915969674598', 'Agarwal Group', 'jo9274Tr24', 'Malleshwaram', '1995-10-13', '2022-05-26', 'Facebook', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(827, 'Advik Lanka', 'biju47@hotmail.com', '05604913312', '2529299297', 'Verma-Arora', 'Kc3342CU29', 'Yelahanka', '1993-09-12', '2022-01-01', 'Instagram', 'Yoga', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(828, 'Shlok Bhalla', 'tkala@hotmail.com', '+914934764534', '8305290684', 'Dyal and Sons', 'Uj5694Hd67', 'Rajajinagar', '1972-10-05', '2016-01-26', 'Google', 'Dairy Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(829, 'Suhana Trivedi', 'ichandra@gmail.com', '+916327134903', '2500837971', 'Jain, Bhatti and Dyal', 'fz1859nm09', 'Indiranagar', '1996-07-14', '2020-08-30', 'Walk-in', 'Software Maintenance', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(830, 'Saira Dara', 'samihakala@ghose.com', '+911115172807', '9272435009', 'Loke LLC', 'eg7270Iw42', 'BTM Layout', '1976-02-29', '2019-07-27', 'Walk-in', 'Flat Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(831, 'Kavya Balan', 'qratta@sekhon.com', '3673125838', '1224057807', 'Ganesh Inc', 'Kt4579Sc93', 'Hebbal', '2002-05-15', '2020-06-30', 'Walk-in', 'Cakes & Chocolates', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(832, 'Vidur Raval', 'dhruv55@sawhney-lall.info', '0074995135', '4527766410', 'Agrawal Ltd', 'Sw4215Rm29', 'RT Nagar', '1974-01-23', '2021-12-14', 'Walk-in', 'Flat Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(833, 'Advik Bahl', 'indranilvenkataraman@goda.biz', '+914621499618', '06965889014', 'Krish, Kade and Kar', 'oK0733rI65', 'Whitefield', '1967-12-19', '2018-04-29', 'Instagram', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(834, 'Darshit Das', 'yreddy@loyal.com', '04076768391', '2999215313', 'Kar-Sawhney', 'iE6665ii43', 'Koramangala', '1971-03-10', '2021-12-26', 'Instagram', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(835, 'Renee Dhaliwal', 'kulkarnizain@hotmail.com', '9838603986', '00668979088', 'Swaminathan-Varughese', 'VJ1244rf27', 'RT Nagar', '1983-05-11', '2017-04-04', 'Facebook', 'Haircare Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(836, 'Kaira Venkatesh', 'ideo@jha-ramachandran.com', '+911794002247', '03856324844', 'Kanda, Bhatnagar and Loke', 'Uw1195ql57', 'Hebbal', '2004-09-13', '2019-06-20', 'Google', 'Yoga', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0);
INSERT INTO `leads_master` (`id`, `name`, `email`, `mobile`, `another_mobile`, `company`, `gst`, `location`, `dob`, `anniversary`, `source`, `looking_for`, `status`, `created_at`, `updated_at`, `is_deleted`) VALUES
(837, 'Priyansh Yadav', 'sedwin@varkey.net', '8971951289', '+910656237365', 'Kapadia-Sekhon', 'Bb9912lx44', 'HSR Layout', '1995-08-02', '2019-01-21', 'Instagram', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(838, 'Gatik Ghosh', 'anyaswamy@hotmail.com', '4838429837', '07073426264', 'Shan Inc', 'uD3518yv30', 'Malleshwaram', '1985-07-08', '2023-11-02', 'Google', 'Software Maintenance', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(839, 'Vedika Dubey', 'kannanjayant@yahoo.com', '2790760954', '+916839031228', 'Gour PLC', 'UD3302Xn00', 'RT Nagar', '1984-10-30', '2021-05-04', 'Walk-in', 'Yoga', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(840, 'Onkar Bhattacharyya', 'qlall@yahoo.com', '07436895056', '+911138588573', 'Khanna, Singhal and Lalla', 'av5392fV90', 'Basavanagudi', '1981-06-15', '2016-11-19', 'Walk-in', 'Haircare Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(841, 'Adira Viswanathan', 'navya10@hotmail.com', '08510153200', '00516083298', 'Bora-Chaudhari', 'BP5953oZ99', 'Yelahanka', '2003-06-15', '2015-06-28', 'Instagram', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(842, 'Heer Sidhu', 'tooraarav@yahoo.com', '0417016944', '07766660632', 'Mahajan-Krishnamurthy', 'VG7877oR10', 'Hebbal', '1976-10-01', '2021-07-24', 'Walk-in', 'Massage & Body Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(843, 'Kartik Iyer', 'elakshi55@jayaraman.net', '08433915642', '0590947567', 'Garde and Sons', 'QI0091tD74', 'HSR Layout', '1999-10-28', '2019-10-25', 'Instagram', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(844, 'Nakul Dora', 'qkrishnamurthy@divan-magar.biz', '08820269427', '7916058386', 'Varma-Luthra', 'Tm7832CN42', 'Banashankari', '1981-11-26', '2017-02-22', 'Facebook', 'Dairy Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(845, 'Adira Mangal', 'jaindarshit@chaudhary-wali.com', '+912341465525', '8412559540', 'Mandal-Desai', 'XV1969sO14', 'Rajajinagar', '2007-01-20', '2021-08-02', 'Instagram', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(846, 'Shaan Ganesh', 'khannatiya@yahoo.com', '2210106965', '04304552715', 'Swamy LLC', 'QV5978sh05', 'Rajajinagar', '2007-01-09', '2020-04-17', 'Instagram', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(847, 'Kartik Konda', 'chakrabortytaran@dewan.com', '07126353627', '7672054182', 'Sagar Ltd', 'yS6161ka68', 'RT Nagar', '1981-07-08', '2023-01-05', 'Instagram', 'Yoga', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(848, 'Rania Sundaram', 'emir88@sarkar.com', '+911913252564', '+916124155975', 'Sehgal-Apte', 'yq9882bh18', 'Jayanagar', '2001-03-17', '2016-10-14', 'Google', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(849, 'Yuvraj  Banik', 'akapoor@gmail.com', '+913325112467', '04159996216', 'Yadav, Dora and Raj', 'XK2057Xt24', 'Marathahalli', '1995-05-07', '2024-04-15', 'Facebook', 'Battery  & Charging', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(850, 'Rati Dayal', 'kalashalv@yahoo.com', '8297115420', '+910101143343', 'Singhal, Jaggi and Kar', 'UU5093nG79', 'Basavanagudi', '1991-09-29', '2024-06-30', 'Instagram', 'Dairy Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(851, 'Charvi Varghese', 'adira12@hotmail.com', '+912012278283', '3718269627', 'Venkataraman PLC', 'Yz7148XN36', 'Whitefield', '2004-04-06', '2019-09-08', 'Facebook', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(852, 'Dhanush Vohra', 'ryan78@gmail.com', '+910349111091', '0235409447', 'Bava and Sons', 'Ra9744JI66', 'BTM Layout', '1996-04-02', '2019-06-06', 'Walk-in', 'Photography & Videographers', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(853, 'Jhanvi Varkey', 'kismat70@bandi-kala.biz', '6972387832', '+911660362876', 'Tak-Mahal', 'hE0196IT18', 'Indiranagar', '1977-05-06', '2024-12-14', 'Facebook', 'Hex Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(854, 'Divyansh Hans', 'gatikbasak@hotmail.com', '6345585432', '03694643712', 'Din-Dalal', 'wD2413Cu84', 'Electronic City', '1978-01-15', '2018-05-26', 'Google', 'Hair Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(855, 'Abram Goel', 'nayantaratoor@chatterjee.com', '+910397178793', '06596981147', 'Lall Ltd', 'Yo5966DJ76', 'BTM Layout', '1984-11-28', '2023-06-25', 'Walk-in', 'Hex Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(856, 'Renee Agrawal', 'badal99@deep-ratta.com', '7468458130', '07483675055', 'Cheema LLC', 'dZ5606Ww41', 'Hebbal', '1967-04-08', '2024-11-29', 'Google', 'Deep Cleaning Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(857, 'Raunak Bhatti', 'tusharswaminathan@gmail.com', '+913715813090', '9009677193', 'Ravel, Choudhury and Chad', 'Sb1766PZ42', 'Malleshwaram', '1987-08-12', '2023-07-15', 'Walk-in', 'Cakes & Chocolates', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(858, 'Romil Gour', 'ykota@gmail.com', '07321810842', '0332846153', 'Kakar, Verma and Badal', 'Ap2997Ej62', 'Banashankari', '1994-06-12', '2016-05-30', 'Walk-in', 'Haircare Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(859, 'Arnav Kant', 'sahil13@hotmail.com', '09349143375', '09150053979', 'Walia Inc', 'hS8328kS57', 'HSR Layout', '1971-04-17', '2025-01-09', 'Facebook', 'Flat Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(860, 'Advik Gara', 'yasminwali@gmail.com', '8018523544', '1078046011', 'Rau, Contractor and Saini', 'Nq2281TI26', 'Indiranagar', '1991-05-18', '2022-12-20', 'Walk-in', 'Software Maintenance', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(861, 'Nishith Madan', 'babudhruv@sehgal.net', '7234408539', '5909586272', 'Gandhi-Handa', 'HT9372JK71', 'BTM Layout', '1995-09-27', '2016-08-10', 'Walk-in', 'Haircare Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(862, 'Sana Chowdhury', 'sridharsamarth@saraf.com', '+911559644107', '+913973944479', 'Bahl, Kara and Sandal', 'qD7163wH06', 'Hebbal', '1996-11-15', '2015-11-28', 'Instagram', 'Massage & Body Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(863, 'Anahi Sankaran', 'bhattadira@gmail.com', '04841661722', '5288830834', 'Salvi, Kaur and Kale', 'AO6336fu83', 'RT Nagar', '1999-08-08', '2022-09-21', 'Facebook', 'ERP', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(864, 'Arhaan Mannan', 'tarankhatri@kala.com', '+919002698620', '+919899706991', 'Toor-D’Alia', 'Xz7957RJ90', 'Hebbal', '2000-12-09', '2019-07-04', 'Facebook', 'Birthday Parties', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(865, 'Ranbir Trivedi', 'kumarparinaaz@sha.com', '1496522198', '2621513328', 'Behl, Aggarwal and Keer', 'Oq3126hX03', 'BTM Layout', '1989-04-30', '2015-06-27', 'Facebook', 'Cakes & Chocolates', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(866, 'Neysa Ram', 'purabbhavsar@gmail.com', '3327821999', '6896809839', 'Dash, Iyer and Joshi', 'UD2752zW00', 'RT Nagar', '1980-01-22', '2018-09-27', 'Walk-in', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(867, 'Sumer Hayre', 'seher47@din.com', '7689931332', '02217814184', 'Bora-Seth', 'IL1820wT10', 'RT Nagar', '1983-06-26', '2017-03-17', 'Instagram', 'Software Maintenance', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(868, 'Samiha Gokhale', 'krishdeol@gaba.com', '+915208439626', '7377670646', 'Tripathi-Amble', 'MM4314vz34', 'Yelahanka', '1973-05-12', '2024-10-12', 'Walk-in', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(869, 'Sara Sane', 'gokulghose@tailor.info', '+913135433288', '01954651575', 'Vig-Manne', 'aN8535ae07', 'Koramangala', '1972-10-02', '2017-10-23', 'Instagram', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(870, 'Priyansh Dugal', 'evora@gmail.com', '+915843602553', '09977978949', 'Varghese, Mann and Devi', 'rZ7967aI34', 'Banashankari', '1968-06-24', '2018-05-22', 'Instagram', 'Dairy Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(871, 'Aaina Jain', 'madanakarsh@mander.org', '5067874888', '+917805550332', 'Karnik-Buch', 'Ea2649Xz21', 'Whitefield', '1964-07-05', '2016-01-21', 'Walk-in', 'Hair Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(872, 'Heer Bath', 'mchoudhary@yahoo.com', '6540992681', '+915428431682', 'Sha-Vasa', 'fG2760Ru31', 'Whitefield', '1976-06-05', '2023-02-27', 'Instagram', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(873, 'Rhea Mangal', 'arhaanbajwa@hotmail.com', '04281504127', '0997400094', 'Dube-Lal', 'jA8251gf65', 'Rajajinagar', '1967-03-16', '2015-12-15', 'Instagram', 'Hex Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(874, 'Sumer Chacko', 'miraan93@yahoo.com', '+916123931124', '2142822476', 'Guha Group', 'VD6535Uo40', 'BTM Layout', '1986-11-11', '2017-02-06', 'Facebook', 'Yoga', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(875, 'Zoya Jaggi', 'anahitatandon@gmail.com', '+910582130090', '04614134526', 'Thakkar Inc', 'aR8231Ak81', 'Koramangala', '1980-10-20', '2016-03-20', 'Instagram', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(876, 'Hazel Magar', 'kavya38@gmail.com', '9953454511', '8419557492', 'Vohra, Seshadri and Khurana', 'MH3622gX20', 'Koramangala', '1999-04-06', '2023-12-01', 'Google', 'Haircare Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(877, 'Ivana Chaudhary', 'skoshy@hotmail.com', '04161468839', '1823812564', 'Subramanian PLC', 'lw9956bs11', 'HSR Layout', '1983-07-10', '2016-03-29', 'Walk-in', 'Haircare Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(878, 'Rasha Sodhi', 'chhabramadhav@hotmail.com', '+915437695981', '5371178492', 'Soman, Raja and Shukla', 'vj6554FK83', 'Yelahanka', '1974-08-06', '2015-12-18', 'Google', 'Flat Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(879, 'Badal Garg', 'xshukla@yahoo.com', '1648035811', '08884091972', 'Cherian, Chandran and Bakshi', 'Dq7879PA11', 'HSR Layout', '1966-07-29', '2017-07-28', 'Instagram', 'Hair Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(880, 'Yasmin Sandhu', 'advik72@yahoo.com', '+917989476191', '9983502975', 'Bhattacharyya-Sami', 'lR2028VI42', 'Jayanagar', '1977-01-23', '2021-06-04', 'Walk-in', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(881, 'Trisha Golla', 'jhanvikant@ghosh-sem.com', '4389331159', '09558350635', 'Saraf-Kakar', 'Yj9569nf72', 'HSR Layout', '1998-02-05', '2018-07-20', 'Instagram', 'Massage & Body Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(882, 'Abram Zachariah', 'shanayagopal@desai.org', '2168546392', '+914726639227', 'Devi-Aggarwal', 'zn9402YY37', 'Indiranagar', '1994-06-21', '2022-03-02', 'Google', 'Birthday Parties', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(883, 'Bhavin Chakraborty', 'sdeep@gmail.com', '03528784382', '+918798603712', 'Warrior, Shere and Suresh', 'Xk4564sH04', 'Marathahalli', '1966-11-20', '2023-03-08', 'Instagram', 'Flat Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(884, 'Miraan Sant', 'khuranaritvik@dara.info', '6557260755', '+912965370184', 'Gour, Hans and Sawhney', 'gy8599gJ87', 'Electronic City', '1998-05-07', '2020-10-03', 'Instagram', 'Hair Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(885, 'Anaya Bail', 'ivanamani@gour.com', '09986299000', '03626588921', 'Bava-Bhattacharyya', 'yL7046eM42', 'HSR Layout', '1971-08-30', '2022-03-30', 'Facebook', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(886, 'Dhanuk Warrior', 'borramehul@zacharia.info', '+912228058380', '07210030790', 'Ganesh, Dugar and Babu', 'Kf2669bx19', 'Basavanagudi', '1997-09-28', '2023-11-29', 'Walk-in', 'Flat Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(887, 'Ishaan Bali', 'tdugar@yahoo.com', '+911711379590', '6173169475', 'Bajaj-Balakrishnan', 'Cx5116zl30', 'BTM Layout', '1975-06-04', '2016-02-14', 'Facebook', 'CRM', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(888, 'Kimaya Kurian', 'anahita63@bedi-kakar.com', '06731032357', '+915965313764', 'Datta, Sharaf and Thakur', 'NT5541oP54', 'HSR Layout', '1970-03-15', '2020-04-19', 'Instagram', 'ERP', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(889, 'Rasha Deol', 'darshit58@hotmail.com', '08230969441', '+910681275129', 'Deshpande-Raja', 'aT5809eo95', 'Koramangala', '1997-11-12', '2017-09-04', 'Instagram', 'Dairy Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(890, 'Khushi Shenoy', 'rajagopalnitya@hotmail.com', '7411739445', '+913448532551', 'Ramakrishnan Group', 'wn5473MW38', 'Banashankari', '1999-12-05', '2019-06-16', 'Instagram', 'Software Maintenance', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(891, 'Prisha Rao', 'savantsara@rau-jha.com', '9947833049', '08608908326', 'Balay, Deol and Shah', 'oq6274LI63', 'BTM Layout', '1971-10-19', '2016-01-08', 'Walk-in', 'Hair Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(892, 'Badal Kaul', 'rheasura@hotmail.com', '+912852087413', '01481379720', 'Babu, Sathe and Deshmukh', 'Lu3991xO06', 'Yelahanka', '2006-04-15', '2015-11-20', 'Instagram', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(893, 'Nitara Choudhury', 'shraytara@yogi-goswami.org', '+913567911955', '2088150834', 'Sangha Inc', 'Cz8864fJ14', 'HSR Layout', '1981-11-15', '2025-02-23', 'Facebook', 'Deep Cleaning Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(894, 'Eva Soni', 'warrioroorja@kata-andra.com', '2745403178', '6033234519', 'Kadakia, Mander and Shroff', 'vi0308Vo90', 'Yelahanka', '1970-07-09', '2019-05-06', 'Facebook', 'Battery  & Charging', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(895, 'Zaina Virk', 'balasubramanianshanaya@hotmail.com', '6981826184', '01246496143', 'Balan PLC', 'no2013Bk53', 'Yelahanka', '1970-09-22', '2019-05-28', 'Facebook', 'Hex Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(896, 'Sara Mani', 'jivika92@ratta.com', '02839110132', '+914331707800', 'Upadhyay Inc', 'tG8145LN46', 'Jayanagar', '1980-06-09', '2015-08-20', 'Instagram', 'Battery  & Charging', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(897, 'Adah Magar', 'manemanjari@barman-deo.com', '2981873978', '+910652762953', 'Grewal, Chada and Loke', 'KC8250KG61', 'Rajajinagar', '2003-05-15', '2015-12-24', 'Instagram', 'Birthday Parties', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(898, 'Kartik Comar', 'chadakabir@chakrabarti-majumdar.biz', '05061515353', '0347101321', 'Vig Ltd', 'oD3450tJ82', 'Whitefield', '2000-06-18', '2016-02-25', 'Instagram', 'Haircare Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(899, 'Tara Kakar', 'chirag07@kala.com', '03614387508', '+912542053307', 'Sachar-Keer', 'ao1758IB04', 'Hebbal', '1965-04-14', '2020-03-22', 'Google', 'Hair Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(900, 'Tanya Seshadri', 'tandonzara@ganesh-tara.biz', '+910602629157', '3462653183', 'Som, Bakshi and Chokshi', 'eQ2936Ex28', 'Basavanagudi', '1972-03-15', '2024-11-26', 'Instagram', 'Dairy Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(901, 'Jayesh Dash', 'hrishita12@hotmail.com', '+918302576753', '+917722413806', 'Reddy, Sinha and Date', 'NI3226dC86', 'Malleshwaram', '1981-06-30', '2016-06-13', 'Facebook', 'Software Maintenance', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(902, 'Urvi Agate', 'semkanav@srivastava-krishna.com', '9019810520', '+912027696672', 'Mahajan-Kulkarni', 'Gn3510Fp17', 'Koramangala', '2001-05-02', '2020-01-11', 'Instagram', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(903, 'Sara Soman', 'ramatejas@mangal.com', '6531621679', '+917287362778', 'Gaba, Sane and Setty', 'Ln6571Nc51', 'Hebbal', '2006-08-08', '2023-01-20', 'Google', 'Dairy Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(904, 'Elakshi Gulati', 'akarsh78@hotmail.com', '+912807946006', '+911383435844', 'Sankar, Badami and Upadhyay', 'tP0152Zg01', 'Koramangala', '1973-02-08', '2021-08-06', 'Instagram', 'Yoga', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(905, 'Aarush Banerjee', 'shereanya@gmail.com', '00568729559', '4389983519', 'Karpe Ltd', 'FP7545Ih42', 'Basavanagudi', '1964-09-14', '2021-08-26', 'Walk-in', 'Yoga', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(906, 'Onkar Sarma', 'raunakchahal@sahni.com', '04931452850', '+914981312059', 'Rama, Dewan and Samra', 'id9796Gt48', 'Rajajinagar', '1996-10-15', '2023-03-29', 'Instagram', 'Photography & Videographers', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(907, 'Pranay Mahajan', 'zgill@sethi.com', '03362768373', '09301871612', 'Ghosh PLC', 'mC2711ny36', 'Whitefield', '1995-06-18', '2019-01-04', 'Facebook', 'Deep Cleaning Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(908, 'Ivana De', 'madhav65@barman-bhalla.com', '07523561358', '+912418130114', 'Chand Group', 'Qn6087hv37', 'Indiranagar', '1984-05-26', '2020-06-02', 'Instagram', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(909, 'Pranay Khosla', 'rati02@hotmail.com', '+914361102258', '05030981848', 'Iyengar, Reddy and Chad', 'mb2988gA39', 'BTM Layout', '1992-07-20', '2018-01-11', 'Instagram', 'Cakes & Chocolates', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(910, 'Aarna Sarkar', 'vaibhavchawla@edwin-swaminathan.com', '2346808846', '3428662051', 'Maharaj, Sankar and Ahluwalia', 'sZ1736WU82', 'Yelahanka', '1996-05-02', '2021-03-01', 'Facebook', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(911, 'Darshit Kuruvilla', 'odar@gmail.com', '+910024632578', '0928733653', 'Rana, Dar and Tank', 'vu2942Yv41', 'Banashankari', '1981-04-09', '2025-04-08', 'Facebook', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(912, 'Vritika Vaidya', 'jayantbora@yahoo.com', '6622843344', '08692546261', 'Kale, Kakar and Barman', 'Ms3173Zx19', 'Basavanagudi', '1973-05-04', '2022-09-18', 'Instagram', 'Birthday Parties', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(913, 'Nirvi Doshi', 'nirvi60@bali-chahal.com', '+919475622544', '8720414980', 'Srinivas LLC', 'cx6293oE37', 'Indiranagar', '1988-07-21', '2018-05-02', 'Facebook', 'Massage & Body Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(914, 'Yuvaan Ram', 'csibal@sheth-arya.com', '+917354280772', '4464691601', 'Maharaj-Sampath', 'ih4724fw37', 'Whitefield', '2000-08-18', '2025-03-26', 'Walk-in', 'Dairy Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(915, 'Alisha Sama', 'khushidash@gmail.com', '08129236720', '+919329096884', 'Sha-Vohra', 'FF9500qX75', 'HSR Layout', '1986-01-01', '2015-12-18', 'Instagram', 'Hex Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(916, 'Jiya Kamdar', 'neysa93@yahoo.com', '+910229626900', '7534819586', 'Iyengar Ltd', 'ny4078Rk23', 'Koramangala', '2000-09-07', '2017-03-13', 'Facebook', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(917, 'Zeeshan Borah', 'jayan03@thakur.com', '6771215495', '+917747375237', 'Kala LLC', 'EN8442rk89', 'HSR Layout', '1994-02-21', '2025-03-20', 'Facebook', 'Cakes & Chocolates', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(918, 'Trisha Zacharia', 'vihaan91@hotmail.com', '07358220427', '08500942279', 'Agrawal, Chander and Shukla', 'DQ7466Oy14', 'Yelahanka', '1999-07-03', '2025-03-25', 'Google', 'CRM', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(919, 'Kashvi Dara', 'ehsaan87@kothari.com', '03418531012', '3806647536', 'Uppal, Swamy and Cherian', 'RK5378hx99', 'Whitefield', '1976-02-16', '2017-08-18', 'Walk-in', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(920, 'Pranay Chatterjee', 'ela38@arora.com', '09630308267', '03673086081', 'Apte, Loke and Bhatt', 'ii0893ue53', 'Whitefield', '2002-04-17', '2022-02-23', 'Instagram', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(921, 'Shanaya Subramaniam', 'auroraseher@sandal.com', '09868655636', '1174262841', 'Hayre-Sengupta', 'Ee3603qx56', 'BTM Layout', '1991-04-01', '2019-06-09', 'Google', 'Photography & Videographers', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(922, 'Ahana  Varughese', 'umadan@bhalla.info', '+911595856794', '07836438647', 'Ganesh, Atwal and Krishnan', 'hY1982Tv78', 'Basavanagudi', '1985-03-18', '2016-07-02', 'Walk-in', 'Hex Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(923, 'Vihaan Thaman', 'mmand@yahoo.com', '+910691627053', '4402663440', 'Thaker-Jani', 'Ps1785SC44', 'Banashankari', '1985-02-09', '2021-12-02', 'Google', 'Birthday Parties', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(924, 'Hrishita Vala', 'rajupranay@yahoo.com', '03817932144', '8687309044', 'Sarin Inc', 'Hg5822ei36', 'Whitefield', '1986-08-14', '2020-10-25', 'Walk-in', 'CRM', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(925, 'Ishaan Bhattacharyya', 'ibrahmbhatt@yahoo.com', '04942444774', '+914395617066', 'Bains-Hari', 'wd8337lX71', 'Jayanagar', '1982-02-12', '2016-02-06', 'Walk-in', 'Deep Cleaning Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(926, 'Veer Chacko', 'yakshitsagar@warrior.com', '6386463378', '+914984880769', 'Sahota-Agrawal', 'Rp9998rc05', 'Basavanagudi', '1996-07-11', '2021-10-11', 'Facebook', 'CRM', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(927, 'Veer Hayer', 'ewalla@sodhi.com', '04132389591', '04886723532', 'Khanna Inc', 'bg3093Eb38', 'Malleshwaram', '2000-09-14', '2016-04-30', 'Google', 'Software Maintenance', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(928, 'Prisha Deo', 'yuvaansolanki@char.com', '+916108675827', '9867502964', 'Chakrabarti, Boase and Rout', 'gZ3580Dk26', 'Koramangala', '1980-12-14', '2021-12-27', 'Walk-in', 'Hex Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(929, 'Kimaya Loyal', 'zsundaram@gmail.com', '+912707897790', '01195212069', 'Bhat-Saran', 'RZ3587NV91', 'Whitefield', '1969-11-14', '2020-01-24', 'Facebook', 'CRM', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(930, 'Kiara Tiwari', 'anika58@lad.com', '6089654010', '04786174736', 'Lanka, Sawhney and Talwar', 'kx0765Be92', 'Basavanagudi', '1969-06-03', '2020-08-13', 'Instagram', 'ERP', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(931, 'Shray Dugar', 'priyanshwable@yahoo.com', '08931178375', '06315923332', 'Sandhu and Sons', 'Ag9526da19', 'Yelahanka', '2003-10-27', '2017-07-12', 'Walk-in', 'Battery  & Charging', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(932, 'Miraya Manne', 'kashvi31@gmail.com', '4080714673', '+915452747223', 'Gandhi-Ramanathan', 'ok7935dL48', 'Electronic City', '1993-05-19', '2019-06-18', 'Facebook', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(933, 'Samarth Solanki', 'iraissac@kata.org', '+918837562937', '07344882052', 'Sinha-Dayal', 'NP8117uj79', 'Banashankari', '1967-08-26', '2016-08-09', 'Walk-in', 'Flat Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(934, 'Myra Dara', 'romilyohannan@hotmail.com', '7134991628', '04229314405', 'Goswami PLC', 'IJ5039Nl20', 'Indiranagar', '2001-01-15', '2015-07-27', 'Walk-in', 'Dairy Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(935, 'Yuvraj  Buch', 'kalaveer@basu.com', '7497285895', '0721493209', 'Mall PLC', 'fv7517qa51', 'Jayanagar', '2004-08-19', '2020-12-04', 'Facebook', 'Cakes & Chocolates', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(936, 'Ahana  Gour', 'dhruvseth@hotmail.com', '4337477816', '00437248316', 'Dey-Viswanathan', 'ul0385Aq01', 'RT Nagar', '1990-05-04', '2016-07-11', 'Instagram', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(937, 'Alia Iyengar', 'mchahal@yahoo.com', '7162681115', '00064016810', 'Kade-Jhaveri', 'fD0405bN19', 'Hebbal', '1984-08-11', '2019-05-28', 'Google', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(938, 'Shamik Banerjee', 'emir83@yahoo.com', '4763370121', '5348881977', 'Bandi, Chopra and Dhingra', 'RI4313lV09', 'RT Nagar', '1968-04-01', '2017-11-16', 'Google', 'CRM', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(939, 'Stuvan Konda', 'alisha56@baria.com', '+915977263162', '03018367637', 'Dash, Yadav and Lanka', 'OQ9294af93', 'RT Nagar', '1993-02-17', '2016-07-17', 'Google', 'Birthday Parties', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(940, 'Ahana  Banik', 'madhav67@goel.info', '00373509740', '0057976110', 'Hayre-Shankar', 'xz8402Xx74', 'Basavanagudi', '1985-12-11', '2018-09-20', 'Instagram', 'Flat Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(941, 'Ayesha Tailor', 'jsubramanian@khosla.com', '04741241478', '08789771697', 'Vig, De and Rege', 'un6700Se43', 'Hebbal', '1983-08-25', '2024-02-03', 'Instagram', 'ERP', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(942, 'Indrans Dalal', 'mannatkadakia@bora.com', '06055552535', '06083734234', 'Loke, Balan and Barad', 'Cy9830rS40', 'Whitefield', '2002-06-22', '2022-03-11', 'Walk-in', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(943, 'Aayush Kalla', 'csaran@badal-bains.com', '9922320124', '02519591613', 'Dugal Ltd', 'LV7631NJ42', 'Hebbal', '1966-06-24', '2021-10-14', 'Google', 'Battery  & Charging', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(944, 'Saksham Agrawal', 'bmajumdar@gmail.com', '08804190002', '09179881191', 'Tandon Inc', 'WV7428oa25', 'Marathahalli', '1968-04-04', '2024-05-01', 'Walk-in', 'Flat Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(945, 'Mannat Ramaswamy', 'mishti12@yahoo.com', '+919024202354', '2668216055', 'Luthra-Viswanathan', 'PU6306tO77', 'Koramangala', '1983-03-08', '2024-03-09', 'Walk-in', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(946, 'Indrans Sarraf', 'zthaker@gmail.com', '+919924907963', '2795167898', 'Sarraf-Ganesh', 'Xo9454rN63', 'Hebbal', '1994-11-14', '2015-07-25', 'Walk-in', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(947, 'Chirag Dutta', 'ehsaan73@gmail.com', '+911530306424', '06153695522', 'Mangal, Sawhney and Sridhar', 'JL3376TT85', 'Whitefield', '1987-01-27', '2017-10-26', 'Google', 'Photography & Videographers', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(948, 'Nirvaan Bhasin', 'jhanvidalia@yahoo.com', '04674860312', '2529349326', 'Dalal-Lanka', 'wl6622NB56', 'Basavanagudi', '1964-09-02', '2019-09-08', 'Google', 'CRM', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(949, 'Hridaan Sachdev', 'onkar04@chandran.org', '+915655608195', '06117708429', 'Ratta, Sha and Dey', 'jS9216Bv72', 'Indiranagar', '1967-06-06', '2017-02-21', 'Facebook', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(950, 'Ranbir Vala', 'ykhalsa@datta.com', '+913759720685', '+911331457354', 'Chawla Ltd', 'Wn3387lP32', 'Indiranagar', '1969-04-28', '2020-11-20', 'Facebook', 'Haircare Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(951, 'Himmat Gour', 'sahil60@hotmail.com', '+915656216079', '06039677750', 'Vohra Group', 'Pu7081LO55', 'BTM Layout', '1987-06-20', '2019-03-19', 'Google', 'Photography & Videographers', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(952, 'Kabir Malhotra', 'divittiwari@iyengar.net', '0851064290', '1569273442', 'Date LLC', 'Hr2551hu53', 'Koramangala', '1990-07-12', '2021-01-29', 'Google', 'Flat Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(953, 'Divij Mammen', 'vedikaanand@krishnan.com', '+918179944883', '07990807018', 'Walla-Sagar', 'ce2919uX74', 'Basavanagudi', '1981-02-27', '2018-08-09', 'Walk-in', 'CRM', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(954, 'Akarsh Varma', 'lankaseher@yahoo.com', '0023261122', '+910227234148', 'Dugal, Das and Soni', 'hx6439eE74', 'HSR Layout', '1969-01-28', '2024-09-28', 'Instagram', 'Hair Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(955, 'Yuvraj  Chhabra', 'mehul47@dass.biz', '+911761150171', '+912524080057', 'Bedi-Tank', 'Yz2605GS46', 'Hebbal', '1982-07-22', '2016-07-02', 'Instagram', 'Haircare Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(956, 'Trisha Chokshi', 'myramalhotra@gmail.com', '3408303957', '9414224673', 'Suri PLC', 'kM1928yF27', 'Malleshwaram', '1969-07-23', '2023-12-25', 'Instagram', 'Flat Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(957, 'Zain Raj', 'bosezain@gmail.com', '7363954126', '06098327511', 'Swaminathan-Varghese', 'Ft1127rI08', 'Indiranagar', '1969-12-06', '2017-07-12', 'Facebook', 'Hex Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(958, 'Vaibhav Verma', 'pihusawhney@gmail.com', '5530794583', '9963163096', 'Rattan LLC', 'Tw7833SS43', 'Electronic City', '1978-07-12', '2018-04-26', 'Walk-in', 'Deep Cleaning Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(959, 'Shamik Sangha', 'ggupta@tripathi-ramanathan.com', '+919996107877', '0788973452', 'Sura LLC', 'Hg9520tV08', 'Whitefield', '1996-02-01', '2020-10-25', 'Facebook', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(960, 'Parinaaz Toor', 'riyasethi@gmail.com', '03274521208', '+912682920070', 'Dua-Sunder', 'On8995Mu89', 'Koramangala', '1975-01-14', '2021-03-28', 'Facebook', 'Hex Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(961, 'Krish Basu', 'bbuch@yahoo.com', '+916201885028', '06974868491', 'Bhalla Group', 'qp8556oK08', 'Hebbal', '1979-06-15', '2023-04-04', 'Google', 'Hair Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(962, 'Azad Sankar', 'ygour@lad.com', '01530300933', '08727143115', 'Vohra, Gera and Varghese', 'En5460uc78', 'Malleshwaram', '2001-12-07', '2023-05-29', 'Walk-in', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(963, 'Indrajit Dubey', 'bawaveer@sibal.com', '+916899817274', '02971658398', 'Gupta-Bandi', 'EF2514me11', 'Marathahalli', '1982-01-11', '2019-02-05', 'Google', 'Photography & Videographers', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(964, 'Farhan Mammen', 'sarakhosla@hari.com', '+913706686695', '09491857443', 'Raj and Sons', 'fF6004IO26', 'Koramangala', '1997-09-20', '2023-08-22', 'Walk-in', 'Photography & Videographers', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(965, 'Anya Madan', 'rmahal@khurana.com', '+918324427850', '7477866785', 'Chadha-Kamdar', 'an6572Ug85', 'Malleshwaram', '1992-11-06', '2024-05-04', 'Google', 'ERP', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(966, 'Ishita Dugal', 'hridaansule@hotmail.com', '04133785889', '06778345752', 'Sastry-Chaudhari', 'Na3826vM08', 'Marathahalli', '1994-08-10', '2020-12-09', 'Walk-in', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(967, 'Nakul Malhotra', 'urvivala@sarma-manda.com', '0808796985', '07957261968', 'Ramanathan Group', 'nw4640yN30', 'Marathahalli', '2000-06-05', '2022-01-26', 'Instagram', 'Cakes & Chocolates', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(968, 'Aniruddh Char', 'bsaran@majumdar.com', '+912552926273', '2343579755', 'Rege, Bhagat and Kapadia', 'Uj8714YL83', 'BTM Layout', '1993-05-15', '2024-09-03', 'Facebook', 'Dairy Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(969, 'Devansh Hans', 'hsankar@mandal.info', '4924482321', '09274761690', 'Andra LLC', 'xd1582Uj38', 'Marathahalli', '1975-08-16', '2018-05-02', 'Walk-in', 'Massage & Body Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(970, 'Aniruddh Saraf', 'stuvanranganathan@ray.biz', '+915285037583', '+911452910572', 'Jain-Shukla', 'DR3635Li09', 'Electronic City', '1989-08-01', '2017-09-28', 'Facebook', 'Hex Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(971, 'Nehmat Rau', 'ela71@de.net', '+911666170023', '06583338318', 'Shah LLC', 'PG9874zU53', 'RT Nagar', '2001-09-17', '2019-11-11', 'Google', 'Hair Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(972, 'Parinaaz Chandran', 'vritika09@karpe.com', '+911603927136', '1454851939', 'Kaur-Sarkar', 'Ow6265CD63', 'Indiranagar', '1996-12-23', '2024-01-17', 'Instagram', 'Photography & Videographers', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(973, 'Sahil Suri', 'deodrishya@gmail.com', '2944610177', '07949839539', 'Upadhyay PLC', 'fr1227HM82', 'Koramangala', '1988-01-31', '2024-05-22', 'Instagram', 'Flat Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(974, 'Hunar Khare', 'farhan35@gmail.com', '7470788797', '1268684051', 'Jaggi PLC', 'Gz5071jg20', 'Jayanagar', '1986-09-11', '2016-06-08', 'Walk-in', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(975, 'Bhamini Issac', 'arnavsethi@contractor-khanna.com', '09539836920', '+912545899232', 'Ghose, Sengupta and Sibal', 'om1366bi19', 'Koramangala', '1987-04-15', '2025-01-09', 'Facebook', 'Massage & Body Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(976, 'Nirvaan Golla', 'srinivasdiya@hotmail.com', '+913579071606', '08271056131', 'Bal Inc', 'nG5347KZ84', 'HSR Layout', '1982-11-15', '2025-01-12', 'Facebook', 'Skincare & Facial Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(977, 'Dishani Kale', 'bediira@gmail.com', '+916845713347', '2954759035', 'Sachar, Dash and Chaudhari', 'AR2387oc98', 'Malleshwaram', '1994-11-28', '2018-03-24', 'Google', 'Software Maintenance', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(978, 'Nirvi Date', 'onkaranne@tandon.com', '08176526107', '+918433975616', 'Varghese Inc', 'BV0106Wt52', 'Indiranagar', '1973-10-13', '2020-03-26', 'Walk-in', 'Software Maintenance', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(979, 'Badal Gole', 'wadhwajivin@yahoo.com', '7923535556', '7061399713', 'Deol-Shukla', 'Zr4979Hc06', 'Yelahanka', '1994-11-04', '2023-08-28', 'Walk-in', 'Flat Head Bolt', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(980, 'Pari Shukla', 'hgandhi@gmail.com', '+916850298076', '+917324986370', 'Srinivasan-Raju', 'pB7347ju44', 'Basavanagudi', '1996-11-23', '2015-09-16', 'Walk-in', 'ERP', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(981, 'Elakshi Kapur', 'yvenkatesh@jayaraman-sridhar.com', '+915299448150', '1478427806', 'Wali, Yogi and Vora', 'Qy7506Rb45', 'Hebbal', '1976-03-31', '2024-04-07', 'Walk-in', 'Battery  & Charging', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(982, 'Bhamini Kant', 'lgolla@basak-deshpande.com', '+913395722915', '07834387848', 'Bail, D’Alia and Chakraborty', 'pq3369Lt49', 'Electronic City', '1979-02-09', '2022-01-16', 'Google', 'Haircare Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(983, 'Himmat Dada', 'anvi55@dave-krishna.info', '+918318784812', '+916957552770', 'Bhandari-Khosla', 'JB9480wH22', 'Malleshwaram', '1964-11-16', '2018-09-09', 'Facebook', 'Speaker, Mike, Projector & Led screen', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(984, 'Ivan Krishnan', 'agatejivika@saxena.biz', '9593439091', '5790218266', 'Lad Ltd', 'pq2071Rj34', 'RT Nagar', '1998-07-03', '2020-05-09', 'Instagram', 'Hair Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(985, 'Veer Kakar', 'fsaxena@gmail.com', '3729020668', '3202160451', 'Datta-Bail', 'wA3307ug87', 'Hebbal', '1984-12-18', '2018-01-12', 'Instagram', 'Birthday Parties', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(986, 'Heer Thaker', 'bansaltanya@hotmail.com', '9614708842', '05433734240', 'Agrawal-Sagar', 'XH8398da75', 'BTM Layout', '1967-04-05', '2015-05-19', 'Google', 'Dairy Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(987, 'Eshani Malhotra', 'neelofar90@hotmail.com', '+913658074550', '+914948929362', 'Batra-Kaur', 'Ns0129Fi19', 'BTM Layout', '1965-05-29', '2019-03-28', 'Facebook', 'Pet Grooming', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(988, 'Chirag Sridhar', 'nkaur@soman.com', '8765543005', '+915046544732', 'Dube, Salvi and Mani', 'Yb5076DS56', 'Marathahalli', '1997-10-03', '2021-03-30', 'Instagram', 'Photography & Videographers', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(989, 'Aniruddh Gokhale', 'navyasaxena@cheema.com', '2209264741', '+912208672564', 'Johal, Baral and Bhandari', 'sL0997Yn94', 'RT Nagar', '1986-01-29', '2022-02-15', 'Walk-in', 'Software Maintenance', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(990, 'Himmat Kulkarni', 'priyansh70@hotmail.com', '+911368467728', '09932963770', 'Apte-Dass', 'YH6830Ka89', 'Electronic City', '1987-02-17', '2022-01-14', 'Facebook', 'Birthday Parties', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(991, 'Yashvi Devan', 'anika02@yahoo.com', '00264737630', '08103450653', 'Khalsa and Sons', 'mh5919Fk94', 'Jayanagar', '2003-12-16', '2025-01-01', 'Walk-in', 'Yoga', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(992, 'Vaibhav Maharaj', 'mannat54@hotmail.com', '9050850126', '+915542124519', 'Sahni Ltd', 'Te7966dD78', 'Hebbal', '1993-06-14', '2024-05-04', 'Walk-in', 'Dairy Products', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(993, 'Ahana  Zacharia', 'aaravsami@sant.com', '+918372731314', '03706528085', 'Bhavsar, Ranganathan and Balakrishnan', 'QZ8827XO17', 'Jayanagar', '1986-07-22', '2020-11-27', 'Walk-in', 'Photography & Videographers', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(994, 'Trisha Mandal', 'evatrivedi@ramanathan-ben.com', '2382359616', '05244689421', 'Chand Group', 'jJ1929vH33', 'Jayanagar', '1968-05-10', '2023-04-24', 'Walk-in', 'Birthday Parties', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(995, 'Heer Hans', 'kismatchaudhary@yahoo.com', '04362450119', '07581711429', 'Mani, Ramesh and Verma', 'Lz5349pI88', 'Hebbal', '1996-07-25', '2015-10-24', 'Facebook', 'Photography & Videographers', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(996, 'Ayesha Bedi', 'parimand@hotmail.com', '00476527039', '0864775653', 'Yogi, Bahl and Jaggi', 'vN0360Pv41', 'Hebbal', '1980-03-21', '2018-09-01', 'Google', 'Yoga', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(997, 'Neelofar Krish', 'amall@butala.info', '6080427153', '+910939389525', 'Bala Ltd', 'Zg5766tP42', 'Jayanagar', '1971-11-06', '2019-06-29', 'Google', 'Massage & Body Treatments', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(998, 'Aarav Thaman', 'anvidey@yahoo.com', '+917501813524', '04691612102', 'Bhatt LLC', 'Hs1255KC39', 'Electronic City', '1987-03-17', '2025-03-20', 'Facebook', 'CRM', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(999, 'Dishani Kothari', 'nayantara30@bhatia.net', '8951905377', '+910974635543', 'Thakur Inc', 'jD0510rc37', 'RT Nagar', '1999-10-03', '2016-08-11', 'Facebook', 'Hair Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0),
(1000, 'Himmat Biswas', 'cratti@yahoo.com', '+910866591527', '5121074687', 'Arora-Basu', 'JA9850RB44', 'Whitefield', '1998-08-01', '2016-01-18', 'Facebook', 'Deep Cleaning Services', 1, '2025-04-29 10:03:09', '2025-04-29 10:03:09', 0);

-- --------------------------------------------------------

--
-- Table structure for table `marketing`
--

CREATE TABLE `marketing` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `title` varchar(255) DEFAULT NULL,
  `subtitle` varchar(255) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `image` varchar(255) DEFAULT NULL,
  `offer_list` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`offer_list`)),
  `summary` text DEFAULT NULL,
  `location` varchar(255) DEFAULT NULL,
  `status` varchar(255) DEFAULT NULL,
  `is_deleted` varchar(255) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `marketings`
--

CREATE TABLE `marketings` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `business_id` varchar(255) NOT NULL,
  `title` varchar(255) NOT NULL,
  `subtitle` varchar(255) NOT NULL,
  `description` text NOT NULL,
  `image` varchar(255) DEFAULT NULL,
  `offer_list` text DEFAULT NULL,
  `summary` text DEFAULT NULL,
  `location` varchar(255) NOT NULL,
  `status` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `marketings`
--

INSERT INTO `marketings` (`id`, `business_id`, `title`, `subtitle`, `description`, `image`, `offer_list`, `summary`, `location`, `status`, `created_at`, `updated_at`, `is_deleted`) VALUES
(1, '3', 'Festive Gift Hampers', 'Exclusive Diwali Collection', 'Celebrate Diwali with our beautifully curated gift hampers.', 'storage/marketings/yr6OiBOmUvvvuOP3yF3AkvP3V4oFaSwWrWuLOhZ2.png', '[\"Flat 20% off\"]', 'Perfect for corporate and family gifting.', 'Mumbai', 1, '2025-03-25 18:32:24', '2025-04-04 10:22:11', 0),
(2, '3', 'Valentine’s Day Specials', 'Express Love with Unique Gifts', 'Surprise your loved ones with personalized gifts.', 'valentine_gifts.jpg', '[\"Buy 1 Get 1 Free\"]', 'Customized gifts available.', 'Delhi', 1, '2025-03-25 18:32:24', '2025-03-25 18:32:24', 0),
(3, '3', 'Birthday Surprise Boxes', 'Curated Gifts for Every Age', 'Choose from a range of birthday special gift boxes.', 'birthday_gifts.jpg', '[\"Free gift wrap\"]', 'Gift sets for kids and adults.', 'Bangalore', 1, '2025-03-25 18:32:24', '2025-03-25 18:32:24', 0),
(4, '3', 'Wedding Gift Collections', 'Luxury Gifting Made Easy', 'Find the perfect wedding gifts for the big day.', 'wedding_gifts.jpg', '[\"10% off on bulk orders\"]', 'Premium gifts for all wedding needs.', 'Chennai', 1, '2025-03-25 18:32:24', '2025-03-25 18:32:24', 0),
(5, '3', 'Corporate Gift Solutions', 'Elegant Gifts for Clients & Employees', 'Personalized corporate gifts with branding options.', 'corporate_gifts.jpg', '[\"Bulk discounts available\"]', 'Custom branding on products.', 'Hyderabad', 1, '2025-03-25 18:32:24', '2025-03-25 18:32:24', 0),
(6, '3', 'New Year Celebrations', 'Start the Year with Special Gifts', 'Welcome the new year with our exclusive gift sets.', 'new_year_gifts.jpg', '[\"Special discount on pre-orders\"]', 'Ideal for personal & corporate gifting.', 'Pune', 1, '2025-03-25 18:32:24', '2025-03-25 18:32:24', 0),
(7, '7', 'check', 'sub ed', 'desc', 'storage/marketings/ohhP3pqsGSQaFeuj8aZTQCPj8dNBVouUpDS2WYzo.jpg', '[\"item 1\",\"item 2\"]', 'lkfkdkas', 'india', 1, '2025-04-13 07:45:14', '2025-04-13 07:45:14', 0);

-- --------------------------------------------------------

--
-- Table structure for table `menu_permissions`
--

CREATE TABLE `menu_permissions` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `user_id` bigint(20) UNSIGNED NOT NULL,
  `permissions` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`permissions`)),
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `menu_permissions`
--

INSERT INTO `menu_permissions` (`id`, `user_id`, `permissions`, `created_at`, `updated_at`) VALUES
(1, 3, '{\"Dashboard\":\"on\",\"Channel Partners\":\"on\",\"Marketings\":\"on\"}', '2025-04-19 05:41:14', '2025-04-19 05:41:14'),
(2, 2, '{\"Dashboard\":\"on\",\"Tenants\":{\"List\":\"on\"},\"Channel Partners\":\"on\",\"Sales and Services\":\"on\",\"Leads Master\":\"on\",\"Sync Request\":\"on\"}', '2025-04-19 06:12:53', '2025-05-02 08:29:49');

-- --------------------------------------------------------

--
-- Table structure for table `migrations`
--

CREATE TABLE `migrations` (
  `id` int(10) UNSIGNED NOT NULL,
  `migration` varchar(255) NOT NULL,
  `batch` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `migrations`
--

INSERT INTO `migrations` (`id`, `migration`, `batch`) VALUES
(1, '0001_01_01_000000_create_users_table', 1),
(2, '0001_01_01_000001_create_cache_table', 1),
(3, '0001_01_01_000002_create_jobs_table', 1),
(4, '2024_09_12_071148_create_query_builder_table', 2),
(5, '2024_10_17_070725_create_marketings_table', 3),
(6, '2025_04_10_155053_create_cron_jobs_table', 4),
(7, '2025_03_03_151952_create_channel_partners_table', 5),
(8, '2025_04_16_170818_create_referrals_table', 6),
(9, '2025_04_18_161728_create_menu_permissions_table', 7),
(10, '2025_05_02_103923_create_sync_requests_table', 8),
(11, '2025_05_10_131648_create_transaction_history_table', 9),
(12, 'create_stages_table', 10),
(13, 'create_statuses_table', 11);

-- --------------------------------------------------------

--
-- Table structure for table `newattachments`
--

CREATE TABLE `newattachments` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `document_id` bigint(20) UNSIGNED NOT NULL,
  `customer_id` bigint(20) UNSIGNED DEFAULT NULL,
  `path` varchar(255) NOT NULL,
  `status` tinyint(1) NOT NULL DEFAULT 1,
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `newattachments`
--

INSERT INTO `newattachments` (`id`, `document_id`, `customer_id`, `path`, `status`, `is_deleted`, `created_at`, `updated_at`) VALUES
(1, 1, 248, 'non_prod_tenant_3/newattachments/IMG_689ae351ef5e5.jpeg', 1, 0, '2025-08-12 06:46:41', '2025-08-12 06:46:41');

-- --------------------------------------------------------

--
-- Table structure for table `number_series`
--

CREATE TABLE `number_series` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `type` varchar(255) NOT NULL,
  `source` varchar(255) NOT NULL,
  `financial_year` varchar(255) NOT NULL,
  `last_number` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `password_reset_tokens`
--

CREATE TABLE `password_reset_tokens` (
  `email` varchar(255) NOT NULL,
  `token` varchar(255) NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `prescription`
--

CREATE TABLE `prescription` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `document_id` bigint(20) UNSIGNED NOT NULL,
  `prescription` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`prescription`)),
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `product-catalogs`
--

CREATE TABLE `product-catalogs` (
  `id` int(10) UNSIGNED NOT NULL,
  `title` text DEFAULT NULL,
  `category_name` varchar(255) DEFAULT NULL,
  `image` text DEFAULT NULL,
  `price` decimal(10,2) DEFAULT NULL,
  `offer` decimal(10,2) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `size` text DEFAULT NULL,
  `color` text DEFAULT NULL,
  `is_inventory` int(11) NOT NULL DEFAULT 0,
  `available_quantity` decimal(10,2) DEFAULT NULL,
  `gst_percentage` varchar(255) DEFAULT NULL,
  `employee_percentage` decimal(10,2) DEFAULT NULL,
  `status` tinyint(1) NOT NULL DEFAULT 1,
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `product-catalogs`
--

INSERT INTO `product-catalogs` (`id`, `title`, `category_name`, `image`, `price`, `offer`, `description`, `size`, `color`, `is_inventory`, `available_quantity`, `gst_percentage`, `employee_percentage`, `status`, `is_deleted`, `created_at`, `updated_at`) VALUES
(1, 'Bridal lehanga', 'Fabric & materials', 'non_prod_tenant_3/product-catalogs/cgDC0Bnfo9A526MKVySy3SQOnovUfaB3VpXbXVwq.jpg', 2500.00, 1500.00, 'test', NULL, 'Red', 1, 99.00, '12%', NULL, 1, 0, '2025-08-12 06:42:26', '2025-08-12 06:46:41'),
(2, 'Designer saree', 'Customization & embellishments', 'non_prod_tenant_3/product-catalogs/8kdaEzLqwxkCi8aEbErDHpmwGQJPlUmN7AlNgzfA.jpg', 3500.00, 2999.00, 'test', NULL, 'Red', 1, 249.00, NULL, NULL, 1, 0, '2025-08-12 06:43:17', '2025-08-12 06:46:41');

-- --------------------------------------------------------

--
-- Table structure for table `query_builder`
--

CREATE TABLE `query_builder` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `business_id` bigint(20) UNSIGNED DEFAULT NULL,
  `source_name` varchar(255) DEFAULT NULL,
  `selected_columns` varchar(255) DEFAULT NULL,
  `target` varchar(50) DEFAULT NULL,
  `method_name` varchar(255) NOT NULL,
  `rule` longtext NOT NULL,
  `query` text DEFAULT NULL,
  `status` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `deleted_at` timestamp NULL DEFAULT NULL,
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `query_builder`
--

INSERT INTO `query_builder` (`id`, `business_id`, `source_name`, `selected_columns`, `target`, `method_name`, `rule`, `query`, `status`, `created_at`, `updated_at`, `deleted_at`, `is_deleted`) VALUES
(19, NULL, 'business_categories', '', NULL, 'get_business_categories', '{\"condition\":\"AND\",\"rules\":[{\"id\":\"name\",\"field\":\"name\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"$1\"}],\"valid\":true}', NULL, 0, '2024-09-13 08:41:51', '2024-11-11 22:05:12', NULL, 1),
(20, NULL, 'business_categories', '', NULL, 'getBusinessList', '{\"condition\":\"AND\",\"rules\":[{\"id\":\"status\",\"field\":\"status\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"1\"}],\"valid\":true}', NULL, 1, '2024-09-18 08:18:27', '2024-09-18 08:18:27', NULL, 0),
(21, NULL, 'sales_and_services', 'service', NULL, 'get_category_by_service', '{\"condition\":\"AND\",\"rules\":[{\"id\":\"business_id\",\"field\":\"business_id\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"$bID\"},{\"id\":\"sub_category_id\",\"field\":\"sub_category_id\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"$sID\"},\n{\"id\":\"status\",\"field\":\"status\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"1\"},{\"id\":\"is_deleted\",\"field\":\"is_deleted\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"0\"},{\"id\":\"service\",\"field\":\"service\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"is_not_null\",\"value\":null}],\"valid\":true}', NULL, 1, '2024-11-09 13:24:14', '2024-11-09 13:24:14', NULL, 0),
(22, NULL, 'sales_and_services', 'product_category', NULL, 'get_category_by_product', '{\"condition\":\"AND\",\"rules\":[{\"id\":\"business_id\",\"field\":\"business_id\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"$bID\"},{\"id\":\"sub_category_id\",\"field\":\"sub_category_id\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"$sID\"},{\"id\":\"status\",\"field\":\"status\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"1\"},{\"id\":\"is_deleted\",\"field\":\"is_deleted\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"0\"},{\"id\":\"product_category\",\"field\":\"product_category\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"is_not_null\",\"value\":null}],\"valid\":true}', NULL, 1, '2024-11-09 13:24:14', '2024-11-09 13:24:14', NULL, 0),
(23, NULL, 'employees', 'full_name', 'Tenant', 'get_employeeNameList', '{\"condition\":\"AND\",\"rules\":[{\"id\":\"status\",\"field\":\"status\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"1\"},{\"id\":\"is_deleted\",\"field\":\"is_deleted\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"0\"}],\"valid\":true}', NULL, 1, '2024-11-17 08:37:36', '2024-11-17 08:37:36', NULL, 0),
(24, NULL, 'sales_and_services', 'product_category,service', NULL, 'get_category_by_name', '{\"condition\":\"AND\",\"rules\":[{\"id\":\"business_id\",\"field\":\"business_id\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"$bID\"},{\"id\":\"sub_category_id\",\"field\":\"sub_category_id\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"$sID\"},{\"id\":\"status\",\"field\":\"status\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"1\"},{\"id\":\"is_deleted\",\"field\":\"is_deleted\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"0\"}],\"valid\":true}', NULL, 1, '2024-11-09 13:24:14', '2024-11-09 13:24:14', NULL, 0),
(25, NULL, 'chances', 'value', NULL, 'get_chances', '{\"condition\":\"AND\",\"rules\":[{\"id\":\"status\",\"field\":\"status\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"1\"},{\"id\":\"is_deleted\",\"field\":\"is_deleted\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"0\"}],\"valid\":true}', NULL, 1, NULL, NULL, NULL, 0),
(26, NULL, '', NULL, 'Tenant', 'get_customer_list', '', 'CALL getCustomerList();', 1, '2024-11-30 08:16:30', '2024-11-30 08:16:30', NULL, 0),
(27, NULL, '', NULL, 'Tenant', 'get_scheduled_list', '', 'CALL getScheduleList(:from_date, :to_date);', 1, '2024-11-30 08:50:47', '2024-11-30 08:50:47', NULL, 0),
(28, NULL, '', NULL, 'Tenant', 'get_leads_list', '', 'CALL getLeadsList(:from_date, :to_date);', 1, '2024-11-30 08:53:43', '2024-11-30 08:53:43', NULL, 0),
(29, NULL, 'customers', '', 'Tenant', 'get_new_contact_list', '{\"condition\":\"AND\",\"rules\":[{\"id\":\"group\",\"field\":\"group\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"is_null\",\"value\":null}],\"valid\":true}', NULL, 1, '2024-12-02 07:52:55', '2024-12-02 07:52:55', NULL, 0),
(30, NULL, 'customers', NULL, 'Tenant', 'get_friends_list', '{\"condition\":\"AND\",\"rules\":[{\"id\":\"group\",\"field\":\"group\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"Friend\"}],\"valid\":true}', NULL, 1, '2024-12-02 08:03:35', '2024-12-02 08:03:35', NULL, 0),
(31, NULL, 'customers', NULL, 'Tenant', 'get_vendor_or_supplier_list', '{\"condition\":\"AND\",\"rules\":[{\"id\":\"group\",\"field\":\"group\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"Vendor/Supplier\"}],\"valid\":true}', NULL, 1, '2024-12-02 08:04:36', '2024-12-02 08:04:36', NULL, 0),
(32, NULL, '', NULL, 'Tenant', 'get_status_not_updated_list', '', 'CALL getStatusNotUpdatedList(:from_date, :to_date);', 1, '2024-12-02 08:16:10', '2024-12-02 08:16:10', NULL, 0),
(33, NULL, '', NULL, 'Tenant', 'get_most_likely_list', '', 'CALL getMostLiklyList(:from_date, :to_date);', 1, '2024-12-02 08:16:10', '2024-12-02 08:16:10', NULL, 0),
(34, NULL, 'customers', NULL, 'Tenant', 'get_family_list', '{\"condition\":\"AND\",\"rules\":[{\"id\":\"group\",\"field\":\"group\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"Family\"}],\"valid\":true}', NULL, 1, '2024-12-31 15:01:43', '2024-12-31 15:01:43', NULL, 0),
(35, NULL, 'customers', NULL, 'Tenant', 'get_partners_list', '{\"condition\":\"AND\",\"rules\":[{\"id\":\"group\",\"field\":\"group\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"Partner\"}],\"valid\":true}', NULL, 1, '2024-12-31 15:18:03', '2024-12-31 15:18:03', NULL, 0),
(36, NULL, '', NULL, 'Tenant', 'get_followup_list', '', 'CALL getFollowUpList(:from_date, :to_date);', 1, '2024-11-30 08:50:47', '2024-11-30 08:50:47', NULL, 0),
(37, NULL, 'job_profile_master', 'job_title', NULL, 'get_job_profile_by_business_id', '{\"condition\":\"AND\",\"rules\":[{\"id\":\"business_id\",\"field\":\"business_id\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"$bID\"},{\"id\":\"status\",\"field\":\"status\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"1\"}],\"valid\":true}', NULL, 1, '2025-04-09 06:46:44', '2025-04-09 06:46:44', NULL, 0),
(38, NULL, 'customers', NULL, 'Tenant', 'get_reject_list', '{\"condition\":\"AND\",\"rules\":[{\"id\":\"group\",\"field\":\"group\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"Rejected\"}],\"valid\":true}', NULL, 1, '2025-04-09 06:46:44', '2025-04-09 06:46:44', NULL, 0),
(39, NULL, 'states', NULL, NULL, 'get_states', '{\"condition\":\"AND\",\"rules\":[{\"id\":\"status\",\"field\":\"status\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"1\"}],\"valid\":true}', NULL, 1, '2025-04-09 06:46:44', '2025-04-09 06:46:44', NULL, 0),
(40, NULL, 'brand_master', 'brand_name', 'Tenant', 'get_brand_list', '{\"condition\":\"AND\",\"rules\":[{\"id\":\"status\",\"field\":\"status\",\"type\":\"integer\",\"input\":\"number\",\"operator\":\"equal\",\"value\":1}],\"valid\":true}', NULL, 1, '2025-06-17 06:47:15', '2025-06-17 06:47:22', NULL, 0),
(41, NULL, 'color_master', 'color_name', NULL, 'get_color_list', '{\"condition\":\"AND\",\"rules\":[{\"id\":\"status\",\"field\":\"status\",\"type\":\"integer\",\"input\":\"number\",\"operator\":\"equal\",\"value\":1}],\"valid\":true}', NULL, 1, '2025-06-18 07:55:54', '2025-06-18 08:42:05', NULL, 0),
(42, NULL, 'size_master', 'size', NULL, 'get_size_list', '{\"condition\":\"AND\",\"rules\":[{\"id\":\"status\",\"field\":\"status\",\"type\":\"integer\",\"input\":\"number\",\"operator\":\"equal\",\"value\":1}],\"valid\":true}', NULL, 1, '2025-06-18 07:55:54', '2025-06-18 08:41:19', NULL, 0),
(43, 2, 'boutique_items', 'item_name', 'Tenant', 'get_item_list', '{\"condition\":\"AND\",\"rules\":[{\"id\":\"status\",\"field\":\"status\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"1\"},{\"id\":\"is_deleted\",\"field\":\"is_deleted\",\"type\":\"string\",\"input\":\"text\",\"operator\":\"equal\",\"value\":\"0\"}],\"valid\":true}', NULL, 1, '2025-07-09 11:31:23', '2025-07-15 08:08:02', NULL, 0);

-- --------------------------------------------------------

--
-- Table structure for table `query_mapping`
--

CREATE TABLE `query_mapping` (
  `id` int(11) NOT NULL,
  `group_name` varchar(250) NOT NULL,
  `method_name` varchar(250) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `is_deleted` int(11) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `query_mapping`
--

INSERT INTO `query_mapping` (`id`, `group_name`, `method_name`, `status`, `created_at`, `updated_at`, `is_deleted`) VALUES
(1, 'Customer', 'get_customer_list', 1, '2024-11-30 16:48:46', '2024-11-30 16:48:46', 0),
(2, 'Leads', 'get_leads_list', 1, '2024-11-30 16:48:50', '2024-11-30 16:48:50', 0),
(3, 'Schedule', 'get_scheduled_list', 1, '2024-11-30 16:49:01', '2024-11-30 16:49:01', 0),
(4, 'Contact', 'get_new_contact_list', 1, '2024-12-02 13:27:24', '2024-12-02 13:27:24', 0),
(5, 'Friend', 'get_friends_list', 1, '2024-12-02 13:38:16', '2024-12-02 13:38:16', 0),
(6, 'Vendor/Supplier', 'get_vendor_or_supplier_list', 1, '2024-12-02 13:38:21', '2024-12-02 13:38:21', 0),
(7, 'Status Not Updated', 'get_status_not_updated_list', 1, '2024-12-02 13:55:12', '2024-12-02 13:55:12', 0),
(8, 'Most Likely', 'get_most_likely_list', 1, '2024-11-30 16:48:46', '2024-11-30 16:48:46', 0),
(9, 'Family', 'get_family_list', 1, '2024-12-31 09:43:24', '2024-12-31 09:43:24', 0),
(10, 'Partner', 'get_partners_list', 1, '2024-12-31 09:58:11', '2024-12-31 09:58:11', 0),
(11, 'Followup', 'get_followup_list', 1, '2024-12-31 09:58:11', '2024-12-31 09:58:11', 0),
(12, 'Rejected', 'get_reject_list', 1, '2025-02-17 06:08:57', '2025-02-17 06:08:57', 0);

-- --------------------------------------------------------

--
-- Table structure for table `referrals`
--

CREATE TABLE `referrals` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `partner_id` bigint(20) NOT NULL,
  `cust_name` varchar(255) NOT NULL,
  `cust_mobile` varchar(255) NOT NULL,
  `referral_code` varchar(255) NOT NULL,
  `cust_email` varchar(255) DEFAULT NULL,
  `status` int(11) NOT NULL DEFAULT 1,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `referrals`
--

INSERT INTO `referrals` (`id`, `partner_id`, `cust_name`, `cust_mobile`, `referral_code`, `cust_email`, `status`, `created_at`, `updated_at`) VALUES
(1, 1, '', '7022329256', 'ABCD', NULL, 1, '2025-07-31 11:02:25', '2025-07-31 11:02:30'),
(5, 2, '', '8217371089', 'ANJAN', NULL, 1, '2025-07-31 11:02:25', '2025-07-31 11:02:30'),
(7, 2, '', '7091676388', 'ABCD123', NULL, 1, '2025-07-31 11:02:25', '2025-07-31 11:02:30'),
(8, 2, '', '9632493240', 'ABCD1', NULL, 1, '2025-07-31 11:02:25', '2025-07-31 11:02:30'),
(9, 2, '', '9840913457', 'ABCD12', NULL, 1, '2025-07-31 11:02:25', '2025-07-31 11:02:30');

-- --------------------------------------------------------

--
-- Table structure for table `sales_and_services`
--

CREATE TABLE `sales_and_services` (
  `id` int(11) NOT NULL,
  `business_id` int(11) NOT NULL,
  `sub_category_id` int(11) DEFAULT NULL,
  `type` enum('sales','service','both','') DEFAULT NULL,
  `service` varchar(250) DEFAULT NULL,
  `product_category` varchar(150) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp(),
  `status` int(11) NOT NULL DEFAULT 1 COMMENT '0=inactive\r\n1=active',
  `is_deleted` tinyint(4) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `sales_and_services`
--

INSERT INTO `sales_and_services` (`id`, `business_id`, `sub_category_id`, `type`, `service`, `product_category`, `created_at`, `updated_at`, `status`, `is_deleted`) VALUES
(1, 1, NULL, 'service', 'Massage & Body Treatments', NULL, '2025-02-05 18:22:06', '2025-02-05 18:22:06', 1, 0),
(2, 1, NULL, 'service', 'Skincare & Facial Treatments', NULL, '2025-02-05 18:27:05', '2025-02-05 18:27:05', 1, 0),
(3, 1, NULL, 'service', 'Hair Services', NULL, '2025-02-05 18:27:05', '2025-02-05 18:27:05', 1, 0),
(4, 1, NULL, 'service', 'Hand & Foot Care', NULL, '2025-02-05 18:27:05', '2025-02-05 18:27:05', 1, 0),
(5, 1, NULL, 'service', 'Waxing & Hair Removal', NULL, '2025-02-05 18:27:05', '2025-02-05 18:27:05', 1, 0),
(6, 1, NULL, 'service', 'Makeup & Beauty Services', NULL, '2025-02-05 18:27:05', '2025-02-05 18:27:05', 1, 0),
(7, 1, NULL, 'service', 'Specialized Treatments', NULL, '2025-02-05 18:27:05', '2025-02-05 18:27:05', 1, 0),
(8, 1, NULL, 'sales', NULL, 'Hair Care Products ', '2025-02-05 18:27:47', '2025-02-05 18:27:47', 1, 0),
(9, 1, NULL, 'sales', NULL, 'Skincare Products', '2025-02-05 18:30:19', '2025-02-05 18:30:19', 1, 0),
(10, 1, NULL, 'sales', NULL, 'Body Care Products', '2025-02-05 18:30:19', '2025-02-05 18:30:19', 1, 0),
(11, 1, NULL, 'sales', NULL, 'Hand & Foot Care Products', '2025-02-05 18:30:19', '2025-02-05 18:30:19', 1, 0),
(12, 1, NULL, 'sales', NULL, 'Waxing & Hair Removal Products', '2025-02-05 18:30:19', '2025-02-05 18:30:19', 1, 0),
(13, 1, NULL, 'sales', NULL, 'Makeup & Beauty Products', '2025-02-05 18:30:19', '2025-02-05 18:30:19', 1, 0),
(14, 1, NULL, 'sales', NULL, 'Professional & Spa Equipment', '2025-02-05 18:30:19', '2025-02-05 18:30:19', 1, 0),
(15, 2, NULL, 'service', 'Clothing & Fashion Services', NULL, '2025-02-05 18:31:52', '2025-02-05 18:31:52', 1, 0),
(16, 2, NULL, 'service', 'Alteration & Repair Services', NULL, '2025-02-05 18:33:41', '2025-02-05 18:33:41', 1, 0),
(17, 2, NULL, 'service', 'Embroidery & Handwork Services', NULL, '2025-02-05 18:33:41', '2025-02-05 18:33:41', 1, 0),
(18, 2, NULL, 'service', 'Customization & Personalization Services', NULL, '2025-02-05 18:33:41', '2025-02-05 18:33:41', 1, 0),
(19, 2, NULL, 'service', 'Accessory & Styling Services', NULL, '2025-02-05 18:33:41', '2025-02-05 18:33:41', 1, 0),
(20, 2, NULL, 'service', 'Luxury & Premium Services', NULL, '2025-02-05 18:33:41', '2025-02-05 18:33:41', 1, 0),
(21, 2, NULL, 'sales', NULL, 'Clothing & Apparel', '2025-02-05 18:34:21', '2025-02-05 18:34:21', 1, 0),
(22, 2, NULL, 'sales', NULL, 'Fabric & Materials', '2025-02-05 18:35:38', '2025-02-05 18:35:38', 1, 0),
(23, 2, NULL, 'sales', NULL, 'Accessories', '2025-02-05 18:35:38', '2025-02-05 18:35:38', 1, 0),
(24, 2, NULL, 'sales', NULL, 'Customization & Embellishments', '2025-02-05 18:35:38', '2025-02-05 18:35:38', 1, 0),
(25, 2, NULL, 'sales', NULL, 'Home & Lifestyle', '2025-02-05 18:35:38', '2025-02-05 18:35:38', 1, 0),
(26, 4, 1, 'sales', NULL, 'Fresh & Live Fish', '2025-02-05 18:38:01', '2025-02-05 18:38:01', 1, 0),
(27, 4, 1, 'sales', NULL, 'Frozen & Processed Fish', '2025-02-05 18:39:01', '2025-02-05 18:39:01', 1, 0),
(28, 4, 1, 'sales', NULL, 'Seafood & Shellfish', '2025-02-05 18:39:01', '2025-02-05 18:39:01', 1, 0),
(29, 4, 1, 'sales', NULL, 'Fish By-Products & Specialty', '2025-02-05 18:39:01', '2025-02-05 18:39:01', 1, 0),
(30, 3, NULL, 'service', 'Customization & Personalization Services', NULL, '2025-02-06 14:09:44', '2025-02-06 14:09:44', 1, 0),
(31, 3, NULL, 'service', 'Gift Wrapping & Packaging Services', NULL, '2025-02-06 14:12:04', '2025-02-06 14:12:04', 1, 0),
(32, 3, NULL, 'service', 'Special Event Gifts & Decorations', NULL, '2025-02-06 14:12:04', '2025-02-06 14:12:04', 1, 0),
(33, 3, NULL, 'service', 'Same-Day & Midnight Gift Delivery Services', NULL, '2025-02-06 14:12:04', '2025-02-06 14:12:04', 1, 0),
(34, 3, NULL, 'service', 'DIY & Handmade Gift Services', NULL, '2025-02-06 14:12:04', '2025-02-06 14:12:04', 1, 0),
(35, 3, NULL, 'service', 'Gift Solutioning Service', NULL, '2025-02-06 14:12:04', '2025-02-06 14:12:04', 1, 0),
(36, 3, NULL, 'service', 'Home Decor Service', NULL, '2025-02-06 14:12:04', '2025-02-06 14:12:04', 1, 0),
(37, 3, NULL, 'sales', NULL, 'Personalized Gifts', '2025-02-06 14:12:58', '2025-02-06 14:12:58', 1, 0),
(38, 3, NULL, 'sales', NULL, 'Greeting Cards & Stationery', '2025-02-06 14:14:52', '2025-02-06 14:14:52', 1, 0),
(39, 3, NULL, 'sales', NULL, 'Home Décor & Handicrafts', '2025-02-06 14:14:52', '2025-02-06 14:14:52', 1, 0),
(40, 3, NULL, 'sales', NULL, 'Festive & Corporate Gifts', '2025-02-06 14:14:52', '2025-02-06 14:14:52', 1, 0),
(41, 3, NULL, 'sales', NULL, 'Toys & Soft Toys', '2025-02-06 14:14:52', '2025-02-06 14:14:52', 1, 0),
(42, 3, NULL, 'sales', NULL, 'Fashion & Accessories', '2025-02-06 14:14:52', '2025-02-06 14:14:52', 1, 0),
(43, 3, NULL, 'sales', NULL, 'Cakes & Chocolates', '2025-02-06 14:14:52', '2025-02-06 14:14:52', 1, 0),
(44, 4, 2, 'service', 'Software Maintanance', NULL, '2025-02-06 14:40:45', '2025-02-06 14:40:45', 1, 0),
(45, 4, 2, 'service', 'Software Migration', NULL, '2025-02-06 14:41:52', '2025-02-06 14:41:52', 1, 0),
(46, 4, 2, 'service', 'Upgradation & Backups', NULL, '2025-02-06 14:41:52', '2025-02-06 14:41:52', 1, 0),
(47, 4, 2, 'sales', NULL, 'ERP', '2025-02-06 14:42:41', '2025-02-06 14:42:41', 1, 0),
(48, 4, 2, 'sales', NULL, 'CRM', '2025-02-06 14:43:21', '2025-02-06 14:43:21', 1, 0),
(49, 4, 2, 'sales', NULL, 'Antivirus', '2025-02-06 14:43:21', '2025-02-06 14:43:21', 1, 0),
(50, 4, 3, 'sales', NULL, 'Fresh Fruits', '2025-02-06 14:44:17', '2025-02-06 14:44:17', 1, 0),
(51, 4, 3, 'sales', NULL, 'Fresh Vegetables', '2025-02-06 14:45:35', '2025-02-06 14:45:35', 1, 0),
(52, 4, 3, 'sales', NULL, 'Organic & Specialty Produce', '2025-02-06 14:45:35', '2025-02-06 14:45:35', 1, 0),
(53, 4, 3, 'sales', NULL, 'Frozen & Processed Fruits & Vegetables', '2025-02-06 14:45:35', '2025-02-06 14:45:35', 1, 0),
(54, 4, 3, 'sales', NULL, 'Juice & Beverage Industry', '2025-02-06 14:45:35', '2025-02-06 14:45:35', 1, 0),
(55, 4, 4, 'sales', NULL, 'Skincare Products', '2025-02-06 14:46:51', '2025-02-06 14:46:51', 1, 0),
(56, 4, 4, 'sales', NULL, 'Haircare Products', '2025-02-06 14:48:52', '2025-02-06 14:48:52', 1, 0),
(57, 4, 4, 'sales', NULL, 'Body Care Products', '2025-02-06 14:48:52', '2025-02-06 14:48:52', 1, 0),
(58, 4, 4, 'sales', NULL, 'Makeup & Cosmetics', '2025-02-06 14:48:52', '2025-02-06 14:48:52', 1, 0),
(59, 4, 4, 'sales', NULL, 'Personal Hygiene ', '2025-02-06 14:48:52', '2025-02-06 14:48:52', 1, 0),
(60, 4, 4, 'sales', NULL, 'Natural & Organic Beauty Products', '2025-02-06 14:48:52', '2025-02-06 14:48:52', 1, 0),
(61, 4, 4, 'sales', NULL, 'Healthcare & Wellness', '2025-02-06 14:48:52', '2025-02-06 14:48:52', 1, 0),
(62, 4, 4, 'sales', NULL, 'Men’s Grooming', '2025-02-06 14:48:52', '2025-02-06 14:48:52', 1, 0),
(63, 4, 4, 'sales', NULL, 'Salon & Professional Beauty Products', '2025-02-06 14:48:52', '2025-02-06 14:48:52', 1, 0),
(64, 4, 5, 'sales', NULL, 'Men’s Clothing', '2025-02-06 14:49:59', '2025-02-06 14:49:59', 1, 0),
(65, 4, 5, 'sales', NULL, 'Women’s Clothing', '2025-02-06 14:52:34', '2025-02-06 14:52:34', 1, 0),
(66, 4, 5, 'sales', NULL, 'Kids’ Clothing', '2025-02-06 14:52:34', '2025-02-06 14:52:34', 1, 0),
(67, 4, 5, 'sales', NULL, 'Seasonal Clothing', '2025-02-06 14:52:34', '2025-02-06 14:52:34', 1, 0),
(68, 4, 5, 'sales', NULL, 'Workwear & Uniform', '2025-02-06 14:52:34', '2025-02-06 14:52:34', 1, 0),
(69, 4, 5, 'sales', NULL, 'Sportswear & Activewear', '2025-02-06 14:52:34', '2025-02-06 14:52:34', 1, 0),
(70, 4, 5, 'sales', NULL, 'Undergarments & Lingerie', '2025-02-06 14:52:34', '2025-02-06 14:52:34', 1, 0),
(71, 4, 5, 'sales', NULL, 'Fashion Accessories', '2025-02-06 14:52:34', '2025-02-06 14:52:34', 1, 0),
(72, 4, 5, 'sales', NULL, 'Footwear', '2025-02-06 14:52:34', '2025-02-06 14:52:34', 1, 0),
(73, 4, 5, 'sales', NULL, 'Fabric & Textile', '2025-02-06 14:52:34', '2025-02-06 14:52:34', 1, 0),
(74, 4, 6, 'sales', NULL, 'Fresh Produce', '2025-02-06 14:53:32', '2025-02-06 14:53:32', 1, 0),
(75, 4, 6, 'sales', NULL, 'Dairy Products', '2025-02-06 14:56:28', '2025-02-06 14:56:28', 1, 0),
(76, 4, 6, 'sales', NULL, 'Meat & Poultry', '2025-02-06 14:56:28', '2025-02-06 14:56:28', 1, 0),
(77, 4, 6, 'sales', NULL, 'Frozen Food', '2025-02-06 14:56:28', '2025-02-06 14:56:28', 1, 0),
(78, 4, 6, 'sales', NULL, 'Packaged & Processed Food', '2025-02-06 14:56:28', '2025-02-06 14:56:28', 1, 0),
(79, 4, 6, 'sales', NULL, 'Bakery Products', '2025-02-06 14:56:28', '2025-02-06 14:56:28', 1, 0),
(80, 4, 6, 'sales', NULL, 'Beverages', '2025-02-06 14:56:28', '2025-02-06 14:56:28', 1, 0),
(81, 4, 6, 'sales', NULL, 'Spices & Condiments', '2025-02-06 14:56:28', '2025-02-06 14:56:28', 1, 0),
(82, 4, 6, 'sales', NULL, 'Organic & Health Food', '2025-02-06 14:56:28', '2025-02-06 14:56:28', 1, 0),
(83, 4, 6, 'sales', NULL, 'Baby & Infant Food', '2025-02-06 14:56:28', '2025-02-06 14:56:28', 1, 0),
(84, 4, 6, 'sales', NULL, 'Gourmet & Specialty Foods', '2025-02-06 14:56:28', '2025-02-06 14:56:28', 1, 0),
(85, 4, 6, 'sales', NULL, 'Health & Dietary Food', '2025-02-06 14:56:28', '2025-02-06 14:56:28', 1, 0),
(86, 5, NULL, 'sales', NULL, 'Laptop', '2025-02-06 15:00:22', '2025-02-06 15:00:22', 1, 0),
(87, 5, NULL, 'sales', NULL, 'Accessories', '2025-02-06 15:02:01', '2025-02-06 15:02:01', 1, 0),
(88, 5, NULL, 'sales', NULL, 'Software', '2025-02-06 15:02:01', '2025-02-06 15:02:01', 1, 0),
(89, 5, NULL, 'sales', NULL, 'Desktop', '2025-02-06 15:02:01', '2025-02-06 15:02:01', 1, 0),
(90, 5, NULL, 'sales', NULL, 'TAB', '2025-02-06 15:02:01', '2025-02-06 15:02:01', 1, 0),
(91, 5, NULL, 'service', 'Repair', NULL, '2025-02-06 15:03:02', '2025-02-06 15:03:02', 1, 0),
(92, 5, NULL, 'service', 'Software upgrade', NULL, '2025-02-06 15:03:45', '2025-02-06 15:03:45', 1, 0),
(93, 5, NULL, 'service', 'Backup', NULL, '2025-02-06 15:03:45', '2025-02-06 15:03:45', 1, 0),
(94, 5, NULL, 'both', 'Hardware upgrade', 'Hardware upgrade', '2025-02-06 15:04:51', '2025-02-06 15:04:51', 1, 0),
(95, 5, NULL, 'both', 'Others', 'Others', '2025-02-06 15:04:51', '2025-02-06 15:04:51', 1, 0),
(96, 6, 7, 'service', 'Mobile & Tablet Repair', NULL, '2025-02-06 15:11:51', '2025-02-06 15:11:51', 1, 0),
(97, 6, 7, 'service', 'Home Appliances Repair', NULL, '2025-02-06 15:12:33', '2025-02-06 15:12:33', 1, 0),
(98, 6, 7, 'service', 'Electronics Equipment Repair', NULL, '2025-02-06 15:12:33', '2025-02-06 15:12:33', 1, 0),
(99, 6, 8, 'service', 'Tire Repair & Replacement', NULL, '2025-02-06 15:16:37', '2025-02-06 15:16:37', 1, 0),
(100, 6, 8, 'service', 'Battery  & Charging', NULL, '2025-02-06 15:16:37', '2025-02-06 15:16:37', 1, 0),
(101, 6, 8, 'service', 'Body shop', NULL, '2025-02-06 15:16:37', '2025-02-06 15:16:37', 1, 0),
(102, 6, 9, 'service', 'Pipe & Drainage', NULL, '2025-02-06 15:17:45', '2025-02-06 15:17:45', 1, 0),
(103, 6, 9, 'service', 'Sump & water line', NULL, '2025-02-06 15:17:45', '2025-02-06 15:17:45', 1, 0),
(104, 6, 10, 'service', 'Lighting & Electrical Fixtures Repair', NULL, '2025-02-06 15:18:32', '2025-02-06 15:18:32', 1, 0),
(105, 6, 10, 'service', 'Smart Home Installation & Repair', NULL, '2025-02-06 15:19:05', '2025-02-06 15:19:05', 1, 0),
(106, 6, 10, 'service', 'Generator Repair & Maintenance', NULL, '2025-02-06 15:19:05', '2025-02-06 15:19:05', 1, 0),
(107, 6, 11, 'service', 'Air Conditioner Repair & Maintenance', NULL, '2025-02-06 15:19:44', '2025-02-06 15:19:44', 1, 0),
(108, 6, 11, 'service', 'Ventilation System Repair', NULL, '2025-02-06 15:19:59', '2025-02-06 15:19:59', 1, 0),
(109, 6, 12, 'service', 'Furniture Repair', NULL, '2025-02-06 15:20:57', '2025-02-06 15:20:57', 1, 0),
(110, 6, 12, 'service', 'Flooring Services (Tile, Hardwood, Laminate)', NULL, '2025-02-06 15:21:29', '2025-02-06 15:21:29', 1, 0),
(111, 6, 12, 'service', 'Wall paininting & Wallpaper', NULL, '2025-02-06 15:21:29', '2025-02-06 15:21:29', 1, 0),
(112, 6, 13, NULL, 'Deep Cleaning Services', NULL, '2025-02-06 15:22:11', '2025-02-06 15:22:11', 1, 0),
(113, 6, 13, NULL, 'Office Cleaning', NULL, '2025-02-06 15:22:54', '2025-02-06 15:22:54', 1, 0),
(114, 6, 13, NULL, 'Post-Event Cleaning', NULL, '2025-02-06 15:22:54', '2025-02-06 15:22:54', 1, 0),
(115, 6, 13, NULL, 'Pest Control Services', NULL, '2025-02-06 15:22:54', '2025-02-06 15:22:54', 1, 0),
(116, 7, NULL, 'service', 'Property Buying & Selling', NULL, '2025-02-06 15:23:23', '2025-02-06 15:23:23', 1, 0),
(117, 7, NULL, 'service', 'Property Renting & Leasing', NULL, '2025-02-06 15:24:27', '2025-02-06 15:24:27', 1, 0),
(118, 7, NULL, 'service', 'Property Management Services', NULL, '2025-02-06 15:24:27', '2025-02-06 15:24:27', 1, 0),
(119, 7, NULL, 'service', 'Real Estate Development', NULL, '2025-02-06 15:24:27', '2025-02-06 15:24:27', 1, 0),
(120, 7, NULL, 'service', 'Property Marketing & Advertising', NULL, '2025-02-06 15:24:27', '2025-02-06 15:24:27', 1, 0),
(121, 8, NULL, 'service', 'Eye Check-up/ consultation', NULL, '2025-04-09 09:34:39', '2025-04-09 09:34:39', 1, 0),
(122, 8, NULL, 'service', 'Lens Replacement Services', NULL, '2025-04-09 09:34:39', '2025-04-09 09:34:39', 1, 0),
(123, 8, NULL, 'service', 'Frame Repair & Adjustment Services', NULL, '2025-04-09 09:34:39', '2025-04-09 09:34:39', 1, 0),
(124, 8, NULL, 'sales', NULL, 'Spectacles ', '2025-04-09 09:34:39', '2025-04-09 09:34:39', 1, 0),
(125, 8, NULL, 'sales', NULL, 'Sunglasses', '2025-04-09 09:34:39', '2025-04-09 09:34:39', 1, 0),
(126, 9, 14, 'service', 'Veterinary Services', NULL, '2025-04-09 09:36:29', '2025-04-09 09:36:29', 1, 0),
(127, 9, 14, 'service', 'Surgical Services', NULL, '2025-04-09 09:36:29', '2025-04-09 09:36:29', 1, 0),
(128, 9, 14, 'service', 'Home Visit Services', NULL, '2025-04-09 09:36:29', '2025-04-09 09:36:29', 1, 0),
(129, 9, 15, 'service', 'Pet Grooming', NULL, '2025-04-09 09:39:45', '2025-04-09 09:39:45', 1, 0),
(130, 9, 15, 'service', 'Preventive Care Packages', NULL, '2025-04-09 09:39:45', '2025-04-09 09:39:45', 1, 0),
(131, 9, 15, 'service', 'Dental Care', NULL, '2025-04-09 09:39:45', '2025-04-09 09:39:45', 1, 0),
(132, 9, 15, 'service', 'Specialized Care', NULL, '2025-04-09 09:39:45', '2025-04-09 09:39:45', 1, 0),
(133, 9, 15, 'service', 'Boarding & Daycare', NULL, '2025-04-09 09:39:45', '2025-04-09 09:39:45', 1, 0),
(134, 9, 15, 'sales', NULL, 'Pet Medications', '2025-04-09 09:41:50', '2025-04-09 09:41:50', 1, 0),
(135, 9, 15, 'sales', NULL, 'Pet Food & Nutrition', '2025-04-09 09:41:50', '2025-04-09 09:41:50', 1, 0),
(136, 9, 15, 'sales', NULL, 'Pet Accessories', '2025-04-09 09:41:50', '2025-04-09 09:41:50', 1, 0),
(137, 9, 15, 'sales', NULL, 'Pet Grooming Products', '2025-04-09 09:41:50', '2025-04-09 09:41:50', 1, 0),
(138, 9, 15, 'sales', NULL, 'Health & Hygiene', '2025-04-09 09:41:50', '2025-04-09 09:41:50', 1, 0),
(139, 9, 15, 'sales', NULL, 'First Aid & Wellness', '2025-04-09 09:41:50', '2025-04-09 09:41:50', 1, 0),
(140, 10, NULL, 'service', 'Birthday Parties', NULL, '2025-04-09 09:45:51', '2025-04-09 09:45:51', 1, 0),
(141, 10, NULL, 'service', 'Marriage Function', NULL, '2025-04-09 09:45:51', '2025-04-09 09:45:51', 1, 0),
(142, 10, NULL, 'service', 'Puberty Function', NULL, '2025-04-09 09:45:51', '2025-04-09 09:45:51', 1, 0),
(143, 10, NULL, 'service', 'House Warming', NULL, '2025-04-09 09:45:51', '2025-04-09 09:45:51', 1, 0),
(144, 10, NULL, 'service', 'Sangeet Functions', NULL, '2025-04-09 09:45:51', '2025-04-09 09:45:51', 1, 0),
(145, 10, NULL, 'service', 'Mehendi Functions, Corporate Events', NULL, '2025-04-09 09:45:51', '2025-04-09 09:45:51', 1, 0),
(146, 10, NULL, 'service', 'Kerala drums, Band , dhol player\'s & thappu melam', NULL, '2025-04-09 09:45:51', '2025-04-09 09:45:51', 1, 0),
(147, 10, NULL, 'service', 'Dj music,dance show & Light Music', NULL, '2025-04-09 09:45:51', '2025-04-09 09:45:51', 1, 0),
(148, 10, NULL, 'service', 'Karaoke', NULL, '2025-04-09 09:45:51', '2025-04-09 09:45:51', 1, 0),
(149, 10, NULL, 'service', 'Decorations for all functions', NULL, '2025-04-09 09:45:51', '2025-04-09 09:45:51', 1, 0),
(150, 10, NULL, 'service', 'Catering service & fruit stalls', NULL, '2025-04-09 09:45:51', '2025-04-09 09:45:51', 1, 0),
(151, 10, NULL, 'service', 'Photography & Videographers', NULL, '2025-04-09 09:45:51', '2025-04-09 09:45:51', 1, 0),
(152, 10, NULL, 'service', 'Magic Show', NULL, '2025-04-09 09:45:51', '2025-04-09 09:45:51', 1, 0),
(153, 10, NULL, 'service', 'Variety dance perform', NULL, '2025-04-09 09:45:51', '2025-04-09 09:45:51', 1, 0),
(154, 10, NULL, 'service', 'Instant photo', NULL, '2025-04-09 09:45:51', '2025-04-09 09:45:51', 1, 0),
(155, 10, NULL, 'sales', NULL, 'Speaker, Mike, Projector & Led screen', '2025-04-09 09:46:39', '2025-04-09 09:46:39', 1, 0),
(156, 4, 19, 'sales', NULL, 'Allen Bolt', '2025-04-24 09:17:39', '2025-04-24 09:17:39', 1, 0),
(157, 4, 19, 'sales', NULL, 'B7 Studs', '2025-04-24 09:17:39', '2025-04-24 09:17:39', 1, 0),
(158, 4, 19, 'sales', NULL, 'Ball Studs', '2025-04-24 09:17:39', '2025-04-24 09:17:39', 1, 0),
(159, 4, 19, 'sales', NULL, 'Button Head', '2025-04-24 09:17:39', '2025-04-24 09:17:39', 1, 0),
(160, 4, 19, 'sales', NULL, 'Carriage Bolt', '2025-04-24 09:17:39', '2025-04-24 09:17:39', 1, 0),
(161, 4, 19, 'sales', NULL, 'Collar Bolt', '2025-04-24 09:17:39', '2025-04-24 09:17:39', 1, 0),
(162, 4, 19, 'sales', NULL, 'Double Ended Studs', '2025-04-24 09:17:39', '2025-04-24 09:17:39', 1, 0),
(163, 4, 19, 'sales', NULL, 'Dowel Pin', '2025-04-24 09:17:39', '2025-04-24 09:17:39', 1, 0),
(164, 4, 19, 'sales', NULL, 'Flat Head Bolt', '2025-04-24 09:17:39', '2025-04-24 09:17:39', 1, 0),
(165, 4, 19, 'sales', NULL, 'Hex Flange Bolt', '2025-04-24 09:17:39', '2025-04-24 09:17:39', 1, 0),
(166, 4, 19, 'sales', NULL, 'Hex Head Bolt', '2025-04-24 09:17:39', '2025-04-24 09:17:39', 1, 0),
(167, 4, 19, 'sales', NULL, 'HSFG Bolt', '2025-04-24 09:17:39', '2025-04-24 09:17:39', 1, 0),
(168, 4, 19, 'sales', NULL, 'HUB', '2025-04-24 09:17:39', '2025-04-24 09:17:39', 1, 0),
(169, 4, 19, 'sales', NULL, 'Railway T Bolt', '2025-04-24 09:17:39', '2025-04-24 09:17:39', 1, 0),
(170, 4, 19, 'sales', NULL, 'Round Head Knurling Bolt', '2025-04-24 09:19:35', '2025-04-24 09:19:35', 1, 0),
(171, 4, 19, 'sales', NULL, 'Round Head Rivets', '2025-04-24 09:19:35', '2025-04-24 09:19:35', 1, 0),
(172, 4, 19, 'sales', NULL, 'Shoulder Bolt', '2025-04-24 09:19:35', '2025-04-24 09:19:35', 1, 0),
(173, 4, 19, 'sales', NULL, 'Shoulder Bolt Not SPCL', '2025-04-24 09:19:35', '2025-04-24 09:19:35', 1, 0),
(174, 4, 19, 'sales', NULL, 'Socket Head Cap Screw', '2025-04-24 09:19:35', '2025-04-24 09:19:35', 1, 0),
(175, 4, 19, 'sales', NULL, 'Square Step Bolt', '2025-04-24 09:19:35', '2025-04-24 09:19:35', 1, 0),
(176, 4, 19, 'sales', NULL, 'Track Shoe Bolt', '2025-04-24 09:19:35', '2025-04-24 09:19:35', 1, 0),
(177, 4, 19, 'sales', NULL, 'Trcator Rim Bolt', '2025-04-24 09:19:35', '2025-04-24 09:19:35', 1, 0),
(178, 4, 19, 'sales', NULL, 'Weld Bolt', '2025-04-24 09:19:35', '2025-04-24 09:19:35', 1, 0),
(179, 4, 2, 'sales', NULL, 'Startup Ecommerce', '2025-05-01 20:46:39', '2025-05-01 20:46:39', 1, 0),
(180, 4, 2, 'sales', NULL, 'Cloud Billing Solutions', '2025-05-01 20:46:39', '2025-05-01 20:46:39', 1, 0),
(181, 4, 2, 'sales', NULL, 'Simple Billing Solutions', '2025-05-01 20:46:39', '2025-05-01 20:46:39', 1, 0),
(182, 4, 2, 'service', 'Websites/Web Apps', NULL, '2025-05-01 20:49:24', '2025-05-01 20:49:24', 1, 0),
(183, 4, 2, 'service', 'Mobile Apps', NULL, '2025-05-01 20:49:24', '2025-05-01 20:49:24', 1, 0),
(184, 4, 2, 'service', 'Custom Applications', NULL, '2025-05-01 20:49:24', '2025-05-01 20:49:24', 1, 0),
(185, 4, 2, 'service', 'Servers and Maintenances', NULL, '2025-05-01 20:49:24', '2025-05-01 20:49:24', 1, 0),
(186, 4, 2, 'service', 'Digital Marketing - SEO, Google Ads, Influencer Marketing', NULL, '2025-05-01 20:49:24', '2025-05-01 20:49:24', 1, 0),
(187, 4, 2, 'service', 'Social Media managemnents', NULL, '2025-05-01 20:49:24', '2025-05-01 20:49:24', 1, 0),
(188, 4, 2, 'service', 'Business consulting', NULL, '2025-05-01 20:49:24', '2025-05-01 20:49:24', 1, 0),
(189, 13, NULL, 'service', 'Dry cleaning of suits, dresses, coats, etc.', NULL, '2025-05-26 13:21:56', '2025-05-26 13:21:56', 1, 0),
(190, 13, NULL, 'service', 'Spot and stain removal', NULL, '2025-05-26 13:21:56', '2025-05-26 13:21:56', 1, 0),
(191, 13, NULL, 'service', 'Pressing and steam ironing', NULL, '2025-05-26 13:21:56', '2025-05-26 13:21:56', 1, 0),
(192, 13, NULL, 'service', 'Delicate fabric care (silk, wool, satin, etc.)', NULL, '2025-05-26 13:21:56', '2025-05-26 13:21:56', 1, 0),
(193, 13, NULL, 'service', 'Formal wear cleaning (tuxedos, gowns)', NULL, '2025-05-26 13:21:56', '2025-05-26 13:21:56', 1, 0),
(194, 13, NULL, 'service', 'Wedding dress cleaning and preservation', NULL, '2025-05-26 13:21:56', '2025-05-26 13:21:56', 1, 0),
(195, 13, NULL, 'service', 'Leather and suede cleaning', NULL, '2025-05-26 13:21:56', '2025-05-26 13:21:56', 1, 0),
(196, 13, NULL, 'service', 'Curtain and drapery cleaning', NULL, '2025-05-26 13:21:56', '2025-05-26 13:21:56', 1, 0),
(197, 13, NULL, 'service', 'Comforter and duvet cleaning', NULL, '2025-05-26 13:21:56', '2025-05-26 13:21:56', 1, 0),
(198, 13, NULL, 'service', 'Blinds cleaning', NULL, '2025-05-26 13:21:56', '2025-05-26 13:21:56', 1, 0),
(199, 13, NULL, 'service', 'Uniform cleaning (military, police, etc.)', NULL, '2025-05-26 13:21:56', '2025-05-26 13:21:56', 1, 0),
(200, 13, NULL, 'service', 'Business attire cleaning', NULL, '2025-05-26 13:21:56', '2025-05-26 13:21:56', 1, 0),
(201, 8, NULL, 'sales', NULL, 'Kids Eyewear', '2025-07-02 11:49:03', '2025-07-02 11:49:03', 1, 0),
(202, 8, NULL, 'sales', NULL, 'Designer/Branded Frames & Lenses', '2025-07-02 11:49:03', '2025-07-02 11:49:03', 1, 0),
(203, 8, NULL, 'sales', NULL, 'Photochromic / Transition Lenses', '2025-07-02 11:49:03', '2025-07-02 11:49:03', 1, 0),
(204, 8, NULL, 'sales', NULL, 'Contact Lenses', '2025-07-02 11:49:03', '2025-07-02 11:49:03', 1, 0),
(205, 8, NULL, 'sales', NULL, 'Anti-Reflective Coating Lenses', '2025-07-02 11:49:03', '2025-07-02 11:49:03', 1, 0),
(206, 4, 20, 'sales', NULL, 'Pipe', '2025-07-05 12:42:38', '2025-07-05 12:42:38', 1, 0);

-- --------------------------------------------------------

--
-- Table structure for table `service-catalogs`
--

CREATE TABLE `service-catalogs` (
  `id` int(10) UNSIGNED NOT NULL,
  `title` text DEFAULT NULL,
  `category_name` varchar(255) DEFAULT NULL,
  `image` text DEFAULT NULL,
  `price` decimal(10,2) DEFAULT NULL,
  `offer` decimal(10,2) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `gst_percentage` varchar(255) DEFAULT NULL,
  `employee_percentage` decimal(10,2) DEFAULT NULL,
  `status` tinyint(1) NOT NULL DEFAULT 1,
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `service-catalogs`
--

INSERT INTO `service-catalogs` (`id`, `title`, `category_name`, `image`, `price`, `offer`, `description`, `gst_percentage`, `employee_percentage`, `status`, `is_deleted`, `created_at`, `updated_at`) VALUES
(1, 'Bridal wear', 'Clothing & fashion services', 'non_prod_tenant_3/service-catalogs/hOlaYYwt83y31LlBs6UpsHHSJSmBBm53b9Rvf3vg.jpg', 6500.00, 5999.00, 'test', '12%', NULL, 1, 0, '2025-08-12 06:44:28', '2025-08-12 06:44:28'),
(2, 'Bridal wear', 'Alteration & repair services', 'non_prod_tenant_3/service-catalogs/fDVb07UYGU769MnVnNL6WBIC2b1ndZIBvjbWBuOO.jpg', 6580.00, 5648.00, NULL, '5%', NULL, 1, 0, '2025-08-12 06:45:14', '2025-08-12 06:45:14');

-- --------------------------------------------------------

--
-- Table structure for table `sessions`
--

CREATE TABLE `sessions` (
  `id` varchar(255) NOT NULL,
  `user_id` bigint(20) UNSIGNED DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` text DEFAULT NULL,
  `payload` longtext NOT NULL,
  `last_activity` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `sessions`
--

INSERT INTO `sessions` (`id`, `user_id`, `ip_address`, `user_agent`, `payload`, `last_activity`) VALUES
('FSVbdbEtWAj5BxIzJ7zorj9SGPKuW5kMtBGoPi7I', 19, '127.0.0.1', 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36', 'YTo0OntzOjY6Il90b2tlbiI7czo0MDoiU25kQkczWFhSNXdLWVRYMDhsTTRzSjJMTHVySG51Uko4dzNQWVh6MyI7czo5OiJfcHJldmlvdXMiO2E6MTp7czozOiJ1cmwiO3M6NDM6Imh0dHA6Ly9sb2NhbGhvc3Q6ODAwMS9zdXBlci1hZG1pbi1kYXNoYm9hcmQiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX1zOjUwOiJsb2dpbl93ZWJfNTliYTM2YWRkYzJiMmY5NDAxNTgwZjAxNGM3ZjU4ZWE0ZTMwOTg5ZCI7aToxOTt9', 1721937215),
('GVXdRhxTHJseUqyWuSJ6V4R61I6hJ8XIMCJKHdYd', NULL, '127.0.0.1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36', 'YTo0OntzOjY6Il90b2tlbiI7czo0MDoiVmZyVHVRNkpadEZrQXMzTnJMcGl5bW5tR2ZZZzg0dkhQYmxYNVRURSI7czozOiJ1cmwiO2E6MTp7czo4OiJpbnRlbmRlZCI7czo0MzoiaHR0cDovLzEyNy4wLjAuMTo4MDAwL3N1cGVyLWFkbWluLWRhc2hib2FyZCI7fXM6OToiX3ByZXZpb3VzIjthOjE6e3M6MzoidXJsIjtzOjMzOiJodHRwOi8vMTI3LjAuMC4xOjgwMDAvYWRtaW4vbG9naW4iO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19', 1721924271),
('RCwsAwZJfxLm4Is4tc8znZD9yDpfwRiXG8Lc0EDd', 19, '127.0.0.1', 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36', 'YTo0OntzOjY6Il90b2tlbiI7czo0MDoiVzBQNEttTkhUUXlUcEJrNE82N2psTFYzMERybHFnb3JUMXNoVjl4TSI7czo2OiJfZmxhc2giO2E6Mjp7czozOiJvbGQiO2E6MDp7fXM6MzoibmV3IjthOjA6e319czo5OiJfcHJldmlvdXMiO2E6MTp7czozOiJ1cmwiO3M6NDM6Imh0dHA6Ly9sb2NhbGhvc3Q6ODAwMC9zdXBlci1hZG1pbi1kYXNoYm9hcmQiO31zOjUwOiJsb2dpbl93ZWJfNTliYTM2YWRkYzJiMmY5NDAxNTgwZjAxNGM3ZjU4ZWE0ZTMwOTg5ZCI7aToxOTt9', 1721928794);

-- --------------------------------------------------------

--
-- Table structure for table `size_master`
--

CREATE TABLE `size_master` (
  `id` int(11) NOT NULL,
  `size` varchar(100) DEFAULT NULL,
  `status` tinyint(1) NOT NULL DEFAULT 1,
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `size_master`
--

INSERT INTO `size_master` (`id`, `size`, `status`, `is_deleted`, `created_at`, `updated_at`) VALUES
(1, 'Small', 1, 0, '2025-06-16 17:16:50', '2025-06-16 17:16:50'),
(2, 'Large', 1, 0, '2025-06-16 17:16:50', '2025-06-16 17:16:50');

-- --------------------------------------------------------

--
-- Table structure for table `stages`
--

CREATE TABLE `stages` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `name` varchar(255) NOT NULL,
  `type` varchar(255) NOT NULL,
  `status` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `stages`
--

INSERT INTO `stages` (`id`, `name`, `type`, `status`, `created_at`, `updated_at`) VALUES
(1, 'Stitching', 'design', 1, '2025-07-29 10:47:34', '2025-07-29 10:47:34'),
(2, 'Cutting', 'design', 1, '2025-07-29 10:47:34', '2025-07-29 10:47:34'),
(3, 'Finishing', 'design', 1, '2025-07-29 10:47:34', '2025-07-29 10:47:34'),
(4, 'Embroidery', 'pattern', 1, '2025-07-29 10:47:34', '2025-07-29 10:47:34');

-- --------------------------------------------------------

--
-- Table structure for table `states`
--

CREATE TABLE `states` (
  `id` int(11) NOT NULL,
  `state_name` varchar(255) NOT NULL,
  `country_id` int(11) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp(),
  `status` int(11) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `states`
--

INSERT INTO `states` (`id`, `state_name`, `country_id`, `created_at`, `updated_at`, `status`) VALUES
(1, 'Karnataka', 91, '2024-07-28 07:32:32', '2024-08-03 16:22:32', 1),
(3, 'Uttarakhand', 91, '2024-07-28 07:18:09', '2024-07-28 07:32:18', 0);

-- --------------------------------------------------------

--
-- Table structure for table `status`
--

CREATE TABLE `status` (
  `id` int(11) NOT NULL,
  `business_id` varchar(255) DEFAULT 'ALL',
  `name` varchar(250) NOT NULL,
  `status` tinyint(4) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp(),
  `is_deleted` int(11) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `status`
--

INSERT INTO `status` (`id`, `business_id`, `name`, `status`, `created_at`, `updated_at`, `is_deleted`) VALUES
(1, 'ALL', 'Schedule', 1, '2024-11-11 16:27:49', '2024-11-11 16:27:49', 0),
(2, 'ALL', 'Followup', 1, '2024-11-11 16:28:16', '2024-11-11 16:28:16', 0),
(3, 'ALL', 'Hold', 1, '2024-11-11 16:28:24', '2024-11-11 16:28:24', 0),
(4, 'ALL', 'Service/ProductPurchased', 1, '2024-11-18 09:51:13', '2024-11-18 09:51:13', 0);

-- --------------------------------------------------------

--
-- Table structure for table `statuses`
--

CREATE TABLE `statuses` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `name` varchar(255) NOT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `statuses`
--

INSERT INTO `statuses` (`id`, `name`, `created_at`, `updated_at`) VALUES
(1, 'Pending', '2025-07-29 10:45:27', '2025-07-29 10:45:27'),
(2, 'In Process', '2025-07-29 10:45:27', '2025-07-29 10:45:27'),
(3, 'Dispatched', '2025-07-29 10:45:27', '2025-07-29 10:45:27'),
(4, 'Delivered', '2025-07-29 10:45:27', '2025-07-29 10:45:27'),
(5, 'Cancelled', '2025-07-29 10:45:27', '2025-07-29 10:45:27'),
(6, 'Held', '2025-07-29 10:45:27', '2025-07-29 10:45:27');

-- --------------------------------------------------------

--
-- Table structure for table `sync_requests`
--

CREATE TABLE `sync_requests` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `tenant_id` bigint(20) NOT NULL,
  `tenant_schema` varchar(255) NOT NULL,
  `contact` tinyint(1) NOT NULL DEFAULT 0,
  `call_history` tinyint(1) NOT NULL DEFAULT 0,
  `status` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `sync_requests`
--

INSERT INTO `sync_requests` (`id`, `tenant_id`, `tenant_schema`, `contact`, `call_history`, `status`, `created_at`, `updated_at`) VALUES
(1, 1, 'non_prod_tenant_1', 0, 0, 1, '2025-05-02 08:09:36', '2025-05-02 09:12:28'),
(2, 1, 'non_prod_tenant_1', 1, 0, 1, '2025-05-02 09:11:03', '2025-05-02 09:12:22'),
(3, 23, 'non_prod_tenant_23', 1, 1, 1, '2025-05-03 05:53:48', '2025-05-03 05:53:48'),
(4, 21, 'non_prod_tenant_21', 1, 1, 0, '2025-07-07 06:15:56', '2025-07-07 06:30:57'),
(5, 22, 'non_prod_tenant_22', 1, 1, 1, '2025-07-07 06:31:12', '2025-07-07 06:31:47');

-- --------------------------------------------------------

--
-- Table structure for table `tax_details`
--

CREATE TABLE `tax_details` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `document_id` bigint(20) UNSIGNED NOT NULL,
  `item_name` varchar(255) NOT NULL,
  `taxable_value` decimal(10,2) NOT NULL,
  `cgst` decimal(10,2) NOT NULL,
  `cgst_percent` decimal(5,2) NOT NULL,
  `sgst` decimal(10,2) NOT NULL,
  `sgst_percent` decimal(5,2) NOT NULL,
  `total_gst` decimal(10,2) NOT NULL,
  `product_id` bigint(20) UNSIGNED DEFAULT NULL,
  `service_id` bigint(20) UNSIGNED DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tax_details`
--

INSERT INTO `tax_details` (`id`, `document_id`, `item_name`, `taxable_value`, `cgst`, `cgst_percent`, `sgst`, `sgst_percent`, `total_gst`, `product_id`, `service_id`, `created_at`, `updated_at`) VALUES
(1, 1, 'Designer saree', 2999.00, 0.00, 0.00, 0.00, 0.00, 0.00, 2, NULL, '2025-08-12 06:46:41', '2025-08-12 06:46:41'),
(2, 1, 'Bridal lehanga', 1500.00, 90.00, 6.00, 90.00, 6.00, 180.00, 1, NULL, '2025-08-12 06:46:41', '2025-08-12 06:46:41');

-- --------------------------------------------------------

--
-- Table structure for table `tbl_feature`
--

CREATE TABLE `tbl_feature` (
  `id` int(11) NOT NULL,
  `module_name` varchar(50) DEFAULT NULL,
  `sub_module_name` varchar(50) DEFAULT NULL,
  `uid` varchar(50) DEFAULT NULL,
  `status` int(11) NOT NULL DEFAULT 1,
  `is_deleted` int(11) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tbl_feature`
--

INSERT INTO `tbl_feature` (`id`, `module_name`, `sub_module_name`, `uid`, `status`, `is_deleted`, `created_at`, `updated_at`) VALUES
(1, 'Employee Login', NULL, 'MOD_EMP', 1, 0, '2025-04-01 09:59:28', '2025-06-04 10:50:11'),
(2, 'QR Product Scan', NULL, 'MOD_QR', 1, 0, '2025-04-01 09:59:28', '2025-04-20 09:19:45'),
(3, 'Send Daily Leads', NULL, 'MOD_LEADS', 1, 0, '2025-04-15 04:37:09', '2025-04-20 09:19:51'),
(4, 'AI', NULL, 'MOD_AI', 1, 0, '2025-04-19 11:06:25', '2025-04-25 05:37:06'),
(5, 'Most likely text', NULL, 'MOD_MLT', 1, 0, '2025-04-19 11:06:25', '2025-04-25 05:37:06'),
(6, 'Make Store Online', NULL, 'MOD_MSO', 1, 0, '2025-06-05 09:50:37', '2025-06-05 09:51:04'),
(7, 'Boutique', NULL, 'MOD_BOUTIQUE', 1, 0, '2025-07-14 06:53:14', '2025-07-14 06:53:14');

-- --------------------------------------------------------

--
-- Table structure for table `tbl_feat_access`
--

CREATE TABLE `tbl_feat_access` (
  `id` int(11) NOT NULL,
  `module_id` bigint(20) NOT NULL,
  `tenant_schema` varchar(100) NOT NULL,
  `limit` int(11) DEFAULT NULL,
  `status` tinyint(4) NOT NULL DEFAULT 1,
  `is_deleted` tinyint(4) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tbl_feat_access`
--

INSERT INTO `tbl_feat_access` (`id`, `module_id`, `tenant_schema`, `limit`, `status`, `is_deleted`, `created_at`, `updated_at`) VALUES
(1, 1, 'non_prod_tenant_1', 12, 1, 0, '2025-08-12 04:50:01', '2025-08-12 04:50:01'),
(2, 2, 'non_prod_tenant_1', 12, 1, 0, '2025-08-12 04:50:01', '2025-08-12 04:50:01'),
(3, 3, 'non_prod_tenant_1', 12, 1, 0, '2025-08-12 04:50:01', '2025-08-12 04:50:01'),
(4, 4, 'non_prod_tenant_1', 12, 1, 0, '2025-08-12 04:50:01', '2025-08-12 04:50:01'),
(5, 5, 'non_prod_tenant_1', 12, 1, 0, '2025-08-12 04:50:01', '2025-08-12 04:50:01'),
(6, 6, 'non_prod_tenant_1', 12, 1, 0, '2025-08-12 04:50:01', '2025-08-12 04:50:01'),
(7, 7, 'non_prod_tenant_1', 12, 1, 0, '2025-08-12 04:50:01', '2025-08-12 04:50:01'),
(8, 1, 'non_prod_tenant_3', NULL, 1, 0, '2025-08-12 09:28:44', '2025-08-12 09:28:44'),
(9, 2, 'non_prod_tenant_3', NULL, 1, 0, '2025-08-12 09:28:44', '2025-08-12 09:28:44'),
(10, 3, 'non_prod_tenant_3', NULL, 1, 0, '2025-08-12 09:28:44', '2025-08-12 09:28:44'),
(11, 4, 'non_prod_tenant_3', NULL, 1, 0, '2025-08-12 09:28:44', '2025-08-12 09:28:44'),
(12, 5, 'non_prod_tenant_3', NULL, 1, 0, '2025-08-12 09:28:44', '2025-08-12 09:28:44'),
(13, 6, 'non_prod_tenant_3', NULL, 1, 0, '2025-08-12 09:28:44', '2025-08-12 09:28:44'),
(14, 7, 'non_prod_tenant_3', NULL, 1, 0, '2025-08-12 09:28:44', '2025-08-12 09:28:44');

-- --------------------------------------------------------

--
-- Table structure for table `tbl_package`
--

CREATE TABLE `tbl_package` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `modules` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`modules`)),
  `feature_list` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`feature_list`)),
  `status` tinyint(4) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tbl_package`
--

INSERT INTO `tbl_package` (`id`, `name`, `modules`, `feature_list`, `status`, `created_at`, `updated_at`) VALUES
(1, 'Basic', '[\r\n  \"MOD_EMP\",\r\n  \"MOD_QR\"\r\n]', '[\n  \"Generate QR Code for Customer\",\n  \"Scan QR to Fetch Customer Info\",\n  \"Track QR Usage History\",\n  \"QR-Based Attendance/Check-in\"\n]', 1, '2025-05-09 07:17:03', '2025-05-09 07:17:55'),
(2, 'Advance', '[\"MOD_EMP\",\"MOD_QR\",\"MOD_LEADS\",\"MOD_AI\",\"MOD_MLT\",\"MOD_MSO\",\"MOD_BOUTIQUE\"]', '[\"Add and Manage Leads\",\"Track Lead Status\",\"Assign Leads to Employees\",\"Send Automated Follow-ups\",\"Auto-Generate Marketing Templates\"]', 1, '2025-05-09 07:32:04', '2025-08-04 13:16:00');

-- --------------------------------------------------------

--
-- Table structure for table `tbl_package_duration_amount`
--

CREATE TABLE `tbl_package_duration_amount` (
  `id` int(11) NOT NULL,
  `duration` varchar(50) NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `tax` int(11) NOT NULL,
  `status` int(11) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `package_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tbl_package_duration_amount`
--

INSERT INTO `tbl_package_duration_amount` (`id`, `duration`, `amount`, `tax`, `status`, `created_at`, `updated_at`, `package_id`) VALUES
(1, 'Monthly', 200.00, 0, 1, '2025-05-09 07:24:40', '2025-08-12 04:47:01', 1),
(2, 'Quaterly', 999.00, 18, 1, '2025-05-09 07:24:40', '2025-07-26 19:05:15', 1),
(3, 'Yearly', 4000.00, 18, 1, '2025-05-09 07:25:47', '2025-05-09 07:25:47', 1),
(4, 'Monthly', 599.00, 18, 1, '2025-05-09 07:24:40', '2025-06-15 08:18:02', 2),
(5, 'Quaterly', 1799.00, 18, 1, '2025-05-09 07:24:40', '2025-07-26 19:05:17', 2),
(6, 'Yearly', 8000.00, 18, 1, '2025-05-09 07:25:47', '2025-05-09 07:25:47', 2);

-- --------------------------------------------------------

--
-- Table structure for table `tenants`
--

CREATE TABLE `tenants` (
  `id` int(10) UNSIGNED NOT NULL,
  `business_id` int(11) DEFAULT NULL,
  `sub_category_id` int(11) DEFAULT NULL,
  `business_description` longtext DEFAULT NULL,
  `refferal_code` varchar(255) DEFAULT NULL,
  `user_type` varchar(100) DEFAULT NULL,
  `first_name` varchar(255) DEFAULT NULL,
  `last_name` varchar(255) DEFAULT NULL,
  `gender` varchar(250) DEFAULT NULL,
  `dob` varchar(50) DEFAULT NULL,
  `age` varchar(50) DEFAULT NULL,
  `mobile` varchar(255) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `password` varchar(250) DEFAULT NULL,
  `mobile_verify` int(11) DEFAULT 0,
  `email_verified_at` timestamp NULL DEFAULT NULL,
  `company_name` varchar(250) DEFAULT NULL,
  `image` varchar(250) DEFAULT NULL,
  `gst` varchar(250) DEFAULT NULL,
  `pan` varchar(50) DEFAULT NULL,
  `adhaar` varchar(50) DEFAULT NULL,
  `longitude` varchar(200) DEFAULT NULL,
  `latitude` varchar(200) DEFAULT NULL,
  `full_address` varchar(250) DEFAULT NULL,
  `otp` varchar(255) DEFAULT NULL,
  `tenant_schema` varchar(255) DEFAULT NULL,
  `device_id` longtext DEFAULT NULL,
  `remember_token` varchar(100) DEFAULT NULL,
  `fcm_token` varchar(255) DEFAULT NULL,
  `market_place` tinyint(4) NOT NULL DEFAULT 0,
  `market_place_url` varchar(100) DEFAULT NULL,
  `cp_id` int(50) DEFAULT NULL,
  `status` int(11) NOT NULL DEFAULT 1,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `is_deleted` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `tenants`
--

INSERT INTO `tenants` (`id`, `business_id`, `sub_category_id`, `business_description`, `refferal_code`, `user_type`, `first_name`, `last_name`, `gender`, `dob`, `age`, `mobile`, `email`, `password`, `mobile_verify`, `email_verified_at`, `company_name`, `image`, `gst`, `pan`, `adhaar`, `longitude`, `latitude`, `full_address`, `otp`, `tenant_schema`, `device_id`, `remember_token`, `fcm_token`, `market_place`, `market_place_url`, `cp_id`, `status`, `created_at`, `updated_at`, `is_deleted`) VALUES
(1, 2, NULL, NULL, 'ABCD', NULL, 'Prathiksha', 'bhat', 'Male', '2005-12-10', NULL, '7022329256', NULL, '$2y$12$5zuUDcivioeVp4LyX3sOQOmGtD9RRt6McsXFzbmDWaIRKeOgxVlQa', 1, NULL, NULL, 'non_prod_tenant_1/profile/mnMzyhUls8ePXqTuYf4mRHHGFmDABKZHmnXPOqjc.jpg', NULL, NULL, NULL, '77.5581183', '13.0788191', '3HH5+G7M, 20th Cross Road, Bengaluru, Karnataka, 560097, India', '3952', 'non_prod_tenant_1', '97bc96137d83eb0ebc00e5c871869c3d00b9f9983960a6afca19a51ae97edb55', NULL, NULL, 0, NULL, NULL, 1, '2025-08-12 04:47:57', '2025-08-12 04:49:10', 0),
(2, 2, NULL, NULL, NULL, 'operational user', 'Prathiksh', 'Prathiksh', 'male', '2025-08-12T10:22', NULL, '8217371089', NULL, NULL, 0, NULL, NULL, '/tmp/phpF6Q3jk', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'non_prod_tenant_1', NULL, NULL, NULL, 0, NULL, NULL, 1, NULL, NULL, 0),
(3, 2, NULL, 'Boutique Business', 'ABCD12', NULL, 'Vignesh', 'S', 'Male', NULL, NULL, '9840913457', NULL, '$2y$12$YEH8/4R68HMk9G48XqXrYORHCvnpdJt7NuAXKuPHhUARXlmcyb4Mm', 1, NULL, 'Boutique Shop', NULL, NULL, NULL, NULL, NULL, NULL, NULL, '3037', 'non_prod_tenant_3', 'a7048321ddd813fd509b52d5ba17fef45e15c0a10fe58645833da2ee26d30319', NULL, 'ewptyXtORESNb7J51joDD8:APA91bGNJymyIfF_99gCLEmLHSsr2x9bI0Ywl5gAIBtYI9K9JRk61wPm4wpI1XAGVGdQEKx5vP2h_xukudPX37AroQUFeHe7YJ_8woFw1giJBiOt51icTt0', 0, NULL, NULL, 1, '2025-08-12 06:16:04', '2025-08-12 06:41:28', 0);

-- --------------------------------------------------------

--
-- Table structure for table `transaction_history`
--

CREATE TABLE `transaction_history` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `transaction_id` varchar(250) NOT NULL,
  `order_id` varchar(250) DEFAULT NULL,
  `phonepe_transaction_id` varchar(250) DEFAULT NULL,
  `tenant_schema` varchar(255) DEFAULT NULL,
  `name` varchar(255) NOT NULL,
  `mobile_number` varchar(255) NOT NULL,
  `package_id` bigint(20) UNSIGNED NOT NULL,
  `duration_id` bigint(20) UNSIGNED NOT NULL,
  `duration` varchar(100) DEFAULT NULL,
  `amount` decimal(11,2) NOT NULL,
  `payment_status` varchar(255) NOT NULL DEFAULT 'INITIATED',
  `status` int(11) NOT NULL DEFAULT 1,
  `payload` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`payload`)),
  `gateway_response` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`gateway_response`)),
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `transaction_history`
--

INSERT INTO `transaction_history` (`id`, `transaction_id`, `order_id`, `phonepe_transaction_id`, `tenant_schema`, `name`, `mobile_number`, `package_id`, `duration_id`, `duration`, `amount`, `payment_status`, `status`, `payload`, `gateway_response`, `created_at`, `updated_at`) VALUES
(1, 'ORD1754313441430000554', 'OMO2508041847223690798535', 'OM2508041847223700798599', 'non_prod_tenant_7', 'Tsed', '9845328671', 2, 5, 'Quaterly', 212282.00, 'COMPLETED', 1, '{\"merchantOrderId\":\"ORD1754313441430000554\",\"amount\":212282,\"expireAfter\":1200,\"metaInfo\":{\"udf1\":\"subscription_payment\",\"udf2\":\"sub_id_ORD1754313441430000554\",\"udf3\":\"student_checkout\",\"udf4\":\"\",\"udf5\":\"\"},\"paymentFlow\":{\"type\":\"PG_CHECKOUT\",\"message\":\"Payment for subscription ID: ORD1754313441430000554\",\"merchantUrls\":{\"callbackUrl\":\"http:\\/\\/localhost:5173\\/payment-status\"}}}', '\"{\\\"type\\\":\\\"CHECKOUT_ORDER_COMPLETED\\\",\\\"event\\\":\\\"checkout.order.completed\\\",\\\"payload\\\":{\\\"merchantId\\\":\\\"ANUJKHANDUAT\\\",\\\"merchantOrderId\\\":\\\"ORD1754313441430000554\\\",\\\"orderId\\\":\\\"OMO2508041847223690798535\\\",\\\"state\\\":\\\"COMPLETED\\\",\\\"amount\\\":\\\"212282\\\",\\\"expireAt\\\":\\\"1754486262168\\\",\\\"metaInfo\\\":{\\\"udf5\\\":null,\\\"udf3\\\":\\\"student_checkout\\\",\\\"udf4\\\":null,\\\"udf1\\\":\\\"subscription_payment\\\",\\\"udf2\\\":\\\"sub_id_ORD1754313441430000554\\\"},\\\"paymentDetails\\\":[{\\\"paymentMode\\\":\\\"CARD\\\",\\\"transactionId\\\":\\\"OM2508041847223700798599\\\",\\\"timestamp\\\":\\\"1754313462168\\\",\\\"amount\\\":\\\"212282\\\",\\\"state\\\":\\\"COMPLETED\\\",\\\"splitInstruments\\\":[{\\\"amount\\\":\\\"212282\\\",\\\"rail\\\":{\\\"type\\\":\\\"PG\\\",\\\"transactionId\\\":\\\"<transactionId>\\\",\\\"authorizationCode\\\":\\\"<authorizationCode>\\\",\\\"serviceTransactionId\\\":\\\"<serviceTransactionId>\\\"},\\\"instrument\\\":{\\\"type\\\":\\\"CREDIT_CARD\\\",\\\"bankTransactionId\\\":\\\"<bankTransactionId>\\\",\\\"bankId\\\":\\\"<bankId>\\\",\\\"arn\\\":\\\"<arn>\\\",\\\"brn\\\":\\\"<brn>\\\"}}]}]}}\"', '2025-08-04 13:17:22', '2025-08-04 13:17:42'),
(2, 'order_6ebb8a64-846a-4120-8fe0-8b4cf2e4c1b3', 'OMO2508071935494902885057', NULL, 'non_prod_tenant_1', 'Sagar cg', '7022329256', 1, 1, NULL, 100.00, 'PENDING', 1, '{\"merchantOrderId\":\"order_6ebb8a64-846a-4120-8fe0-8b4cf2e4c1b3\",\"amount\":100,\"expireAfter\":1200,\"metaInfo\":{\"udf1\":\"subscription_payment\",\"udf2\":\"sub_id_order_6ebb8a64-846a-4120-8fe0-8b4cf2e4c1b3\",\"udf3\":\"student_checkout\",\"udf4\":\"\",\"udf5\":\"\"},\"paymentFlow\":{\"type\":\"PG_CHECKOUT\",\"message\":\"Payment for subscription ID: order_6ebb8a64-846a-4120-8fe0-8b4cf2e4c1b3\",\"merchantUrls\":{\"callbackUrl\":\"http:\\/\\/localhost:5173\\/payment-status\"}}}', '{\"success\":true,\"data\":{\"orderId\":\"OMO2508071935494902885057\",\"state\":\"PENDING\",\"redirectUrl\":\"https:\\/\\/mercury-t2.phonepe.com\\/transact\\/pgv2?token=hq4wOGdzX31IuPyyh7\\/7AYOLiipO42P8QtgmusudZHta7zUAMbV5uMV5f6kF1hmvheryrLdSpk5RSkIxX+HqcxtC3z\\/TLOL02Bo15Ro0pCJODru4LaZZE350y9sShrlgHMZLteFpg6Ti9mkEU1qyrV4Vv6WdP7M5vy5NptKm9UkPNqAEsW04b6Wl7fEIOhNt81PUVDXDHPFWqAAnUnDVTkJwwHp67TxVnvHTWaS61fDbZ3+esO0avlc1IUfqHpKnBUFrPdcvrFoUqIH05gSePw31OGAn7uqTxOBbNjiHG1Vae\\/PJN54kHu6OxvNwahC\\/0USNPgGcWPqbsXDhuE9rBhCFYxJMj5p5bpSN4\\/VajwXRFp5cx7crnjjEpX3Te\\/G+QLccC+q3A\\/Z+dqpa7evoaxoAR7JZ2yRqmLBppRL7O7XVE5fbuxdezQfNy+6Ft8MjIHBeIMjw2tCMNo2FouW4nstIaan4c+bbr7qRjtRy65fluetqPTEZ9VQhGKAHXj5rVVXuuFUoCYoqZ\\/u3gDbUL+HWmZyEUduQ9lUtcOLsOjmFWRwwjdZG\",\"expireAt\":1754576749482}}', '2025-08-07 14:05:49', '2025-08-07 14:05:49'),
(3, 'order_bb8b6046-b9e5-4c54-9f13-3305fed16e37', 'OMO2508071937057792356206', NULL, 'non_prod_tenant_1', 'Sagar cg', '7022329256', 1, 1, NULL, 100.00, 'PENDING', 1, '{\"merchantOrderId\":\"order_bb8b6046-b9e5-4c54-9f13-3305fed16e37\",\"amount\":100,\"expireAfter\":1200,\"metaInfo\":{\"udf1\":\"subscription_payment\",\"udf2\":\"sub_id_order_bb8b6046-b9e5-4c54-9f13-3305fed16e37\",\"udf3\":\"student_checkout\",\"udf4\":\"\",\"udf5\":\"\"},\"paymentFlow\":{\"type\":\"PG_CHECKOUT\",\"message\":\"Payment for subscription ID: order_bb8b6046-b9e5-4c54-9f13-3305fed16e37\",\"merchantUrls\":{\"callbackUrl\":\"http:\\/\\/localhost:5173\\/payment-status\"}}}', '{\"success\":true,\"data\":{\"orderId\":\"OMO2508071937057792356206\",\"state\":\"PENDING\",\"redirectUrl\":\"https:\\/\\/mercury-t2.phonepe.com\\/transact\\/pgv2?token=hq4wOGdzX31IuPyyh7\\/7AYOLiipO42P8QtgmusudZHta7zUAMbV5uMV5f6kF1hmvheryrLdSpk5RSkIxX+HqcxtC3z\\/TLOL02Bo15EE3mQBOD5a8L6ZzEiN12NRLhrljDsV1peFpk6f29lMEHU6ivgUVuLmaPKAuqzpdiNKm9UkPNqAEsW04b6Wl7fEIOhNt8FD6ajXDHPFWqAAnUnDVTkJwwHp67TxVnvHTWaS61fDbZ3+esO0avlc1IUfqHpKnBUFrPdcvrFoUqIH05gSePw31OGAn7uqTxOBbNjiHG1Vae\\/PJN54kHu6OxvNwahC\\/0USNPgGcWPqbsXDhuE9rBhCFYxJMj5p5bpSN4\\/VajwXRFp5cx7crnjjEpX3Te\\/G+QLccC+q3A\\/Z+dqpa7evoaxoAR7JZ2yRqmLBpnxT6O7XVEbPS4hFa5Vi13ublzMATWUY9K7mkk8iqBv\\/P8fa1xK5mV73kSLnFprTDuM192OqQivIAcRoD0H5YQ7AtUUdJVSf2xmcfCIRvH52Am1zhGdLaxcaGI8tmApCERaLmWNFaP0zi\\/7pL\",\"expireAt\":1754576825771}}', '2025-08-07 14:07:05', '2025-08-07 14:07:05'),
(4, 'order_08c68b44-d4da-45ab-b7b6-34c17ce53050', 'OMO2508071951486043813211', NULL, 'non_prod_tenant_1', 'Sagar cg', '7022329256', 1, 1, NULL, 100.00, 'PENDING', 1, '{\"merchantOrderId\":\"order_08c68b44-d4da-45ab-b7b6-34c17ce53050\",\"amount\":100,\"expireAfter\":1200,\"metaInfo\":{\"udf1\":\"subscription_payment\",\"udf2\":\"sub_id_order_08c68b44-d4da-45ab-b7b6-34c17ce53050\",\"udf3\":\"student_checkout\",\"udf4\":\"\",\"udf5\":\"\"},\"paymentFlow\":{\"type\":\"PG_CHECKOUT\",\"message\":\"Payment for subscription ID: order_08c68b44-d4da-45ab-b7b6-34c17ce53050\",\"merchantUrls\":{\"callbackUrl\":\"http:\\/\\/localhost:5173\\/payment-status\"}}}', '{\"success\":true,\"data\":{\"orderId\":\"OMO2508071951486043813211\",\"state\":\"PENDING\",\"redirectUrl\":\"https:\\/\\/mercury-t2.phonepe.com\\/transact\\/pgv2?token=hq4wOGdzX31IuPyyh7\\/7AYOLiipO42P8QtgmusudZHta7zUAMbV5uMV5f6kF1hmvheryrLdSpk5RSkIxX+HqcxtC3z\\/TLOL02Bo15V8htCUVDru0L6ZZEiF0yNMShrlgVdJ2veF\\/rprn9UMEHU2fskwB56GdP6A5sDlzqtKm9UkPNqAEsW04b6Wl7fEIOhNh81DUWDXDHPFWqAAnUnDVTkJwwHp67TxVnvHTWaS61fDbZ3+esO0avlc1IUfqHpKnBUFrPdcvrFoUqIH05gSePw31OGAn7uqTxOBbNjiHG1Vae\\/PJN54kHu6OxvNwahC\\/0USNPgGcWPqbsXDhuE9rBhCFYxJMj5p5bpSN4\\/VajwXRFp5cx7crnjjEpX3Te\\/G+QLccC+q3A\\/Z+dqpa7evoaxoAR7JZ2yRqmLB5pRb6QLXVaL\\/5y3V58Ujh4a\\/RtcMaW2wFdObskeumB4uNotOU\\/sxhEb3sCvXMjJXOl+NK65DLj+odAHgqxnZXPZUZcwNkFlDM2RY2d5V7PZu\\/rFKvJtjX8PuMbP1hW19NmVhpH+dag+I7gY2I\",\"expireAt\":1754577708598}}', '2025-08-07 14:21:48', '2025-08-07 14:21:48'),
(5, 'order_99bd420f-5db8-4ec2-9a63-31ad7ee38e05', 'OMO2508071957409272645701', NULL, 'non_prod_tenant_1', 'Sagar cg', '7022329256', 1, 1, NULL, 100.00, 'PENDING', 1, '{\"merchantOrderId\":\"order_99bd420f-5db8-4ec2-9a63-31ad7ee38e05\",\"amount\":100,\"expireAfter\":1200,\"metaInfo\":{\"udf1\":\"subscription_payment\",\"udf2\":\"sub_id_order_99bd420f-5db8-4ec2-9a63-31ad7ee38e05\",\"udf3\":\"student_checkout\",\"udf4\":\"\",\"udf5\":\"\"},\"paymentFlow\":{\"type\":\"PG_CHECKOUT\",\"message\":\"Payment for subscription ID: order_99bd420f-5db8-4ec2-9a63-31ad7ee38e05\",\"merchantUrls\":{\"callbackUrl\":\"http:\\/\\/localhost:5173\\/payment-status\"}}}', '{\"success\":true,\"data\":{\"orderId\":\"OMO2508071957409272645701\",\"state\":\"PENDING\",\"redirectUrl\":\"https:\\/\\/mercury-t2.phonepe.com\\/transact\\/pgv2?token=hq4wOGdzX31IuPyyh7\\/7AYOLiipO42P8QtgmusudZHta7zUAMbV5uMV5f6kF1hmvheryrLdSpk5RSkIxX+HqcxtC3z\\/TLOL02Bo15R0hpCJMD7i0aLJzE3tgyMhOhrljCNJbveFpk7u89lMEHU6PuV8B57mdPI4cqzpjvtKm9UkPNqAEsW04b6Wl7fEIOhNh9lP6fjXDHPFWqAAnUnDVTkJwwHp67TxVnvHTWaS61fDbZ3+esO0avlc1IUfqHpKnBUFrPdcvrFoUqIH05gSePw31OGAn7uqTxOBbNjiHG1Vae\\/PJN54kHu6OxvNwahC\\/0USNPgGcWPqbsXDhuE9rBhCFYxJMj5p5bpSN4\\/VajwXRFp5cx7crnjjEpX3Te\\/G+QLccC+q3A\\/Z+dqpa7evoaxoAR7JZ2yRqmLB5lxP7K7XVc7DOznd5+HP3wsXWjuAmDnQjMsKu68X9Ps+v3\\/TozogyQovVXf\\/4+ZzlgcJJxLXuhvh1CSw49mArK6YZBxBaRkvb50IiZe9LB56q20PfP8G47eq2d9sqqNMMGcvlNo6BDDOioBv4\",\"expireAt\":1754578060920}}', '2025-08-07 14:27:40', '2025-08-07 14:27:40'),
(6, 'order_caaa4e21-5df4-47d5-a2c7-eec6b58d50ac', 'OMO2508072239393290744395', NULL, 'non_prod_tenant_1', 'Sagar cg', '7022329256', 1, 1, NULL, 100.00, 'PENDING', 1, '{\"merchantOrderId\":\"order_caaa4e21-5df4-47d5-a2c7-eec6b58d50ac\",\"amount\":100,\"expireAfter\":1200,\"metaInfo\":{\"udf1\":\"subscription_payment\",\"udf2\":\"sub_id_order_caaa4e21-5df4-47d5-a2c7-eec6b58d50ac\",\"udf3\":\"student_checkout\",\"udf4\":\"\",\"udf5\":\"\"},\"paymentFlow\":{\"type\":\"PG_CHECKOUT\",\"message\":\"Payment for subscription ID: order_caaa4e21-5df4-47d5-a2c7-eec6b58d50ac\",\"merchantUrls\":{\"callbackUrl\":\"http:\\/\\/localhost:5173\\/payment-status\"}}}', '{\"success\":true,\"data\":{\"orderId\":\"OMO2508072239393290744395\",\"state\":\"PENDING\",\"redirectUrl\":\"https:\\/\\/mercury-t2.phonepe.com\\/transact\\/pgv2?token=hq4wOGdzX31IuPyyh7\\/7AYOLiipO42P8QtgmusudZHta7zUAMbV5uMV5f6kF1hmvheryrLdSpk5RSkIxX+HqcxtC3z\\/TLOL02Bo15EI3pC5PD7uoZqVJE3tgyNhKhrlgV9FloeF\\/kLTk9VMFC1mPsgYWv7rFK7AhsC5wptKm9UkPNqAEsW04b6Wl7fEIOy1h81PqVDXDHPFWqAAnUnDVTkJwwHp67TxVnvHTWaS61fDbZ3+esO0avlc1IUfqHpKnBUFrPdcvrFoUqIH05gSePw31OGAn7uqTxOBbNjiHG1Vae\\/PJN54kHu6OxvNwahC\\/0USNPgGcWPqbsXDhuE9rBhCFYxJMj5p5bpSN4\\/VajwXRFp5cx7crnjjEpX3Te\\/G+QLccC+q3A\\/Z+dqpa7evoaxoAR7JZ2yRqn7B5n177O7XVWZPI3jEMwUCz\\/7GPl\\/08JSYVMMrO1NS+GNWOq8SQnaNxTcjgXd7FlY+cm9978veWqfVDFR8a8G8mHYQOcBMRdliau3tpd4guIZPftTDQJtXWlePaW\\/1GJVm2ACFIS8eSJUI0tLyT\",\"expireAt\":1754587779321}}', '2025-08-07 17:09:39', '2025-08-07 17:09:39'),
(7, 'order_66c17566-3b7d-4469-afec-21e5d6d7d854', 'OMO2508072240153662885998', NULL, 'non_prod_tenant_1', 'Sagar cg', '7022329256', 1, 1, NULL, 100.00, 'PENDING', 1, '{\"merchantOrderId\":\"order_66c17566-3b7d-4469-afec-21e5d6d7d854\",\"amount\":100,\"expireAfter\":1200,\"metaInfo\":{\"udf1\":\"subscription_payment\",\"udf2\":\"sub_id_order_66c17566-3b7d-4469-afec-21e5d6d7d854\",\"udf3\":\"student_checkout\",\"udf4\":\"\",\"udf5\":\"\"},\"paymentFlow\":{\"type\":\"PG_CHECKOUT\",\"message\":\"Payment for subscription ID: order_66c17566-3b7d-4469-afec-21e5d6d7d854\",\"merchantUrls\":{\"callbackUrl\":\"http:\\/\\/localhost:5173\\/payment-status\"}}}', '{\"success\":true,\"data\":{\"orderId\":\"OMO2508072240153662885998\",\"state\":\"PENDING\",\"redirectUrl\":\"https:\\/\\/mercury-t2.phonepe.com\\/transact\\/pgv2?token=hq4wOGdzX31IuPyyh7\\/7AYOLiipO42P8QtgmusudZHta7zUAMbV5uMV5f6kF1hmvheryrLdSpk5RSkIxX+HqcxtC3z\\/TLOL02Bo15RogniVfD4aoLaZzEzBj5eURhrlgVMVLn+F\\/k6Ti4lMEHk6PqgUVkbWaP8Yl8zlzutKm9UkPNqAEsW04b6Wl7fEIOy1h8FDEajXDHPFWqAAnUnDVTkJwwHp67TxVnvHTWaS61fDbZ3+esO0avlc1IUfqHpKnBUFrPdcvrFoUqIH05gSePw31OGAn7uqTxOBbNjiHG1Vae\\/PJN54kHu6OxvNwahC\\/0USNPgGcWPqbsXDhuE9rBhCFYxJMj5p5bpSN4\\/VajwXRFp5cx7crnjjEpX3Te\\/G+QLccC+q3A\\/Z+dqpa7evoaxoAR7JZ2yRqn7B5nxf6O7XVcefI2xwLlgf3+dHvhuchGHo6AePc6f+LQ\\/Csy8SC6IFVHYz8cPvbsKrN2vBY7J7O895JMhAkzF4MN6UJaz1IQ3b81WcvUOVeepm0k1fROZLez+qGef2ZaIWmXoW0ukCICIP16vAb\",\"expireAt\":1754587815359}}', '2025-08-07 17:10:15', '2025-08-07 17:10:15'),
(8, 'order_e6d157b2-26a9-4cd4-b3f5-1d726c56918b', 'OMO2508072255281037845086', NULL, 'non_prod_tenant_1', 'Sagar cg', '7022329256', 1, 1, NULL, 100.00, 'PENDING', 1, '{\"merchantOrderId\":\"order_e6d157b2-26a9-4cd4-b3f5-1d726c56918b\",\"amount\":100,\"expireAfter\":1200,\"metaInfo\":{\"udf1\":\"subscription_payment\",\"udf2\":\"sub_id_order_e6d157b2-26a9-4cd4-b3f5-1d726c56918b\",\"udf3\":\"student_checkout\",\"udf4\":\"\",\"udf5\":\"\"},\"paymentFlow\":{\"type\":\"PG_CHECKOUT\",\"message\":\"Payment for subscription ID: order_e6d157b2-26a9-4cd4-b3f5-1d726c56918b\",\"merchantUrls\":{\"callbackUrl\":\"http:\\/\\/localhost:5173\\/payment-status\"}}}', '{\"success\":true,\"data\":{\"orderId\":\"OMO2508072255281037845086\",\"state\":\"PENDING\",\"redirectUrl\":\"https:\\/\\/mercury-t2.phonepe.com\\/transact\\/pgv2?token=hq4wOGdzX31IuPyyh7\\/7AYOLiipO42P8QtgmusudZHta7zUAMbV5uMV5f6kF1hmvheryrLdSpk5RSkIxX+HqcxtC3z\\/TLOL02Bo15EQgnjlfD6iZdqVzEzN04sRPhrljDtFlpeF\\/rrDj9XkEH1mcnE0BuKLAP54fvzhgotKm9UkPNqAEsW04b6Wl7fEIOy1b81D6WDXDHPFWqAAnUnDVTkJwwHp67TxVnvHTWaS61fDbZ3+esO0avlc1IUfqHpKnBUFrPdcvrFoUqIH05gSePw31OGAn7uqTxOBbNjiHG1Vae\\/PJN54kHu6OxvNwahC\\/0USNPgGcWPqbsXDhuE9rBhCFYxJMj5p5bpSN4\\/VajwXRFp5cx7crnjjEpX3Te\\/G+QLccC+q3A\\/Z+dqpa7evoaxoAR7JZ2yRqn7FHpRT6QLXVTJvoyCBM+GSw0vX5sYIDCVFXN9Da1ueIR4iw3\\/+v5a9XdI\\/TfOrQlYyTsp1c3KGTj+FnISEJ6HxcAKo5WAVGFGLawElhfalpDvqKnkfVCdWhyMSlUf0OdTtca8Z2ey1CaLbu0mI6\",\"expireAt\":1754588728097}}', '2025-08-07 17:25:28', '2025-08-07 17:25:28'),
(9, 'ORD1754627009089000637', 'OMO2508080953319127863975', NULL, 'non_prod_tenant_1', 'Sagar', '7022329256', 1, 1, NULL, 100.00, 'PENDING', 1, '{\"merchantOrderId\":\"ORD1754627009089000637\",\"amount\":100,\"expireAfter\":1200,\"metaInfo\":{\"udf1\":\"subscription_payment\",\"udf2\":\"sub_id_ORD1754627009089000637\",\"udf3\":\"student_checkout\",\"udf4\":\"\",\"udf5\":\"\"},\"paymentFlow\":{\"type\":\"PG_CHECKOUT\",\"message\":\"Payment for subscription ID: ORD1754627009089000637\",\"merchantUrls\":{\"callbackUrl\":\"http:\\/\\/localhost:5173\\/payment-status\"}}}', '{\"success\":true,\"data\":{\"orderId\":\"OMO2508080953319127863975\",\"state\":\"PENDING\",\"expireAt\":1754628211907,\"token\":\"hq4wOGdzX31IuPyyh7\\/7AYOLiipO42P8QtgmusudZHta7zUAMbV5uMV5f6kF1hmvheryrLdSpk5RSkIxX+HqcxtC3z\\/1GuT3zDcjiBggmSEUDLi8KqVeRH93y8ANhId8V8JIg\\/xHk7i+8kBbH02iqgQBv6bCPLAxvztkocuJhU4WIJEfkXgKYOKx4e1QOCpyu3+iRyrDG\\/JFnjwKAmiOTmhCnT9G2BNOi+2NQZ6Ao\\/PmekCdiPNozXg8PEveFJDINXZ6Veg19UYCt72ywQmKIEzdAXgx7IC1ychmCDiaNElRefCTEIU0HaykmZBhUHWG00KOGy2YS52bsnXDokpGHlC\\/c3ZJiZlcbKOcgNNsjgLSE7RhnogrtCPEpX3Cb8OHBaAhc66jEPp6WZYijbDBTlsUQokFzSlrmbNEknLYBsS\\/FYbt6y1J1gWxytnYlf8qX2g3Ne7o9NucFsXHwteO8r5sT4yGWcb\\/gc7CnMto5PPK8tsHCyAptkAZLKkLWTtsGEPkT5aIJjvn0IYSAKADnh7L\"}}', '2025-08-08 04:23:31', '2025-08-08 04:23:31'),
(10, 'ORD1754627029455000209', 'OMO2508080953520502645086', NULL, 'non_prod_tenant_1', 'Sagar', '7022329256', 1, 1, NULL, 100.00, 'PENDING', 1, '{\"merchantOrderId\":\"ORD1754627029455000209\",\"amount\":100,\"expireAfter\":1200,\"metaInfo\":{\"udf1\":\"subscription_payment\",\"udf2\":\"sub_id_ORD1754627029455000209\",\"udf3\":\"student_checkout\",\"udf4\":\"\",\"udf5\":\"\"},\"paymentFlow\":{\"type\":\"PG_CHECKOUT\",\"message\":\"Payment for subscription ID: ORD1754627029455000209\",\"merchantUrls\":{\"callbackUrl\":\"http:\\/\\/localhost:5173\\/payment-status\"}}}', '{\"success\":true,\"data\":{\"orderId\":\"OMO2508080953520502645086\",\"state\":\"PENDING\",\"expireAt\":1754628232044,\"token\":\"hq4wOGdzX31IuPyyh7\\/7AYOLiipO42P8QtgmusudZHta7zUAMbV5uMV5f6kF1hmvheryrLdSpk5RSkIxX+HqcxtC3z\\/1GuT3zDcjiBggmSEUDLi0KqZednt3y8ANh4dwUcJIg\\/xHk7i+8kBbH02iqgQBv6bCPLA5vjtkocuJhU4WIJEfkXgKYOKx4e1QOCpyu3+iRyrDG\\/JFnjwKAmiOTmhCnT9G2BNOi+2NQZ6Ao\\/PmekCdiPNozXg8PEveFJDINXZ6Veg19UYCt72ywQmKIEzdAXgx7IC1ychmCDiaNElRefCTEIU0HaykmZBhUHWG00KOGy2YS52bsnXDokpGHlC\\/c3ZJiZlcbKOcgNNsjgLSE7RhnogrtCPEpX3Cb8OHBaAhc66jEPJ1WZYihuzvGn4Gd+QP+AR2nchChBbXQL2pEZjg4BID0wLr4unJhOckHVEINNvR4OaIRs2ww+iOxLF1Xa\\/fCr\\/zurfRu+J434HqpaFnBCw+5GInLboIRgNiemV+WzeiudMRJ914jdYhzkvP\"}}', '2025-08-08 04:23:52', '2025-08-08 04:23:52'),
(11, 'order_b9a611bd-571a-4729-9e3f-1a2822db7e5f', 'OMO2508081039190740744322', NULL, 'non_prod_tenant_1', 'Sagar cg', '7022329256', 1, 1, NULL, 100.00, 'PENDING', 1, '{\"merchantOrderId\":\"order_b9a611bd-571a-4729-9e3f-1a2822db7e5f\",\"amount\":100,\"expireAfter\":1200,\"metaInfo\":{\"udf1\":\"subscription_payment\",\"udf2\":\"sub_id_order_b9a611bd-571a-4729-9e3f-1a2822db7e5f\",\"udf3\":\"student_checkout\",\"udf4\":\"\",\"udf5\":\"\"},\"paymentFlow\":{\"type\":\"PG_CHECKOUT\",\"message\":\"Payment for subscription ID: order_b9a611bd-571a-4729-9e3f-1a2822db7e5f\",\"merchantUrls\":{\"callbackUrl\":\"http:\\/\\/localhost:5173\\/payment-status\"}}}', '{\"success\":true,\"data\":{\"orderId\":\"OMO2508081039190740744322\",\"state\":\"PENDING\",\"redirectUrl\":\"https:\\/\\/mercury-t2.phonepe.com\\/transact\\/pgv2?token=hq4wOGdzX31IuPyyh7\\/7AYOLiipO42P8QtgmusudZHta7zUAMbV5uMV5f6kF1hmvheryrLdSpk5RSkIxX+HqcxtC3z\\/TLOL02Bo15EEhpC0VDKi7drJZE3t09ccShrlgV8ZLn+Fpk6v04UMEH1qMtgACv6WaKJ4QqzlwstKm9UkPNqAEsW04b6Wl7fELOQNT8VPEVDXDHPFWqAAnUnDVTkJwwHp67TxVnvHTWaS61fDbZ3+esO0avlc1IUfqHpKnBUFrPdcvrFoUqIH05gSePw31OGAn7uqTxOBbNjiHG1Vae\\/PJN54kHu6OxvNwahC\\/0USNPgGcWPqbsXDhuE9rBhCFYxJMj5p5bpSN4\\/VajwXRFp5cx7crnjjEpX3Te\\/G+QLccC+q3A\\/Z+dqpa7evoaxoAR7JZ2yRm0bNHmxP7O7XVYIfdoXFa2Fux4c\\/kuudBJzM\\/MuP1lIP+F9zPr8Hs4ItuQZLMAfzt9YvQh8Qr0PbyhPJGCAEK5GtbGaN0cBZWf0bZv3RtcL90IMqKvFDBBNHskuuTONuvgc0imFCyE7+Ne4Jx8YZA\",\"expireAt\":1754630959066}}', '2025-08-08 05:09:19', '2025-08-08 05:09:19'),
(12, 'order_c2d92c13-c1cc-4c0a-bc14-1b3c0f62066a', 'OMO2508081130137215828225', NULL, 'non_prod_tenant_1', 'Sagar cg', '7022329256', 2, 4, NULL, 70682.00, 'PENDING', 1, '{\"merchantOrderId\":\"order_c2d92c13-c1cc-4c0a-bc14-1b3c0f62066a\",\"amount\":70682,\"expireAfter\":1200,\"metaInfo\":{\"udf1\":\"subscription_payment\",\"udf2\":\"sub_id_order_c2d92c13-c1cc-4c0a-bc14-1b3c0f62066a\",\"udf3\":\"student_checkout\",\"udf4\":\"\",\"udf5\":\"\"},\"paymentFlow\":{\"type\":\"PG_CHECKOUT\",\"message\":\"Payment for subscription ID: order_c2d92c13-c1cc-4c0a-bc14-1b3c0f62066a\",\"merchantUrls\":{\"callbackUrl\":\"http:\\/\\/localhost:5173\\/payment-status\"}}}', '{\"success\":true,\"data\":{\"orderId\":\"OMO2508081130137215828225\",\"state\":\"PENDING\",\"redirectUrl\":\"https:\\/\\/mercury-t2.phonepe.com\\/transact\\/pgv2?token=hq4wOGdzX31IuPyyh7\\/7AYOLiipO42P8QtgmusudZHta7zUAMbV5uMV5f6kF1hmvheryrLdSpk5RSkIxX+HqcxtC3z\\/TLOL02Bo15EIjnjkSDJGwZ6VjEiB32M8QhrljDsZmseF\\/qbP29WkEH1qysV4CkrbDPJ419TlKrtKm9UkPNqAEsW04b6Wl7fELORNx9lDEcjXDHPFWqAAnUnDVTkJwwHp67TxVnvHTWaS61fDbZ3+esO0avlc1IUfqHpKnBUFrPdcvrFoUqIH05gSePw31OGAn7uqTxOBbNjiHG1Vae\\/PJN54kHu6OxvNwahC\\/0USNPgGcWPqbsXDhuE9rBhCFYxJMj5p5bpSN4\\/VajwXRFp5cx7crnjjEpX3Te\\/G+QLccC+q3A\\/Z+dqpa7evoaxoAR7JZ2yRm0bN5lxf5HbXVfpv74yBylVHN0P\\/8iIYwW1csDrjT9vWQINSO\\/\\/Tv+Ll3Cc3CZNL4scjDiM0u+fXQmNNCcxsn6lwMGqM2ThJYaEb4xGMgTr99IeK3lXLSGvTD+PSHIMtJqJWHplUUFfg7nqkekt6d\",\"expireAt\":1754634013713}}', '2025-08-08 06:00:13', '2025-08-08 06:00:13'),
(13, 'ORD1754649974608000588', 'OMO2508081616173736661630', NULL, 'non_prod_tenant_1', 'Sagar', '7022329256', 1, 1, 'Monthly', 100.00, 'FAILED', 1, '{\"merchantOrderId\":\"ORD1754649974608000588\",\"amount\":100,\"expireAfter\":1200,\"metaInfo\":{\"udf1\":\"subscription_payment\",\"udf2\":\"sub_id_ORD1754649974608000588\",\"udf3\":\"student_checkout\",\"udf4\":\"\",\"udf5\":\"\"},\"paymentFlow\":{\"type\":\"PG_CHECKOUT\",\"message\":\"Payment for subscription ID: ORD1754649974608000588\",\"merchantUrls\":{\"callbackUrl\":\"http:\\/\\/localhost:5173\\/payment-status\"}}}', '\"{\\\"success\\\":true,\\\"data\\\":{\\\"orderId\\\":\\\"OMO2508081616173736661630\\\",\\\"state\\\":\\\"FAILED\\\",\\\"amount\\\":100,\\\"expireAt\\\":1754651177367,\\\"errorCode\\\":\\\"TXN_NOT_COMPLETED\\\",\\\"detailedErrorCode\\\":\\\"ORDER_EXPIRED\\\",\\\"metaInfo\\\":{\\\"udf1\\\":\\\"subscription_payment\\\",\\\"udf2\\\":\\\"sub_id_ORD1754649974608000588\\\",\\\"udf3\\\":\\\"student_checkout\\\",\\\"udf4\\\":\\\"\\\",\\\"udf5\\\":\\\"\\\"},\\\"paymentDetails\\\":[]}}\"', '2025-08-08 10:46:17', '2025-08-09 11:20:40'),
(14, 'ORD1754738445602000457', 'OMO2508091650470902345472', NULL, 'non_prod_tenant_1', 'Sagar', '8217371089', 1, 1, 'Monthly', 100.00, 'FAILED', 1, '{\"merchantOrderId\":\"ORD1754738445602000457\",\"amount\":100,\"expireAfter\":1200,\"metaInfo\":{\"udf1\":\"subscription_payment\",\"udf2\":\"sub_id_ORD1754738445602000457\",\"udf3\":\"student_checkout\",\"udf4\":\"\",\"udf5\":\"\"},\"paymentFlow\":{\"type\":\"PG_CHECKOUT\",\"message\":\"Payment for subscription ID: ORD1754738445602000457\",\"merchantUrls\":{\"callbackUrl\":\"http:\\/\\/localhost:5173\\/payment-status\"}}}', '\"{\\\"success\\\":true,\\\"data\\\":{\\\"orderId\\\":\\\"OMO2508091650470902345472\\\",\\\"state\\\":\\\"FAILED\\\",\\\"amount\\\":100,\\\"expireAt\\\":1754739647083,\\\"errorCode\\\":\\\"TXN_CANCELLED\\\",\\\"detailedErrorCode\\\":\\\"REQUEST_CANCEL_BY_REQUESTEE\\\",\\\"metaInfo\\\":{\\\"udf1\\\":\\\"subscription_payment\\\",\\\"udf2\\\":\\\"sub_id_ORD1754738445602000457\\\",\\\"udf3\\\":\\\"student_checkout\\\",\\\"udf4\\\":\\\"\\\",\\\"udf5\\\":\\\"\\\"},\\\"paymentDetails\\\":[{\\\"transactionId\\\":\\\"OM2508091650521766661069\\\",\\\"paymentMode\\\":\\\"UPI_INTENT\\\",\\\"timestamp\\\":1754738452204,\\\"amount\\\":100,\\\"payableAmount\\\":100,\\\"feeAmount\\\":0,\\\"state\\\":\\\"FAILED\\\",\\\"errorCode\\\":\\\"TXN_CANCELLED\\\",\\\"detailedErrorCode\\\":\\\"REQUEST_CANCEL_BY_REQUESTEE\\\"}]}}\"', '2025-08-09 11:20:47', '2025-08-09 11:21:01'),
(15, 'ORD1754738463686000270', 'OMO2508091651047017588714', NULL, 'non_prod_tenant_1', 'Sagar', '8217371089', 1, 1, 'Monthly', 100.00, 'COMPLETED', 1, '{\"merchantOrderId\":\"ORD1754738463686000270\",\"amount\":100,\"expireAfter\":1200,\"metaInfo\":{\"udf1\":\"subscription_payment\",\"udf2\":\"sub_id_ORD1754738463686000270\",\"udf3\":\"student_checkout\",\"udf4\":\"\",\"udf5\":\"\"},\"paymentFlow\":{\"type\":\"PG_CHECKOUT\",\"message\":\"Payment for subscription ID: ORD1754738463686000270\",\"merchantUrls\":{\"callbackUrl\":\"http:\\/\\/localhost:5173\\/payment-status\"}}}', '\"{\\\"success\\\":true,\\\"data\\\":{\\\"orderId\\\":\\\"OMO2508091651047017588714\\\",\\\"state\\\":\\\"PENDING\\\",\\\"amount\\\":100,\\\"expireAt\\\":1754739664695,\\\"metaInfo\\\":{\\\"udf1\\\":\\\"subscription_payment\\\",\\\"udf2\\\":\\\"sub_id_ORD1754738463686000270\\\",\\\"udf3\\\":\\\"student_checkout\\\",\\\"udf4\\\":\\\"\\\",\\\"udf5\\\":\\\"\\\"},\\\"paymentDetails\\\":[{\\\"transactionId\\\":\\\"OM2508091651076064686627\\\",\\\"paymentMode\\\":\\\"UPI_INTENT\\\",\\\"timestamp\\\":1754738467634,\\\"amount\\\":100,\\\"payableAmount\\\":100,\\\"feeAmount\\\":0,\\\"state\\\":\\\"PENDING\\\"}]}}\"', '2025-08-09 11:21:04', '2025-08-09 11:21:19'),
(16, 'ORD1754903134988000640', 'OMO2508111435363792345264', NULL, 'non_prod_tenant_10', 'Vignesh', '9840913457', 1, 1, 'Monthly', 100.00, 'COMPLETED', 1, '{\"merchantOrderId\":\"ORD1754903134988000640\",\"amount\":100,\"expireAfter\":1200,\"metaInfo\":{\"udf1\":\"subscription_payment\",\"udf2\":\"sub_id_ORD1754903134988000640\",\"udf3\":\"student_checkout\",\"udf4\":\"\",\"udf5\":\"\"},\"paymentFlow\":{\"type\":\"PG_CHECKOUT\",\"message\":\"Payment for subscription ID: ORD1754903134988000640\",\"merchantUrls\":{\"callbackUrl\":\"http:\\/\\/localhost:5173\\/payment-status\"}}}', '\"{\\\"success\\\":true,\\\"data\\\":{\\\"orderId\\\":\\\"OMO2508111435363792345264\\\",\\\"state\\\":\\\"COMPLETED\\\",\\\"amount\\\":100,\\\"payableAmount\\\":100,\\\"feeAmount\\\":0,\\\"expireAt\\\":1754904336373,\\\"metaInfo\\\":{\\\"udf1\\\":\\\"subscription_payment\\\",\\\"udf2\\\":\\\"sub_id_ORD1754903134988000640\\\",\\\"udf3\\\":\\\"student_checkout\\\",\\\"udf4\\\":\\\"\\\",\\\"udf5\\\":\\\"\\\"},\\\"paymentDetails\\\":[{\\\"transactionId\\\":\\\"OM2508111435400284020850\\\",\\\"paymentMode\\\":\\\"UPI_INTENT\\\",\\\"timestamp\\\":1754903140058,\\\"amount\\\":100,\\\"payableAmount\\\":100,\\\"feeAmount\\\":0,\\\"state\\\":\\\"COMPLETED\\\",\\\"instrument\\\":{\\\"type\\\":\\\"ACCOUNT\\\",\\\"maskedAccountNumber\\\":\\\"XXXXXXXXXX52\\\",\\\"ifsc\\\":\\\"ICIC0002704\\\",\\\"accountType\\\":\\\"SAVINGS\\\"},\\\"rail\\\":{\\\"type\\\":\\\"UPI\\\",\\\"utr\\\":\\\"207863127741\\\",\\\"upiTransactionId\\\":\\\"IBL1e7a0ea3c6844ea38693b879d9599071\\\"},\\\"splitInstruments\\\":[{\\\"instrument\\\":{\\\"type\\\":\\\"ACCOUNT\\\",\\\"maskedAccountNumber\\\":\\\"XXXXXXXXXX52\\\",\\\"ifsc\\\":\\\"ICIC0002704\\\",\\\"accountType\\\":\\\"SAVINGS\\\"},\\\"rail\\\":{\\\"type\\\":\\\"UPI\\\",\\\"utr\\\":\\\"207863127741\\\",\\\"upiTransactionId\\\":\\\"IBL1e7a0ea3c6844ea38693b879d9599071\\\"},\\\"amount\\\":100}]}]}}\"', '2025-08-11 09:05:36', '2025-08-11 09:06:03'),
(20, 'ORD1754980747824000204', 'OMO2508121209100385304331', NULL, 'non_prod_tenant_3', 'Vignesh', '9840913457', 1, 1, 'Monthly', 20000.00, 'COMPLETED', 1, '{\"merchantOrderId\":\"ORD1754980747824000204\",\"amount\":20000,\"expireAfter\":1200,\"metaInfo\":{\"udf1\":\"subscription_payment\",\"udf2\":\"sub_id_ORD1754980747824000204\",\"udf3\":\"student_checkout\",\"udf4\":\"\",\"udf5\":\"\"},\"paymentFlow\":{\"type\":\"PG_CHECKOUT\",\"message\":\"Payment for subscription ID: ORD1754980747824000204\",\"merchantUrls\":{\"callbackUrl\":\"http:\\/\\/localhost:5173\\/payment-status\"}}}', '\"{\\\"success\\\":true,\\\"data\\\":{\\\"orderId\\\":\\\"OMO2508121209100385304331\\\",\\\"state\\\":\\\"PENDING\\\",\\\"amount\\\":20000,\\\"expireAt\\\":1754981950032,\\\"metaInfo\\\":{\\\"udf1\\\":\\\"subscription_payment\\\",\\\"udf2\\\":\\\"sub_id_ORD1754980747824000204\\\",\\\"udf3\\\":\\\"student_checkout\\\",\\\"udf4\\\":\\\"\\\",\\\"udf5\\\":\\\"\\\"},\\\"paymentDetails\\\":[{\\\"transactionId\\\":\\\"OM2508121209188404406557\\\",\\\"paymentMode\\\":\\\"UPI_INTENT\\\",\\\"timestamp\\\":1754980758869,\\\"amount\\\":20000,\\\"payableAmount\\\":20000,\\\"feeAmount\\\":0,\\\"state\\\":\\\"PENDING\\\"}]}}\"', '2025-08-12 06:39:10', '2025-08-12 06:39:24'),
(21, 'ORD1754980770220000184', 'OMO2508121209315245286662', NULL, 'non_prod_tenant_3', 'Vignesh', '9840913457', 1, 1, 'Monthly', 20000.00, 'FAILED', 1, '{\"merchantOrderId\":\"ORD1754980770220000184\",\"amount\":20000,\"expireAfter\":1200,\"metaInfo\":{\"udf1\":\"subscription_payment\",\"udf2\":\"sub_id_ORD1754980770220000184\",\"udf3\":\"student_checkout\",\"udf4\":\"\",\"udf5\":\"\"},\"paymentFlow\":{\"type\":\"PG_CHECKOUT\",\"message\":\"Payment for subscription ID: ORD1754980770220000184\",\"merchantUrls\":{\"callbackUrl\":\"http:\\/\\/localhost:5173\\/payment-status\"}}}', '\"{\\\"success\\\":true,\\\"data\\\":{\\\"orderId\\\":\\\"OMO2508121209315245286662\\\",\\\"state\\\":\\\"FAILED\\\",\\\"amount\\\":20000,\\\"expireAt\\\":1754981971518,\\\"errorCode\\\":\\\"TXN_CANCELLED\\\",\\\"detailedErrorCode\\\":\\\"REQUEST_CANCEL_BY_REQUESTEE\\\",\\\"metaInfo\\\":{\\\"udf1\\\":\\\"subscription_payment\\\",\\\"udf2\\\":\\\"sub_id_ORD1754980770220000184\\\",\\\"udf3\\\":\\\"student_checkout\\\",\\\"udf4\\\":\\\"\\\",\\\"udf5\\\":\\\"\\\"},\\\"paymentDetails\\\":[{\\\"transactionId\\\":\\\"OM2508121209336455304876\\\",\\\"paymentMode\\\":\\\"UPI_INTENT\\\",\\\"timestamp\\\":1754980773672,\\\"amount\\\":20000,\\\"payableAmount\\\":20000,\\\"feeAmount\\\":0,\\\"state\\\":\\\"FAILED\\\",\\\"errorCode\\\":\\\"TXN_CANCELLED\\\",\\\"detailedErrorCode\\\":\\\"REQUEST_CANCEL_BY_REQUESTEE\\\"}]}}\"', '2025-08-12 06:39:31', '2025-08-12 06:39:39'),
(22, 'ORD1754980786518000148', 'OMO2508121209478858237879', NULL, 'non_prod_tenant_3', 'Vignesh', '9840913457', 1, 1, 'Monthly', 20000.00, 'COMPLETED', 1, '{\"merchantOrderId\":\"ORD1754980786518000148\",\"amount\":20000,\"expireAfter\":1200,\"metaInfo\":{\"udf1\":\"subscription_payment\",\"udf2\":\"sub_id_ORD1754980786518000148\",\"udf3\":\"student_checkout\",\"udf4\":\"\",\"udf5\":\"\"},\"paymentFlow\":{\"type\":\"PG_CHECKOUT\",\"message\":\"Payment for subscription ID: ORD1754980786518000148\",\"merchantUrls\":{\"callbackUrl\":\"http:\\/\\/localhost:5173\\/payment-status\"}}}', '\"{\\\"success\\\":true,\\\"data\\\":{\\\"orderId\\\":\\\"OMO2508121209478858237879\\\",\\\"state\\\":\\\"PENDING\\\",\\\"amount\\\":20000,\\\"expireAt\\\":1754981987879,\\\"metaInfo\\\":{\\\"udf1\\\":\\\"subscription_payment\\\",\\\"udf2\\\":\\\"sub_id_ORD1754980786518000148\\\",\\\"udf3\\\":\\\"student_checkout\\\",\\\"udf4\\\":\\\"\\\",\\\"udf5\\\":\\\"\\\"},\\\"paymentDetails\\\":[{\\\"transactionId\\\":\\\"OM2508121209500750084490\\\",\\\"paymentMode\\\":\\\"UPI_INTENT\\\",\\\"timestamp\\\":1754980790102,\\\"amount\\\":20000,\\\"payableAmount\\\":20000,\\\"feeAmount\\\":0,\\\"state\\\":\\\"PENDING\\\"}]}}\"', '2025-08-12 06:39:47', '2025-08-12 06:40:04');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `name` varchar(255) NOT NULL,
  `email` varchar(255) DEFAULT NULL,
  `email_verified_at` timestamp NULL DEFAULT NULL,
  `mobile` varchar(50) DEFAULT NULL,
  `otp` bigint(20) DEFAULT NULL,
  `password` varchar(255) DEFAULT NULL,
  `remember_token` varchar(100) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `role` int(11) DEFAULT NULL COMMENT '0=admin\r\n1=tenant\r\n2=super admin\r\n',
  `tenant_schema` varchar(250) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `name`, `email`, `email_verified_at`, `mobile`, `otp`, `password`, `remember_token`, `created_at`, `updated_at`, `role`, `tenant_schema`) VALUES
(1, 'super admin', 'superadmin@123.com', NULL, NULL, 0, '$2y$12$xBHLd3q/WMzYgnGrCw.AUekpOTlL85YYJcw64Fz.eSGW99wiSuVwe', 'dou8X3G6S11YUOBOQXwJXT64YhgfLGDn9YWjuTkI0yuTLUh7HtFUGPkszTGh', '2024-07-24 20:18:33', '2024-07-24 20:18:33', 2, NULL),
(2, 'Vignesh', 'vignesh.ee@gmail.com', NULL, NULL, NULL, '$2y$12$3kcAjQVgPNEvSNXFrNmiyOCK5o8DqY7Uf4obhE1lc/WFT7o/sI/C6', 'eDRlRPKELoDwXJof7jdYLiDJro0YCJfaki9fGHMCiBDaAGUzjmr1za0Sobol', '2025-04-13 02:00:47', '2025-04-13 02:00:47', 0, NULL),
(3, 'Demo NP', 'demo@mail.com', NULL, NULL, NULL, '$2y$12$pGgFblJQ5aRd7BLyedFJX./cWGY8VLLWHHRd/cNZDXUWgAnMgzUba', NULL, '2025-04-19 05:40:03', '2025-04-19 05:40:03', 0, NULL);

--
-- Indexes for dumped tables
--

--
-- Indexes for table `ai_feature_list`
--
ALTER TABLE `ai_feature_list`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `apks`
--
ALTER TABLE `apks`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `appointment`
--
ALTER TABLE `appointment`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `app_permissions`
--
ALTER TABLE `app_permissions`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `permission_key` (`permission_key`);

--
-- Indexes for table `bill_items`
--
ALTER TABLE `bill_items`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `boutique_design_areas`
--
ALTER TABLE `boutique_design_areas`
  ADD PRIMARY KEY (`id`),
  ADD KEY `item_id` (`item_id`);

--
-- Indexes for table `boutique_design_options`
--
ALTER TABLE `boutique_design_options`
  ADD PRIMARY KEY (`id`),
  ADD KEY `design_area_id` (`design_area_id`);

--
-- Indexes for table `boutique_items`
--
ALTER TABLE `boutique_items`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `boutique_item_measurements`
--
ALTER TABLE `boutique_item_measurements`
  ADD PRIMARY KEY (`id`),
  ADD KEY `item_id` (`item_id`);

--
-- Indexes for table `boutique_pattern`
--
ALTER TABLE `boutique_pattern`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `business_categories`
--
ALTER TABLE `business_categories`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `business_sub_categories`
--
ALTER TABLE `business_sub_categories`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `cache`
--
ALTER TABLE `cache`
  ADD PRIMARY KEY (`key`);

--
-- Indexes for table `cache_locks`
--
ALTER TABLE `cache_locks`
  ADD PRIMARY KEY (`key`);

--
-- Indexes for table `chances`
--
ALTER TABLE `chances`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `channel_partners`
--
ALTER TABLE `channel_partners`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `channel_partners_mobile_unique` (`mobile`);

--
-- Indexes for table `cities`
--
ALTER TABLE `cities`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `color_master`
--
ALTER TABLE `color_master`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `contact_groups`
--
ALTER TABLE `contact_groups`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `countries`
--
ALTER TABLE `countries`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `cron_jobs`
--
ALTER TABLE `cron_jobs`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `documents`
--
ALTER TABLE `documents`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `employee_commission`
--
ALTER TABLE `employee_commission`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `employee_login_setting`
--
ALTER TABLE `employee_login_setting`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `ent_form_builder`
--
ALTER TABLE `ent_form_builder`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `failed_jobs`
--
ALTER TABLE `failed_jobs`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `failed_jobs_uuid_unique` (`uuid`);

--
-- Indexes for table `fcm_routes`
--
ALTER TABLE `fcm_routes`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `form_builder`
--
ALTER TABLE `form_builder`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `jobs`
--
ALTER TABLE `jobs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `jobs_queue_index` (`queue`);

--
-- Indexes for table `job_batches`
--
ALTER TABLE `job_batches`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `job_profile_master`
--
ALTER TABLE `job_profile_master`
  ADD PRIMARY KEY (`id`),
  ADD KEY `business_id` (`business_id`);

--
-- Indexes for table `leads_history`
--
ALTER TABLE `leads_history`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `leads_master`
--
ALTER TABLE `leads_master`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `marketing`
--
ALTER TABLE `marketing`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `marketings`
--
ALTER TABLE `marketings`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `menu_permissions`
--
ALTER TABLE `menu_permissions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `menu_permissions_user_id_foreign` (`user_id`);

--
-- Indexes for table `migrations`
--
ALTER TABLE `migrations`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `newattachments`
--
ALTER TABLE `newattachments`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `number_series`
--
ALTER TABLE `number_series`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `number_series_type_source_financial_year_unique` (`type`,`source`,`financial_year`);

--
-- Indexes for table `password_reset_tokens`
--
ALTER TABLE `password_reset_tokens`
  ADD PRIMARY KEY (`email`);

--
-- Indexes for table `prescription`
--
ALTER TABLE `prescription`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `product-catalogs`
--
ALTER TABLE `product-catalogs`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `query_builder`
--
ALTER TABLE `query_builder`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `query_mapping`
--
ALTER TABLE `query_mapping`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `referrals`
--
ALTER TABLE `referrals`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `referrals_referral_code_unique` (`referral_code`);

--
-- Indexes for table `sales_and_services`
--
ALTER TABLE `sales_and_services`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `service-catalogs`
--
ALTER TABLE `service-catalogs`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `sessions`
--
ALTER TABLE `sessions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `sessions_user_id_index` (`user_id`),
  ADD KEY `sessions_last_activity_index` (`last_activity`);

--
-- Indexes for table `size_master`
--
ALTER TABLE `size_master`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `stages`
--
ALTER TABLE `stages`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `states`
--
ALTER TABLE `states`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `status`
--
ALTER TABLE `status`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `statuses`
--
ALTER TABLE `statuses`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `sync_requests`
--
ALTER TABLE `sync_requests`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `tax_details`
--
ALTER TABLE `tax_details`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `tbl_feature`
--
ALTER TABLE `tbl_feature`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `tbl_feat_access`
--
ALTER TABLE `tbl_feat_access`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `tbl_package`
--
ALTER TABLE `tbl_package`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `tbl_package_duration_amount`
--
ALTER TABLE `tbl_package_duration_amount`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `tenants`
--
ALTER TABLE `tenants`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`),
  ADD UNIQUE KEY `mobile` (`mobile`);

--
-- Indexes for table `transaction_history`
--
ALTER TABLE `transaction_history`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `transaction_history_transaction_id_unique` (`transaction_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `users_email_unique` (`email`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `ai_feature_list`
--
ALTER TABLE `ai_feature_list`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `apks`
--
ALTER TABLE `apks`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

--
-- AUTO_INCREMENT for table `appointment`
--
ALTER TABLE `appointment`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `app_permissions`
--
ALTER TABLE `app_permissions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

--
-- AUTO_INCREMENT for table `boutique_design_areas`
--
ALTER TABLE `boutique_design_areas`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=29;

--
-- AUTO_INCREMENT for table `boutique_design_options`
--
ALTER TABLE `boutique_design_options`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=152;

--
-- AUTO_INCREMENT for table `boutique_items`
--
ALTER TABLE `boutique_items`
  MODIFY `id` int(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `boutique_item_measurements`
--
ALTER TABLE `boutique_item_measurements`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=92;

--
-- AUTO_INCREMENT for table `boutique_pattern`
--
ALTER TABLE `boutique_pattern`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `business_categories`
--
ALTER TABLE `business_categories`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=14;

--
-- AUTO_INCREMENT for table `business_sub_categories`
--
ALTER TABLE `business_sub_categories`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT for table `chances`
--
ALTER TABLE `chances`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `channel_partners`
--
ALTER TABLE `channel_partners`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `cities`
--
ALTER TABLE `cities`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=17;

--
-- AUTO_INCREMENT for table `color_master`
--
ALTER TABLE `color_master`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `contact_groups`
--
ALTER TABLE `contact_groups`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=18;

--
-- AUTO_INCREMENT for table `countries`
--
ALTER TABLE `countries`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=217;

--
-- AUTO_INCREMENT for table `cron_jobs`
--
ALTER TABLE `cron_jobs`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `employee_login_setting`
--
ALTER TABLE `employee_login_setting`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `ent_form_builder`
--
ALTER TABLE `ent_form_builder`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=19;

--
-- AUTO_INCREMENT for table `failed_jobs`
--
ALTER TABLE `failed_jobs`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `fcm_routes`
--
ALTER TABLE `fcm_routes`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=26;

--
-- AUTO_INCREMENT for table `form_builder`
--
ALTER TABLE `form_builder`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=19;

--
-- AUTO_INCREMENT for table `jobs`
--
ALTER TABLE `jobs`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `job_profile_master`
--
ALTER TABLE `job_profile_master`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=36;

--
-- AUTO_INCREMENT for table `leads_history`
--
ALTER TABLE `leads_history`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=36;

--
-- AUTO_INCREMENT for table `leads_master`
--
ALTER TABLE `leads_master`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1001;

--
-- AUTO_INCREMENT for table `marketings`
--
ALTER TABLE `marketings`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `menu_permissions`
--
ALTER TABLE `menu_permissions`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `migrations`
--
ALTER TABLE `migrations`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=14;

--
-- AUTO_INCREMENT for table `number_series`
--
ALTER TABLE `number_series`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `query_builder`
--
ALTER TABLE `query_builder`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=44;

--
-- AUTO_INCREMENT for table `query_mapping`
--
ALTER TABLE `query_mapping`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;

--
-- AUTO_INCREMENT for table `referrals`
--
ALTER TABLE `referrals`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT for table `sales_and_services`
--
ALTER TABLE `sales_and_services`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=207;

--
-- AUTO_INCREMENT for table `size_master`
--
ALTER TABLE `size_master`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `stages`
--
ALTER TABLE `stages`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `states`
--
ALTER TABLE `states`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `status`
--
ALTER TABLE `status`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=44;

--
-- AUTO_INCREMENT for table `statuses`
--
ALTER TABLE `statuses`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `sync_requests`
--
ALTER TABLE `sync_requests`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `tbl_feature`
--
ALTER TABLE `tbl_feature`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `tbl_feat_access`
--
ALTER TABLE `tbl_feat_access`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

--
-- AUTO_INCREMENT for table `tbl_package`
--
ALTER TABLE `tbl_package`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `tbl_package_duration_amount`
--
ALTER TABLE `tbl_package_duration_amount`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `tenants`
--
ALTER TABLE `tenants`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `transaction_history`
--
ALTER TABLE `transaction_history`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=23;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `boutique_design_areas`
--
ALTER TABLE `boutique_design_areas`
  ADD CONSTRAINT `boutique_design_areas_ibfk_1` FOREIGN KEY (`item_id`) REFERENCES `boutique_items` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `boutique_design_options`
--
ALTER TABLE `boutique_design_options`
  ADD CONSTRAINT `boutique_design_options_ibfk_1` FOREIGN KEY (`design_area_id`) REFERENCES `boutique_design_areas` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `job_profile_master`
--
ALTER TABLE `job_profile_master`
  ADD CONSTRAINT `job_profile_master_ibfk_1` FOREIGN KEY (`business_id`) REFERENCES `business_categories` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `menu_permissions`
--
ALTER TABLE `menu_permissions`
  ADD CONSTRAINT `menu_permissions_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
