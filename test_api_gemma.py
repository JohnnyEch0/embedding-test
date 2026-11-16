"""Tests for api_gemma CLI."""
import json
import os

import pytest

from types import SimpleNamespace

import api_gemma


# fake client matching openai interface
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

    def test_dims_in_filename(self, tmp_path, fake_client, monkeypatch):
        monkeypatch.setattr(api_gemma, "client", fake_client)
        (tmp_path / "in").mkdir()
        (tmp_path / "in" / "test.md").write_text("hello world\nfoo bar\n")
        api_gemma.main(["--dims", "64", str(tmp_path / "in"), str(tmp_path / "out")])
        files = list((tmp_path / "out").glob("eg2_d64_*.jsonl"))
        assert len(files) == 1
        recs = [json.loads(ln) for ln in files[0].read_text().splitlines() if ln.strip()]
        assert len(recs) == 2
        assert len(recs[0]["words"]) == 2  # line 1: hello world
        assert all(len(e) == 64 for e in [w["embedding"] for w in recs[0]["words"]])

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
