from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import base64
from datetime import datetime
import os
import sys

try:
    from ai_models import voice_model, vision_model
    AI_MODELS_AVAILABLE = True
except ImportError:
    AI_MODELS_AVAILABLE = False
    print("⚠️  Aviso: Modelos de IA não disponíveis")

try:
    from ia_integration import ia_integration
    IA_INTEGRATION_AVAILABLE = True
except ImportError:
    IA_INTEGRATION_AVAILABLE = False
    print("⚠️  Aviso: Integração de IA não disponível")

app = Flask(__name__)
CORS(app)

interface_state = {
    "screen_capture": None,
    "audio_data": None,
    "video_frame": None,
    "interactions": [],
    "ai_response": None,
    "status": "idle",
    "voice_status": "idle",
    "vision_status": "idle"
}


@app.route('/api/status', methods=['GET'])
def get_status():
    """Retorna o status atual da interface"""
    return jsonify(interface_state)

@app.route('/api/health', methods=['GET'])
def health_check():
    """Verifica saúde do servidor"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'ai_models_available': AI_MODELS_AVAILABLE,
        'ia_integration_available': IA_INTEGRATION_AVAILABLE
    })


@app.route('/api/screen-capture', methods=['POST'])
def receive_screen_capture():
    """Recebe dados de captura de tela"""
    try:
        data = request.json
        interface_state['screen_capture'] = {
            'timestamp': datetime.now().isoformat(),
            'data': data.get('image')[:100] + '...' if data.get('image') else None
        }
        interface_state['status'] = 'screen_captured'
        print(f"[TELA] Captura recebida em {interface_state['screen_capture']['timestamp']}")
        return jsonify({'success': True, 'message': 'Screen capture received'})
    except Exception as e:
        print(f"[ERRO] Captura de tela: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 400

@app.route('/api/audio', methods=['POST'])
def receive_audio():
    """Recebe dados de áudio"""
    try:
        data = request.json
        interface_state['audio_data'] = {
            'timestamp': datetime.now().isoformat(),
            'duration': data.get('duration'),
            'frequency': data.get('frequency')
        }
        interface_state['status'] = 'audio_captured'
        print(f"[ÁUDIO] Áudio recebido: {data.get('duration')}s @ {data.get('frequency')}Hz")
        return jsonify({'success': True, 'message': 'Audio received'})
    except Exception as e:
        print(f"[ERRO] Áudio: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 400

@app.route('/api/video-frame', methods=['POST'])
def receive_video_frame():
    """Recebe frames de vídeo"""
    try:
        data = request.json
        interface_state['video_frame'] = {
            'timestamp': datetime.now().isoformat(),
            'width': data.get('width'),
            'height': data.get('height')
        }
        interface_state['status'] = 'video_captured'
        print(f"[VÍDEO] Frame recebido: {data.get('width')}x{data.get('height')}")
        return jsonify({'success': True, 'message': 'Video frame received'})
    except Exception as e:
        print(f"[ERRO] Vídeo: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 400

@app.route('/api/interaction', methods=['POST'])
def receive_interaction():
    """Recebe eventos de interação"""
    try:
        data = request.json
        interaction = {
            'timestamp': datetime.now().isoformat(),
            'type': data.get('type'),
            'element': data.get('element'),
            'value': data.get('value')
        }
        interface_state['interactions'].append(interaction)
        interface_state['status'] = 'interaction_received'
        print(f"[INTERAÇÃO] {data.get('type')} em {data.get('element')}")
        return jsonify({'success': True, 'message': 'Interaction received'})
    except Exception as e:
        print(f"[ERRO] Interação: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 400


@app.route('/api/ai-response', methods=['POST'])
def send_ai_response():
    """Recebe resposta da IA e a armazena"""
    try:
        data = request.json
        interface_state['ai_response'] = {
            'timestamp': datetime.now().isoformat(),
            'text': data.get('text'),
            'action': data.get('action')
        }
        interface_state['status'] = 'ai_responded'
        print(f"[IA] Resposta: {data.get('text')[:50]}...")
        return jsonify({'success': True, 'message': 'AI response received'})
    except Exception as e:
        print(f"[ERRO] Resposta IA: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 400


@app.route('/api/voice/listen', methods=['POST'])
def voice_listen():
    """Escuta áudio e converte para texto"""
    if not AI_MODELS_AVAILABLE:
        return jsonify({'success': False, 'error': 'Modelos de IA não disponíveis'}), 503
    
    try:
        interface_state['voice_status'] = 'listening'
        result = voice_model.listen(timeout=5)
        interface_state['voice_status'] = voice_model.get_status()
        return jsonify(result)
    except Exception as e:
        interface_state['voice_status'] = 'error'
        print(f"[ERRO] Voz: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/voice/status', methods=['GET'])
def voice_status():
    """Retorna status do modelo de voz"""
    if not AI_MODELS_AVAILABLE:
        return jsonify({'status': 'unavailable'}), 503
    return jsonify({'status': voice_model.get_status()})


@app.route('/api/vision/detect-faces', methods=['POST'])
def detect_faces():
    """Detecta rostos em uma imagem"""
    if not AI_MODELS_AVAILABLE:
        return jsonify({'success': False, 'error': 'Modelos de IA não disponíveis'}), 503
    
    try:
        data = request.json
        image_data = data.get('image')
        interface_state['vision_status'] = 'processing'
        result = vision_model.detect_faces(image_data)
        interface_state['vision_status'] = vision_model.get_status()
        return jsonify(result)
    except Exception as e:
        interface_state['vision_status'] = 'error'
        print(f"[ERRO] Detecção de rostos: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/vision/detect-objects', methods=['POST'])
def detect_objects():
    """Detecta objetos em uma imagem"""
    if not AI_MODELS_AVAILABLE:
        return jsonify({'success': False, 'error': 'Modelos de IA não disponíveis'}), 503
    
    try:
        data = request.json
        image_data = data.get('image')
        interface_state['vision_status'] = 'processing'
        result = vision_model.detect_objects(image_data)
        interface_state['vision_status'] = vision_model.get_status()
        return jsonify(result)
    except Exception as e:
        interface_state['vision_status'] = 'error'
        print(f"[ERRO] Detecção de objetos: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/vision/status', methods=['GET'])
def vision_status():
    """Retorna status do modelo de visão"""
    if not AI_MODELS_AVAILABLE:
        return jsonify({'status': 'unavailable'}), 503
    return jsonify({'status': vision_model.get_status()})


@app.route('/api/ia/message', methods=['POST'])
def ia_message():
    """Envia mensagem para a IA e recebe resposta"""
    if not IA_INTEGRATION_AVAILABLE:
        return jsonify({'success': False, 'error': 'Integração de IA não disponível'}), 503
    
    try:
        data = request.json
        text = data.get('text')
        context = data.get('context', {})
        
        if not text:
            return jsonify({'success': False, 'error': 'Texto vazio'}), 400
        
        result = ia_integration.send_message(text, context)
        return jsonify(result)
    except Exception as e:
        print(f"[ERRO] Mensagem IA: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/ia/multimodal', methods=['POST'])
def ia_multimodal():
    """Processa entrada multimodal (voz + visão + tela)"""
    if not IA_INTEGRATION_AVAILABLE:
        return jsonify({'success': False, 'error': 'Integração de IA não disponível'}), 503
    
    try:
        data = request.json
        voice_text = data.get('voice_text')
        vision_data = data.get('vision_data')
        screen_data = data.get('screen_data')
        
        result = ia_integration.process_multimodal_input(voice_text, vision_data, screen_data)
        return jsonify(result)
    except Exception as e:
        print(f"[ERRO] Multimodal: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/ia/history', methods=['GET'])
def ia_history():
    """Retorna histórico de conversação"""
    if not IA_INTEGRATION_AVAILABLE:
        return jsonify({'history': []}), 503
    
    history = ia_integration.get_conversation_history()
    return jsonify({'history': history})

@app.route('/api/ia/clear-history', methods=['POST'])
def ia_clear_history():
    """Limpa histórico de conversação"""
    if not IA_INTEGRATION_AVAILABLE:
        return jsonify({'success': False, 'error': 'Integração de IA não disponível'}), 503
    
    ia_integration.clear_history()
    return jsonify({'success': True, 'message': 'Histórico limpo'})

@app.route('/api/ia/status', methods=['GET'])
def ia_status():
    """Retorna status da IA"""
    if not IA_INTEGRATION_AVAILABLE:
        return jsonify({'status': 'unavailable'}), 503
    
    return jsonify({'status': ia_integration.get_status()})


@app.route('/api/sync', methods=['POST'])
def sync_all():
    """Sincroniza todos os dados"""
    try:
        data = request.json
        interface_state['status'] = 'synced'
        print(f"[SYNC] Sincronização completa - {len(interface_state['interactions'])} interações")
        return jsonify({
            'success': True,
            'message': 'All data synced',
            'state': interface_state
        })
    except Exception as e:
        print(f"[ERRO] Sincronização: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 400

@app.route('/api/reset', methods=['POST'])
def reset_state():
    """Reseta o estado da interface"""
    try:
        global interface_state
        interface_state = {
            "screen_capture": None,
            "audio_data": None,
            "video_frame": None,
            "interactions": [],
            "ai_response": None,
            "status": "idle",
            "voice_status": "idle",
            "vision_status": "idle"
        }
        print("[RESET] Estado resetado")
        return jsonify({'success': True, 'message': 'State reset'})
    except Exception as e:
        print(f"[ERRO] Reset: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 400


if __name__ == '__main__':
    print("\n" + "="*60)
    print("🚀 Backend Adapta ONE iniciando...")
    print("="*60)
    print(f"📡 Servidor rodando em http://localhost:5000")
    print(f"✓ CORS habilitado para localhost:8000")
    if AI_MODELS_AVAILABLE:
        print(f"✓ Modelos de IA carregados com sucesso")
    else:
        print(f"⚠️  Modelos de IA não disponíveis")
    if IA_INTEGRATION_AVAILABLE:
        print(f"✓ Integração de IA carregada com sucesso")
    else:
        print(f"⚠️  Integração de IA não disponível")
    print("="*60 + "\n")
    
    app.run(debug=True, port=5000, host='0.0.0.0', use_reloader=False)