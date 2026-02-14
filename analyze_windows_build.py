import os
import google.generativeai as genai

# Configuração
API_KEY = "AIzaSyBlem2g_EFVLTt3Fb1AofF1EOAf05YPo3U"
MODEL_NAME = "gemini-3-pro-preview"

def analyze_build_log(log_path):
    # Carregar o log
    if not os.path.exists(log_path):
        print(f"❌ Log file not found at {log_path}")
        return

    print(f"📂 Reading log file: {log_path}...")
    with open(log_path, "r", encoding="utf-8", errors="ignore") as f:
        log_content = f.read()

    # Inicializar Gemini
    genai.configure(api_key=API_KEY)
    model = genai.GenerativeModel(MODEL_NAME)

    prompt = f"""
Você é um Engenheiro de Compilação Sênior com especialidade em Flutter (Windows) e C++ nativo (Visual Studio).

TAREFA:
Analise o log de erro abaixo proveniente de um build do Flutter Windows (`flutter build windows --release`).
O desenvolvedor tentou remover o plugin `flutter_soloud` para evitar erros de compilação nativa, mas o build ainda falha.

LOG DE ERRO:
{log_content[-30000:]} # Enviando os últimos 30k caracteres para focar no erro

IDENTIFIQUE:
1. Por que a compilação ainda está falhando mesmo após remover o plugin problemático?
2. Existem referências fantasmas no CMake ou no Gradle?
3. Faltam ferramentas no ambiente (MSBuild, CMake, Visual Studio Build Tools)?
4. Sugira o comando EXATO ou a mudança de arquivo para consertar isso e gerar o .exe.

RESPOSTA EM PORTUGUÊS:
"""

    print("🧠 Consultando Gemini 3 na GCP (Vertex AI)...")
    try:
        response = model.generate_content(prompt)
        print("\n=== ANÁLISE DO GEMINI ===\n")
        print(response.text)
        
        with open("SOLUCAO_BUILD_WINDOWS.md", "w", encoding="utf-8") as f:
            f.write(response.text)
        print("\n✅ Solução salva em SOLUCAO_BUILD_WINDOWS.md")
        
    except Exception as e:
        print(f"❌ Erro ao consultar Gemini: {e}")

if __name__ == "__main__":
    analyze_build_log("/home/web2a/windows_build_failure.log")
