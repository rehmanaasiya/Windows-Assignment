use mavenmovies;

-- 1. **Rank the customers based on the total amount they've spent on rentals.**
select customer_id, Concat(first_name, ' ', last_name) as 
customer_name, amount, Rank() Over(order by amount desc) as rank_by_amount 
from (select c.customer_id, c.first_name, c.last_name, sum(p.amount) as amount 
from customer c
join payment p on c.customer_id = p.customer_id
group by c.customer_id) 
as total_amount_per_customer;

-- 2. **Calculate the cumulative revenue generated by each film over time.** 
SELECT film_id, title, rental_date, amount,
       SUM(amount) OVER (PARTITION BY film_id ORDER BY rental_date) AS cumulative_revenue
from (SELECT f.film_id, f.title, r.rental_date, p.amount FROM film f
join inventory i ON f.film_id = i.film_id
join rental r ON i.inventory_id = r.inventory_id
join payment p ON r.rental_id = p.rental_id) AS film_revenue;

-- 3. **Determine the average rental duration for each film, considering films with similar lengths.**
Select film_id, title, rental_duration,
Avg(rental_duration) over(partition by rental_duration) AS avg_rental_duration from film;

-- 4. **Identify the top 3 films in each category based on their rental counts.**
With category_film_rentals as (
Select fc.category_id, f.film_id, f.title, COUNT(r.rental_id) as rental_count,
rank() over(partition by fc.category_id ORDER BY COUNT(r.rental_id) desc) as rank_in_category
from film f
join film_category fc ON f.film_id = fc.film_id
join inventory i ON f.film_id = i.film_id
join rental r on i.inventory_id = r.inventory_id
group by fc.category_id, f.film_id, f.title)
select category_id, film_id, title, rental_count, rank_in_category
from category_film_rentals
where rank_in_category <= 3;

-- 5. **Calculate the difference in rental counts between each customer's total rentals and the average rentals
-- across all customers.**
select customer_id, concat(first_name, ' ', last_name) as customer_name,
rental_count, rental_count - AVG(rental_count) OVER () AS diff_from_avg_rentals
from(select c.customer_id, c.first_name, c.last_name, count(r.rental_id) as rental_count
from customer c left join rental r ON c.customer_id = r.customer_id
group by c.customer_id) as customer_rentals;

-- 6. **Find the monthly revenue trend for the entire rental store over time.**
SELECT DATE_FORMAT(payment_date, '%Y-%m') AS payment_month,
SUM(amount) AS monthly_revenue FROM payment
GROUP BY payment_month;

-- 7. **Identify the customers whose total spending on rentals falls within the top 20% of all customers.**
WITH ranked_customers AS (
SELECT customer_id, CONCAT(first_name, ' ', last_name) AS customer_name, total_amount,
NTILE(5) OVER (ORDER BY total_amount DESC) AS percentile
FROM (SELECT c.customer_id, c.first_name, c.last_name, SUM(p.amount) AS total_amount FROM customer c
JOIN payment p ON c.customer_id = p.customer_id
GROUP BY c.customer_id) AS customer_amounts)
SELECT customer_id, customer_name, total_amount, percentile
FROM ranked_customers WHERE percentile = 1;

-- 8. **Calculate the running total of rentals per category, ordered by rental count:**
SELECT category_id, film_id, title, rental_count,
SUM(rental_count) OVER (PARTITION BY category_id ORDER BY film_id) AS running_total
FROM (SELECT fc.category_id, f.film_id, f.title, COUNT(r.rental_id) AS rental_count
FROM film f JOIN film_category fc ON f.film_id = fc.film_id
JOIN inventory i ON f.film_id = i.film_id
JOIN rental r ON i.inventory_id = r.inventory_id
GROUP BY fc.category_id, f.film_id, f.title) AS category_film_rentals;

-- 9. **Find the films that have been rented less than the average rental count for their respective categories:**
WITH category_avg_rentals AS (SELECT fc.category_id, 
AVG(COUNT(r.rental_id)) OVER (PARTITION BY fc.category_id) AS avg_rental_count
FROM film f JOIN film_category fc ON f.film_id = fc.film_id
JOIN inventory i ON f.film_id = i.film_id
JOIN rental r ON i.inventory_id = r.inventory_id
GROUP BY fc.category_id, f.film_id, f.title)
SELECT cf.category_id, cf.film_id, cf.title, cf.rental_count, car.avg_rental_count
FROM (SELECT fc.category_id, f.film_id, f.title, COUNT(r.rental_id) AS rental_count
FROM film f JOIN film_category fc ON f.film_id = fc.film_id
JOIN inventory i ON f.film_id = i.film_id
JOIN rental r ON i.inventory_id = r.inventory_id
GROUP BY fc.category_id, f.film_id, f.title) AS cf
JOIN category_avg_rentals AS car ON cf.category_id = car.category_id
WHERE cf.rental_count < car.avg_rental_count;

-- 10. **Identify the top 5 months with the highest revenue and display the revenue generated in each month:**
SELECT payment_month, monthly_revenue
FROM (SELECT DATE_FORMAT(payment_date, '%Y-%m') AS payment_month,
SUM(amount) AS monthly_revenue,
RANK() OVER (ORDER BY SUM(amount) DESC) AS revenue_rank FROM payment
GROUP BY DATE_FORMAT(payment_date, '%Y-%m')) AS monthly_revenues
WHERE revenue_rank <= 5;