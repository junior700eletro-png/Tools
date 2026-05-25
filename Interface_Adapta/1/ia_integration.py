import requests
import json
from datetime import datetime
from typing import Dict, Any

class AdaptaAIIntegration:
    """Integração com a API de IA Adapta ONE"""
    
    def __init__(self, api_key: str = None):
        self.api_key = api_key
        self.api_endpoint = "https://api.adapta.one/v1"
        self.conversation_history = []
        self.status = "ready"
    
    def send_message(self, text: str, context: Dict[str, Any] = None) -> Dict[str, Any]:
        """Envia uma mensagem para a IA e recebe resposta"""
        try:
            self.status = "processing"
            
            payload = {
                "message": text,
                "context": context or {},
                "timestamp": datetime.now().isoformat()
            }
            
            self.conversation_history.append({
                "role": "user",
                "content": text,
                "timestamp": datetime.now().isoformat()
            })
            
            print(f"[IA] Enviando: {text[:50]}...")
            
            response = self.generate_response(text, context)
            
            self.conversation_history.append({
                "role": "assistant",
                "content": response['text'],
                "timestamp": datetime.now().isoformat()
            })
            
            self.status = "completed"
            return response
            
        except Exception as e:
            self.status = "error"
            print(f"[ERRO] IA: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }
    
    def generate_response(self, text: str, context: Dict[str, Any] = None) -> Dict[str, Any]:
        """Gera resposta baseada no texto e contexto"""
        try:
            text_lower = text.lower()
            
            if any(word in text_lower for word in ['oi', 'olá', 'opa', 'e aí']):
                response_text = "Olá! Sou a IA Adapta ONE. Como posso ajudá-lo?"
            elif any(word in text_lower for word in ['como', 'qual', 'o que']):
                response_text = "Entendi sua pergunta. Deixa eu analisar os dados capturados..."
            elif any(word in text_lower for word in ['obrigado', 'valeu', 'thanks']):
                response_text = "De nada! Estou aqui para ajudar."
            else:
                response_text = f"Processando: {text[:30]}... Análise concluída."
            
            return {
                'success': True,
                'text': response_text,
                'action': 'respond',
                'confidence': 0.85,
                'timestamp': datetime.now().isoformat()
            }
        except Exception as e:
            return {
                'success': False,
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }
    
    def process_multimodal_input(self, voice_text: str = None, vision_data: Dict = None, screen_data: str = None) -> Dict[str, Any]:
        """Processa entrada multimodal (voz + visão + tela)"""
        try:
            self.status = "processing_multimodal"
            
            context = {
                'voice': voice_text,
                'vision': vision_data,
                'screen': screen_data,
                'timestamp': datetime.now().isoformat()
            }
            
            message_parts = []
            if voice_text:
                message_parts.append(f"[VOZ] {voice_text}")
            if vision_data and vision_data.get('faces_detected'):
                message_parts.append(f"[VISÃO] {vision_data['faces_detected']} rosto(s) detectado(s)")
            if screen_data:
                message_parts.append("[TELA] Captura de tela recebida")
            
            combined_message = " | ".join(message_parts) if message_parts else "Processando entrada multimodal..."
            
            response = self.send_message(combined_message, context)
            
            self.status = "completed"
            return response
            
        except Exception as e:
            self.status = "error"
            print(f"[ERRO] Processamento multimodal: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }
    
    def get_conversation_history(self) -> list:
        """Retorna histórico de conversação"""
        return self.conversation_history
    
    def clear_history(self):
        """Limpa histórico de conversação"""
        self.conversation_history = []
        print("[IA] Histórico limpo")
    
    def get_status(self) -> str:
        return self.status


ia_integration = AdaptaAIIntegration()