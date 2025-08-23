import json
import pathlib
import unittest

class TestJSONConfigs(unittest.TestCase):
    FILES = [
        "BShizzle Custom.json",
        "Brewfile.lock.json",
        "iTerm2-Default-profile.json",
    ]

    def test_json_configs_load(self):
        repo_root = pathlib.Path(__file__).resolve().parents[1]
        for fname in self.FILES:
            path = repo_root / fname
            with open(path, 'r', encoding='utf-8') as f:
                json.load(f)

if __name__ == '__main__':
    unittest.main()
