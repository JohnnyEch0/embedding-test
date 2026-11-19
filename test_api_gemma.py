"""Tests for api_gemma CLI."""
import json
import os

import pytest

from types import SimpleNamespace

import api_gemma


# --- iter_md_files ---


class TestIterMdFiles:

    def test_only_md_yielded_sorted(self, tmp_path):
        (tmp_path / "a.md").write_text("x")
        (tmp_path / "b.txt").write_text("x")
        (tmp_path / "sub").mkdir()
        (tmp_path / "sub" / "inner.md").write_text("x")
        assert list(api_gemma.iter_md_files(tmp_path)) == [tmp_path / "a.md"]

    def test_empty_dir(self, tmp_path):
        assert list(api_gemma.iter_md_files(tmp_path)) == []


# --- parse_md_lines ---

class TestParseMdLines:

    def test_blank_lines_skipped_index_preserved(self):
        lines = ["hello world", "", "   ", "foo bar"]
        records = api_gemma.parse_md_lines(lines)
        assert records == [
            api_gemma.Record(line_index=0, line="hello world", words=["hello", "world"]),
            api_gemma.Record(line_index=3, line="foo bar", words=["foo", "bar"]),
        ]

    def test_all_blank(self):
        assert api_gemma.parse_md_lines(["", "", ""]) == []


# --- write_jsonl ---

class TestWriteJsonl:

    def test_writes_jsonl_returns_path(self, tmp_path):
        records = [
            {"line_index": 0, "line": "hello world", "words": [
                {"word": "hello", "embedding": [0.1]},
                {"word": "world", "embedding": [0.2]},
            ]},
        ]
        path = api_gemma.write_jsonl(records, tmp_path, dims=64, stem="test")
        assert path == tmp_path / "eg2_d64_test.jsonl"
        assert path.exists()
        assert json.loads(path.read_text()) == records[0]


# --- attach_embeddings ---

class TestAttachEmbeddings:

    def test_returns_new_records_and_does_not_mutate(self, tmp_path):
        records = [
            api_gemma.Record(line_index=0, line="hello world", words=["hello", "world"]),
            api_gemma.Record(line_index=2, line="foo bar", words=["foo", "bar"]),
        ]
        vectors = [[0.1], [0.2], [0.3], [0.4]]
        out = api_gemma.attach_embeddings(records, vectors)
        assert out == [
            {"line_index": 0, "line": "hello world", "words": [
                {"word": "hello", "embedding": [0.1]},
                {"word": "world", "embedding": [0.2]},
            ]},
            {"line_index": 2, "line": "foo bar", "words": [
                {"word": "foo", "embedding": [0.3]},
                {"word": "bar", "embedding": [0.4]},
            ]},
        ]
        # original untouched
        assert records[0].words == ["hello", "world"]
        assert records[1].words == ["foo", "bar"]


# --- embed_file ---

class TestEmbedFile:

    def test_end_to_end(self, tmp_path, fake_client):
        (tmp_path / "in").mkdir()
        (tmp_path / "in" / "test.md").write_text("hello world\nfoo bar\n")
        out = tmp_path / "out"
        out.mkdir()
        api_gemma.embed_file(tmp_path / "in" / "test.md", fake_client, "google/embeddinggemma-2", 64, 4, out)
        files = list(out.glob("eg2_d64_*.jsonl"))
        assert len(files) == 1
        recs = [json.loads(ln) for ln in files[0].read_text().splitlines() if ln.strip()]
        assert len(recs) == 2
        assert all(len(e) == 64 for e in [w["embedding"] for w in recs[0]["words"]])

    def test_empty_md_ignored(self, tmp_path, fake_client):
        (tmp_path / "in").mkdir()
        (tmp_path / "in" / "empty.md").write_text("")
        api_gemma.embed_file(tmp_path / "in" / "empty.md", fake_client, "google/embeddinggemma-2", 64, 4, tmp_path / "out")
        assert list((tmp_path / "out").iterdir()) == []
class FakeEmbeddings:
    """Records create() calls, returns canned vectors sliced to the asked dims."""

    def __init__(self, vectors):
        self.vectors = vectors
        self.calls = []

    def create(self, model, input, dimensions):
        self.calls.append((model, list(input), dimensions))
        from types import SimpleNamespace
        data = [SimpleNamespace(index=i, embedding=self.vectors[w][:dimensions])
                for i, w in enumerate(input)]
        return SimpleNamespace(data=data)


@pytest.fixture
def fake_client():
    """Patch api_gemma.client with a fake returning canned vectors."""
    vectors = {
        "hello": [0.1] * 128,
        "world": [0.2] * 128,
        "foo": [0.3] * 128,
        "bar": [0.4] * 128,
    }
    fake = SimpleNamespace(embeddings=FakeEmbeddings(vectors))
    return fake


@pytest.fixture
def tmp_dirs(tmp_path):
    """Create tmp input/output dirs with a small .md file."""
    inp = tmp_path / "in"
    out = tmp_path / "out"
    inp.mkdir()
    out.mkdir()
    (inp / "test.md").write_text("hello world\nfoo bar\n")
    return inp, out


# --- strip_frontmatter ---

class TestStripFrontmatter:

    def test_strips_frontmatter(self):
        text = "---\ntitle: Test\nauthor: Someone\n---\n\nBody line 1.\nBody line 2."
        assert api_gemma.strip_frontmatter(text) == "Body line 1.\nBody line 2."

    def test_no_frontmatter(self):
        text = "Just a poem.\nNo frontmatter."
        assert api_gemma.strip_frontmatter(text) == text

    def test_unclosed_frontmatter(self):
        text = "---\ntitle: Test\nNo closing"
        assert api_gemma.strip_frontmatter(text) == text

    def test_empty_frontmatter(self):
        text = "---\n---\n\nBody"
        assert api_gemma.strip_frontmatter(text) == "Body"


# --- parse_frontmatter ---

class TestParseFrontmatter:

    def test_parses_quoted_values(self):
        text = '---\ntitle: "Wild Geese"\nauthor: "Mary Oliver"\n---\n\nBody.'
        fm = api_gemma.parse_frontmatter(text)
        assert fm == {"title": "Wild Geese", "author": "Mary Oliver"}

    def test_parses_unquoted_values(self):
        text = "---\ntitle: Wild Geese\nauthor: Mary Oliver\n---\n\nBody."
        fm = api_gemma.parse_frontmatter(text)
        assert fm == {"title": "Wild Geese", "author": "Mary Oliver"}

    def test_no_frontmatter(self):
        text = "Just a poem."
        assert api_gemma.parse_frontmatter(text) == {}

    def test_malformed_frontmatter(self):
        text = "---\ntitle: Test\nNo closing"
        assert api_gemma.parse_frontmatter(text) == {}

    def test_extra_fields_ignored(self):
        text = "---\ntitle: X\nauthor: Y\nyear: 1986\n---\n\nBody."
        fm = api_gemma.parse_frontmatter(text)
        assert len(fm) == 3


# --- make_metadata ---

class TestMakeMetadata:

    def test_author_title_from_frontmatter(self):
        m = api_gemma.make_metadata("Mary Oliver", "Wild Geese", "model", 128)
        assert m.author == "Mary Oliver"
        assert m.title == "Wild Geese"

    def test_author_none_when_missing(self):
        m = api_gemma.make_metadata(None, "Wild Geese", "model", 128)
        assert m.author is None


# --- poem_texts ---

class TestPoemTexts:

    def test_frontmatter_stripped(self, tmp_path):
        """Frontmatter must not leak into words/lines/verses."""
        md = tmp_path / "t.md"
        md.write_text(
            "---\n"
            "title: Test Poem\n"
            "author: Someone\n"
            "---\n"
            "\n"
            "alpha beta\n"
            "gamma\n"
        )
        words, raw_lines, verse_infos, poem_text = api_gemma.poem_texts(md)
        assert words == ["alpha", "beta", "gamma"]
        assert raw_lines == ["alpha beta", "gamma"]
        assert len(verse_infos) == 1

    def test_frontmatter_author_title_extracted(self, tmp_path):
        """embed_poem_file must pull author/title from frontmatter into metadata."""
        md = tmp_path / "t.md"
        md.write_text(
            "---\n"
            "title: Wild Geese\n"
            "author: Mary Oliver\n"
            "---\n"
            "\n"
            "alpha beta\n"
            "gamma\n"
        )
        fm = api_gemma.parse_frontmatter(md.read_text(encoding="utf-8"))
        assert fm["title"] == "Wild Geese"
        assert fm["author"] == "Mary Oliver"
        md = tmp_path / "t.md"
        md.write_text("alpha beta\ngamma\n\ndelta epsilon\n")
        words, lines, verse_infos, poem_text = api_gemma.poem_texts(md)
        assert words == ["alpha", "beta", "gamma", "delta", "epsilon"]
        assert lines == ["alpha beta", "gamma", "delta epsilon"]
        assert len(verse_infos) == 2
        # verse texts are newline-joined line blocks; poem joins verses with a blank line
        assert verse_infos[0] == ("alpha beta\ngamma", (0, 2))
        assert verse_infos[1] == ("delta epsilon", (2, 3))
        assert poem_text == "alpha beta\ngamma\n\ndelta epsilon"

    def test_single_stanza(self, tmp_path):
        md = tmp_path / "t.md"
        md.write_text("one two\nthree four\n")
        words, lines, verse_infos, poem_text = api_gemma.poem_texts(md)
        assert len(verse_infos) == 1
        assert verse_infos[0][1] == (0, 2)

    def test_blank_blocks_skipped(self, tmp_path):
        md = tmp_path / "t.md"
        md.write_text("\n\none two\n\n\n")
        words, lines, verse_infos, poem_text = api_gemma.poem_texts(md)
        assert words == ["one", "two"]
        assert len(verse_infos) == 1


# --- embed_poem_file ---

class TestEmbedPoemFile:

    def test_metadata_author_title_from_frontmatter(self, tmp_path):
        """metadata.author/title must come from frontmatter, not filename."""
        md = tmp_path / "in" / "wild-geese_mary-oliver.md"
        md.parent.mkdir()
        md.write_text(
            "---\n"
            "title: \"Wild Geese\"\n"
            "author: \"Mary Oliver\"\n"
            "---\n"
            "\n"
            "You do not have to be good.\n"
        )
        out = tmp_path / "out"
        out.mkdir()
        result = api_gemma.embed_poem_file(md, any_fake_client(), "fake-model", 64, 4, out)
        data = json.loads(result.read_text())
        assert data["metadata"]["author"] == "Mary Oliver"
        assert data["metadata"]["title"] == "Wild Geese"

    def test_end_to_end_writes_json_by_default(self, tmp_path):
        md = tmp_path / "in" / "test.md"
        md.parent.mkdir()
        md.write_text("hello world\nfoo bar\n\nbaz qux\n")
        out = tmp_path / "out"
        out.mkdir()
        result = api_gemma.embed_poem_file(md, any_fake_client(), "fake-model", 64, 4, out)
        assert result == out / "eg2_d64_test.json"
        data = json.loads(result.read_text())
        assert set(data) == {"metadata", "lines", "verses", "poem"}
        assert data["metadata"]["type"] == "Poem-Embeddings"
        assert data["metadata"]["schema_version"] == 1
        assert data["metadata"]["dimensions"] == 64
        assert len(data["lines"]) == 3
        for r in data["lines"]:
            assert len(r["line_embedding"]) == 64
            for w in r["words"]:
                assert len(w["embedding"]) == 64
        assert [v["line_range"] for v in data["verses"]] == [[0, 2], [2, 3]]
        for v in data["verses"]:
            assert len(v["verse_embedding"]) == 64
        assert len(data["poem"]["poem_embedding"]) == 64

    def test_jsonl_flag_writes_deprecated_format(self, tmp_path):
        md = tmp_path / "in" / "test.md"
        md.parent.mkdir()
        md.write_text("hello world\nfoo bar\n")
        out = tmp_path / "out"
        out.mkdir()
        result = api_gemma.embed_poem_file(md, any_fake_client(), "fake-model", 64, 4, out,
                                           jsonl=True)
        assert result == out / "eg2_d64_test.jsonl"
        recs = [json.loads(ln) for ln in result.read_text().splitlines() if ln.strip()]
        assert recs[0]["type"] == "Poem-Embeddings"  # header first
        assert sum("line_index" in r for r in recs) == 2
        assert sum("poem" in r for r in recs) == 1

    def test_empty_md_returns_none(self, tmp_path):
        md = tmp_path / "in" / "empty.md"
        md.parent.mkdir()
        md.write_text("\n\n")
        out = tmp_path / "out"
        out.mkdir()
        assert api_gemma.embed_poem_file(md, any_fake_client(), "m", 8, 4, out) is None
        assert list(out.iterdir()) == []


class AnyFakeEmbeddings:
    """Canned vector per position, any input strings."""

    def create(self, model, input, dimensions):
        from types import SimpleNamespace
        data = [SimpleNamespace(index=i, embedding=[i / 1000.0] * dimensions)
                for i in range(len(input))]
        return SimpleNamespace(data=data)


def any_fake_client():
    from types import SimpleNamespace
    return SimpleNamespace(embeddings=AnyFakeEmbeddings())


# --- parse_args ---

class TestParseArgs:

    def test_defaults(self):
        args = api_gemma.parse_args(["poem", "poem_emb"])
        assert args.input == "poem"
        assert args.output == "poem_emb"
        assert args.model == "google/embeddinggemma-2"
        assert args.dims == 128
        assert args.batch == 256

    def test_flag_overrides(self):
        args = api_gemma.parse_args(
            ["--model", "m", "--dims", "64", "--batch", "128", "poem", "poem_emb"]
        )
        assert args.model == "m"
        assert args.dims == 64
        assert args.batch == 128

    def test_missing_positionals_exits(self):
        with pytest.raises(SystemExit):
            api_gemma.parse_args([])

    def test_bad_dims_rejected(self):
        with pytest.raises(SystemExit):
            api_gemma.parse_args(["--dims", "not-an-int", "poem", "poem_emb"])


# --- embed ---

class TestEmbed:

    def test_batches_of_256(self):
        words = [f"w{i}" for i in range(600)]
        vectors = {w: [0.1] * 128 for w in words}
        fake = SimpleNamespace(embeddings=FakeEmbeddings(vectors))
        out = api_gemma.embed(words, fake, "google/embeddinggemma-2", 128, 256)
        calls = fake.embeddings.calls
        assert [len(c[1]) for c in calls] == [256, 256, 88]

        # 100 words, batch 256 → 1 call
        fake = SimpleNamespace(embeddings=FakeEmbeddings({w: [0.1] * 128 for w in words[:100]}))
        api_gemma.embed(words[:100], fake, "google/embeddinggemma-2", 128, 256)
        assert len(fake.embeddings.calls) == 1
        assert len(fake.embeddings.calls[0][1]) == 100

    def test_preserves_order(self):
        words = ["hello", "world", "foo", "bar"]
        vectors = {w: [0.1 * i] * 128 for i, w in enumerate(words)}
        fake = SimpleNamespace(embeddings=FakeEmbeddings(vectors))
        out = api_gemma.embed(words, fake, "google/embeddinggemma-2", 128, 256)
        assert [out[0], out[1], out[2], out[3]] == [
            vectors["hello"], vectors["world"], vectors["foo"], vectors["bar"]
        ]


class TestMain:

    def test_dims_in_filename(self, tmp_path, monkeypatch):
        fake = any_fake_client()
        monkeypatch.setattr(api_gemma, "client", fake)
        (tmp_path / "in").mkdir()
        (tmp_path / "in" / "test.md").write_text("hello world\nfoo bar\n")
        api_gemma.main(["--dims", "64", str(tmp_path / "in"), str(tmp_path / "out")])
        files = list((tmp_path / "out").glob("eg2_d64_*.json"))
        assert len(files) == 1
        data = json.loads(files[0].read_text())
        assert len(data["lines"]) == 2  # test.md has 2 lines
        assert len(data["lines"][0]["words"]) == 2  # line 1: hello world
        assert all(len(e) == 64 for e in [w["embedding"] for w in data["lines"][0]["words"]])
        assert len(data["verses"]) == 1
        assert "poem_embedding" in data["poem"]

    def test_jsonl_flag(self, tmp_path, monkeypatch):
        fake = any_fake_client()
        monkeypatch.setattr(api_gemma, "client", fake)
        (tmp_path / "in").mkdir()
        (tmp_path / "in" / "test.md").write_text("hello world\nfoo bar\n")
        api_gemma.main(["--dims", "64", "--jsonl", str(tmp_path / "in"), str(tmp_path / "out")])
        files = list((tmp_path / "out").glob("eg2_d64_*.jsonl"))
        assert len(files) == 1
        assert not list((tmp_path / "out").glob("eg2_d64_*.json"))

    def test_non_md_ignored(self, tmp_path, fake_client, monkeypatch):
        monkeypatch.setattr(api_gemma, "client", fake_client)
        (tmp_path / "in").mkdir()
        (tmp_path / "in" / "notes.txt").write_text("ignore me")
        api_gemma.main(["--dims", "64", str(tmp_path / "in"), str(tmp_path / "out")])
        assert list((tmp_path / "out").iterdir()) == []

    def test_empty_md_ignored(self, tmp_path, fake_client, monkeypatch):
        monkeypatch.setattr(api_gemma, "client", fake_client)
        (tmp_path / "in").mkdir()
        (tmp_path / "in" / "empty.md").write_text("")
        api_gemma.main(["--dims", "64", str(tmp_path / "in"), str(tmp_path / "out")])
        assert list((tmp_path / "out").iterdir()) == []
