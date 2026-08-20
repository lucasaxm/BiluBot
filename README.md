# BiluBot

A Telegram bot written in Ruby. Its main feature is pulling media from Reddit
(`/r <subreddit>`), plus assorted media downloading and image commands.

## Requirements

- Ruby 3.4.x (see `.tool-versions`, managed with [asdf](https://asdf-vm.com/))
- ImageMagick (for `rmagick`) and ffmpeg
- Python tools used to download media: `yt-dlp` and `gallery-dl` (`pip install -r requirements.txt`)

The database is SQLite and is created automatically on first run at
`db/bilubot.sqlite3`. Set `DATABASE_URL` if you want to point somewhere else.

## Setup

```bash
asdf install            # installs the Ruby version in .tool-versions
bundle install
pip install -r requirements.txt

cp tokens.example.env tokens.env   # then fill in the values
```

### Reddit credentials

Reddit requires OAuth for API access. Create a **script** app at
<https://www.reddit.com/prefs/apps> and fill in `tokens.env`:

- `BILU_REDDIT_CLIENT_ID_DL` — the app's client id
- `BILU_REDDIT_CLIENT_SECRET_DL` — the app's secret
- `BILU_REDDIT_APP_NAME_DL` and `BILU_REDDIT_USERNAME` — used to build the
  descriptive `User-Agent` that Reddit requires

The bot uses application-only (client credentials) OAuth, so it reads public
subreddits without logging in as a user. NSFW listings are generally not
available to app-only tokens.

### Telegram credentials

Get a token from [@BotFather](https://core.telegram.org/bots#6-botfather) and set
`BILU_TELEGRAM_TOKEN`. `BILU_TELEGRAM_LOG_ID` is the chat id where errors are
reported. The `-d`/`--dev` flag makes the bot use `BILU_DEV_*` values instead.

## Running

```bash
./run_bilubot.sh              # auto-restarting loop
bundle exec ruby server.rb    # single run
bundle exec ruby server.rb -d # dev mode
```

## Checks

These don't need credentials or network access:

```bash
bundle exec ruby script/reddit_client_test.rb  # Reddit API client, stubbed HTTP
bundle exec ruby script/reddit_flow_test.rb    # /r command flow, stubbed Telegram + Reddit
```

To verify real credentials against the live Reddit API:

```bash
bundle exec ruby script/reddit_smoke_test.rb ruby
```

## Commands

- `/r <subreddit>` — send a media post from the subreddit
- `/bsr <subreddit>` / `/usr <subreddit>` — ban/unban a subreddit in the chat (admins only in groups)
- `/print <url>`, `/leiaisso` — screenshots
- `-p <query>` / `-v <query>` — search and send audio/video
- links posted in chat are offered for download via gallery-dl/yt-dlp
