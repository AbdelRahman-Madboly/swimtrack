"""Tests for analyse.py using the synthetic fixture in tests/fixtures."""
import os
import re

import numpy as np
import pandas as pd
import pytest

import analyse


def test_fixture_has_expected_labels(session_df):
    assert set(session_df["label"]) == {
        "still", "freestyle", "turn_flip", "backstroke", "rest_wall"}
    assert len(session_df) == 1500


def test_prepare_frame_rejects_missing_columns():
    df = pd.DataFrame({"ts_ms": [0, 20], "ax": [0.0, 0.0]})
    with pytest.raises(ValueError, match="missing columns"):
        analyse.prepare_frame(df)


def test_prepare_frame_fills_optional_columns_and_blank_labels(session_df):
    raw = session_df.drop(columns=["dropped", "seq", "t_s"]).copy()
    raw["label"] = raw["label"].astype(object)
    raw.loc[0, "label"] = None
    raw.loc[1, "label"] = "  "
    out = analyse.prepare_frame(raw)
    assert (out["dropped"] == 0).all()
    assert out.loc[0, "label"] == analyse.UNLABELLED
    assert out.loc[1, "label"] == analyse.UNLABELLED
    assert out["t_s"].iloc[0] == 0.0


def test_session_summary_reports_rate_and_label_counts(session_df):
    s = analyse.session_summary(session_df)
    assert s["rows"] == 1500
    assert s["hz"] == pytest.approx(50.0, rel=0.01)
    assert s["drop_pct"] == 0.0
    assert s["label_rows"]["freestyle"] == 300


def test_window_features_shape_and_values(session_df):
    X, y = analyse.extract_window_features(session_df, ["freestyle"], window=50, step=25)
    # 300 rows -> windows starting at 0, 25, ..., 250
    assert X.shape == (11, 24)
    assert set(y) == {"freestyle"}
    first = session_df[session_df["label"] == "freestyle"].iloc[:50]
    names = analyse.feature_names()
    assert X[0, names.index("ax_mean")] == pytest.approx(first["ax"].mean())
    assert X[0, names.index("gx_max")] == pytest.approx(first["gx"].max())
    assert X[0, names.index("az_min")] == pytest.approx(first["az"].min())


def test_window_features_do_not_cross_labels(session_df):
    X, y = analyse.extract_window_features(session_df, ["still", "rest_wall"])
    assert len(X) == len(y) == 22
    assert list(y).count("still") == 11


def test_window_features_empty_when_too_short(session_df):
    short = session_df[session_df["label"] == "freestyle"].iloc[:10]
    X, y = analyse.extract_window_features(short, ["freestyle"])
    assert X.shape == (0, 24)
    assert len(y) == 0


def test_feature_names_order():
    names = analyse.feature_names()
    assert names[:4] == ["ax_mean", "ax_std", "ax_min", "ax_max"]
    assert len(names) == 24


def test_suggest_thresholds_with_turn_and_rest_data(session_df, capsys):
    s = analyse.suggest_thresholds(session_df)
    assert set(s) == {"STROKE_THRESHOLD_G", "TURN_GYRO_Z_THRESH_DPS",
                      "REST_VARIANCE_THRESH"}
    assert s["STROKE_THRESHOLD_G"] >= 0.05
    assert s["TURN_GYRO_Z_THRESH_DPS"] >= 50.0
    assert s["REST_VARIANCE_THRESH"] >= 0.001
    assert "#define STROKE_THRESHOLD_G" in capsys.readouterr().out


def test_suggest_thresholds_falls_back_to_current_values(session_df):
    only_swim = session_df[session_df["label"] == "freestyle"]
    s = analyse.suggest_thresholds(only_swim)
    assert s["STROKE_THRESHOLD_G"] == analyse.CURRENT_STROKE_THRESHOLD_G
    assert s["TURN_GYRO_Z_THRESH_DPS"] == analyse.CURRENT_TURN_GYRO_Z_THRESH_DPS
    assert s["REST_VARIANCE_THRESH"] == analyse.CURRENT_REST_VARIANCE_THRESH


def test_classifier_separates_synthetic_strokes(session_df):
    strokes = session_df[session_df["label"].isin(["freestyle", "backstroke"])]
    X, y = analyse.extract_window_features(strokes, ["backstroke", "freestyle"])
    clf, scores = analyse.train_classifier(X, y)
    assert scores.mean() > 0.9
    tree = analyse.best_tree(clf, X, y)
    pred = clf.classes_[tree.predict(X).astype(int)]
    assert (pred == y).mean() > 0.9


def _simple_tree():
    from sklearn.tree import DecisionTreeClassifier
    names = analyse.feature_names()
    X = np.zeros((40, len(names)))
    X[:20, names.index("ax_min")] = -0.8          # class 0
    X[20:, names.index("ax_min")] = 0.0           # class 1
    y = np.array([0] * 20 + [1] * 20)
    return DecisionTreeClassifier(max_depth=2, random_state=0).fit(X, y), names


def test_tree_to_cpp_renders_a_compilable_shape():
    tree, names = _simple_tree()
    code = analyse.tree_to_cpp(tree, names, ["backstroke", "freestyle"])
    assert code.startswith("StrokeType classifyFeatures(float ax_min)\n{")
    assert code.count("{") == code.count("}")
    m = re.search(r"if \(ax_min <= (-?\d+\.\d{4})f\)", code)
    assert m and -0.8 < float(m.group(1)) < 0.0
    lines = code.splitlines()
    assert lines[3].strip() == "return StrokeType::BACKSTROKE;"
    assert "return StrokeType::FREESTYLE;" in code


def test_tree_to_cpp_leaf_only_tree():
    from sklearn.tree import DecisionTreeClassifier
    tree = DecisionTreeClassifier().fit(np.zeros((4, 24)), [1, 1, 1, 1])
    code = analyse.tree_to_cpp(tree, analyse.feature_names(), ["freestyle"])
    assert "StrokeType classifyFeatures(void)" in code
    assert "return StrokeType::FREESTYLE;" in code


def test_run_classifier_writes_text_and_cpp(session_df, tmp_path):
    result = analyse.run_classifier(session_df, str(tmp_path))
    assert result is not None
    assert result["classes"] == ["backstroke", "freestyle"]
    txt = (tmp_path / "stroke_classifier.txt").read_text()
    inc = (tmp_path / "stroke_classifier.inc").read_text()
    assert "Labels (class index order): ['backstroke', 'freestyle']" in txt
    assert "StrokeType classifyFeatures(" in inc


def test_run_classifier_skips_with_one_stroke_label(session_df, tmp_path):
    one = session_df[session_df["label"] != "backstroke"]
    assert analyse.run_classifier(one, str(tmp_path)) is None
    assert not os.listdir(tmp_path)


def test_main_end_to_end(fixture_csv, tmp_path):
    analyse.main([fixture_csv, "--out-dir", str(tmp_path)])
    produced = sorted(os.listdir(tmp_path))
    assert produced == ["stroke_classifier.inc", "stroke_classifier.txt",
                        "synthetic_session_boxplots.png",
                        "synthetic_session_timeseries.png"]


def test_main_rejects_bad_csv(tmp_path):
    bad = tmp_path / "bad.csv"
    bad.write_text("a,b\n1,2\n")
    with pytest.raises(SystemExit):
        analyse.main([str(bad), "--no-classifier", "--out-dir", str(tmp_path)])
