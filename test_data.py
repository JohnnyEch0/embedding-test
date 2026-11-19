"""Tests for PoemEmbeddings (one-file-per-poem store) in data.py."""
import json
from pathlib import Path

import pytest

from data import (Metadata, PoemEmbeddings, WordEmb, LineEmb, VerseEmb, PoemEmb)

REPO = Path(__file__).parent


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
        LineEmb(
            line_index=0,
            line="hello world",
            words=[
                WordEmb("hello", [0.1, 0.2, 0.3, 0.4]),
                WordEmb("world", [0.5, 0.6, 0.7, 0.8]),
            ],
            line_embedding=[1.0, 1.1, 1.2, 1.3],
        ),
        LineEmb(
            line_index=1,
            line="foo bar",
            words=[WordEmb("foo", [0.9, 0.9, 0.9, 0.9])],
            line_embedding=[2.0, 2.1, 2.2, 2.3],
        ),
    ]
    pe.verses = [
        VerseEmb(
            verse_index=0,
            line_range=(0, 2),
            text="hello world\nfoo bar\n",
            verse_embedding=[3.0, 3.1, 3.2, 3.3],
        ),
    ]
    pe.poem = PoemEmb(
        text="hello world\nfoo bar\n",
        poem_embedding=[4.0, 4.1, 4.2, 4.3],
    )
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
        assert out.metadata.title == "Test Poem"
        assert out.metadata.model == "fake-model"
        assert out.metadata.dimensions == 4
        assert out.metadata.procedures == ["test"]
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


class TestToJson:

    def test_roundtrip(self, tmp_path):
        src = make_instance()
        path = tmp_path / "poem.json"
        src.to_json(path)
        out = PoemEmbeddings.from_json(path)
        assert out.lines == src.lines
        assert out.verses == src.verses
        assert out.poem == src.poem
        assert out.metadata.author == "Test Author"
        assert out.metadata.title == "Test Poem"
        assert out.metadata.model == "fake-model"
        assert out.metadata.dimensions == 4
        assert out.metadata.procedures == ["test"]
        assert out.metadata.schema_version == PoemEmbeddings.SCHEMA_VERSION

    def test_single_file_all_levels_present(self, tmp_path):
        path = tmp_path / "poem.json"
        make_instance().to_json(path)
        data = json.loads(path.read_text(encoding="utf-8"))
        assert set(data) == {"metadata", "lines", "verses", "poem"}
        assert data["metadata"]["type"] == "Poem-Embeddings"
        assert all("line_embedding" in l and "words" in l for l in data["lines"])
        assert all("verse_embedding" in v for v in data["verses"])
        assert "poem_embedding" in data["poem"]


class TestDataclasses:

    def test_word_roundtrip_and_key_order(self):
        w = WordEmb("you", [0.1, 0.2])
        d = w.to_dict()
        assert list(d) == ["word", "embedding"]
        assert WordEmb.from_dict(d) == w

    def test_line_roundtrip_and_key_order(self):
        l = make_instance().lines[0]
        assert list(l.to_dict()) == ["line_index", "line", "words", "line_embedding"]
        assert LineEmb.from_dict(l.to_dict()) == l

    def test_verse_roundtrip_and_key_order(self):
        v = make_instance().verses[0]
        d = v.to_dict()
        assert list(d) == ["verse_index", "line_range", "text", "verse_embedding"]
        out = VerseEmb.from_dict(d)
        assert out == v
        assert out.line_range == (0, 2)

    def test_poem_roundtrip_and_key_order(self):
        p = make_instance().poem
        assert list(p.to_dict()) == ["text", "poem_embedding"]
        assert PoemEmb.from_dict(p.to_dict()) == p


class TestLoadSave:

    def test_save_load_json_roundtrip(self, tmp_path):
        src = make_instance()
        path = tmp_path / "poem.json"
        src.save(path)
        out = PoemEmbeddings.load(path)
        assert out.lines == src.lines
        assert out.verses == src.verses
        assert out.poem == src.poem

    def test_save_load_jsonl_roundtrip(self, tmp_path):
        src = make_instance()
        path = tmp_path / "poem.jsonl"
        src.save(path)
        out = PoemEmbeddings.load(path)
        assert out.lines == src.lines
        assert out.verses == src.verses
        assert out.poem == src.poem

    def test_unknown_extension_raises(self, tmp_path):
        p = tmp_path / "poem.txt"
        p.write_text("{}")
        with pytest.raises(ValueError):
            PoemEmbeddings.load(p)
        with pytest.raises(ValueError):
            make_instance().save(p)


class TestWildGeeseCompatibility:
    """The standard format must stay byte-compatible with the committed data."""

    def test_save_matches_committed_json(self, tmp_path):
        src = REPO / "poem_emb" / "eg2_d128_wild-geese_mary-oliver.jsonl"
        committed = REPO / "poem_emb" / "eg2_d128_wild-geese_mary-oliver.json"
        if not src.exists() or not committed.exists():
            pytest.skip("repo data files not present")
        out = tmp_path / "out.json"
        PoemEmbeddings.load(src).save(out)
        assert out.read_bytes() == committed.read_bytes()
