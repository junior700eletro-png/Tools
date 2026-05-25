# Arquivo: patch_generator.py
# Caminho: Agente_Independente / src / fixer / patch_generator.py
# Propósito: Gerar blocos FIND/REPLACE automaticamente comparando código original e corrigido

import difflib


class PatchGenerator:
    def generate_patch_blocks(
        self, original_code: str, fixed_code: str, context_lines: int = 1
    ) -> list[dict]:
        original_lines = original_code.splitlines(keepends=False)
        fixed_lines = fixed_code.splitlines(keepends=False)

        diff_iter = difflib.unified_diff(
            original_lines, fixed_lines, n=context_lines, lineterm='\n'
        )
        diff_lines = list(diff_iter)

        patches = []
        i = 0
        while i < len(diff_lines):
            line = diff_lines[i]
            if line.startswith('@@'):
                hunk_start = i + 1
                j = hunk_start
                while j < len(diff_lines) and not diff_lines[j].startswith('@@'):
                    j += 1
                hunk_lines = diff_lines[hunk_start:j]

                find_parts = []
                replace_parts = []
                for dline in hunk_lines:
                    if not dline or len(dline) < 2:
                        continue
                    prefix = dline[0]
                    content = dline[1:-1]  # remove prefix and \n
                    if prefix in ' -':
                        find_parts.append(content)
                    if prefix in ' +':
                        replace_parts.append(content)

                find_str = '\n'.join(find_parts) + '\n' if find_parts else ''
                replace_str = '\n'.join(replace_parts) + '\n' if replace_parts else ''

                patches.append({'find': find_str, 'replace': replace_str})

                i = j
            else:
                i += 1
        return patches
