# Công cụ quản lý vHost
#### Mục tiêu:
Script này được viết bởi Trí nhằm thực hiện chức năng cốt lõi là có thể tạo được **một hoặc hàng loạt** virtual host (các website) trên một server Linux - cụ thể là Ubuntu, tham khảo dựa trên thao tác của các web Panel

#### Các chức năng phụ:
- Xem tất cả các vHost đang có
- Xoá một hoặc nhiều vHost
- Đổi tên vHost
- Active/Enable vHost
- Suspend/Disable vHost
- Cài đặt WordPress cho vHost được chỉ định

Lưu đồ giải thuật (flowchart) cần tải file vHostManagement.drawio và truy cập draw.io để mở file

#### Luồng đi chính:
1. Tạo ra vòng lặp while với  switch case gồm 8 options, hiển thị như một menu (màn hình chính), mỗi tuỳ chọn sẽ gọi 1 function để giải quyết, ngoại trừ option thoát và option kiểm tra người dùng nhập dữ liệu ngoài switch case
2. Sau khi thực hiện xong một function thì sẽ về lại màn hình chính
3. Trước khi vào vòng lặp thì script chạy sẽ cài đặt các phần mềm cần thiết như curl, apache, mysql, php và wp-cli

#### Mong muốn hoàn thiện thêm các chức năng khác:
- Chạy check thêm mysql_secure_installation đã được thực hiện trước đó hay chưa
- Kiểm tra đầu vào (regex) cho input của user
- Có thể tuỳ biến các version php khác nhau cho từng vhost
- Có thể tìm kiếm và search các php extension và install hàng loạt

#### Tài liệu tham khảo:
- Bash basic: https://www.w3schools.com/bash/
- Vẽ flowchart: https://stanford.com.vn/kien-thuc-lap-trinh/tin-chi-tiet/cagId/27/id/22569/huong-dan-viet-so-do-khoi-thuat-toan-trong-lap-trinh
- Công cụ cài đặt WordPress tự động (wp-cli): https://wp-cli.org/
