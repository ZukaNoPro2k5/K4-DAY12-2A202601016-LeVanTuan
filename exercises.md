# Phiếu Phản Ánh — K4 Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng chứa cụm từ đó bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Lê Văn Tuấn  Mã học viên: 2A202601016

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `api_token` không có giá trị mặc định nên app chết ngay khi
khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà việc
"chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Nếu để mặc định, ứng dụng vẫn chạy trên cloud nhưng sử dụng token 'changeme'. Kẻ gian có thể dễ dàng gọi API bằng token này, làm tiêu tốn tiền thật (do LLM thật tính phí). Việc 'fail fast' giúp phát hiện lỗi cấu hình ngay lúc deploy.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/chat` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> `{"event": "chat_completed", "severity": "INFO", "ts": "2026-08-10T07:00:00+00:00", "client_id": "sv01", "usd_cost": 0.0001}`
> Tự động parse JSON để vẽ biểu đồ tổng chi phí, hoặc dễ dàng filter log theo `client_id` và `severity`.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t chat:single .
docker build -t chat:multi .
docker images | grep chat
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ... MB |
| Multi-stage | ... MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> 1 stage: ~1000 MB, Multi-stage: ~150 MB.
> Ở bản multi-stage, các công cụ build bị vứt bỏ. Image cuối cùng chỉ chứa môi trường python slim nhỏ gọn và thư viện chạy.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Đặt `COPY . .` trước `RUN pip install` khiến mỗi lần sửa một file code, Docker sẽ invalid cache và phải chạy lại `pip install` rất chậm. Đặt `COPY requirements.txt` lên trước giúp tận dụng cache.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Khi chạy bằng root, nếu có lỗ hổng, hacker sẽ có quyền root bên trong container và có thể leo thang đặc quyền ra máy host. Lệnh `USER appuser` cắt đứt chuỗi tấn công này.

---

### Câu 6 — Bearer token (CP3)

Vì sao 401 phải kèm header `WWW-Authenticate: Bearer`? Và vì sao ta trả **cùng
một** thông báo lỗi cho cả ba trường hợp (thiếu header, sai scheme, sai token)
thay vì nói rõ sai ở đâu cho người dùng dễ sửa?

> Bắt buộc theo chuẩn HTTP (RFC 6750) để chỉ dẫn phương thức xác thực. Trả cùng một lỗi giúp chống timing/enumeration attack.

---

### Câu 7 — Token bucket (CP3)

Với `capacity=10`, `refill_per_minute=10`: một client im lặng 10 phút rồi gửi
liên tiếp. Nó gửi được bao nhiêu request trước khi bị 429? Nếu bỏ đoạn
`min(capacity, ...)` trong `available()` thì con số đó thành bao nhiêu, và tại sao?

> Gửi liên tiếp 10 request. Nếu bỏ `min(capacity, ...)`, token tích lên vô hạn (ví dụ 100), client có thể gửi 100 request một lúc, làm mất tác dụng của rate limit.

---

### Câu 8 — Ngân sách theo ngày (CP3)

So sánh hạn mức $30/tháng với hạn mức $1/ngày cho cùng một client. Giả sử có sự
cố khiến một client gọi liên tục từ 2h sáng. Với mỗi cách, thiệt hại tối đa là
bao nhiêu và service tự hồi phục khi nào?

> Sự cố lúc 2h sáng sẽ đốt sạch $30/tháng ngay. Nếu hạn mức $1/ngày, thiệt hại tối đa $1 và ngày hôm sau service hoạt động lại bình thường.

---

### Câu 9 — /healthz khác /readyz (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Khi Redis mất kết nối, /healthz của 3 container đều báo lỗi. Orchestrator lầm tưởng 3 container treo nên restart cả 3, làm sập toàn bộ hệ thống thay vì chờ Redis sống lại.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> Lỗi: Container crash do thiếu biến `API_TOKEN`.
> Tìm nguyên nhân: Xem log trên dashboard của platform.
> Cách sửa: Thêm biến `API_TOKEN` với giá trị bí mật và deploy lại.
