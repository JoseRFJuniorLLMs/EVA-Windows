import os
from google import genai
from pathlib import Path

# Setup Gemini 3 Pro Preview
API_KEY = "AIzaSyBlem2g_EFVLTt3Fb1AofF1EOAf05YPo3U"
client = genai.Client(api_key=API_KEY)
MODEL_NAME = 'gemini-3-pro-preview'

MOBILE_PATH = Path("d:/DEV/EVA-Mobile-FZPN")
WINDOWS_PATH = Path("d:/DEV/EVA-Windows")

def get_context():
    content = ""
    # Blueprint for Windows
    with open(WINDOWS_PATH / "fazer.txt", 'r', encoding='utf-8') as f:
        content += "\n\n--- FILE: EVA-Windows/fazer.txt (Migration Guide) ---\n"
        content += f.read()

    # Mobile Core Audio Logic
    mobile_files = [
        'lib/data/services/native_audio_service.dart',
        'lib/core/safety/audio_capture_service.dart'
    ]
    for target in mobile_files:
        file_path = MOBILE_PATH / target
        if file_path.exists():
            with open(file_path, 'r', encoding='utf-8') as f:
                content += f"\n\n--- FILE: EVA-Mobile/{target} ---\n"
                content += f.read()
    return content

def run_project_implementation():
    print(f"Tasking {MODEL_NAME} to implement the COMPLETE EVA-Windows project...")
    context = get_context()
    
    prompt = f"""
Você é o Gemini 3 "Arquiteto Sênior de Software e Especialista em Flutter Desktop". 
Sua missão é criar o projeto COMPLETO 'EVA-Windows'.

CONTEXTO (Guia de Migração + Lógica Mobile):
{context}

OBJETIVO:
Implementar um assistente virtual nativo para Windows que usa a API Gemini Multimodal Live (voz-para-voz).

REQUISITOS TÉCNICOS OBRIGATÓRIOS (Baseados no doc `fazer.txt`):
1. **Ambiente:** Flutter Desktop (Windows).
2. **UI Nativa:** Janela customizada usando `bitsdojo_window`.
3. **Core de Áudio:** 
   - Entrada: `record` (Captura PCM 16kHz).
   - Saída: `flutter_soloud` (Motor de áudio de baixa latência).
4. **Avatar:** Suporte a animação **Rive** sincronizada com a fala (mouth intensity mapping).
5. **Comunicação:** WebSocket para streaming de áudio bidirecional.

VOCÊ DEVE GERAR O CÓDIGO COMPLETO PARA OS SEGUINTES ARQUIVOS:
- `pubspec.yaml` (Dependências desktop corretas).
- `lib/main.dart` (Configuração de janela e service locator).
- `lib/services/audio_service_windows.dart` (O coração do sistema de som).
- `lib/services/websocket_service.dart` (Streaming de bytes).
- `lib/presentation/widgets/avatar_widget.dart` (Controle do Rive).
- `lib/presentation/screens/desktop_home.dart` (UI principal assistente).

PENSE PASSO A PASSO. Garanta que o código para Windows use as APIs corretas e evite WebViews.
Forneça os arquivos em blocos Markdown claros.
"""

    response = client.models.generate_content(
        model=MODEL_NAME,
        contents=prompt
    )
    
    with open(WINDOWS_PATH / "gemini_3_full_implementation.md", 'w', encoding='utf-8') as f:
        f.write(response.text)
    
    print(f"EVA-Windows implementation generated! Check 'gemini_3_full_implementation.md'.")

if __name__ == "__main__":
    run_project_implementation()
