#!/usr/bin/env ruby
# frozen_string_literal: true

# Quick edit-send loop for testing Telegram rich text / legacy entity setups.
# Edit the SCENARIO block below, then just re-run:
#   bundle exec ruby script/rich_format_playground.rb
#
# Sends to the dev bot's private chat with you (chat_id below), so you can
# check the result in Telegram immediately after each run.

require 'dotenv'
require 'telegram/bot'
require 'json'

Dotenv.load(File.expand_path('../tokens.env', __dir__))

CHAT_ID = 470_438_197 # boatarde's user id - private chat with biludevbot
T = Telegram::Bot::Types

bot = Telegram::Bot::Client.new(ENV['BILU_DEV_TELEGRAM_TOKEN'])

def utf16_length(str)
  str.each_char.sum { |c| c.ord > 0xFFFF ? 2 : 1 }
end

# Sends a plain sendMessage with manual entities (the legacy formatting system:
# bold, italic, spoiler, blockquote, expandable_blockquote, code, date_time...).
def send_legacy(bot, text, entities, reply_markup: nil)
  result = bot.api.send_message(
    chat_id: CHAT_ID,
    text: text,
    entities: entities,
    reply_markup: reply_markup
  )
  puts "SUCCESS message_id=#{result.message_id}"
rescue Telegram::Bot::Exceptions::ResponseError => e
  puts "FAILED: #{e.response.body}"
end

# Sends a sendRichMessage with structured blocks (paragraph/heading/collage/
# details/blockquote/footer/etc. - see telegram-bot-ruby's types/rich_block_*).
def send_rich(bot, blocks, reply_markup: nil)
  result = bot.api.send_rich_message(
    chat_id: CHAT_ID,
    rich_message: T::InputRichMessage.new(blocks: blocks),
    reply_markup: reply_markup
  )
  puts "SUCCESS message_id=#{result.message_id}"
  puts "rich_message block types: #{result.rich_message.blocks.map(&:type).inspect}"
rescue Telegram::Bot::Exceptions::ResponseError => e
  puts "FAILED: #{e.response.body}"
end

# ---------------------------------------------------------------------------
# SCENARIO - edit below, then re-run the script.
# Uncomment ONE of the two blocks (legacy or rich), leave the other commented.
# ---------------------------------------------------------------------------

# -- Legacy entities scenario -------------------------------------------------
header = 'r/example'
byline = 'u/someone'
tag = "\u{1F51E} NSFW"
title = 'A test title to see how it wraps and where entities land'
body = "Some body text.\nSecond line of body text to check the blockquote."

text = "#{header}\n#{byline}\n\n#{tag}\n#{title}\n\n#{body}\n\n\u{25B2} 42"
entities = [
  { type: 'bold', offset: 0, length: utf16_length(header) },
  { type: 'code', offset: utf16_length("#{header}\n#{byline}\n\n"), length: utf16_length(tag) },
  { type: 'bold', offset: utf16_length("#{header}\n#{byline}\n\n#{tag}\n"), length: utf16_length(title) },
  { type: 'expandable_blockquote', offset: utf16_length("#{header}\n#{byline}\n\n#{tag}\n#{title}\n\n"),
    length: utf16_length(body) }
]
reply_markup = T::InlineKeyboardMarkup.new(
  inline_keyboard: [[
    T::InlineKeyboardButton.new(text: '13 Comments', url: 'https://www.reddit.com/'),
    T::InlineKeyboardButton.new(text: 'More from r/example', callback_data: 'callback /r example')
  ]]
)
send_legacy(bot, text, entities, reply_markup: reply_markup)

text = "My mom was overseas and i had the house to myself during college so i brought a $300 sex toy of a fat jiggly ass. It was the second sex tot I ever brought.

I didn’t want to get one too small because that’s weird as hell so my only other option was life size, and 60lbs. The first time i used it i was so lost in the sauce i forgot to breathe. The second i took a break and took a single breath, i started spasming on the floor due to lack of oxygen. It felt like my chest was caving it every breath.

One day i had it in reverse cowgirl and it rolled on me by accident. i thought i was finna die when it hit my neck. The toys lips touched my lips, when it rolled across my face i ended up tasted my kids. I tried to push it off of me but i was so tired and the toy was so damn slippery i couldn’t get the damn thing off of me in time. Have you ever tried to throw wet HEAVY silicone while spent? That shit is impossible.

I genuinely miss it because i had it for about 5 months. I was able to throw it away with amazing luck because my homie visited and moved the trash closer to the house to be kind but he unknowingly moved it out of range of the camera so i can dump it, the house cameras also died and needed to be charged the day it came and the day i needed to throw it away. She has no evidence of me having it.

I only got it because i heard that dudes during their first time has a weak stroke game or can’t nut so in my mind I might as well get practice in. I been asked out twice which i rejected both because one was crazy and the other annoyed me. Recently i’ve been getting way more attention by women so I thought i should practice just in case.

So there was this post, that was like “share your wildest gooning stories!” In my mind It wasn’t that bad so I commented mine. Normally my comments get 1,000 likes sometimes so I didn’t think much of it. 19k likes…my confession got 19k likes. Now whenever I comment on instagram I get a screenshot of what i said in the replies of my comment.

I said that shit in conference that it would be buried. I only told 2 people of this and now I am confident many of my peers saw it by now too.

TLDR brought a 60lbs $300 sex toy because i wanted to practice my stroke game, what ended up happening is I forgot to breathe so i ended up spasming on the floor."

# -- Rich message scenario (uncomment to use instead) ------------------------
blocks = [
  T::InputRichBlockParagraph.new(text: T::RichTextBold.new(text: 'r/example')),
  T::InputRichBlockParagraph.new(text: [
    'u/someone'
  ]),
  T::InputRichBlockParagraph.new(text: T::RichTextMarked.new(text: "\u{1F51E} NSFW")),
  T::InputRichBlockSectionHeading.new(text: 'A test title', size: 3),
  T::InputRichBlockDetails.new(
    summary: 'Read more',
    blocks: [T::InputRichBlockParagraph.new(text: 'Some body text.')]
  ),
  T::InputRichBlockFooter.new(text: "\u{25B2} 42")
]
send_rich(bot, blocks)
