# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization
#
# Dưới đây là Dockerfile "chạy được nhưng chưa production": một stage,
# chạy bằng user root, không có health check, base image nặng.
#
# NHIỆM VỤ: sửa file này thành bản production-ready. Yêu cầu:
#   [ ] Multi-stage build: stage `builder` cài dependency, stage runtime
#       chỉ copy kết quả sang → image nhỏ hơn, không mang theo compiler.
#       Cú pháp: `FROM python:3.11-slim AS builder`
#   [ ] Base image slim (hoặc alpine), không dùng `python:3.11` bản đầy đủ
#   [ ] COPY requirements.txt và pip install TRƯỚC khi COPY source code
#       (Docker cache theo layer: sửa 1 dòng code không phải cài lại thư viện)
#   [ ] Tạo user thường và chuyển sang bằng lệnh `USER` — container chạy
#       root nghĩa là ai thoát được khỏi app cũng thành root trên host
#   [ ] Có `HEALTHCHECK` gọi vào endpoint /healthz
#   [ ] Đọc cổng từ biến môi trường PORT (cloud tự gán cổng, không cố định 8000)
#
# Đích cần đạt: image dưới 400MB (bản một stage dưới đây khoảng 1.8GB).
#
# Kiểm tra:  pytest tests/test_cp2.py -v
# Build thử: docker build -t day12-chat:prod .
#            docker images day12-chat:prod     # xem dung lượng
# ═══════════════════════════════════════════════════════════════════

# Stage 1: builder - Biên dịch và cài đặt thư viện
FROM python:3.11-slim AS builder

WORKDIR /install

# Chỉ copy requirements.txt trước để tận dụng Docker cache
COPY requirements.txt .

# Cài đặt thư viện vào thư mục /install
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: runtime - Môi trường chạy thực tế, nhỏ gọn
FROM python:3.11-slim AS runtime

WORKDIR /app

# Copy các thư viện đã được cài đặt từ stage builder
COPY --from=builder /install /usr/local

# Copy mã nguồn dự án
COPY . .

# Tạo user thường để chạy ứng dụng (bảo mật)
RUN useradd --create-home --uid 10001 appuser
USER appuser

# Healthcheck để Docker biết ứng dụng có đang sống không
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:${PORT:-8000}/healthz').read()" || exit 1

EXPOSE 8000

CMD ["python", "app/main.py"]
