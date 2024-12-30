#!/usr/bin/python3
"""
Combine DQM tables from a list of files into a single table.

"""

import argparse
import logging

from astropy.io import fits
from astropy.table import Table, vstack


def combine_tables(file_list, output_file):
    """
    Combine tables

    """

    const_table_name = "DQM"

    logging.info("Combine DQM tables from a list of files into a single table.")

    logging.info(f"Reading file list from {file_list}")
    with open(file_list) as f:
        fits_files = f.readlines()
    fits_files = [x.strip() for x in fits_files]

    logging.info(f"Combining {len(fits_files)} files")
    print(fits_files)

    # Batch size for opening files
    batch_size = 1000
    combined_tables = []

    for i in range(0, len(fits_files), batch_size):
        batch_files = fits_files[i : i + batch_size]
        batch_tables = []

        for fits_file in batch_files:
            try:
                with fits.open(fits_file) as hdul:
                    if hdul[1].name == const_table_name:
                        table = Table(hdul[1].data)
                        batch_tables.append(table)
            except FileNotFoundError:
                logging.warning(f"File {fits_file} not found")
                pass

        combined_tables.extend(batch_tables)

    final_combined_table = vstack(combined_tables, join_type="exact")
    logging.info(f"Writing combined table to {output_file}")
    final_combined_table.write(output_file, overwrite=True)


def main():
    logging.basicConfig(level=logging.INFO)
    parser = argparse.ArgumentParser(
        description="Combine DQM tables from a list of files into a single table."
    )
    parser.add_argument(
        "--input_file_list", type=str, required=True, help="List of input files to combine"
    )
    parser.add_argument("--output_file", type=str, required=True, help="Output file name")
    args = parser.parse_args()

    combine_tables(args.input_file_list, args.output_file)


if __name__ == "__main__":
    main()
