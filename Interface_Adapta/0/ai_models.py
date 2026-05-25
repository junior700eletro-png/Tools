import speech_recognition as sr
import cv2
import numpy as np
from PIL import Image
import io
import base64
from datetime import datetime

class VoiceModel:
    """Modelo de reconhecimento de voz"""
    
    def __init__(self):
        self.recognizer = sr.Recognizer()
        try:
            self.microphone = sr.Microphone()
            self.status = "ready"
        except Exception as e:
            print(f"[VOZ] Aviso: Microfone não disponível - {str(e)}")
            self.microphone = None
            self.status = "unavailable"
    
    def listen(self, timeout=5):
        """Escuta áudio do microfone e converte para texto"""
        if self.microphone is None:
            return {
                'success': False,
                'error': 'Microfone não disponível',
                'timestamp': datetime.now().isoformat()
            }
        
        try:
            self.status = "listening"
            with self.microphone as source:
                print("[VOZ] Escutando...")
                audio = self.recognizer.listen(source, timeout=timeout)
            
            text = self.recognizer.recognize_google(audio, language='pt-BR')
            self.status = "recognized"
            print(f"[VOZ] Reconhecido: {text}")
            return {
                'success': True,
                'text': text,
                'confidence': 0.95,
                'timestamp': datetime.now().isoformat()
            }
        except sr.UnknownValueError:
            self.status = "error"
            return {
                'success': False,
                'error': 'Não consegui entender o áudio',
                'timestamp': datetime.now().isoformat()
            }
        except sr.RequestError as e:
            self.status = "error"
            return {
                'success': False,
                'error': f'Erro no serviço: {str(e)}',
                'timestamp': datetime.now().isoformat()
            }
        except Exception as e:
            self.status = "error"
            return {
                'success': False,
                'error': f'Erro desconhecido: {str(e)}',
                'timestamp': datetime.now().isoformat()
            }
    
    def get_status(self):
        return self.status


class VisionModel:
    """Modelo de visão computacional"""
    
    def __init__(self):
        self.status = "ready"
        try:
            self.cascade = cv2.CascadeClassifier(
                cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
            )
            print("[VISÃO] Modelo de detecção de rostos carregado")
        except Exception as e:
            print(f"[VISÃO] Erro ao carregar modelo: {str(e)}")
            self.cascade = None
            self.status = "error"
    
    def detect_faces(self, image_data):
        """Detecta rostos em uma imagem"""
        if self.cascade is None:
            return {
                'success': False,
                'error': 'Modelo não disponível',
                'timestamp': datetime.now().isoformat()
            }
        
        try:
            self.status = "processing"
            
            if isinstance(image_data, str):
                if ',' in image_data:
                    image_data = image_data.split(',')[1]
                image_data = base64.b64decode(image_data)
            
            nparr = np.frombuffer(image_data, np.uint8)
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            if img is None:
                return {
                    'success': False,
                    'error': 'Não consegui decodificar a imagem',
                    'timestamp': datetime.now().isoformat()
                }
            
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            
            faces = self.cascade.detectMultiScale(gray, 1.3, 5)
            
            self.status = "completed"
            
            print(f"[VISÃO] {len(faces)} rosto(s) detectado(s)")
            
            return {
                'success': True,
                'faces_detected': len(faces),
                'face_coordinates': faces.tolist(),
                'timestamp': datetime.now().isoformat()
            }
        except Exception as e:
            self.status = "error"
            print(f"[VISÃO] Erro na detecção de rostos: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }
    
    def detect_objects(self, image_data):
        """Detecta objetos em uma imagem"""
        try:
            self.status = "processing"
            
            if isinstance(image_data, str):
                if ',' in image_data:
                    image_data = image_data.split(',')[1]
                image_data = base64.b64decode(image_data)
            
            nparr = np.frombuffer(image_data, np.uint8)
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            if img is None:
                return {
                    'success': False,
                    'error': 'Não consegui decodificar a imagem',
                    'timestamp': datetime.now().isoformat()
                }
            
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            edges = cv2.Canny(gray, 100, 200)
            contours, _ = cv2.findContours(edges, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
            
            self.status = "completed"
            
            print(f"[VISÃO] {len(contours)} objeto(s) detectado(s)")
            
            return {
                'success': True,
                'objects_detected': len(contours),
                'image_shape': img.shape,
                'timestamp': datetime.now().isoformat()
            }
        except Exception as e:
            self.status = "error"
            print(f"[VISÃO] Erro na detecção de objetos: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }
    
    def get_status(self):
        return self.status


print("[INIT] Inicializando modelos de IA...")
voice_model = VoiceModel()
vision_model = VisionModel()
print("[INIT] Modelos carregados com sucesso!")