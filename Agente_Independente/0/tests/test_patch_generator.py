# Arquivo: test_patch_generator.py
# Caminho: Agente_Independente / tests / test_patch_generator.py
# Propósito: Testes unitários para o gerador de patches (diff)

import unittest
import sys
import os

# Adiciona o diretório pai ao path para importar PatchGenerator
dir_path = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(dir_path))

from patch_generator import PatchGenerator


class TestPatchGenerator(unittest.TestCase):
    def setUp(self):
        self.generator = PatchGenerator()

    def test_simple_line_modification(self):
        old = ['a = 1', 'b = 2', 'c = 3']
        new = ['a = 1', 'b = 20', 'c = 3']
        patches = self.generator.generate_patches(old, new)
        self.assertEqual(len(patches), 1)
        patch = patches[0]
        self.assertIn('find', patch)
        self.assertIn('replace', patch)
        expected_find = 'a = 1\nb = 2\nc = 3\n'
        expected_replace = 'a = 1\nb = 20\nc = 3\n'
        self.assertEqual(patch['find'], expected_find)
        self.assertEqual(patch['replace'], expected_replace)

    def test_line_addition(self):
        old = ['a = 1', 'c = 3']
        new = ['a = 1', 'b = 2', 'c = 3']
        patches = self.generator.generate_patches(old, new)
        self.assertEqual(len(patches), 1)
        patch = patches[0]
        self.assertIn('find', patch)
        self.assertIn('replace', patch)
        expected_find = 'a = 1\nc = 3\n'
        expected_replace = 'a = 1\nb = 2\nc = 3\n'
        self.assertEqual(patch['find'], expected_find)
        self.assertEqual(patch['replace'], expected_replace)

    def test_line_removal(self):
        old = ['a = 1', 'b = 2', 'c = 3']
        new = ['a = 1', 'c = 3']
        patches = self.generator.generate_patches(old, new)
        self.assertEqual(len(patches), 1)
        patch = patches[0]
        self.assertIn('find', patch)
        self.assertIn('replace', patch)
        expected_find = 'a = 1\nb = 2\nc = 3\n'
        expected_replace = 'a = 1\nc = 3\n'
        self.assertEqual(patch['find'], expected_find)
        self.assertEqual(patch['replace'], expected_replace)


if __name__ == '__main__':
    unittest.main()

