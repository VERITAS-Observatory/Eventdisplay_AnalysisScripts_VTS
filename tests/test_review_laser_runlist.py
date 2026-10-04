"""Exercise the laser wrapper with distinct per-telescope calibration runs."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def executable(path, body):
    path.write_text("#!/bin/bash\n" + body)
    path.chmod(0o755)


with tempfile.TemporaryDirectory() as temporary:
    directory = Path(temporary)
    scripts = directory / "scripts"
    scripts.mkdir()
    (scripts / "helper_scripts").mkdir()
    (directory / "bin").mkdir()
    (directory / "data").mkdir()
    (directory / "Calibration/Tel_1").mkdir(parents=True)
    (directory / "Calibration/Tel_2").mkdir()
    wrapper = scripts / "SPANALYSIS.evndisp_laser_runs_from_runlist.sh"
    shutil.copyfile(Path(__file__).resolve().parents[1] / "scripts" / wrapper.name, wrapper)
    executable(scripts / "helper_scripts/UTILITY.script_init.sh", "exit 0\n")
    executable(directory / "bin/VTS.getLaserRunFromDB", """
echo "$*" >> "$LASER_LOOKUPS"
[[ $2 == 120000 ]] || exit 9
case $1 in 1) echo 70001;; 2) echo 120002;; *) exit 9;; esac
""")
    executable(scripts / "SPANALYSIS.evndisp_laser_run.sh", """
echo "$*" >> "$LASER_CALLS"
exit "${CALIBRATION_STATUS:-0}"
""")
    (directory / "data/70001.cvbf").touch()
    (directory / "data/120002.cvbf").touch()
    runlist = directory / "runs"
    runlist.write_text("120000\n")
    calls = directory / "calls"
    lookups = directory / "lookups"
    environment = os.environ.copy()
    environment.pop("LASER_RUNFILE", None)
    environment.update(VERITAS_DATA_DIR=temporary, VERITAS_EVNDISP_AUX_DIR=temporary,
                       EVNDISPSYS=temporary, LASER_CALLS=str(calls), LASER_LOOKUPS=str(lookups))

    def run():
        return subprocess.run(["bash", str(wrapper), str(runlist), "12"],
                              env=environment, text=True, capture_output=True)

    result = run()
    assert result.returncode == 0, result.stdout + result.stderr
    assert calls.exists(), "Existing raw laser files did not trigger calibration"
    assert calls.read_text().splitlines() == ["70001 1", "120002 2"]
    assert lookups.read_text().splitlines() == ["1 120000", "2 120000"]

    # An existing telescope calibration skips only that telescope's processing.
    (directory / "Calibration/Tel_1/70001.gain.root").touch()
    calls.unlink()
    result = run()
    assert result.returncode == 0
    assert calls.read_text().splitlines() == ["120002 2"]

    # A real calibration failure must propagate to the batch caller.
    environment["CALIBRATION_STATUS"] = "7"
    assert run().returncode != 0

print("PASS laser file discovery, distinct telescope runs, existing calibration and failure propagation")
