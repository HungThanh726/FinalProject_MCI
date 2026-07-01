# 📊 SQL Business Analytics Library

![SQL Server](https://img.shields.io/badge/SQL%20Server-T--SQL-CC2927?style=flat&logo=microsoftsqlserver)
![Power BI](https://img.shields.io/badge/Power%20BI-Dashboard-F2C811?style=flat&logo=powerbi)
![Status](https://img.shields.io/badge/Status-Active-brightgreen?style=flat)

A multi-domain **Business Data Analytics** project using **T-SQL on SQL Server**, covering retail sales analysis, AdventureWorks product & customer analytics, and relational database design for a library management system. Designed to demonstrate end-to-end analyst skills: **data modeling → SQL analytics → BI reporting**.

---

## 🗂️ Repository Structure

```
sql-analytics-portfolio/
│
├── README.md                    ← This file
├── Master_TSQL.sql              ← All queries, clean & annotated
├── PowerBI_Guide.md             ← Dashboard setup instructions
│
└── modules/
    ├── 01_retail_orders.sql     ← Orders DB (hocsql)
    ├── 02_adventureworks.sql    ← Sales DB (LEARNSQL / AdventureWorks)
    └── 03_library_system.sql    ← LibraryManagement DB (DDL + analytics)
```

---

## 🧰 Tech Stack

| Layer              | Tool                                    |
|--------------------|-----------------------------------------|
| Database Engine    | SQL Server 2019+ (T-SQL)                |
| Query IDE          | SSMS (SQL Server Management Studio)     |
| BI / Visualization | Power BI Desktop                        |
| Version Control    | Git / GitHub                            |

---

## 📦 Modules

---

### Module 1 — Retail Orders Analysis
**Database:** `hocsql` &nbsp;|&nbsp; **Table:** `Orders`

Analyzes a retail orders dataset across regions, provinces, product subcategories, and customer segments. Focuses on profitability calculation and data filtering patterns.

**Business Questions:**
| # | Question |
|---|----------|
| BQ1 | What is the Total Cost, Total Revenue, and Net Profit by Region? |
| BQ2 | Which orders are non-Critical priority? |
| BQ3 | Which orders ship from provinces containing "New"? |
| BQ4 | Which non-Air shipment orders have value < 500? |
| BQ5 | Which subcategories start with "Co"? |
| BQ6 | Which corporate/consumer segments place orders > 10 units? |

**Key Techniques:**
- Derived columns: arithmetic expressions for cost/revenue/profit
- `WHERE` filtering: `IN`, `NOT IN`, `LIKE`, `NOT LIKE`, `AND` combinations
- Multi-condition row filtering across text and numeric columns

---

### Module 2 — AdventureWorks Sales Analytics
**Database:** `LEARNSQL` &nbsp;|&nbsp; **Tables:** `Sales_2015–2017`, `Products`, `Customers`, `Territories`, `Product_Subcategories`, `Product_Categories`

End-to-end sales analytics on a multi-year fact table (2015–2017). Covers revenue aggregation, product dimension analysis, customer segmentation, and above-average customer identification.

**Business Questions:**
| # | Question |
|---|----------|
| BQ1 | What is the monthly revenue trend across all years? (`MonthlySaleReport` view) |
| BQ2 | What is revenue by Product Color × Gender? |
| BQ3 | What is revenue by Product Color × Size × Category? |
| BQ4 | What is revenue by Product Color × Size × Category × Customer Demographics? |
| BQ5 | Which customers exceed the average revenue for their year? |
| BQ6 | What is revenue by Territory Region × Product Size? |
| BQ7 | What is the monthly order volume by Color × Category? |

**Key Techniques:**
- `UNION ALL` across 3 sales year-tables → consolidated `ALLSALES` view
- Multi-table `JOIN` chains (up to 5 tables)
- `CREATE VIEW` for reusable analytics layers
- Nested subqueries for benchmark (AVG) comparison
- `FORMAT()`, `YEAR()`, `SUM()`, `COUNT(DISTINCT)`, `AVG()`
- `ROW_NUMBER() OVER (PARTITION BY ...)` for ranking

---

### Module 3 — Library Management System
**Database:** `LibraryManagement` &nbsp;|&nbsp; **8 Tables**

Designs and implements a normalized relational database for a university library system, including borrow and sale transaction tracking, user role management, and book inventory.

**System Design:**

```
Roles ──────< Users >──────── Borrow_Transaction >──── Products
                │                                          │
                │              Sale_Transaction >──────────┤
                │                                          │
              Major ──────────────────────────────< Products
                                                        │
                                               Book_Category
                                               Book_Stock
```

**Analytics Deliverables:**
| # | View / Query |
|---|--------------|
| V1 | `ThongKeThueSachTheoThang` — Monthly borrow volume by book title |
| V2 | Top 2 most-borrowed book categories per month (ROW_NUMBER) |
| Q1 | Revenue + customer count by category & year for power users (>5 transactions) |

**Key Techniques:**
- `CREATE DATABASE`, `CREATE TABLE` with proper data types
- `ALTER TABLE ADD CONSTRAINT` — Primary Keys + Foreign Keys
- `ROW_NUMBER() OVER (PARTITION BY year, month ORDER BY volume DESC)`
- `JOIN` across transaction + dimension tables
- `FORMAT()` for period grouping

---

## 🔑 SQL Technique Coverage Matrix

| Technique                            | Mod 1 | Mod 2 | Mod 3 |
|--------------------------------------|:-----:|:-----:|:-----:|
| SELECT + WHERE filters               |  ✅   |  ✅   |  ✅   |
| Derived columns (arithmetic)         |  ✅   |  ✅   |       |
| IN / NOT IN / LIKE / NOT LIKE        |  ✅   |       |       |
| UNION ALL (multi-table stacking)     |       |  ✅   |       |
| Multi-table JOIN (3–5 tables)        |       |  ✅   |  ✅   |
| CREATE VIEW                          |       |  ✅   |  ✅   |
| Nested Subquery (inline benchmark)   |       |  ✅   |       |
| AVG comparison filter                |       |  ✅   |       |
| Window Function: ROW_NUMBER()        |       |       |  ✅   |
| DDL: CREATE TABLE, ALTER TABLE       |       |       |  ✅   |
| PK / FK Constraint design            |       |       |  ✅   |
| FORMAT() / YEAR() for time grouping  |       |  ✅   |  ✅   |

---

## 🚀 How to Run

### Prerequisites
- SQL Server 2019+ (or SQL Server Express — free)
- SSMS (SQL Server Management Studio)

### Steps

```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/sql-analytics-portfolio.git
cd sql-analytics-portfolio
```

1. Open **SSMS** → connect to your local instance
2. Open `Master_TSQL.sql`
3. Run **Section by section** — each section targets a different database:
   - `USE hocsql` → Module 1
   - `USE LEARNSQL` → Module 2
   - Module 3 starts with `CREATE DATABASE LibraryManagement`
4. Connect **Power BI Desktop** → see `PowerBI_Guide.md`

> ⚠️ Note: The `hocsql` and `LEARNSQL` databases must already exist on your SQL Server instance with the source data loaded. These are standard training databases (Orders dataset, AdventureWorks).

---

## 📈 Key Insights

- **Net Profit leader:** West, Ontario, and Nunavut regions have the highest combined revenue after margin and shipping cost deductions
- **Revenue peak:** Monthly report (`MonthlySaleReport`) shows Q4 spikes across all AdventureWorks sales years
- **High-value customers:** Customers who exceed their year's average revenue represent a minority but disproportionate revenue share — prime loyalty program targets
- **Product mix:** Larger product sizes (L, XL) drive higher total revenue in most territory regions
- **Library:** Borrow volume by title reveals which books need more stock during semester months

---

## 📂 File Guide

| File | Description |
|------|-------------|
| `README.md` | Project overview, module breakdown, setup guide |
| `Master_TSQL.sql` | All queries consolidated, annotated, error-free |
| `PowerBI_Guide.md` | Step-by-step Power BI dashboard setup with DAX measures |

---

## 👤 Author

**[Your Name]**
Business Data Analyst

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-0077B5?style=flat&logo=linkedin)](https://linkedin.com/in/YOUR_PROFILE)
[![GitHub](https://img.shields.io/badge/GitHub-Follow-181717?style=flat&logo=github)](https://github.com/YOUR_USERNAME)

📧 your.email@gmail.com

---

## 📜 License

MIT License — free to use for learning and portfolio reference.
