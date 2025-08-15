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
-- Database: `non_prod_tenant_3`
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
(1, 1, 'Designer saree', 1, 3500.00, 2999.00, 2999.00, 2999.00, 6.00, 2, NULL, '2025-08-12 06:46:41', '2025-08-12 06:46:41'),
(2, 1, 'Bridal lehanga', 1, 2500.00, 1500.00, 1500.00, 1680.00, 6.00, 1, NULL, '2025-08-12 06:46:41', '2025-08-12 06:46:41');

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
-- Table structure for table `customers`
--

CREATE TABLE `customers` (
  `id` int(10) UNSIGNED NOT NULL,
  `emp_id` bigint(20) DEFAULT NULL,
  `phone_account_id` varchar(50) DEFAULT NULL,
  `name` varchar(255) NOT NULL,
  `email` varchar(255) DEFAULT NULL,
  `mobile` varchar(100) NOT NULL,
  `type` varchar(100) DEFAULT NULL,
  `source` varchar(100) DEFAULT NULL,
  `another_mobile` varchar(100) DEFAULT NULL,
  `company` varchar(255) DEFAULT NULL,
  `gst` varchar(100) DEFAULT NULL,
  `profile_pic` varchar(100) DEFAULT NULL,
  `location` varchar(255) DEFAULT NULL,
  `group` varchar(255) DEFAULT NULL,
  `dob` varchar(255) DEFAULT NULL,
  `anniversary` varchar(255) DEFAULT NULL,
  `created_by` bigint(20) DEFAULT NULL,
  `status` int(11) DEFAULT 1,
  `contact_status` varchar(255) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `is_deleted` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `customers`
--

INSERT INTO `customers` (`id`, `emp_id`, `phone_account_id`, `name`, `email`, `mobile`, `type`, `source`, `another_mobile`, `company`, `gst`, `profile_pic`, `location`, `group`, `dob`, `anniversary`, `created_by`, `status`, `contact_status`, `created_at`, `updated_at`, `is_deleted`) VALUES
(1, NULL, '2246', 'AAM', NULL, '8754592393', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(2, NULL, '2901', 'AAM kishore', NULL, '8939685311', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(3, NULL, '2917', 'AAM patil', NULL, '9881261368', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(4, NULL, '2909', 'AAM Pradeep', NULL, '8939685325', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(5, NULL, '10013', 'AAM Rajavelan', NULL, '8754571070', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(6, NULL, '4218', 'AAM Rajesh', NULL, '9730066771', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(7, NULL, '3433', 'Aanjana 2', NULL, '6374838392', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(8, NULL, '4219', 'Aanjana Lifestyle', NULL, '8939043853', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(9, NULL, '10026', 'Abdul Vamo systems', NULL, '7550179997', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(10, NULL, '9905', 'Abhimanyu', NULL, '8971204817', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(11, NULL, '4221', 'Abhishek Personal', NULL, '9999302498', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(12, NULL, '69', 'Abhu 506', NULL, '2488826549', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(13, NULL, '4223', 'AC Mechanic Afreen', NULL, '8189876569', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(14, NULL, '2788', 'AD agro rythu seva BM Kumar', NULL, '9866229139', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(15, NULL, '4226', 'AD Akhila agencies Raju', NULL, '9845253779', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(16, NULL, '3571', 'AD Akshay agro', NULL, '9486338952', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(17, NULL, '3021', 'AD Alagar Kailasam Agency', NULL, '9003916391', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(18, NULL, '9789', 'AD Amruth Entrprises Suryakanth', NULL, '9449688458', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(19, NULL, '4227', 'AD Amrutha agro agency', NULL, '9449874794', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(20, NULL, '2769', 'AD Anbu Traders Vinothkumar', NULL, '9443321332', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(21, NULL, '3970', 'AD Ankush Samrudhi Agro Centre', NULL, '9886440636', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(22, NULL, '2530', 'AD Annai agency', NULL, '9443263465', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(23, NULL, '2403', 'AD Aroor Agro chemicals', NULL, '9095011566', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(24, NULL, '4228', 'AD Arvind Karupiah', NULL, '9942020046', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(25, NULL, '3989', 'AD Bala Sri kumaran farm', NULL, '9842137400', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(26, NULL, '2920', 'AD Bharathy agro', NULL, '9842740637', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(27, NULL, '3630', 'AD Evergreen Agro Jose', NULL, '9786685583', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(28, NULL, '2699', 'AD Evergreen agrp', NULL, '9943963999', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(29, NULL, '9714', 'AD Global agro Nitin Tekale', NULL, '9860294308', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(30, NULL, '2807', 'AD guna traders', NULL, '9095187363', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(31, NULL, '2249', 'AD Kamaraj Sri Subhalakshmi', NULL, '9842724330', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(32, NULL, '3618', 'AD Kissan fertilizer', NULL, '9842153191', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(33, NULL, '8521', 'AD Krishna Agro Ram Kiran', NULL, '9886773512', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(34, NULL, '4230', 'AD Lakshmi agro service', NULL, '9444437472', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(35, NULL, '4231', 'AD Mahi Seeds Mahesh', NULL, '9865161168', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(36, NULL, '956', 'AD Meenakshi agency', NULL, '9794444350', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(37, NULL, '3990', 'AD Paul madailkiiyal kerala', NULL, '6282463709', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(38, NULL, '3962', 'AD Peeyar Agro Gopinathan', NULL, '9842123310', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(39, NULL, '3038', 'AD PNR Sudhakar Director', NULL, '9550538765', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(40, NULL, '4232', 'AD Priyadarshini Andal Fertilizer', NULL, '6382775158', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(41, NULL, '2831', 'AD Pugalendhi Udumpet Hitech', NULL, '9842225540', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(42, NULL, '2843', 'AD Raayan agro', NULL, '9443750132', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(43, NULL, '4233', 'AD Raghunathan KKV Hitech Rasipuram', NULL, '9443211752', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(44, NULL, '3889', 'AD Rajendran Rank Marketing', NULL, '9500915000', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(45, NULL, '3629', 'AD Ramachandran Srisubhalakshmi Hybridseeds', NULL, '9443243089', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(46, NULL, '1123', 'AD Ramamoorthy 2 srk', NULL, '9786666615', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(47, NULL, '4234', 'AD Ramamoorthy Srk Seeds', NULL, '9443042372', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(48, NULL, '4235', 'AD Ravi chandra', NULL, '9985829939', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(49, NULL, '2538', 'AD Sachin Hanuman agro', NULL, '7795606267', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(50, NULL, '4236', 'AD Saisiri agencies telengana', NULL, '9989535657', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(51, NULL, '4237', 'AD Sangamesh agro Sharad', NULL, '9886846898', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(52, NULL, '4238', 'AD Shreyas Manjunatha agro', NULL, '9741882731', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(53, NULL, '3992', 'AD Sri vinayaga pannai', NULL, '9942625775', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(54, NULL, '7987', 'AD Sudhakar nageshwar rao', NULL, '9848099966', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(55, NULL, '4239', 'AD Sundaramoorthy Srivari', NULL, '9943952699', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(56, NULL, '2913', 'AD Thirumagal agencies', NULL, '9894325284', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(57, NULL, '8527', 'AD Thirumagal Agro', NULL, '9443247966', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(58, NULL, '3642', 'AD vel urakkadai', NULL, '9943449242', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(59, NULL, '3532', 'AD Vignesh Enterprises', NULL, '9500577774', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(60, NULL, '3336', 'AD Vijayam Agencies Senthil', NULL, '9791378888', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(61, NULL, '4240', 'AD Vinayak Patil Akshaya agro', NULL, '9008455531', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(62, NULL, '5983', 'Adeptek Sushma', NULL, '9535485788', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(63, NULL, '2786', 'Adhipranesh V', NULL, '9042011521', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(64, NULL, '4242', 'Adithya Auto Ev Perumal', NULL, '9841984127', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(65, NULL, '9824', 'Adv Siva Gopi', NULL, '9345410689', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(66, NULL, '2976', 'Advance Pesticide Kudhal', NULL, '8308800539', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(67, NULL, '2138', 'Advocate Hariharan Rekha Anni Connect', NULL, '9884334293', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(68, NULL, '7309', 'Advocate Sundarrajan', NULL, '8610410953', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(69, NULL, '10371', 'Agrica Anand Erode', NULL, '9965446688', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(70, NULL, '4246', 'Airtel DFD Sushmit', NULL, '7428469025', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(71, NULL, '4245', 'Airtel Kumaravel', NULL, '9444545844', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(72, NULL, '6221', 'Aishwarya', NULL, '9488001739', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(73, NULL, '7286', 'Aishwarya Boutique', NULL, '9986642531', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(74, NULL, '9628', 'Ajay Neighbor', NULL, '9940245441', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(75, NULL, '474', 'Ajeez Driver Mohamad', NULL, '9994820530', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(76, NULL, '10077', 'Ajit Ashima', NULL, '9820117769', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(77, NULL, '473', 'Akash 2', NULL, '7010792366', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(78, NULL, '823', 'Akash Blood Report', NULL, '4424726666', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(79, NULL, '3441', 'Akash Reception', NULL, '7299974701', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(80, NULL, '2214', 'Akshay Agro Banu Prakash', NULL, '9880293116', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(81, NULL, '4252', 'Alf Nilesh', NULL, '9370239300', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(82, NULL, '4255', 'Alf Nilesh jadhav', NULL, '8888315707', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(83, NULL, '9950', 'Alf Ram', NULL, '9677798476', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(84, NULL, '237', 'Alf Ram 2', NULL, '7092645830', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(85, NULL, '4250', 'Alf Suhas', NULL, '9822765445', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(86, NULL, '3756', 'Alf Vikram', NULL, '9922439871', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(87, NULL, '2416', 'Aliyaz Gauge Vendor', NULL, '9940999811', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(88, NULL, '683', 'Allen New', NULL, '7358306804', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(89, NULL, '3033', 'Alpha Chandrasekaran', NULL, '9840151200', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(90, NULL, '3827', 'Alpines GM NITIN', NULL, '9740183707', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(91, NULL, '4259', 'Altacit lakshminarayan adv', NULL, '9840590483', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(92, NULL, '4258', 'Altacit Prakash', NULL, '8608899958', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(93, NULL, '1024', 'Amala', NULL, '9566164978', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(94, NULL, '3701', 'Ambicavoda', NULL, '9884728158', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(95, NULL, '4009', 'Ambika', NULL, '8939326355', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(96, NULL, '403', 'Amit 2', NULL, '9971527772', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(97, NULL, '4261', 'Amit GGN', NULL, '9350437944', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(98, NULL, '697', 'Amit Jio', NULL, '8708576163', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(99, NULL, '75', 'Amit Landline', NULL, '1244595222', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(100, NULL, '3961', 'Amit Personal', NULL, '9643132246', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(101, NULL, '303', 'Amit Plant Head Nipman', NULL, '7895002102', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(102, NULL, '274', 'Amma', NULL, '9500102106', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(103, NULL, '10104', 'Amma', NULL, '9789932630', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(104, NULL, '857', 'Amudha', NULL, '7904819794', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(105, NULL, '3523', 'Amudha 2', NULL, '6379012470', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(106, NULL, '3214', 'Anagha', NULL, '9920921993', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(107, NULL, '9788', 'Analtytical invstmnt pavan', NULL, '9606602808', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(108, NULL, '4265', 'Ananada Cell City', NULL, '9841600249', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(109, NULL, '3914', 'Anand anna vellore', NULL, '9884254774', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(110, NULL, '4266', 'Anand CTS sai cousin', NULL, '9841504947', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(111, NULL, '890', 'Anand Keluskar Ferring Pharma', NULL, '9172344392', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(112, NULL, '7459', 'Anand Rajashekhar Shimoga', NULL, '9844400490', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(113, NULL, '3924', 'Anekal FPo siddaraju', NULL, '9482192508', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(114, NULL, '6768', 'Angel\'s Abode Principal', NULL, '7892109438', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(115, NULL, '3882', 'Angels abode Uday', NULL, '9538273679', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(116, NULL, '3037', 'Anil Nippon', NULL, '9791033844', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(117, NULL, '734', 'Anita Whatsapp', NULL, '7200078630', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(118, NULL, '2507', 'Anmol Rajarshi', NULL, '9163348151', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(119, NULL, '3997', 'Annachi.india', NULL, '9940127529', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(120, NULL, '455', 'Annachi.usa', NULL, '2482490945', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(121, NULL, '9605', 'Anu Akka', NULL, '9940186361', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(122, NULL, '9608', 'Anu Anni Whatsapp', NULL, '9790928140', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(123, NULL, '1790', 'Anurekha Anni', NULL, '9444082012', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(124, NULL, '2301', 'Apollo bangalore', NULL, '6361042346', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(125, NULL, '7527', 'Apollo Muthu', NULL, '8838021140', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(126, NULL, '4269', 'Appa', NULL, '9789933120', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(127, NULL, '3423', 'Aqua gen RO', NULL, '7550048482', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(128, NULL, '8520', 'Aqua Gen Ro Prabhakaran', NULL, '9941103330', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(129, NULL, '10289', 'Ar Express Annamalai', NULL, '9945006325', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(130, NULL, '3316', 'AR Sapthagiri Srinivasa', NULL, '9449658756', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(131, NULL, '3766', 'AR Shilpa Hitech Dr Shivanna', NULL, '9845440599', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(132, NULL, '5196', 'Aravind.ranjith', NULL, '9894533598', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(133, NULL, '2142', 'Arinjay', NULL, '8824671246', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(134, NULL, '861', 'arthi subbu chennai', NULL, '6374002662', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(135, NULL, '4273', 'Arthi Vaitheeswaran', NULL, '9597417317', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(136, NULL, '3625', 'Arthi.sister', NULL, '9566063780', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(137, NULL, '2552', 'Artis agro Vijay markad', NULL, '8380096875', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(138, NULL, '10121', 'Arul chithappa banglr', NULL, '9940047498', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(139, NULL, '9988', 'Arul KWE', NULL, '9176440112', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(140, NULL, '4275', 'Arul Paaps', NULL, '9715415441', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(141, NULL, '3976', 'Arumugam Peripa', NULL, '4422236180', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(142, NULL, '10111', 'Arun Anna1', NULL, '9952581310', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(143, NULL, '797', 'Arun donaldson', NULL, '9560194449', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(144, NULL, '10062', 'Arun Gokul Friend Chn', NULL, '9884707337', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(145, NULL, '6654', 'Arun JBM', NULL, '8248704697', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(146, NULL, '2093', 'Arun Saran Corporation', NULL, '7812077120', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(147, NULL, '4281', 'Aruna School', NULL, '9841989178', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(148, NULL, '472', 'Aruna.csc', NULL, '2483960466', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(149, NULL, '4282', 'Arunfrend1', NULL, '9791009711', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(150, NULL, '7557', 'Arunkumar. N So. K.s. Narasimhan D S P Neelangarai', NULL, '9025231250', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(151, NULL, '2773', 'Ascen hyveg Abhishek', NULL, '9940958786', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(152, NULL, '2516', 'Ascen Ramesh', NULL, '9500455922', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(153, NULL, '4283', 'Ashima Ayush deep pandey', NULL, '8840379685', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(154, NULL, '4284', 'Ashok coimbatore', NULL, '8778608990', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(155, NULL, '4286', 'Ashok Colg Dubai', NULL, '1566594868', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(156, NULL, '425', 'Ashok.wife', NULL, '8479128027', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(157, NULL, '1115', 'Ashoka Comforts', NULL, '8392279970', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(158, NULL, '4288', 'Ashwath gangavathi region', NULL, '9535364488', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(159, NULL, '3868', 'Ashwin CMC', NULL, '9894355731', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(160, NULL, '9576', 'Asim One Optician A', NULL, '9980803994', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(161, NULL, '2974', 'Athinarayanan San', NULL, '8939863623', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(162, NULL, '3512', 'Austin Anand', NULL, '9886395584', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(163, NULL, '2308', 'Auto Johnson Bangalore', NULL, '9742551289', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(164, NULL, '3134', 'Auto Rahim', NULL, '9043509972', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(165, NULL, '4291', 'Avdel HITESH', NULL, '9820402627', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(166, NULL, '3105', 'Avdel Sudir', NULL, '9900611539', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(167, NULL, '777', 'Avtec', NULL, '8236834815', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(168, NULL, '3240', 'Avtec Kapil', NULL, '7990455301', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(169, NULL, '3271', 'Avtec Mohit', NULL, '8770921927', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(170, NULL, '4292', 'AVTeC Samresh Singh', NULL, '9755473410', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(171, NULL, '4293', 'Ayanar selvi plumber', NULL, '9566203999', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(172, NULL, '241', 'Ayyappa Landline', NULL, '8027831071', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(173, NULL, '10079', 'Babu Anna New Number', NULL, '9080184156', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(174, NULL, '6736', 'Babu Indian Bank', NULL, '9444046565', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(175, NULL, '4294', 'Bagampriyal', NULL, '9486482777', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(176, NULL, '4295', 'Bala.car', NULL, '5862025645', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(177, NULL, '4298', 'Balaji 2', NULL, '8072599924', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(178, NULL, '2187', 'Balaji Ace', NULL, '9940175093', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(179, NULL, '2510', 'Balaji Ace 2', NULL, '9025255093', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(180, NULL, '4300', 'Balaji Frnd Senthil', NULL, '9500456030', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(181, NULL, '4296', 'Balaji katpadi', NULL, '9841398239', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(182, NULL, '280', 'Balaji Landline', NULL, '4467167745', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(183, NULL, '4297', 'Balaji Sai', NULL, '9597753387', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(184, NULL, '678', 'Balambika Udhaya', NULL, '8061348309', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(185, NULL, '4302', 'bam singh', NULL, '8373944262', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(186, NULL, '4303', 'Bang city police', NULL, '9480801000', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(187, NULL, '7660', 'Banglore Sankar', NULL, '9740471617', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(188, NULL, '2626', 'Banu.perima', NULL, '9840995530', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(189, NULL, '4305', 'Bapu Gaikwad Nasik', NULL, '9850732435', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(190, NULL, '680', 'Barad.mobile', NULL, '8870127561', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(191, NULL, '4306', 'Baskar Sir MD Park Inn Resorts', NULL, '9841088139', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(192, NULL, '2160', 'Bayer balaji', NULL, '9003049371', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(193, NULL, '4310', 'Bb', NULL, '9884395464', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(194, NULL, '2336', 'BCIC Narasimha Nakshatri', NULL, '9741898711', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(195, NULL, '7690', 'BCIC Rajashree', NULL, '9900210107', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(196, NULL, '2152', 'Best Agrolite Vandita', NULL, '9599927524', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(197, NULL, '2291', 'bethesda', NULL, '9698477700', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(198, NULL, '2218', 'BG Piyush', NULL, '8308814086', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(199, NULL, '3292', 'Bharat certis Krishna Saxena', NULL, '9289360474', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(200, NULL, '4311', 'Bharat.jaya', NULL, '9791124053', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(201, NULL, '252', 'Bharat.matri', NULL, '4439243849', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(202, NULL, '61', 'Bharat.matri1', NULL, '4439144101', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(203, NULL, '4312', 'Bharat.yamuna', NULL, '9942364712', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(204, NULL, '2566', 'Bhavani', NULL, '9443644277', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(205, NULL, '4314', 'BHAVYA TAN', NULL, '7904450352', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(206, NULL, '2153', 'Bheem sen SVFS', NULL, '9449072683', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(207, NULL, '7172', 'Bhoomika House Of Atlier', NULL, '7899024315', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(208, NULL, '3792', 'Bhupinder Rikki Plastics', NULL, '8870333806', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(209, NULL, '4316', 'Bhushan signutra', NULL, '7208040547', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(210, NULL, '4317', 'Bhuvana Krishna', NULL, '9962640428', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(211, NULL, '3945', 'bike.mechanic', NULL, '9600061660', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(212, NULL, '4318', 'Binil Balakrishnan Sanofi', NULL, '9585222544', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(213, NULL, '314', 'Blue', NULL, '0445891381', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(214, NULL, '160', 'Blue Dart Customer Care', NULL, '8602331234', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(215, NULL, '156', 'Blue Dart Delhi Kabiraj', NULL, '7008111160', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(216, NULL, '2303', 'Blue Dart Rajiv Gandhi', NULL, '9500284825', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(217, NULL, '394', 'Blue Dart Ruban', NULL, '8056015935', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(218, NULL, '3607', 'Blue Dart Sriperumpudur Office', NULL, '9940082638', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(219, NULL, '569', 'Blue Dart Support', NULL, '8754597800', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(220, NULL, '742', 'Blue Dart Vanakumar Disptch', NULL, '9790725215', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(221, NULL, '1103', 'Blue Star', NULL, '8002091177', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(222, NULL, '666', 'BM Jaysree', NULL, '9962122955', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(223, NULL, '4319', 'Bnglr house sandeep', NULL, '8142111840', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(224, NULL, '3536', 'Boat New', NULL, '9995544116', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(225, NULL, '1620', 'Boobathy Auto', NULL, '9940325356', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(226, NULL, '3686', 'Boopathy IB Survey', NULL, '9003991336', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(227, NULL, '4321', 'Brakes India Bhuvnesh', NULL, '9840204451', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(228, NULL, '4322', 'Broker Srini', NULL, '6379650498', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(229, NULL, '4328', 'Cab Praveen', NULL, '7338952355', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(230, NULL, '2849', 'Cable Tv', NULL, '9941237226', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(231, NULL, '4329', 'Cactus Anchal Tyagi', NULL, '9731641166', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(232, NULL, '10305', 'Callyzer Nimmy', NULL, '9081444096', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(233, NULL, '4330', 'Camera Man Cctv', NULL, '9566903353', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(234, NULL, '4331', 'Canada Arun School', NULL, '4162545510', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(235, NULL, '3852', 'Carvewing Akhila', NULL, '8310134422', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(236, NULL, '4333', 'Carvewing Arpit', NULL, '7022450733', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(237, NULL, '4339', 'Carvewing Harshini G', NULL, '7975226403', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(238, NULL, '4340', 'carvewing jay patel', NULL, '7359258270', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(239, NULL, '4335', 'Carvewing Keerthi', NULL, '8762308860', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(240, NULL, '3440', 'Carvewing Luke', NULL, '9258758616', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(241, NULL, '4341', 'Carvewing Megha Chopdi CW', NULL, '7483747399', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(242, NULL, '3740', 'Carvewing Niranjan', NULL, '8105188589', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(243, NULL, '4336', 'Carvewing Palak', NULL, '9826252262', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(244, NULL, '5475', 'Carvewing Prassana', NULL, '9533519732', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(245, NULL, '10103', 'Carvewing Prathiksha', NULL, '7022329256', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(246, NULL, '4337', 'Carvewing Roopashri', NULL, '8197905542', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(247, NULL, '4334', 'Carvewing Sagar', NULL, '8217371089', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(248, NULL, '6735', 'Carvewing Yoga', NULL, '9677003373', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(249, NULL, '4342', 'Carvewong Amratha', NULL, '9845834909', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(250, NULL, '2035', 'Cashify 2', NULL, '9953353995', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(251, NULL, '8651', 'Cashify Vignesh', NULL, '8072327435', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(252, NULL, '3715', 'Catering', NULL, '9941105289', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(253, NULL, '2320', 'CF Prabu Anna', NULL, '9884348390', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(254, NULL, '4345', 'Chaitra rajagatta HFPC', NULL, '9740316509', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(255, NULL, '4346', 'Chaitra Tubugere HFPC', NULL, '7483199102', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(256, NULL, '706', 'Chander Driver', NULL, '9967389521', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(257, NULL, '2862', 'Chandru Builder', NULL, '9840984126', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(258, NULL, '8557', 'Charmine Chaya Designer Sudio', NULL, '8310734322', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0);
INSERT INTO `customers` (`id`, `emp_id`, `phone_account_id`, `name`, `email`, `mobile`, `type`, `source`, `another_mobile`, `company`, `gst`, `profile_pic`, `location`, `group`, `dob`, `anniversary`, `created_by`, `status`, `contact_status`, `created_at`, `updated_at`, `is_deleted`) VALUES
(259, NULL, '5515', 'CHB_AbiFashionsKidswear', NULL, '9884856904', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(260, NULL, '10012', 'CHB_Afra-ModestBoutique', NULL, '8637644692', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(261, NULL, '5492', 'CHB_ArshaBoutique', NULL, '9003123766', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(262, NULL, '5516', 'CHB_ASMBOUTIQUE', NULL, '9384644939', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(263, NULL, '5496', 'CHB_AuraFashionEmporium', NULL, '9677019189', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(264, NULL, '5524', 'CHB_Aurelia', NULL, '9543730659', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(265, NULL, '5521', 'CHB_Chellama\'SBoutique', NULL, '9043626155', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(266, NULL, '5487', 'CHB_DAWNDRESSES', NULL, '9840181960', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(267, NULL, '5522', 'CHB_DeDeeFashion', NULL, '9080078326', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(268, NULL, '5500', 'CHB_DevaTextiles', NULL, '9962833648', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(269, NULL, '5481', 'CHB_DreamFashionMen\'sWear', NULL, '8940088071', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(270, NULL, '5529', 'CHB_DwarakaBoutique', NULL, '7358090363', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(271, NULL, '5503', 'CHB_FashionOutfitMenswear', NULL, '8248344461', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(272, NULL, '5534', 'CHB_FocusMensWear-Pallaavaram', NULL, '9585400030', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(273, NULL, '5508', 'CHB_GLOCOLLECTIONS', NULL, '9840662504', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(274, NULL, '5489', 'CHB_HiyaFashions&Boutique-Women\'sApparel&Customisation', NULL, '7299927172', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(275, NULL, '5494', 'CHB_IndianTerrain-Chrompet,Chennai', NULL, '8069866670', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(276, NULL, '5533', 'CHB_InspireTrendyBoutique', NULL, '9884443308', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(277, NULL, '5501', 'CHB_JLFASHIONBOUTIQUE', NULL, '9840833490', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(278, NULL, '5527', 'CHB_KardhanaDesignerBoutique', NULL, '8438532333', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(279, NULL, '5523', 'CHB_KarpagavalliCouturetailoring&Trainingcentre', NULL, '9789009067', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(280, NULL, '5531', 'CHB_LakshaInstituteoffashiontechnology', NULL, '8838055388', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(281, NULL, '5511', 'CHB_MadrasBoutique', NULL, '9841665033', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(282, NULL, '5507', 'CHB_Max', NULL, '9150085547', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(283, NULL, '5517', 'CHB_MAYABoutique', NULL, '9894825425', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(284, NULL, '5498', 'CHB_MedleyBoutique', NULL, '9841144055', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(285, NULL, '5483', 'CHB_MeenaTailor', NULL, '7200712429', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(286, NULL, '5525', 'CHB_Milir', NULL, '8925425777', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(287, NULL, '5513', 'CHB_MOORTHYBOUTIIQUE', NULL, '7904155927', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(288, NULL, '5532', 'CHB_MyDreamz', NULL, '9840830180', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(289, NULL, '5490', 'CHB_NalliSilkSareesatChrompet', NULL, '8095877784', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(290, NULL, '5495', 'CHB_Needle&Threads', NULL, '8939124602', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(291, NULL, '5482', 'CHB_NeubabybyNuberryChrompetBabyShop', NULL, '7448805217', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(292, NULL, '5493', 'CHB_NewBoutiqQueen', NULL, '9445539191', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(293, NULL, '5512', 'CHB_OUTFITIN-ChrompetClothingStore', NULL, '9940165467', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(294, NULL, '5488', 'CHB_ParijatCollections', NULL, '9500094822', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(295, NULL, '5519', 'CHB_POONTHUGIL', NULL, '9363736093', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(296, NULL, '5506', 'CHB_RahmaanTextiles&Readymades', NULL, '9841804546', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(297, NULL, '5485', 'CHB_RamrajCotton-Chrompet,Chennai', NULL, '7639049147', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(298, NULL, '5528', 'CHB_RaymondReadytoWear', NULL, '8069865895', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(299, NULL, '5491', 'CHB_RKBoutique-TailorShopinChennai', NULL, '9677188031', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(300, NULL, '5526', 'CHB_Saiboutique', NULL, '9003233810', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(301, NULL, '5484', 'CHB_SecretFashions', NULL, '9944139684', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(302, NULL, '5518', 'CHB_SelectionDresses', NULL, '9003158356', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(303, NULL, '5510', 'CHB_SEWINSTYLE', NULL, '9677028951', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(304, NULL, '5520', 'CHB_ShreeBoutique', NULL, '9941381232', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(305, NULL, '5509', 'CHB_ShreeTex', NULL, '9176755766', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(306, NULL, '5486', 'CHB_SrutthiDresses', NULL, '7200936702', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(307, NULL, '5982', 'CHB_TempleTheDesignerStudioSarees', NULL, '9025604609', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(308, NULL, '5499', 'CHB_THAMIZHINIFASHIONZ', NULL, '8072844769', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(309, NULL, '5505', 'CHB_TharamFashions', NULL, '9940684031', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(310, NULL, '5502', 'CHB_ThenuBoutique', NULL, '9841526267', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(311, NULL, '5497', 'CHB_Threadlines', NULL, '7305309990', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(312, NULL, '5480', 'CHB_TRENDS', NULL, '9360701072', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(313, NULL, '5530', 'CHB_Trends-in', NULL, '9940299665', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(314, NULL, '2659', 'Chennai CASa', NULL, '9176786321', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(315, NULL, '2253', 'Chidambaram', NULL, '9094774504', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(316, NULL, '4347', 'Chidambaram Rane Trw', NULL, '9500241622', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(317, NULL, '796', 'Chinamu', NULL, '9566013886', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(318, NULL, '2104', 'Chinamu 1', NULL, '9840681258', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(319, NULL, '2425', 'Chinna.shans', NULL, '9884338248', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(320, NULL, '3676', 'Chithra Aunty', NULL, '9940536091', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(321, NULL, '35', 'Chn Coating Giri Babu', NULL, '9840149106', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(322, NULL, '3845', 'Chockan Engineering', NULL, '9943704787', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(323, NULL, '7114', 'Christopher Intern Kristu Jnth Coll', NULL, '9366119089', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(324, NULL, '114', 'Citi Cc', NULL, '4428522484', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(325, NULL, '497', 'Citiairways', NULL, '8882484697', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(326, NULL, '4349', 'CKM Badrakumar', NULL, '9176628019', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(327, NULL, '1514', 'CKM Manikandan', NULL, '9176674660', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(328, NULL, '3221', 'CkM Shyam', NULL, '9176633409', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(329, NULL, '3517', 'Clients Solutions Vidyaranypura', NULL, '9035200040', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(330, NULL, '2859', 'Cloudlead.ai', NULL, '9860172606', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(331, NULL, '4351', 'colg.annatha', NULL, '9551727858', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(332, NULL, '4352', 'colg.Auto', NULL, '9600093049', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(333, NULL, '2945', 'Colg.bala', NULL, '9789992546', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(334, NULL, '2232', 'Complinity Anwesha', NULL, '8882927997', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(335, NULL, '3867', 'Conrad', NULL, '9158006034', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(336, NULL, '4353', 'Contractzy Pinky', NULL, '7972848875', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(337, NULL, '4354', 'Cook Boomi', NULL, '9789997547', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(338, NULL, '8523', 'Country Club Jade Beach Resort', NULL, '9710447365', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(339, NULL, '4358', 'Croma Delivery Theju', NULL, '9663314557', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(340, NULL, '1027', 'crystal crop lalith', NULL, '9560917722', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(341, NULL, '4360', 'crystal lalit', NULL, '9958793105', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(342, NULL, '419', 'Csc help desk', NULL, '8776122211', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(343, NULL, '218', 'Csc hr', NULL, '7033181500', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(344, NULL, '4363', 'Csc Kannan Mgr', NULL, '9841072138', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(345, NULL, '720', 'Csc Karthik Usa', NULL, '4798029160', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(346, NULL, '10129', 'Csc lakshman', NULL, '9840713738', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(347, NULL, '268', 'csc Madhavan', NULL, '9884749726', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(348, NULL, '4361', 'Csc meiyappan', NULL, '9003743995', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(349, NULL, '9856', 'Csc shanawaz', NULL, '9884143384', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(350, NULL, '9974', 'Csc venkat. team', NULL, '9840411534', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(351, NULL, '566', 'Csc.abi', NULL, '9003546109', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(352, NULL, '3823', 'Csc.akilan', NULL, '9884617600', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(353, NULL, '4365', 'Csc.Arthi', NULL, '8056085242', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(354, NULL, '265', 'Csc.arun', NULL, '9962485724', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(355, NULL, '258', 'Csc.bala.koyi', NULL, '9176266624', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(356, NULL, '4366', 'Csc.balaji.purna', NULL, '9943180072', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(357, NULL, '3548', 'Csc.ballu', NULL, '7845577619', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(358, NULL, '4367', 'Csc.barani', NULL, '9994117687', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(359, NULL, '312', 'Csc.baranifather', NULL, '9003236029', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(360, NULL, '4368', 'Csc.bharathi', NULL, '9940744428', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(361, NULL, '712', 'Csc.bhuvan.hr', NULL, '8754550144', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(362, NULL, '525', 'Csc.cts.kartikusa', NULL, '4793404361', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(363, NULL, '180', 'csc.dineshmainfrm', NULL, '9790971726', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(364, NULL, '3377', 'Csc.divya', NULL, '9994239423', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(365, NULL, '461', 'Csc.divya.priya', NULL, '9092273138', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(366, NULL, '4370', 'Csc.elango', NULL, '9789591717', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(367, NULL, '4371', 'Csc.guru', NULL, '9865040027', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(368, NULL, '3070', 'Csc.harsha', NULL, '8056107784', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(369, NULL, '3036', 'Csc.hema', NULL, '9841632702', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(370, NULL, '2872', 'csc.Ilango', NULL, '9884044110', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(371, NULL, '3216', 'Csc.jp', NULL, '9840311343', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(372, NULL, '4372', 'Csc.kamalesh', NULL, '7418458408', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(373, NULL, '3729', 'Csc.kanthan', NULL, '9941451347', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(374, NULL, '4373', 'Csc.karthiksampa', NULL, '9840782132', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(375, NULL, '608', 'Csc.kirutika', NULL, '9789489263', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(376, NULL, '2572', 'Csc.koushik', NULL, '9381753650', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(377, NULL, '673', 'csc.Kumar', NULL, '9884700969', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(378, NULL, '393', 'Csc.latha.akka', NULL, '9566033377', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(379, NULL, '3835', 'Csc.lekha', NULL, '9789257762', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(380, NULL, '780', 'Csc.limbi', NULL, '9003565670', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(381, NULL, '10372', 'Csc.mariappan', NULL, '9952172736', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(382, NULL, '3577', 'Csc.mparts.karthi', NULL, '9942111639', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(383, NULL, '7764', 'Csc.murali', NULL, '9940124388', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(384, NULL, '3697', 'Csc.muthu', NULL, '9884306665', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(385, NULL, '3431', 'Csc.naveen', NULL, '7708956354', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(386, NULL, '3596', 'Csc.nithya', NULL, '9500449627', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(387, NULL, '2701', 'Csc.partha', NULL, '9884744054', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(388, NULL, '652', 'Csc.pravin', NULL, '9962809182', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(389, NULL, '398', 'Csc.priya.cousin', NULL, '9940429385', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(390, NULL, '184', 'Csc.punitha', NULL, '9940361052', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(391, NULL, '4375', 'Csc.punithanew', NULL, '9176326387', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(392, NULL, '494', 'csc.Raghu', NULL, '9884623525', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(393, NULL, '66', 'Csc.rajitha', NULL, '8438951263', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(394, NULL, '4376', 'Csc.rajitha.sitan', NULL, '9962594622', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(395, NULL, '482', 'Csc.rajithanew', NULL, '9003137271', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(396, NULL, '2720', 'Csc.rajnish', NULL, '9841485439', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(397, NULL, '4377', 'Csc.ram', NULL, '9962517273', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(398, NULL, '41', 'Csc.ram.usa', NULL, '5033295326', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(399, NULL, '744', 'Csc.ramesh', NULL, '2486138046', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(400, NULL, '2966', 'Csc.ravi.sandy', NULL, '9840691901', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(401, NULL, '659', 'Csc.sankar.vb', NULL, '9600065470', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(402, NULL, '193', 'csc.Sankarmainfra', NULL, '9094946084', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(403, NULL, '10117', 'csc.Santhosh', NULL, '9994527827', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(404, NULL, '3767', 'Csc.satesh.sarava', NULL, '9790413311', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(405, NULL, '658', 'Csc.satesh1', NULL, '9842058491', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(406, NULL, '10120', 'Csc.satheesh', NULL, '9790086689', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(407, NULL, '2915', 'Csc.sheeba', NULL, '9840845245', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(408, NULL, '4380', 'Csc.sivasankar', NULL, '9942540076', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(409, NULL, '2461', 'Csc.sridharthalap', NULL, '9840473343', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(410, NULL, '4381', 'Csc.subranchu', NULL, '9445007750', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(411, NULL, '2799', 'Csc.sundar', NULL, '8122425192', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(412, NULL, '10107', 'Csc.sureshbabu', NULL, '9894216233', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(413, NULL, '4382', 'Csc.sureshmanger', NULL, '9840302047', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(414, NULL, '10069', 'csc.Sureshvera', NULL, '9841245505', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(415, NULL, '242', 'Csc.tcs.mani', NULL, '9965018612', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(416, NULL, '3604', 'Csc.thahaseen', NULL, '9710410827', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(417, NULL, '416', 'Csc.uday', NULL, '9500056630', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(418, NULL, '564', 'Csc.vadivel', NULL, '9600169714', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(419, NULL, '582', 'csc.Vamsee', NULL, '9566002982', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(420, NULL, '590', 'Csc.venkat.usa1', NULL, '2482751861', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(421, NULL, '378', 'Csc.vijay.infy', NULL, '9600011425', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(422, NULL, '2693', 'csc.Vijay.pdr', NULL, '9551789280', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(423, NULL, '4385', 'Csc.vimal', NULL, '9884818878', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(424, NULL, '3297', 'csc.visnupriya', NULL, '8098881305', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(425, NULL, '263', 'Cscanusha', NULL, '9791133539', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(426, NULL, '3888', 'Cscmadhujilla', NULL, '9849616732', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(427, NULL, '708', 'Csctransport', NULL, '9940113973', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(428, NULL, '4387', 'ctv Paramesh D', NULL, '9786923713', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(429, NULL, '4388', 'D Venkat. ps', NULL, '9600155592', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(430, NULL, '506', 'Daikin CC', NULL, '8001029300', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(431, NULL, '10067', 'Damodaran Vilvarani', NULL, '9943590343', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(432, NULL, '3872', 'Darshan Saurabh Vivek (Huf)', NULL, '9405000044', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(433, NULL, '3190', 'Dasarathan Vehicle', NULL, '9626438339', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(434, NULL, '3136', 'David.telesis', NULL, '9500015633', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(435, NULL, '3870', 'DCM Shriram Amit shrivatsava', NULL, '9760421576', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(436, NULL, '2473', 'dcm shriram Naresh Kumar', 'nareshkumar1@dcmshriram.com', '9997285585', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(437, NULL, '3426', 'Deej3', NULL, '7299200220', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(438, NULL, '631', 'Deejos Interiors', NULL, '8778270098', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(439, NULL, '4390', 'Deepak 2', NULL, '8124570215', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(440, NULL, '4391', 'Deepak feetiliser Praveen chandra', NULL, '9225107044', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(441, NULL, '4392', 'Deepak Fertilizer Vineet', NULL, '7710028091', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(442, NULL, '3804', 'Deepak Godrej Agrovet', NULL, '9820781981', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(443, NULL, '3003', 'Departmental', NULL, '9566202496', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(444, NULL, '2730', 'Devi Cousin', NULL, '9176150705', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(445, NULL, '3060', 'Dfd Ashima', NULL, '8097088781', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(446, NULL, '7770', 'Dfd Auditor Jyothi Mani', NULL, '9841580875', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(447, NULL, '4399', 'DFD Bibin', NULL, '8489415110', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(448, NULL, '4403', 'Dfd chirag intern', NULL, '9980450152', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(449, NULL, '4404', 'Dfd DON HR Teju', NULL, '9632379911', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(450, NULL, '3143', 'DFD guru 2', NULL, '9008775959', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(451, NULL, '3770', 'DFD Guru Prathap', NULL, '9964998768', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(452, NULL, '4402', 'DFD Milan', NULL, '7795491448', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(453, NULL, '4405', 'DFD Preethu VB', NULL, '8088434005', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(454, NULL, '4401', 'DFD Preritha', NULL, '6361179020', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(455, NULL, '4406', 'DFD Rajesh Kannan', NULL, '9840916469', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(456, NULL, '4407', 'Dfd Ranjan Nadig', NULL, '7760079758', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(457, NULL, '4408', 'DFD Santosh Kiran', NULL, '9880733855', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(458, NULL, '958', 'DFD Shashi 2', NULL, '9008275159', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(459, NULL, '4400', 'DFD Sudipta', NULL, '9831176526', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(460, NULL, '4396', 'DFD Swathi', NULL, '7902480395', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(461, NULL, '2685', 'DFD Swathi Office', NULL, '7204920555', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(462, NULL, '4397', 'DFD Veena', NULL, '9591013001', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(463, NULL, '10302', 'DfD Zate', NULL, '7483323205', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(464, NULL, '9912', 'Dford Aishwarya', NULL, '8217876570', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(465, NULL, '4422', 'Dford Aishwarya Whatsapp', NULL, '7204832535', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(466, NULL, '4415', 'Dford Archana', NULL, '9663932931', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(467, NULL, '1128', 'Dford Arpithraj', NULL, '0224507338', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(468, NULL, '8696', 'Dford Bayer Hardik', NULL, '8780411649', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(469, NULL, '4424', 'Dford Bharath Wadone', NULL, '9036343759', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(470, NULL, '9917', 'Dford Chitra HR', NULL, '9900749659', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(471, NULL, '4426', 'Dford Driver Rajkumar', NULL, '8123824675', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(472, NULL, '4421', 'Dford Hari', NULL, '9944692346', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(473, NULL, '3750', 'Dford jayadeva', NULL, '8147799518', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(474, NULL, '4416', 'Dford Jithu', NULL, '9019839253', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(475, NULL, '4428', 'Dford Jittu personal', NULL, '9149173251', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(476, NULL, '4412', 'Dford Lokesh', NULL, '8660775527', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(477, NULL, '4418', 'Dford Luke', NULL, '9790902414', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(478, NULL, '4419', 'Dford Magesh', NULL, '9842566490', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(479, NULL, '4429', 'Dford Malathi J', NULL, '9742004315', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(480, NULL, '4410', 'Dford Manasa', NULL, '9980801801', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(481, NULL, '6064', 'Dford Manju', NULL, '9632493240', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(482, NULL, '4430', 'Dford Mohan IT', NULL, '9972592888', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(483, NULL, '4420', 'Dford Raghavendra', NULL, '7411501085', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(484, NULL, '9973', 'DforD Rajesh Handuja', NULL, '9731172562', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(485, NULL, '4414', 'Dford rangasamy', NULL, '9976909914', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(486, NULL, '4413', 'Dford Riona', NULL, '8310871063', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(487, NULL, '4432', 'Dford Rudra HR', NULL, '9900108989', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(488, NULL, '2034', 'Dford Sanjana DF support', NULL, '9008645959', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(489, NULL, '4411', 'Dford Shashi', NULL, '9845671036', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(490, NULL, '3825', 'Dford shivanand', NULL, '9535752948', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(491, NULL, '4433', 'Dford shivanand 2', NULL, '8951049111', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(492, NULL, '4417', 'Dford Shivani', NULL, '8197337279', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(493, NULL, '4434', 'Dford Shivani personal', NULL, '8147358637', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(494, NULL, '4435', 'Dford Suresh Krishnamoorthy', NULL, '9566210597', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(495, NULL, '4436', 'Dford Vasu ISMS', NULL, '9740662224', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(496, NULL, '6609', 'Dford Veeresh', NULL, '9243221679', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(497, NULL, '980', 'Dford Vishwa', NULL, '9008785959', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(498, NULL, '4409', 'Dford Viswa2', NULL, '9980794794', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(499, NULL, '8346', 'Dhamu Enterprises Bosch Vendor', NULL, '9945524534', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(500, NULL, '5189', 'Dhana', NULL, '9791649067', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(501, NULL, '2719', 'Dhana National', NULL, '9962908580', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(502, NULL, '3565', 'Dhana parivarthan', NULL, '9600052531', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(503, NULL, '3871', 'Dhaneshwaran Gowri', NULL, '9790941826', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(504, NULL, '96', 'Dhans Shanmugam', NULL, '9514750498', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(505, NULL, '2698', 'Dhanuka agritech Rahul Dhanuka', NULL, '9810162037', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(506, NULL, '4438', 'Dharani', NULL, '9962222403', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(507, NULL, '10263', 'Dharma Veltech', NULL, '9941953949', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(508, NULL, '3529', 'Dhavasi Velayutham', NULL, '9994575808', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(509, NULL, '9982', 'Dhinesh Rekha Anni friend', NULL, '7358189215', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(510, NULL, '4441', 'Dhiraj Agro', NULL, '7887783992', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(511, NULL, '48', 'Dhl anbu', NULL, '4442694416', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(512, NULL, '33', 'DHL Booking Chn', NULL, '4422259400', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(513, NULL, '128', 'Dhl Express', NULL, '1800111345', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(514, NULL, '7766', 'Digicides Marketing Services Dean Dutta', NULL, '7042111085', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(515, NULL, '2050', 'Digital Wall Chandan', NULL, '9663958096', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(516, NULL, '3142', 'Digital Wall Vijay', NULL, '9606182971', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(517, NULL, '2484', 'Digital Walls Consulting Vijay', NULL, '8105373070', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0);
INSERT INTO `customers` (`id`, `emp_id`, `phone_account_id`, `name`, `email`, `mobile`, `type`, `source`, `another_mobile`, `company`, `gst`, `profile_pic`, `location`, `group`, `dob`, `anniversary`, `created_by`, `status`, `contact_status`, `created_at`, `updated_at`, `is_deleted`) VALUES
(518, NULL, '2921', 'Dilli 2 Koyama', NULL, '9710729552', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(519, NULL, '10074', 'Dinesh', NULL, '8667487842', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(520, NULL, '9919', 'Dinesh Amma', NULL, '9790944566', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(521, NULL, '7994', 'Dinesh Getsetspecs. In', NULL, '9886077120', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(522, NULL, '4445', 'Dinesh Tcl', NULL, '9840840550', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(523, NULL, '7768', 'Dinesh.vellore', NULL, '9500480272', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(524, NULL, '3597', 'Dish', NULL, '9884016522', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(525, NULL, '4448', 'Divya Barathi', NULL, '6383068688', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(526, NULL, '2642', 'Divya Cousin', NULL, '9940059363', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(527, NULL, '4449', 'Divya Doctor', NULL, '9962521408', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(528, NULL, '3844', 'DNH', NULL, '8527321584', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(529, NULL, '3959', 'DNH RAJKUMAR QA', NULL, '9818647805', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(530, NULL, '4451', 'Doctor', NULL, '9840283686', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(531, NULL, '4454', 'Donaldson Chinniyan', NULL, '9626889675', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(532, NULL, '9819', 'Donaldson POWNKUMAR', NULL, '9566002625', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(533, NULL, '3534', 'Donaldson Santhosh', NULL, '9944023941', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(534, NULL, '3055', 'Donaldson Vijay', NULL, '7358509111', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(535, NULL, '3780', 'Dr Devendran', NULL, '9677020776', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(536, NULL, '2751', 'Dr Senthil', NULL, '9444226422', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(537, NULL, '4458', 'Driver Chengalpattu', NULL, '9585750240', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(538, NULL, '79', 'Driver Gugan', NULL, '9884933420', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(539, NULL, '3879', 'Driver Senthil', NULL, '9176666207', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(540, NULL, '693', 'Driver Sureshbabu', NULL, '8939245680', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(541, NULL, '4461', 'Driver.jeevacsc', NULL, '9941080032', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(542, NULL, '4462', 'DS group Ashish Kadyan', NULL, '9210411991', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(543, NULL, '202', 'Dtdc 1', NULL, '8610925128', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(544, NULL, '123', 'DTDC 2', NULL, '9952909258', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(545, NULL, '4463', 'DTDC Anbalagan', NULL, '9840849288', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(546, NULL, '9964', 'Dtdc Courier', NULL, '9382279779', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(547, NULL, '552', 'Dtdc Tracking', NULL, '4424421601', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(548, NULL, '7693', 'dummy', NULL, '7089976487', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(549, NULL, '2768', 'Durga Guru Quality', NULL, '9566246599', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(550, NULL, '3150', 'Durga Metal DAS', NULL, '7200044696', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(551, NULL, '559', 'Durga.broadcast', NULL, '3134217518', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(552, NULL, '516', 'Durga.siran', NULL, '2484219518', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(553, NULL, '2666', 'Dwaraka Athai', NULL, '9840593174', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(554, NULL, '2780', 'Dwc Chandan', NULL, '8943955449', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(555, NULL, '767', 'Dynamic Fasteners', NULL, '9618529955', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(556, NULL, '4469', 'eagles.satesh', NULL, '9551008575', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(557, NULL, '2043', 'East West Neerja Nawani', NULL, '9999884011', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(558, NULL, '2215', 'eastwest Kirti', NULL, '7977838629', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(559, NULL, '4470', 'Eastwest Namratha', NULL, '8197762228', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(560, NULL, '843', 'Eb Office', NULL, '4422650087', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(561, NULL, '3614', 'Eco Rajesh 2', NULL, '9148254153', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(562, NULL, '3931', 'ECO Rajesh Singh', NULL, '9945171115', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(563, NULL, '2008', 'emergency alert', NULL, '8527355100', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(564, NULL, '2789', 'Erode Agro varun', NULL, '9865230003', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(565, NULL, '3602', 'Eshwar.csc', NULL, '9884077063', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(566, NULL, '4472', 'ESP', NULL, '9962013481', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(567, NULL, '2651', 'Esp 3', NULL, '7403880388', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(568, NULL, '10300', 'ESP Aravind supervispr', NULL, '9087501581', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(569, NULL, '4473', 'ESP homes', NULL, '9042096961', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(570, NULL, '3637', 'ESP office', NULL, '9962752752', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(571, NULL, '3958', 'Esther office', NULL, '8904093777', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(572, NULL, '4475', 'Esther personal', NULL, '7348897237', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(573, NULL, '3445', 'Eye Benefits Ramesh', NULL, '9035613146', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(574, NULL, '5199', 'Farm Aid Ranjith Tally Head', NULL, '9597169746', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(575, NULL, '6732', 'Farm Aid Renganath MD FAS', NULL, '9842999903', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(576, NULL, '561', 'Fast Track 2', NULL, '4424732020', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(577, NULL, '3877', 'fast track driver', NULL, '7667464750', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(578, NULL, '477', 'Fasttrack', NULL, '9655653123', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(579, NULL, '45', 'FB Cakes', NULL, '7299972424', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(580, NULL, '753', 'FedEx International Courier Tamil', NULL, '8002096161', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(581, NULL, '2715', 'fhh', NULL, '8072979554', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(582, NULL, '5191', 'Fifo Cleaning Services', NULL, '7306846575', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(583, NULL, '3799', 'Flats Vishali', NULL, '8970003291', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(584, NULL, '2838', 'Flower Sampath', NULL, '9003014093', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(585, NULL, '10006', 'FMc Apoorva', NULL, '8879976367', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(586, NULL, '4481', 'Foreman Udhaykumar', NULL, '9841271145', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(587, NULL, '3100', 'Freshon Sathya', NULL, '8088080909', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(588, NULL, '2881', 'Fsst Track 1', NULL, '4428889999', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(589, NULL, '3668', 'Gaja', NULL, '9790955166', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(590, NULL, '946', 'Gallabox Aishwarya', NULL, '8069336409', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(591, NULL, '3996', 'Gallabox Nirmal', NULL, '8838840003', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(592, NULL, '4483', 'Gallabox Nirmal whatsapp', NULL, '9003720281', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(593, NULL, '6060', 'Ganesh', NULL, '9789057921', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(594, NULL, '1414', 'Ganesh Anna madhav new', NULL, '9445128249', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(595, NULL, '4485', 'Ganesh Babu2', NULL, '9940634242', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(596, NULL, '4486', 'Ganesh Dubai 2', NULL, '8056270884', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(597, NULL, '682', 'Ganesh Seikusui Dljm', NULL, '7401292152', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(598, NULL, '3035', 'Gas Chennai', NULL, '7588888824', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(599, NULL, '3994', 'Gas Connection Jeevan', NULL, '9071961484', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(600, NULL, '3713', 'Gate Jitendra', NULL, '9629796388', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(601, NULL, '5473', 'Gautami Raiker contractzy', NULL, '8007452709', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(602, NULL, '6030', 'Gay3 Cousin', NULL, '6232094757', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(603, NULL, '426', 'Gaya3.cousin', NULL, '6027530140', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(604, NULL, '688', 'Gayathri 2', NULL, '7823944558', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(605, NULL, '1040', 'Gayathri Frnd', NULL, '9941218818', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(606, NULL, '3419', 'Gayatri Akka 2', NULL, '7424931407', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(607, NULL, '3141', 'Gayatri Aunty', NULL, '9940453460', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(608, NULL, '921', 'Geetha Servant', NULL, '9790877463', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(609, NULL, '3315', 'Geetha Vellore', NULL, '7598203185', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(610, NULL, '8558', 'ghy', NULL, '0057425855', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(611, NULL, '2432', 'Giri bro', NULL, '8072404285', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(612, NULL, '4490', 'Giri bro 2', NULL, '7339512606', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(613, NULL, '2554', 'Giri mama', NULL, '9443625715', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(614, NULL, '277', 'Giriaa', NULL, '7904469419', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(615, NULL, '4491', 'Girias Mano', NULL, '9551182456', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(616, NULL, '3875', 'Glam Trends Vidyaranyapura in Bengaluru, Karnataka', NULL, '9845556888', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(617, NULL, '4495', 'Gnansekar Sakura Old Company', NULL, '9688119951', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(618, NULL, '2230', 'Goa chithi', NULL, '9823913067', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(619, NULL, '458', 'Gok Ind', NULL, '9841570066', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(620, NULL, '2675', 'Gokul airtel', NULL, '9994543807', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(621, NULL, '674', 'Gokul India', NULL, '8056087323', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(622, NULL, '10093', 'Gokul Mama', NULL, '2487052796', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(623, NULL, '10105', 'Gokul Mama 2', NULL, '7305318429', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(624, NULL, '3593', 'Gokul Sanjay', NULL, '9790848122', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(625, NULL, '4003', 'Gokul Sethu', 'gokulakrish.s@gmail.com', '9342070771', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(626, NULL, '3029', 'Gokul.shankar', NULL, '9884799234', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(627, NULL, '244', 'Gokulsuppprt', NULL, '7345020780', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(628, NULL, '3698', 'Gold finch Raju', NULL, '9880388671', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(629, NULL, '4498', 'Goldmine Logesh', NULL, '8939416625', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(630, NULL, '4499', 'Gopi 2', NULL, '8939840467', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(631, NULL, '4007', 'Gopi Father', NULL, '8608431560', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(632, NULL, '281', 'Gopi Jio', NULL, '8668127536', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(633, NULL, '2884', 'Gopi Whatsapp', NULL, '9566040467', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(634, NULL, '3855', 'Gopi.hexaware', NULL, '9941319914', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(635, NULL, '602', 'Goutham.cousin', NULL, '9710883412', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(636, NULL, '2782', 'Gowri Enterprises', NULL, '9444192918', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(637, NULL, '4501', 'Gowri Neibour', NULL, '7904812426', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(638, NULL, '4502', 'Gowri Shankar', NULL, '9677091683', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(639, NULL, '10288', 'Gowri Whatsapp', NULL, '9789911828', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(640, NULL, '4503', 'Gowtham Sai', NULL, '8667300208', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(641, NULL, '9922', 'Grand', NULL, '9962099780', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(642, NULL, '3359', 'ground.chandra', NULL, '9176855410', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(643, NULL, '3130', 'Guna 2', NULL, '9600060749', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(644, NULL, '3131', 'Guna Driver', NULL, '9677063711', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(645, NULL, '2221', 'Guna Jio', NULL, '8667864676', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(646, NULL, '2604', 'Guna Office', NULL, '9840092782', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(647, NULL, '3185', 'Guru Logistics Transport', NULL, '9025986955', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(648, NULL, '3798', 'Guru.school', NULL, '9884281548', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(649, NULL, '8812', 'Gurunanak Driver 2', NULL, '9901543074', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(650, NULL, '3708', 'Gurunanak Log Ranjith', NULL, '9500032601', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(651, NULL, '2811', 'Gurunanak New Driver', NULL, '8838994656', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(652, NULL, '3683', 'Gurunanak Transporter', NULL, '9003173925', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(653, NULL, '791', 'Hari', NULL, '9566520022', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(654, NULL, '3587', 'Hari Amma', NULL, '9003065428', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(655, NULL, '4006', 'Hari Cashify', NULL, '9884472672', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(656, NULL, '7993', 'Harikrishna', NULL, '9036081013', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(657, NULL, '2123', 'Harini Bangalore', NULL, '8197526260', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(658, NULL, '9955', 'Harini Katpadi Anu Anni', NULL, '6383837268', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(659, NULL, '4508', 'Harish Nairy', NULL, '8495057758', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(660, NULL, '3581', 'Harita sai', NULL, '9176543775', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(661, NULL, '4509', 'Harsha Bargav', NULL, '9701900932', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(662, NULL, '10064', 'Harshini Appa', NULL, '9940153808', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(663, NULL, '6057', 'Hasan siddhant mumbI', NULL, '9920860522', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(664, NULL, '547', 'Hasini', NULL, '9940520684', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(665, NULL, '10131', 'Hasini Boutique Rekha Vidyaranyapura Boutique', NULL, '9035042424', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(666, NULL, '435', 'Hathway Customer Care', NULL, '4440914340', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(667, NULL, '529', 'Hathway Customer Care2', NULL, '9962028682', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(668, NULL, '3759', 'Hathway Karthik', NULL, '9566632110', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(669, NULL, '616', 'Hathway Lokesh Technical', NULL, '9176006551', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(670, NULL, '4510', 'Hathway Modem Fixing Team', NULL, '8012798008', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(671, NULL, '9945', 'Hathway Technical Cable Team', NULL, '7397520991', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(672, NULL, '912', 'Hathyway Customer Care', NULL, '4440284028', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(673, NULL, '1327', 'Hatsun Thiagu', NULL, '9003096352', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(674, NULL, '7', 'Hdfc', NULL, '0000185541', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(675, NULL, '3880', 'HDFC Arun', NULL, '9884473120', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(676, NULL, '1703', 'HDFC Customer Care', NULL, '4461606161', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(677, NULL, '2315', 'HDFC Manjunath', NULL, '8971874467', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(678, NULL, '4514', 'HDFC Ponraj', NULL, '9962672333', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(679, NULL, '1004', 'HDFC Praveen RM. Shashi', NULL, '8861248790', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(680, NULL, '3712', 'hemakumar', NULL, '9790993938', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(681, NULL, '5229', 'Hitachi Arun', NULL, '9600037182', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(682, NULL, '2502', 'Hkx Dimple', NULL, '8860600304', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(683, NULL, '3165', 'HKX Manish', NULL, '9871503740', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(684, NULL, '2940', 'HKx Oshiar', NULL, '9643837143', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(685, NULL, '1035', 'Home landline', NULL, '4435500378', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(686, NULL, '2925', 'Hospital', NULL, '7639137427', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(687, NULL, '2186', 'Hosur Lodge Muthuraj', NULL, '6381263027', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(688, NULL, '1022', 'Hotel Mantra Residency', NULL, '8362307900', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(689, NULL, '4518', 'Hotel Maurya Thane', NULL, '9594726177', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(690, NULL, '4519', 'Hotel Shree International', NULL, '9606205505', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(691, NULL, '738', 'Hotel Shrinidhi', NULL, '4522580555', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(692, NULL, '389', 'House.landline', NULL, '4445574918', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(693, NULL, '9915', 'Hulimavu Tyre Replace Shiv Shankar', NULL, '8073417277', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(694, NULL, '3542', 'hutson anandvel', NULL, '9840943963', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(695, NULL, '4520', 'hutson divakar', NULL, '9840943981', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(696, NULL, '3568', 'Hyper', NULL, '9176576826', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(697, NULL, '524', 'Icici Charulatha', NULL, '9790841514', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(698, NULL, '3064', 'Icici Thenmozhi', NULL, '8655373586', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(699, NULL, '2961', 'ICICI Vijayalakshmi', NULL, '9324110850', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(700, NULL, '3299', 'ICS Shiva 2', NULL, '7358170666', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(701, NULL, '4534', 'Ifb Service Chrompet', NULL, '9751735478', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(702, NULL, '3024', 'Imop Hariharan', NULL, '9551056706', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(703, NULL, '3684', 'Indian Bank Advocate', NULL, '9841186862', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(704, NULL, '4549', 'Indian Bank Alwarpet', NULL, '9500498677', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(705, NULL, '3560', 'Indian Bank Manager Alwarpet', NULL, '8248255052', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(706, NULL, '4552', 'Indian Bank Manager New', NULL, '7639884356', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(707, NULL, '4550', 'Indian bank staff', NULL, '9940581036', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(708, NULL, '4551', 'Indian bank sundar', NULL, '9043544702', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(709, NULL, '7767', 'Indifi Sumit', NULL, '9999271334', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(710, NULL, '2979', 'Isuzu Ajay Kumar', NULL, '9894624169', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(711, NULL, '4560', 'Isuzu Nishant', NULL, '9790906536', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(712, NULL, '4559', 'Isuzu Nitin', NULL, '9080998503', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(713, NULL, '346', 'Isuzu Nitin Soalanki', NULL, '8939913227', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(714, NULL, '4568', 'Isuzu Ravikumar SPD', NULL, '8148442065', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(715, NULL, '2681', 'Isuzu Tausif', NULL, '4466111850', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(716, NULL, '4558', 'Isuzu Veilumuthu', NULL, '9894609853', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(717, NULL, '4571', 'Isuzu Vetri Kumaran', NULL, '8015807719', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(718, NULL, '3658', 'IYM Ajay', NULL, '9818700644', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(719, NULL, '4579', 'IYM Ajeet', NULL, '9811220031', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(720, NULL, '2600', 'Iym Anbu Stores', NULL, '9600184727', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(721, NULL, '3603', 'IYM Aravind bill Passing', NULL, '8838198077', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(722, NULL, '3632', 'IYM Arun quality', NULL, '9884741688', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(723, NULL, '215', 'Iym Athi', NULL, '9393863623', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(724, NULL, '3298', 'Iym Bala Projects', NULL, '9962019700', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(725, NULL, '2515', 'Iym Bala2', NULL, '9884010195', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(726, NULL, '4574', 'Iym Balaji', NULL, '9884150588', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(727, NULL, '2871', 'Iym Balaji Auditor', NULL, '9884987875', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(728, NULL, '3950', 'Iym Bharathi Whatsapp', NULL, '9894478753', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(729, NULL, '4584', 'IYM Bhupender Sharma', NULL, '9953797803', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(730, NULL, '4585', 'Iym chandru san', NULL, '8903438901', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(731, NULL, '467', 'Iym Charles. SPD', NULL, '8939927323', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(732, NULL, '10295', 'Iym Chn Nivas', NULL, '9176993126', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(733, NULL, '4588', 'Iym Dinesh 2', NULL, '9962070465', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(734, NULL, '2217', 'IYM Dinesh Kumar', NULL, '8807750465', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(735, NULL, '2959', 'Iym Diwakar', NULL, '9884895790', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(736, NULL, '4590', 'Iym Ganesh AUDIT2', NULL, '9003077659', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(737, NULL, '3861', 'Iym Ganeshbabu', NULL, '9962997701', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(738, NULL, '762', 'Iym Gate Common', NULL, '7824882364', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(739, NULL, '3758', 'Iym Harendra', NULL, '9953291221', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(740, NULL, '537', 'Iym Himanshu', NULL, '7823995220', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(741, NULL, '4580', 'Iym Jagadees', NULL, '9962629584', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(742, NULL, '7177', 'Iym Jaiganesh', NULL, '9962990446', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(743, NULL, '10009', 'IYM Jatinder', NULL, '9718931895', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(744, NULL, '4591', 'IYM JEEVA SAN', NULL, '9962090260', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(745, NULL, '3257', 'Iym Karthik', NULL, '9884723066', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(746, NULL, '6132', 'Iym karthik R&D', NULL, '9791769385', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(747, NULL, '4593', 'IYM KARTHIK R&D WHATSAPP', NULL, '9894912365', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(748, NULL, '4573', 'Iym Karthikeyan', NULL, '8939835537', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(749, NULL, '4578', 'Iym Karunesh', NULL, '9718675488', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(750, NULL, '4572', 'IYM Manikandan', NULL, '9789019082', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(751, NULL, '4575', 'IYM Mayank', NULL, '9740564612', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(752, NULL, '2464', 'Iym Mohit CE IYM SJP', NULL, '8800133077', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(753, NULL, '337', 'Iym Narayanan', NULL, '9962983491', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(754, NULL, '2933', 'Iym Patra', NULL, '9940629643', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(755, NULL, '481', 'Iym Prakash', NULL, '9962672509', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(756, NULL, '2310', 'IYM PRAMOD R&D', NULL, '9791237852', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(757, NULL, '4598', 'Iym R&D Santhosh', NULL, '7838629952', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(758, NULL, '4600', 'Iym Ram CE', NULL, '9789007933', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(759, NULL, '4601', 'IYM Rizwan SJP', NULL, '9278666615', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(760, NULL, '4603', 'Iym Shamugam Stores', NULL, '9884157971', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(761, NULL, '130', 'IYM Shanmugam Stores', NULL, '8939877332', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(762, NULL, '9846', 'Iym Shenbagaraman', NULL, '9962992481', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(763, NULL, '3778', 'IYM SJP Krishna', NULL, '9650015899', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(764, NULL, '2248', 'Iym SjP Sakul', NULL, '9540998099', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(765, NULL, '2113', 'Iym Spd Senthamil', NULL, '9884423799', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(766, NULL, '4581', 'Iym Sriganesh', NULL, '8939622799', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(767, NULL, '2423', 'IYM Sriram', NULL, '9962677978', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(768, NULL, '4604', 'IYM Stores Perumal', NULL, '9688676789', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(769, NULL, '4605', 'Iym Stores Sathish', NULL, '9994492393', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(770, NULL, '2476', 'Iym Stores Swaminathan', NULL, '9962085828', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(771, NULL, '445', 'IYM Umapathy Finance', NULL, '9655013962', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(772, NULL, '427', 'IYM Vadivel', NULL, '9514144927', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(773, NULL, '3717', 'IYM Vasu', NULL, '9884916327', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(774, NULL, '3586', 'IYM Vikram', NULL, '9842326662', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(775, NULL, '2904', 'Iym. Ganesh Audit 1', NULL, '8939879472', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(776, NULL, '3599', 'IYM. Manikandan CE Team', NULL, '9884736976', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(777, NULL, '1076', 'J', NULL, '7010872292', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(778, NULL, '124', 'Jaanu', NULL, '9442401321', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0);
INSERT INTO `customers` (`id`, `emp_id`, `phone_account_id`, `name`, `email`, `mobile`, `type`, `source`, `another_mobile`, `company`, `gst`, `profile_pic`, `location`, `group`, `dob`, `anniversary`, `created_by`, `status`, `contact_status`, `created_at`, `updated_at`, `is_deleted`) VALUES
(779, NULL, '9925', 'Jaba', NULL, '9941262676', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(780, NULL, '4609', 'Jagadees', NULL, '9791990460', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(781, NULL, '3252', 'jagadeesh raji chronpet', NULL, '9940095465', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(782, NULL, '4611', 'Jagan Childhood Friend', NULL, '9841811550', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(783, NULL, '9996', 'Jaggi', NULL, '8073343278', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(784, NULL, '4614', 'Jaishri Prabhu', NULL, '9003153144', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(785, NULL, '4615', 'Jalappa Venugopal', NULL, '9449222504', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(786, NULL, '2597', 'Jana', NULL, '9382889725', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(787, NULL, '7055', 'Janani Arun Kumar', NULL, '6374453644', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(788, NULL, '894', 'Janani Bentonville', NULL, '4793214262', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(789, NULL, '831', 'Janani Us2', NULL, '9344752356', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(790, NULL, '3819', 'Janu', NULL, '6126154323', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(791, NULL, '757', 'Janu.cousin', NULL, '3053710000', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(792, NULL, '4619', 'Jaya', NULL, '9677084610', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(793, NULL, '4618', 'Jaya Varadhan', NULL, '9884962399', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(794, NULL, '4620', 'Jayanth Sai Next home', NULL, '9677203243', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(795, NULL, '7988', 'Jayanthi Vasthra Boutique Manickam', NULL, '9886163331', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(796, NULL, '584', 'Jayasree Luminous Battery', NULL, '7397280739', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(797, NULL, '9958', 'JB Akash Gupta', NULL, '9757092025', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(798, NULL, '3893', 'JB Amit Nayak', NULL, '8826890835', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(799, NULL, '3569', 'JB Binil Balakrishnan', NULL, '9730943570', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(800, NULL, '3795', 'Jb Jagat Singh', NULL, '9717293048', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(801, NULL, '4621', 'JB Mayank', NULL, '8130496352', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(802, NULL, '4622', 'JB Rajesh', NULL, '9535768969', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(803, NULL, '2466', 'JBM Arumugam Engg Dept', NULL, '9092019393', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(804, NULL, '3829', 'JBM Mani Quality', NULL, '9626983003', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(805, NULL, '4624', 'JBM Sakthi', NULL, '7010797127', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(806, NULL, '4623', 'JBM Sudeep', NULL, '7004245714', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(807, NULL, '2989', 'Jeevanandam', NULL, '9944067258', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(808, NULL, '4634', 'Jeyavelan Sabapathy S', NULL, '9282422138', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(809, NULL, '3757', 'Jitendra Biz consultant', NULL, '8510001836', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(810, NULL, '1177', 'jitttttu', NULL, '3415627269', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(811, NULL, '9975', 'Jittu Pant', 'jittupant12@gmail.com', '9720361880', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(812, NULL, '4636', 'JMI ARUN', NULL, '9597609827', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(813, NULL, '3448', 'JMI Balaji', NULL, '7358383714', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(814, NULL, '722', 'Jodi chrysler', NULL, '5862917617', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(815, NULL, '2492', 'John Pondy Resort', NULL, '9585045350', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(816, NULL, '2213', 'Johoku Anil', NULL, '8939858228', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(817, NULL, '321', 'Johoku Balaji', NULL, '8939858225', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(818, NULL, '671', 'Johoku Driver', NULL, '7092698580', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(819, NULL, '3768', 'Johoku Driver Santhanam', NULL, '9786822235', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(820, NULL, '2471', 'Johoku Gangadharan', NULL, '8939858244', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(821, NULL, '388', 'Johoku Haridoss', NULL, '7358383712', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(822, NULL, '1766', 'Johoku Rajakumaran', NULL, '7708063509', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(823, NULL, '3968', 'Johoku Venkat', NULL, '8939858227', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(824, NULL, '9078', 'Joshua Mathew', NULL, '9742252908', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(825, NULL, '887', 'Josiyar', NULL, '9884509077', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(826, NULL, '795', 'Jothi Patti', NULL, '9943340685', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(827, NULL, '9968', 'Jothi vellore', NULL, '9003776135', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(828, NULL, '2065', 'Jothy Rent', NULL, '9940304048', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(829, NULL, '3270', 'Jupiter Robert', NULL, '9840785202', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(830, NULL, '2735', 'Kadimi Srinivasan', NULL, '9840885561', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(831, NULL, '3762', 'Kalai Mami', NULL, '9940699926', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(832, NULL, '3794', 'Kalaivani Tata', NULL, '9952975680', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(833, NULL, '3887', 'Kalisma Shamik Bose', NULL, '9650563923', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(834, NULL, '243', 'Kalisma Venkatesh', NULL, '8411880992', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(835, NULL, '3725', 'Kalpana', NULL, '9952188148', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(836, NULL, '4641', 'Kalpana.ponnan', NULL, '9790491800', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(837, NULL, '4642', 'Kalyan Priya', NULL, '9940489832', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(838, NULL, '4643', 'Kamashi cleaning. maid', NULL, '9042078730', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(839, NULL, '9984', 'Kambar Sir Bagewadi Engg', NULL, '9538633938', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(840, NULL, '7761', 'Kamesh', NULL, '9025532631', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(841, NULL, '3907', 'Kamila', NULL, '9841506174', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(842, NULL, '3755', 'Kanagavel', NULL, '9444012572', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(843, NULL, '3947', 'Kanagu Kumar Rto', NULL, '9841021973', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(844, NULL, '2305', 'Kaneko San Japan', NULL, '9026689120', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(845, NULL, '10127', 'Kannan INDIAN Bank Survey Egr', NULL, '8144334391', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(846, NULL, '3310', 'Kannan kuppu frnd', NULL, '9791022556', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(847, NULL, '806', 'Kannan Mama', NULL, '9677112607', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(848, NULL, '293', 'kannan.naven', NULL, '9952408335', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(849, NULL, '4648', 'Karthi Jio', NULL, '8668135877', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(850, NULL, '2269', 'karthi kappur', NULL, '7339242499', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(851, NULL, '247', 'Karthi Office', NULL, '4467448355', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(852, NULL, '8551', 'Karthi Prufen', NULL, '9891779884', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(853, NULL, '62', 'Karthi.businesssys', NULL, '9500063728', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(854, NULL, '4649', 'Karthi.collage', NULL, '2487619338', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(855, NULL, '433', 'Karthi.new.mani', NULL, '9940027025', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(856, NULL, '3687', 'Karthik 2', NULL, '9845425518', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(857, NULL, '10025', 'Karthik Hot Bread', NULL, '9840847651', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(858, NULL, '7769', 'karthik muthaiyan', NULL, '1556575129', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(859, NULL, '2260', 'Karthik Paaps', NULL, '9578133832', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(860, NULL, '3574', 'Karthik PSA Avtec', NULL, '9940400380', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(861, NULL, '227', 'Karthikbuss.csc', NULL, '2489617792', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(862, NULL, '2089', 'karthikeyan kannamangalam', NULL, '9442668900', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(863, NULL, '4656', 'KCB Udhayanan', NULL, '9841717604', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(864, NULL, '4657', 'Kcc Ravichandran bnglr', NULL, '9845823737', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(865, NULL, '8525', 'KCC surya Prakash', NULL, '7411959452', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(866, NULL, '351', 'Keshav', NULL, '8248112803', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(867, NULL, '9079', 'Khazana', NULL, '8072789885', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(868, NULL, '1667', 'Kitty Gokul', NULL, '2488299818', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(869, NULL, '4663', 'Kitty PP', 'kiruthygaa@gmail.com', '9840925653', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(870, NULL, '27', 'Kitty US', NULL, '2489976411', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(871, NULL, '646', 'Kittyusa', NULL, '2393847135', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(872, NULL, '117', 'Kokila.helios', NULL, '8041950220', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(873, NULL, '3541', 'Koshik Amma', NULL, '7904612755', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(874, NULL, '4665', 'Koshy Appa', NULL, '9500031361', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(875, NULL, '2097', 'Kotakkal Ayurvadha Salai', NULL, '8870106740', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(876, NULL, '3215', 'Kovalam sea la vie resort sabiya', NULL, '8925984372', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(877, NULL, '3838', 'Koyama Dilli', NULL, '8939811452', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(878, NULL, '2680', 'Koyama Saravana', NULL, '8939811451', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(879, NULL, '6733', 'Koyama Srilekha', NULL, '8939811467', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(880, NULL, '191', 'Koyas Fasteners', NULL, '9445393672', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(881, NULL, '3350', 'Kr Auto Loganathan', NULL, '8925328882', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(882, NULL, '4670', 'Kriba', NULL, '9566210804', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(883, NULL, '2456', 'krishn hyderabad', NULL, '9959822911', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(884, NULL, '2977', 'Krishna Chatering', NULL, '7871425590', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(885, NULL, '4673', 'Krishna.vop', NULL, '9551411682', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(886, NULL, '546', 'Krishnan Csc', NULL, '6126702227', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(887, NULL, '3722', 'Krithika School', NULL, '9840706365', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(888, NULL, '6765', 'Kriya Boutique Lavanya', NULL, '9945099205', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(889, NULL, '4676', 'Kumar Mama', NULL, '9448076727', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(890, NULL, '283', 'Kumar Rani', NULL, '9600101100', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(891, NULL, '7762', 'Kumar Vandi', NULL, '9600435351', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(892, NULL, '3654', 'Kumaran kundram vasu naatu marundhu', NULL, '9150379242', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(893, NULL, '2547', 'Kumari Perima', NULL, '9994182972', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(894, NULL, '576', 'Kumersan.h20', NULL, '2484803299', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(895, NULL, '4677', 'Kuppu', NULL, '9840325591', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(896, NULL, '5192', 'Kura Vinoth National BS', NULL, '9361430239', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(897, NULL, '3682', 'Kwe Anantharaman', NULL, '9840604256', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(898, NULL, '84', 'Kwe Babu', NULL, '7299004273', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(899, NULL, '4679', 'KWE Divakar', NULL, '9710946919', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(900, NULL, '3020', 'Kwe Rajkumar', NULL, '8754397333', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(901, NULL, '4678', 'Kwe Thilak', NULL, '9629270726', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(902, NULL, '4682', 'Kyowa Naresh', NULL, '8072437684', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(903, NULL, '2504', 'Kyowa Ravi', NULL, '8939883605', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(904, NULL, '637', 'Kyowa Vadivel', NULL, '7904740627', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(905, NULL, '764', 'Kyowa Vadivel 1', NULL, '8939624899', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(906, NULL, '4685', 'Kyowa Vadivel 3', NULL, '9003447700', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(907, NULL, '2172', 'Kyowa VINOTH', NULL, '9629333792', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(908, NULL, '4686', 'L. P. M. Lakshmi Traders', NULL, '9445266486', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(909, NULL, '10114', 'Lakshmi Athai', NULL, '9789028846', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(910, NULL, '4687', 'lakshmi bhavan venkatesh', NULL, '9884111213', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(911, NULL, '1043', 'Lakshmi Ganesh Sembakkam Municipality', NULL, '8754029281', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(912, NULL, '1018', 'Landline', NULL, '4443849394', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(913, NULL, '1013', 'Landline Dinesh', NULL, '4448572585', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(914, NULL, '621', 'Lanson Toyoto Service', NULL, '4430817222', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(915, NULL, '8182', 'Leapswitch Networks', NULL, '8411020105', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(916, NULL, '4688', 'leapswitch swapnil', NULL, '7972507633', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(917, NULL, '4689', 'Lekha', NULL, '9600072745', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(918, NULL, '10106', 'Lic Johnson', NULL, '9940618360', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(919, NULL, '228', 'Limbi Cousin', NULL, '9786745253', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(920, NULL, '316', 'Limbrit.csc', NULL, '2488392385', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(921, NULL, '3429', 'Lister Chitlapakkam', NULL, '7358217821', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(922, NULL, '154', 'Livpure Cuatomer Care', NULL, '8004199399', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(923, NULL, '2512', 'Logu', NULL, '8778467143', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(924, NULL, '4690', 'Loopworm Abhishek', NULL, '8892444563', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(925, NULL, '212', 'Lotus Kar 2', NULL, '9952842276', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(926, NULL, '4692', 'Lotus karthik', NULL, '8148809890', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(927, NULL, '714', 'Lotus Land2', NULL, '4442165655', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(928, NULL, '307', 'Lotus Landline', NULL, '4428233404', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(929, NULL, '568', 'Lotus Narayanan1', NULL, '7010867795', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(930, NULL, '2195', 'Lotus Pavithra', NULL, '9952118783', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(931, NULL, '2546', 'Lotus Sridhar', NULL, '9445224167', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(932, NULL, '4691', 'Lotus Uppal', NULL, '9840471843', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(933, NULL, '2935', 'Lotus. Narayanan Brn Head', NULL, '9940540327', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(934, NULL, '3904', 'LR Mayil Vaganam', NULL, '9941664760', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(935, NULL, '57', 'Lucas Vinoth', NULL, '7395982691', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(936, NULL, '4696', 'Lucky', NULL, '9962761406', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(937, NULL, '3860', 'Madan', NULL, '9444354011', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(938, NULL, '4697', 'Madhavan National', NULL, '9884220133', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(939, NULL, '166', 'Madhavan usa', NULL, '3133743669', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(940, NULL, '3138', 'Magesh Auto', NULL, '8939035443', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(941, NULL, '4699', 'Magesh Royal Enfield', NULL, '9962673067', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(942, NULL, '4700', 'Magesh Washing Machine', NULL, '9841989404', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(943, NULL, '200', 'Magesh Washing Mc 2', NULL, '8939148556', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(944, NULL, '3700', 'Magna', NULL, '9840020040', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(945, NULL, '4703', 'Maha', NULL, '8610761972', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(946, NULL, '2189', 'Maha Enterprises Sundarapandian', NULL, '9841004821', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(947, NULL, '10306', 'Maha Krishnan', NULL, '9841418820', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(948, NULL, '694', 'Maha Vinoth', NULL, '9003003305', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(949, NULL, '4004', 'Mahadev Vdrnyapura Owner', NULL, '9986231479', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(950, NULL, '6686', 'Mahalakshmi Tailor', NULL, '7204614564', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(951, NULL, '3641', 'Mahesh Chithapa', NULL, '9940129393', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(952, NULL, '9575', 'Mahesh Gowda Cvwng Sol', NULL, '9731569729', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(953, NULL, '4709', 'Mahesh Sagar Frnd', NULL, '6305481230', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(954, NULL, '4710', 'Malar Servant Maid', NULL, '9976307408', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(955, NULL, '3083', 'Malkeet Singh', NULL, '9254484722', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(956, NULL, '10084', 'Malli Appa', NULL, '9941665609', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(957, NULL, '1753', 'Malli.athai', NULL, '9003218642', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(958, NULL, '10063', 'Mals', NULL, '9841059607', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(959, NULL, '512', 'Malu', NULL, '8939488340', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(960, NULL, '327', 'Malu appa', NULL, '9840088376', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(961, NULL, '2072', 'Malu australia', NULL, '1451262462', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(962, NULL, '878', 'Mamanar', NULL, '7358090578', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(963, NULL, '3611', 'Mami', NULL, '9840037301', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(964, NULL, '4712', 'manavalan', NULL, '9908708410', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(965, NULL, '557', 'Mando Bala', NULL, '7824800456', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(966, NULL, '2274', 'Mando Bharath', NULL, '8681852369', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(967, NULL, '10', 'Mando Chandan', NULL, '8668022169', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(968, NULL, '318', 'Mando Gopalan', NULL, '7824800404', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(969, NULL, '4716', 'Mando Markering Vignesh', NULL, '9840585938', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(970, NULL, '475', 'Mando Rakesh 2', NULL, '7824800695', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(971, NULL, '2222', 'Mando Sowmya', NULL, '8939248836', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(972, NULL, '437', 'Mando Sudeep', NULL, '7824800471', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(973, NULL, '502', 'Mando Sudhakar', NULL, '4471800542', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(974, NULL, '4713', 'Mando Velan', NULL, '7824800510', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(975, NULL, '3622', 'Mando Vignesh', NULL, '9790510705', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(976, NULL, '511', 'Mando Vignesh Marktng', NULL, '7824800349', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(977, NULL, '16', 'Mando Viswanathan', NULL, '7824800303', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(978, NULL, '4722', 'Mangal Karthik', NULL, '9787691760', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(979, NULL, '2103', 'Mangal Praveen', NULL, '9840303595', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(980, NULL, '4721', 'Mangal Suresh', NULL, '9003067068', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(981, NULL, '3430', 'Mangal Vinoth', NULL, '7013298563', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(982, NULL, '4724', 'Mangalam Chithi', NULL, '9449076727', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(983, NULL, '3320', 'Mani Anna Nagar', NULL, '9444023323', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(984, NULL, '3866', 'Mani Ect', NULL, '9941089906', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(985, NULL, '510', 'Mani Plumber', NULL, '7358476254', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(986, NULL, '4725', 'Mani.mpts', NULL, '2486008224', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(987, NULL, '109', 'Manij AXPRESS', NULL, '8588895361', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(988, NULL, '4726', 'Manikandan ramani athai', NULL, '9790886488', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(989, NULL, '3437', 'Manipal Vijay Niranjan Unni nw', NULL, '6364836470', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(990, NULL, '10297', 'Manmatha Devi', NULL, '7305346909', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(991, NULL, '1148', 'Manoj', NULL, '9940630834', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(992, NULL, '7113', 'Mari Amma Take Care Lady', NULL, '9840626895', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(993, NULL, '3895', 'Mari.pk', NULL, '9751701540', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(994, NULL, '3446', 'Marico Ashok Kumar', NULL, '9952425593', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(995, NULL, '6741', 'Mark Mili Arathi', NULL, '9844543657', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(996, NULL, '4729', 'Martin MH', NULL, '9880426856', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(997, NULL, '4732', 'Master csc', NULL, '6304006399', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(998, NULL, '2906', 'MCIM Rachna', NULL, '7483029756', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(999, NULL, '4733', 'Medplus Karthik', NULL, '9003228257', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1000, NULL, '4734', 'Medtrain Nandini', NULL, '6360109157', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1001, NULL, '2055', 'Meenatchi', NULL, '8903484295', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1002, NULL, '1003', 'Meesho', NULL, '7619630838', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1003, NULL, '273', 'Meiyappan usa', NULL, '2489096398', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1004, NULL, '234', 'Meru Cab', NULL, '9212144422', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1005, NULL, '2839', 'Metal One. bass', NULL, '9551299292', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1006, NULL, '4736', 'Metalone Radha', NULL, '7299026868', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1007, NULL, '4737', 'Metz Sevugarajan', NULL, '8190810222', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1008, NULL, '3263', 'MH Bala Murali', NULL, '9482061765', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1009, NULL, '3726', 'MH Hidayat', NULL, '8892747104', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1010, NULL, '906', 'microsoft support', NULL, '9289307501', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1011, NULL, '452', 'Mike cricket', NULL, '2486224879', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1012, NULL, '7691', 'Milk Man Deepak', NULL, '7358691567', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1013, NULL, '63', 'Minami Janarthanan', NULL, '7358703316', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1014, NULL, '4739', 'Minami Richardson', NULL, '7502012021', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1015, NULL, '266', 'Minami Senthil', NULL, '9789836505', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1016, NULL, '4741', 'Mindeika Gnansekar', NULL, '8248518722', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1017, NULL, '3915', 'Mithun Shriram City', NULL, '9962000128', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1018, NULL, '3328', 'Mitsuba Jaykumar', NULL, '9944929532', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1019, NULL, '279', 'Mitsubishi Delhi', NULL, '1143641439', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1020, NULL, '4743', 'Mitsubishi RAVI MOBILE', NULL, '9743440904', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1021, NULL, '483', 'Mitsubishi Ravinaik', NULL, '8046480622', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1022, NULL, '4751', 'MK Aravind 2', NULL, '8778547846', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1023, NULL, '4747', 'MK Ayyappa', NULL, '7204899667', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1024, NULL, '4744', 'MK Biradar', NULL, '7353899916', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1025, NULL, '4746', 'MK Hariharan', NULL, '9042310425', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1026, NULL, '3197', 'Mk Karthik Heat Treatment', NULL, '9535917690', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1027, NULL, '3267', 'MK Karthik Heat Treatment 2', NULL, '9894326830', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1028, NULL, '3883', 'MK KIRTAN', NULL, '9900019870', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1029, NULL, '3912', 'MK LOKESH', NULL, '9535161050', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1030, NULL, '3955', 'MK lokesh 2', NULL, '8050590503', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1031, NULL, '3956', 'MK Lokesh New', NULL, '9606055738', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1032, NULL, '550', 'MK Mohan', NULL, '7904074177', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1033, NULL, '3787', 'Mk Plating Madura Veetan', NULL, '9731605365', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1034, NULL, '4748', 'MK Prasanth', NULL, '9448992905', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1035, NULL, '4750', 'MK Purushoth', NULL, '9597572297', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1036, NULL, '2112', 'Mk Shivanna', NULL, '9448992923', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1037, NULL, '3078', 'MK Sunil Plating', NULL, '9008910240', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1038, NULL, '2381', 'MK Venkat Quality', NULL, '7639757273', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1039, NULL, '144', 'MK Venkatesan', NULL, '9448992921', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0);
INSERT INTO `customers` (`id`, `emp_id`, `phone_account_id`, `name`, `email`, `mobile`, `type`, `source`, `another_mobile`, `company`, `gst`, `profile_pic`, `location`, `group`, `dob`, `anniversary`, `created_by`, `status`, `contact_status`, `created_at`, `updated_at`, `is_deleted`) VALUES
(1040, NULL, '4749', 'Mk Vijay', NULL, '9448992912', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1041, NULL, '9961', 'MK Vijay 2', NULL, '7975532558', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1042, NULL, '2617', 'Mk Vinoth 2', NULL, '9384245119', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1043, NULL, '331', 'MK Vinoth 3', NULL, '6379036604', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1044, NULL, '3613', 'MKF Kumar', NULL, '9600123410', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1045, NULL, '3734', 'Mkf Venkatesan Sales', NULL, '8098080650', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1046, NULL, '4756', 'Mkf Vinoth Pha', NULL, '9003440693', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1047, NULL, '132', 'Mkt Vehicle', NULL, '9087936956', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1048, NULL, '3133', 'MM printers Ganesh', NULL, '9791037626', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1049, NULL, '2655', 'MM printers shop', NULL, '9884604673', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1050, NULL, '4758', 'Mohammad Alauddin', NULL, '9007893830', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1051, NULL, '4760', 'Mohan 2', NULL, '9600253220', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1052, NULL, '2167', 'Mohan iyer', NULL, '9710219477', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1053, NULL, '4759', 'Mohan Jaya', NULL, '9176515993', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1054, NULL, '3657', 'MOI', NULL, '9500025259', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1055, NULL, '185', 'Monica Landline', NULL, '1244595204', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1056, NULL, '308', 'Monish Blue Dart', NULL, '9791036027', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1057, NULL, '7989', 'Monisha Gowrika Boutique', NULL, '9591328912', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1058, NULL, '9378', 'Monjuri Collections Arijith', NULL, '7667078545', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1059, NULL, '2182', 'Moorthy Mama', NULL, '9444043569', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1060, NULL, '3210', 'Movex Bhagat', NULL, '7835063315', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1061, NULL, '2824', 'Movex Harish San', NULL, '8510056984', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1062, NULL, '2082', 'msg91 whtsapp', NULL, '8889378605', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1063, NULL, '703', 'MSM iNN', NULL, '4352402242', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1064, NULL, '213', 'MSM Lodge Shake', NULL, '9626733225', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1065, NULL, '4763', 'MTR Surya Vishnu', NULL, '9751745259', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1066, NULL, '4762', 'MTR Umesh', NULL, '7795119643', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1067, NULL, '9783', 'Mukesh Paatra Bhandar', NULL, '9379228808', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1068, NULL, '3103', 'Mukund Ajay', NULL, '9500038020', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1069, NULL, '7394', 'Murali Amma', NULL, '6383446713', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1070, NULL, '745', 'Murugan 2', NULL, '9840343744', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1071, NULL, '4764', 'Murugan Kaja', NULL, '9840163163', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1072, NULL, '3803', 'Murugan sriram', NULL, '9444115974', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1073, NULL, '573', 'Murugan travels', NULL, '7299185959', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1074, NULL, '4765', 'Murugesh', NULL, '8870989015', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1075, NULL, '4766', 'Muthu Advocate', NULL, '9884433318', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1076, NULL, '306', 'Muthu Csc', NULL, '9003063462', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1077, NULL, '111', 'Muthu usa', NULL, '2486138451', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1078, NULL, '3554', 'Muthu Veltec', NULL, '9500095035', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1079, NULL, '811', 'Nacl Industries Sai charan', NULL, '8121001557', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1080, NULL, '4770', 'Nagaraj', NULL, '8056221185', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1081, NULL, '9374', 'Nakshatra Sundar', NULL, '9986965663', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1082, NULL, '2339', 'Namdhari Deepinder', NULL, '9945104583', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1083, NULL, '2474', 'Nandha Ana2', NULL, '7904398112', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1084, NULL, '2851', 'Nandha Anna', NULL, '9600179823', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1085, NULL, '769', 'Narayanan Electrician', NULL, '9551502796', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1086, NULL, '29', 'Narendran Yamaha', NULL, '9962655643', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1087, NULL, '9854', 'Naresh Hebbal (National Opticals Hulimavu)', NULL, '7310101618', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1088, NULL, '86', 'Narula Anil San', NULL, '9910074488', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1089, NULL, '3619', 'Nasiqh.csc', NULL, '8341789064', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1090, NULL, '4774', 'Nathiya', NULL, '7548807535', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1091, NULL, '4775', 'National Chair', NULL, '7019036532', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1092, NULL, '4776', 'National Insurance. John', NULL, '8939845519', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1093, NULL, '9903', 'National Opticals Mustafa', NULL, '9936300786', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1094, NULL, '4777', 'National School Gopi', NULL, '9884306930', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1095, NULL, '2288', 'Naukri priya', NULL, '9821063827', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1096, NULL, '3321', 'naveen.Vinod', NULL, '9566067301', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1097, NULL, '5232', 'Neodove Bhavya', NULL, '9108034369', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1098, NULL, '9989', 'Nextgen aqua service', NULL, '7305993781', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1099, NULL, '4778', 'Nhk Bearing', NULL, '9566183616', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1100, NULL, '3424', 'NHK Neelesh', NULL, '7339597444', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1101, NULL, '4782', 'Nif Mk Santosh Whatsapp', NULL, '9688576537', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1102, NULL, '4786', 'Nifast Abhishek', NULL, '9654405734', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1103, NULL, '484', 'Nifast Abhishek 2', NULL, '9958355757', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1104, NULL, '4784', 'Nifast Akash', NULL, '7305720207', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1105, NULL, '2875', 'Nifast Amit', NULL, '9891426744', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1106, NULL, '2908', 'Nifast Amit Sales', NULL, '9599661366', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1107, NULL, '2337', 'Nifast Driver', NULL, '8778095323', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1108, NULL, '4791', 'Nifast GGN Quality Ravi', NULL, '9911208485', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1109, NULL, '4787', 'Nifast Guna', NULL, '9840796411', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1110, NULL, '10071', 'Nifast Inatomi San', NULL, '9870156633', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1111, NULL, '8785', 'Nifast Kaneko San', NULL, '9910927888', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1112, NULL, '2319', 'Nifast Kapil', NULL, '9991156135', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1113, NULL, '2731', 'Nifast Krishna Quality', NULL, '9500178403', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1114, NULL, '9', 'Nifast Kuldeep', NULL, '8112295117', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1115, NULL, '4788', 'Nifast Kuldeep2', NULL, '7891914554', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1116, NULL, '3156', 'Nifast Malkit', NULL, '8527859197', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1117, NULL, '2826', 'Nifast Manoj', NULL, '9958644450', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1118, NULL, '256', 'Nifast Mukai San', NULL, '9500115820', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1119, NULL, '8835', 'Nifast Narendra', NULL, '8527816055', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1120, NULL, '4793', 'Nifast New Driver', NULL, '9941765299', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1121, NULL, '3664', 'Nifast Parvesh', NULL, '9654834304', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1122, NULL, '2343', 'Nifast Pawan Gautham', NULL, '8851238748', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1123, NULL, '4785', 'Nifast Prabhu', NULL, '9043202319', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1124, NULL, '4796', 'Nifast Quality Sundeep', NULL, '8109688762', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1125, NULL, '4797', 'Nifast Rakesh Tripati', NULL, '9910666431', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1126, NULL, '627', 'Nifast Rinku', NULL, '9958644499', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1127, NULL, '374', 'Nifast Sandeep 2', NULL, '7987083873', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1128, NULL, '413', 'Nifast Santhosh MK', NULL, '8248439602', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1129, NULL, '4799', 'Nifast Santhosh Office', NULL, '8925316777', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1130, NULL, '271', 'Nifast Saravana', NULL, '9500023082', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1131, NULL, '3040', 'Nifast SH Sakaravathi', NULL, '9500368758', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1132, NULL, '9377', 'Nifast SH Settu', NULL, '8220461975', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1133, NULL, '642', 'Nifast Srinivadan Driver', NULL, '9514986249', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1134, NULL, '4801', 'Nifast Sunil Accounts', NULL, '7404170197', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1135, NULL, '2987', 'Nifast Sunil Sangwan', NULL, '7838596514', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1136, NULL, '3853', 'Nifast Tarun', NULL, '8860530640', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1137, NULL, '401', 'Nifast Watanabe San', NULL, '9871118613', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1138, NULL, '4802', 'Nifat SH. Suresh', NULL, '9159507120', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1139, NULL, '3287', 'Nik Case', NULL, '9773641959', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1140, NULL, '197', 'Nip Charles', NULL, '7339488076', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1141, NULL, '4810', 'Nip Charles New', NULL, '7358905549', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1142, NULL, '4808', 'Nip Ejaz', NULL, '8527971371', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1143, NULL, '4806', 'Nip Gopal', NULL, '9790789057', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1144, NULL, '6655', 'Nip Prabhu 1', NULL, '9940599112', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1145, NULL, '4805', 'Nip Prabu', NULL, '9791658686', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1146, NULL, '4807', 'Nip Ram', NULL, '8939298076', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1147, NULL, '365', 'Nip RAM 2', NULL, '9092624338', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1148, NULL, '232', 'Nip Sab1', NULL, '8939111657', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1149, NULL, '3987', 'Nip Senthil', NULL, '9940230390', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1150, NULL, '4804', 'Nip Suresh', NULL, '8754578568', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1151, NULL, '2947', 'Nip Vinoth', NULL, '9094795056', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1152, NULL, '2212', 'Nipman Pravin, MD', NULL, '9810134560', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1153, NULL, '204', 'Nipman Rajesh Yadav', NULL, '8572899316', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1154, NULL, '3439', 'Nippon Lakshmi', NULL, '7639268224', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1155, NULL, '451', 'Nippon Landline', NULL, '9962205700', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1156, NULL, '2497', 'Nippon Rajan FLT', NULL, '8939966681', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1157, NULL, '4817', 'Nirmala Sm', NULL, '9751263625', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1158, NULL, '3732', 'Nishant Belaku Eye Hospital', NULL, '8197917971', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1159, NULL, '651', 'Nissan Sivakumar', NULL, '4467483105', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1160, NULL, '2131', 'Nissan.amir', NULL, '3133208807', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1161, NULL, '5557', 'Nithi', NULL, '9841626641', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1162, NULL, '10373', 'Nithi Jio', NULL, '7904818421', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1163, NULL, '4822', 'Nithin Churi', NULL, '7892037294', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1164, NULL, '13', 'Nithya', NULL, '9843512362', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1165, NULL, '941', 'No broker arunraj', NULL, '8068132054', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1166, NULL, '1113', 'Nobroker Nishant banglr', NULL, '8046019332', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1167, NULL, '2528', 'Nouriture Soumyajit', NULL, '9051664631', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1168, NULL, '4830', 'Nuziveedu Lakshmi', NULL, '9912098097', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1169, NULL, '3753', 'Nuziveedu Srinivasbabu', NULL, '8886061374', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1170, NULL, '4829', 'Nuziveedu Tarak', NULL, '9999741839', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1171, NULL, '504', 'Nw', NULL, '9840239716', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1172, NULL, '610', 'Olympic Cards', NULL, '4442066392', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1173, NULL, '593', 'Om Delhi Airport', NULL, '9211783458', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1174, NULL, '2440', 'Om Gurgoan Office Amir Deekshan', NULL, '9654088498', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1175, NULL, '2276', 'Om Keshnath', NULL, '9282170472', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1176, NULL, '2366', 'Om Log Driver', NULL, '9790274231', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1177, NULL, '4834', 'Om Log Driver Hari', NULL, '9176171225', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1178, NULL, '3906', 'Om Log Driver Karthik', NULL, '9790275764', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1179, NULL, '3774', 'Om Log Driver Karthik 2', NULL, '9942888092', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1180, NULL, '4835', 'Om Log Driver Keerthy', NULL, '7667364407', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1181, NULL, '478', 'Om Log Isaac Landline', NULL, '4422331106', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1182, NULL, '4837', 'Om Log Manager GGN', NULL, '9268568512', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1183, NULL, '238', 'Om Log Pickup From Sunguvachatram', NULL, '9047987118', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1184, NULL, '2830', 'Om Log Sholavaram', NULL, '9282170457', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1185, NULL, '2900', 'Om Log Train', NULL, '9344206727', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1186, NULL, '384', 'Om Logistics Isaac', NULL, '9282444624', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1187, NULL, '2522', 'Om Logistics Soolai', NULL, '9282170473', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1188, NULL, '3168', 'Om Logistics Sungavachatram', NULL, '9282170456', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1189, NULL, '8345', 'Om Logistics Sunil', NULL, '8745000132', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1190, NULL, '3269', 'ondc sahayak', NULL, '8130935050', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1191, NULL, '9080', 'Optical Square Ravi', NULL, '7892580474', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1192, NULL, '189', 'Orphanage Home', NULL, '8939818363', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1193, NULL, '2939', 'Osakai Janani', NULL, '8525992064', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1194, NULL, '7841', 'Osakai Kumaresan', NULL, '9786968373', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1195, NULL, '2774', 'Osakai Narasimhan', NULL, '9840022588', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1196, NULL, '4843', 'Osakai Sathya', NULL, '7708338499', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1197, NULL, '2694', 'Osakai Umapathy', NULL, '9488444767', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1198, NULL, '10061', 'Paapu', NULL, '7358281418', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1199, NULL, '9626', 'Padhu Pande', NULL, '8056187159', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1200, NULL, '4846', 'Padma Charan testenium', NULL, '9243422236', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1201, NULL, '9642', 'Padma new', NULL, '8870037729', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1202, NULL, '10254', 'Padmaja Madura', NULL, '9492732621', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1203, NULL, '2724', 'Padmashree', NULL, '7200972779', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1204, NULL, '1141', 'Palani aniyalai', NULL, '9047647376', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1205, NULL, '676', 'Palani kitty Dad', NULL, '9884482165', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1206, NULL, '4848', 'Palani Mama', NULL, '9003149545', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1207, NULL, '2052', 'Pandian.electrici', NULL, '9841860594', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1208, NULL, '44', 'Papa sisters', NULL, '9094088237', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1209, NULL, '8218', 'Parag Food Bheemanappa', NULL, '7420852867', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1210, NULL, '3791', 'Parag Sudhir', NULL, '9665049593', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1211, NULL, '2409', 'Parimalam', NULL, '9962953918', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1212, NULL, '4850', 'Parthiban', NULL, '9094034946', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1213, NULL, '9965', 'Paul Mew Siddhant Engineering Services', NULL, '9820056720', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1214, NULL, '4852', 'Paul W', NULL, '9008788477', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1215, NULL, '8113', 'Pavan Harsha Cousin', NULL, '9346328469', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1216, NULL, '4853', 'Pavi 2', NULL, '8925409225', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1217, NULL, '1158', 'Pavi College', NULL, '7338991097', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1218, NULL, '4854', 'Pazhani', NULL, '7200911968', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1219, NULL, '2589', 'Pazhani Builder', NULL, '9677040066', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1220, NULL, '737', 'Petrol Nifast. Arivu', NULL, '9840540587', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1221, NULL, '4857', 'PfsTam', NULL, '8007821258', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1222, NULL, '8160', 'Philo Elite Boutique Fashions', NULL, '6366334481', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1223, NULL, '4858', 'Phonepe Aditya', NULL, '7903298692', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1224, NULL, '4859', 'PI Simhadri Naidu', NULL, '8008401901', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1225, NULL, '856', 'policy bazr', NULL, '7971762789', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1226, NULL, '3549', 'Pondy Resort', NULL, '9585169852', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1227, NULL, '4861', 'Ponngodi Sm', NULL, '9080533413', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1228, NULL, '3009', 'Ponraj SFL', NULL, '9940110724', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1229, NULL, '3733', 'Pooja Das', NULL, '9971093519', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1230, NULL, '701', 'Pooja Landline', NULL, '1294046801', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1231, NULL, '2565', 'Pooja Manish', NULL, '9810046577', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1232, NULL, '533', 'Pooja Sahoo', NULL, '7056707082', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1233, NULL, '2599', 'Pooja. Suresh Unit 2', NULL, '9871133200', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1234, NULL, '2852', 'Porter', NULL, '8828831516', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1235, NULL, '487', 'Prabha Accounts Baskar', NULL, '8754414328', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1236, NULL, '4862', 'Prabha Auto Shatheesh', NULL, '9791047019', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1237, NULL, '10113', 'Prabhu Veltech', NULL, '9840929992', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1238, NULL, '250', 'Prabu.colg', NULL, '9884494804', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1239, NULL, '10057', 'Pradhyun Daddy', NULL, '7299935359', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1240, NULL, '2992', 'Pradipa SM Hospital Nurse', NULL, '9941590335', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1241, NULL, '1679', 'Prakash Saranya', NULL, '9840770766', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1242, NULL, '5193', 'Prakash Seva Bandhu', NULL, '9740589312', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1243, NULL, '3372', 'Prakash.frend', NULL, '9945475757', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1244, NULL, '2813', 'Pramod AXPRESS', NULL, '9087883170', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1245, NULL, '97', 'Prasad csc', NULL, '2486135632', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1246, NULL, '615', 'Prasanth Vishwa', NULL, '9940261161', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1247, NULL, '4875', 'Prashanth Medtrain', NULL, '9731722531', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1248, NULL, '4876', 'Prashanth Shanthi Aunty', NULL, '9677258669', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1249, NULL, '2438', 'prateek toll free', NULL, '1800224344', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1250, NULL, '3609', 'Pravin.satesh', NULL, '9952152287', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1251, NULL, '3564', 'Prayag Krishn Lalwani', NULL, '7995003687', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1252, NULL, '4881', 'Prem', NULL, '8667806465', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1253, NULL, '4880', 'Prem cab', NULL, '9962830975', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1254, NULL, '4879', 'Prem trainer', NULL, '9884933470', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1255, NULL, '4884', 'Premkumar IT - Nifast', NULL, '8072217025', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1256, NULL, '4885', 'Premntah', NULL, '9790842512', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1257, NULL, '4887', 'Prince Kapoor', NULL, '9560697683', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1258, NULL, '383', 'Prince Restuarant', NULL, '9786496207', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1259, NULL, '773', 'Priya US', NULL, '9806363439', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1260, NULL, '563', 'Priyesh csc', NULL, '2487058043', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1261, NULL, '4889', 'Proen Damini Sadiye', NULL, '9686079535', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1262, NULL, '3920', 'Proen Mukund', NULL, '9845162335', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1263, NULL, '2767', 'Proen Nilesh', NULL, '7028254934', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1264, NULL, '4890', 'Proeon Sumit', NULL, '9689673703', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1265, NULL, '2885', 'Proff Courier. ram', NULL, '9626296103', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1266, NULL, '4894', 'PVC Loganathan', NULL, '8667578360', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1267, NULL, '4895', 'Quess Sudhir', NULL, '9972463729', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1268, NULL, '4896', 'Radhapandian Valli', NULL, '9940015866', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1269, NULL, '1033', 'Radhika Akash', NULL, '7299974784', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1270, NULL, '4897', 'Raghav', NULL, '8122234282', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1271, NULL, '4898', 'Raghavan Gnyanam', NULL, '9840607465', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1272, NULL, '521', 'Raghu Raja', NULL, '9444319190', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1273, NULL, '8561', 'Rahul BP Cylinder', NULL, '9845758200', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1274, NULL, '10298', 'Rahul Hubby', 'vig.ee@gmail.com', '9840913457', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1275, NULL, '724', 'Rahul majikjag', NULL, '2393847132', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1276, NULL, '3573', 'rahul.bang', NULL, '9900472570', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1277, NULL, '444', 'Rahul.landline', NULL, '4466774169', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1278, NULL, '10089', 'Rahul.tata', NULL, '8807204227', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1279, NULL, '4900', 'Raj Lbib inteenational', NULL, '9884789704', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1280, NULL, '1960', 'Raja 2', NULL, '7358555954', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1281, NULL, '3428', 'Raja anna vellore', NULL, '7305389369', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1282, NULL, '3685', 'Raja Lodge', NULL, '8072089610', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1283, NULL, '3813', 'Raja mama', NULL, '9444211210', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1284, NULL, '4901', 'Raja Uncle Daughter', NULL, '9042620755', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1285, NULL, '2749', 'Raja.colg', NULL, '9962574228', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1286, NULL, '2834', 'Rajagatta FPO chsitra', NULL, '9611338612', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1287, NULL, '2490', 'Rajagatta Sowmya Gowda', NULL, '9742726289', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1288, NULL, '10068', 'Rajashekhara channel part', NULL, '9686301233', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1289, NULL, '4902', 'Rajendran', NULL, '9444102981', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1290, NULL, '315', 'Rajes CSC', NULL, '2488774051', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1291, NULL, '2793', 'Rajesh hair Cut', NULL, '8189996111', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1292, NULL, '3313', 'Rajesh Jana', NULL, '9940193413', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1293, NULL, '531', 'Rajesh mngr', NULL, '2482028932', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1294, NULL, '4904', 'Raji Bro', NULL, '9962418672', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1295, NULL, '2496', 'Rajkumar Thirumalai Nagar', NULL, '9840489464', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1296, NULL, '4906', 'Rakesh', NULL, '9884260000', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1297, NULL, '1730', 'Rakshana', NULL, '9003135128', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1298, NULL, '1092', 'Rakshana 2', NULL, '1458614693', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0);
INSERT INTO `customers` (`id`, `emp_id`, `phone_account_id`, `name`, `email`, `mobile`, `type`, `source`, `another_mobile`, `company`, `gst`, `profile_pic`, `location`, `group`, `dob`, `anniversary`, `created_by`, `status`, `contact_status`, `created_at`, `updated_at`, `is_deleted`) VALUES
(1299, NULL, '3188', 'Rakshana New', NULL, '1448443447', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1300, NULL, '3164', 'Ram Chithapa', NULL, '9962222636', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1301, NULL, '9577', 'Ramachandran Dreams Hoodi S', NULL, '9741301055', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1302, NULL, '4015', 'Ramakrishnan Advocate', NULL, '9841136863', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1303, NULL, '257', 'Ramanathan', NULL, '9442968200', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1304, NULL, '3230', 'Ramarao Durga Metal Finishers', NULL, '9750077755', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1305, NULL, '206', 'Ramasamy Balaji', NULL, '9080893909', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1306, NULL, '4909', 'Ramesh Driver', NULL, '9445749763', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1307, NULL, '2509', 'Ramesh Gurunanak', NULL, '9710690086', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1308, NULL, '4910', 'Ramesh.bean', NULL, '9790942160', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1309, NULL, '2205', 'ramesh.gurukal', NULL, '9710573522', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1310, NULL, '5197', 'Rameshkuhan R', NULL, '9663397124', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1311, NULL, '261', 'Ramji Kanagavel', NULL, '8939996637', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1312, NULL, '2448', 'Ramsays Suresh', NULL, '9444444143', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1313, NULL, '3899', 'Ramu chidambaram son', NULL, '8825734518', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1314, NULL, '3583', 'Ramya', NULL, '9791182115', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1315, NULL, '3152', 'Ramya.kitty', NULL, '9600981740', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1316, NULL, '2039', 'Rani Chithi', NULL, '9360187002', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1317, NULL, '2677', 'Rani Chithi Anna Nagar', NULL, '9444260017', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1318, NULL, '2752', 'Rani chithi arul', NULL, '9884369951', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1319, NULL, '885', 'Rani chithi arul chrompet', NULL, '6385124118', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1320, NULL, '4911', 'Ranjit csc', NULL, '2487360244', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1321, NULL, '8524', 'Ranjith.cousin', NULL, '9626543635', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1322, NULL, '567', 'Ranjith.viveks', NULL, '9094989431', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1323, NULL, '10377', 'Rank Mark saravanan', NULL, '9384054859', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1324, NULL, '9276', 'Rashmi Advita Fashion', NULL, '9739073628', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1325, NULL, '668', 'Ratz Mca', NULL, '9980711983', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1326, NULL, '4916', 'Ravi', NULL, '9843447303', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1327, NULL, '10100', 'Ravi Anna', NULL, '9790419611', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1328, NULL, '4917', 'Ravi Mama Chrompet', NULL, '9944915257', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1329, NULL, '4918', 'Ravi mama Vishwa.R', NULL, '7824041056', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1330, NULL, '3247', 'Ravi Moorthy Mama', NULL, '9486246551', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1331, NULL, '8517', 'Ravi Shankar', NULL, '9840944888', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1332, NULL, '3522', 'Rayaan Karthik', NULL, '9176988008', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1333, NULL, '766', 'Rayyan Premkumar', NULL, '9176988009', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1334, NULL, '3334', 'RBM Mohinder', NULL, '9711300406', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1335, NULL, '605', 'Rebtel Local Call', NULL, '3134440915', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1336, NULL, '4920', 'Recur adil hayat', NULL, '8826856473', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1337, NULL, '4919', 'Recur Amit', NULL, '8287104601', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1338, NULL, '3646', 'Recur Vaibhav', NULL, '9654010261', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1339, NULL, '3157', 'Rekha', NULL, '9840854674', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1340, NULL, '10119', 'Rekha Akka', NULL, '9790758292', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1341, NULL, '4922', 'Rekha Harshinì', NULL, '8678940722', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1342, NULL, '493', 'Rekha Landline', NULL, '4424410668', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1343, NULL, '4921', 'Rekha Office', NULL, '7824865856', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1344, NULL, '2243', 'Rekha Suresh', NULL, '9791141818', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1345, NULL, '4924', 'Rental New', NULL, '8608572135', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1346, NULL, '4925', 'Revathi (Gokul Frnd)', NULL, '2486359967', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1347, NULL, '6247', 'Revathi Akka Neighbour', NULL, '8095202947', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1348, NULL, '4926', 'Revs karthi', NULL, '9087033884', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1349, NULL, '422', 'Ricoh Customer Care', NULL, '8001030066', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1350, NULL, '64', 'Ricoh Finance Aneesh', NULL, '9790997840', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1351, NULL, '70', 'Ricoh. Kalyan Grp Leader', NULL, '9940637772', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1352, NULL, '4927', 'Rithu Kitty', NULL, '7708473958', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1353, NULL, '3807', 'Rk Enterprises Anand', NULL, '9688340004', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1354, NULL, '4930', 'RNTBC Sivakumar', NULL, '9677288848', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1355, NULL, '4929', 'RNTBC Vigneshwaran', NULL, '9600560250', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1356, NULL, '4931', 'RNTBCI Darsan', NULL, '8939939815', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1357, NULL, '4933', 'Rohan Khanna PracticeLeague', NULL, '8308839594', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1358, NULL, '9921', 'Rohini Neibour', NULL, '9962585863', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1359, NULL, '4934', 'Rohit Dnh', NULL, '9540768408', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1360, NULL, '2210', 'Room Sidhanath Subasree', NULL, '9381013724', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1361, NULL, '4935', 'rounak', NULL, '8380086600', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1362, NULL, '3706', 'Royal Enfield Sachin', NULL, '9884897898', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1363, NULL, '4936', 'royal fab adore', NULL, '9930358777', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1364, NULL, '2036', 'RTF Amarjeet Singh', NULL, '9822061717', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1365, NULL, '36', 'RTF Ashwini', NULL, '2536696774', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1366, NULL, '2129', 'RTF Jaipal Quality', NULL, '7401111180', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1367, NULL, '3525', 'RTF Manoj', NULL, '9444388039', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1368, NULL, '558', 'RTF NILESH', NULL, '7720016648', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1369, NULL, '367', 'RTF Nilesh Rathod', NULL, '2551663912', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1370, NULL, '56', 'RTF Pooja', NULL, '2536696791', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1371, NULL, '539', 'RTF Rahul', NULL, '8308813415', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1372, NULL, '715', 'RTF Utam Sonawane', NULL, '7774023729', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1373, NULL, '9857', 'RTF Vaishali', NULL, '7774023728', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1374, NULL, '4938', 'S Srinivasan Bhel Rnipet', NULL, '9442308554', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1375, NULL, '3545', 'Sachidhanandam Vivek FIL', NULL, '9840753880', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1376, NULL, '2592', 'Sadhik Sundirect', NULL, '9382707090', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1377, NULL, '1179', 'Sagar 2', NULL, '2546315487', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1378, NULL, '1180', 'sagar 3', NULL, '4561846494', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1379, NULL, '4940', 'Sagar Lahoti', NULL, '9867106106', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1380, NULL, '4941', 'Sagar Shashi', NULL, '9845328671', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1381, NULL, '3436', 'Sai Mama', NULL, '9840509937', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1382, NULL, '3223', 'Sai Shubh Yatra', NULL, '9840064243', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1383, NULL, '10096', 'Sai Shubyatra', NULL, '9710181243', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1384, NULL, '162', 'Sai.Anu Anni', NULL, '8939667575', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1385, NULL, '95', 'Saket Fabs', NULL, '9871080097', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1386, NULL, '662', 'Sakura anto', NULL, '8939894166', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1387, NULL, '749', 'Sakura Arunprasanth', NULL, '8939944401', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1388, NULL, '4947', 'Sakura Bharath', NULL, '8939832940', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1389, NULL, '530', 'Sakura Murugavl Landline', NULL, '4433610715', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1390, NULL, '4946', 'Sakura Satheesh', NULL, '9791264964', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1391, NULL, '110', 'Sakura Satheesh Narayanan', NULL, '8939894164', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1392, NULL, '4950', 'Sameer Parqg Milk', NULL, '9960277377', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1393, NULL, '3370', 'Sammu', NULL, '7358471783', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1394, NULL, '10229', 'Sampath anna villupuram', NULL, '6374018935', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1395, NULL, '4952', 'Sandeep Sharma', NULL, '9215444019', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1396, NULL, '4954', 'Sandhiya Kalasapakkam', NULL, '9585162227', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1397, NULL, '3960', 'Sandhya Vilvarani new', NULL, '9585360028', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1398, NULL, '3595', 'Sangeetha Akka', NULL, '9894520230', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1399, NULL, '8185', 'Sangi Appu', NULL, '7200004325', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1400, NULL, '7765', 'sanj driver', NULL, '9535265556', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1401, NULL, '7176', 'Sanjay', NULL, '9500151599', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1402, NULL, '3846', 'Sanjay New', NULL, '9940689853', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1403, NULL, '4960', 'Sankar csc', NULL, '2484620797', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1404, NULL, '4959', 'Sankar Tata', NULL, '7200013553', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1405, NULL, '2382', 'Sankarfamily', NULL, '9566848440', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1406, NULL, '536', 'Sankarsaran', NULL, '2488927045', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1407, NULL, '4024', 'sanmugam anu appa', NULL, '9442744812', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1408, NULL, '6962', 'Sansera Ali', NULL, '9902046613', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1409, NULL, '3711', 'Sansera Balamurugan', NULL, '8147571493', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1410, NULL, '3710', 'Sansera Jayaprakash', NULL, '9740233511', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1411, NULL, '4962', 'Sansera Laksminathan', NULL, '9538764777', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1412, NULL, '10261', 'Sansera Rakesh', NULL, '9686133593', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1413, NULL, '2283', 'Sansera Sanjeev Sharma', NULL, '9810203939', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1414, NULL, '3391', 'Sansera Sathish', NULL, '9845333544', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1415, NULL, '3513', 'Sansera Vineeth', NULL, '9740475250', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1416, NULL, '2191', 'Sansera Vithal Prabhu', NULL, '9880677433', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1417, NULL, '3938', 'Sansera Vittal', NULL, '9845620093', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1418, NULL, '8584', 'Sansol Srinivas', NULL, '7396090099', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1419, NULL, '3153', 'Santhanam Tata', NULL, '9384088061', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1420, NULL, '4964', 'Saradha Chithi', NULL, '9444023264', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1421, NULL, '4965', 'Saran Bro', NULL, '8939757880', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1422, NULL, '2294', 'Saranya 2', NULL, '7358411985', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1423, NULL, '1598', 'Saranya Athai Eswari', NULL, '9940477686', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1424, NULL, '4966', 'Saranya Frnd', NULL, '9884728129', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1425, NULL, '5', 'Saranya.cousin', NULL, '8939305902', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1426, NULL, '4967', 'Saraswathi Deepa', NULL, '8553665279', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1427, NULL, '635', 'Sarath Bluedart', NULL, '9940072961', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1428, NULL, '3375', 'Saravana Mama', NULL, '9994190370', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1429, NULL, '3898', 'Saravana Whatsapp', NULL, '9092110695', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1430, NULL, '2059', 'Saravanan Mathi Father', NULL, '9840858606', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1431, NULL, '4968', 'Saravanan Sai saravana hotel', NULL, '9486731248', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1432, NULL, '522', 'Saravanan usa', NULL, '2482494977', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1433, NULL, '4969', 'Sarika San', NULL, '9818686301', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1434, NULL, '10203', 'Satheesh Indian Bank', NULL, '9176741986', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1435, NULL, '326', 'Sathish Sai Subhyatra', NULL, '9176635372', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1436, NULL, '10374', 'Sathish Tata', NULL, '9597352222', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1437, NULL, '9928', 'Sathya cctv chrompet', NULL, '9940160664', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1438, NULL, '2238', 'Sathya Inn', NULL, '7025556363', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1439, NULL, '4972', 'Sathyan', NULL, '9600121125', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1440, NULL, '40', 'Satish Cataler', NULL, '9632422101', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1441, NULL, '3204', 'Saurabh Kasar', NULL, '9881877776', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1442, NULL, '4973', 'Saurav Jittu frnd', NULL, '8126656728', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1443, NULL, '4974', 'Savi Agarwal', NULL, '8085533711', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1444, NULL, '3677', 'SBL corp Manikandan', NULL, '9600522233', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1445, NULL, '10090', 'school.hemanathan', NULL, '8867061205', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1446, NULL, '1657', 'school.hemnath', NULL, '9962265232', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1447, NULL, '4977', 'school.Ravi', NULL, '9789003625', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1448, NULL, '732', 'Scv', NULL, '1173726104', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1449, NULL, '233', 'Security Sampath', NULL, '9962802605', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1450, NULL, '3763', 'Sekar anna', NULL, '9880120329', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1451, NULL, '3127', 'Sekisui Suresh', NULL, '8939812516', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1452, NULL, '759', 'Sekisui Yuvaraj', NULL, '9962400844', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1453, NULL, '9340', 'self', NULL, '8764356889', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1454, NULL, '4981', 'Selva Driver 2', NULL, '9841942883', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1455, NULL, '4982', 'Selva Gate Entry', NULL, '9789576397', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1456, NULL, '4983', 'Selvakumar Priya', NULL, '9962007765', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1457, NULL, '9709', 'Selvam Blue Dart', NULL, '9789916736', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1458, NULL, '4008', 'Selvam malli', NULL, '9841035640', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1459, NULL, '6058', 'Selvi 2', NULL, '7305539530', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1460, NULL, '4986', 'Selvi Akka', NULL, '9094417736', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1461, NULL, '4987', 'Selvi Balaji Rengan Homes Servant', NULL, '7358477564', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1462, NULL, '7171', 'Senthil Athi Friend', NULL, '9677144370', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1463, NULL, '3624', 'Senthilnathan Ascen hyveg', NULL, '9944993939', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1464, NULL, '10094', 'Sethu new', NULL, '0173690788', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1465, NULL, '534', 'Sethu.colg', NULL, '0322640200', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1466, NULL, '3659', 'Sethu.colgnew', NULL, '8939677445', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1467, NULL, '775', 'Sethu.colgnew1', NULL, '9884699614', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1468, NULL, '7558', 'Sethu.father', NULL, '9790727874', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1469, NULL, '4991', 'Settu 2', NULL, '6385564789', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1470, NULL, '6', 'Seven Hills Incharge', NULL, '9943005218', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1471, NULL, '4992', 'SGS Harsha', NULL, '8553425268', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1472, NULL, '581', 'shakiba.vivek', NULL, '9677087769', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1473, NULL, '4993', 'Sham.gopi', NULL, '9840887902', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1474, NULL, '7842', 'Shankar Usa', NULL, '2625015770', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1475, NULL, '2411', 'Shankar.tcl', NULL, '8754447886', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1476, NULL, '408', 'Shankarindia', NULL, '9095273432', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1477, NULL, '2134', 'Shanmugam Iyer', NULL, '7358230838', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1478, NULL, '729', 'Shanmugam.boston', NULL, '6782966485', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1479, NULL, '443', 'Shanmugam.dasari', NULL, '7153170202', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1480, NULL, '9941', 'Shantha School', NULL, '9952017021', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1481, NULL, '2227', 'Shanthi Amma Take Care', NULL, '7094740117', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1482, NULL, '2110', 'Shanti Giri', NULL, '9443096980', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1483, NULL, '3731', 'Sharavanan MECHANIC', NULL, '9886787090', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1484, NULL, '4023', 'Sharmila Revathi Daughter', NULL, '9353024782', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1485, NULL, '2630', 'Sheeltron Manju', NULL, '8884403592', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1486, NULL, '4995', 'Sheeth', NULL, '9538355251', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1487, NULL, '551', 'Sheeth 2', NULL, '8618001696', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1488, NULL, '203', 'Shiva Driver 2', NULL, '9884070934', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1489, NULL, '2634', 'Shiva Kavita cousin', NULL, '8904043950', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1490, NULL, '4996', 'Shivani M', NULL, '9994740324', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1491, NULL, '91', 'Shivs', NULL, '9003046035', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1492, NULL, '3937', 'Shobana Anni', NULL, '9940342549', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1493, NULL, '2285', 'shoby mamiyaar', NULL, '9940670785', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1494, NULL, '4997', 'Shoby US', NULL, '2489284566', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1495, NULL, '4998', 'Shravan Hegde contractzy', NULL, '8805564291', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1496, NULL, '4999', 'Shwetha', NULL, '9686450489', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1497, NULL, '1589', 'Siddhanta Channel Partner Ajaani Hero Motors', NULL, '9035239855', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1498, NULL, '9010', 'Siddhanta Chnl Partner Billing software Swayam', NULL, '9845972853', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1499, NULL, '6897', 'Siddharth Prabhakar', NULL, '7338999453', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1500, NULL, '92', 'Sify L2 Support', NULL, '9940028929', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1501, NULL, '5001', 'Sify Mohan', NULL, '9380639960', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1502, NULL, '5002', 'Sify Saravanan', NULL, '9840490497', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1503, NULL, '9929', 'Signutra Ashish', NULL, '9810309639', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1504, NULL, '5003', 'Signutra Pushpa Raj', NULL, '8109296437', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1505, NULL, '5004', 'Silku Chithi', NULL, '8122909189', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1506, NULL, '5006', 'Sindhu', NULL, '7010467103', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1507, NULL, '60', 'Sindu.sis.mani', NULL, '9094115590', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1508, NULL, '3818', 'singaravel perippa', NULL, '9444129214', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1509, NULL, '5007', 'Siva Airtel', NULL, '9791344018', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1510, NULL, '1501', 'Siva Anna Vellore', NULL, '9445539900', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1511, NULL, '3427', 'Siva Driver 2', NULL, '6380175070', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1512, NULL, '3041', 'Sivachandran CSC', NULL, '9255779904', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1513, NULL, '994', 'Skill Nation', NULL, '7820916286', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1514, NULL, '5008', 'Smdheer S Treasury John Distilleries', 'sudhir@jdl.in', '9902006762', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1515, NULL, '1', 'Sneha Csc', NULL, '8939959922', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1516, NULL, '578', 'Som.smak', NULL, '9916569018', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1517, NULL, '3442', 'Sonjay Kant Manipal Natural Extracts Cfo, Kurlon', NULL, '7330999277', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1518, NULL, '5011', 'Sony.instaler', NULL, '9940076565', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1519, NULL, '3381', 'Soundar', NULL, '9500126522', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1520, NULL, '2360', 'Soundar', NULL, '9962931739', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1521, NULL, '665', 'soundarpandian', NULL, '9282100995', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1522, NULL, '5013', 'Sp engrs satish', NULL, '9894263346', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1523, NULL, '9913', 'SPAM', NULL, '4471658003', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1524, NULL, '5014', 'Sparchem Siddharth', NULL, '9867502724', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1525, NULL, '3967', 'Spectrum Maulik', NULL, '9993533344', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1526, NULL, '2122', 'Spring Valley', NULL, '9842561317', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1527, NULL, '849', 'Spring Valley 2', NULL, '9842027526', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1528, NULL, '5015', 'Sreeja Akka', NULL, '8667408249', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1529, NULL, '72', 'Sreeja Neighbour', NULL, '9445187441', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1530, NULL, '6566', 'Sreejith', NULL, '9900005695', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1531, NULL, '5016', 'SRI Kevin Sir', NULL, '9080934946', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1532, NULL, '7125', 'Sridhar KCB', NULL, '9791133366', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1533, NULL, '5018', 'Sridhar Uncle', NULL, '9677080663', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1534, NULL, '116', 'SridharperalaNew', NULL, '2482257693', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1535, NULL, '224', 'SridharTeam csc', NULL, '2484310580', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1536, NULL, '319', 'Sridharvellore', NULL, '2489908519', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1537, NULL, '131', 'Srini callingcard', NULL, '5597461951', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1538, NULL, '322', 'Srini new', NULL, '2489096394', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1539, NULL, '5020', 'Srini Prufen', NULL, '9941508585', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1540, NULL, '119', 'Srinivas@hyd', NULL, '9603179345', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1541, NULL, '6731', 'sriram synergy', NULL, '9444867208', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1542, NULL, '3644', 'Sriram.sai', NULL, '9600654042', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1543, NULL, '3651', 'Srivari Sundar', NULL, '9443247955', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1544, NULL, '5023', 'Srividya Manikandan', NULL, '9840269001', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1545, NULL, '3601', 'Srmc. Shiva Tennis Coach', NULL, '9841272172', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1546, NULL, '2998', 'SRT Angel Front office', NULL, '9740761144', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1547, NULL, '5024', 'SSGbuilders', NULL, '9444079107', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1548, NULL, '333', 'SSR Hotel', NULL, '9550095023', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1549, NULL, '713', 'Stanley Binite', NULL, '8588866026', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1550, NULL, '2891', 'Stanley Sivasubramani', NULL, '8939716435', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1551, NULL, '6061', 'Subathra Mami', NULL, '9841078518', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1552, NULL, '2882', 'Subbanathan cuddalore', NULL, '9487579928', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1553, NULL, '2686', 'Subbi APPA', NULL, '7904231729', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1554, NULL, '645', 'Subbi Appa Sekar', NULL, '9841358232', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1555, NULL, '5028', 'Subbu Kalyanmohan', NULL, '9841071219', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1556, NULL, '5029', 'Subbu Karthik sundaram', NULL, '9840427472', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1557, NULL, '2184', 'Subbu US', NULL, '7164296097', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0);
INSERT INTO `customers` (`id`, `emp_id`, `phone_account_id`, `name`, `email`, `mobile`, `type`, `source`, `another_mobile`, `company`, `gst`, `profile_pic`, `location`, `group`, `dob`, `anniversary`, `created_by`, `status`, `contact_status`, `created_at`, `updated_at`, `is_deleted`) VALUES
(1558, NULL, '5031', 'Subbu.team', NULL, '2482490179', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1559, NULL, '6730', 'Subha Anni', NULL, '9944381046', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1560, NULL, '575', 'Subha.santhanamSir', NULL, '2487978730', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1561, NULL, '2916', 'Subu', NULL, '9940783873', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1562, NULL, '5033', 'Sudha Meiyappan', NULL, '9381035979', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1563, NULL, '5204', 'Sudha Servant', NULL, '9176560389', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1564, NULL, '2708', 'Sudhan Nanganallur', NULL, '8919996919', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1565, NULL, '10296', 'Sudhir Amarnath', NULL, '8122294024', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1566, NULL, '284', 'Sudhir Hitesh', NULL, '8295735400', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1567, NULL, '3526', 'Sudhir IlayaRaja', NULL, '9215911240', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1568, NULL, '5034', 'Suganya', NULL, '9677014201', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1569, NULL, '3790', 'Sugu Mama', NULL, '9940149186', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1570, NULL, '7174', 'Sujatha Harish Contact', NULL, '9840101443', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1571, NULL, '3876', 'Sujatha Hem', NULL, '8197371587', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1572, NULL, '9976', 'Sumathi Servant', NULL, '9498055609', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1573, NULL, '300', 'Sun Ccare', NULL, '8002007575', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1574, NULL, '690', 'Sun hD Card', NULL, '1347167649', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1575, NULL, '728', 'Sun Nxt Cust Nbr', NULL, '4444676767', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1576, NULL, '9967', 'Sun Udhayam Govindharaj', NULL, '9445003831', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1577, NULL, '2166', 'Sun Udhayam Sharavana', NULL, '9445003833', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1578, NULL, '2996', 'Sundar', NULL, '9941756610', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1579, NULL, '5037', 'Sundar thambi', NULL, '8283015995', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1580, NULL, '5038', 'Sundaram Manoharan', NULL, '9840706147', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1581, NULL, '1627', 'Sundu colg', NULL, '9962308088', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1582, NULL, '3432', 'Sundu friend', NULL, '1497782660', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1583, NULL, '1371', 'Sundu India Jio', NULL, '8838244952', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1584, NULL, '9951', 'Sunil 2', NULL, '8527858726', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1585, NULL, '9918', 'Sunita Angels abode', NULL, '9036184540', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1586, NULL, '3612', 'Support Nikita', NULL, '9008772526', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1587, NULL, '2176', 'Supriya tele solutions', NULL, '8147924011', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1588, NULL, '10059', 'Suresh (reka)', NULL, '9789058873', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1589, NULL, '2732', 'Suresh anu bro', NULL, '9600193209', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1590, NULL, '2194', 'Suresh Arun Anna Vellore', NULL, '9597738423', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1591, NULL, '3099', 'Suresh Minami Metals', NULL, '7358703319', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1592, NULL, '5039', 'Suresh National', NULL, '9840946243', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1593, NULL, '3', 'Suresh Sairam', NULL, '8939749240', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1594, NULL, '5041', 'Suresh Seven Hills', NULL, '7548833470', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1595, NULL, '5042', 'Surya Driver 2', NULL, '9884279796', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1596, NULL, '5043', 'Surya Mukai San Driver', NULL, '8667446445', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1597, NULL, '5044', 'SVRangaswamy Venkatesh', NULL, '9844123326', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1598, NULL, '5045', 'Swapna Carvewing', NULL, '6309241625', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1599, NULL, '3741', 'swathi.cousin', NULL, '9884293402', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1600, NULL, '5046', 'Swedha', NULL, '9003128064', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1601, NULL, '5047', 'Swedha.csc', NULL, '9789940867', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1602, NULL, '2252', 'Synergy Debasish mukarjee', NULL, '9840830183', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1603, NULL, '5049', 'Synergy Ilayakumar', NULL, '9500046584', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1604, NULL, '2819', 'Synergy Karthik legal', NULL, '9789991886', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1605, NULL, '5050', 'Synergy Suresh', NULL, '8754425389', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1606, NULL, '5052', 'T Kannan', NULL, '9042001114', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1607, NULL, '5051', 'T Karthik', NULL, '9036080818', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1608, NULL, '5053', 'T Mani', NULL, '9281004080', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1609, NULL, '5056', 'T Mani Tenant', NULL, '9944699750', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1610, NULL, '169', 'T Prasanna', NULL, '7200059080', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1611, NULL, '5054', 'T Satheesh', NULL, '9283389162', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1612, NULL, '3843', 'T Subbu', NULL, '9043027472', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1613, NULL, '2635', 'T Sundeep', NULL, '9043012455', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1614, NULL, '5984', 'Taamara Boutique', NULL, '9886056497', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1615, NULL, '5057', 'Tamil Sify', NULL, '9952350399', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1616, NULL, '3053', 'TASC Shabana', NULL, '7829025543', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1617, NULL, '5918', 'Tata Emm Emm Gokul', NULL, '9916106730', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1618, NULL, '2242', 'Tata service ess ess motors accnts', NULL, '9620229692', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1619, NULL, '3930', 'Tata Subbu Commercial', NULL, '9043070770', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1620, NULL, '5200', 'Taylor.vimal', NULL, '9840554549', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1621, NULL, '2679', 'Tcl Arjun Thakur', NULL, '9032051431', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1622, NULL, '5894', 'test 2', NULL, '1234567890', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1623, NULL, '1175', 'test 3', NULL, '2356788999', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1624, NULL, '1176', 'test 4', NULL, '2245677899', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1625, NULL, '9920', 'test cntct', NULL, '8790654436', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1626, NULL, '8041', 'test customer', NULL, '9876435679', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1627, NULL, '2', 'Thai Summit Pravin', NULL, '8939830506', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1628, NULL, '418', 'Thai Summit Sanjay', NULL, '4433234671', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1629, NULL, '5063', 'Tharun Marketing Support', NULL, '7010970284', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1630, NULL, '1153', 'The Park Royal', NULL, '7042424242', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1631, NULL, '5064', 'Thendral Doctor', NULL, '8124726361', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1632, NULL, '5066', 'Thirumagal agro Sylesh', NULL, '9655460460', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1633, NULL, '2275', 'Three Bond Loganathan', NULL, '9952967443', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1634, NULL, '623', 'Three Bond Sugumar', NULL, '9940299677', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1635, NULL, '3282', 'Thulasi Kulakarai mandapam', NULL, '9840714029', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1636, NULL, '3572', 'thulasi raju', NULL, '9094522081', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1637, NULL, '5069', 'Tik Radha krish', NULL, '9962047721', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1638, NULL, '399', 'Tikona Customer Care', NULL, '8002094276', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1639, NULL, '2938', 'Tli Anbu', NULL, '7867013803', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1640, NULL, '5072', 'Tli Chotram', NULL, '8754571349', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1641, NULL, '2527', 'TLI Dinesh', NULL, '9600034621', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1642, NULL, '3718', 'TLI DRIVER 3', NULL, '8110958267', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1643, NULL, '5074', 'TLi Driver mano', NULL, '7708535644', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1644, NULL, '5076', 'TLI Driver New', NULL, '9962749536', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1645, NULL, '5205', 'Tli Mohan', NULL, '9047793972', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1646, NULL, '3916', 'TLI Nathram', NULL, '7867013806', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1647, NULL, '5071', 'Tli Prakash', NULL, '8015537846', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1648, NULL, '55', 'TLI Sridhar', NULL, '9600036104', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1649, NULL, '2235', 'TLI Sridhar San Iym', NULL, '7867013805', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1650, NULL, '471', 'Tli Subramani', NULL, '9843031467', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1651, NULL, '37', 'TLI Subramani 2', NULL, '8610617418', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1652, NULL, '2888', 'TLI Vehicle', NULL, '9841193910', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1653, NULL, '3716', 'Tli Vignesh', NULL, '7867013804', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1654, NULL, '10052', 'Tnt ArJun', NULL, '8095993784', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1655, NULL, '3438', 'Tnt Murali Elumalai', NULL, '7200003607', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1656, NULL, '3824', 'TNT raj suresh', NULL, '9445720604', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1657, NULL, '5081', 'Tnt Shafa Riyaz', NULL, '6385718731', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1658, NULL, '5078', 'TNT Younus', NULL, '9944915560', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1659, NULL, '515', 'Transunion Cibil Ltd', NULL, '2261404300', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1660, NULL, '5082', 'Travels', NULL, '9444118037', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1661, NULL, '5083', 'Treleborg Senthil', NULL, '8939981675', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1662, NULL, '5084', 'Trident Prahlad', NULL, '9015915360', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1663, NULL, '2145', 'Triplerock', NULL, '7007610464', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1664, NULL, '2181', 'Tropical Mahesh Babu bnglr', NULL, '9343072909', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1665, NULL, '42', 'TSA MUNI PURCHASE', NULL, '9585409919', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1666, NULL, '462', 'TSA Sanjay', NULL, '8939830508', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1667, NULL, '5095', 'TSVV', NULL, '8148055505', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1668, NULL, '8515', 'Tycoon Rehan Khan', NULL, '7204171501', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1669, NULL, '726', 'Ub Suresh', NULL, '8428929282', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1670, NULL, '5100', 'Uber Auto Kumar', NULL, '8951799606', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1671, NULL, '672', 'Uber Driver', NULL, '8939285266', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1672, NULL, '5099', 'Uber Saravanan', NULL, '9043634818', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1673, NULL, '8519', 'UC Asad Electrician', NULL, '8892482251', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1674, NULL, '3122', 'Udayakumar Rajan', NULL, '1529515082', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1675, NULL, '5102', 'uma akka raji perima', NULL, '9445402506', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1676, NULL, '5103', 'Umaa Bala', NULL, '8946053797', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1677, NULL, '3443', 'Unipress Ahamed', NULL, '7418712641', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1678, NULL, '183', 'Unipress Alagu', NULL, '9176697336', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1679, NULL, '282', 'Unkno', NULL, '7502890220', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1680, NULL, '1145', 'unknown', NULL, '9035389360', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1681, NULL, '1702', 'Unknown', NULL, '9444132833', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1682, NULL, '3623', 'Unni dford', NULL, '9902855663', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1683, NULL, '630', 'UPS Vijay', NULL, '8939841808', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1684, NULL, '205', 'Usa Gokul Frnd', NULL, '9094929791', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1685, NULL, '5106', 'Usha Maami', NULL, '9444919651', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1686, NULL, '5109', 'Vaanavil Estate Arun', NULL, '9790931771', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1687, NULL, '3236', 'Vadivel Milk', NULL, '9962917300', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1688, NULL, '5110', 'Vaibhav Sun pharma', NULL, '9167759933', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1689, NULL, '5112', 'Vanakumar Bluedart', NULL, '7550174784', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1690, NULL, '653', 'Vantec Arul', NULL, '9500087642', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1691, NULL, '9653', 'Var', NULL, '9597255379', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1692, NULL, '10073', 'Varadhan.hem', NULL, '9840891797', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1693, NULL, '758', 'Varalakshmi.athai', NULL, '9003806888', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1694, NULL, '3650', 'Varun Ramanathan Head Accounts Kurlon', 'varunramanathan@kurlon.com', '8088904763', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1695, NULL, '1011', 'vasantha perima tkovilur', NULL, '9952146636', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1696, NULL, '5116', 'Vasu Neighbour', NULL, '9600070966', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1697, NULL, '5117', 'Vasuki Athai', NULL, '9884133899', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1698, NULL, '774', 'Vehicle Dasarathan', NULL, '9965284302', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1699, NULL, '2324', 'vellachandhi anandan', NULL, '7358721827', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1700, NULL, '5119', 'Velmurugan vishwa dad', NULL, '9551756618', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1701, NULL, '5121', 'Venkat blue Dart', NULL, '9840989550', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1702, NULL, '10066', 'Venkat Lakshmi Chithi', NULL, '9840359423', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1703, NULL, '617', 'Venkat Shobi', NULL, '9600074246', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1704, NULL, '5120', 'Venkat Sundu', NULL, '2482276243', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1705, NULL, '2526', 'Venkat Suprajit', NULL, '9940170365', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1706, NULL, '101', 'Venkat.aftersales', NULL, '2488820228', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1707, NULL, '216', 'Venkat.mama', NULL, '2489317149', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1708, NULL, '2734', 'Venkates Springs Arun', NULL, '9600772517', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1709, NULL, '931', 'Venkey', NULL, '7397321784', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1710, NULL, '657', 'Venu smepersonal', NULL, '2484943622', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1711, NULL, '23', 'Vetri Mechanic', NULL, '9884286851', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1712, NULL, '2430', 'Vetrina Snehal', NULL, '8600844429', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1713, NULL, '3434', 'Vibrant David', NULL, '7012451038', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1714, NULL, '5917', 'Vibrant Joseph', NULL, '9176675376', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1715, NULL, '5124', 'Vidhya Kupu Frnd', NULL, '8056434362', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1716, NULL, '67', 'Vidhya.jawahar', NULL, '2484216452', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1717, NULL, '2778', 'Vidhyaa GTC', NULL, '9444164313', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1718, NULL, '3591', 'Vidya Carvewing', NULL, '8289922526', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1719, NULL, '5125', 'Vidya Shashiraja', NULL, '9844329820', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1720, NULL, '2573', 'Vievej', NULL, '9551293123', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1721, NULL, '9211', 'Vignesh Dford', NULL, '9513066926', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1722, NULL, '3314', 'Vignesh gokul', NULL, '9840143807', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1723, NULL, '491', 'Vignesh Indian Bank Acct Numb', NULL, '6714847238', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1724, NULL, '49', 'Vignesh.colg', NULL, '9940342528', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1725, NULL, '2578', 'Vijay Bang', NULL, '9611126065', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1726, NULL, '4021', 'Vijay Vidyaranypura Furniture', NULL, '9743257002', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1727, NULL, '354', 'Vijaya sampath Akka', NULL, '4423810550', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1728, NULL, '3013', 'Viji madhu', NULL, '9962551181', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1729, NULL, '9914', 'Vikas Avtec', NULL, '8989495466', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1730, NULL, '5129', 'Vikas Weighng. Kamalakannan', NULL, '9840785354', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1731, NULL, '3191', 'Vikram Lifelong Metal', NULL, '9884013701', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1732, NULL, '10014', 'Vikram More', NULL, '9820064241', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1733, NULL, '3974', 'Vinithra School', NULL, '9940539752', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1734, NULL, '10230', 'Vino national', NULL, '9884495559', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1735, NULL, '10110', 'Vinod Gokul', NULL, '9840039034', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1736, NULL, '5134', 'Vinod guru stationary', NULL, '9986370490', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1737, NULL, '2451', 'Vinod venkat srm info', NULL, '9940377660', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1738, NULL, '5135', 'Vinod.sai', NULL, '9840034165', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1739, NULL, '2185', 'Vinoth Anna CMC', NULL, '9159150777', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1740, NULL, '5136', 'Vinoth Somic', NULL, '7299947632', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1741, NULL, '5137', 'Vinoth.cricket', NULL, '2486229309', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1742, NULL, '341', 'Visher blue Dart', NULL, '9810820764', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1743, NULL, '5138', 'Vishnu Yesbank', NULL, '9066343212', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1744, NULL, '5139', 'Vishwa', NULL, '9894096262', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1745, NULL, '9948', 'vishwa srikar mahesh apmc', NULL, '9972564900', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1746, NULL, '591', 'Visu', NULL, '9940037353', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1747, NULL, '3422', 'Viswa', NULL, '9578055084', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1748, NULL, '2053', 'Viswa', NULL, '9840300589', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1749, NULL, '655', 'Vivek csc', NULL, '2484107001', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1750, NULL, '5142', 'Vivek kannan jothi', NULL, '8220533801', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1751, NULL, '2280', 'Vivek.cousin', NULL, '9962501350', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1752, NULL, '488', 'Vp usa', NULL, '6472176460', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1753, NULL, '9782', 'Vyapar Customer support', NULL, '9333911911', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1754, NULL, '2948', 'Vyapar Whatsapp support', NULL, '8147754195', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1755, NULL, '2997', 'W Abilaya Ladies Tailors', NULL, '9916366173', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1756, NULL, '5143', 'W ADAMZ CLUB KAMMANAHALLI', NULL, '7019135497', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1757, NULL, '1756', 'W adidas Factory Outlet', NULL, '8041732931', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1758, NULL, '1636', 'W Allen Solly', NULL, '8042051798', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1759, NULL, '1758', 'W allensolly', NULL, '8040944892', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1760, NULL, '3392', 'W AM Fashion Boutique & Collections.', NULL, '8095681275', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1761, NULL, '1650', 'W Ambika Jewellers & Bankers', NULL, '8025421353', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1762, NULL, '7686', 'W Amyra, The Fashion Studio', NULL, '7259211563', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1763, NULL, '3721', 'W Apparel 360 - Men\'s Clothing Store', NULL, '9686115003', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1764, NULL, '8550', 'W ARFIN BOUTIQUE MOHAMMEDHANIF', NULL, '8073405910', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1765, NULL, '3244', 'W Aroma Shimmers', NULL, '9945104621', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1766, NULL, '2561', 'W Ashvik Gold Kammanahalli - Sell Your Gold For Cash', NULL, '6364006008', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1767, NULL, '5145', 'W Avigna Fashion Boutique', NULL, '9916537960', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1768, NULL, '2790', 'W ââ\" Fâsââ\"ââ', NULL, '9739202929', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1769, NULL, '3054', 'W Banana Club Kammanahalli', NULL, '6363802384', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1770, NULL, '5194', 'W Beauty Store', NULL, '8310226014', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1771, NULL, '5146', 'W Breeze ethnic wear', NULL, '8884998021', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1772, NULL, '5147', 'W BRIDALICIOUS BOUTIQUE', NULL, '9986338255', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1773, NULL, '5206', 'W Bright I fashion jewellery', NULL, '9894732739', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1774, NULL, '3946', 'W Colors The Kids Style', NULL, '9845975297', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1775, NULL, '2692', 'W Creative fabz', NULL, '9900242211', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1776, NULL, '2231', 'W Dazzle World', NULL, '9844096500', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1777, NULL, '2331', 'W Dâart Creations', NULL, '9845417467', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1778, NULL, '3671', 'W Debut fashion', NULL, '9916441717', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1779, NULL, '5148', 'W Divine Fashion Boutique ( Jeya JR )', NULL, '9972942097', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1780, NULL, '7505', 'W ELA by JISHA', NULL, '9611011927', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1781, NULL, '2543', 'W Elite Boutique', NULL, '9972034774', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1782, NULL, '5149', 'W Expose A Fashion Destination', NULL, '9980211719', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1783, NULL, '5150', 'W Falcon Sports', NULL, '7022829582', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1784, NULL, '2633', 'W Farhana Designer Studio', NULL, '7892668932', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1785, NULL, '2118', 'W Fashion House', NULL, '7760477854', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1786, NULL, '5151', 'W Fashion Land - Best leather shoes in Bangalore', NULL, '8197651532', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1787, NULL, '3921', 'W Fashion Studio', NULL, '9844367096', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1788, NULL, '1707', 'W Fastrack store', NULL, '8041632190', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1789, NULL, '1746', 'W Favourite Shop', NULL, '8022956316', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1790, NULL, '5152', 'W Femina Fashion Boutique Ladies Fashion Designer', NULL, '9686964446', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1791, NULL, '3094', 'W Femme fashion', NULL, '9980939983', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1792, NULL, '3175', 'W Firstcry.com Store Bangalore CMR Road', NULL, '7760594330', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1793, NULL, '2601', 'W Flash Fashion', NULL, '9448884158', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1794, NULL, '8522', 'W Fresh Pick With Love Collection', NULL, '8296098921', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1795, NULL, '5153', 'W Glam and Groove Boutique', NULL, '9986575763', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1796, NULL, '1733', 'W Global Baby Store Kammanahalli', NULL, '8025441993', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1797, NULL, '1711', 'W Go Colors - Kamanahalli | Women\'s Leggings, Jeans & Pants', NULL, '8048650121', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1798, NULL, '1767', 'W GRT Jewellers, Kammanahalli', NULL, '8025461515', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1799, NULL, '3081', 'W H S Fashion', NULL, '7892894237', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1800, NULL, '5201', 'W HKAASC fashion studio', NULL, '9611775931', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1801, NULL, '10301', 'W HM Kurta', NULL, '9353197125', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1802, NULL, '3425', 'W IKONIX PERFUMER-Kammanahalli', NULL, '7022674447', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1803, NULL, '3643', 'W Ikra by Mila', NULL, '8147838404', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1804, NULL, '3107', 'W IMPO- Clothing & Accessories Store for MEN and WOMEN', NULL, '9611097678', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1805, NULL, '3034', 'W Imran Bag Shop', NULL, '7892130355', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1806, NULL, '2404', 'W Infiniti Fashion Never Ends', NULL, '9591498439', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1807, NULL, '6734', 'W JOANNAH FANCY COSTUMES - GRADUATION GOWNS AND HATS', NULL, '9972011997', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1808, NULL, '3856', 'W JOCKEY STORE ROYAL FASHION', NULL, '9606847396', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1809, NULL, '3971', 'W JOCKEY STORE VANSHIKA FASHION (MULTI BRAND ETC )', NULL, '8097236077', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1810, NULL, '3954', 'W JORU', NULL, '9731304159', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1811, NULL, '1631', 'W Joyalukkas Jewellery - Kammanahalli', NULL, '8025039900', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1812, NULL, '2667', 'W Kalamandir , Kammanahalli', NULL, '9108936060', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1813, NULL, '2980', 'W Kamakshi Kids Wear', NULL, '8553139720', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0);
INSERT INTO `customers` (`id`, `emp_id`, `phone_account_id`, `name`, `email`, `mobile`, `type`, `source`, `another_mobile`, `company`, `gst`, `profile_pic`, `location`, `group`, `dob`, `anniversary`, `created_by`, `status`, `contact_status`, `created_at`, `updated_at`, `is_deleted`) VALUES
(1814, NULL, '3111', 'W Kannur cottons', NULL, '8892717819', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1815, NULL, '3631', 'W Kritique (Studio Kritique)', NULL, '9886780146', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1816, NULL, '1757', 'W Kushal\'s Fashion Jewellery - Kammanahalli, Bengaluru', NULL, '9873513650', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1817, NULL, '2083', 'W Lavender, The Boutique', NULL, '9886765047', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1818, NULL, '3327', 'W Let\'s Wash Laundry Kammanahalli', NULL, '7899258914', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1819, NULL, '5207', 'W Liya Boutique', NULL, '8660902068', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1820, NULL, '1677', 'W Louis Philippe - Kammanahalli', NULL, '8043725932', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1821, NULL, '3388', 'W MAA KALI FLORIST', NULL, '9738059750', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1822, NULL, '5154', 'W Maanini VAstra Samskrithi India Pvt Ltd', NULL, '9901217968', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1823, NULL, '1708', 'W Malabar Gold and Diamonds - Kammanahalli - Bangalore', NULL, '8025423916', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1824, NULL, '2424', 'W Manoj Textiles', NULL, '9448828912', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1825, NULL, '3238', 'W Manyavar', NULL, '8041203846', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1826, NULL, '2348', 'W Manyavar & Mohey', NULL, '7795668227', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1827, NULL, '3617', 'W Maple Silks', NULL, '7259570028', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1828, NULL, '5155', 'W Marina Fashion Boutique', NULL, '9591038339', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1829, NULL, '5156', 'W Max', NULL, '9036730338', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1830, NULL, '3085', 'W Mayur Collection (Export Surplus)', NULL, '9986266962', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1831, NULL, '5157', 'W Meher\'s Fashion 4Ever', NULL, '7975931373', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1832, NULL, '2449', 'W Mercy Fashion', NULL, '8217476508', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1833, NULL, '1656', 'W Miniklub', NULL, '8049933056', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1834, NULL, '5158', 'W Miya Designer Boutique', NULL, '9538405022', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1835, NULL, '3977', 'W Moh Mith', NULL, '9108466668', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1836, NULL, '9652', 'W NASRA BOUTIQUE', NULL, '9916873448', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1837, NULL, '5159', 'W NAVRANG NX (House of Dharaa)', NULL, '9620204640', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1838, NULL, '1604', 'W New Gulshan Family Store', NULL, '8041740303', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1839, NULL, '2477', 'W New style ladies dress makers', NULL, '9902953353', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1840, NULL, '1646', 'W NewU', NULL, '8041635146', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1841, NULL, '3972', 'W Ns Fashion', NULL, '8296505927', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1842, NULL, '3975', 'W Nuozone Boutique', NULL, '9731313134', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1843, NULL, '2414', 'W OB Inspirations', NULL, '9886200092', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1844, NULL, '2136', 'W Oxygen The Garden Boutique', NULL, '9880602020', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1845, NULL, '1693', 'W Pantaloons (Commercial Street, Bengaluru)', NULL, '7795678451', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1846, NULL, '2911', 'W Pavan Fashion', NULL, '7022449579', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1847, NULL, '5160', 'W Praveen Hi-Fashion', NULL, '9066480415', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1848, NULL, '5161', 'W PRINCESS CREATION FASHION DISIGNER BOUTIQUE', NULL, '9611808248', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1849, NULL, '5162', 'W RN FAMOUS DESIGNER BOUTIQUE', NULL, '8892636161', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1850, NULL, '2032', 'W RY Fashions', NULL, '8884331199', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1851, NULL, '3556', 'W S S Fashion Designer', NULL, '9901960795', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1852, NULL, '3108', 'W S.U.Collection@Kammanahalli, Lower , Track pants, shorts &T shirt wholesale', NULL, '8089325350', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1853, NULL, '1752', 'W Sagar Textorium', NULL, '8025455970', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1854, NULL, '2937', 'W Sai Fashion', NULL, '9845960653', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1855, NULL, '3900', 'W Sai Siddhi Sarees', NULL, '8310977240', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1856, NULL, '1719', 'W Salma\'s Designer Boutique', NULL, '8025435577', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1857, NULL, '2383', 'W Sampradaya womenâs couture', NULL, '9019574477', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1858, NULL, '1747', 'W Sansar Collections', NULL, '9152356932', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1859, NULL, '5198', 'W Savys Boutique', NULL, '7795766790', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1860, NULL, '5163', 'W Shams boutique', NULL, '9035348101', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1861, NULL, '3323', 'W Shiva Shakthi Fancy Store', NULL, '9448704174', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1862, NULL, '1785', 'W Shri Durga Mangalore Stores. Kammanahalli', NULL, '8025449331', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1863, NULL, '3294', 'W Shri Sai Boutique', NULL, '9535212380', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1864, NULL, '3555', 'W Smiley Women\'s Fashion', NULL, '9731300669', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1865, NULL, '1787', 'W Soch', NULL, '8069897587', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1866, NULL, '5164', 'W Sonas Flair', NULL, '9945417845', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1867, NULL, '2447', 'W Sri Mayuri Fashions', NULL, '9483831787', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1868, NULL, '1771', 'W SRI VENKATESWARA GARMENTS UNIT 6', NULL, '7975438347', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1869, NULL, '3389', 'W Starlight kurta Gallery', NULL, '9845394477', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1870, NULL, '5165', 'W Steve\'s Stitch', NULL, '8951778488', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1871, NULL, '2836', 'W Style Union - Kammanahalli', NULL, '9429692121', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1872, NULL, '3981', 'W Sun Gift Gallery & Fancy Store', NULL, '9886909142', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1873, NULL, '5166', 'W Surya gift and fancy paradise', NULL, '7014098970', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1874, NULL, '5167', 'W T S Fashion', NULL, '8123517145', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1875, NULL, '2391', 'W Taneira Sarees (Kammanahalli, Bengaluru)', NULL, '9902966599', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1876, NULL, '400', 'W The Boutique', NULL, '9148572780', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1877, NULL, '5195', 'W The Wardrobe Boutique', NULL, '9901039546', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1878, NULL, '5168', 'W TINY TRENDZ {KIDS WEAR & TOYS}', NULL, '9742851714', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1879, NULL, '2540', 'W Twamev', NULL, '9008459214', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1880, NULL, '5169', 'W Universal Clothing / Universal Exports', NULL, '9900382569', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1881, NULL, '5170', 'W Varnika Brass Boutique', NULL, '8884090023', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1882, NULL, '2627', 'W Velvet Drama Studio', NULL, '8050323606', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1883, NULL, '3761', 'W VISHNU TIMES SALES AND SERVICE', NULL, '9448031391', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1884, NULL, '1641', 'W VR Fashions', NULL, '8041122899', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1885, NULL, '1723', 'W Wardrobe Mens Clothing & Accessories', NULL, '8041490094', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1886, NULL, '2710', 'W Watch studio', NULL, '9845032169', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1887, NULL, '2363', 'W Waterlily Studio', NULL, '9686078170', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1888, NULL, '3680', 'W Women\'s Ethnic Wear', NULL, '9731400858', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1889, NULL, '7763', 'W XDRAX', NULL, '9037720714', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1890, NULL, '5172', 'W Yahvi Studio', NULL, '9945836962', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1891, NULL, '1600', 'W YUKBA DESIGNER STUDIO', NULL, '8040976391', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1892, NULL, '2144', 'W Zara Fashion Ladies Tailor', NULL, '9161642213', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1893, NULL, '2520', 'W ZECODE Kammanahalli', NULL, '9152977456', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1894, NULL, '5173', 'walkin support', NULL, '7975702877', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1895, NULL, '5233', 'Waqin Kavitha New Jio', NULL, '7892197358', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1896, NULL, '8184', 'Waqin Sharmila', NULL, '9113088737', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1897, NULL, '10030', 'Waqin Sushma', NULL, '8073044581', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1898, NULL, '3652', 'Waqn Kavita', NULL, '7204167596', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1899, NULL, '2764', 'Water Can', NULL, '9003022346', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1900, NULL, '2228', 'Wintrack Guru', NULL, '7358767601', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1901, NULL, '5176', 'Wintrack Jagadeesh', NULL, '9080745332', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1902, NULL, '3421', 'Wintrk Jeyakumar', NULL, '7338999056', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1903, NULL, '5179', 'Wqn Kavitha', NULL, '8296325676', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1904, NULL, '1178', 'xyz', NULL, '4256362526', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1905, NULL, '3069', 'yashve mart', NULL, '9790885691', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1906, NULL, '3674', 'YJAT ASHOK', NULL, '8939949852', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1907, NULL, '5180', 'YJAT GNANVEL', NULL, '8668174122', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1908, NULL, '18', 'YJAT Hemachandran', NULL, '6379371241', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1909, NULL, '121', 'Yjat Kaviyarasan', NULL, '9884438864', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1910, NULL, '3161', 'Yjat Rajasekaran', NULL, '9176044849', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1911, NULL, '5183', 'YJAT Rajesh PPC', NULL, '7904513258', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1912, NULL, '5474', 'YJAT Rajeshkumar PPC', NULL, '7200697102', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1913, NULL, '3969', 'Yjat Saravanan', NULL, '9444005695', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1914, NULL, '3797', 'Yo Appa', NULL, '9842298424', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1915, NULL, '2857', 'Yokesh gayathri', NULL, '7459686592', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1916, NULL, '305', 'Yorozu Arulraj', NULL, '8939949851', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1917, NULL, '5186', 'Yorozu Rajesh', NULL, '9884654345', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1918, NULL, '6682', 'YuA Boutique Saritha Sreejtih', NULL, '7090604020', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1919, NULL, '3837', 'Yusen Srividya', NULL, '9677127643', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1920, NULL, '594', 'Yuvaraj usa', NULL, '2484942512', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1921, NULL, '5188', 'Zahid.csc', NULL, '9840678413', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1922, NULL, '3301', 'Zaish Ahmad Shaidh K M', NULL, '1502253996', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1923, NULL, '1023', 'Zaish Shaidh 2', NULL, '8660374472', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1924, NULL, '3380', 'Zoho samuel', NULL, '7358611104', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1925, NULL, '1267', 'zoho.csc.abdul', NULL, '9884088398', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1926, NULL, '910', '+1400491085', NULL, '1400491085', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1927, NULL, '372', '+91 91 76 025514', NULL, '9176025514', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1928, NULL, '765', '+91 99 62 390343', NULL, '9962390343', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1929, NULL, '1527', '+919965395853', NULL, '9965395853', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1930, NULL, '3002', '+91 98401 43735', NULL, '9840143735', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1931, NULL, '5025', 'MultiFit', NULL, '8088695823', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'OLD', '2025-08-12 06:35:23', '2025-08-12 06:35:23', 0),
(1932, NULL, '10381', 'Venkat Athi', NULL, '9655521657', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'NEW', '2025-08-12 07:30:57', '2025-08-12 07:30:57', 0),
(1933, NULL, '459', 'Anay Setty', 'indrajitkannan@gmail.com', '2649521095', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'NEW', '2025-08-12 09:15:26', '2025-08-12 09:15:26', 0),
(1934, NULL, '437', 'Aniruddh Ramanathan', 'sainidharmajan@gaba.biz', '5180712847', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'NEW', '2025-08-12 09:15:26', '2025-08-12 09:15:26', 0),
(1935, NULL, '455', 'Areyyy', NULL, '7022555555', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'NEW', '2025-08-12 09:15:26', '2025-08-12 09:15:26', 0),
(1936, NULL, '447', 'Divij Balakrishnan', 'kiaan94@raja.com', '9810041114', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'NEW', '2025-08-12 09:15:26', '2025-08-12 09:15:26', 0),
(1937, NULL, '861', 'Dp', NULL, '1354855055', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'NEW', '2025-08-12 09:15:26', '2025-08-12 09:15:26', 0),
(1938, NULL, '460', 'Farhan Sahota', 'hazeljani@hotmail.com', '9071855063', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'NEW', '2025-08-12 09:15:26', '2025-08-12 09:15:26', 0),
(1939, NULL, '451', 'Ishita Raju', 'hdeshpande@gmail.com', '1163158766', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'NEW', '2025-08-12 09:15:26', '2025-08-12 09:15:26', 0),
(1940, NULL, '493', 'Nun Check', NULL, '7088965847', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'NEW', '2025-08-12 09:15:26', '2025-08-12 09:15:26', 0),
(1941, NULL, '859', 'Qwerty', NULL, '8585858556', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'NEW', '2025-08-12 09:15:26', '2025-08-12 09:15:26', 0),
(1942, NULL, '452', 'Rhea Zachariah', 'karpetaimur@gmail.com', '6702714268', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'NEW', '2025-08-12 09:15:26', '2025-08-12 09:15:26', 0),
(1943, NULL, '438', 'Rohan Chhabra', 'mannatkala@gmail.com', '6466746352', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'NEW', '2025-08-12 09:15:26', '2025-08-12 09:15:26', 0),
(1944, NULL, '852', 'S A G A R', NULL, '8787878787', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'NEW', '2025-08-12 09:15:26', '2025-08-12 09:15:26', 0),
(1945, NULL, '853', 'S S S S S S S', NULL, '8585856855', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'NEW', '2025-08-12 09:15:26', '2025-08-12 09:15:26', 0),
(1946, NULL, '850', 'sa', NULL, '8022329654', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'NEW', '2025-08-12 09:15:26', '2025-08-12 09:15:26', 0),
(1947, NULL, '840', 'sagans', NULL, '7804848595', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'NEW', '2025-08-12 09:15:26', '2025-08-12 09:15:26', 0),
(1948, NULL, '841', 'sgdhs', NULL, '6764949494', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'NEW', '2025-08-12 09:15:26', '2025-08-12 09:15:26', 0),
(1949, NULL, '862', 'Sh Dedg', NULL, '5858888878', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'NEW', '2025-08-12 09:15:26', '2025-08-12 09:15:26', 0),
(1950, NULL, '855', 'sssss', NULL, '8585858585', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'NEW', '2025-08-12 09:15:26', '2025-08-12 09:15:26', 0),
(1951, NULL, '863', 'Su', NULL, '1236547805', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'NEW', '2025-08-12 09:15:26', '2025-08-12 09:15:26', 0),
(1952, NULL, '849', 'Testing Contact', NULL, '9659595956', NULL, 'Mobile App', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 'NEW', '2025-08-12 09:15:26', '2025-08-12 09:15:26', 0);

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
-- Table structure for table `employees`
--

CREATE TABLE `employees` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `full_name` varchar(255) DEFAULT NULL,
  `mobile` varchar(255) NOT NULL,
  `status` tinyint(1) NOT NULL DEFAULT 1,
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0,
  `image` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `doc_id` varchar(255) DEFAULT NULL,
  `employee_id` varchar(255) DEFAULT NULL,
  `product` varchar(255) DEFAULT NULL,
  `service` varchar(255) DEFAULT NULL,
  `total_amount` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `employee_comission`
--

CREATE TABLE `employee_comission` (
  `id` bigint(20) NOT NULL,
  `employee_id` bigint(20) NOT NULL,
  `doc_id` bigint(20) NOT NULL,
  `product` varchar(255) DEFAULT NULL,
  `service` varchar(255) DEFAULT NULL,
  `total_amount` decimal(10,2) NOT NULL,
  `status` tinyint(4) DEFAULT 1,
  `is_deleted` tinyint(4) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `employee_comission`
--

INSERT INTO `employee_comission` (`id`, `employee_id`, `doc_id`, `product`, `service`, `total_amount`, `status`, `is_deleted`, `created_at`, `updated_at`) VALUES
(1, 1, 10, 'Hair Color', 'Hair Styling', 1500.50, 1, 0, '2025-08-12 13:33:47', '2025-08-12 13:33:47'),
(2, 1, 0, NULL, NULL, 200.00, 1, 0, '2025-08-12 13:51:24', '2025-08-12 13:51:24');

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
-- Table structure for table `setting_master`
--

CREATE TABLE `setting_master` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `emp_view_contact` int(11) NOT NULL DEFAULT 0,
  `emp_create_contact` int(11) NOT NULL DEFAULT 0,
  `emp_view_customer` int(11) NOT NULL DEFAULT 0,
  `gst_persantage` int(11) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `setting_master`
--

INSERT INTO `setting_master` (`id`, `emp_view_contact`, `emp_create_contact`, `emp_view_customer`, `gst_persantage`, `created_at`, `updated_at`) VALUES
(1, 0, 0, 0, 0, '2025-08-12 08:41:16', '2025-08-12 08:41:16');

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

--
-- Indexes for dumped tables
--

--
-- Indexes for table `appointment`
--
ALTER TABLE `appointment`
  ADD PRIMARY KEY (`id`);

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
-- Indexes for table `customers`
--
ALTER TABLE `customers`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `documents`
--
ALTER TABLE `documents`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `employees`
--
ALTER TABLE `employees`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `employees_mobile_unique` (`mobile`);

--
-- Indexes for table `employee_comission`
--
ALTER TABLE `employee_comission`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `marketing`
--
ALTER TABLE `marketing`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `newattachments`
--
ALTER TABLE `newattachments`
  ADD PRIMARY KEY (`id`);

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
-- Indexes for table `service-catalogs`
--
ALTER TABLE `service-catalogs`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `setting_master`
--
ALTER TABLE `setting_master`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `stages`
--
ALTER TABLE `stages`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `statuses`
--
ALTER TABLE `statuses`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `tax_details`
--
ALTER TABLE `tax_details`
  ADD PRIMARY KEY (`id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `appointment`
--
ALTER TABLE `appointment`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

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
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `customers`
--
ALTER TABLE `customers`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1953;

--
-- AUTO_INCREMENT for table `employees`
--
ALTER TABLE `employees`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `employee_comission`
--
ALTER TABLE `employee_comission`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `setting_master`
--
ALTER TABLE `setting_master`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `stages`
--
ALTER TABLE `stages`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `statuses`
--
ALTER TABLE `statuses`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

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
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
