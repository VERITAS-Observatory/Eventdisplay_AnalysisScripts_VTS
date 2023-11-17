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

import astropy
import numpy as np
from astropy.io import fits
from astropy.table import Table
from unidecode import unidecode


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
        "--input_path",
        type=str,
        required=True,
        help="Path to DBTEXT files",
    )

    parser.add_argument(
        "--output_path",
        type=str,
        required=True,
        help="Output path for FITS file",
    )

    args = parser.parse_args()

    return args


def read_file(file_path):
    """
    Read DB file (in sql format) and return as astropy table

    """

    # check if file size is zero
    try:
        if os.path.getsize(file_path) == 0:
            logging.info("File %s is empty", file_path)
            return None
    except FileNotFoundError:
        logging.error("Error reading %s", file_path)
        return None

    try:
        table = Table.read(file_path, format="ascii.basic", delimiter="|", comment="#")
    except astropy.io.ascii.core.InconsistentTableError:
        logging.error("Error reading %s", file_path)
        return None

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
    if table is None:
        return np.nan, np.nan, None, np.nan, np.nan

    condition = table["run_id"] == run
    table = table[condition]
    time_diffs = np.diff(np.array(table["timestamp"])) / 1000.0
    l3_values = np.diff(np.array(table["L3"], dtype=float))
    l3_values /= time_diffs

    if len(l3_values) > 0:
        l3_mean = np.mean(l3_values)
        # standard deviation excluding outliers (>3 sigma)
        l3_std = np.std(l3_values[np.abs(l3_values - np.mean(l3_values)) < 3 * np.std(l3_values)])
    else:
        l3_mean = np.nan
        l3_std = np.nan

    # (exclude first value, as for l3_values)
    try:
        time_since_run_start = (np.array(table["timestamp"][1:]) - table["timestamp"][0]) / 1000.0
    except IndexError:
        time_since_run_start = np.array([])

    l3_table = Table([time_since_run_start, l3_values], names=("time", "l3_rate"))

    # dead time
    try:
        l3_busy = np.array(table["L3orVDAQBusyScaler"], dtype=float)
        busy = np.diff(l3_busy)
        ten_mhz = np.diff(np.array(table["TenMHzScaler"]))
        dead_time = np.mean(busy / ten_mhz)
        dead_time_std = np.std(busy / ten_mhz)
    except ValueError:
        dead_time = np.nan
        dead_time_std = np.nan

    return l3_mean, l3_std, l3_table, dead_time, dead_time_std


def extract_elevation(run, temp_run_dir, config_mask):
    """
    return mean elevation of a run
    (assuming that all telescopes point in the same direction)

    """

    elevation_tel = []

    for i in range(0, 4):
        if config_mask & (1 << i):
            table = read_file(os.path.join(temp_run_dir, f"{run}.rawpointing_TEL{i}"))
            if table is not None:
                meas_el = np.array(table["elevation_meas"], dtype=float)
                elevation_tel.append(meas_el.mean())

    return np.mean(elevation_tel) * 180.0 / np.pi


def fir_correction(elevation, temp):
    """
    Correct FIR for ambient temperature

    """

    return -0.0026 * elevation**2 + 0.434 * elevation - 0.65 * temp


def extract_corrected_fir(fir_mean, ambient_temp, run, temp_run_dir, config_mask):
    """
    Correct FIR for ambient temperature

    """

    if fir_mean is None:
        return np.nan

    elevation = extract_elevation(run, temp_run_dir, config_mask)
    return fir_mean + (fir_correction(elevation, ambient_temp) - fir_correction(90.0, 20.0))


def extract_fir(run, temp_run_dir, config_mask):
    """
    Extract mean and std of FIR values for the three different FIRS

    """

    table = read_file(os.path.join(temp_run_dir, f"{run}.fir"))
    if table is None:
        return {
            "fir_mean_0": np.nan,
            "fir_mean_1": np.nan,
            "fir_mean_3": np.nan,
            "fir_std_0": np.nan,
            "fir_std_1": np.nan,
            "fir_std_3": np.nan,
            "fir_mean_corrected_0": np.nan,
            "fir_mean_corrected_1": np.nan,
            "fir_mean_corrected_3": np.nan,
        }

    tel_ids = (0, 1, 3)
    fir_mean = []
    fir_std = []
    fir_ambient_temp = []

    for tel in tel_ids:
        condition = table["telescope_id"] == tel
        table_tel = table[condition]
        if len(table_tel) > 0:
            fir_mean.append(table_tel["radiant_sky_temp"].mean())
            fir_std.append(table_tel["radiant_sky_temp"].std())
            fir_ambient_temp.append(table_tel["ambient_temp"].mean())
        else:
            fir_mean.append(np.nan)
            fir_std.append(np.nan)
            fir_ambient_temp.append(np.nan)

    return {
        "fir_mean_0": fir_mean[0],
        "fir_mean_1": fir_mean[1],
        "fir_mean_3": fir_mean[2],
        "fir_std_0": fir_std[0],
        "fir_std_1": fir_std[1],
        "fir_std_3": fir_std[2],
        "fir_mean_corrected_0": extract_corrected_fir(
            fir_mean[0], fir_ambient_temp[0], run, temp_run_dir, config_mask
        ),
        "fir_mean_corrected_1": extract_corrected_fir(
            fir_mean[1], fir_ambient_temp[1], run, temp_run_dir, config_mask
        ),
        "fir_mean_corrected_3": extract_corrected_fir(
            fir_mean[2], fir_ambient_temp[2], run, temp_run_dir, config_mask
        ),
    }


def extract_weather(run, temp_run_dir):
    """
    Extract weather information

    """

    table = read_file(os.path.join(temp_run_dir, f"{run}.weather"))
    weather = {}

    if table is not None:
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
            if table is not None:
                current = np.array(table["current_meas"], dtype=float)
                current = current[current > 0.5]
                if len(current) > 0:
                    nsb_mean.append(current.mean())
                    nsb_median.append(np.median(current))
                    nsb_std.append(current.std())

    if len(nsb_mean) > 0:
        return np.mean(nsb_mean), np.mean(nsb_median), np.mean(nsb_std)
    return np.nan, np.nan, np.nan


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
    if run_dqm is not None:
        row["data_category"] = run_dqm["data_category"][0]
        row["dqm_status"] = run_dqm["status"][0]
        row["dqm_status_reason"] = run_dqm["status_reason"][0]
        row["dqm_tel_cut_mask"] = run_dqm["tel_cut_mask"][0]
        row["vpm_config_mask"] = run_dqm["vpm_config_mask"][0]
        row["light_level"] = run_dqm["light_level"][0]
        row["dqm_comment"] = convert_to_ascii(str(run_dqm["comment"][0]))
    else:
        row["data_category"] = ""
        row["dqm_status"] = ""
        row["dqm_status_reason"] = ""
        row["dqm_tel_cut_mask"] = np.nan
        row["vpm_config_mask"] = np.nan
        row["light_level"] = np.nan
        row["dqm_comment"] = ""


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
    row.update(extract_fir(run, temp_run_dir, row["config_mask"]))

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


def convert_to_ascii(text):
    """
    Convert to ascii

    """
    return unidecode(text)


def convert_table_comment_to_ascii(table):
    """
    Convert comment column to ascii

    """

    column_name = ["comment", "authors"]

    try:
        for name in column_name:
            if name in table.colnames:
                for i, row in enumerate(table):
                    old_length = len(row[name])
                    new_string = convert_to_ascii(row[name])
                    table[i][name] = new_string[:old_length]
    except AttributeError:
        pass


def main():
    logging.basicConfig(level=logging.INFO)

    parse = read_args()

    tar_file = get_tar_file_name(parse.run, parse.input_path)
    logging.info(f"Reading run {parse.run} from {tar_file}")

    # Create a temporary directory
    temp_dir = os.path.join(parse.output_path, "temp")
    logging.info("Temporary directory: %s", temp_dir)

    # open fits file to write all tables to
    fits_file = os.path.join(parse.output_path, f"{parse.run}.db.fits.gz")
    logging.info("Writing to %s", fits_file)

    try:
        # Extract the tar archive into the temporary directory
        try:
            with tarfile.open(tar_file, "r") as tar:
                tar.extractall(temp_dir)
        except FileNotFoundError:
            logging.error("File %s not found", tar_file)
            return
        temp_run_files = os.path.join(temp_dir, str(parse.run))

        dqm_table, l3_table = extract_dqm_table(parse.run, temp_run_files)

        hdu = []
        hdu.append(fits.PrimaryHDU())

        hdu.append(fits.BinTableHDU(dqm_table))
        hdu[-1].name = "DQM"
        hdu.append(fits.BinTableHDU(l3_table))
        hdu[-1].name = "L3"

        for file_name in os.listdir(temp_run_files):
            file_path = os.path.join(temp_run_files, file_name)
            logging.info("Converting %s", file_path)
            table = read_file(file_path)
            if "dqm" in file_name.lower():
                convert_table_comment_to_ascii(table)
            if table is not None:
                hdu.append(fits.BinTableHDU(table))
                hdu[-1].name = file_name.split(".")[1]

        hdul = fits.HDUList(hdu)
        hdul.writeto(fits_file, overwrite=True)

    finally:
        # Delete the temporary directory and its contents
        logging.info("Deleting %s", temp_dir)

#        shutil.rmtree(temp_dir)


if __name__ == "__main__":
    main()
