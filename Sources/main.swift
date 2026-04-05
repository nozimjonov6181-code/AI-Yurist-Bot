import Foundation

let telegramToken = "8619856731:AAFfs0IZhdC0N5vA03uxNY4yicEw3ehxkS8"
// DIQQAT: Shu yerga YANgi (4-chi) API kalitni qo'y. U faqat botning ishlashi uchun xizmat qiladi!
let geminiApiKey = "AIzaSyAHpmRUe5zGdOAIA7NyzNNJp_I_KX6Z0Lk"
let pineconeApiKey = "pcsk_2oUVQd_6G3fz1moamV6mqbGRdUU2B5Tqk4XTeqdSs8JgGTGGkECPkt6y8a5tP3xx2DKh57"
let pineconeHost = "https://yurist-pro-cwgplja.svc.aped-4627-b74a.pinecone.io"

var offset = 0

print("🚀 AI-Yurist Bot ishga tushmoqda...")

// 1. Mijoz savolini vektorga aylantirish (Ayg'oqchi bilan)
func embedQuestion(_ text: String) async throws -> [Double] {
    let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=\(geminiApiKey)")!
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.addValue("application/json", forHTTPHeaderField: "Content-Type")
    let body: [String: Any] = ["model": "models/gemini-embedding-001", "content": ["parts": [["text": text]]]]
    req.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    let (data, _) = try await URLSession.shared.data(for: req)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    
    // AYG'OQCHI: Agar Gemini xato bersa, uni konsolga chiqaramiz
    if let errorObj = json?["error"] as? [String: Any] {
        let errorMsg = errorObj["message"] as? String ?? "Noma'lum xato"
        print("\n🚨 GEMINI SAVOLNI VEKTORGA AYLANTIRIShDA XATO QILDI: \n\(errorMsg)\n")
        throw NSError(domain: "Gemini", code: 2, userInfo: [NSLocalizedDescriptionKey: "Gemini limiti yoki kalit xatosi"])
    }
    
    guard let embedding = json?["embedding"] as? [String: Any], let values = embedding["values"] as? [Double] else {
        print("\n🚨 NOMA'LUM JAVOB: \(String(data: data, encoding: .utf8) ?? "")\n")
        throw NSError(domain: "Gemini", code: 1, userInfo: [NSLocalizedDescriptionKey: "Vektor formati xato"])
    }
    return values
}

// 2. Pinecone bazasidan savolga eng mos keluvchi Top-3 ta qonunni izlash
func searchPinecone(vector: [Double]) async throws -> String {
    let url = URL(string: "\(pineconeHost)/query")!
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.addValue("application/json", forHTTPHeaderField: "Content-Type")
    req.addValue(pineconeApiKey, forHTTPHeaderField: "Api-Key")
    
    let body: [String: Any] = [
        "vector": vector,
        "topK": 3,
        "includeMetadata": true
    ]
    req.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    let (data, _) = try await URLSession.shared.data(for: req)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    guard let matches = json?["matches"] as? [[String: Any]] else { return "" }
    
    var foundContext = ""
    for match in matches {
        if let metadata = match["metadata"] as? [String: Any], let text = metadata["text"] as? String {
            foundContext += text + "\n\n"
        }
    }
    return foundContext
}

// 3. Topilgan qonunlarga asoslanib Gemini orqali aqlli va xalqchil javob yasash
func generateAnswer(question: String, context: String, chatId: Int) async {
    let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(geminiApiKey)"
    guard let url = URL(string: urlString) else { return }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let prompt = """
    Sen O'zbekiston kichik va o'rta biznesi (SME) uchun professional yuridik maslahatchisan.
    Faqat quyidagi HUQUQIY BAZA ma'lumotlaridan foydalanib savolga aniq va to'liq javob ber. 
    Agar javob bazada umuman yo'q bo'lsa, o'zingdan qonun to'qima va "Kechirasiz, mening bazamda bu haqida ma'lumot yo'q" deb ayt.
    
    HUQUQIY BAZA:
    \(context)
    
    FOYDALANUVCHI SAVOLI:
    \(question)
    """
    
    let body: [String: Any] = ["contents": [["parts": [["text": prompt]]]]]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    
    do {
        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = json["candidates"] as? [[String: Any]],
           let firstPart = (candidates.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]],
           let aiText = firstPart.first?["text"] as? String {
            await sendMessage(chatId: chatId, text: aiText)
        } else {
            await sendMessage(chatId: chatId, text: "AI javob berishda xatolikka yo'l qo'ydi.")
        }
    } catch {
        await sendMessage(chatId: chatId, text: "Tarmoq xatosi yuz berdi.")
    }
}

// 4. Telegramga xabar yuborish
func sendMessage(chatId: Int, text: String) async {
    let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    let urlStr = "https://api.telegram.org/bot\(telegramToken)/sendMessage?chat_id=\(chatId)&text=\(encodedText)"
    guard let url = URL(string: urlStr) else { return }
    let _ = try? await URLSession.shared.data(from: url)
}

// 5. Telegramdan kelayotgan xabarlarni eshitish
func startBot() async {
    print("✅ Bot ishlashga tayyor! Telegramdan yuridik savol yozishingiz mumkin.")
    while true {
        let urlStr = "https://api.telegram.org/bot\(telegramToken)/getUpdates?offset=\(offset)&timeout=10"
        guard let url = URL(string: urlStr) else { continue }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["result"] as? [[String: Any]] {
                for update in result {
                    if let updateId = update["update_id"] as? Int { offset = updateId + 1 }
                    if let msg = update["message"] as? [String: Any],
                       let text = msg["text"] as? String,
                       let chat = msg["chat"] as? [String: Any],
                       let chatId = chat["id"] as? Int {
                        
                        print("📩 Yangi savol: \(text)")
                        await sendMessage(chatId: chatId, text: "⏳ Baza qidirilmoqda. Iltimos kuting...")
                        
                        // RAG jarayoni: Savol -> Vektor -> Qidiruv -> AI Javobi
                        do {
                            let questionVector = try await embedQuestion(text)
                            let context = try await searchPinecone(vector: questionVector)
                            
                            if context.isEmpty {
                                await sendMessage(chatId: chatId, text: "Kechirasiz, so'rovingiz bo'yicha bazadan huquqiy matn topilmadi.")
                            } else {
                                await generateAnswer(question: text, context: context, chatId: chatId)
                            }
                        } catch {
                            await sendMessage(chatId: chatId, text: "Qidiruv tizimida xatolik yuz berdi: \(error.localizedDescription)")
                        }
                    }
                }
            }
        } catch {
            print("Tarmoq bilan ulanish kutilmoqda...")
        }
        
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
}

Task {
    await startBot()
}

RunLoop.main.run()
