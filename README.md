# 🛠️ System Automation & Security Audit Tools

O colecție de scripturi avansate pentru eficientizarea fluxurilor de lucru în Linux, monitorizarea resurselor hardware și testarea vulnerabilităților de securitate.

## 🚀 Categorii Principale

### 🔍 Security & Research (PoC)
* **Ticket Auditor:** Utilitar pentru identificarea vulnerabilităților de tip IDOR/Enumerare în sisteme de ticketing.
* **Proxy Checker:** Script de validare automată pentru proxy-uri HTTP (disponibilitate și latență).
* **Instant Share:** Generare rapidă de tuneluri publice (ngrok) cu acces prin QR code.

### 🤖 AI & Productivity
* **OCR-GPT Assistant:** Captură de ecran cu procesare ImageMagick și interogare automată LLM (Tesseract + GPT).
* **Ollama Batcher:** Gestionarea și descărcarea automată a modelelor AI locale.
* **Exam Helper:** Sistem de căutare fuzzy în baze de date locale folosind regex-uri complexe.

### ⚙️ System & Hardware Management
* **Network Diagnoser:** Enumerare avansată a interfețelor WiFi/Ethernet, DNS și Gateway.
* **BT-Manager:** Control granular pentru serviciile Bluetooth și conexiuni automate la device-uri (ATH/RCA).
* **IO-Bench:** Benchmark riguros pentru vitezele de citire/scriere (Workload 1GB).
* **Sysmon:** Monitorizarea în timp real a frecvenței CPU, RAM și stocării.

## 🛠️ Tech Stack & Dependencies
* **Shell:** Zsh / Bash
* **Data Processing:** `awk`, `sed`, `ripgrep`, `jq`
* **Tools:** `tesseract-ocr`, `xdotool`, `imagemagick`, `spectacle`, `curl`

## 🛡️ Security Focused
Toate scripturile sunt concepute cu accent pe **Security Considerations**, incluzând:
- Sanitizarea input-ului pentru prevenirea command injection.
- Gestionarea sigură a fișierelor temporare (`mktemp` & `trap`).
- Limitarea privilegiilor și utilizarea responsabilă a `sudo`.

---
*Acest depozit demonstrează abilități de automatizare, securitate ofensivă/defensivă și administrare avansată de sisteme Linux.*
