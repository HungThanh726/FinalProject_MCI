# 📚 Library Borrow Management — T-SQL Database Design & Analytics

![SQL Server](https://img.shields.io/badge/SQL%20Server-T--SQL-CC2927?style=flat&logo=microsoftsqlserver)
![Power BI](https://img.shields.io/badge/Power%20BI-Dashboard-F2C811?style=flat&logo=powerbi)

Bài tập thiết kế cơ sở dữ liệu quản lý **cho thuê sách thư viện trường học**. Vì Project cuối khoá không có dataset, toàn bộ dữ liệu (40 người dùng, 30 đầu sách, 289 lượt mượn trong 4 tháng) được **tự sinh** để mô phỏng hoạt động thực tế của thư viện, đủ điều kiện kiểm thử các yêu cầu phân tích đặt ra.

---

## 🗂️ Cấu trúc Repository

```
library-borrow-management/
├── README.md                    ← File này
├── Library_Master_TSQL.sql      ← Toàn bộ schema + data + 6 câu hỏi
├── PowerBI_Guide_Library.md     ← Hướng dẫn dựng dashboard Power BI
├── Library_ERD.png              ← Sơ đồ ERD (ảnh tĩnh, dùng cho Word/PPT)
└── Library_ERD.svg              ← Sơ đồ ERD (vector, chất lượng cao)
```

---

## 🎯 6 Câu hỏi bài tập & cách giải quyết

| # | Yêu cầu | Vị trí trong file SQL | Kỹ thuật |
|---|---------|------------------------|----------|
| 1 | Tự tạo dữ liệu, tạo PK/FK | PHẦN 0–2 | `CREATE TABLE`, `INSERT`, ràng buộc khóa |
| 2 | Xác định PK/FK, lý do cần các bảng, quy trình nhập liệu | PHẦN 1 (comment) | Thiết kế CSDL quan hệ |
| 3 | View thống kê thuê sách theo ngành học/tháng + Top 2 | PHẦN 3 | `CREATE VIEW`, `ROW_NUMBER() OVER (PARTITION BY ...)` |
| 4 | SubQuery — sách có >5 người mượn/tháng | PHẦN 4 | Subquery trong `FROM` |
| 5 | CTE — sách có >5 người mượn/tháng (lặp lại câu 4) | PHẦN 5 | `WITH ... AS (...)` |
| 6 | CTE — người dùng mượn >10 lần | PHẦN 6 | `WITH ... AS (...)` + `JOIN` |

---

## 🧱 Câu 1 & 2 — Thiết kế bảng

### Sơ đồ quan hệ ERD (khóa chính / khóa ngoại)

![Library ERD](./Library_ERD.png)

> File ảnh tĩnh: `Library_ERD.png` / `Library_ERD.svg` — dùng để chèn vào Word, PowerPoint, hoặc báo cáo (không phụ thuộc engine render của GitHub).
> Bản Mermaid bên dưới cũng tự render trực tiếp khi xem README trên GitHub web.

```mermaid
erDiagram
  ROLES ||--o{ USERS : "phan loai"
  MAJOR ||--o{ PRODUCTS : "thuoc nganh"
  BOOK_CATEGORY ||--o{ PRODUCTS : "thuoc the loai"
  PRODUCTS ||--|| BOOK_STOCK : "ton kho"
  USERS ||--o{ BORROW_TRANSACTION : "muon sach"
  PRODUCTS ||--o{ BORROW_TRANSACTION : "duoc muon"

  ROLES {
    int Position_id PK
    string Position_name
    string Role
    int Semester_limited
  }
  MAJOR {
    int Major_ID PK
    string Major_Name
  }
  BOOK_CATEGORY {
    int Category_ID PK
    string Category_Name
  }
  USERS {
    int Users_id PK
    string Full_name
    string Gender
    string Email
    string Phone_number
    int Position_id FK
    int Remaining_limited
  }
  PRODUCTS {
    int Product_ID PK
    string Product_Name
    string Author
    int Unit_Price
    int Category_ID FK
    int Major_ID FK
  }
  BOOK_STOCK {
    int Product_ID PK_FK
    int Inventory_Number
  }
  BORROW_TRANSACTION {
    int Order_ID PK
    int Users_id FK
    int Product_ID FK
    date Start_date
    date End_date
    int Quantity
  }
```

### Sơ đồ tóm tắt (dạng text, đọc nhanh)

```
Roles ──────< Users >──────── Borrow_Transaction >──── Products >──── Major
                                                            │
                                                       Book_Category
                                                            │
                                                       Book_Stock
```

### Danh sách bảng & lý do tồn tại

| Bảng | Vai trò | Tại sao cần |
|------|---------|-------------|
| **Roles** | Vai trò người mượn (SV/GV/Nhân viên) | Mỗi nhóm có giới hạn mượn (`Semester_limited`) khác nhau — tách riêng để dễ đổi chính sách mà không sửa bảng Users |
| **Major** | Ngành học | Phục vụ trực tiếp yêu cầu "thống kê theo phân ngành trường học" |
| **Book_Category** | Thể loại sách | Phân loại độc lập với ngành học — 1 ngành có thể có nhiều thể loại sách khác nhau |
| **Users** | Người mượn sách | Bảng chiều (dimension) lưu thông tin định danh |
| **Products** | Đầu sách | Bảng chiều trung tâm, liên kết Ngành học + Thể loại |
| **Book_Stock** | Tồn kho | Tách riêng khỏi Products vì tồn kho thay đổi liên tục (mỗi lượt mượn/trả), tránh "khóa" cả bảng mô tả sách |
| **Borrow_Transaction** | Giao dịch mượn sách | Bảng giao dịch (fact table) — trung tâm cho mọi báo cáo thống kê |

### Khóa chính / khóa ngoại

| Bảng | PK | FK |
|------|----|----|
| Roles | `Position_id` | — |
| Major | `Major_ID` | — |
| Book_Category | `Category_ID` | — |
| Users | `Users_id` | `Position_id` → Roles |
| Products | `Product_ID` | `Category_ID` → Book_Category, `Major_ID` → Major |
| Book_Stock | `Product_ID` | `Product_ID` → Products |
| Borrow_Transaction | `Order_ID` | `Users_id` → Users, `Product_ID` → Products |

### Quy trình nhập liệu & quản lý

1. **Thêm sách mới**: `INSERT` vào `Products` → sau đó `INSERT` dòng tương ứng vào `Book_Stock` (tồn kho ban đầu).
2. **Thêm người dùng mới**: `INSERT` vào `Users` — bắt buộc `Position_id` phải tồn tại trong `Roles` (đảm bảo bởi FK).
3. **Phát sinh mượn sách**: `INSERT` vào `Borrow_Transaction`; đồng thời cần `UPDATE` giảm `Book_Stock.Inventory_Number` và giảm `Users.Remaining_limited`.
4. **Trả sách**: `UPDATE Borrow_Transaction.End_date`, đồng thời `UPDATE` tăng lại tồn kho.
5. **Toàn vẹn dữ liệu**: ràng buộc FK ngăn việc mượn sách không tồn tại, hoặc gán người dùng vào vai trò không có thật.

---

## 📊 Dữ liệu mẫu (tự sinh)

| Đối tượng | Số lượng |
|-----------|----------|
| Ngành học | 5 (CNTT, Kinh Tế, Ngôn Ngữ Anh, Y Dược, Luật) |
| Thể loại sách | 5 |
| Đầu sách | 30 (6 sách/ngành) |
| Người dùng | 40 (SV/GV/Nhân viên) |
| Giao dịch mượn | 289 (trải từ 01/2025 → 04/2025) |

> Dữ liệu được sinh có chủ đích để đảm bảo tồn tại: một số đầu sách có **>5 người mượn riêng biệt/tháng** (phục vụ câu 4–5), và một số người dùng có **tổng số lần mượn >10** (phục vụ câu 6).

---

## 🚀 Cách chạy

1. Mở **SSMS** (SQL Server Management Studio)
2. Chạy file `Library_Master_TSQL.sql` **từ trên xuống dưới** — file tự tạo database `LibraryManagement`, tự xóa bảng cũ nếu có (cho phép chạy lại nhiều lần)
3. Mỗi PHẦN trong file tương ứng với 1 câu hỏi — có thể chạy riêng từng phần sau khi đã chạy PHẦN 0–2 (schema + data)

---

## 📈 Kết quả phân tích chính (ví dụ)

- **Top 2 ngành học mượn nhiều nhất mỗi tháng**: thay đổi theo tháng — phản ánh nhu cầu học tập theo môn/kỳ thi
- **Sách "hot" (>5 người mượn/tháng)**: thường là giáo trình cốt lõi của từng ngành (vd. "Cơ Sở Dữ Liệu" cho CNTT)
- **Người dùng mượn nhiều (>10 lần)**: nhóm này là đối tượng ưu tiên cho chương trình "thẻ thư viện VIP" hoặc gia hạn mượn dài hơn

---

## 👤 Tác giả

**[Tên bạn]** — Business Data Analyst
📧 your.email@gmail.com

---

## 📜 License

MIT License — sử dụng tự do cho mục đích học tập.
