#!/usr/bin/python3
"""
Combine all DB tables into a single FITS file for a given observation run.
Calculate and print a DQM summary for the observation run.

Example:

    $ python3 db_write_fits.py --run 64080 \
        --output_path /path/to/output.fits \
        --input_path $VERITAS_DATA_DIR/DBTEXT

"""

import argparse
import logging
import os
import tarfile

import numpy as np
from astropy.table import Table


def read_args():
    """Read command line arguments."""

    parser = argparse.ArgumentParser(description=__doc__)

    parser.add_argument(
        "--run",
        type=int,
        required=True,
        help="Run number",
    )

    parser.add_argument(
        "--output_path",
        type=str,
        required=True,
        help="Output path for FITS file",
    )

    parser.add_argument(
        "--input_path",
        type=str,
        required=True,
        help="Path to DBTEXT files",
    )

    args = parser.parse_args()

    return args


def read_file(file_path):
    """
    Read DB file (in sql format) and return as astropy table

    """

    table = Table.read(file_path, format="ascii.basic", delimiter="|", comment="#")

    return table


def extract_l3_rate(run, temp_run_dir):
    """
    Calculate L3 rate and dead times

    Returns
    -------
    l3_mean : float
        Mean L3 rate
    l3_std : float
        Standard deviation of L3 rate (excluding outliers)
    l3_table: astropy.table.Table
        Table of L3 rate values
    dead_time: float
        Mean dead time
    dead_time_std: float
        Standard deviation of dead time (excluding outliers)

    """

    table = read_file(os.path.join(temp_run_dir, f"{run}.L3"))
    condition = table["run_id"] == run
    table = table[condition]
    time_diffs = np.diff(np.array(table["timestamp"])) / 1000.0
    l3_values = np.diff(np.array(table["L3"], dtype=float))
    l3_values /= time_diffs

    l3_mean = np.mean(l3_values)
    # standard deviation excluding outliers (>3 sigma)
    l3_std = np.std(l3_values[np.abs(l3_values - np.mean(l3_values)) < 3 * np.std(l3_values)])

    # (exclude first value, as for l3_values)
    time_since_run_start = (np.array(table["timestamp"][1:]) - table["timestamp"][0]) / 1000.0

    l3_table = Table([time_since_run_start, l3_values], names=("time", "l3_rate"))

    # dead time
    busy = np.diff(np.array(table["L3orVDAQBusyScaler"]))
    ten_mhz = np.diff(np.array(table["TenMHzScaler"]))
    dead_time = np.mean(busy / ten_mhz)
    dead_time_std = np.std(busy / ten_mhz)

    return l3_mean, l3_std, l3_table, dead_time, dead_time_std


def extract_fir(run, temp_run_dir):
    """
    Extract mean and std of FIR values for the three different FIRS

    """

    table = read_file(os.path.join(temp_run_dir, f"{run}.fir"))

    tel_ids = (0, 1, 3)
    fir_mean = []
    fir_std = []

    for tel in tel_ids:
        condition = table["telescope_id"] == tel
        table_tel = table[condition]
        fir_mean.append(table_tel["radiant_sky_temp"].mean())
        fir_std.append(table_tel["radiant_sky_temp"].std())

    return {
        "fir_mean_0": fir_mean[0],
        "fir_mean_1": fir_mean[1],
        "fir_mean_3": fir_mean[2],
        "fir_std_0": fir_std[0],
        "fir_std_1": fir_std[1],
        "fir_std_3": fir_std[2],
    }


def extract_weather(run, temp_run_dir):
    """
    Extract weather information

    """

    table = read_file(os.path.join(temp_run_dir, f"{run}.weather"))

    weather = {}

    weather["wind_speed_mean"] = table["WS_mph_Avg"].mean()
    weather["wind_speed_max"] = table["WS_mph_Max"].mean()
    weather["wind_speed_min"] = table["WS_mph_Min"].mean()
    weather["wind_speed_dir"] = table["WindDir"].mean()
    weather["air_temperature"] = table["AirTF_Avg"].mean()
    weather["relative_humidity"] = table["RH"].mean()

    return weather


def extract_nsb(run, temp_run_dir, config_mask):
    """
    Extract mean and std of NSB values from participating telescopes

    """

    nsb_mean = []
    nsb_median = []
    nsb_std = []

    for i in range(0, 4):
        if config_mask & (1 << i):
            table = read_file(os.path.join(temp_run_dir, f"{run}.HVsettings_TEL{i}"))
            current = np.array(table["current_meas"], dtype=float)
            current = current[current > 0.5]
            nsb_mean.append(current.mean())
            nsb_median.append(np.median(current))
            nsb_std.append(current.std())

    if len(nsb_mean) > 0:
        return np.mean(nsb_mean), np.mean(nsb_median), np.mean(nsb_std)
    return None, None


def extract_dqm_table(run, temp_run_dir):
    """
    Extract DQM row and return as astropy table

    """

    row = {}

    # run info
    run_info = read_file(os.path.join(temp_run_dir, f"{run}.runinfo"))
    row["run_id"] = run_info["run_id"][0]
    row["run_type"] = run_info["run_type"][0]
    row["observing_mode"] = run_info["observing_mode"][0]
    row["run_status"] = run_info["run_status"][0]
    row["weather"] = run_info["weather"][0]
    row["config_mask"] = run_info["config_mask"][0]
    row["trigger_config"] = run_info["trigger_config"][0]

    # run dqm
    run_dqm = read_file(os.path.join(temp_run_dir, f"{run}.rundqm"))
    row["data_category"] = run_dqm["data_category"][0]
    row["dqm_status"] = run_dqm["status"][0]
    row["dqm_status_reason"] = run_dqm["status_reason"][0]
    row["dqm_tel_cut_mask"] = run_dqm["tel_cut_mask"][0]
    row["light_level"] = run_dqm["light_level"][0]
    row["dqm_comment"] = run_dqm["comment"][0]

    # L3 rate
    (
        row["l3_rate_mean"],
        row["l3_rate_std"],
        l3_table,
        row["dead_time"],
        row["dead_time_std"],
    ) = extract_l3_rate(run, temp_run_dir)

    # currents (nsb)
    row["nsb_mean"], row["nsb_median"], row["nsb_std"] = extract_nsb(
        run, temp_run_dir, row["config_mask"]
    )

    # weather
    row.update(extract_weather(run, temp_run_dir))

    # FIR temperature
    row.update(extract_fir(run, temp_run_dir))

    print("DQM row: ", row)

    return Table([row]), l3_table


def get_tar_file_name(run, input_path):
    """
    Get name of tar file for given run
    (preprocessing directory type)

    """

    subdir = str(run)[0]
    if run > 99999:
        subdir = str(run)[0:2]
    return f"{input_path}/{subdir}/{run}.tar.gz"


def main():
    logging.basicConfig(level=logging.INFO)

    parse = read_args()

    tar_file = get_tar_file_name(parse.run, parse.input_path)
    logging.info(f"Reading run {parse.run} from {tar_file}")

    # Create a temporary directory
    temp_dir = os.path.join(parse.output_path, "temp")
    logging.info("Temporary directory: %s", temp_dir)

    # open fits file to write all tables to
    fits_file = os.path.join(parse.output_path, f"{parse.run}.db.fits")
    logging.info("Writing to %s", fits_file)

    try:
        # Extract the tar archive into the temporary directory
        with tarfile.open(tar_file, "r") as tar:
            tar.extractall(temp_dir)
        temp_run_files = os.path.join(temp_dir, str(parse.run))

        dqm_table, l3_table = extract_dqm_table(parse.run, temp_run_files)

        dqm_table.write(fits_file, format="fits", overwrite=True)
        l3_table.write(fits_file, format="fits", overwrite=True)

        for file_name in os.listdir(temp_run_files):
            file_path = os.path.join(temp_run_files, file_name)
            logging.info("Converting %s", file_path)
            table = read_file(file_path)
            table.write(fits_file, format="fits", append=True)

    finally:
        # Delete the temporary directory and its contents
        logging.info("Deleting %s", temp_dir)


#        shutil.rmtree(temp_dir)


if __name__ == "__main__":
    main()
