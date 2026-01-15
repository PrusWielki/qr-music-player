const stateKey = 'spotify_auth_state';
const codeVerifierKey = 'spotify_code_verifier';

const loadingSection = document.getElementById('loading-section');
const resultsSection = document.getElementById('results-section');

const HARDCODED_PLAYLIST_ID = '56afGpmssmu4sR9Pz92jfE';

function generateRandomString(length) {
    let text = '';
    const possible = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    for (let i = 0; i < length; i++) {
        text += possible.charAt(Math.floor(Math.random() * possible.length));
    }
    return text;
}

async function sha256(plain) {
    if (!plain) return null;
    const encoder = new TextEncoder();
    const data = encoder.encode(plain);
    return window.crypto.subtle.digest('SHA-256', data);
}

function base64urlencode(a) {
    return btoa(String.fromCharCode.apply(null, new Uint8Array(a)))
        .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function login() {
    let clientId = getClientId();
    if (!clientId) {
        return; 
    }

    const redirectUri = window.location.href.split('?')[0].split('#')[0];
    const state = generateRandomString(16);
    const codeVerifier = generateRandomString(64);
    
    localStorage.setItem(stateKey, state);
    localStorage.setItem(codeVerifierKey, codeVerifier);

    const hashed = await sha256(codeVerifier);
    const codeChallenge = base64urlencode(hashed);

    const scope = 'playlist-read-private playlist-read-collaborative';
    
    let url = 'https://accounts.spotify.com/authorize';
    url += '?response_type=code'; 
    url += '&client_id=' + encodeURIComponent(clientId);
    url += '&scope=' + encodeURIComponent(scope);
    url += '&redirect_uri=' + encodeURIComponent(redirectUri);
    url += '&state=' + encodeURIComponent(state);
    url += '&code_challenge_method=S256';
    url += '&code_challenge=' + codeChallenge;

    window.location = url;
}

async function getToken(code) {
    let clientId = getClientId();
    const codeVerifier = localStorage.getItem(codeVerifierKey);
    const redirectUri = window.location.href.split('?')[0].split('#')[0];

    const payload = {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
            client_id: clientId,
            grant_type: 'authorization_code',
            code: code,
            redirect_uri: redirectUri,
            code_verifier: codeVerifier,
        }),
    };

    const body = await fetch("https://accounts.spotify.com/api/token", payload);
    const text = await body.text();
    
    if (!body.ok) {
        try {
            const err = JSON.parse(text);
            throw new Error(err.error_description || err.error || body.statusText);
        } catch (e) {
             throw new Error("Token Error: " + text.substring(0, 100));
        }
    }
    
    const response = JSON.parse(text);
    return response.access_token;
}

function getClientId() {
    if (window.ENV && window.ENV.SPOTIFY_CLIENT_ID && window.ENV.SPOTIFY_CLIENT_ID !== '__SPOTIFY_CLIENT_ID__') {
        return window.ENV.SPOTIFY_CLIENT_ID.trim();
    }
    return null;
}

async function init() {
    const args = new URLSearchParams(window.location.search);
    const code = args.get('code');
    const error = args.get('error');

    if (error) {
        alert("Authentication failed: " + error);
        return; 
    }

    if (code) {
        document.getElementById('loading-text').innerText = "Authenticating...";
        
        try {
            const token = await getToken(code);
            if (token) {
                localStorage.setItem('spotify_token', token);
                window.history.replaceState({}, document.title, "/");
                
                startAnalysis(token);
            } else {
                alert("Authentication failed: No token received");
            }
        } catch(e) {
            console.error(e);
            alert("Error during token exchange: " + e.message);
        }
    } else if (localStorage.getItem('spotify_token')) {
        startAnalysis(localStorage.getItem('spotify_token'));
    } else {
        document.getElementById('loading-text').innerText = "Redirecting to Spotify...";
        
        const checkInterval = setInterval(() => {
            if (getClientId()) {
                clearInterval(checkInterval);
                login();
            }
        }, 100); 
        
        setTimeout(() => {
            if (!getClientId()) {
                 clearInterval(checkInterval);
                 loadingSection.classList.add('hidden');
                 alert("Client ID not configured. Please deploy via GitHub Actions or set window.ENV.SPOTIFY_CLIENT_ID.");
            }
        }, 2000);
    }
}

init();

async function startAnalysis(token) {
    loadingSection.classList.remove('hidden');
    document.getElementById('loading-text').innerText = "Fetching tracks...";

    try {
        await analyzePlaylist(HARDCODED_PLAYLIST_ID, token);
        loadingSection.classList.add('hidden');
        resultsSection.classList.remove('hidden');
    } catch (e) {
        console.error(e);
        if (e.message.includes("401") || e.message.includes("Expired") || e.message.includes("Unauthorized")) {
            console.log("Token expired, clearing and reloading");
            localStorage.removeItem('spotify_token');
            window.location.reload();
        } else {
            alert("Error: " + e.message);
            loadingSection.classList.add('hidden');
        }
    }
}

async function analyzePlaylist(playlistId, token) {
    let items = [];
    let nextUrl = `https://api.spotify.com/v1/playlists/${playlistId}/tracks?limit=50`;

    while (nextUrl) {
        const response = await fetch(nextUrl, {
            headers: { 'Authorization': 'Bearer ' + token }
        });
        
        if (!response.ok) {
            if (response.status === 401) {
                throw new Error("Unauthorized (401)");
            }
            const text = await response.text();
            try {
                const err = JSON.parse(text);
                throw new Error(err.error?.message || response.statusText);
            } catch (jsonErr) {
                throw new Error(text.substring(0, 100) || response.statusText);
            }
        }

        const data = await response.json();
        items = items.concat(data.items);
        nextUrl = data.next;
        
        document.getElementById('loading-text').innerText = `Fetching tracks... (${items.length})`;
    }

    const validTracks = [];
    
    items.forEach(item => {
        const track = item.track;
        if (!track) return;

        if (track.album && track.album.release_date) {
            const releaseDate = track.album.release_date;
            const year = parseInt(releaseDate.substring(0, 4));
            
            if (!isNaN(year)) {
                validTracks.push({
                    name: track.name,
                    year: year,
                    decade: Math.floor(year / 10) * 10
                });
            }
        }
    });

    if (validTracks.length === 0) {
        throw new Error("No valid tracks found with release dates.");
    }

    renderCharts(validTracks);
}

function renderCharts(tracks) {
    const years = tracks.map(t => t.year);
    const decades = tracks.map(t => t.decade);

    const yearTrace = {
        x: years,
        type: 'histogram',
        marker: { color: '#1DB954' },
        xbins: { size: 1 }
    };

    const yearLayout = {
        title: 'Songs by Year',
        paper_bgcolor: 'rgba(0,0,0,0)',
        plot_bgcolor: 'rgba(0,0,0,0)',
        font: { color: '#FFF' },
        margin: { t: 40, l: 40, r: 20, b: 40 },
        height: 400,
        xaxis: { title: 'Year', tickmode: 'linear', dtick: 1 },
        yaxis: { title: 'Count' },
        bargap: 0.1,
        autosize: true
    };

    Plotly.newPlot('year-chart', [yearTrace], yearLayout, {responsive: true});

    const decadeTrace = {
        x: decades,
        type: 'histogram',
        marker: { color: '#33C1FF' },
        xbins: { size: 10 }
    };

    const decadeLayout = {
        title: 'Songs by Decade',
        paper_bgcolor: 'rgba(0,0,0,0)',
        plot_bgcolor: 'rgba(0,0,0,0)',
        font: { color: '#FFF' },
        margin: { t: 40, l: 40, r: 20, b: 40 },
        height: 400,
        xaxis: { title: 'Decade', tickmode: 'linear', dtick: 10 },
        yaxis: { title: 'Count' },
        bargap: 0.1,
        autosize: true
    };
    
    Plotly.newPlot('decade-chart', [decadeTrace], decadeLayout, {responsive: true}).then(() => {
        window.dispatchEvent(new Event('resize'));
    });

    renderTable(tracks);
}

function renderTable(tracks) {
    tracks.sort((a, b) => a.year - b.year);

    const container = document.getElementById('songs-table-container');
    let html = `
        <table>
            <thead>
                <tr>
                    <th>Year</th>
                    <th>Song Name</th>
                    <th>Decade</th>
                </tr>
            </thead>
            <tbody>
    `;

    tracks.forEach(track => {
        html += `
            <tr>
                <td>${track.year}</td>
                <td>${track.name}</td>
                <td>${track.decade}s</td>
            </tr>
        `;
    });

    html += `
            </tbody>
        </table>
    `;

    container.innerHTML = html;
}
