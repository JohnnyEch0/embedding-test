"""Tests for PoemEmbeddings (one-file-per-poem store) in data.py."""
import json

import pytest

from data import Metadata, PoemEmbeddings


def make_metadata():
    m = Metadata()
    m.schema_version = PoemEmbeddings.SCHEMA_VERSION
    m.author = "Test Author"
    m.title = "Test Poem"
    m.model = "fake-model"
    m.dimensions = 4
    m.procedures = ["test"]
    return m


def make_instance():
    pe = PoemEmbeddings()
    pe.metadata = make_metadata()
    pe.lines = [
        {
            "line_index": 0,
            "line": "hello world",
            "words": [
                {"word": "hello", "embedding": [0.1, 0.2, 0.3, 0.4]},
                {"word": "world", "embedding": [0.5, 0.6, 0.7, 0.8]},
            ],
            "line_embedding": [1.0, 1.1, 1.2, 1.3],
        },
        {
            "line_index": 1,
            "line": "foo bar",
            "words": [{"word": "foo", "embedding": [0.9, 0.9, 0.9, 0.9]}],
            "line_embedding": [2.0, 2.1, 2.2, 2.3],
        },
    ]
    pe.verses = [
        {
            "verse_index": 0,
            "line_range": [0, 2],
            "text": "hello world\nfoo bar\n",
            "verse_embedding": [3.0, 3.1, 3.2, 3.3],
        },
    ]
    pe.poem = {
        "text": "hello world\nfoo bar\n",
        "poem_embedding": [4.0, 4.1, 4.2, 4.3],
    }
    return pe


class TestToJsonl:

    def test_roundtrip(self, tmp_path):
        src = make_instance()
        path = tmp_path / "poem.jsonl"
        src.to_jsonl(path)
        out = PoemEmbeddings.from_jsonl(path)
        assert out.lines == src.lines
        assert out.verses == src.verses
        assert out.poem == src.poem
        assert out.metadata.author == "Test Author"
        assert out.metadata.model == "fake-model"
        assert out.metadata.dimensions == 4
        assert out.metadata.schema_version == PoemEmbeddings.SCHEMA_VERSION

    def test_header_is_first_line_and_valid_json(self, tmp_path):
        path = tmp_path / "poem.jsonl"
        make_instance().to_jsonl(path)
        raw_lines = path.read_text(encoding="utf-8").splitlines()
        # every line must parse on its own: header + 2 line + 1 verse + 1 poem
        assert len(raw_lines) == 5
        for raw in raw_lines:
            json.loads(raw)
        header = json.loads(raw_lines[0])
        assert header["type"] == "Poem-Embeddings"
        assert "schema_version" in header

    def test_line_records_carry_line_embedding(self, tmp_path):
        path = tmp_path / "poem.jsonl"
        make_instance().to_jsonl(path)
        recs = [json.loads(r) for r in path.read_text(encoding="utf-8").splitlines()]
        line_recs = [r for r in recs if "line_index" in r]
        assert len(line_recs) == 2
        for r in line_recs:
            assert len(r["line_embedding"]) == 4

    def test_verse_records_carry_line_range(self, tmp_path):
        path = tmp_path / "poem.jsonl"
        make_instance().to_jsonl(path)
        recs = [json.loads(r) for r in path.read_text(encoding="utf-8").splitlines()]
        verse_recs = [r for r in recs if "verse_index" in r]
        assert len(verse_recs) == 1
        assert verse_recs[0]["line_range"] == [0, 2]
        assert len(verse_recs[0]["verse_embedding"]) == 4

    def test_single_poem_record(self, tmp_path):
        path = tmp_path / "poem.jsonl"
        make_instance().to_jsonl(path)
        recs = [json.loads(r) for r in path.read_text(encoding="utf-8").splitlines()]
        poem_recs = [r for r in recs if "poem" in r]
        assert len(poem_recs) == 1
        assert poem_recs[0]["poem"] is True
        assert len(poem_recs[0]["poem_embedding"]) == 4


class TestFromJsonl:

    def test_missing_header_raises(self, tmp_path):
        path = tmp_path / "bad.jsonl"
        path.write_text('{"line_index": 0, "line": "x", "words": [], "line_embedding": []}\n')
        with pytest.raises(LookupError):
            PoemEmbeddings.from_jsonl(path)

    def test_missing_poem_record_raises(self, tmp_path):
        path = tmp_path / "bad.jsonl"
        path.write_text('{"schema_version": 1, "author": "a", "title": "t", '
                        '"model": "m", "dimensions": 4, "procedures": []}\n')
        with pytest.raises(LookupError):
            PoemEmbeddings.from_jsonl(path)
