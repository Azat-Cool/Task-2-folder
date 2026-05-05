BEGIN;

WITH new_movies AS (
    SELECT
        'Iron Man' AS title,
        'Billionaire genius Tony Stark is kidnapped by terrorists and forced to build a weapon, but instead builds a powered suit of armor to escape. After returning home, a changed Stark refines the armor, stops manufacturing weapons, and uses his suit to combat his former partners who are selling weapons, ultimately embracing his role as Iron Man.'
         AS description,
        2008 AS release_year,
        (SELECT l.language_id FROM public."language" l WHERE lower(l."name") = 'english') AS language_id,
        7 AS rental_duration,
        4.99 AS rental_rate,
        126 AS length,
        'PG-13'::mpaa_rating AS rating
    UNION ALL
    SELECT
        'The Avengers: Infinity War' AS title,
        'follows the Avengers and Guardians of the Galaxy attempting to stop Thanos from collecting all six Infinity Stones. Thanos seeks to wipe out half of all life in the universe to restore balance. Despite the heroes efforts, Thanos succeeds and initiates The Snap.' AS description,
        2018 AS release_year,
        (SELECT l.language_id FROM public."language" l WHERE lower(l."name") = 'english') AS language_id,
        14 AS rental_duration,
        9.99 AS rental_rate,
        149 AS length,
        'PG-13'::mpaa_rating AS rating
    UNION ALL
    SELECT
        'The witch experiment' AS title,
        'Mercenaries are chasing a girl with superhuman powers who as escaped from a laboratory. A certain organization kidnaps a schoolgirl to hold her captive in a secret laboratory and conduct experiments on her. The girl finds a new family, but the secret organization isn’t ready to let go.' AS description,
        2022 AS release_year,
        (SELECT l.language_id FROM public."language" l WHERE lower(l."name") = 'english') AS language_id,
        21 AS rental_duration,
        19.99 AS rental_rate,
        113 AS length,
        'PG-13'::mpaa_rating AS rating
)
INSERT INTO public.film
    (title, description, release_year, language_id, rental_duration, rental_rate, "length", rating, last_update)
SELECT
    nm.title, nm.description, nm.release_year, nm.language_id, nm.rental_duration, nm.rental_rate, nm."length", nm.rating, current_date
FROM new_movies nm
WHERE NOT EXISTS (
    SELECT 1 FROM public.film f WHERE f.title = nm.title AND f.release_year = nm.release_year
);


INSERT INTO actor (first_name, last_name, last_update)
SELECT first_name, last_name, CURRENT_DATE
FROM (
    VALUES 
        ('Robert', 'Downey'), ('Gwyneth', 'Paltrow'),
        ('Chris', 'Hemsworth'), ('Josh', 'Brolin'),
        ('Kim', 'Da-mi'), ('Choi', 'Woo-shik')
) AS new_actors(first_name, last_name)
WHERE NOT EXISTS (
    SELECT 1 FROM actor a WHERE a.first_name = new_actors.first_name AND a.last_name = new_actors.last_name
);

INSERT INTO film_actor (actor_id, film_id, last_update)
SELECT a.actor_id, f.film_id, CURRENT_DATE
FROM actor a
JOIN film f ON 1=1
WHERE 
    (a.first_name = 'Robert' AND a.last_name = 'Downey' AND f.title = 'Iron Man') OR
    (a.first_name = 'Gwyneth' AND a.last_name = 'Paltrow' AND f.title = 'Iron Man') OR
    (a.first_name = 'Chris' AND a.last_name = 'Hemsworth' AND f.title = 'The Avengers: Infinity War') OR
    (a.first_name = 'Josh' AND a.last_name = 'Brolin' AND f.title = 'The Avengers: Infinity War') OR
    (a.first_name = 'Kim' AND a.last_name = 'Da-mi' AND f.title = 'The witch experiment') OR
    (a.first_name = 'Choi' AND a.last_name = 'Woo-shik' AND f.title = 'The witch experiment')
ON CONFLICT (actor_id, film_id) DO NOTHING;



INSERT INTO inventory (film_id, store_id, last_update)
SELECT f.film_id, s.store_id, CURRENT_DATE
FROM film f
CROSS JOIN (SELECT store_id FROM store LIMIT 1) s
WHERE f.title IN ('Iron Man', 'The Avengers: Infinity War', 'The witch experiment')
AND NOT EXISTS (
    SELECT 1 FROM inventory i WHERE i.film_id = f.film_id AND i.store_id = s.store_id
);

WITH target_customer AS (
    SELECT customer_id, 1 AS priority 
    FROM customer WHERE first_name = 'Mark' AND last_name = 'Robbinson'
    UNION ALL
    SELECT c.customer_id, 2 AS priority
    FROM customer c
    JOIN rental r ON c.customer_id = r.customer_id
    JOIN payment p ON c.customer_id = p.customer_id
    GROUP BY c.customer_id
    HAVING COUNT(DISTINCT r.rental_id) >= 43 AND COUNT(DISTINCT p.payment_id) >= 43
),
selected AS (SELECT customer_id FROM target_customer ORDER BY priority ASC LIMIT 1)
UPDATE customer
SET first_name = 'Mark', last_name = 'Robbinson', email = 'mark@gmail.com', last_update = CURRENT_DATE
WHERE customer_id = (SELECT customer_id FROM selected);

SELECT * FROM payment WHERE customer_id = (SELECT customer_id FROM customer WHERE first_name = 'Mark' AND last_name = 'Robbinson');
SELECT * FROM rental WHERE customer_id = (SELECT customer_id FROM customer WHERE first_name = 'Mark' AND last_name = 'Robbinson');

DELETE FROM payment 
WHERE customer_id = (SELECT customer_id FROM customer WHERE first_name = 'Mark' AND last_name = 'Robbinson')
AND payment_date < '2017-01-01'; 

DELETE FROM rental 
WHERE customer_id = (SELECT customer_id FROM customer WHERE first_name = 'Mark' AND last_name = 'Robbinson')
AND rental_date < '2017-01-01';

WITH newly_rented AS (
    INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
    SELECT 
        '2017-01-01 10:00:00'::timestamp,
        i.inventory_id,
        c.customer_id,
        '2017-01-01 10:00:00'::timestamp + (f.rental_duration * INTERVAL '1 day'),
        (SELECT staff_id FROM staff LIMIT 1),
        CURRENT_DATE
    FROM film f
    JOIN inventory i ON f.film_id = i.film_id
    CROSS JOIN (SELECT customer_id FROM customer WHERE first_name = 'Mark' AND last_name = 'Robbinson' LIMIT 1) c
    WHERE f.title IN ('Iron Man', 'The Avengers: Infinity War', 'The witch experiment')
    AND NOT EXISTS (
        SELECT 1 FROM rental r WHERE r.customer_id = c.customer_id AND r.inventory_id = i.inventory_id
    )
    RETURNING rental_id, customer_id, staff_id, inventory_id
)
INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date)
SELECT 
    nr.customer_id, nr.staff_id, nr.rental_id, f.rental_rate, '2017-01-15 14:00:00'::timestamp
FROM newly_rented nr
JOIN inventory i ON nr.inventory_id = i.inventory_id
JOIN film f ON i.film_id = f.film_id;

COMMIT;