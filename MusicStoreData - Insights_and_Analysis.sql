--  how many customers are there in each country?
SELECT country,
       COUNT(*) AS total_customers
FROM customer
GROUP BY country
ORDER BY total_customers DESC;


--  how many tracks belong to each genre?
SELECT g.name AS genre,
	   COUNT(t.track_id) AS track_count
FROM track t
JOIN genre g ON t.genre_id = g.genre_id
GROUP BY g.name
ORDER BY track_count DESC;


-- List all playlists with number of tracks in each
SELECT p.name AS playlist,
       COUNT(pt.track_id) AS number_of_tracks
FROM playlist p
JOIN playlist_track pt ON p.playlist_id = pt.playlist_id
GROUP BY p.name
ORDER BY number_of_tracks DESC;


-- Show total revenue per country
SELECT c.country,
       ROUND(SUM(i.total), 2) AS revenue
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.country
ORDER BY revenue DESC;


-- Show track details with price higher than average
SELECT name, unit_price
FROM track
WHERE unit_price > (SELECT AVG(unit_price) FROM track)
ORDER BY unit_price DESC;


-- Most Loyal Customers per Country
WITH RankedCustomers AS (
  SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.country,
    COUNT(i.invoice_id) AS InvoiceCount,
    RANK() OVER (PARTITION BY c.country ORDER BY COUNT(i.invoice_id) DESC) AS rnk
  FROM customer c
  JOIN invoice i ON c.customer_id = i.customer_id
  GROUP BY c.customer_id, c.first_name, c.last_name, c.country
)
SELECT customer_id, first_name, last_name, country, InvoiceCount
FROM RankedCustomers WHERE rnk <= 3;



-- Revenue Growth Rate Month over Month
WITH MonthlyRevenue AS (
  SELECT 
    DATE_FORMAT(invoice_date, '%Y-%m') AS Month,
    SUM(total) AS Revenue
  FROM invoice
  GROUP BY Month
),
RevenueChange AS (
  SELECT 
    Month,
    Revenue,
    LAG(Revenue) OVER (ORDER BY Month) AS PrevRevenue
  FROM MonthlyRevenue
)
SELECT 
  Month,
  Revenue,
  PrevRevenue,
  ROUND((Revenue - PrevRevenue) / PrevRevenue * 100, 2) AS GrowthPercent
FROM RevenueChange
WHERE PrevRevenue IS NOT NULL;


-- Customers Who Only Purchased Rock Music
SELECT DISTINCT c.customer_id, c.first_name, c.last_name
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
JOIN invoice_line il ON i.invoice_id = il.invoice_id
JOIN track t ON il.track_id = t.track_id
JOIN genre g ON t.genre_id = g.genre_id
WHERE g.name = 'rock'
AND NOT EXISTS (
  SELECT 1
  FROM invoice i2
  JOIN invoice_line il2 ON i2.invoice_id = il2.invoice_id
  JOIN track t2 ON il2.track_id = t2.track_id
  JOIN genre g2 ON t2.genre_id = g2.genre_id
  WHERE i2.customer_id = c.customer_id AND g2.name <> 'rock'
);



-- Genre-wise Average Track Duration and Revenue
SELECT 
    g.name AS Genre,
    ROUND(AVG(t.milliseconds) / 1000, 2) AS AvgDurationSec,
    ROUND(SUM(il.unit_price * il.quantity), 2) AS TotalRevenue
FROM track t JOIN genre g
ON t.genre_id = g.genre_id
JOIN invoice_line il ON t.track_id = il.track_id
GROUP BY g.name
ORDER BY TotalRevenue DESC;


--  Find Customers Who Spent Above the Country Average
WITH CountrySpending AS (
  SELECT 
    c.country,
    c.customer_id,
    SUM(i.total) AS TotalSpent
  FROM customer c
  JOIN invoice i ON c.customer_id = i.customer_id
  GROUP BY c.customer_id, c.country
),
CountryAvg AS (
  SELECT country, AVG(TotalSpent) AS AvgSpent
  FROM CountrySpending
  GROUP BY Country
)
SELECT cs.customer_id, cs.country, cs.TotalSpent, ca.AvgSpent
FROM CountrySpending cs
JOIN CountryAvg ca ON cs.country = ca.country
WHERE cs.TotalSpent > ca.AvgSpent;


--  Top 5 Longest Tracks Per Genre
WITH RankedTracks AS (
  SELECT 
    t.track_id,
    t.name AS TrackName,
    g.name AS Genre,
    t.milliseconds,
    RANK() OVER (PARTITION BY g.genre_id ORDER BY t.milliseconds DESC) AS rnk
  FROM track t
  JOIN genre g ON t.genre_id = g.genre_id
)
SELECT * 
FROM RankedTracks
WHERE rnk <= 5
ORDER BY Genre, rnk;


--  Customer Retention: Days Between First and Last Purchase
SELECT 
  c.customer_id,
  c.first_name,
  c.last_name,
  MIN(i.invoice_date) AS FirstPurchase,
  MAX(i.invoice_date) AS LastPurchase,
  DATEDIFF(MAX(i.invoice_date), MIN(i.invoice_date)) AS DaysBetween
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY DaysBetween DESC;


-- Revenue Contribution % by Each Country
WITH CountryRevenue AS (
  SELECT country, SUM(total) AS Revenue
  FROM customer c
  JOIN invoice i ON c.customer_id = i.customer_id
  GROUP BY country
),
TotalRevenue AS (
  SELECT SUM(Revenue) AS GlobalRevenue FROM CountryRevenue
)
SELECT 
  cr.country,
  cr.Revenue,
  ROUND((cr.Revenue / tr.GlobalRevenue) * 100, 2) AS RevenuePercent
FROM CountryRevenue cr
CROSS JOIN TotalRevenue tr
ORDER BY RevenuePercent DESC;


-- Find Top 2 Most Common Genres in Each Playlist
WITH GenreRanks AS (
  SELECT 
    pl.name AS Playlist,
    g.name AS Genre,
    COUNT(*) AS TrackCount,
    RANK() OVER (PARTITION BY pl.playlist_id ORDER BY COUNT(*) DESC) AS rnk
  FROM playlist_track pt
  JOIN playlist pl ON pt.playlist_id = pl.playlist_id
  JOIN track t ON pt.track_id = t.track_id
  JOIN genre g ON t.genre_id = g.genre_id
  GROUP BY pl.playlist_id, g.genre_id, Playlist, Genre
)
SELECT Playlist, Genre, TrackCount FROM GenreRanks WHERE rnk <= 2;


-- Customer-Genre Preference Score
WITH GenreSpend AS (
  SELECT 
    c.customer_id,
    g.name AS Genre,
    SUM(il.unit_price * il.quantity) AS TotalGenreSpend
  FROM customer c
  JOIN invoice i ON c.customer_id = i.customer_id
  JOIN invoice_line il ON i.invoice_id = il.invoice_id
  JOIN track t ON il.track_id = t.track_id
  JOIN genre g ON t.genre_id = g.genre_id
  GROUP BY c.customer_id, g.genre_id
),
GenreMaxSpend AS (
  SELECT 
    customer_id,
    MAX(TotalGenreSpend) AS MaxSpend
  FROM GenreSpend
  GROUP BY customer_id
)
SELECT 
  gs.customer_id,
  gs.Genre,
  ROUND(gs.TotalGenreSpend / gms.MaxSpend, 2) AS PreferenceScore
FROM GenreSpend gs
JOIN GenreMaxSpend gms ON gs.customer_id = gms.customer_id
ORDER BY gs.customer_id, PreferenceScore DESC;


-- The Artist name and total track count of the top 10 rock bands.
SELECT artist.artist_id,
	   artist.name,
       COUNT(track.track_id) AS num_of_songs
FROM artist
JOIN album ON album.artist_id = artist.artist_id
JOIN track ON track.album_id = album.album_id
WHERE genre_id 
	IN (SELECT genre_id 
	    FROM genre
	    WHERE name LIKE 'Rock')
GROUP BY artist.artist_id
ORDER BY num_of_songs DESC
LIMIT 10;


-- amount spent by each customer on artists.
WITH best_selling_artist AS 
	(SELECT artist.artist_id AS artist_id, 
		    artist.name AS artist_name, 
		    SUM(invoice_line.unit_price * invoice_line.quantity) AS total_spent
	 FROM invoice_line
	 JOIN track ON track.track_id = invoice_line.track_id
	 JOIN album ON album.album_id = track.album_id
	 JOIN artist ON artist.artist_id = album.artist_id
	 GROUP BY 1
	 ORDER BY 3 DESC)
SELECT c.customer_id AS customer_id, 
	   c.first_name AS name, 
	   bsa.artist_name AS artist_name, 
	   SUM(il.unit_price * il.quantity) AS total_spent
FROM invoice i
JOIN customer c ON c.customer_id = i.customer_id
JOIN invoice_line il ON il.invoice_id = i.invoice_id
JOIN track t ON t.track_id = il.track_id
JOIN album al ON al.album_id = t.album_id
JOIN best_selling_artist bsa ON bsa.artist_id = al.artist_id
GROUP BY 1, 2, 3
ORDER BY 4 DESC;


-- Who are the most popular artists?
SELECT COUNT(invoice_line.quantity) AS purchases,
       artist.name AS artist_name
FROM invoice_line 
JOIN track ON track.track_id = invoice_line.track_id
JOIN album ON album.album_id = track.album_id
JOIN artist ON artist.artist_id = album.artist_id
GROUP BY 2
ORDER BY 1 DESC;


--  Customer that has spent the most on music for each country.
WITH customer_with_country AS
	(SELECT customer.customer_id,
            first_name,
            last_name,
            billing_country,
            SUM(total) AS total_spent,
		    ROW_NUMBER() OVER(PARTITION BY billing_country ORDER BY SUM(total) DESC) AS row_num
	FROM invoice
	JOIN customer ON customer.customer_id = invoice.customer_id
	GROUP BY 1,2,3,4
	ORDER BY 4, 5 DESC)
SELECT customer_id, first_name, last_name, billing_country, total_spent
FROM customer_with_country
WHERE row_num = 1;









