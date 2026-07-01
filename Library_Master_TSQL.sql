/*
================================================================================
  T-SQL — QUẢN LÝ CHO THUÊ SÁCH THƯ VIỆN TRƯỜNG HỌC (LIBRARY MANAGEMENT)
  Tác giả  : [Tên bạn]
  Database : LibraryManagement
  Mô tả    : File tự sinh dữ liệu mẫu (không có dataset gốc) — phục vụ 6 câu hỏi
             bài tập: thiết kế bảng, PK/FK, View thống kê theo ngành học,
             SubQuery, và CTE (2 dạng).
================================================================================
  MỤC LỤC:
    PHẦN 0 — Tạo Database & Bảng (Câu 1)
    PHẦN 1 — Khóa chính / Khóa ngoại (Câu 2)
    PHẦN 2 — Dữ liệu mẫu tự tạo (Câu 1)
    PHẦN 3 — View thống kê thuê sách theo Ngành học + Top 2/tháng (Câu 3)
    PHẦN 4 — SubQuery: sách có >5 người thuê mỗi tháng (Câu 4)
    PHẦN 5 — CTE: sách có >5 người thuê mỗi tháng (Câu 5)
    PHẦN 6 — CTE: người dùng thuê sách >10 lần (Câu 6)
================================================================================
*/


/*
================================================================================
  PHẦN 0 — TẠO DATABASE & BẢNG (Câu 1)
================================================================================
  Lý do thiết kế các bảng:
  - Roles            : phân loại đối tượng mượn sách (Sinh viên / Giảng viên /
                        Nhân viên) để áp giới hạn mượn theo từng nhóm.
  - Major             : ngành học — phục vụ thống kê "theo phân ngành trường học".
  - Book_Category     : phân loại sách theo chủ đề (tách biệt với Ngành học,
                        vì 1 ngành có thể có nhiều thể loại sách).
  - Products          : danh mục đầu sách, liên kết tới Ngành học & Thể loại.
  - Book_Stock        : số lượng tồn kho từng đầu sách — kiểm soát còn hàng.
  - Users             : thông tin người mượn, liên kết tới Roles.
  - Borrow_Transaction: giao dịch mượn sách — bảng trung tâm để thống kê.
================================================================================
*/

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'LibraryManagement')
    CREATE DATABASE LibraryManagement;
GO

USE LibraryManagement;
GO

-- Xóa bảng cũ nếu tồn tại (cho phép chạy lại script nhiều lần)
IF OBJECT_ID('Borrow_Transaction','U') IS NOT NULL DROP TABLE Borrow_Transaction;
IF OBJECT_ID('Book_Stock','U') IS NOT NULL DROP TABLE Book_Stock;
IF OBJECT_ID('Products','U') IS NOT NULL DROP TABLE Products;
IF OBJECT_ID('Users','U') IS NOT NULL DROP TABLE Users;
IF OBJECT_ID('Roles','U') IS NOT NULL DROP TABLE Roles;
IF OBJECT_ID('Book_Category','U') IS NOT NULL DROP TABLE Book_Category;
IF OBJECT_ID('Major','U') IS NOT NULL DROP TABLE Major;
GO

-- Bảng Roles: vai trò người mượn
CREATE TABLE Roles (
    Position_id      INT           NOT NULL,
    Position_name    VARCHAR(100)  NOT NULL,
    Role             VARCHAR(50),
    Semester_limited INT                          -- số sách tối đa được mượn/kỳ
);

-- Bảng Major: ngành học
CREATE TABLE Major (
    Major_ID    INT           NOT NULL,
    Major_Name  VARCHAR(100)  NOT NULL
);

-- Bảng Book_Category: thể loại sách
CREATE TABLE Book_Category (
    Category_ID   INT           NOT NULL,
    Category_Name VARCHAR(100)  NOT NULL
);

-- Bảng Users: người dùng (mượn sách)
CREATE TABLE Users (
    Users_id          INT           NOT NULL,
    Full_name         VARCHAR(255)  NOT NULL,
    Gender            VARCHAR(5)    NOT NULL,
    Email             VARCHAR(255),
    Phone_number      CHAR(11),
    Position_id       INT           NOT NULL,     -- FK -> Roles
    Remaining_limited INT
);

-- Bảng Products: đầu sách
CREATE TABLE Products (
    Product_ID    INT           NOT NULL,
    Product_Name  VARCHAR(255)  NOT NULL,
    Author        VARCHAR(100),
    Unit_Price    INT,
    Category_ID   INT           NOT NULL,         -- FK -> Book_Category
    Major_ID      INT           NOT NULL          -- FK -> Major
);

-- Bảng Book_Stock: tồn kho
CREATE TABLE Book_Stock (
    Product_ID        INT  NOT NULL,               -- FK -> Products
    Inventory_Number  INT
);

-- Bảng Borrow_Transaction: giao dịch mượn sách
CREATE TABLE Borrow_Transaction (
    Order_ID    INT   NOT NULL,
    Users_id    INT   NOT NULL,                    -- FK -> Users
    Product_ID  INT   NOT NULL,                    -- FK -> Products
    Start_date  DATE  NOT NULL,
    End_date    DATE,
    Quantity    INT
);
GO


/*
================================================================================
  PHẦN 1 — KHÓA CHÍNH / KHÓA NGOẠI (Câu 2)
================================================================================
  Trả lời câu hỏi "Để quản lý cho thuê sách cần các bảng nào?":

  1. Roles  → vì mỗi nhóm người dùng (SV/GV/NV) có quyền mượn và giới hạn
              số sách khác nhau; tách riêng để dễ thay đổi chính sách mượn
              mà không sửa bảng Users.
  2. Major  → để thống kê nhu cầu mượn sách theo ngành học (yêu cầu đề bài),
              và để gợi ý sách phù hợp chuyên ngành cho sinh viên.
  3. Book_Category → phân loại sách độc lập với ngành học, hỗ trợ tìm kiếm
              và báo cáo theo chủ đề.
  4. Users  → lưu thông tin người mượn, là một chiều (dimension) chính.
  5. Products → danh mục đầu sách — chiều (dimension) trung tâm.
  6. Book_Stock → tách riêng để theo dõi tồn kho real-time mà không làm
              "phình" bảng Products (cập nhật tồn kho thường xuyên hơn
              thông tin mô tả sách).
  7. Borrow_Transaction → bảng giao dịch (fact table), mỗi dòng = 1 lần mượn.
              Tách riêng theo nguyên tắc chuẩn hóa: 1 user có thể mượn
              nhiều sách, 1 sách có thể được nhiều user mượn (N-N qua
              bảng trung gian giao dịch).

  Thao tác nhập liệu & quản lý:
  - Khi có sách mới        → INSERT vào Products, sau đó INSERT Book_Stock.
  - Khi có người dùng mới  → INSERT vào Users (phải có Position_id hợp lệ
                              tồn tại trong Roles — đảm bảo bởi FK).
  - Khi phát sinh mượn sách→ INSERT vào Borrow_Transaction; đồng thời
                              UPDATE giảm Book_Stock.Inventory_Number và
                              giảm Users.Remaining_limited.
  - Khi trả sách           → UPDATE Borrow_Transaction.End_date, và
                              UPDATE tăng lại Book_Stock.Inventory_Number.
  - Ràng buộc FK đảm bảo không thể mượn sách/Product_ID không tồn tại,
    hoặc gán user vào Role không tồn tại → toàn vẹn dữ liệu (data integrity).
================================================================================
*/

ALTER TABLE Roles
    ADD CONSTRAINT PK_Roles PRIMARY KEY (Position_id);

ALTER TABLE Major
    ADD CONSTRAINT PK_Major PRIMARY KEY (Major_ID);

ALTER TABLE Book_Category
    ADD CONSTRAINT PK_Book_Category PRIMARY KEY (Category_ID);

ALTER TABLE Users
    ADD CONSTRAINT PK_Users PRIMARY KEY (Users_id);

ALTER TABLE Products
    ADD CONSTRAINT PK_Products PRIMARY KEY (Product_ID);

ALTER TABLE Book_Stock
    ADD CONSTRAINT PK_Book_Stock PRIMARY KEY (Product_ID);

ALTER TABLE Borrow_Transaction
    ADD CONSTRAINT PK_Borrow_Transaction PRIMARY KEY (Order_ID);
GO

-- Khóa ngoại
ALTER TABLE Users
    ADD CONSTRAINT FK_Users_Roles
    FOREIGN KEY (Position_id) REFERENCES Roles (Position_id);

ALTER TABLE Products
    ADD CONSTRAINT FK_Products_Category
    FOREIGN KEY (Category_ID) REFERENCES Book_Category (Category_ID);

ALTER TABLE Products
    ADD CONSTRAINT FK_Products_Major
    FOREIGN KEY (Major_ID) REFERENCES Major (Major_ID);

ALTER TABLE Book_Stock
    ADD CONSTRAINT FK_BookStock_Products
    FOREIGN KEY (Product_ID) REFERENCES Products (Product_ID);

ALTER TABLE Borrow_Transaction
    ADD CONSTRAINT FK_Borrow_Users
    FOREIGN KEY (Users_id) REFERENCES Users (Users_id);

ALTER TABLE Borrow_Transaction
    ADD CONSTRAINT FK_Borrow_Products
    FOREIGN KEY (Product_ID) REFERENCES Products (Product_ID);
GO


/*
================================================================================
  PHẦN 2 — DỮ LIỆU MẪU TỰ TẠO (Câu 1)
================================================================================
  Không có dataset gốc nên dữ liệu được tự sinh:
  - 5 Ngành học, 5 Thể loại sách, 30 đầu sách (6 sách/ngành)
  - 40 người dùng (SV/GV/Nhân viên)
  - 289 giao dịch mượn sách trải từ 01/2025 - 04/2025
  - Dữ liệu được sinh có chủ đích để đảm bảo có:
      • Một số đầu sách có > 5 người mượn riêng biệt trong cùng 1 tháng
      • Một số người dùng có tổng số lần mượn > 10
================================================================================
*/

INSERT INTO Major (Major_ID, Major_Name) VALUES (1, N'Cong Nghe Thong Tin');
INSERT INTO Major (Major_ID, Major_Name) VALUES (2, N'Kinh Te');
INSERT INTO Major (Major_ID, Major_Name) VALUES (3, N'Ngon Ngu Anh');
INSERT INTO Major (Major_ID, Major_Name) VALUES (4, N'Y Duoc');
INSERT INTO Major (Major_ID, Major_Name) VALUES (5, N'Luat');

INSERT INTO Book_Category (Category_ID, Category_Name) VALUES (1, N'Sach Chuyen Nganh CNTT');
INSERT INTO Book_Category (Category_ID, Category_Name) VALUES (2, N'Sach Kinh Te - Tai Chinh');
INSERT INTO Book_Category (Category_ID, Category_Name) VALUES (3, N'Sach Ngoai Ngu');
INSERT INTO Book_Category (Category_ID, Category_Name) VALUES (4, N'Sach Y Khoa');
INSERT INTO Book_Category (Category_ID, Category_Name) VALUES (5, N'Sach Luat - Phap Ly');

INSERT INTO Roles (Position_id, Position_name, Role, Semester_limited) VALUES (1, N'Sinh Vien', N'Borrower', 4);
INSERT INTO Roles (Position_id, Position_name, Role, Semester_limited) VALUES (2, N'Giang Vien', N'Borrower', 10);
INSERT INTO Roles (Position_id, Position_name, Role, Semester_limited) VALUES (3, N'Nhan Vien Thu Vien', N'Staff', 0);

INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (1, N'Do Van Khoa', N'Nam', N'user1@university.edu.vn', '0958966946', 1, 2);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (2, N'Pham Thi Khoa', N'Nu', N'user2@university.edu.vn', '0996977837', 1, 1);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (3, N'Le Van Uyen', N'Nam', N'user3@university.edu.vn', '0931931511', 1, 7);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (4, N'Dang Thi Hoa', N'Nu', N'user4@university.edu.vn', '0917507864', 1, 3);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (5, N'Vu Van Oanh', N'Nam', N'user5@university.edu.vn', '0938317637', 1, 9);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (6, N'Vu Van Giang', N'Nam', N'user6@university.edu.vn', '0963100814', 1, 10);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (7, N'Hoang Thi Em', N'Nu', N'user7@university.edu.vn', '0985345555', 1, 8);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (8, N'Ngo Thi Phuc', N'Nu', N'user8@university.edu.vn', '0963606628', 2, 5);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (9, N'Le Thi Tam', N'Nu', N'user9@university.edu.vn', '0916323852', 1, 1);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (10, N'Le Thi Phuc', N'Nu', N'user10@university.edu.vn', '0961642594', 1, 6);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (11, N'Bui Van Tam', N'Nam', N'user11@university.edu.vn', '0984252722', 1, 0);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (12, N'Tran Van Uyen', N'Nam', N'user12@university.edu.vn', '0996028436', 1, 5);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (13, N'Do Thi Phong', N'Nu', N'user13@university.edu.vn', '0945351479', 1, 8);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (14, N'Dang Van Dung', N'Nam', N'user14@university.edu.vn', '0950056581', 2, 10);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (15, N'Pham Van Em', N'Nam', N'user15@university.edu.vn', '0931682744', 1, 8);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (16, N'Dang Van Anh', N'Nam', N'user16@university.edu.vn', '0975579548', 1, 0);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (17, N'Vu Thi Linh', N'Nu', N'user17@university.edu.vn', '0942329237', 1, 9);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (18, N'Tran Van Son', N'Nam', N'user18@university.edu.vn', '0981498611', 2, 2);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (19, N'Bui Thi Uyen', N'Nu', N'user19@university.edu.vn', '0980823176', 1, 9);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (20, N'Pham Thi Uyen', N'Nu', N'user20@university.edu.vn', '0936998038', 1, 4);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (21, N'Vu Thi Quyen', N'Nu', N'user21@university.edu.vn', '0970597444', 2, 1);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (22, N'Tran Thi Minh', N'Nu', N'user22@university.edu.vn', '0984346088', 1, 3);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (23, N'Nguyen Van Chau', N'Nam', N'user23@university.edu.vn', '0917901903', 1, 3);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (24, N'Nguyen Thi Minh', N'Nu', N'user24@university.edu.vn', '0941944441', 1, 4);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (25, N'Pham Van Uyen', N'Nam', N'user25@university.edu.vn', '0986644106', 1, 9);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (26, N'Bui Thi Phuc', N'Nu', N'user26@university.edu.vn', '0923009833', 1, 10);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (27, N'Do Thi Phuc', N'Nu', N'user27@university.edu.vn', '0917270733', 1, 10);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (28, N'Tran Van Binh', N'Nam', N'user28@university.edu.vn', '0955540424', 1, 1);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (29, N'Pham Thi Uyen', N'Nu', N'user29@university.edu.vn', '0966623995', 1, 2);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (30, N'Pham Thi Chau', N'Nu', N'user30@university.edu.vn', '0983863413', 1, 1);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (31, N'Dang Thi Anh', N'Nu', N'user31@university.edu.vn', '0941726318', 3, 2);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (32, N'Bui Thi Giang', N'Nu', N'user32@university.edu.vn', '0917869910', 2, 2);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (33, N'Do Thi Khoa', N'Nu', N'user33@university.edu.vn', '0971070189', 2, 4);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (34, N'Dang Thi Son', N'Nu', N'user34@university.edu.vn', '0949823450', 1, 3);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (35, N'Ngo Van Uyen', N'Nam', N'user35@university.edu.vn', '0952091325', 1, 0);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (36, N'Bui Thi Tam', N'Nu', N'user36@university.edu.vn', '0981286543', 2, 2);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (37, N'Dang Thi Chau', N'Nu', N'user37@university.edu.vn', '0919196777', 2, 9);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (38, N'Pham Thi Oanh', N'Nu', N'user38@university.edu.vn', '0986460539', 1, 3);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (39, N'Nguyen Van Yen', N'Nam', N'user39@university.edu.vn', '0998231132', 1, 9);
INSERT INTO Users (Users_id, Full_name, Gender, Email, Phone_number, Position_id, Remaining_limited) VALUES (40, N'Vu Van Khoa', N'Nam', N'user40@university.edu.vn', '0952169044', 1, 3);

INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (1, N'Lap Trinh C Co Ban', N'Tran Thi B', 50000, 1, 1);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (2, N'Co So Du Lieu', N'Hoang Van E', 65000, 1, 1);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (3, N'Cau Truc Du Lieu', N'Pham Thi D', 65000, 1, 1);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (4, N'Mang May Tinh', N'Tran Thi B', 150000, 1, 1);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (5, N'Tri Tue Nhan Tao', N'Tran Thi B', 120000, 1, 1);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (6, N'An Ninh Mang', N'Do Van G', 50000, 1, 1);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (7, N'Kinh Te Vi Mo', N'Nguyen Van A', 50000, 2, 2);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (8, N'Kinh Te Vi Mo Nang Cao', N'Pham Thi D', 65000, 2, 2);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (9, N'Tai Chinh Doanh Nghiep', N'Nguyen Van A', 120000, 2, 2);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (10, N'Marketing Can Ban', N'Pham Thi D', 150000, 2, 2);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (11, N'Quan Tri Hoc', N'Do Van G', 65000, 2, 2);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (12, N'Ke Toan Tai Chinh', N'Bui Thi H', 120000, 2, 2);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (13, N'Ngu Phap Tieng Anh', N'Hoang Van E', 50000, 3, 3);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (14, N'Tieng Anh Thuong Mai', N'Le Van C', 150000, 3, 3);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (15, N'Van Hoc Anh My', N'Do Van G', 75000, 3, 3);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (16, N'Ky Nang Viet Luan', N'Hoang Van E', 65000, 3, 3);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (17, N'Bien Dich', N'Pham Thi D', 75000, 3, 3);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (18, N'Phat Am Chuan', N'Tran Thi B', 50000, 3, 3);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (19, N'Giai Phau Hoc', N'Do Van G', 50000, 4, 4);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (20, N'Sinh Ly Hoc', N'Vu Thi F', 75000, 4, 4);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (21, N'Duoc Ly Hoc', N'Hoang Van E', 50000, 4, 4);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (22, N'Benh Hoc Noi Khoa', N'Bui Thi H', 120000, 4, 4);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (23, N'Vi Sinh Y Hoc', N'Tran Thi B', 90000, 4, 4);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (24, N'Dinh Duong Hoc', N'Tran Thi B', 120000, 4, 4);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (25, N'Luat Dan Su', N'Hoang Van E', 150000, 5, 5);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (26, N'Luat Hinh Su', N'Vu Thi F', 120000, 5, 5);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (27, N'Luat Lao Dong', N'Pham Thi D', 150000, 5, 5);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (28, N'Luat Thuong Mai', N'Tran Thi B', 50000, 5, 5);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (29, N'Hien Phap', N'Pham Thi D', 75000, 5, 5);
INSERT INTO Products (Product_ID, Product_Name, Author, Unit_Price, Category_ID, Major_ID) VALUES (30, N'Luat Hanh Chinh', N'Tran Thi B', 65000, 5, 5);

INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (1, 19);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (2, 13);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (3, 10);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (4, 18);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (5, 20);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (6, 7);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (7, 20);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (8, 16);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (9, 18);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (10, 15);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (11, 15);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (12, 8);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (13, 10);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (14, 15);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (15, 18);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (16, 20);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (17, 14);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (18, 17);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (19, 6);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (20, 19);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (21, 7);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (22, 15);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (23, 13);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (24, 15);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (25, 8);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (26, 17);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (27, 5);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (28, 19);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (29, 18);
INSERT INTO Book_Stock (Product_ID, Inventory_Number) VALUES (30, 6);

INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (1, 26, 1, '2025-01-20', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (2, 9, 1, '2025-01-19', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (3, 20, 1, '2025-01-04', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (4, 30, 1, '2025-01-03', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (5, 21, 1, '2025-01-18', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (6, 5, 1, '2025-01-07', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (7, 1, 1, '2025-01-17', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (8, 37, 1, '2025-01-09', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (9, 23, 7, '2025-01-27', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (10, 5, 7, '2025-01-18', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (11, 16, 7, '2025-01-23', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (12, 24, 7, '2025-01-10', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (13, 19, 7, '2025-01-20', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (14, 11, 7, '2025-01-26', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (15, 29, 7, '2025-01-21', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (16, 36, 13, '2025-01-04', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (17, 20, 13, '2025-01-24', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (18, 7, 13, '2025-01-18', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (19, 9, 13, '2025-01-05', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (20, 17, 13, '2025-01-09', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (21, 8, 13, '2025-01-10', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (22, 3, 7, '2025-01-23', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (23, 3, 11, '2025-01-07', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (24, 3, 22, '2025-01-21', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (25, 3, 28, '2025-01-09', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (26, 7, 16, '2025-01-09', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (27, 7, 29, '2025-01-28', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (28, 7, 2, '2025-01-03', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (29, 7, 21, '2025-01-14', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (30, 12, 2, '2025-01-01', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (31, 12, 11, '2025-01-25', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (32, 12, 5, '2025-01-21', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (33, 18, 6, '2025-01-24', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (34, 18, 15, '2025-01-18', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (35, 18, 23, '2025-01-14', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (36, 25, 1, '2025-01-04', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (37, 25, 3, '2025-01-23', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (38, 25, 29, '2025-01-05', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (39, 25, 18, '2025-01-02', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (40, 31, 19, '2025-01-18', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (41, 31, 5, '2025-01-14', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (42, 31, 5, '2025-01-02', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (43, 24, 29, '2025-01-26', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (44, 3, 29, '2025-01-12', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (45, 14, 22, '2025-01-08', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (46, 7, 12, '2025-01-25', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (47, 36, 29, '2025-01-28', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (48, 27, 20, '2025-01-24', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (49, 10, 30, '2025-01-08', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (50, 11, 26, '2025-01-26', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (51, 12, 29, '2025-01-14', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (52, 2, 6, '2025-01-24', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (53, 22, 26, '2025-01-14', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (54, 16, 9, '2025-01-06', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (55, 7, 13, '2025-01-28', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (56, 3, 28, '2025-01-16', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (57, 15, 7, '2025-01-27', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (58, 30, 12, '2025-01-10', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (59, 15, 8, '2025-01-01', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (60, 13, 13, '2025-01-11', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (61, 18, 28, '2025-01-03', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (62, 18, 12, '2025-01-21', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (63, 33, 13, '2025-01-22', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (64, 35, 11, '2025-01-01', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (65, 8, 29, '2025-01-09', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (66, 12, 19, '2025-01-09', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (67, 3, 4, '2025-01-20', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (68, 28, 12, '2025-01-24', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (69, 21, 14, '2025-01-20', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (70, 33, 4, '2025-01-13', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (71, 37, 7, '2025-01-09', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (72, 28, 2, '2025-02-14', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (73, 1, 2, '2025-02-03', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (74, 34, 2, '2025-02-22', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (75, 35, 2, '2025-02-11', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (76, 13, 2, '2025-02-20', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (77, 24, 2, '2025-02-11', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (78, 20, 8, '2025-02-23', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (79, 33, 8, '2025-02-10', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (80, 40, 8, '2025-02-18', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (81, 27, 8, '2025-02-05', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (82, 21, 8, '2025-02-07', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (83, 26, 8, '2025-02-14', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (84, 12, 14, '2025-02-14', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (85, 37, 14, '2025-02-26', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (86, 20, 14, '2025-02-19', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (87, 26, 14, '2025-02-20', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (88, 36, 14, '2025-02-21', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (89, 1, 14, '2025-02-11', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (90, 38, 14, '2025-02-15', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (91, 19, 14, '2025-02-15', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (92, 14, 14, '2025-02-15', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (93, 33, 19, '2025-02-03', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (94, 31, 19, '2025-02-27', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (95, 11, 19, '2025-02-25', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (96, 6, 19, '2025-02-08', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (97, 19, 19, '2025-02-22', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (98, 40, 19, '2025-02-10', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (99, 22, 19, '2025-02-08', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (100, 3, 5, '2025-02-01', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (101, 3, 2, '2025-02-08', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (102, 7, 20, '2025-02-28', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (103, 7, 25, '2025-02-03', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (104, 7, 15, '2025-02-14', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (105, 12, 19, '2025-02-07', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (106, 12, 23, '2025-02-23', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (107, 12, 13, '2025-02-16', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (108, 12, 13, '2025-02-08', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (109, 18, 21, '2025-02-23', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (110, 18, 1, '2025-02-25', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (111, 25, 25, '2025-02-14', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (112, 25, 8, '2025-02-06', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (113, 31, 17, '2025-02-15', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (114, 31, 2, '2025-02-18', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (115, 31, 8, '2025-02-28', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (116, 31, 4, '2025-02-15', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (117, 30, 22, '2025-02-17', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (118, 36, 20, '2025-02-11', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (119, 29, 20, '2025-02-27', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (120, 33, 14, '2025-02-27', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (121, 36, 15, '2025-02-06', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (122, 31, 15, '2025-02-09', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (123, 16, 27, '2025-02-21', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (124, 18, 25, '2025-02-25', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (125, 34, 16, '2025-02-21', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (126, 16, 9, '2025-02-15', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (127, 5, 23, '2025-02-10', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (128, 16, 9, '2025-02-11', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (129, 21, 29, '2025-02-18', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (130, 6, 5, '2025-02-05', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (131, 15, 13, '2025-02-23', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (132, 10, 23, '2025-02-07', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (133, 5, 14, '2025-02-14', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (134, 22, 18, '2025-02-15', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (135, 27, 2, '2025-02-07', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (136, 27, 13, '2025-02-25', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (137, 38, 23, '2025-02-01', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (138, 37, 13, '2025-02-16', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (139, 1, 12, '2025-02-10', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (140, 25, 28, '2025-02-27', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (141, 27, 18, '2025-02-24', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (142, 35, 26, '2025-02-20', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (143, 15, 16, '2025-02-08', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (144, 28, 3, '2025-03-05', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (145, 32, 3, '2025-03-20', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (146, 2, 3, '2025-03-18', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (147, 25, 3, '2025-03-01', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (148, 22, 3, '2025-03-13', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (149, 26, 3, '2025-03-19', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (150, 11, 3, '2025-03-19', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (151, 30, 3, '2025-03-22', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (152, 6, 9, '2025-03-09', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (153, 28, 9, '2025-03-13', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (154, 9, 9, '2025-03-11', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (155, 30, 9, '2025-03-07', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (156, 12, 9, '2025-03-15', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (157, 4, 9, '2025-03-11', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (158, 25, 20, '2025-03-12', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (159, 18, 20, '2025-03-08', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (160, 27, 20, '2025-03-21', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (161, 17, 20, '2025-03-03', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (162, 6, 20, '2025-03-25', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (163, 31, 20, '2025-03-21', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (164, 2, 20, '2025-03-02', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (165, 4, 20, '2025-03-25', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (166, 3, 8, '2025-03-07', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (167, 3, 27, '2025-03-01', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (168, 7, 5, '2025-03-08', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (169, 7, 5, '2025-03-16', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (170, 7, 22, '2025-03-04', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (171, 7, 19, '2025-03-07', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (172, 12, 23, '2025-03-09', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (173, 12, 25, '2025-03-12', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (174, 12, 6, '2025-03-20', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (175, 18, 24, '2025-03-23', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (176, 18, 4, '2025-03-25', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (177, 18, 27, '2025-03-06', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (178, 18, 10, '2025-03-04', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (179, 25, 1, '2025-03-10', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (180, 25, 19, '2025-03-22', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (181, 25, 30, '2025-03-13', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (182, 25, 13, '2025-03-23', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (183, 31, 3, '2025-03-19', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (184, 31, 23, '2025-03-27', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (185, 16, 4, '2025-03-23', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (186, 20, 28, '2025-03-22', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (187, 39, 26, '2025-03-04', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (188, 37, 26, '2025-03-02', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (189, 23, 18, '2025-03-14', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (190, 24, 3, '2025-03-17', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (191, 22, 1, '2025-03-28', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (192, 27, 27, '2025-03-16', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (193, 7, 14, '2025-03-12', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (194, 30, 23, '2025-03-05', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (195, 28, 6, '2025-03-24', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (196, 34, 21, '2025-03-09', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (197, 40, 26, '2025-03-18', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (198, 31, 15, '2025-03-14', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (199, 38, 9, '2025-03-11', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (200, 16, 27, '2025-03-03', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (201, 18, 29, '2025-03-15', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (202, 16, 25, '2025-03-15', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (203, 37, 20, '2025-03-22', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (204, 25, 11, '2025-03-01', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (205, 32, 28, '2025-03-11', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (206, 12, 16, '2025-03-07', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (207, 23, 26, '2025-03-09', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (208, 22, 9, '2025-03-20', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (209, 18, 18, '2025-03-01', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (210, 34, 7, '2025-03-03', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (211, 16, 24, '2025-03-14', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (212, 32, 18, '2025-03-25', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (213, 16, 23, '2025-03-16', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (214, 32, 15, '2025-03-26', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (215, 2, 3, '2025-03-10', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (216, 15, 13, '2025-03-23', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (217, 16, 10, '2025-03-22', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (218, 38, 12, '2025-03-16', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (219, 36, 17, '2025-03-12', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (220, 36, 4, '2025-04-24', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (221, 22, 4, '2025-04-07', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (222, 23, 4, '2025-04-11', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (223, 30, 4, '2025-04-04', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (224, 18, 4, '2025-04-24', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (225, 20, 4, '2025-04-18', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (226, 17, 4, '2025-04-25', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (227, 15, 4, '2025-04-23', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (228, 8, 4, '2025-04-06', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (229, 14, 10, '2025-04-10', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (230, 31, 10, '2025-04-08', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (231, 18, 10, '2025-04-12', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (232, 34, 10, '2025-04-06', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (233, 19, 10, '2025-04-10', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (234, 7, 10, '2025-04-01', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (235, 13, 10, '2025-04-23', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (236, 18, 15, '2025-04-04', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (237, 3, 15, '2025-04-28', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (238, 4, 15, '2025-04-01', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (239, 36, 15, '2025-04-19', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (240, 19, 15, '2025-04-10', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (241, 9, 15, '2025-04-16', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (242, 32, 15, '2025-04-16', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (243, 3, 11, '2025-04-06', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (244, 3, 2, '2025-04-09', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (245, 3, 28, '2025-04-16', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (246, 7, 27, '2025-04-03', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (247, 7, 13, '2025-04-16', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (248, 12, 19, '2025-04-21', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (249, 12, 22, '2025-04-02', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (250, 18, 5, '2025-04-26', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (251, 18, 19, '2025-04-10', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (252, 25, 8, '2025-04-04', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (253, 25, 18, '2025-04-25', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (254, 31, 20, '2025-04-20', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (255, 31, 26, '2025-04-20', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (256, 31, 8, '2025-04-25', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (257, 25, 15, '2025-04-15', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (258, 20, 28, '2025-04-19', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (259, 28, 10, '2025-04-19', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (260, 40, 2, '2025-04-20', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (261, 7, 25, '2025-04-07', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (262, 14, 9, '2025-04-22', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (263, 6, 6, '2025-04-08', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (264, 12, 18, '2025-04-03', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (265, 11, 1, '2025-04-14', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (266, 29, 23, '2025-04-20', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (267, 31, 10, '2025-04-02', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (268, 15, 10, '2025-04-23', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (269, 19, 23, '2025-04-28', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (270, 30, 3, '2025-04-22', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (271, 15, 30, '2025-04-09', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (272, 38, 22, '2025-04-26', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (273, 13, 14, '2025-04-04', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (274, 35, 8, '2025-04-21', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (275, 10, 30, '2025-04-09', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (276, 10, 3, '2025-04-02', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (277, 11, 26, '2025-04-10', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (278, 39, 24, '2025-04-27', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (279, 37, 30, '2025-04-10', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (280, 29, 4, '2025-04-15', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (281, 20, 23, '2025-04-13', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (282, 18, 17, '2025-04-18', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (283, 32, 15, '2025-04-03', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (284, 39, 2, '2025-04-14', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (285, 21, 20, '2025-04-09', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (286, 2, 3, '2025-04-08', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (287, 37, 19, '2025-04-01', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (288, 18, 19, '2025-04-02', NULL, 1);
INSERT INTO Borrow_Transaction (Order_ID, Users_id, Product_ID, Start_date, End_date, Quantity) VALUES (289, 12, 16, '2025-04-17', NULL, 1);

/*
================================================================================
  PHẦN 3 — VIEW THỐNG KÊ THUÊ SÁCH THEO NGÀNH HỌC + TOP 2/THÁNG (Câu 3)
================================================================================
  Yêu cầu: Tạo View lưu trữ thống kê dữ liệu cho thuê sách theo phân ngành
  học từng tháng, trong đó tìm ra TOP 2 ngành học có nhu cầu thuê sách
  nhiều nhất mỗi tháng.

  Thiết kế gồm 2 View:
    (a) ThongKeMuonTheoNganh_Thang  → thống kê thô: số lượt mượn theo
        Ngành học + Tháng (làm nguồn cho phần xếp hạng).
    (b) Top2NganhMuonNhieuNhat      → áp ROW_NUMBER() lên (a) để lấy
        Top 2 ngành/tháng.
================================================================================
*/

IF OBJECT_ID('ThongKeMuonTheoNganh_Thang', 'V') IS NOT NULL
    DROP VIEW ThongKeMuonTheoNganh_Thang;
GO

CREATE VIEW ThongKeMuonTheoNganh_Thang AS
SELECT
    m.Major_Name                              AS NganhHoc,
    FORMAT(bt.Start_date, 'MM/yyyy')          AS ThangNam,
    COUNT(bt.Order_ID)                        AS SoLuotMuon,
    SUM(bt.Quantity)                          AS TongSoLuongSachMuon
FROM Borrow_Transaction AS bt
JOIN Products AS p
    ON p.Product_ID = bt.Product_ID
JOIN Major AS m
    ON m.Major_ID = p.Major_ID
GROUP BY
    m.Major_Name,
    FORMAT(bt.Start_date, 'MM/yyyy');
GO
-- Kiểm tra: SELECT * FROM ThongKeMuonTheoNganh_Thang ORDER BY ThangNam, SoLuotMuon DESC;


IF OBJECT_ID('Top2NganhMuonNhieuNhat', 'V') IS NOT NULL
    DROP VIEW Top2NganhMuonNhieuNhat;
GO

CREATE VIEW Top2NganhMuonNhieuNhat AS
SELECT
    NganhHoc,
    ThangNam,
    SoLuotMuon,
    TongSoLuongSachMuon,
    Hang
FROM (
    SELECT
        NganhHoc,
        ThangNam,
        SoLuotMuon,
        TongSoLuongSachMuon,
        ROW_NUMBER() OVER (
            PARTITION BY ThangNam
            ORDER BY SoLuotMuon DESC
        ) AS Hang
    FROM ThongKeMuonTheoNganh_Thang
) AS Ranked
WHERE Hang <= 2;
GO

-- Kết quả Top 2 ngành học mượn sách nhiều nhất mỗi tháng:
SELECT * FROM Top2NganhMuonNhieuNhat ORDER BY ThangNam, Hang;


/*
================================================================================
  PHẦN 4 — SUBQUERY: SÁCH CÓ > 5 NGƯỜI THUÊ MỖI THÁNG (Câu 4)
================================================================================
  Yêu cầu: dùng SubQuery để tìm các đầu sách có nhiều hơn 5 người mượn
  riêng biệt (distinct) trong mỗi tháng.

  Cách làm: SubQuery độc lập trong mệnh đề FROM tính số người mượn
  riêng biệt theo (Product, Tháng), sau đó lọc ở câu SELECT ngoài
  bằng WHERE > 5 (vì không thể đặt điều kiện COUNT(DISTINCT) trực tiếp
  trong WHERE của câu GROUP BY gốc — phải lồng subquery).
================================================================================
*/

SELECT
    SachThang.Product_Name,
    SachThang.ThangNam,
    SachThang.SoNguoiMuon
FROM (
    -- SubQuery: số người mượn riêng biệt theo từng sách, từng tháng
    SELECT
        p.Product_Name,
        FORMAT(bt.Start_date, 'MM/yyyy')        AS ThangNam,
        COUNT(DISTINCT bt.Users_id)              AS SoNguoiMuon
    FROM Borrow_Transaction AS bt
    JOIN Products AS p
        ON p.Product_ID = bt.Product_ID
    GROUP BY
        p.Product_Name,
        FORMAT(bt.Start_date, 'MM/yyyy')
) AS SachThang
WHERE SachThang.SoNguoiMuon > 5
ORDER BY
    SachThang.ThangNam,
    SachThang.SoNguoiMuon DESC;


/*
================================================================================
  PHẦN 5 — CTE: SÁCH CÓ > 5 NGƯỜI THUÊ MỖI THÁNG (Câu 5)
================================================================================
  Yêu cầu: làm lại Câu 4 nhưng dùng CTE (Common Table Expression) thay
  cho SubQuery — cùng kết quả, khác cú pháp, dễ đọc và có thể tái sử dụng
  nhiều lần trong cùng câu lệnh.
================================================================================
*/

WITH SachThang_CTE AS (
    SELECT
        p.Product_Name,
        FORMAT(bt.Start_date, 'MM/yyyy')        AS ThangNam,
        COUNT(DISTINCT bt.Users_id)              AS SoNguoiMuon
    FROM Borrow_Transaction AS bt
    JOIN Products AS p
        ON p.Product_ID = bt.Product_ID
    GROUP BY
        p.Product_Name,
        FORMAT(bt.Start_date, 'MM/yyyy')
)
SELECT
    Product_Name,
    ThangNam,
    SoNguoiMuon
FROM SachThang_CTE
WHERE SoNguoiMuon > 5
ORDER BY
    ThangNam,
    SoNguoiMuon DESC;


/*
================================================================================
  PHẦN 6 — CTE: NGƯỜI DÙNG MƯỢN SÁCH > 10 LẦN (Câu 6)
================================================================================
  Yêu cầu: dùng CTE tính tổng số lần mượn sách cho mỗi người dùng (toàn
  bộ thời gian, không phân theo tháng), sau đó hiển thị những người
  mượn nhiều hơn 10 lần.
================================================================================
*/

WITH TongSoLanMuon_CTE AS (
    SELECT
        bt.Users_id,
        COUNT(bt.Order_ID)    AS SoLanMuon
    FROM Borrow_Transaction AS bt
    GROUP BY
        bt.Users_id
)
SELECT
    u.Users_id,
    u.Full_name,
    r.Position_name           AS VaiTro,
    t.SoLanMuon
FROM TongSoLanMuon_CTE AS t
JOIN Users AS u
    ON u.Users_id = t.Users_id
JOIN Roles AS r
    ON r.Position_id = u.Position_id
WHERE t.SoLanMuon > 10
ORDER BY
    t.SoLanMuon DESC;

/*
================================================================================
  KẾT THÚC FILE
  Xem hướng dẫn dashboard Power BI tại file PowerBI_Guide_Library.md
================================================================================
*/
