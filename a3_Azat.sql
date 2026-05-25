DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'fitness_club_db') THEN
        EXECUTE 'CREATE DATABASE fitness_club_db';
    END IF;
END $$;

create database fitness_club_db;


CREATE SCHEMA IF NOT EXISTS fitness_club;

-- Re-runnable: drop in reverse FK order, then recreate
DROP TABLE IF EXISTS fitness_club.class_bookings,
                     fitness_club.member_subscriptions,
                     fitness_club.equipment,
                     fitness_club.class_schedules,
                     fitness_club.classes,
                     fitness_club.memberships,
                     fitness_club.members,
                     fitness_club.staff,
                     fitness_club.locations,
                     fitness_club.cities CASCADE;

-- ============================================================
-- PART 2: CREATE TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS fitness_club.cities (
    city_id      SERIAL PRIMARY KEY,
    city_name    VARCHAR(100) NOT NULL UNIQUE,
    state        VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS fitness_club.locations (
    location_id  SERIAL PRIMARY KEY,
    city_id      INT NOT NULL REFERENCES fitness_club.cities(city_id) ON DELETE RESTRICT,
    name         VARCHAR(100) NOT NULL,
    zip_code     VARCHAR(10) NOT NULL
);

CREATE TABLE IF NOT EXISTS fitness_club.staff (
    staff_id     SERIAL PRIMARY KEY,
    email        VARCHAR(120) NOT NULL UNIQUE,
    full_name    VARCHAR(150) NOT NULL,
    role         VARCHAR(50) NOT NULL,
    nickname     VARCHAR(50) -- Speculative column to be dropped later
);

CREATE TABLE IF NOT EXISTS fitness_club.members (
    member_id    SERIAL PRIMARY KEY,
    -- #4 UNIQUE on a natural key
    email        VARCHAR(120) UNIQUE NOT NULL,
    -- #5 NOT NULL on a non-trivial column
    full_name    VARCHAR(150) NOT NULL,
    -- #3 Value restricted to specific options
    gender       VARCHAR(10) NOT NULL CHECK (gender IN ('M','F','Other')),
    birth_date   DATE NOT NULL,
    phone        VARCHAR(15),
    tier_status  VARCHAR(20) DEFAULT 'standard'
);

CREATE TABLE IF NOT EXISTS fitness_club.memberships (
    membership_id SERIAL PRIMARY KEY,
    type_name     VARCHAR(50) NOT NULL UNIQUE,
    monthly_fee   NUMERIC(10,2) NOT NULL
);

CREATE TABLE IF NOT EXISTS fitness_club.member_subscriptions (
    subscription_id SERIAL PRIMARY KEY,
    member_id       INT NOT NULL REFERENCES fitness_club.members(member_id) ON DELETE CASCADE,
    membership_id   INT NOT NULL REFERENCES fitness_club.memberships(membership_id) ON DELETE RESTRICT,
    -- #1 Date after 2026-01-01
    start_date      DATE NOT NULL CHECK (start_date > DATE '2026-01-01'),
    applied_fee     NUMERIC(10,2) NOT NULL
);

CREATE TABLE IF NOT EXISTS fitness_club.classes (
    class_id         SERIAL PRIMARY KEY,
    name             VARCHAR(100) NOT NULL UNIQUE,
    -- #2 Measured value cannot be negative
    duration_minutes INT NOT NULL CHECK (duration_minutes >= 0)
);

CREATE TABLE IF NOT EXISTS fitness_club.class_schedules (
    schedule_id   SERIAL PRIMARY KEY,
    class_id      INT NOT NULL REFERENCES fitness_club.classes(class_id) ON DELETE CASCADE,
    location_id   INT NOT NULL REFERENCES fitness_club.locations(location_id) ON DELETE CASCADE,
    staff_id      INT NOT NULL REFERENCES fitness_club.staff(staff_id) ON DELETE RESTRICT,
    schedule_date DATE NOT NULL CHECK (schedule_date > DATE '2026-01-01')
);

CREATE TABLE IF NOT EXISTS fitness_club.class_bookings (
    booking_id    SERIAL PRIMARY KEY,
    member_id     INT NOT NULL REFERENCES fitness_club.members(member_id) ON DELETE CASCADE,
    schedule_id   INT NOT NULL REFERENCES fitness_club.class_schedules(schedule_id) ON DELETE CASCADE,
    status        VARCHAR(20) NOT NULL
);

CREATE TABLE IF NOT EXISTS fitness_club.equipment (
    equipment_id   SERIAL PRIMARY KEY,
    location_id    INT NOT NULL REFERENCES fitness_club.locations(location_id) ON DELETE CASCADE,
    name           VARCHAR(100) NOT NULL,
    weight_kg      NUMERIC(5,2) NOT NULL CHECK (weight_kg >= 0),
    quantity       INT NOT NULL CHECK (quantity >= 0),
    purchase_price NUMERIC(10,2) NOT NULL CHECK (purchase_price >= 0),
    -- GENERATED derived from other columns
    total_value    NUMERIC(12,2) GENERATED ALWAYS AS (quantity * purchase_price) STORED
);


-- ============================================================
-- PART 3: ALTER TABLE
-- ============================================================

-- 1. ALTER COLUMN: Phone numbers need to be wider for international formatting
ALTER TABLE fitness_club.members ALTER COLUMN phone TYPE VARCHAR(20);

-- 2. ADD CONSTRAINT: Ensure location names are not duplicated within the system
ALTER TABLE fitness_club.locations ADD CONSTRAINT uq_location_name UNIQUE (name);

-- 3. DROP COLUMN: The nickname column is unnecessary for official HR data
ALTER TABLE fitness_club.staff DROP COLUMN nickname;

-- 4. RENAME COLUMN: Rename ambiguous 'status' to 'booking_status'
ALTER TABLE fitness_club.class_bookings RENAME COLUMN status TO booking_status;

-- 5. SET DEFAULT: New bookings should automatically default to 'confirmed'
ALTER TABLE fitness_club.class_bookings ALTER COLUMN booking_status SET DEFAULT 'confirmed';


-- ============================================================
-- PART 4: INSERT
-- ============================================================

-- Re-runnable reset: truncate in reverse FK order
TRUNCATE TABLE fitness_club.class_bookings,
               fitness_club.equipment,
               fitness_club.class_schedules,
               fitness_club.member_subscriptions,
               fitness_club.memberships,
               fitness_club.classes,
               fitness_club.members,
               fitness_club.staff,
               fitness_club.locations,
               fitness_club.cities
        RESTART IDENTITY CASCADE;

-- Insert Cities (Parent)
INSERT INTO fitness_club.cities (city_name, state) VALUES
    ('New York', 'NY'),
    ('Los Angeles', 'CA'),
    ('Austin', 'TX');

-- Insert Locations (Parent/Child)
INSERT INTO fitness_club.locations (city_id, name, zip_code) VALUES
    ((SELECT city_id FROM fitness_club.cities WHERE city_name = 'New York'), 'Downtown Manhattan Elite', '10001'),
    ((SELECT city_id FROM fitness_club.cities WHERE city_name = 'Los Angeles'), 'Venice Beach Muscle', '90291'),
    ((SELECT city_id FROM fitness_club.cities WHERE city_name = 'Austin'), 'Austin Southpark', '78704');

-- Insert Staff (Parent)
INSERT INTO fitness_club.staff (email, full_name, role) VALUES
    ('j.smith@fitnessclub.com', 'John Smith', 'Manager'),
    ('s.connor@fitnessclub.com', 'Sarah Connor', 'Trainer'),
    ('d.johnson@fitnessclub.com', 'Dwayne Johnson', 'Trainer');

-- Insert Members (Parent)
INSERT INTO fitness_club.members (email, full_name, gender, birth_date, phone) VALUES
    ('alice.w@example.com', 'Alice Williams', 'F', DATE '1992-05-14', '+1-555-0101'),
    ('b.miller@example.com', 'Brian Miller', 'M', DATE '1988-10-22', '+1-555-0102'),
    ('c.davis@example.com', 'Charlie Davis', 'Other', DATE '1995-02-08', '+1-555-0103');

-- Insert Memberships (Parent)
INSERT INTO fitness_club.memberships (type_name, monthly_fee) VALUES
    ('Basic', 49.99),
    ('Premium', 89.99),
    ('VIP All-Access', 149.99);

-- Insert Classes (Parent)
INSERT INTO fitness_club.classes (name, duration_minutes) VALUES
    ('Power Yoga', 60),
    ('HIIT Core', 45),
    ('Olympic Weightlifting', 90);

-- Insert Equipment (Child)
INSERT INTO fitness_club.equipment (location_id, name, weight_kg, quantity, purchase_price) VALUES
    ((SELECT location_id FROM fitness_club.locations WHERE name = 'Downtown Manhattan Elite'), 'Treadmill Series 7', 120.00, 15, 2500.00),
    ((SELECT location_id FROM fitness_club.locations WHERE name = 'Venice Beach Muscle'), 'Olympic Barbell', 20.00, 30, 250.00),
    ((SELECT location_id FROM fitness_club.locations WHERE name = 'Austin Southpark'), 'Kettlebell Set', 24.00, 50, 85.00);

-- Insert Member Subscriptions (Child with FK lookups)
INSERT INTO fitness_club.member_subscriptions (member_id, membership_id, start_date, applied_fee) VALUES
    ((SELECT member_id FROM fitness_club.members WHERE email = 'alice.w@example.com'),
     (SELECT membership_id FROM fitness_club.memberships WHERE type_name = 'Premium'),
     DATE '2026-03-01', 89.99),
    ((SELECT member_id FROM fitness_club.members WHERE email = 'b.miller@example.com'),
     (SELECT membership_id FROM fitness_club.memberships WHERE type_name = 'Basic'),
     DATE '2026-04-15', 49.99),
    ((SELECT member_id FROM fitness_club.members WHERE email = 'c.davis@example.com'),
     (SELECT membership_id FROM fitness_club.memberships WHERE type_name = 'VIP All-Access'),
     DATE '2026-05-01', 149.99);

-- Insert Class Schedules (Child with FK lookups)
INSERT INTO fitness_club.class_schedules (class_id, location_id, staff_id, schedule_date) VALUES
    ((SELECT class_id FROM fitness_club.classes WHERE name = 'Power Yoga'),
     (SELECT location_id FROM fitness_club.locations WHERE name = 'Downtown Manhattan Elite'),
     (SELECT staff_id FROM fitness_club.staff WHERE email = 's.connor@fitnessclub.com'),
     DATE '2026-06-10'),
    ((SELECT class_id FROM fitness_club.classes WHERE name = 'HIIT Core'),
     (SELECT location_id FROM fitness_club.locations WHERE name = 'Austin Southpark'),
     (SELECT staff_id FROM fitness_club.staff WHERE email = 'd.johnson@fitnessclub.com'),
     DATE '2026-06-11'),
    ((SELECT class_id FROM fitness_club.classes WHERE name = 'Olympic Weightlifting'),
     (SELECT location_id FROM fitness_club.locations WHERE name = 'Venice Beach Muscle'),
     (SELECT staff_id FROM fitness_club.staff WHERE email = 'd.johnson@fitnessclub.com'),
     DATE '2026-06-12');

-- Insert Class Bookings (Junction table using INSERT ... SELECT)
INSERT INTO fitness_club.class_bookings (member_id, schedule_id, booking_status)
SELECT m.member_id, s.schedule_id, x.b_status
FROM (VALUES
    ('alice.w@example.com', 'Power Yoga', DATE '2026-06-10', 'confirmed'),
    ('b.miller@example.com', 'HIIT Core', DATE '2026-06-11', 'waitlisted'),
    ('c.davis@example.com', 'Olympic Weightlifting', DATE '2026-06-12', 'confirmed')
) AS x(member_email, class_name, sched_date, b_status)
JOIN fitness_club.members m ON m.email = x.member_email
JOIN fitness_club.classes c ON c.name = x.class_name
JOIN fitness_club.class_schedules s ON s.class_id = c.class_id AND s.schedule_date = x.sched_date;


-- ============================================================
-- PART 5: UPDATE
-- ============================================================

-- Simple UPDATE: Upgrade member tiers based on their subscription choices
-- Business reason: Members paying for 'VIP All-Access' are flagged as premium in their profile.
UPDATE fitness_club.members
SET tier_status = 'premium'
WHERE member_id IN (
    SELECT member_id 
    FROM fitness_club.member_subscriptions ms
    JOIN fitness_club.memberships m ON ms.membership_id = m.membership_id
    WHERE m.type_name = 'VIP All-Access'
);

-- UPDATE ... FROM: Apply a 10% grandfathered discount to active subscriptions
-- Business reason: Re-aligns existing subscription applied_fees to the latest base monthly_fee minus a loyalty discount.
UPDATE fitness_club.member_subscriptions ms
SET applied_fee = sub.discounted_fee
FROM (
    SELECT membership_id, (monthly_fee * 0.9) AS discounted_fee
    FROM fitness_club.memberships
) sub
WHERE ms.membership_id = sub.membership_id;


-- ============================================================
-- PART 5: DELETE
-- ============================================================

-- Business reason: Purge waitlisted bookings for classes that have already passed.
-- Wrapped in BEGIN ... ROLLBACK so demo data survives for the defense check.
BEGIN;
    DELETE FROM fitness_club.class_bookings
    WHERE booking_status = 'waitlisted'
      AND schedule_id IN (
          SELECT schedule_id 
          FROM fitness_club.class_schedules 
          WHERE schedule_date < CURRENT_DATE
      )
    RETURNING booking_id, member_id, schedule_id;
ROLLBACK;


-- ============================================================
-- PART 6: GRANT / REVOKE
-- ============================================================

-- Re-runnable role cleanup
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'fitness_readonly') THEN
        REASSIGN OWNED BY fitness_readonly TO CURRENT_USER;
        DROP OWNED BY fitness_readonly;
        DROP ROLE fitness_readonly;
    END IF;
    
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'fitness_writer') THEN
        REASSIGN OWNED BY fitness_writer TO CURRENT_USER;
        DROP OWNED BY fitness_writer;
        DROP ROLE fitness_writer;
    END IF;
END $$;

-- Two roles for application infrastructure
CREATE ROLE fitness_readonly;
CREATE ROLE fitness_writer;

-- Schema USAGE is required before table-level grants function
GRANT USAGE ON SCHEMA fitness_club TO fitness_readonly, fitness_writer;

-- Reader: Read-only access to all tracking metrics and data
GRANT SELECT ON ALL TABLES IN SCHEMA fitness_club TO fitness_readonly;

-- Writer: Application backend can modify bookings
GRANT INSERT, UPDATE ON fitness_club.class_bookings TO fitness_writer;

-- REVOKE: Post-mortem security patch
-- Business reason: The booking UI service should only be able to INSERT new reservations. 
-- Status updates (like cancellations) are now handled by a separate audit-logged backend service.
REVOKE UPDATE ON fitness_club.class_bookings FROM fitness_writer;