# Final Project — Fitness Club Database

**Domain Description:**
This database handles the daily operations for a fitness club franchise with multiple locations in the US. It keeps track of the gyms, staff, customer memberships, class schedules, member bookings, and equipment inventory. It's designed to reliably manage active subscriptions, assign trainers, and track facility use.

**Database Name:** `fitness_club_db`
**Schema Name:** `fitness_club`

**Run Instructions:**
1. Connect to your PostgreSQL server using `psql`, pgAdmin, or DBeaver.
2. Run the `02_final.sql` script from top to bottom.
3. The script is fully re-runnable. You can execute it multiple times safely without duplicate errors—it automatically drops and recreates the schema, resets sequences, and cleans up roles.

**Design Decisions:**
* **3NF Compliance:** I separated `cities` into its own table and linked it to `locations`. This fixes a 3NF violation by removing the transitive dependency between `zip_code` and `city_name`/`state`.
* **ON DELETE CASCADE:** I applied this to `class_bookings`. This way, if a specific `class_schedule` is cancelled and removed, all the member bookings attached to it are automatically cleaned up.
* **ON DELETE RESTRICT:** I used this on `member_subscriptions`. It acts as a safety net so no one can accidentally delete a `membership` tier while members are actively subscribed and paying for it.
