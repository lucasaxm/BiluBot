class OverwatchController

  def sub_router(bilu, message)
    bilu.reply_with_text("received #{message.text}", message)
  end

end
