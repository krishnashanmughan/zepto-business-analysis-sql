# Zepto Quick-Commerce Business Analysis (SQL)

A SQL analytics project exploring quick-commerce operations across customer
behavior, product performance, transactions, and delivery efficiency — built
on a 6-table relational schema.

> **Note:** Built on a synthetic practice dataset (~15K rows per table). The
> focus is SQL and analytical technique, not real-world business findings.

## Skills Demonstrated
- **Joins & aggregation** across a 6-table schema (customers, orders,
  products, transactions, ratings, delivery).
- **Window functions:** `LEAD`/`LAG` for inter-order gaps and month-over-month
  sales growth.
- **CTEs** for multi-step analytical queries.
- **Business KPIs:** retention rate, repeat-purchase %, revenue by
  city/brand/category, payment success rate, delivery-partner load.

## Data Model
A relational schema linking orders to customers, products, transactions,
ratings, and delivery partners.

![Data Model](Zepto_Data_Model.png)

## Repository Structure
