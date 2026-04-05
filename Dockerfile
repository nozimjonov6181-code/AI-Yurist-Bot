# 1. Serverga rasmiy Swift tizimini o'rnatishni buyuramiz
FROM swift:5.9

# 2. Ishchi papka yaratamiz
WORKDIR /app

# 3. Barcha kodlarni serverga nusxalaymiz
COPY . .

# 4. Kodingizni xatosiz yig'ish (Build qilish)
RUN swift build -c release

# 5. Tayyor bo'lgan botni ishga tushirish
CMD [".build/release/YuristBot"]
