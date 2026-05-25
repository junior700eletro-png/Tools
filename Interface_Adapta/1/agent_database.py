import psycopg2
import json
import difflib
import os
from uuid import uuid4

def get_connection():
    return psycopg2.connect(
        host=os.getenv('DB_HOST', 'localhost'),
        port=int(os.getenv('DB_PORT', '5432')),
        dbname=os.getenv('DB_NAME', 'postgres'),
        user=os.getenv('DB_USER', 'postgres'),
        password=os.getenv('DB_PASS', '')
    )

def get_latest_version(project_id):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT data::text 
                FROM project_versions 
                WHERE project_id = %s AND status = 'active' 
                ORDER BY version_number DESC LIMIT 1
                """ ,
                (project_id,)
            )
            result = cur.fetchone()
            return result[0] if result else None

def validate_changes(old_json, new_json):
    details = []

    try:
        old_dict = json.loads(old_json) if old_json else {}
        new_dict = json.loads(new_json)
        details.append({"layer": 1, "passed": True, "message": "Both JSONs are valid."})
    except json.JSONDecodeError as e:
        details.append({"layer": 1, "passed": False, "message": f"JSON invalid: {str(e)}"})
        return False, details

    old_keys_str = "\n".join(sorted(old_dict.keys()))
    new_keys_str = "\n".join(sorted(new_dict.keys()))
    sm = difflib.SequenceMatcher(None, old_keys_str, new_keys_str)
    ratio = sm.ratio()
    if ratio >= 0.8:
        details.append({"layer": 2, "passed": True, "message": f"Structure similar (ratio: {ratio:.2%})"})
    else:
        details.append({"layer": 2, "passed": False, "message": f"Structure changed significantly (ratio: {ratio:.2%})"})

    old_str = json.dumps(old_dict, sort_keys=True, indent=2)
    new_str = json.dumps(new_dict, sort_keys=True, indent=2)
    sm2 = difflib.SequenceMatcher(None, old_str, new_str)
    change_ratio = sm2.ratio()
    if change_ratio >= 0.6:
        details.append({"layer": 3, "passed": True, "message": f"Changes acceptable (similarity: {change_ratio:.2%})"})
    else:
        details.append({"layer": 3, "passed": False, "message": f"Too many changes (similarity: {change_ratio:.2%})"})

    status = all(d["passed"] for d in details)
    return status, details

def create_new_version(project_id, new_json, validacao_ok):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT COALESCE(MAX(version_number), 0) FROM project_versions WHERE project_id = %s",
                (project_id,)
            )
            latest_num = cur.fetchone()[0]
            new_num = latest_num + 1
            version_id = str(uuid4())
            status = 'active' if validacao_ok else 'em_validacao'
            if validacao_ok:
                feedback_dict = {'status': 'success', 'message': 'Version created and activated successfully.'}
            else:
                feedback_dict = {'status': 'failed', 'message': 'Version marked as em_validacao.', 'errors': ['Please review the changes.']}
            feedback_str = json.dumps(feedback_dict)
            cur.execute(
                """
                INSERT INTO project_versions (id, project_id, version_number, data, status, feedback)
                VALUES (%s, %s, %s, %s::jsonb, %s, %s::jsonb)
                """ ,
                (version_id, project_id, new_num, new_json, status, feedback_str)
            )
        conn.commit()
        return version_id

def get_feedback(version_id):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT feedback::text FROM project_versions WHERE id = %s",
                (version_id,)
            )
            result = cur.fetchone()
            if not result:
                return {"json": {"error": "Version not found"}, "text": "Version not found."}
            fb_str = result[0]
            fb_dict = json.loads(fb_str) if fb_str else {}

    lines = ["=== Version Feedback ==="]
    status = fb_dict.get('status', 'unknown')
    if status == 'success':
        lines.append("✅ Validation PASSED")
        lines.append("New version is now ACTIVE.")
    elif status == 'failed':
        lines.append("❌ Validation FAILED")
        lines.append("Version marked as 'em_validacao'.")
        if 'errors' in fb_dict:
            lines.extend([f"• {err}" for err in fb_dict['errors']])
    lines.append("======================")
    text = "\n".join(lines)
    return {"json": fb_dict, "text": text}

def agent_validate_and_execute(project_id, new_json):
    old_json = get_latest_version(project_id) or "{}"
    is_valid, validation_details = validate_changes(old_json, new_json)
    version_id = create_new_version(project_id, new_json, is_valid)
    feedback = get_feedback(version_id)
    feedback_json = feedback["json"]
    feedback_text = feedback["text"]
    if not is_valid:
        feedback_json["validation_details"] = validation_details
        extra_text = "\n\nValidation Report:\n" + "\n".join(
            f"Layer {d['layer']}: {'✅ PASS' if d['passed'] else '❌ FAIL'} - {d['message']}" 
            for d in validation_details
        )
        feedback_text += extra_text
    return is_valid, feedback_json, feedback_text

