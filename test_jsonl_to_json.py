"""Tests for scripts/jsonl_to_single_json.py."""
import json

import pytest

import test_data
from scripts.jsonl_to_single_json import convert


def make_jsonl(tmp_path):
    src = test_data.make_instance()
    path = tmp_path / "poem.jsonl"
    src.to_jsonl(path)
    return src, path


class TestConvert:

    def test_roundtrip_contents(self, tmp_path):
        src, src_path = make_jsonl(tmp_path)
        out = tmp_path / "poem.json"
        result = convert(src_path, out)
        assert result == out
        data = json.loads(out.read_text(encoding="utf-8"))
        assert data["lines"] == src.lines
        assert data["verses"] == src.verses
        assert data["poem"] == src.poem
        assert data["metadata"]["author"] == "Test Author"
        assert data["metadata"]["model"] == "fake-model"
        assert data["metadata"]["dimensions"] == 4
        assert data["metadata"]["type"] == "Poem-Embeddings"

    def test_single_file_all_levels_present(self, tmp_path):
        _, src_path = make_jsonl(tmp_path)
        out = tmp_path / "poem.json"
        convert(src_path, out)
        data = json.loads(out.read_text(encoding="utf-8"))
        # word-, line-, verse- and poem-level all in one object
        assert all("line_embedding" in l and "words" in l for l in data["lines"])
        assert all("verse_embedding" in v for v in data["verses"])
        assert "poem_embedding" in data["poem"]

    def test_atomic_write_no_partial(self, tmp_path):
        _, src_path = make_jsonl(tmp_path)
        out = tmp_path / "poem.json"
        convert(src_path, out)
        assert not (tmp_path / "poem.json.tmp").exists()
