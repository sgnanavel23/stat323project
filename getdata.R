# Load the packages
library(httr)
library(base64enc)
library(jsonlite)

# Set your Spotify API credentials
client_id <- "a55a11bb77454560aaccf3d89fd09027"
client_secret <- "9510178f564b4b69a3aaf78e4a7d099f"

token <- get_token(client_id, client_secret)

get_token <- function(client_id, client_secret) {
  # Encode client ID and secret
  auth_string <- paste0(client_id, ":", client_secret)
  auth_base64 <- base64encode(charToRaw(auth_string))
  
  # Prepare request
  url <- "https://accounts.spotify.com/api/token"
  headers <- add_headers(
    Authorization = paste("Basic", auth_base64),
    `Content-Type` = "application/x-www-form-urlencoded"
  )
  body <- list(grant_type = "client_credentials")
  
  # Send POST request
  response <- POST(url, headers, body = body, encode = "form")
  content <- content(response, as = "text", encoding = "UTF-8")
  print (content)
  token <- fromJSON(content)$access_token
  
  return(token)
}

get_auth_header <- function(token) {
  return(add_headers(Authorization = paste("Bearer", token)))
}

################################################################################

# ARTIST DATA

artists <- c(
  "Bruno Mars", "The Weeknd", "Lady Gaga", "Billie Eilish", "Kendrick Lamar",
  "Coldplay", "Rihanna", "SZA", "Bad Bunny", "Taylor Swift", "Ariana Grande",
  "Ed Sheeran", "Justin Bieber", "Drake", "David Guetta", "Dua Lipa",
  "Eminem", "Travis Scott", "Sia", "Calvin Harris", "Sabrina Carpenter",
  "Post Malone", "Shakira", "J Balvin", "Kanye West"
)

search_spotify_artist <- function(token, artist_name) {
  url <- paste0('https://api.spotify.com/v1/search?q=', URLencode(artist_name), '&type=artist&limit=1')
  response <- httr::GET(
    url, 
    httr::add_headers(Authorization = paste('Bearer', token))
  )
  content <- httr::content(response, "parsed")
  
  if (length(content$artists$items) == 0) {
    return(NULL)  # Skip if no artist found
  }
  
  artist <- content$artists$items[[1]]
  
  return(data.frame(
    name = artist$name,
    id = artist$id,
    popularity = artist$popularity,
    followers = artist$followers$total,
    genres = paste(artist$genres, collapse = ", "),
    spotify_url = artist$external_urls$spotify,
    stringsAsFactors = FALSE
  ))
}

all_top_artists <- do.call(rbind, lapply(artists, function(name) {
  tryCatch({
    Sys.sleep(0.5)
    search_spotify_artist(token, name)
  }, error = function(e) {
    message("Failed to fetch: ", name)
    return(NULL)
  })
}))

################################################################################

# TRACK DATA

get_artist_top_tracks <- function(token, artist_id, market = "US") {
  url <- paste0("https://api.spotify.com/v1/artists/", artist_id, "/top-tracks?market=", market)
  response <- httr::GET(url, httr::add_headers(Authorization = paste("Bearer", token)))
  
  # Check for request success
  if (response$status_code != 200) {
    message("Request failed with status: ", response$status_code)
    return(NULL)
  }
  
  content <- httr::content(response, "parsed")
  
  if (length(content$tracks) == 0) {
    message("No tracks returned for artist ID: ", artist_id)
    return(NULL)
  }
  
  tracks <- content$tracks
  
  top_tracks_df <- do.call(rbind, lapply(tracks, function(track) {
    data.frame(
      name = track$name,
      popularity = track$popularity,
      album_name = track$album$name,
      id = track$id,
      duration_min = round(track$duration_ms / 60000, 2),
      explicit = ifelse(is.null(track$explicit), NA, track$explicit),
      spotify_url = ifelse(is.null(track$external_urls$spotify), NA, track$external_urls$spotify),
      track_number = ifelse(is.null(track$track_number), NA, track$track_number),
      stringsAsFactors = FALSE
    )
  }))
  
  return(top_tracks_df)
}

all_top_tracks <- do.call(rbind, lapply(1:nrow(artist_data), function(i) {
  tryCatch({
    Sys.sleep(0.5)
    tracks <- get_artist_top_tracks(token, artist_data$id[i])
    
    if (!is.null(tracks)) {
      tracks$artist <- artist_data$name[i]
    }
    
    return(tracks)
  }, error = function(e) {
    message("Failed to fetch top tracks for: ", artist_data$name[i])
    return(NULL)
  })
}))
