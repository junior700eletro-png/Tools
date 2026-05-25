import requests
import json
import time
from datetime import datetime
from typing import Dict, Any

class AdaptaSystemTester:
    """Testa todos os componentes do sistema Adapta ONE"""
    
    def __init__(self):
        self.backend_url = "http://localhost:5000"
        self.frontend_url = "http://localhost:8000"
        self.results = []
        self.passed = 0
        self.failed = 0
    
    def print_header(self, text: str):
        """Imprime cabeçalho formatado"""
        print("\n" + "="*70)
        print(f"  {text}")
        print("="*70)
    
    def print_test(self, name: str, status: str, message: str = ""):
        """Imprime resultado de teste"""
        icon = "✅" if status == "PASS" else "❌"
        print(f"{icon} {name}")
        if message:
            print(f"   └─ {message}")
        
        if status == "PASS":
            self.passed += 1
        else:
            self.failed += 1
        
        self.results.append({
            'test': name,
            'status': status,
            'message': message,
            'timestamp': datetime.now().isoformat()
        })
    
    def test_backend_connection(self) -> bool:
        """Testa conexão com backend"""
        self.print_header("1️⃣  TESTE DE CONEXÃO COM BACKEND")
        
        try:
            response = requests.get(f"{self.backend_url}/api/health", timeout=5)
            if response.status_code == 200:
                data = response.json()
                self.print_test(
                    "Conexão com Backend",
                    "PASS",
                    f"Status: {data.get('status')} | IA Models: {data.get('ai_models_available')} | IA Integration: {data.get('ia_integration_available')}"
                )
                return True
            else:
                self.print_test("Conexão com Backend", "FAIL", f"Status Code: {response.status_code}")
                return False
        except Exception as e:
            self.print_test("Conexão com Backend", "FAIL", str(e))
            return False
    
    def test_frontend_connection(self) -> bool:
        """Testa conexão com frontend"""
        self.print_header("2️⃣  TESTE DE CONEXÃO COM FRONTEND")
        
        try:
            response = requests.get(f"{self.frontend_url}/index.html", timeout=5)
            if response.status_code == 200:
                self.print_test(
                    "Conexão com Frontend",
                    "PASS",
                    f"Arquivo index.html carregado ({len(response.content)} bytes)"
                )
                return True
            else:
                self.print_test("Conexão com Frontend", "FAIL", f"Status Code: {response.status_code}")
                return False
        except Exception as e:
            self.print_test("Conexão com Frontend", "FAIL", str(e))
            return False
    
    def test_ai_models(self) -> bool:
        """Testa disponibilidade dos modelos de IA"""
        self.print_header("3️⃣  TESTE DE MODELOS DE IA")
        
        try:
            response_voice = requests.get(f"{self.backend_url}/api/voice/status", timeout=5)
            if response_voice.status_code == 200:
                voice_status = response_voice.json().get('status')
                self.print_test("Modelo de Voz", "PASS", f"Status: {voice_status}")
            else:
                self.print_test("Modelo de Voz", "FAIL", f"Status Code: {response_voice.status_code}")
            
            response_vision = requests.get(f"{self.backend_url}/api/vision/status", timeout=5)
            if response_vision.status_code == 200:
                vision_status = response_vision.json().get('status')
                self.print_test("Modelo de Visão", "PASS", f"Status: {vision_status}")
                return True
            else:
                self.print_test("Modelo de Visão", "FAIL", f"Status Code: {response_vision.status_code}")
                return False
        except Exception as e:
            self.print_test("Modelos de IA", "FAIL", str(e))
            return False
    
    def test_ia_integration(self) -> bool:
        """Testa integração de IA"""
        self.print_header("4️⃣  TESTE DE INTEGRAÇÃO DE IA")
        
        try:
            response_status = requests.get(f"{self.backend_url}/api/ia/status", timeout=5)
            if response_status.status_code == 200:
                ia_status = response_status.json().get('status')
                self.print_test("Status da IA", "PASS", f"Status: {ia_status}")
            else:
                self.print_test("Status da IA", "FAIL", f"Status Code: {response_status.status_code}")
                return False
            
            payload = {
                "text": "Olá, como você está?",
                "context": {}
            }
            response_message = requests.post(
                f"{self.backend_url}/api/ia/message",
                json=payload,
                timeout=5
            )
            if response_message.status_code == 200:
                data = response_message.json()
                self.print_test(
                    "Envio de Mensagem",
                    "PASS",
                    f"Resposta: {data.get('text')[:50]}..."
                )
                return True
            else:
                self.print_test("Envio de Mensagem", "FAIL", f"Status Code: {response_message.status_code}")
                return False
        except Exception as e:
            self.print_test("Integração de IA", "FAIL", str(e))
            return False
    
    def test_api_routes(self) -> bool:
        """Testa rotas principais da API"""
        self.print_header("5️⃣  TESTE DE ROTAS DA API")
        
        routes = [
            ("/api/status", "GET", None, "Status da Interface"),
            ("/api/health", "GET", None, "Health Check"),
            ("/api/ia/history", "GET", None, "Histórico de IA"),
            ("/api/voice/status", "GET", None, "Status de Voz"),
            ("/api/vision/status", "GET", None, "Status de Visão"),
        ]
        
        all_passed = True
        for route, method, payload, description in routes:
            try:
                if method == "GET":
                    response = requests.get(f"{self.backend_url}{route}", timeout=5)
                else:
                    response = requests.post(f"{self.backend_url}{route}", json=payload, timeout=5)
                
                if response.status_code in [200, 201, 503]:
                    self.print_test(f"Rota {route}", "PASS", f"{description}")
                else:
                    self.print_test(f"Rota {route}", "FAIL", f"Status Code: {response.status_code}")
                    all_passed = False
            except Exception as e:
                self.print_test(f"Rota {route}", "FAIL", str(e))
                all_passed = False
        
        return all_passed
    
    def test_multimodal_processing(self) -> bool:
        """Testa processamento multimodal"""
        self.print_header("6️⃣  TESTE DE PROCESSAMENTO MULTIMODAL")
        
        try:
            payload = {
                "voice_text": "Detectei um rosto na câmera",
                "vision_data": {"faces_detected": 1},
                "screen_data": "Captura de tela processada"
            }
            response = requests.post(
                f"{self.backend_url}/api/ia/multimodal",
                json=payload,
                timeout=5
            )
            if response.status_code == 200:
                data = response.json()
                self.print_test(
                    "Processamento Multimodal",
                    "PASS",
                    f"Resposta: {data.get('text')[:50]}..."
                )
                return True
            else:
                self.print_test("Processamento Multimodal", "FAIL", f"Status Code: {response.status_code}")
                return False
        except Exception as e:
            self.print_test("Processamento Multimodal", "FAIL", str(e))
            return False
    
    def print_summary(self):
        """Imprime resumo dos testes"""
        self.print_header("📊 RESUMO DOS TESTES")
        
        total = self.passed + self.failed
        percentage = (self.passed / total * 100) if total > 0 else 0
        
        print(f"\n✅ Testes Passados: {self.passed}")
        print(f"❌ Testes Falhados: {self.failed}")
        print(f"📈 Taxa de Sucesso: {percentage:.1f}%")
        print(f"⏱️  Timestamp: {datetime.now().isoformat()}")
        
        print("\n" + "="*70)
        if self.failed == 0:
            print("🎉 TODOS OS TESTES PASSARAM! Sistema pronto para uso.")
        else:
            print(f"⚠️  {self.failed} teste(s) falharam. Verifique os logs acima.")
        print("="*70 + "\n")
    
    def run_all_tests(self):
        """Executa todos os testes"""
        print("\n")
        print("╔════════════════════════════════════════════════════════════════════╗")
        print("║                                                                    ║")
        print("║        🧠 ADAPTA ONE - TESTE COMPLETO DO SISTEMA 🧠              ║")
        print("║                                                                    ║")
        print("╚════════════════════════════════════════════════════════════════════╝")
        
        print("\n⏳ Aguardando 3 segundos para garantir que os servidores estão prontos...")
        time.sleep(3)
        
        self.test_backend_connection()
        time.sleep(1)
        
        self.test_frontend_connection()
        time.sleep(1)
        
        self.test_ai_models()
        time.sleep(1)
        
        self.test_ia_integration()
        time.sleep(1)
        
        self.test_api_routes()
        time.sleep(1)
        
        self.test_multimodal_processing()
        
        self.print_summary()
        
        self.save_results()
    
    def save_results(self):
        """Salva resultados dos testes em arquivo JSON"""
        try:
            with open('test_results.json', 'w', encoding='utf-8') as f:
                json.dump({
                    'timestamp': datetime.now().isoformat(),
                    'passed': self.passed,
                    'failed': self.failed,
                    'results': self.results
                }, f, indent=2, ensure_ascii=False)
            print(f"📄 Resultados salvos em: test_results.json")
        except Exception as e:
            print(f"⚠️  Erro ao salvar resultados: {str(e)}")


if __name__ == '__main__':
    tester = AdaptaSystemTester()
    tester.run_all_tests()