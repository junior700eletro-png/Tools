# backend.py
from flask import Flask, request, jsonify
import threading

app = Flask(__name__)

# Global state dictionary and its lock
interface_state = {}
state_lock = threading.Lock()

@app.route('/api/multimodal', methods=['POST'])
def multimodal():
    # Strict input validation
    data = request.get_json(silent=True)
    if not data or 'input' not in data or not isinstance(data['input'], str):
        return jsonify({'error': 'Invalid input: must provide a non-empty string in "input" field'}), 400
    
    input_str = data['input'].strip()
    if not input_str:
        return jsonify({'error': 'Input string must not be empty'}), 400
    
    # Thread-safe state access
    with state_lock:
        interface_state['last_input'] = input_str
        interface_state['count'] = interface_state.get('count', 0) + 1
        current_state = dict(interface_state)
    
    # Process input (simulate)
    try:
        result = process_input(input_str)
    except Exception as e:
        # Log the exception internally but return generic error
        app.logger.error(f"Processing failed: {e}")
        return jsonify({'error': 'Internal processing error'}), 500
    
    return jsonify({'result': result, 'state': current_state})

def process_input(s):
    # Simulated processing - could raise exceptions
    if s == 'bad':
        raise ValueError('Bad input')
    return s.upper()

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    app.run(debug=False)