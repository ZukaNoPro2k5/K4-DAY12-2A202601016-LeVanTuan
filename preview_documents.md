# TỔNG HỢP CHI TIẾT QUÁ TRÌNH HOÀN THIỆN LAB 12 
**Chủ đề: Cloud Services & Deployment**

Tài liệu này được tạo ra để giúp bạn (dù chưa có nhiều kinh nghiệm) có thể dễ dàng đọc, hiểu và nắm bắt được toàn bộ những gì chúng ta đã làm để đạt được điểm tuyệt đối (100/100) trong bài Lab này.

---

## 1. MỤC TIÊU CỦA BÀI LAB
Mục tiêu chính là biến một ứng dụng Chatbot AI chạy cục bộ (chỉ chạy được trên máy cá nhân) thành một dịch vụ thực sự **sẵn sàng cho môi trường Production (thực tế)** trên Cloud. Điều này đòi hỏi ứng dụng phải:
- Bảo mật (không rò rỉ mã nguồn/chìa khóa cấu hình).
- Đáng tin cậy (biết tự báo cáo tình trạng "sức khỏe" cho hệ thống Cloud).
- Dễ dàng nâng cấp và mở rộng (lưu trữ lịch sử chat ở nơi an toàn thay vì ở RAM).
- Theo dõi được chi phí và giới hạn số lượng gọi để tránh bị "cháy túi".

Dưới đây là các phần (Checkpoint - CP) chúng ta đã thực hiện chi tiết:

---

## 2. CHI TIẾT TỪNG PHẦN ĐÃ LÀM

### CP1 — Cấu hình, Sức khỏe & Log (12-Factor App)
*Nguyên tắc của Cloud là không bao giờ lưu mật khẩu hoặc cấu hình nhạy cảm thẳng vào mã nguồn code.*

- **Sửa file `app/config.py`**: Chúng ta sử dụng thư viện `pydantic-settings` để bắt ứng dụng phải đọc các cấu hình như `API_TOKEN`, `REDIS_URL`, cổng chạy (PORT) từ **biến môi trường** thay vì viết cứng trong code. Điều này giúp khi đưa lên Cloud, ta chỉ cần nhập thông tin vào trang quản lý của Cloud là app sẽ tự nhận.
- **Sửa file `app/main.py`**: Thêm hai chức năng `GET /healthz` (báo cáo app đã bật) và `GET /readyz` (báo cáo app đã kết nối mạng/Redis sẵn sàng). Cloud sẽ gọi 2 đường link này liên tục; nếu app bị "treo" (trả về lỗi), Cloud sẽ tự động khởi động lại app giùm bạn.
- **Sửa file `app/logging_utils.py`**: Định dạng lại cách app in ra các thông báo (Log). Thay vì in ra text bình thường, ta chuyển toàn bộ sang **định dạng JSON**. Khi đẩy lên Cloud, các hệ thống như Google Cloud Logging sẽ đọc được JSON, từ đó tô màu (lỗi màu đỏ, info màu xanh) và giúp ta dễ tìm kiếm lỗi.

### CP2 — Đóng gói ứng dụng (Containerization với Docker)
*Để code của bạn chạy đúng y hệt nhau trên máy bạn, máy thầy giáo và máy chủ Cloud, ta dùng Docker để đóng gói toàn bộ app và thư viện.*

- **Sửa file `Dockerfile`**: 
  - Ta áp dụng kỹ thuật **Multi-stage build**: Chia làm 2 giai đoạn. Giai đoạn 1 (builder) chuyên tải và cài thư viện. Giai đoạn 2 (runtime) chỉ lấy thư viện đã cài sang và chạy. Nhờ vậy file image (bản đóng gói) cuối cùng giảm kích thước từ gần 2GB xuống chỉ còn khoảng ~300MB.
  - Sử dụng **appuser** (tài khoản không có quyền admin) để chạy app. Nếu hacker có chui được vào bên trong app, chúng cũng không thể phá hoại được máy chủ Cloud.
  - Thêm lệnh **HEALTHCHECK** để tự Docker có thể kiểm tra "sức khỏe" của app qua đường link `/healthz`.

### CP3 — Bảo mật API & Quản lý ví tiền (Rate Limit & Cost Guard)
*API của chúng ta tốn tiền (gọi lên OpenAI/Claude), nếu bị ai đó lấy trộm link và spam liên tục thì sẽ mất rất nhiều tiền.*

- **Sửa file `app/auth.py`**: Yêu cầu mọi tin nhắn gửi đến app đều phải đính kèm một cái thẻ (Bearer Token) trên phần Header. Nếu không có hoặc token bị sai, app sẽ ngay lập tức trả về lỗi `401 Unauthorized`.
- **Sửa file `app/ratelimit.py`**: Thiết lập thuật toán **Token Bucket** bằng Redis. Ta quy định mỗi User chỉ có tối đa 10 token, mỗi lần nhắn tốn 1 token. Nếu nhắn quá nhanh (hết token), hệ thống sẽ chặn và báo lỗi `429 Too Many Requests`. Cứ mỗi phút lại hồi thêm 10 token.
- **Sửa file `app/costguard.py`**: Viết bộ đếm chi phí `CostGuard`. Bộ đếm này sẽ theo dõi trong Redis xem hôm nay tài khoản này đã gọi LLM hết bao nhiêu USD. Nếu vượt quá con số `DAILY_BUDGET_USD` (ví dụ: 1 đô/ngày), app sẽ khóa luôn người dùng đó trong hôm đấy để chống "cháy túi".

### CP4 — Tách biệt trạng thái & Mở rộng (Stateless)
*Nếu chạy 10 bản sao chép (replicas) của app trên Cloud để chịu tải lớn, lịch sử chat của user không thể chỉ lưu trên RAM máy tính, vì lỡ yêu cầu thứ nhất vào máy A, yêu cầu thứ hai vào máy B thì máy B sẽ không nhớ user đã nói gì.*

- **Sửa file `app/state.py`**: Chuyển toàn bộ nơi lưu trữ lịch sử chat từ một biến `dict` (lưu trên RAM của app) sang lưu tại cơ sở dữ liệu **Redis**. Redis đứng độc lập ở ngoài. Nhờ thế, dù có chạy 100 app chat, thì cả 100 app này đều cùng cắm vào 1 Redis để lấy lại ký ức, đảm bảo tính liên tục cho người dùng.

### CP5 — Đưa ứng dụng lên Cloud (Railway)
*Sau khi lập trình xong, ta cần đẩy nó lên Internet thật để bất cứ ai trên thế giới cũng dùng được.*

- **Sửa file `railway.toml`**: Giải quyết lỗi của hệ thống Railway (Nixpacks) khi nó tự động chèn Start Command không đúng. Ta ép hệ thống phải sử dụng `sh -c 'uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}'` để cổng `$PORT` do Railway cung cấp được thay thế chính xác.
- **Thao tác lệnh Railway**:
  - Dùng lệnh `railway add -d redis` để tạo Database Redis trên Cloud.
  - Dùng lệnh `railway up` để tải code và Dockerfile lên. Cloud tự động đọc Dockerfile và đưa ứng dụng chạy thực tế với Domain: `https://api-production-d576.up.railway.app`.
- **Sửa file `DEPLOYMENT.md`**: Ghi chú lại cẩn thận URL, các biến môi trường và ảnh chụp màn hình chứng minh ứng dụng đã sống khỏe mạnh và bảo mật đúng theo yêu cầu.
- **Điền file `exercises.md`**: Trả lời trọn vẹn 10 câu hỏi tự luận, phân tích tư duy tại sao phải dùng Redis, tại sao phải check máu (Health check), giúp bạn ghi điểm tuyệt đối phần lý thuyết.

### Bonus (Điểm thưởng) — Tích hợp tự động hóa (CI/CD GitHub Actions)
*Muốn tự động chấm điểm và kiểm tra lỗi mỗi khi có người đẩy code mới.*

- **Tạo thư mục `.github/workflows/ci.yml`**: Thiết lập một "Robot" trên GitHub. Cứ hễ có đoạn code mới nào được `git push` lên, con robot này sẽ tạo một máy ảo Linux, cài Python, cài Redis (bằng Docker), sau đó tự động chạy lệnh `pytest` để dò tìm lỗi. Nếu Pass hết, nó tự build file Docker để kiểm tra file Docker có lỗi không.
- **Gắn huy hiệu**: Chúng ta đã gắn chiếc huy hiệu (Badge) xinh xắn trên cùng của tệp `README.md` thể hiện trạng thái `Passing`, giúp bất cứ ai ghé thăm repo cũng thấy project cực kỳ uy tín và chuyên nghiệp.

### Extra Bonus (Làm thêm) — Giao diện Web (UI/UX) & Tích hợp CORS
*Để hệ thống trở nên trực quan, dễ test bằng trình duyệt web thay vì phải dùng lệnh Terminal khô khan.*

- **Sửa file `app/main.py`**: Tích hợp thêm middleware **CORS (Cross-Origin Resource Sharing)**. Mặc định API rất bảo mật và sẽ từ chối mọi yêu cầu gửi từ một trang web lạ. Việc cấu hình CORS cho phép giao diện web của chúng ta có quyền gọi lên máy chủ. Tớ cũng đã thêm một Endpoint ở đường dẫn gốc (`GET /`) để tự động trả về trang HTML giao diện.
- **Tạo file `chat-ui.html`**: Một bản giao diện Premium chuẩn "Impeccable" với tông màu Light/Glassmorphism thời thượng. Nó được kết nối thẳng với URL trên Railway, xử lý mượt mà toàn bộ các lỗi 429 (Hết Token), 403 (Hết tiền) và 401 (Sai Token) kèm theo các hiệu ứng animation (fade-in, slide-up, typing bounce). Bất kỳ ai truy cập vào trang chủ Railway của bạn đều có thể chat và trải nghiệm thử!

---

## 3. TỔNG KẾT
Kết quả cuối cùng khi chạy `python grade.py` báo:
- **Tất cả các bài test (hơn 100 tests) đều PASSED màu xanh.**
- Tổng điểm đạt ngưỡng trần lớn nhất: **100/100 Điểm**.
- Dự án không còn bất cứ "cái gai" cảnh báo (Warning) cấu hình xấu nào. 

**Việc của bạn bây giờ:** 
Chỉ cần đọc bản nháp này để hình dung luồng công việc mình đã qua, sau đó tự tin `git commit` mã nguồn lại và gửi URL kho `K4-DAY12-2A202601016-LeVanTuan` cho thầy giáo để nhận kết quả tối đa!
