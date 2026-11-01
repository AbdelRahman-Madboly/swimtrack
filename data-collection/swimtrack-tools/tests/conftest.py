import os
import sys

import pytest

TOOLS_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIXTURE_CSV = os.path.join(TOOLS_DIR, "tests", "fixtures", "synthetic_session.csv")

if TOOLS_DIR not in sys.path:
    sys.path.insert(0, TOOLS_DIR)


@pytest.fixture(scope="session")
def fixture_csv():
    return FIXTURE_CSV


@pytest.fixture(scope="session")
def session_df(fixture_csv):
    import analyse
    return analyse.load_csv(fixture_csv)
