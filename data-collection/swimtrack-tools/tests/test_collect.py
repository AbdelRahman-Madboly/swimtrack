"""Tests for the derived-column logic in collect.py and the synthetic generator."""
import filecmp

import pytest

import collect
import make_synthetic


def _row(mag, gz=0.0, ts=0):
    return {"mag_raw": mag, "gz": gz, "ts_ms": ts}


def test_first_sample_seeds_filters():
    st = collect.State()
    d = collect.compute_derived(st, _row(1.0))
    assert d["mag_filt"] == pytest.approx(1.0)
    assert d["baseline"] == pytest.approx(1.0)
    assert d["threshold"] == pytest.approx(1.0 + collect.STROKE_THRESHOLD_G)
    assert d["variance"] == 0.0


def test_stroke_event_on_falling_edge_only():
    st = collect.State()
    events = []
    for i, mag in enumerate([1.0] * 5 + [2.0] * 5 + [1.0] * 10):
        d = collect.compute_derived(st, _row(mag, ts=i * 20))
        events.append(d["event_stroke"])
    assert sum(events) == 1
    assert events.index(1) > 10   # after the peak, not at the rising edge


def test_turn_event_needs_sustained_rotation():
    st = collect.State()
    flags = [collect.compute_derived(st, _row(1.0, gz=200.0, ts=t))["event_turn"]
             for t in (0, 20, 40)]
    assert flags == [0, 0, 1]
    st = collect.State()
    assert collect.compute_derived(st, _row(1.0, gz=-200.0, ts=0))["event_turn"] == 0
    assert collect.compute_derived(st, _row(1.0, gz=0.0, ts=20))["event_turn"] == 0


def test_variance_window_is_bounded():
    st = collect.State()
    for i in range(collect.VARIANCE_WINDOW * 3):
        collect.compute_derived(st, _row(1.0 if i % 2 else 2.0, ts=i * 20))
    assert len(st.var_buf) == collect.VARIANCE_WINDOW


def test_check_drop_detects_gaps_and_wraps():
    st = collect.State()
    assert collect.check_drop(st, 254) == 0     # first packet is never a drop
    assert collect.check_drop(st, 255) == 0
    assert collect.check_drop(st, 0) == 0       # wraps at 256
    assert collect.check_drop(st, 2) == 1


def test_generator_is_deterministic(fixture_csv, tmp_path):
    out = tmp_path / "again.csv"
    rows = make_synthetic.generate(str(out), seed=42, seconds_per_label=6)
    assert rows == 1500
    assert filecmp.cmp(str(out), fixture_csv, shallow=False)
