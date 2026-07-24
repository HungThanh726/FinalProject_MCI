/*
LIBRARY ANALYTICS PROJECT — MASTER T-SQL
  Database : LibraryDB
================================================================================
  MỤC LỤC:
    PHẦN 1 — Import hướng dẫn & Schema mapping
    PHẦN 2 — Doanh thu cho thuê theo tháng × danh mục         (BQ1 — VIEW)
    PHẦN 3 — Doanh thu bán sách theo tháng × danh mục         (BQ2)
    PHẦN 4 — Top 2 danh mục thuê nhiều nhất/tháng             (BQ3 — ROW_NUMBER)
    PHẦN 5 — Sách có >5 người thuê riêng biệt/tháng           (BQ4 — Subquery)
    PHẦN 6 — Sách có >5 người thuê riêng biệt/tháng           (BQ5 — CTE)
    PHẦN 7 — Sinh viên thuê sách >10 lần                      (BQ6 — CTE)
    PHẦN 8 — Tồn kho trung bình theo kệ sách × danh mục       (BQ7)
================================================================================
  LƯU Ý VỀ NGÀY THÁNG:
    Rent_Date (Rental_Transaction) → kiểu DATE chuẩn, dùng trực tiếp được
    Order_Date (Sale_Transaction)  → Excel serial number (VD: 42743)
    In_Date (SerInv_Transaction)   → Excel serial number
    Công thức convert:
      CAST(DATEADD(day, CAST(Order_Date AS INT), '1899-12-30') AS DATE)
================================================================================
*/

USE LibraryDB
GO


/*
================================================================================
  PHẦN 1 — SCHEMA MAPPING (CSV → SQL Server Table)
================================================================================
  Chạy Import Flat File trong SSMS cho từng file CSV.

  CSV File                  → Table Name           Key Columns
  ─────────────────────────────────────────────────────────────
  Student.csv               → Student              Library_Card_Number PK
  Teacher.csv               → Teacher              Library_Card_Number PK
  Category.csv              → Category             Category_ID PK
  Shelves.csv               → Shelves              Shelves_ID PK, Category_ID FK
  Products.csv              → Products             Product_id PK, Category_ID FK, Shelves_ID FK
  RoleId.csv                → RoleId               RoleId PK
  Service.csv               → Service              Service_ID PK
  Classes.csv               → Classes              Class_Code PK
  Rental_Transaction.csv    → Rental_Transaction   Rent_Number PK, Product_ID FK
  Sale_Transaction.csv      → Sale_Transaction     Order_Number PK, Product_ID FK
  SerInv_Transaction_.csv   → SerInv_Transaction   Product_ID FK, Shelves_ID FK

  Quan hệ giữa các bảng:
    Rental_Transaction.Product_ID        → Products.Product_id
    Rental_Transaction.Library_Card_Number → Student.Library_Card_Number
    Sale_Transaction.Product_ID          → Products.Product_id
    SerInv_Transaction.Product_ID        → Products.Product_id
    SerInv_Transaction.Shelves_ID        → Shelves.Shelves_ID
    Products.Category_ID                 → Category.Category_ID
    Products.Shelves_ID                  → Shelves.Shelves_ID
    Shelves.Category_ID                  → Category.Category_ID
================================================================================
*/


/*
================================================================================
  PHẦN 2 — BQ1: VIEW DOANH THU CHO THUÊ THEO THÁNG × DANH MỤC
================================================================================
  Rental Revenue = Order_Quantity × Product_UnitRental
  Rent_Date đã là kiểu DATE → dùng FORMAT() trực tiếp
================================================================================
*/

CREATE VIEW v_DoanhThuThueThang AS
SELECT
    FORMAT(CAST(rt.Rent_Date AS DATE), 'MM/yyyy')    AS ThangNam,
    cat.Category_Name                                 AS DanhMuc,
    sh.Shelf_Location                                 AS ViTriKe,
    SUM(rt.Order_Quantity)                            AS TongLuotThue,
    SUM(rt.Order_Quantity * p.Product_UnitRental)     AS DoanhThuThue
FROM Rental_Transaction AS rt
JOIN Products  AS p   ON p.Product_id    = rt.Product_ID
JOIN Category  AS cat ON cat.Category_ID = p.Category_ID
JOIN Shelves   AS sh  ON sh.Shelves_ID   = p.Shelves_ID
GROUP BY
    FORMAT(CAST(rt.Rent_Date AS DATE), 'MM/yyyy'),
    cat.Category_Name,
    sh.Shelf_Location;
GO

-- Gọi kết quả
SELECT * FROM v_DoanhThuThueThang ORDER BY ThangNam, DoanhThuThue DESC;


/*
================================================================================
  PHẦN 3 — BQ2: DOANH THU BÁN SÁCH THEO THÁNG × DANH MỤC
================================================================================
  Order_Date lưu dạng Excel serial number → dùng DATEADD để convert
  Sale Revenue = Order_Quantity × Product_UnitPrice
================================================================================
*/

SELECT
    FORMAT(
        CAST(DATEADD(day, CAST(st.Order_Date AS INT), '1899-12-30') AS DATE),
        'MM/yyyy'
    )                                                 AS ThangNam,
    cat.Category_Name                                 AS DanhMuc,
    SUM(st.Order_Quantity)                            AS TongLuotBan,
    SUM(st.Order_Quantity * p.Product_UnitPrice)      AS DoanhThuBan
FROM Sale_Transaction AS st
JOIN Products  AS p   ON p.Product_id    = st.Product_ID
JOIN Category  AS cat ON cat.Category_ID = p.Category_ID
GROUP BY
    FORMAT(
        CAST(DATEADD(day, CAST(st.Order_Date AS INT), '1899-12-30') AS DATE),
        'MM/yyyy'
    ),
    cat.Category_Name
ORDER BY ThangNam, DoanhThuBan DESC;


/*
================================================================================
  PHẦN 4 — BQ3: TOP 2 DANH MỤC ĐƯỢC THUÊ NHIỀU NHẤT TỪNG THÁNG
================================================================================
  Dùng ROW_NUMBER() OVER (PARTITION BY ThangNam) để xếp hạng lại từ đầu
  mỗi tháng, sau đó lọc WHERE Hang <= 2.
  Nguồn: view v_DoanhThuThueThang đã tạo ở PHẦN 2.
================================================================================
*/

SELECT
    DanhMuc,
    ThangNam,
    TongLuotThue,
    DoanhThuThue,
    Hang
FROM (
    SELECT
        DanhMuc,
        ThangNam,
        TongLuotThue,
        DoanhThuThue,
        ROW_NUMBER() OVER (
            PARTITION BY ThangNam          -- xếp hạng lại từ 1 mỗi tháng
            ORDER BY TongLuotThue DESC
        ) AS Hang
    FROM v_DoanhThuThueThang
) AS Ranked
WHERE Hang <= 2
ORDER BY ThangNam, Hang;


/*
================================================================================
  PHẦN 5 — BQ4: SUBQUERY — SÁCH CÓ >5 NGƯỜI THUÊ RIÊNG BIỆT TRONG THÁNG
================================================================================
  COUNT(DISTINCT Library_Card_Number) tính số người thuê riêng biệt.
  Không thể lọc aggregate trực tiếp trong WHERE → dùng subquery trong FROM,
  sau đó WHERE ở câu SELECT ngoài.
================================================================================
*/

SELECT
    sq.Product_Name,
    sq.ThangNam,
    sq.SoNguoiThue
FROM (
    -- Subquery: đếm số người thuê riêng biệt theo sách × tháng
    SELECT
        p.Product_Name,
        FORMAT(CAST(rt.Rent_Date AS DATE), 'MM/yyyy')  AS ThangNam,
        COUNT(DISTINCT rt.Library_Card_Number)           AS SoNguoiThue
    FROM Rental_Transaction AS rt
    JOIN Products AS p ON p.Product_id = rt.Product_ID
    GROUP BY
        p.Product_Name,
        FORMAT(CAST(rt.Rent_Date AS DATE), 'MM/yyyy')
) AS sq
WHERE sq.SoNguoiThue > 5
ORDER BY sq.ThangNam, sq.SoNguoiThue DESC;


/*
================================================================================
  PHẦN 6 — BQ5: CTE — SÁCH CÓ >5 NGƯỜI THUÊ RIÊNG BIỆT TRONG THÁNG
================================================================================
*/

WITH cte_SoNguoiThueTheoSach AS (
    SELECT
        p.Product_Name,
        FORMAT(CAST(rt.Rent_Date AS DATE), 'MM/yyyy')  AS ThangNam,
        COUNT(DISTINCT rt.Library_Card_Number)           AS SoNguoiThue
    FROM Rental_Transaction AS rt
    JOIN Products AS p ON p.Product_id = rt.Product_ID
    GROUP BY
        p.Product_Name,
        FORMAT(CAST(rt.Rent_Date AS DATE), 'MM/yyyy')
)
SELECT
    Product_Name,
    ThangNam,
    SoNguoiThue
FROM cte_SoNguoiThueTheoSach
WHERE SoNguoiThue > 5
ORDER BY ThangNam, SoNguoiThue DESC;


/*
================================================================================
  PHẦN 7 — BQ6: CTE — SINH VIÊN THUÊ SÁCH HƠN 10 LẦN
================================================================================
  CTE tính tổng số lần thuê (số giao dịch) và tổng số sách thuê
  cho mỗi thẻ thư viện, sau đó JOIN Student để lấy thông tin người dùng.
  Chú ý: Library_Card_Number trong Rental_Transaction chỉ khớp với
  bảng Student (STC01...), không khớp với Teacher (TC01...).
================================================================================
*/

WITH cte_TongLanThue AS (
    SELECT
        rt.Library_Card_Number,
        COUNT(rt.Rent_Number)    AS SoLanThue,     -- số giao dịch thuê
        SUM(rt.Order_Quantity)   AS TongSachThue   -- tổng số lượt sách
    FROM Rental_Transaction AS rt
    GROUP BY rt.Library_Card_Number
)
SELECT
    stu.Full_name,
    stu.Gender,
    stu.Class,
    t.SoLanThue,
    t.TongSachThue
FROM cte_TongLanThue AS t
JOIN Student AS stu
    ON stu.Library_Card_Number = t.Library_Card_Number
WHERE t.SoLanThue > 10
ORDER BY t.SoLanThue DESC;


/*
================================================================================
  PHẦN 8 — BQ7: TỒN KHO TRUNG BÌNH THEO KỆ SÁCH × DANH MỤC
================================================================================
  SerInv_Transaction lưu lịch sử tồn kho cuối ngày (DayEnd_Stock_Pcs)
  theo từng kệ sách và đầu sách.
  In_Date cũng là Excel serial → convert nếu cần lọc theo kỳ thời gian.
================================================================================
*/

SELECT
    sh.Shelves_ID,
    sh.Shelf_Description,
    sh.Shelf_Location,
    cat.Category_Name,
    COUNT(DISTINCT inv.Product_ID)     AS SoDauSach,
    AVG(inv.DayEnd_Stock_Pcs)          AS TonKhoBinhQuan,
    MIN(inv.DayEnd_Stock_Pcs)          AS TonKhoThapNhat,
    MAX(inv.DayEnd_Stock_Pcs)          AS TonKhoCaoNhat
FROM SerInv_Transaction AS inv
JOIN Shelves   AS sh  ON sh.Shelves_ID   = inv.Shelves_ID
JOIN Category  AS cat ON cat.Category_ID = sh.Category_ID
GROUP BY
    sh.Shelves_ID,
    sh.Shelf_Description,
    sh.Shelf_Location,
    cat.Category_Name
ORDER BY TonKhoBinhQuan ASC;   -- kệ có tồn kho thấp nhất hiển thị đầu

