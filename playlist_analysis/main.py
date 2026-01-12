import requests
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
import spotipy
from spotipy.oauth2 import SpotifyClientCredentials
import os
import sys
from dotenv import load_dotenv

load_dotenv()

# --- CONFIG ---
playlist_url = "https://open.spotify.com/playlist/56afGpmssmu4sR9Pz92jfE"  # <-- put your playlist link here
playlist_id = playlist_url.split("/")[-1].split("?")[0]

# --- AUTH CONFIG ---
if not os.environ.get("SPOTIPY_CLIENT_ID") or not os.environ.get("SPOTIPY_CLIENT_SECRET"):
    print("Error: SPOTIPY_CLIENT_ID and SPOTIPY_CLIENT_SECRET environment variables are required.")
    print("Please set them directly or create a .env file (if using python-dotenv).")
    print("You can get credentials at https://developer.spotify.com/dashboard")
    sys.exit(1)

auth_manager = SpotifyClientCredentials()
sp = spotipy.Spotify(auth_manager=auth_manager)

# --- FETCH PLAYLIST DATA ---
print(f"Fetching playlist {playlist_id}...")
# Fetch playlist info first to verify access, though playlist_items handles tracks
try:
    results = sp.playlist_items(playlist_id)
except spotipy.exceptions.SpotifyException as e:
    print(f"Error fetching playlist: {e}")
    sys.exit(1)

# --- EXTRACT SONGS AND YEARS ---
tracks = []
items = results['items']
while results['next']:
    results = sp.next(results)
    items.extend(results['items'])

for item in items:
    track = item["track"]
    if not track:
        continue
    # Some local files or abnormal tracks might not have album/release_date
    if track.get("album") and track["album"].get("release_date"):
        release_date = track["album"]["release_date"]
        # Handle year-only or incomplete dates
        year = int(release_date[:4])
        tracks.append({
            "track": track["name"],
            "artist": track["artists"][0]["name"],
            "year": year
        })

# --- CREATE DATAFRAME ---
df = pd.DataFrame(tracks)
df["decade"] = (df["year"] // 10) * 10
df = df.sort_values("year")

# --- PLOT HISTOGRAM ---
plt.figure(figsize=(15, 12))
total_songs = len(df)
plt.suptitle(f"Spotify Playlist Analysis (Total Songs: {total_songs})", fontsize=20)
sns.set_style("whitegrid")
min_year = int(df["year"].min())
max_year = int(df["year"].max())

# --- SUBPLOT 1: YEARS ---
plt.subplot(2, 1, 1)
# discrete=True centers bars on integers. shrink=0.9 gives a small gap between bars.
sns.histplot(data=df, x="year", discrete=True, color="green", shrink=0.9)

plt.title("Spotify Playlist – Songs by Release Year")
plt.xlabel("Year")
plt.ylabel("Number of Songs")

# Show every year on x-axis and rotate labels
plt.xticks(ticks=range(min_year, max_year + 1), rotation=90)

# --- SUBPLOT 2: DECADES ---
plt.subplot(2, 1, 2)
sns.countplot(data=df, x="decade", color="skyblue")
plt.title("Spotify Playlist – Songs by Decade")
plt.xlabel("Decade")
plt.ylabel("Number of Songs")

plt.tight_layout()
plt.savefig("playlist_years.png")
print("Plot saved to playlist_years.png")
