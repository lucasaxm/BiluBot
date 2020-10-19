require_relative '../logger/logging'

class DistortService
  include Logging

  # @param [Bilu::Bot] bilu
  def initialize(bilu)
    @bilu = bilu
  end

  def distort(message)
    return unless message.reply_to_message
    m = message.reply_to_message
    if m.photo
      file_id = m.photo[-1].file_id
      file_name = "#{file_id}.jpg"
    elsif m.sticker
      return if m.sticker.is_animated
      file_id = m.sticker.file_id
      file_name = "#{file_id}.webp"
    elsif m.document
      return unless m.document.mime_type.startswith("image/")
      file_id = m.document.file_id
      file_name = "#{file_id}.#{m.document.mime_type.split('/')[1]}"
    end

    file_path = @bilu.get_file(file_id)
    temp_file = @bilu.download_file(file_path, file_name)



  end

end