#!/usr/bin/env python3
"""
generate_training_data.py
Resonance - Core ML Training Data Generator

Generates synthetic training data for the AudioFeatureRegressor Core ML model.
Uses the 25-genre lookup table from AudioFeaturePredictor's genreLookup to
produce realistic BPM, energy, valence, and instrumentalness values with
duration, era, track number, and explicitness adjustments plus Gaussian noise.

Usage:
    python3 generate_training_data.py [--output training_data.csv]
"""

import argparse
import csv
import random
import sys

# Genre lookup table matching AudioFeaturePredictor.genreLookup in Swift.
# Format: genre -> (bpm, energy, valence, instrumentalness)
GENRE_TABLE = {
    "ambient": (70, 0.15, 0.40, 0.85),
    "classical": (80, 0.25, 0.50, 0.90),
    "jazz": (100, 0.35, 0.55, 0.40),
    "acoustic": (95, 0.30, 0.60, 0.30),
    "folk": (100, 0.35, 0.55, 0.20),
    "country": (110, 0.45, 0.65, 0.10),
    "r&b": (85, 0.40, 0.55, 0.10),
    "soul": (90, 0.40, 0.60, 0.10),
    "pop": (120, 0.55, 0.70, 0.05),
    "indie": (115, 0.45, 0.50, 0.15),
    "alternative": (118, 0.50, 0.45, 0.15),
    "rock": (130, 0.70, 0.50, 0.15),
    "punk": (160, 0.80, 0.45, 0.10),
    "metal": (140, 0.85, 0.30, 0.20),
    "electronic": (128, 0.65, 0.55, 0.60),
    "dance": (128, 0.75, 0.70, 0.40),
    "house": (126, 0.70, 0.60, 0.55),
    "techno": (130, 0.75, 0.40, 0.75),
    "hip-hop": (90, 0.50, 0.45, 0.05),
    "rap": (85, 0.55, 0.40, 0.05),
    "trap": (140, 0.60, 0.35, 0.10),
    "reggae": (80, 0.40, 0.65, 0.15),
    "latin": (100, 0.60, 0.75, 0.10),
    "k-pop": (125, 0.70, 0.75, 0.05),
    "lofi": (75, 0.20, 0.45, 0.60),
}

# Noise standard deviation as a fraction of the value range for each feature.
NOISE_SIGMA_FRACTION = 0.05

# Value ranges for computing noise sigma.
BPM_RANGE = 180.0    # 40 - 220
UNIT_RANGE = 1.0     # 0.0 - 1.0


def clamp(value: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, value))


def add_noise(value: float, sigma: float, lo: float, hi: float) -> float:
    return clamp(value + random.gauss(0, sigma), lo, hi)


def generate_rows():
    """Yields one dict per synthetic training sample."""
    durations = list(range(90, 601, 30))       # 90s to 600s, step 30
    years = list(range(1960, 2027, 5))          # 1960 to 2026, step 5
    track_numbers = [1, 3, 6, 10]
    explicit_flags = [0, 1]

    bpm_sigma = BPM_RANGE * NOISE_SIGMA_FRACTION
    unit_sigma = UNIT_RANGE * NOISE_SIGMA_FRACTION

    for genre, (base_bpm, base_energy, base_valence, base_inst) in GENRE_TABLE.items():
        for duration in durations:
            for year in years:
                for track_num in track_numbers:
                    for is_explicit in explicit_flags:
                        bpm = base_bpm
                        energy = base_energy
                        valence = base_valence
                        instrumentalness = base_inst

                        # Duration adjustments
                        if duration < 180:
                            energy = min(1.0, energy + 0.05)
                        elif duration > 360:
                            energy = max(0.0, energy - 0.05)
                            bpm = max(60, bpm - 10)

                        # Era adjustments
                        if year < 1980:
                            energy = max(0.0, energy - 0.05)
                        elif year >= 2010:
                            energy = min(1.0, energy + 0.03)

                        # Track number: opening tracks (1-2) get energy boost
                        if track_num <= 2:
                            energy = min(1.0, energy + 0.04)

                        # Explicit content: slightly higher energy, edgier valence
                        if is_explicit:
                            energy = min(1.0, energy + 0.03)
                            valence = max(0.0, valence - 0.03)

                        # Add Gaussian noise
                        bpm = add_noise(bpm, bpm_sigma, 40, 220)
                        energy = add_noise(energy, unit_sigma, 0.0, 1.0)
                        valence = add_noise(valence, unit_sigma, 0.0, 1.0)
                        instrumentalness = add_noise(
                            instrumentalness, unit_sigma, 0.0, 1.0
                        )

                        # genreCount: simulate 1-4 genre tags
                        genre_count = random.choice([1, 1, 2, 2, 3, 4])

                        yield {
                            "genre": genre,
                            "duration": duration,
                            "year": year,
                            "genreCount": genre_count,
                            "trackNumber": track_num,
                            "isExplicit": is_explicit,
                            "bpm": round(bpm, 2),
                            "energy": round(energy, 4),
                            "valence": round(valence, 4),
                            "instrumentalness": round(instrumentalness, 4),
                        }


def main():
    parser = argparse.ArgumentParser(
        description="Generate synthetic training data for AudioFeatureRegressor."
    )
    parser.add_argument(
        "--output",
        default="training_data.csv",
        help="Output CSV file path (default: training_data.csv)",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        help="Random seed for reproducibility (default: 42)",
    )
    args = parser.parse_args()

    random.seed(args.seed)

    fieldnames = [
        "genre", "duration", "year", "genreCount", "trackNumber",
        "isExplicit", "bpm", "energy", "valence", "instrumentalness",
    ]

    row_count = 0
    with open(args.output, "w", newline="") as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        for row in generate_rows():
            writer.writerow(row)
            row_count += 1

    print(f"Generated {row_count} training samples -> {args.output}")


if __name__ == "__main__":
    main()
