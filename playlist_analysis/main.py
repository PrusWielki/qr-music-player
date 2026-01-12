import requests
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
import spotipy
from spotipy.oauth2 import SpotifyClientCredentials
import os
import sys
from dotenv import load_dotenv
from collections import Counter

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
unique_artist_ids = set()

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
        
        # Get all artists details
        artist_names = [artist["name"] for artist in track["artists"]]
        authors = ", ".join(artist_names)
        
        current_track_artist_ids = []
        for artist in track["artists"]:
            if artist.get("id"):
                current_track_artist_ids.append(artist["id"])
                unique_artist_ids.add(artist["id"])

        # Get Spotify link
        link = track["external_urls"].get("spotify", "")
        
        tracks.append({
            "year": year,
            "Song Name": track["name"],
            "Authors": authors,
            "Album": track["album"]["name"],
            "Link": link,
            "artist_names_list": artist_names,
            "artist_ids": current_track_artist_ids
        })

# --- FETCH GENRES ---
print(f"Fetching details for {len(unique_artist_ids)} artists...")
artist_genres_map = {}
unique_artist_ids_list = list(unique_artist_ids)

# Spotify API allows max 50 artists per request
for i in range(0, len(unique_artist_ids_list), 50):
    chunk = unique_artist_ids_list[i:i+50]
    try:
        artists_info = sp.artists(chunk)
        for artist in artists_info["artists"]:
            if artist:
                artist_genres_map[artist["id"]] = artist["genres"]
    except Exception as e:
        print(f"Error fetching artists chunk: {e}")

# --- AGGREGATE STATS ---
all_genres = []
all_artists = []

for t in tracks:
    all_artists.extend(t["artist_names_list"])
    for aid in t["artist_ids"]:
        genres = artist_genres_map.get(aid, [])
        all_genres.extend(genres)

# --- CREATE DATAFRAME ---
df = pd.DataFrame(tracks)
df["decade"] = (df["year"] // 10) * 10
df = df.sort_values("year")

# Save to CSV
csv_columns = ["year", "Song Name", "Authors", "Album", "Link"]
df[csv_columns].to_csv("playlist_tracks.csv", index=False)
print("Data saved to playlist_tracks.csv")

# --- PLOT HISTOGRAM ---
plt.figure(figsize=(20, 20))
total_songs = len(df)
plt.suptitle(f"Spotify Playlist Analysis (Total Songs: {total_songs})", fontsize=24)
sns.set_style("whitegrid")

min_year = int(df["year"].min())
max_year = int(df["year"].max())

# --- SUBPLOT 1: YEARS ---
plt.subplot(4, 1, 1)
# discrete=True centers bars on integers. shrink=0.9 gives a small gap between bars.
sns.histplot(data=df, x="year", discrete=True, color="green", shrink=0.9)
plt.title("Songs by Release Year")
plt.xlabel("Year")
plt.ylabel("Count")
plt.xticks(ticks=range(min_year, max_year + 1), rotation=90)

# --- SUBPLOT 2: DECADES ---
plt.subplot(4, 1, 2)
sns.countplot(data=df, x="decade", color="skyblue")
plt.title("Songs by Decade")
plt.xlabel("Decade")
plt.ylabel("Count")

# --- SUBPLOT 3: TOP GENRES ---
plt.subplot(4, 1, 3)
genre_counts = Counter(all_genres).most_common(15)
if genre_counts:
    genres_df = pd.DataFrame(genre_counts, columns=["Genre", "Count"])
    sns.barplot(data=genres_df, x="Count", y="Genre", palette="viridis")
    plt.title("Top 15 Genres")
else:
    plt.text(0.5, 0.5, "No Genre Data Available", ha='center')

# --- SUBPLOT 4: TOP ARTISTS ---
plt.subplot(4, 1, 4)
artist_counts = Counter(all_artists).most_common(15)
if artist_counts:
    artists_df = pd.DataFrame(artist_counts, columns=["Artist", "Count"])
    sns.barplot(data=artists_df, x="Count", y="Artist", palette="magma")
    plt.title("Top 15 Artists")
else:
    plt.text(0.5, 0.5, "No Artist Data Available", ha='center')

plt.tight_layout(rect=[0, 0.03, 1, 0.95]) # Adjust layout to make room for suptitle
plt.savefig("playlist_analysis.png")
print("Plot saved to playlist_analysis.png")
