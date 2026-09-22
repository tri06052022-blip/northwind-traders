# Northwind Sales Performance Analysis 2014

Dự án sử dụng các kỹ năng sau:

- **Kỹ năng sử dụng:** SQL Server, SSMS, Power Query, DAX, Power BI, Data Storytelling.

## 1. Bài toán kinh doanh và yêu cầu đầu vào

| Câu hỏi kinh doanh | Dashboard cung cấp | Quyết định được hỗ trợ |
|---|---|---|
| Quy mô bán hàng năm 2014 ra sao, tháng nào cao/thấp? | Tổng KPI, doanh thu theo tháng và danh mục | Cung cấp cơ sở để theo dõi biến động doanh thu theo tháng và danh mục. |
| Sản phẩm nào đóng góp chính? | Top 10 sản phẩm, tỷ trọng nhóm ABC | Ưu tiên theo dõi sản phẩm chủ lực; rà soát danh mục đóng góp thấp |
| Doanh thu tập trung vào khách nào, ai cần chăm sóc? | Top khách, mức tập trung doanh thu, RFM, danh sách cần chú ý | Ưu tiên giữ chân, phát triển và tái kích hoạt khách |
| Nhân viên đóng góp thế nào và sử dụng chiết khấu ra sao? | Doanh thu, đơn hàng, khách phục vụ và tỷ lệ chiết khấu theo nhân viên/band | Chọn trường hợp cần rà soát chính sách và trao đổi cách bán hàng |

## 2. Dữ liệu nguồn và chất lượng

Nguồn trong repository là 7 file **CSV**, có thể mở bằng Excel. Chúng chứa toàn bộ lịch sử được cung cấp; lớp phân tích chính chỉ lấy năm 2014.

| File | Số dòng toàn nguồn | Nội dung |
|---|---:|---|
| orders.csv | 830 | Đầu đơn hàng, ngày đặt, khách và nhân viên phụ trách |
| order_details.csv | 2,155 | Sản phẩm, giá giao dịch, số lượng, chiết khấu trong từng đơn |
| products.csv | 77 | Danh mục sản phẩm và thuộc tính |
| categories.csv | 8 | Danh mục ngành hàng |
| customers.csv | 91 | Thông tin khách hàng |
| employees.csv | 9 | Thông tin nhân viên |
| shippers.csv | 3 | Đơn vị vận chuyển; không dùng trong mô hình bán hàng cuối |

## 3. Dòng chảy và biến đổi dữ liệu

```text
7 CSV → SQL Server / raw
                    ↓ kiểm tra dữ liệu
          analytics.vw_sales_detail
          Nối 6 bảng, thêm doanh thu từng dòng
                    ↓ lọc ngày đặt năm 2014
          analytics.vw_sales_2014
                    ├→ vw_fact_sales_2014
                    ├→ product_performance → vw_dim_product_2014
                    ├→ customer_rfm → vw_dim_customer_2014
                    └→ employee_contribution → vw_dim_employee_2014
          Lịch 365 ngày → vw_dim_date_2014
                    ↓
          Power Query → Quan hệ Dim–Fact → DAX → 4 trang Power BI
```

### Mô hình Power BI

| View nhập vào Power BI | Số dòng | Vai trò |
|---|---:|---|
| `vw_fact_sales_2014` | 1,059 | Từng dòng giao dịch thuộc 408 đơn năm 2014 |
| `vw_dim_date_2014` | 365 | Ngày, tháng, quý, năm |
| `vw_dim_product_2014` | 77 | Sản phẩm, danh mục, ABC và xếp hạng |
| `vw_dim_customer_2014` | 86 | Khách có đơn năm 2014, quốc gia và RFM |
| `vw_dim_employee_2014` | 9 | Nhân viên và thông tin mô tả |

## 4. Dashboard cung cấp những gì?

Dashboard sử dụng các chỉ số chính gồm **Net Sales, Total Orders, Units Sold, Active Customers, Products Sold, Average Order Value** và **Weighted Discount %**. Trong đó, Net Sales là doanh thu sau chiết khấu; Average Order Value bằng Net Sales chia số đơn; Weighted Discount % bằng tổng tiền chiết khấu chia Gross Sales.

| Trang dashboard | Nội dung cung cấp | Giá trị sử dụng |
|---|---|---|
| **Sales Overview** | KPI tổng quan, doanh thu theo tháng và danh mục; bộ lọc tháng, quốc gia và danh mục | Theo dõi quy mô, biến động doanh thu và xác định tháng hoặc danh mục cần chú ý |
| **Product Performance** | Top 10 sản phẩm, sản lượng, chiết khấu và cơ cấu ABC | Xác định sản phẩm đóng góp chính và mức tập trung doanh thu theo nhóm sản phẩm |
| **Customer Analysis** | Top khách hàng, tỷ trọng Top 10, phân bố RFM và danh sách khách giá trị cao cần chú ý | Đánh giá mức tập trung doanh thu và hỗ trợ lựa chọn nhóm khách cần duy trì, phát triển hoặc tái kích hoạt |
| **Employee & Discount** | Doanh thu, số đơn, khách phục vụ và chiết khấu theo nhân viên hoặc Discount Band | Xác định trường hợp cần rà soát thêm về cơ cấu bán hàng và chính sách chiết khấu |

ABC chia sản phẩm thành A, B và C theo tỷ trọng Net Sales lũy kế. RFM phân nhóm khách hàng theo lần mua gần nhất, tần suất mua và giá trị mua, với ngày tham chiếu **2015-01-01**. Discount Band gồm None, Low, Medium và High theo tỷ lệ giảm giá của từng dòng giao dịch.

## 5. Phát hiện và ý nghĩa kinh doanh

### 5.1. Tháng 12 cao nhất, tháng 6 thấp nhất về Net Sales

Net Sales tháng 12 khoảng **71,398.43**, so với **36,362.80** tháng 6. Dairy Products dẫn đầu ngành hàng với khoảng **115,387.64**, tiếp theo là Beverages khoảng **103,924.31**.

### 5.2. Nhóm A tập trung phần lớn doanh thu sản phẩm

| ABC | Số sản phẩm | Net Sales | Tỷ trọng |
|---|---:|---:|---:|
| A | 37 | 498,773.80 | 80.83% |
| B | 21 | 87,900.52 | 14.24% |
| C | 19 | 30,410.89 | 4.93% |

Côte de Blaye dẫn đầu với khoảng **49.20 nghìn**, sau đó là Raclette Courdavault **35.78 nghìn** và Thüringer Rostbratwurst **34.76 nghìn**.

Kết luận: nhóm A đáng được ưu tiên giám sát khả năng cung ứng và nhu cầu. Nhóm A có 37/77 sản phẩm chiếm 80.83% doanh thu. 

### 5.3. 10 khách lớn nhất đóng góp 46.50% Net Sales

Mười khách chiếm khoảng 11.63% trong 86 khách hoạt động nhưng đóng góp gần một nửa doanh thu. Điều này cho thấy mức tập trung đáng theo dõi.

Các segment RFM được gán theo thứ tự ưu tiên từ trên xuống dựa trên điểm Recency (R), Frequency (F) và Monetary (M), mỗi điểm từ 1 đến 5:

| RFM Segment | Quy tắc phân nhóm | Số khách |
|---|---|---:|
| Champions | R ≥ 4, F ≥ 4 và M ≥ 4 | 15 |
| Loyal | R ≥ 3, F ≥ 3 và M ≥ 3 | 11 |
| Potential Loyalists | R ≥ 4 và F ≥ 2 | 13 |
| At Risk | R ≤ 2, F ≥ 3 và M ≥ 3 | 11 |
| Hibernating | R ≤ 2 và F ≤ 2 | 18 |
| Others | Các trường hợp còn lại | 18 |

Danh sách ưu tiên cần chú ý theo tiêu chí giá trị cao nhưng đã lâu chưa phát sinh đơn mới (R ≤ 2 và M ≥ 4) gồm 4 khách hàng, cần được ưu tiên liên hệ và chăm sóc để giảm thiểu rủi ro mất khách.



### 5.4. Đóng góp và mức chiết khấu khác nhau giữa nhân viên

Margaret Peacock có Net Sales cao nhất, khoảng **128,809.79 từ 81 đơn**, với Weighted Discount khoảng **7.65%**. Janet Leverling đạt **108,026.16 từ 71 đơn**, với tỷ lệ khoảng **3.37%**. Anne Dodsworth có tỷ lệ khoảng **11.05%**, trong khi mức toàn bộ là **6.27%**.
