#!/usr/bin/env python3
"""
analyse.py - SwimTrack threshold analyser and stroke classifier
================================================================
Loads a labelled CSV produced by collect.py and produces:

  1. Summary table: rows, duration, sample rate, rows per label
  2. Time-series plot (4-panel PNG): mag_filt with threshold and baseline,
     |gyroZ| with the turn threshold, variance with the rest threshold,
     and a label colour bar
  3. Feature distribution box plots (PNG), grouped by label
  4. Threshold suggestions printed to the console with a config.h snippet
  5. Stroke classifier (Random Forest) when two or more stroke labels are
     present: cross-validation accuracy, per-class report, and the best single
     tree exported as text (stroke_classifier.txt) and as a C++ snippet
     (stroke_classifier.inc) for the firmware

Requirements:
  pip install -r requirements.txt

Usage:
  python analyse.py swimtrack_20260411_143022.csv
  python analyse.py swimtrack_20260411_143022.csv --no-classifier
"""

import argparse
import sys
import os

try:
    import pandas as pd
    import numpy as np
    import matplotlib
    matplotlib.use("Agg")   # no display needed, saves to PNG
    import matplotlib.pyplot as plt
    import matplotlib.patches as mpatches
    from matplotlib.gridspec import GridSpec
except ImportError:
    sys.exit("ERROR: Missing packages. Run: pip install -r requirements.txt")

# ============================================================
#  CURRENT FIRMWARE THRESHOLDS  (for comparison in output)
# ============================================================

# Keep in step with firmware/include/config.h
CURRENT_STROKE_THRESHOLD_G     = 0.095
CURRENT_TURN_GYRO_Z_THRESH_DPS = 150.0
CURRENT_REST_VARIANCE_THRESH   = 0.16421

# Classifier window: 50 samples = 1 s at 50 Hz, 50 % overlap
WINDOW_SAMPLES = 50
WINDOW_STEP    = 25
IMU_COLUMNS    = ["ax", "ay", "az", "gx", "gy", "gz"]
FEATURE_STATS  = ["mean", "std", "min", "max"]

# ============================================================
#  LABEL GROUPS
# ============================================================

SWIMMING_LABELS     = {"freestyle", "backstroke", "breaststroke", "butterfly"}
TURN_LABELS         = {"turn_flip", "turn_open"}
REST_LABELS         = {"still", "rest_wall"}
STROKE_LABELS_ML    = ["freestyle", "backstroke", "breaststroke", "butterfly"]

LABEL_COLOURS = {
    "freestyle"         : "#2196F3",
    "backstroke"        : "#4CAF50",
    "breaststroke"      : "#FF9800",
    "butterfly"         : "#9C27B0",
    "turn_flip"         : "#F44336",
    "turn_open"         : "#E91E63",
    "rest_wall"         : "#00BCD4",
    "idle"              : "#9E9E9E",
    "still"             : "#607D8B",
    "false_positive_test": "#FF5722",
    "walk"              : "#795548",
}
DEFAULT_COLOUR = "#BDBDBD"


# ============================================================
#  LOAD + VALIDATE
# ============================================================

REQUIRED_COLUMNS = {"ts_ms", "ax", "ay", "az", "gx", "gy", "gz",
                    "mag_raw", "mag_filt", "gyroZ_abs", "baseline",
                    "threshold", "variance", "label"}
UNLABELLED = "unlabelled"


def prepare_frame(df: pd.DataFrame) -> pd.DataFrame:
    """Validate columns and add the helper columns the analysis needs.

    Raises ValueError when a required column is missing. `seq` and `dropped`
    are optional (older captures do not have them); `dropped` defaults to 0.
    Empty labels become "unlabelled".
    """
    missing = REQUIRED_COLUMNS - set(df.columns)
    if missing:
        raise ValueError(f"CSV is missing columns: {sorted(missing)}")

    df = df.copy()
    if "dropped" not in df.columns:
        df["dropped"] = 0
    df["label"] = df["label"].fillna(UNLABELLED).astype(str).str.strip()
    df.loc[df["label"] == "", "label"] = UNLABELLED
    df["t_s"] = (df["ts_ms"] - df["ts_ms"].iloc[0]) / 1000.0
    return df


def load_csv(path: str) -> pd.DataFrame:
    print(f"[LOAD] Reading: {path}")
    return prepare_frame(pd.read_csv(path))


# ============================================================
#  SUMMARY
# ============================================================

def session_summary(df: pd.DataFrame) -> dict:
    """Return rows, duration, mean sample rate, packet loss and rows per label."""
    duration_s = float(df["t_s"].iloc[-1]) if len(df) else 0.0
    hz = len(df) / duration_s if duration_s > 0 else 0.0
    drop_pct = float(df["dropped"].sum()) / len(df) * 100 if len(df) else 0.0
    return {
        "rows": int(len(df)),
        "duration_s": duration_s,
        "hz": hz,
        "drop_pct": drop_pct,
        "label_rows": {str(k): int(v) for k, v in df["label"].value_counts().items()},
    }


def print_summary(df: pd.DataFrame):
    summary = session_summary(df)
    hz = summary["hz"]
    duration_s = summary["duration_s"]

    print()
    print("=" * 55)
    print("  SwimTrack Session Summary")
    print("=" * 55)
    print(f"  Total rows    : {summary['rows']:,}")
    print(f"  Duration      : {duration_s:.1f} s  ({duration_s/60:.1f} min)")
    print(f"  Average rate  : {hz:.1f} Hz")
    print(f"  Packet loss   : {summary['drop_pct']:.2f}%")
    print()
    print(f"  {'Label':<22} {'Rows':>7}  {'Duration':>9}  {'%':>5}")
    print(f"  {'-'*22} {'-'*7}  {'-'*9}  {'-'*5}")
    for label, rows in sorted(summary["label_rows"].items()):
        secs = rows / hz if hz > 0 else 0
        pct  = rows / summary["rows"] * 100
        print(f"  {label:<22} {rows:>7,}  {secs:>8.1f}s  {pct:>4.1f}%")
    print("=" * 55)
    print()


# ============================================================
#  TIME-SERIES PLOT
# ============================================================

def plot_timeseries(df: pd.DataFrame, out_path: str):
    labels_present = df["label"].unique()
    fig = plt.figure(figsize=(18, 12))
    gs  = GridSpec(4, 1, figure=fig, hspace=0.08)

    ax1 = fig.add_subplot(gs[0])
    ax2 = fig.add_subplot(gs[1], sharex=ax1)
    ax3 = fig.add_subplot(gs[2], sharex=ax1)
    ax4 = fig.add_subplot(gs[3], sharex=ax1)

    t = df["t_s"].values

    # ── Panel 1: mag_filt, threshold, baseline ─────────────
    ax1.plot(t, df["mag_filt"],  lw=0.8, color="#2196F3", label="mag_filt")
    ax1.plot(t, df["threshold"], lw=0.8, color="#F44336", ls="--", label="threshold")
    ax1.plot(t, df["baseline"],  lw=0.8, color="#FF9800", ls=":",  label="baseline")
    ax1.set_ylabel("Accel [g]")
    ax1.legend(loc="upper right", fontsize=8)
    ax1.set_title("SwimTrack Session Analysis", fontsize=13, fontweight="bold")

    # ── Panel 2: |gyroZ| ────────────────────────────────────
    ax2.plot(t, df["gyroZ_abs"], lw=0.6, color="#9C27B0", label="|gyroZ|")
    ax2.axhline(CURRENT_TURN_GYRO_Z_THRESH_DPS, color="#F44336",
                ls="--", lw=1.0, label=f"{CURRENT_TURN_GYRO_Z_THRESH_DPS} dps threshold")
    ax2.set_ylabel("|gz| [dps]")
    ax2.legend(loc="upper right", fontsize=8)

    # ── Panel 3: variance ────────────────────────────────────
    ax3.plot(t, df["variance"], lw=0.7, color="#607D8B", label="variance")
    ax3.axhline(CURRENT_REST_VARIANCE_THRESH, color="#4CAF50",
                ls="--", lw=1.0, label=f"{CURRENT_REST_VARIANCE_THRESH} g² threshold")
    ax3.set_ylabel("Variance [g²]")
    ax3.legend(loc="upper right", fontsize=8)

    # ── Panel 4: label colour bar ────────────────────────────
    label_codes = pd.Categorical(df["label"]).codes
    unique_labels = df["label"].unique()
    colours_map = [LABEL_COLOURS.get(l, DEFAULT_COLOUR) for l in df["label"]]
    ax4.scatter(t, [0.5] * len(t), c=colours_map, s=2, marker="|")
    ax4.set_yticks([])
    ax4.set_ylabel("Label")
    ax4.set_xlabel("Time [s]")

    # Legend for label panel
    patches = [mpatches.Patch(color=LABEL_COLOURS.get(l, DEFAULT_COLOUR), label=l)
               for l in sorted(unique_labels)]
    ax4.legend(handles=patches, loc="upper right", fontsize=7, ncol=3)

    # Hide x tick labels on top panels
    for ax in [ax1, ax2, ax3]:
        plt.setp(ax.get_xticklabels(), visible=False)

    plt.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close()
    print(f"[PLOT] Time-series saved: {out_path}")


# ============================================================
#  BOX PLOTS
# ============================================================

def plot_boxplots(df: pd.DataFrame, out_path: str):
    features = ["mag_filt", "gyroZ_abs", "variance"]
    labels   = sorted(df["label"].unique())

    fig, axes = plt.subplots(1, 3, figsize=(16, 6))
    fig.suptitle("Feature Distributions by Label", fontsize=13, fontweight="bold")

    for ax, feat in zip(axes, features):
        data   = [df.loc[df["label"] == l, feat].dropna().values for l in labels]
        colours = [LABEL_COLOURS.get(l, DEFAULT_COLOUR) for l in labels]

        try:
            bp = ax.boxplot(data, patch_artist=True, tick_labels=labels,
                            medianprops=dict(color="black", lw=1.5))
        except TypeError:   # matplotlib < 3.9
            bp = ax.boxplot(data, patch_artist=True, labels=labels,
                            medianprops=dict(color="black", lw=1.5))
        for patch, colour in zip(bp["boxes"], colours):
            patch.set_facecolor(colour)
            patch.set_alpha(0.7)

        # Reference lines
        if feat == "mag_filt":
            pass  # threshold varies per row; no fixed line
        elif feat == "gyroZ_abs":
            ax.axhline(CURRENT_TURN_GYRO_Z_THRESH_DPS, color="red",
                       ls="--", lw=1, label=f"{CURRENT_TURN_GYRO_Z_THRESH_DPS} dps")
            ax.legend(fontsize=8)
        elif feat == "variance":
            ax.axhline(CURRENT_REST_VARIANCE_THRESH, color="green",
                       ls="--", lw=1, label=f"{CURRENT_REST_VARIANCE_THRESH} g²")
            ax.legend(fontsize=8)

        ax.set_title(feat)
        ax.set_xlabel("Label")
        ax.tick_params(axis="x", rotation=35)

    plt.tight_layout()
    plt.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close()
    print(f"[PLOT] Box plots saved: {out_path}")


# ============================================================
#  THRESHOLD SUGGESTIONS
# ============================================================

def suggest_thresholds(df: pd.DataFrame) -> dict:
    print()
    print("=" * 55)
    print("  THRESHOLD SUGGESTIONS")
    print("=" * 55)

    suggestions = {}

    # ── STROKE_THRESHOLD_G ────────────────────────────────────
    swim_df = df[df["label"].isin(SWIMMING_LABELS)]["mag_filt"].dropna()
    rest_df = df[df["label"].isin(REST_LABELS)]["mag_filt"].dropna()

    if len(swim_df) > 10 and len(rest_df) > 10:
        swim_q25 = swim_df.quantile(0.25)
        rest_q75 = rest_df.quantile(0.75)
        baseline_est = rest_df.median()
        suggested_stroke = (swim_q25 + rest_q75) / 2.0 - baseline_est
        suggested_stroke = max(0.05, round(suggested_stroke, 4))
        suggestions["STROKE_THRESHOLD_G"] = suggested_stroke

        print()
        print("  STROKE_THRESHOLD_G")
        print(f"    Swimming mag_filt  median={swim_df.median():.4f}  "
              f"q25={swim_q25:.4f}  q75={swim_df.quantile(0.75):.4f}")
        print(f"    Rest mag_filt      median={rest_df.median():.4f}  "
              f"q25={rest_df.quantile(0.25):.4f}  q75={rest_q75:.4f}")
        print(f"    Current  : {CURRENT_STROKE_THRESHOLD_G:.4f} g  (above baseline)")
        print(f"    > Suggested STROKE_THRESHOLD_G ≈ {suggested_stroke:.4f} g")
    else:
        print()
        print("  STROKE_THRESHOLD_G - not enough swim + rest data to suggest")
        suggestions["STROKE_THRESHOLD_G"] = CURRENT_STROKE_THRESHOLD_G

    # ── TURN_GYRO_Z_THRESH_DPS ───────────────────────────────
    turn_df   = df[df["label"].isin(TURN_LABELS)]["gyroZ_abs"].dropna()
    noturn_df = df[~df["label"].isin(TURN_LABELS)]["gyroZ_abs"].dropna()

    if len(turn_df) > 10 and len(noturn_df) > 10:
        turn_q10   = turn_df.quantile(0.10)
        noturn_q95 = noturn_df.quantile(0.95)
        suggested_turn = (turn_q10 + noturn_q95) / 2.0
        suggested_turn = max(50.0, round(suggested_turn, 1))
        suggestions["TURN_GYRO_Z_THRESH_DPS"] = suggested_turn

        print()
        print("  TURN_GYRO_Z_THRESH_DPS")
        print(f"    Turn |gz|     median={turn_df.median():.1f}  "
              f"q10={turn_q10:.1f}  max={turn_df.max():.1f}")
        print(f"    No-turn |gz|  median={noturn_df.median():.1f}  "
              f"q95={noturn_q95:.1f}  max={noturn_df.max():.1f}")
        print(f"    Current  : {CURRENT_TURN_GYRO_Z_THRESH_DPS:.1f} dps")
        print(f"    > Suggested TURN_GYRO_Z_THRESH_DPS ≈ {suggested_turn:.1f} dps")
    else:
        print()
        print("  TURN_GYRO_Z_THRESH_DPS - not enough turn data to suggest")
        suggestions["TURN_GYRO_Z_THRESH_DPS"] = CURRENT_TURN_GYRO_Z_THRESH_DPS

    # ── REST_VARIANCE_THRESH ──────────────────────────────────
    rest_var   = df[df["label"].isin(REST_LABELS)]["variance"].dropna()
    active_var = df[df["label"].isin(SWIMMING_LABELS)]["variance"].dropna()

    if len(rest_var) > 10 and len(active_var) > 10:
        rest_q90   = rest_var.quantile(0.90)
        active_q10 = active_var.quantile(0.10)
        suggested_var = (rest_q90 + active_q10) / 2.0
        suggested_var = max(0.001, round(suggested_var, 5))
        suggestions["REST_VARIANCE_THRESH"] = suggested_var

        print()
        print("  REST_VARIANCE_THRESH")
        print(f"    Rest variance    median={rest_var.median():.5f}  "
              f"q90={rest_q90:.5f}")
        print(f"    Active variance  median={active_var.median():.5f}  "
              f"q10={active_q10:.5f}")
        print(f"    Current  : {CURRENT_REST_VARIANCE_THRESH:.5f} g²")
        print(f"    > Suggested REST_VARIANCE_THRESH ≈ {suggested_var:.5f} g²")
    else:
        print()
        print("  REST_VARIANCE_THRESH - not enough rest + active data to suggest")
        suggestions["REST_VARIANCE_THRESH"] = CURRENT_REST_VARIANCE_THRESH

    # ── config.h snippet ──────────────────────────────────────
    print()
    print("  -- Candidate values for firmware/include/config.h --")
    print()
    print(f"  #define STROKE_THRESHOLD_G        {suggestions['STROKE_THRESHOLD_G']:.4f}f")
    print(f"  #define TURN_GYRO_Z_THRESH_DPS    {suggestions['TURN_GYRO_Z_THRESH_DPS']:.1f}f")
    print(f"  #define REST_VARIANCE_THRESH      {suggestions['REST_VARIANCE_THRESH']:.5f}f")
    print(f"  #define LAP_MIN_DURATION_MS       15000")
    print()
    print("=" * 55)
    print()

    return suggestions


# ============================================================
#  STROKE CLASSIFIER
# ============================================================

def feature_names(columns=IMU_COLUMNS) -> list:
    return [f"{col}_{stat}" for col in columns for stat in FEATURE_STATS]


def extract_window_features(df: pd.DataFrame, labels,
                            window: int = WINDOW_SAMPLES,
                            step: int = WINDOW_STEP):
    """Slice each label's rows into overlapping windows and compute
    mean / std / min / max for every IMU axis.

    Returns (X, y) as numpy arrays. Windows never span two labels.
    """
    features_list = []
    labels_list = []
    for label in labels:
        sub = df.loc[df["label"] == label, IMU_COLUMNS].to_numpy(dtype=float)
        i = 0
        while i + window <= len(sub):
            win = sub[i:i + window]
            feats = []
            for col_idx in range(win.shape[1]):
                col = win[:, col_idx]
                feats += [col.mean(), col.std(), col.min(), col.max()]
            features_list.append(feats)
            labels_list.append(label)
            i += step
    n_feats = len(IMU_COLUMNS) * len(FEATURE_STATS)
    X = np.array(features_list, dtype=float).reshape(-1, n_feats)
    y = np.array(labels_list)
    return X, y


def train_classifier(X, y, seed: int = 42):
    """Fit a Random Forest and return (classifier, cross-validation scores)."""
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.model_selection import cross_val_score, StratifiedKFold

    classes, counts = np.unique(y, return_counts=True)
    n_splits = int(max(2, min(5, counts.min())))
    clf = RandomForestClassifier(n_estimators=100, max_depth=8,
                                 random_state=seed, n_jobs=-1)
    cv = StratifiedKFold(n_splits=n_splits, shuffle=True, random_state=seed)
    scores = cross_val_score(clf, X, y, cv=cv, scoring="accuracy")
    clf.fit(X, y)
    return clf, scores


def best_tree(clf, X, y):
    """Return the forest member that scores best on (X, y).

    Each tree predicts encoded class indices, so the labels are encoded with
    the forest's own class order before scoring.
    """
    y_idx = np.searchsorted(clf.classes_, y)
    scores = [t.score(X, y_idx) for t in clf.estimators_]
    return clf.estimators_[int(np.argmax(scores))]


def tree_to_cpp(tree, names, class_names, func_name="classifyFeatures") -> str:
    """Render a fitted sklearn decision tree as a C++ function.

    The function takes the features the tree uses as named float arguments
    and returns a StrokeType value, matching firmware/include/stroke_detector.h.
    """
    t = tree.tree_
    used = sorted({names[i] for i in t.feature if i >= 0},
                  key=lambda n: names.index(n))
    args = ", ".join(f"float {n}" for n in used) or "void"

    def enum_name(class_idx):
        return "StrokeType::" + str(class_names[class_idx]).upper()

    lines = [f"StrokeType {func_name}({args})", "{"]

    def walk(node, depth):
        pad = "    " * depth
        left, right = t.children_left[node], t.children_right[node]
        if left == right:   # leaf
            cls = int(np.argmax(t.value[node][0]))
            lines.append(f"{pad}return {enum_name(cls)};")
            return
        feat = names[t.feature[node]]
        thr = float(t.threshold[node])
        lines.append(f"{pad}if ({feat} <= {thr:.4f}f) {{")
        walk(left, depth + 1)
        lines.append(f"{pad}}} else {{")
        walk(right, depth + 1)
        lines.append(f"{pad}}}")

    walk(0, 1)
    lines.append("}")
    return "\n".join(lines) + "\n"


def run_classifier(df: pd.DataFrame, out_dir: str):
    try:
        from sklearn.metrics import classification_report
        from sklearn.tree import export_text
    except ImportError:
        print("[CLASSIFIER] scikit-learn not installed, skipping.")
        print("             Run: pip install -r requirements.txt")
        return None

    stroke_df = df[df["label"].isin(STROKE_LABELS_ML)]
    present = sorted(stroke_df["label"].unique())

    if len(present) < 2:
        print(f"[CLASSIFIER] Only {len(present)} stroke label(s) present "
              f"({list(present)}), need 2+ for classification. Skipping.")
        return None

    print(f"\n[CLASSIFIER] Labels found: {present}")
    print(f"[CLASSIFIER] Extracting {WINDOW_SAMPLES}-sample window features...")

    X, y = extract_window_features(stroke_df, present)
    if len(X) < 20:
        print("[CLASSIFIER] Not enough windows for reliable training "
              f"(got {len(X)}). Collect more data per label.")
        return None

    print(f"[CLASSIFIER] Windows: {len(X)}  Features: {X.shape[1]}")

    clf, scores = train_classifier(X, y)
    print(f"\n[CLASSIFIER] Cross-validation accuracy: "
          f"{scores.mean()*100:.1f}% +/- {scores.std()*100:.1f}%")
    print("[CLASSIFIER] Windows overlap and come from one session, so this "
          "figure is optimistic.")

    print()
    print(classification_report(y, clf.predict(X), target_names=list(clf.classes_)))

    tree = best_tree(clf, X, y)
    names = feature_names()
    class_names = [str(c) for c in clf.classes_]

    tree_path = os.path.join(out_dir, "stroke_classifier.txt")
    with open(tree_path, "w", encoding="utf-8") as f:
        f.write("SwimTrack stroke classifier: best decision tree\n")
        f.write(f"Labels (class index order): {class_names}\n")
        f.write(f"CV accuracy on this session: {scores.mean()*100:.1f}%\n")
        f.write(f"Tree depth: {tree.get_depth()}\n\n")
        f.write(export_text(tree, feature_names=names))

    cpp_path = os.path.join(out_dir, "stroke_classifier.inc")
    with open(cpp_path, "w", encoding="utf-8") as f:
        f.write("// Generated by analyse.py. Review before copying into\n")
        f.write("// firmware/src/stroke_detector_part2.cpp.\n")
        f.write(tree_to_cpp(tree, names, class_names))

    print(f"[CLASSIFIER] Best tree saved: {tree_path}")
    print(f"[CLASSIFIER] C++ snippet saved: {cpp_path}")
    print(f"[CLASSIFIER] Tree depth: {tree.get_depth()}")
    return {"scores": scores, "tree": tree, "classes": class_names,
            "tree_path": tree_path, "cpp_path": cpp_path}


# ============================================================
#  MAIN
# ============================================================

def main(argv=None):
    parser = argparse.ArgumentParser(description="SwimTrack session analyser")
    parser.add_argument("csv", help="CSV file from collect.py")
    parser.add_argument("--no-classifier", dest="no_classifier", action="store_true",
                        help="Skip the stroke classifier step")
    parser.add_argument("--out-dir", dest="out_dir", default=None,
                        help="Where to write plots and classifier files "
                             "(default: next to the CSV)")
    args = parser.parse_args(argv)

    if not os.path.isfile(args.csv):
        sys.exit(f"ERROR: File not found: {args.csv}")

    out_dir  = args.out_dir or os.path.dirname(os.path.abspath(args.csv))
    os.makedirs(out_dir, exist_ok=True)
    stem     = os.path.splitext(os.path.basename(args.csv))[0]

    try:
        df = load_csv(args.csv)
    except ValueError as exc:
        sys.exit(f"ERROR: {exc}\n       Was it created by collect.py?")
    print_summary(df)

    ts_path  = os.path.join(out_dir, f"{stem}_timeseries.png")
    box_path = os.path.join(out_dir, f"{stem}_boxplots.png")

    plot_timeseries(df, ts_path)
    plot_boxplots(df, box_path)

    suggest_thresholds(df)

    if not args.no_classifier:
        run_classifier(df, out_dir)

    print("[DONE] Analysis complete.")
    print(f"[DONE] Plots  : {ts_path}")
    print(f"[DONE]          {box_path}")


if __name__ == "__main__":
    main()